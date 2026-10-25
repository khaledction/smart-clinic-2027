/// مستخدم النظام: طبيب / سكرتيرة (استقبال) / مدير.
class User {
  const User({
    this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.isActive = true,
  });

  final int? id;
  final String username;
  final String fullName;
  final String role; // doctor | reception | admin
  final bool isActive;

  bool get isDoctor => role == 'doctor' || role == 'admin';
  bool get isAdmin => role == 'admin';

  String get roleLabel => switch (role) {
    'doctor' => 'طبيب',
    'reception' => 'استقبال',
    'admin' => 'مدير',
    _ => role,
  };

  factory User.fromMap(Map<String, Object?> m) => User(
    id: m['id'] as int?,
    username: m['username'] as String,
    fullName: (m['full_name'] as String?) ?? '',
    role: m['role'] as String,
    isActive: (m['is_active'] as int? ?? 1) == 1,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'username': username,
    'full_name': fullName,
    'role': role,
    'is_active': isActive ? 1 : 0,
  };

  User copyWith({
    int? id,
    String? username,
    String? fullName,
    String? role,
    bool? isActive,
  }) => User(
    id: id ?? this.id,
    username: username ?? this.username,
    fullName: fullName ?? this.fullName,
    role: role ?? this.role,
    isActive: isActive ?? this.isActive,
  );
}

/// إعدادات العيادة (صف واحد فقط، id = 1).
class ClinicSettings {
  const ClinicSettings({
    this.clinicName = '',
    this.doctorName = '',
    this.specialty = '',
    this.phone = '',
    this.address = '',
    this.defaultFee = 0,
    this.visitDuration = 20,
    this.footerNote = '',
  });

  final String clinicName;
  final String doctorName;
  final String specialty;
  final String phone;
  final String address;
  final double defaultFee;
  final int visitDuration;
  final String footerNote;

  factory ClinicSettings.fromMap(Map<String, Object?>? m) {
    if (m == null) return const ClinicSettings();
    return ClinicSettings(
      clinicName: (m['clinic_name'] as String?) ?? '',
      doctorName: (m['doctor_name'] as String?) ?? '',
      specialty: (m['specialty'] as String?) ?? '',
      phone: (m['phone'] as String?) ?? '',
      address: (m['address'] as String?) ?? '',
      defaultFee: (m['default_fee'] as num?)?.toDouble() ?? 0,
      visitDuration: (m['visit_duration'] as int?) ?? 20,
      footerNote: (m['footer_note'] as String?) ?? '',
    );
  }

  Map<String, Object?> toMap() => {
    'id': 1,
    'clinic_name': clinicName,
    'doctor_name': doctorName,
    'specialty': specialty,
    'phone': phone,
    'address': address,
    'default_fee': defaultFee,
    'visit_duration': visitDuration,
    'footer_note': footerNote,
  };

  ClinicSettings copyWith({
    String? clinicName,
    String? doctorName,
    String? specialty,
    String? phone,
    String? address,
    double? defaultFee,
    int? visitDuration,
    String? footerNote,
  }) => ClinicSettings(
    clinicName: clinicName ?? this.clinicName,
    doctorName: doctorName ?? this.doctorName,
    specialty: specialty ?? this.specialty,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    defaultFee: defaultFee ?? this.defaultFee,
    visitDuration: visitDuration ?? this.visitDuration,
    footerNote: footerNote ?? this.footerNote,
  );
}
