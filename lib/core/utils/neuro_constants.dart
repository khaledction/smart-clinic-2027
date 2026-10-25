// ============================================================================
//  كل القوائم الثابتة في مكان واحد — عدّل هنا لتخصيص التطبيق لتخصصك
//  (هذا الملف هو أكثر ملف ستعدّله عند تحويل القالب إلى تخصص آخر).
// ============================================================================

class NeuroConstants {
  NeuroConstants._();

  static const Map<String, String> visitTypes = {
    'new': 'كشف جديد',
    'followup': 'مراجعة',
    'emergency': 'إسعافية',
    'procedure': 'إجراء',
    'first': 'أول مرة',
    'session': 'جلسة',
  };

  /// نوعا الجلسات المعتمدان حالياً في كل البرنامج.
  /// السجلات القديمة بأسماء أخرى تبقى كما هي ولا تظهر في قوائم الاختيار.
  static const List<String> sessionOptions = ['جلسة EMS', 'جلسة سحب فقرات'];

  /// نوع الموعد.
  static const Map<String, String> appointmentKinds = {
    'checkup': 'معاينة',
    'session': 'جلسة',
  };

  static const List<String> imagingOptions = ['شعاعي', 'طبقي محوري', 'آخر'];

  static const List<String> transferTargets = ['مشفى', 'عيادة', 'مركز طبي'];

  static const List<String> speechOptions = [
    'طبيعية',
    'بصعوبة',
    'مشاكل نطق',
    'آخر',
  ];
  static const List<String> sensationOptions = [
    'طبيعي',
    'ضعيف',
    'متوسط',
    'تجاوب ضعيف',
  ];

  static const Map<String, String> appointmentStatuses = {
    'scheduled': 'مجدول',
    'arrived': 'وصل',
    'done': 'تم',
    'cancelled': 'ملغى',
    'no_show': 'لم يحضر',
  };

  static const Map<String, String> paymentMethods = {
    'cash': 'نقداً',
    'card': 'بطاقة',
    'insurance': 'تأمين',
    'transfer': 'تحويل',
  };

  static const Map<String, String> genders = {'m': 'ذكر', 'f': 'أنثى'};

  static const List<String> bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  /// أنواع الاستقصاءات الشائعة في طب الأعصاب
  static const List<String> investigationKinds = [
    'EEG — تخطيط كهربية الدماغ',
    'EMG — تخطيط كهربية العضل',
    'NCS — دراسة التوصيل العصبي',
    'MRI — رنين مغناطيسي',
    'CT — أشعة مقطعية',
    'MRA/MRV — تصوير الأوعية',
    'Doppler — إيكو دوبلر للسباتي',
    'LP — بزل قطني',
    'تحليل مخبري',
    'أخرى',
  ];

  /// المقاييس العصبية المعيارية — [الاسم, الدرجة العظمى]
  static const Map<String, double> neuroScales = {
    'MMSE — ميني منتال': 30,
    'MoCA — مونتريال المعرفي': 30,
    'NIHSS — السكتة': 42,
    'mRS — رانكين المعدل': 6,
    'EDSS — التصلب المتعدد': 10,
    'UPDRS III — باركنسون': 132,
    'H&Y — هوهن ويار': 5,
    'GAD-7 — القلق': 21,
    'PHQ-9 — الاكتئاب': 27,
    'Barthel — الاستقلال الوظيفي': 100,
  };

  /// تشخيصات عصبية شائعة مع رموز ICD-10 (أضف ما تشاء)
  static const Map<String, String> commonDiagnoses = {
    'G43.9': 'صداع نصفي، غير محدد',
    'G44.2': 'صداع توتري',
    'G40.909': 'صرع، غير محدد',
    'G20': 'مرض باركنسون',
    'G35': 'تصلب متعدد',
    'G45.9': 'نوبة إقفارية عابرة',
    'G62.9': 'اعتلال عصبي محيطي',
    'G56.0': 'متلازمة النفق الرسغي',
    'G50.0': 'ألم العصب ثلاثي التوائم',
    'G51.0': 'شلل بل (Bell palsy)',
    'G30.9': 'داء ألزهايمر',
    'G31.9': 'خرف، غير محدد',
    'G47.00': 'أرق',
    'G93.3': 'إعياء ما بعد الفيروس',
    'M54.5': 'ألم أسفل الظهر',
    'R42': 'دوار وعدم اتزان',
    'R51.9': 'صداع',
    'F03.90': 'تدهور معرفي',
  };

  /// قوالب جاهزة لفحص الأعصاب القحفية (تُدرج تلقائياً في نموذج الفحص)
  static const Map<String, String> cranialNerveLabels = {
    'I': 'الشمي',
    'II': 'البصري — حدة البصر والمجال',
    'III/IV/VI': 'حركة العين والحدقة',
    'V': 'ثلاثي التوائم — الحس والمضغ',
    'VII': 'الوجهي — حركة الوجه',
    'VIII': 'السمعي الدهليزي',
    'IX/X': 'البلعومي والرئوي — البلع والحنك',
    'XI': 'اللاحق — الكتف',
    'XII': 'تحت اللسان — حركة اللسان',
  };

  /// خيارات سريعة لحقول الفحص العصبي (تظهر كقائمة منسدلة)
  static const List<String> quickNormal = ['طبيعي', 'غير طبيعي'];
  static const List<String> motorOptions = [
    '5/5 طبيعي',
    '4/5',
    '3/5',
    '2/5',
    '1/5',
    '0/5',
  ];
  static const List<String> toneOptions = [
    'طبيعي',
    'تشنجي',
    'مرتخٍ',
    'تيبس عجلي',
  ];
  static const List<String> reflexOptions = [
    'طبيعي ++',
    'خفيف +',
    'مفرط +++',
    'غائب',
    'مُكلون',
  ];
  static const List<String> consciousnessOptions = [
    'واعٍ مدرك',
    'واعٍ لكن مشوش',
    'نعاس',
    'ذهول',
    'سبات',
  ];
}
