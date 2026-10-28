import '../../core/utils/date_fmt.dart';

/// زيارة (كشف) واحدة للمريض.
class Visit {
  const Visit({
    this.id,
    required this.patientId,
    required this.visitDate,
    this.visitType = 'new',
    this.sessionName,
    this.patientWeightKg,
    this.completedAt,
    this.chiefComplaint,
    this.onsetDuration,
    this.diagnosis,
    this.icd10,
    this.plan,
    this.followupInDays,
    this.notes,
    this.createdAt,
    // ملحقات (تُحمَّل عند الحاجة)
    this.exam,
    this.scales = const [],
    this.prescriptions = const [],
    this.patientName,
    this.patientAgeYears,
    this.patientAgeRecordedOn,
  });

  final int? id;
  final int patientId;
  final DateTime visitDate;
  final String visitType;
  final String? sessionName;
  final double? patientWeightKg;
  final String? completedAt;
  final String? chiefComplaint;
  final String? onsetDuration;
  final String? diagnosis;
  final String? icd10;
  final String? plan;
  final int? followupInDays;
  final String? notes;
  final DateTime? createdAt;

  final NeuroExam? exam;
  final List<NeuroScale> scales;
  final List<Prescription> prescriptions;
  final String? patientName;
  final int? patientAgeYears;
  final String? patientAgeRecordedOn;

  DateTime? get followUpDate => followupInDays == null
      ? null
      : visitDate.add(Duration(days: followupInDays!));

  factory Visit.fromMap(Map<String, Object?> m) => Visit(
    id: m['id'] as int?,
    patientId: m['patient_id'] as int,
    visitDate: DateFmt.parse(m['visit_date'] as String?) ?? DateTime.now(),
    visitType:
        (m['visit_category'] as String?) ??
        (m['visit_type'] as String?) ??
        'new',
    sessionName: m['session_name'] as String?,
    patientWeightKg: (m['patient_weight_kg'] as num?)?.toDouble(),
    completedAt: m['completed_at'] as String?,
    chiefComplaint: m['chief_complaint'] as String?,
    onsetDuration: m['onset_duration'] as String?,
    diagnosis: m['diagnosis'] as String?,
    icd10: m['icd10'] as String?,
    plan: m['plan'] as String?,
    followupInDays: m['followup_in_days'] as int?,
    notes: m['notes'] as String?,
    createdAt: DateFmt.parse(m['created_at'] as String?),
    patientName: m['full_name'] as String?,
    patientAgeYears: m['patient_age_years'] as int?,
    patientAgeRecordedOn: m['patient_age_recorded_on'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'patient_id': patientId,
    'patient_weight_kg': patientWeightKg,
    'completed_at': completedAt,
    'patient_age_years': patientAgeYears,
    'patient_age_recorded_on': patientAgeRecordedOn,
    'visit_date': DateFmt.isoDate(visitDate),
    'visit_type': visitType == 'session'
        ? 'procedure'
        : visitType == 'first'
        ? 'new'
        : visitType,
    'visit_category': ['first', 'session'].contains(visitType)
        ? visitType
        : null,
    'session_name': visitType == 'session' ? sessionName : null,
    'chief_complaint': chiefComplaint,
    'onset_duration': onsetDuration,
    'diagnosis': diagnosis,
    'icd10': icd10,
    'plan': plan,
    'followup_in_days': followupInDays,
    'notes': notes,
    'created_at': createdAt?.toIso8601String(),
  };

  Visit copyWith({
    int? id,
    int? patientId,
    DateTime? visitDate,
    String? visitType,
    String? sessionName,
    double? patientWeightKg,
    String? completedAt,
    String? chiefComplaint,
    String? onsetDuration,
    String? diagnosis,
    String? icd10,
    String? plan,
    int? followupInDays,
    String? notes,
    DateTime? createdAt,
    NeuroExam? exam,
    List<NeuroScale>? scales,
    List<Prescription>? prescriptions,
    String? patientName,
    int? patientAgeYears,
    String? patientAgeRecordedOn,
  }) => Visit(
    id: id ?? this.id,
    patientId: patientId ?? this.patientId,
    visitDate: visitDate ?? this.visitDate,
    visitType: visitType ?? this.visitType,
    sessionName: sessionName ?? this.sessionName,
    patientWeightKg: patientWeightKg ?? this.patientWeightKg,
    completedAt: completedAt ?? this.completedAt,
    chiefComplaint: chiefComplaint ?? this.chiefComplaint,
    onsetDuration: onsetDuration ?? this.onsetDuration,
    diagnosis: diagnosis ?? this.diagnosis,
    icd10: icd10 ?? this.icd10,
    plan: plan ?? this.plan,
    followupInDays: followupInDays ?? this.followupInDays,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    exam: exam ?? this.exam,
    scales: scales ?? this.scales,
    prescriptions: prescriptions ?? this.prescriptions,
    patientName: patientName ?? this.patientName,
    patientAgeYears: patientAgeYears ?? this.patientAgeYears,
    patientAgeRecordedOn: patientAgeRecordedOn ?? this.patientAgeRecordedOn,
  );
}

/// الفحص العصبي الموجّه المرافق للزيارة.
class NeuroExam {
  const NeuroExam({
    this.id,
    this.visitId,
    this.gcs,
    this.consciousness,
    this.orientation,
    this.speech,
    this.cranialNerves,
    this.motorPower,
    this.tone,
    this.reflexes,
    this.sensation,
    this.coordination,
    this.gait,
    this.meningeal,
    this.findings,
  });

