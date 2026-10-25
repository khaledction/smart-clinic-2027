import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/attachment_picker.dart';
import '../../core/widgets/attachment_viewer.dart';
import '../patients/patient_header.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/widgets/date_input.dart';
import '../../core/widgets/day_groups.dart';
import '../../data/repositories/visit_repository.dart';
import '../../core/widgets/clinic_brand.dart';

/// تسميات العرض فقط — القيم المخزنة في قاعدة البيانات لا تتغير.
const resultStatuses = {
  'legacy': 'صور وتحاليل سابقة',
  'requested': 'مطلوب',
  'received': 'وردت النتيجة',
  'reviewed': 'راجع الطبيب النتيجة',
};

/// رمز صغير معبّر عن كل حالة.
const resultStatusIcons = <String, IconData>{
  'legacy': Icons.photo_library_outlined,
  'requested': Icons.pending_actions_outlined,
  'received': Icons.move_to_inbox_outlined,
  'reviewed': Icons.fact_check_outlined,
};

Widget _statusLabel(String? status, {double size = 18}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(
      resultStatusIcons[status] ?? Icons.help_outline,
      size: size,
      color: AppColors.navy,
    ),
    const SizedBox(width: 8),
    Flexible(
      child: Text(
        resultStatuses[status] ?? 'غير محدد',
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
);

class InvestigationsScreen extends StatefulWidget {
  const InvestigationsScreen({
    super.key,
    required this.patientId,
    this.sourceVisitId,
  });
  final int patientId;
  final int? sourceVisitId;
  @override
  State<InvestigationsScreen> createState() => _InvestigationsScreenState();
}

class _InvestigationsScreenState extends State<InvestigationsScreen> {
  late Future<List<Map<String, Object?>>> _rows = _load();
  Future<List<Map<String, Object?>>> _load() async =>
      (await AppDatabase.instance.database).rawQuery(
        'SELECT i.*, (SELECT COUNT(*) FROM investigation_attachments a '
        'WHERE a.investigation_id=i.id) AS att_count '
        'FROM investigations i WHERE i.patient_id=? '
        'ORDER BY i.performed_on DESC, i.id DESC',
        [widget.patientId],
      );
  void refresh() {
    setState(() {
      _rows = _load();
    });
  }

  Future<void> _edit([Map<String, Object?>? old]) async {
    final visits = await VisitRepository().forPatient(widget.patientId);
    if (!mounted) return;
    final name = TextEditingController(text: old?['kind'] as String?),
        site = TextEditingController(text: old?['body_site'] as String?),
        report = TextEditingController(text: old?['report'] as String?),
        facility = TextEditingController(text: old?['facility'] as String?);
    String status = old?['workflow_status'] as String? ?? 'requested';
    int? visitId = old?['visit_id'] as int? ?? widget.sourceVisitId;
    DateTime date =
        DateFmt.parse(old?['performed_on'] as String?) ?? DateTime.now();
    // مرفقات جديدة تُحفظ داخل قاعدة البيانات عند «حفظ».
    final pending = <({String name, Uint8List bytes})>[];
    final saved = old == null
        ? <Map<String, Object?>>[]
        : await (await AppDatabase.instance.database).query(
            'investigation_attachments',
            columns: ['id', 'name'],
            where: 'investigation_id=?',
            whereArgs: [old['id']],
          );
    if (!mounted) return;
    String? error;
    bool busy = false;
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, up) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(
              old == null ? 'طلب / إضافة فحص أو تقرير' : 'تعديل توثيق الفحص',
            ),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'اسم الفحص / التحليل / التصوير',
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: site,
                        decoration: const InputDecoration(
                          labelText: 'المنطقة — مثال: تصوير كامل العمود الفقري',
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        initialValue: visitId ?? -1,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'الزيارة المرتبطة (اختياري)',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: -1,
                            child: Text('دون ربط بزيارة'),
                          ),
                          for (final v in visits)
                            DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                '${DateFmt.date(v.visitDate)} — زيارة ${v.id}',
                              ),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) => up(() => visitId = v == -1 ? null : v),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'حالة النتيجة',
                        ),
                        items: resultStatuses.keys
                            .map(
                              (k) => DropdownMenuItem(
                                value: k,
                                child: _statusLabel(k),
                              ),
                            )
                            .toList(),
                        onChanged: busy ? null : (v) => up(() => status = v!),
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          icon: const Icon(Icons.event_outlined, size: 18),
                          onPressed: busy
                              ? null
                              : () async {
                                  final d = await showAppDatePicker(
                                    ctx,
                                    helpText: 'تاريخ الطلب / الفحص',
                                    initialDate: date,
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime(2100),
                                  );
                                  if (d != null && ctx.mounted) {
                                    up(() => date = d);
                                  }
                                },
                          label: Text(
                            'تاريخ الطلب / الفحص: ${DateFmt.date(date)}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: facility,
                        decoration: const InputDecoration(
                          labelText: 'المخبر / مركز التصوير',
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: report,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'نص النتيجة / ملاحظات الطبيب',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _AttachmentList(
                        saved: [for (final r in saved) r['name'] as String],
                        pending: [for (final f in pending) f.name],
                        onRemovePending: busy
                            ? null
                            : (i) => up(() => pending.removeAt(i)),
                      ),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('invAttach'),
                    onPressed: busy
                        ? null
                        : () async {
                            try {
                              final pick = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowMultiple: true,
                                allowedExtensions: [
                                  'pdf',
                                  'png',
                                  'jpg',
                                  'jpeg',
                                ],
                                withData: false,
                              );
                              if (pick == null) return;
                              for (final picked in pick.files) {
                                final f = File(picked.path!);
                                if (await f.length() > 15 * 1024 * 1024) {
                                  throw StateError(
                                    'الحد الأقصى 15 ميغابايت للمرفق: ${path.basename(f.path)}',
                                  );
                                }
                                final bytes = await f.readAsBytes();
                                if (ctx.mounted) {
                                  up(
                                    () => pending.add((
                                      name: path.basename(f.path),
                                      bytes: bytes,
                                    )),
                                  );
                                }
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                up(() => error = e.toString());
                              }
                            }
                          },
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: const Text('إرفاق الصور أو PDF'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('invPreview'),
                    onPressed: busy
                        ? null
                        : () {
                            final files = [
                              for (final r in saved)
                                ViewerFile(
                                  name: r['name'] as String,
                                  load: () => _attachmentBytes(r['id'] as int),
                                ),
                              for (final f in pending)
                                ViewerFile(
                                  name: f.name,
                                  load: () async => f.bytes,
                                ),
                            ];
                            if (files.isEmpty) {
                              up(
                                () => error = 'لا توجد صور أو ملفات PDF للمعاينة. أرفقها أولاً.',
                              );
                              return;
                            }
                            AttachmentPicker.preview(ctx, files);
                          },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('معاينة الصور أو PDF'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('invSave'),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    onPressed: busy
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            // لا شيء مكتوب ولا مرفقات ← لا يُحفظ سجل فارغ.
                            if (old == null &&
                                pending.isEmpty &&
                                [
                                  name,
                                  site,
                                  facility,
                                  report,
                                ].every((c) => c.text.trim().isEmpty)) {
                              Navigator.pop(ctx);
                              return;
                            }
                            up(() => busy = true);
                            try {
                              final db = await AppDatabase.instance.database;
                              await db.transaction((tx) async {
                                if (visitId != null &&
                                    (await tx.query(
                                      'visits',
                                      where: 'id=? AND patient_id=?',
                                      whereArgs: [visitId, widget.patientId],
                                    )).isEmpty) {
                                  throw StateError('الزيارة لا تتبع للمريض');
                                }
                                final data = {
                                  'patient_id': widget.patientId,
                                  'visit_id': visitId,
                                  'kind': name.text.trim(),
                                  'body_site': site.text.trim(),
                                  'report': report.text.trim(),
                                  'facility': facility.text.trim(),
                                  'performed_on': DateFmt.isoDate(date),
                                  'workflow_status': status,
                                };
                                int id;
                                if (old == null) {
                                  id = await tx.insert('investigations', {
                                    ...data,
                                    'created_at': DateTime.now()
                                        .toIso8601String(),
                                  });
                                } else {
                                  id = old['id'] as int;
                                  await tx.update(
                                    'investigations',
                                    data,
                                    where: 'id=?',
                                    whereArgs: [id],
                                  );
                                  await tx.insert('audit_log', {
                                    'action': 'investigation_edit',
                                    'entity': 'investigations',
                                    'entity_id': id,
                                    'detail': 'before=$old',
                                    'at': DateTime.now().toIso8601String(),
                                  });
                                }
                                for (final f in pending) {
                                  await tx.insert('investigation_attachments', {
                                    'investigation_id': id,
                                    'name': f.name,
                                    'bytes': f.bytes,
                                  });
                                }
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (ctx.mounted) {
                                up(() {
                                  busy = false;
                                  error = e.toString();
                                });
                              }
                            }
                          },
                    label: const Text('حفظ'),
                  ),
                  TextButton.icon(
                    key: const Key('invCancel'),
                    onPressed: busy ? null : () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('إلغاء'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in [name, site, report, facility]) {
      c.dispose();
    }
    if (mounted) refresh();
  }

  Future<List<ViewerFile>> _savedFiles(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'investigation_attachments',
      columns: ['id', 'name'],
      where: 'investigation_id=?',
      whereArgs: [id],
      orderBy: 'id',
    );
    return [
      for (final r in rows)
        ViewerFile(
          name: r['name'] as String,
          load: () => _attachmentBytes(r['id'] as int),
        ),
    ];
  }

  /// «معاينة المرفق»: مباشرة لمرفق واحد، وإلا قائمة للاختيار.
  Future<void> _previewAttachments(int id) async {
    final files = await _savedFiles(id);
    if (!mounted) return;
    await AttachmentPicker.preview(context, files);
  }

  /// «المرفقات»: القائمة دائماً مع معاينة / تحميل / إلغاء.
  Future<void> _attachments(int id) async {
    final files = await _savedFiles(id);
    if (!mounted) return;
    await AttachmentPicker.show(context, files);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandedAppBar(
      title: const Text('الفحوص والنتائج'),
      actions: [
        TextButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('طلب / إضافة فحص'),
        ),
      ],
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ترويسة ملف المريض نفسها للتأكد أننا في الملف الصحيح.
        PatientChartHeaderLoader(patientId: widget.patientId),
        Expanded(child: _list()),
      ],
    ),
  );

  Widget _list() => FutureBuilder<List<Map<String, Object?>>>(
    future: _rows,
    builder: (ctx, s) {
      if (s.hasError) return Center(child: Text('تعذر التحميل: ${s.error}'));
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      if (s.data!.isEmpty) {
        return const Center(
          child: Text('لا توجد فحوص. أضف طلباً أو تقريراً من الأعلى.'),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: DayGroups<Map<String, Object?>>(
          items: s.data!,
          dateOf: (r) => DateFmt.parse(r['performed_on'] as String?),
          noun: 'فحص',
          groupBuilder: (rows) => Column(
            children: [
              for (final r in rows)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          (r['kind'] as String? ?? '').trim().isEmpty
                              ? 'فحص بدون اسم'
                              : r['kind'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _statusLabel(r['workflow_status'] as String?),
                        const SizedBox(height: 4),
                        Text('الجهة: ${r['facility'] ?? 'غير محددة'}'),
                        SelectableText(
                          r['report'] as String? ?? 'لم ترد نتيجة موثقة',
                        ),
                        if (r['attachment_path'] != null)
                          SelectableText(
                            'مسار مرفق قديم: ${r['attachment_path']}',
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _edit(r),
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: const Text('فتح / تعديل'),
                              ),
                              if (((r['att_count'] as int?) ?? 0) > 0) ...[
                                FilledButton.icon(
                                  key: Key('invCardPreview${r['id']}'),
                                  onPressed: () =>
                                      _previewAttachments(r['id'] as int),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('معاينة المرفق'),
                                ),
                                FilledButton.icon(
                                  key: Key('invCardFiles${r['id']}'),
                                  onPressed: () => _attachments(r['id'] as int),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 18,
                                  ),
                                  label: Text('المرفقات (${r['att_count']})'),
                                ),
                              ] else
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.attach_file,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'بدون مرفقات',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Future<Uint8List> _attachmentBytes(int id) async {
    final db = await AppDatabase.instance.database;
    final row = (await db.query(
      'investigation_attachments',
      columns: ['bytes'],
      where: 'id=?',
      whereArgs: [id],
    )).single;
    return row['bytes'] as Uint8List;
  }
}

/// قائمة المرفقات داخل نافذة الفحص: المحفوظة سابقاً والجديدة.
class _AttachmentList extends StatelessWidget {
  const _AttachmentList({
    required this.saved,
    required this.pending,
    required this.onRemovePending,
  });

  final List<String> saved;
  final List<String> pending;
  final void Function(int index)? onRemovePending;

  static IconData _icon(String name) => name.toLowerCase().endsWith('.pdf')
      ? Icons.picture_as_pdf_outlined
      : Icons.image_outlined;

  @override
  Widget build(BuildContext context) {
    if (saved.isEmpty && pending.isEmpty) {
      return const Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          'لا توجد مرفقات بعد — استخدم «إرفاق الصور أو PDF» في الأسفل.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final n in saved)
            Chip(
              avatar: Icon(_icon(n), size: 16, color: AppColors.navy),
              label: Text(n),
            ),
          for (var i = 0; i < pending.length; i++)
            InputChip(
              avatar: Icon(_icon(pending[i]), size: 16, color: AppColors.paid),
              label: Text('${pending[i]} (جديد)'),
              onDeleted: onRemovePending == null
                  ? null
                  : () => onRemovePending!(i),
              deleteButtonTooltipMessage: 'إزالة قبل الحفظ',
            ),
        ],
      ),
    );
  }
}
