import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/providers/session_provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/neuro_constants.dart';
import '../../core/utils/age_input.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/patient.dart';
import '../../data/repositories/patient_repository.dart';
import '../../core/widgets/clinic_brand.dart';

/// نموذج إضافة / تعديل مريض.
/// الحقل الإلزامي الوحيد في البرنامج: اسم المريض الثلاثي (3 كلمات على الأقل).
/// الاسم القديم المحفوظ مسبقاً يُقبل كما هو إن لم يُعدَّل (لا نفرض تعديل
/// سجلات قديمة).
String? tripleNameError(String? value, {String? original}) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'اسم المريض الثلاثي مطلوب';
  if (original != null && v == original.trim()) return null;
  final words = v.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  if (words < 3) return 'اكتب الاسم الثلاثي (الاسم واسم الأب والكنية)';
  return null;
}

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key, this.patient});

  final Patient? patient;

  bool get isEdit => patient != null;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PatientRepository();

  late final TextEditingController _name;
  late final TextEditingController _fileNo;
  late final TextEditingController _nationalId;
  late final TextEditingController _phone;
  late final TextEditingController _phoneAlt;
  late final TextEditingController _address;
  late final TextEditingController _referral;
  late final TextEditingController _allergies;
  late final TextEditingController _notes;

  String? _gender;
  String? _bloodType;
  late final TextEditingController _age;
  late final TextEditingController _weight;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _name = TextEditingController(text: p?.fullName ?? '');
    _fileNo = TextEditingController(text: p?.fileNo ?? '');
    _nationalId = TextEditingController(text: p?.nationalId ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _phoneAlt = TextEditingController(text: p?.phoneAlt ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _referral = TextEditingController(text: p?.referralSource ?? '');
    _allergies = TextEditingController(text: p?.allergies ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _gender = p?.gender;
    _bloodType = p?.bloodType;
    _age = TextEditingController(text: p?.age?.toString() ?? '');
    _weight = TextEditingController(text: p?.weightKg?.toString() ?? '');
    _active = p?.isActive ?? true;

    if (p == null) _suggestFileNo();
  }

  Future<void> _suggestFileNo() async {
    final next = await _repo.nextFileNo();
    if (mounted) setState(() => _fileNo.text = next);
  }

  @override
  void dispose() {
    for (final c in [
      _age,
      _weight,
      _name,
      _fileNo,
      _nationalId,
      _phone,
      _phoneAlt,
      _address,
      _referral,
      _allergies,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // تحقّق من عدم تكرار رقم الملف
      if (_fileNo.text.trim().isNotEmpty) {
        final taken = await _repo.fileNoTaken(
          _fileNo.text.trim(),
          exceptId: widget.patient?.id,
        );
        if (taken && mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رقم الملف مستخدم لمريض آخر'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
      }

      final patient = Patient(
        id: widget.patient?.id,
        fileNo: _fileNo.text.trim().isEmpty ? null : _fileNo.text.trim(),
        fullName: _name.text.trim(),
        nationalId: _nationalId.text.trim().isEmpty
            ? null
            : _nationalId.text.trim(),
        gender: _gender,
        birthDate: widget.patient?.birthDate,
        ageYears: parseAge(_age.text),
        weightKg: parseWeight(_weight.text),
        weightRecordedOn: _weight.text.trim().isEmpty
            ? null
            : parseWeight(_weight.text) == widget.patient?.weightKg
            ? widget.patient?.weightRecordedOn
            : DateTime.now(),
        ageRecordedOn: _age.text.trim().isEmpty
            ? null
            : (parseAge(_age.text) == widget.patient?.ageYears
                  ? widget.patient?.ageRecordedOn ?? DateTime.now()
                  : DateTime.now()),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        phoneAlt: _phoneAlt.text.trim().isEmpty ? null : _phoneAlt.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        referralSource: _referral.text.trim().isEmpty
            ? null
            : _referral.text.trim(),
        bloodType: _bloodType,
        allergies: _allergies.text.trim().isEmpty
            ? null
            : _allergies.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        isActive: _active,
        createdAt: widget.patient?.createdAt,
      );

      if (widget.isEdit) {
        await _repo.update(patient);
      } else {
        await _repo.insert(patient);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر الحفظ: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// شريط الأزرار أعلى النافذة: إلغاء + حفظ في أقصى اليسار.
  Widget _topBar(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: 36,
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 36,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(
        title: Text(widget.isEdit ? 'تعديل بيانات المريض' : 'مريض جديد'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _topBar(context),
          Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  SectionCard(
                    title: 'البيانات الأساسية',
                    icon: Icons.person_outline,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        final cols = w > 700 ? 3 : (w > 420 ? 2 : 1);
                        final fw = cols == 1
                            ? double.infinity
                            : (w - 14 * (cols - 1)) / cols;
                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _field(
                              fw,
                              AppTextField(
                                controller: _name,
                                label: 'الاسم الثلاثي *',
                                validator: (v) => tripleNameError(
                                  v,
                                  original: widget.patient?.fullName,
                                ),
                              ),
                            ),
                            _field(
                              fw,
                              AppTextField(
                                controller: _fileNo,
                                label: 'رقم الملف',
                              ),
                            ),
                            _field(
                              fw,
                              AppTextField(
                                controller: _nationalId,
                                label: 'الرقم الوطني / الهوية',
                              ),
                            ),
                            _field(
                              fw,
                              AppTextField(
                                controller: _age,
                                label: 'العمر بالسنوات',
                                hint: 'مثال: 45 — يُحفظ مع تاريخ التسجيل',
                                keyboardType: TextInputType.number,
                                validator: validateAge,
                              ),
                            ),
                            _field(
                              fw,
                              AppTextField(
                                controller: _weight,
                                label: 'الوزن (كغ)',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: validateWeight,
                              ),
                            ),
                            _field(
                              fw,
                              AppDropdownField<String>(
                                label: 'الجنس',
                                value: _gender,
                                items: NeuroConstants.genders.entries
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(e.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => _gender = v),
                              ),
                            ),
                            _field(
                              fw,
                              AppDropdownField<String>(
                                label: 'فصيلة الدم',
                                value: _bloodType,
                                items: NeuroConstants.bloodTypes
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _bloodType = v),
                              ),
                            ),
                            _field(
                              fw,
                              AppTextField(
                                controller: _phone,
                                label: 'الهاتف',
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            _field(
                              fw,
                              AppTextField(
                                controller: _phoneAlt,
                                label: 'هاتف بديل',
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            _field(
                              fw,
                              AppTextField(
                                controller: _address,
                                label: 'العنوان',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (context.watch<SessionProvider>().user?.isDoctor == true)
                    SectionCard(
                      title: 'ملاحظات سريرية',
                      icon: Icons.medical_information_outlined,
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _allergies,
                            label: 'الحساسية (أدوية / أطعمة)',
                            maxLines: 1,
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _notes,
                            label: 'ملاحظات عامة',
                            maxLines: 1,
                          ),
                          if (widget.isEdit) ...[
                            const SizedBox(height: 14),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'الملف نشط',
                                style: TextStyle(fontSize: 13.5),
                              ),
                              value: _active,
                              onChanged: (v) => setState(() => _active = v),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _field(double fw, Widget child) =>
      SizedBox(width: fw, child: child);
}