  final int? id;
  final int? visitId;
  final int? gcs;
  final String? consciousness;
  final String? orientation;
  final String? speech;
  final String? cranialNerves;
  final String? motorPower;
  final String? tone;
  final String? reflexes;
  final String? sensation;
  final String? coordination;
  final String? gait;
  final String? meningeal;
  final String? findings;

  bool get isEmpty => [
    gcs,
    consciousness,
    orientation,
    speech,
    cranialNerves,
    motorPower,
    tone,
    reflexes,
    sensation,
    coordination,
    gait,
    meningeal,
    findings,
  ].every((e) => e == null || (e is String && e.trim().isEmpty));

  factory NeuroExam.fromMap(Map<String, Object?> m) => NeuroExam(
    id: m['id'] as int?,
    visitId: m['visit_id'] as int?,
    gcs: m['gcs'] as int?,
    consciousness: m['consciousness'] as String?,
    orientation: m['orientation'] as String?,
    speech: m['speech'] as String?,
    cranialNerves: m['cranial_nerves'] as String?,
    motorPower: m['motor_power'] as String?,
    tone: m['tone'] as String?,
    reflexes: m['reflexes'] as String?,
    sensation: m['sensation'] as String?,
    coordination: m['coordination'] as String?,
    gait: m['gait'] as String?,
    meningeal: m['meningeal'] as String?,
    findings: m['findings'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'visit_id': visitId,
    'gcs': gcs,
    'consciousness': consciousness,
    'orientation': orientation,
    'speech': speech,
    'cranial_nerves': cranialNerves,
    'motor_power': motorPower,
    'tone': tone,
    'reflexes': reflexes,
    'sensation': sensation,
    'coordination': coordination,
    'gait': gait,
    'meningeal': meningeal,
    'findings': findings,
  };

  NeuroExam copyWith({
    int? id,
    int? visitId,
    int? gcs,
    String? consciousness,
    String? orientation,
    String? speech,
    String? cranialNerves,
    String? motorPower,
    String? tone,
    String? reflexes,
    String? sensation,
    String? coordination,
    String? gait,
    String? meningeal,
    String? findings,
  }) => NeuroExam(
    id: id ?? this.id,
    visitId: visitId ?? this.visitId,
    gcs: gcs ?? this.gcs,
    consciousness: consciousness ?? this.consciousness,
    orientation: orientation ?? this.orientation,
    speech: speech ?? this.speech,
    cranialNerves: cranialNerves ?? this.cranialNerves,
    motorPower: motorPower ?? this.motorPower,
    tone: tone ?? this.tone,
    reflexes: reflexes ?? this.reflexes,
    sensation: sensation ?? this.sensation,
    coordination: coordination ?? this.coordination,
    gait: gait ?? this.gait,
    meningeal: meningeal ?? this.meningeal,
    findings: findings ?? this.findings,
  );
}

/// نتيجة مقياس عصبي معياري (MMSE, EDSS, ...).
class NeuroScale {
  const NeuroScale({
    this.id,
    required this.visitId,
    required this.scale,
    required this.score,
    this.maxScore,
    this.notes,
    this.recordedAt,
  });

  final int? id;
  final int visitId;
  final String scale;
  final double score;
  final double? maxScore;
  final String? notes;
  final DateTime? recordedAt;

  factory NeuroScale.fromMap(Map<String, Object?> m) => NeuroScale(
    id: m['id'] as int?,
    visitId: m['visit_id'] as int,
    scale: (m['scale'] as String?) ?? '',
    score: (m['score'] as num?)?.toDouble() ?? 0,
    maxScore: (m['max_score'] as num?)?.toDouble(),
    notes: m['notes'] as String?,
    recordedAt: DateFmt.parse(m['recorded_at'] as String?),
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'visit_id': visitId,
    'scale': scale,
    'score': score,
    'max_score': maxScore,
    'notes': notes,
    'recorded_at': recordedAt?.toIso8601String(),
  };

  NeuroScale copyWith({
    int? id,
    int? visitId,
    String? scale,
    double? score,
    double? maxScore,
    String? notes,
    DateTime? recordedAt,
  }) => NeuroScale(
    id: id ?? this.id,
    visitId: visitId ?? this.visitId,
    scale: scale ?? this.scale,
    score: score ?? this.score,
    maxScore: maxScore ?? this.maxScore,
    notes: notes ?? this.notes,
    recordedAt: recordedAt ?? this.recordedAt,
  );
}

/// دواء موصوف في زيارة معينة.
class Prescription {
  const Prescription({
    this.id,
    this.visitId,
    required this.drug,
    this.dose,
    this.frequency,
    this.durationDays,
    this.notes,
  });

  final int? id;
  final int? visitId;
  final String drug;
  final String? dose;
  final String? frequency;
  final int? durationDays;
  final String? notes;

  factory Prescription.fromMap(Map<String, Object?> m) => Prescription(
    id: m['id'] as int?,
    visitId: m['visit_id'] as int?,
    drug: (m['drug'] as String?) ?? '',
    dose: m['dose'] as String?,
    frequency: m['frequency'] as String?,
    durationDays: m['duration_days'] as int?,
    notes: m['notes'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'visit_id': visitId,
    'drug': drug,
    'dose': dose,
    'frequency': frequency,
    'duration_days': durationDays,
    'notes': notes,
  };

  Prescription copyWith({
    int? id,
    int? visitId,
    String? drug,
    String? dose,
    String? frequency,
    int? durationDays,
    String? notes,
  }) => Prescription(
    id: id ?? this.id,
    visitId: visitId ?? this.visitId,
    drug: drug ?? this.drug,
    dose: dose ?? this.dose,
    frequency: frequency ?? this.frequency,
    durationDays: durationDays ?? this.durationDays,
    notes: notes ?? this.notes,
  );
}

