import '../../core/utils/date_fmt.dart';

/// موعد في عيادة الأعصاب.
class Appointment {
  const Appointment({
    this.id,
    required this.patientId,
    required this.startAt,
    this.durationMin = 20,
    this.status = 'scheduled',
    this.reason,
    this.createdAt,
    this.patientName,
    this.patientPhone,
    this.kind,
    this.sessionName,
    this.sessionId,
    this.visitId,
  });

  final int? id;
  final int patientId;
  final DateTime startAt;
  final int durationMin;
  final String status;
  final String? reason;
  final DateTime? createdAt;

  /// 'checkup' معاينة، 'session' جلسة، null = موعد قديم غير محدد النوع.
  final String? kind;

  /// نوع الجلسة (جلسة EMS / جلسة سحب فقرات) عندما kind = session.
  final String? sessionName;

  /// الجلسة المرتبطة (treatment_sessions) — تُملأ عند الإنشاء من الزيارة أو عند الإنجاز.
  final int? sessionId;

  /// الزيارة المرتبطة عند إنجاز موعد معاينة.
  final int? visitId;

  bool get isSession => kind == 'session';
  bool get isCheckup => kind == 'checkup';

  String get kindLabel => switch (kind) {
    'checkup' => 'معاينة',
    'session' => sessionName?.trim().isNotEmpty == true ? sessionName! : 'جلسة',
    _ => 'غير محدد',
  };

  // من JOIN مع جدول المرضى
  final String? patientName;
  final String? patientPhone;

  DateTime get endAt => startAt.add(Duration(minutes: durationMin));

  String get statusLabel => switch (status) {
    'scheduled' => 'مجدول',
    'arrived' => 'وصل',
    'done' => 'تم',
    'cancelled' => 'ملغى',
    'no_show' => 'لم يحضر',
    _ => status,
  };

  factory Appointment.fromMap(Map<String, Object?> m) => Appointment(
    id: m['id'] as int?,
    patientId: m['patient_id'] as int,
    startAt: DateFmt.parse(m['start_at'] as String?) ?? DateTime.now(),
    durationMin: (m['duration_min'] as int?) ?? 20,
    status: (m['status'] as String?) ?? 'scheduled',
    reason: m['reason'] as String?,
    createdAt: DateFmt.parse(m['created_at'] as String?),
    patientName: m['full_name'] as String?,
    patientPhone: m['phone'] as String?,
    kind: m['kind'] as String?,
    sessionName: m['session_name'] as String?,
    sessionId: m['session_id'] as int?,
    visitId: m['visit_id'] as int?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'patient_id': patientId,
    'start_at': startAt.toIso8601String(),
    'duration_min': durationMin,
    'status': status,
    'reason': reason,
    'created_at': createdAt?.toIso8601String(),
    'kind': kind,
    'session_name': kind == 'session' ? sessionName : null,
    'session_id': sessionId,
    'visit_id': visitId,
  };

  Appointment copyWith({
    int? id,
    int? patientId,
    DateTime? startAt,
    int? durationMin,
    String? status,
    String? reason,
    DateTime? createdAt,
    String? patientName,
    String? patientPhone,
    String? kind,
    String? sessionName,
    int? sessionId,
    int? visitId,
  }) => Appointment(
    id: id ?? this.id,
    patientId: patientId ?? this.patientId,
    startAt: startAt ?? this.startAt,
    durationMin: durationMin ?? this.durationMin,
    status: status ?? this.status,
    reason: reason ?? this.reason,
    createdAt: createdAt ?? this.createdAt,
    patientName: patientName ?? this.patientName,
    patientPhone: patientPhone ?? this.patientPhone,
    kind: kind ?? this.kind,
    sessionName: sessionName ?? this.sessionName,
    sessionId: sessionId ?? this.sessionId,
    visitId: visitId ?? this.visitId,
  );
}

/// عملية مالية (كشف / دفعة).
class Payment {
  const Payment({
    this.id,
    required this.patientId,
    this.visitId,
    required this.amount,
    this.method = 'cash',
    this.paidAt,
    this.note,
    this.patientName,
  });

  final int? id;
  final int patientId;
  final int? visitId;
  final double amount;
  final String method;
  final DateTime? paidAt;
  final String? note;
  final String? patientName;

  factory Payment.fromMap(Map<String, Object?> m) => Payment(
    id: m['id'] as int?,
    patientId: m['patient_id'] as int,
    visitId: m['visit_id'] as int?,
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    method: (m['method'] as String?) ?? 'cash',
    paidAt: DateFmt.parse(m['paid_at'] as String?),
    note: m['note'] as String?,
    patientName: m['full_name'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'patient_id': patientId,
    'visit_id': visitId,
    'amount': amount,
    'method': method,
    'paid_at': paidAt?.toIso8601String(),
    'note': note,
  };
}

/// استقصاء / فحص مساند (EEG، MRI، EMG، ...).
class Investigation {
  const Investigation({
    this.id,
    required this.patientId,
    this.visitId,
    required this.kind,
    this.bodySite,
    this.performedOn,
    this.report,
    this.attachmentPath,
    this.createdAt,
  });

  final int? id;
  final int patientId;
  final int? visitId;
  final String kind;
  final String? bodySite;
  final DateTime? performedOn;
  final String? report;
  final String? attachmentPath;
  final DateTime? createdAt;

  factory Investigation.fromMap(Map<String, Object?> m) => Investigation(
    id: m['id'] as int?,
    patientId: m['patient_id'] as int,
    visitId: m['visit_id'] as int?,
    kind: (m['kind'] as String?) ?? '',
    bodySite: m['body_site'] as String?,
    performedOn: DateFmt.parse(m['performed_on'] as String?),
    report: m['report'] as String?,
    attachmentPath: m['attachment_path'] as String?,
    createdAt: DateFmt.parse(m['created_at'] as String?),
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'patient_id': patientId,
    'visit_id': visitId,
    'kind': kind,
    'body_site': bodySite,
    'performed_on': performedOn == null ? null : DateFmt.isoDate(performedOn!),
    'report': report,
    'attachment_path': attachmentPath,
    'created_at': createdAt?.toIso8601String(),
  };
}
