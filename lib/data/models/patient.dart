import '../../core/utils/date_fmt.dart';

/// مريض في عيادة الأعصاب.
class Patient {
  const Patient({
    this.id,
    this.fileNo,
    required this.fullName,
    this.nationalId,
    this.gender,
    this.birthDate,
    this.ageYears,
    this.weightKg,
    this.weightRecordedOn,
    this.ageRecordedOn,
    this.phone,
    this.phoneAlt,
    this.address,
    this.referralSource,
    this.bloodType,
    this.allergies,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String? fileNo;
  final String fullName;
  final String? nationalId;
  final String? gender; // m | f
  final DateTime? birthDate;
  final int? ageYears;
  final double? weightKg;
  final DateTime? weightRecordedOn;
  final DateTime? ageRecordedOn;
  final String? phone;
  final String? phoneAlt;
  final String? address;
  final String? referralSource;
  final String? bloodType;
  final String? allergies;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int? get age => ageYears ?? DateFmt.age(birthDate);

  String get ageLabel => age == null ? 'غير محدد' : '$age سنة';

  String get genderLabel => switch (gender) {
    'm' => 'ذكر',
    'f' => 'أنثى',
    _ => '—',
  };

  factory Patient.fromMap(Map<String, Object?> m) => Patient(
    id: m['id'] as int?,
    fileNo: m['file_no'] as String?,
    fullName: (m['full_name'] as String?) ?? '',
    nationalId: m['national_id'] as String?,
    gender: m['gender'] as String?,
    birthDate: DateFmt.parse(m['birth_date'] as String?),
    ageYears: m['age_years'] as int?,
    weightKg: (m['weight_kg'] as num?)?.toDouble(),
    weightRecordedOn: DateFmt.parse(m['weight_recorded_on'] as String?),
    ageRecordedOn: DateFmt.parse(m['age_recorded_on'] as String?),
    phone: m['phone'] as String?,
    phoneAlt: m['phone_alt'] as String?,
    address: m['address'] as String?,
    referralSource: m['referral_source'] as String?,
    bloodType: m['blood_type'] as String?,
    allergies: m['allergies'] as String?,
    notes: m['notes'] as String?,
    isActive: (m['is_active'] as int? ?? 1) == 1,
    createdAt: DateFmt.parse(m['created_at'] as String?),
    updatedAt: DateFmt.parse(m['updated_at'] as String?),
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'file_no': fileNo,
    'full_name': fullName,
    'national_id': nationalId,
    'gender': gender,
    'birth_date': birthDate == null ? null : DateFmt.isoDate(birthDate!),
    'age_years': ageYears,
    'weight_kg': weightKg,
    'weight_recorded_on': weightRecordedOn?.toIso8601String(),
    'age_recorded_on': ageRecordedOn == null
        ? null
        : DateFmt.isoDate(ageRecordedOn!),
    'phone': phone,
    'phone_alt': phoneAlt,
    'address': address,
    'referral_source': referralSource,
    'blood_type': bloodType,
    'allergies': allergies,
    'notes': notes,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  Patient copyWith({
    int? id,
    String? fileNo,
    String? fullName,
    String? nationalId,
    String? gender,
    DateTime? birthDate,
    int? ageYears,
    double? weightKg,
    DateTime? weightRecordedOn,
    DateTime? ageRecordedOn,
    String? phone,
    String? phoneAlt,
    String? address,
    String? referralSource,
    String? bloodType,
    String? allergies,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Patient(
    id: id ?? this.id,
    fileNo: fileNo ?? this.fileNo,
    fullName: fullName ?? this.fullName,
    nationalId: nationalId ?? this.nationalId,
    gender: gender ?? this.gender,
    birthDate: birthDate ?? this.birthDate,
    ageYears: ageYears ?? this.ageYears,
    weightKg: weightKg ?? this.weightKg,
    weightRecordedOn: weightRecordedOn ?? this.weightRecordedOn,
    ageRecordedOn: ageRecordedOn ?? this.ageRecordedOn,
    phone: phone ?? this.phone,
    phoneAlt: phoneAlt ?? this.phoneAlt,
    address: address ?? this.address,
    referralSource: referralSource ?? this.referralSource,
    bloodType: bloodType ?? this.bloodType,
    allergies: allergies ?? this.allergies,
    notes: notes ?? this.notes,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// بند في التاريخ المرضي العام (سكري، ضغط، ...).
class MedicalHistoryItem {
  const MedicalHistoryItem({
    this.id,
    required this.patientId,
    required this.condition,
    this.sinceYear,
    this.notes,
  });

  final int? id;
  final int patientId;
  final String condition;
  final int? sinceYear;
  final String? notes;

  factory MedicalHistoryItem.fromMap(Map<String, Object?> m) =>
      MedicalHistoryItem(
        id: m['id'] as int?,
        patientId: m['patient_id'] as int,
        condition: (m['condition'] as String?) ?? '',
        sinceYear: m['since_year'] as int?,
        notes: m['notes'] as String?,
      );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'patient_id': patientId,
    'condition': condition,
    'since_year': sinceYear,
    'notes': notes,
  };
}

/// دواء مزمن مستمر (مهم جداً في الأعصاب: الصرع، باركنسون، التصلب).
class Medication {
  const Medication({
    this.id,
    required this.patientId,
    required this.drug,
    this.dose,
    this.frequency,
    this.route,
    this.indication,
    this.startedOn,
    this.stoppedOn,
    this.isActive = true,
  });

  final int? id;
  final int patientId;
  final String drug;
  final String? dose;
  final String? frequency;
  final String? route;
  final String? indication;
  final DateTime? startedOn;
  final DateTime? stoppedOn;
  final bool isActive;

  factory Medication.fromMap(Map<String, Object?> m) => Medication(
    id: m['id'] as int?,
    patientId: m['patient_id'] as int,
    drug: (m['drug'] as String?) ?? '',
    dose: m['dose'] as String?,
    frequency: m['frequency'] as String?,
    route: m['route'] as String?,
    indication: m['indication'] as String?,
    startedOn: DateFmt.parse(m['started_on'] as String?),
    stoppedOn: DateFmt.parse(m['stopped_on'] as String?),
    isActive: (m['is_active'] as int? ?? 1) == 1,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'patient_id': patientId,
    'drug': drug,
    'dose': dose,
    'frequency': frequency,
    'route': route,
    'indication': indication,
    'started_on': startedOn == null ? null : DateFmt.isoDate(startedOn!),
    'stopped_on': stoppedOn == null ? null : DateFmt.isoDate(stoppedOn!),
    'is_active': isActive ? 1 : 0,
  };
}

