<div align="center">

# 🏥 Smart Clinic

**نظام إدارة عيادات طبية — تطبيق سطح مكتب**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D6?style=flat-square&logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![Database](https://img.shields.io/badge/Database-SQLite-003B57?style=flat-square&logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

[العربية](#العربية) · [English](#english)

</div>

---

<p align="center">
  <img src="assets/images/my%20clinic.png" alt="Smart Clinic — واجهة التطبيق" width="820">
</p>

---

<a name="العربية"></a>

## 🇸🇦 العربية

### 📋 عن المشروع

**Smart Clinic** نظام إدارة متكامل للعيادات الطبية، يعمل على أجهزة سطح المكتب بنظام Windows. صُمّم ليكون **عاماً لأي تخصص طبي** — عيادة عامة، أسنان، أطفال، جلدية، أو أي تخصص آخر — دون الحاجة لتعديل الكود.

يهدف النظام إلى استبدال الدفاتر الورقية والملفات المتفرقة بحل رقمي واحد ينظّم بيانات المرضى والمواعيد والسجلات الطبية والفواتير، مع نظام صلاحيات يحدّد ما يمكن لكل مستخدم رؤيته أو تعديله.

يعمل التطبيق **محلياً بالكامل** (قاعدة بيانات SQLite على جهازك)، أي أن بيانات المرضى تبقى داخل العيادة ولا تُرسل إلى أي خدمة خارجية.

---

### ✨ المميزات

#### 👥 إدارة المرضى
- إضافة وتعديل وحذف بيانات المرضى
- بحث فوري بالاسم أو رقم الهاتف أو رقم الملف
- ملف شامل لكل مريض: البيانات الشخصية، التاريخ المرضي، الحساسية
- أرشفة المريض بدلاً من حذفه نهائياً

#### 📅 المواعيد
- جدولة المواعيد وتقويم يومي/أسبوعي
- حالات مرئية لكل موعد: **قادم · قيد الفحص · مكتمل · ملغي**
- كشف تعارض المواعيد قبل الحفظ
- عرض مواعيد اليوم كشاشة البداية

#### 🩺 السجل الطبي
- سجل زيارات كامل لكل مريض مرتباً زمنياً
- تسجيل التشخيص والملاحظات والوصفة لكل زيارة
- مراجعة التاريخ المرضي قبل بدء الفحص
- متابعة حالة المريض عبر الزيارات

#### 💰 الفواتير والمدفوعات
- إنشاء فاتورة مرتبطة بالزيارة
- حالات الدفع: **مدفوع · مدفوع جزئياً · غير مدفوع**
- حساب الإيرادات اليومية والشهرية
- طباعة الفاتورة

#### 📊 التقارير والإحصائيات
- تقرير يومي وشهري بعدد الزيارات والإيرادات
- أكثر أيام/ساعات العمل ازدحاماً
- إحصائيات عامة عن نشاط العيادة

#### 🔐 المستخدمون والصلاحيات
- تسجيل دخول محمي بكلمة مرور
- أدوار متعددة: **مدير · طبيب · سكرتير**
- صلاحيات مخصصة لكل دور (من يرى الفواتير؟ من يعدّل السجل الطبي؟)
- إدارة حسابات المستخدمين

#### 🎨 تجربة استخدام
- واجهة عربية كاملة بدعم RTL
- مؤشرات حالة ملوّنة وحالات فارغة واضحة
- نوافذ تأكيد قبل العمليات الحساسة (حذف، إلغاء)
- بيانات تجريبية جاهزة للتجربة الفورية

---

### 🛠 التقنيات المستخدمة

| التقنية | الاستخدام |
|---|---|
| **Flutter** | بناء واجهة المستخدم |
| **Dart** | لغة البرمجة |
| **sqflite / sqflite_common_ffi** | قاعدة بيانات SQLite المحلية |
| **path_provider / path** | تحديد مسارات قاعدة البيانات |
| **GitHub Actions** | بناء تلقائي لنسخة Windows |

---

### ⚙️ المتطلبات

- **Flutter** 3.x أو أحدث
- **Dart** 3.x أو أحدث
- **Windows** 10 / 11 (64-bit)
- **Visual Studio 2022** مع عبء العمل *Desktop development with C++* (للبناء والتشغيل على Windows)

للتحقق من بيئتك:
```bash
flutter doctor -v
```

---

### 🚀 التشغيل

```bash
# 1. استنساخ المستودع
git clone https://github.com/khaledction/smart-clinic.git
cd smart-clinic

# 2. تثبيت الحزم
flutter pub get

# 3. تشغيل التطبيق
flutter run -d windows
```

---

### 📦 بناء نسخة إصدار (Release)

```bash
flutter build windows --release
```

الملف التنفيذي الناتج:
```
build\windows\x64\runner\Release\
```

---

### 🧪 الاختبارات

```bash
flutter test
```

---

### 📁 بنية المشروع

```
smart-clinic/
├── lib/
│   ├── core/
│   │   ├── database/          # تهيئة قاعدة البيانات والبيانات الأولية
│   │   └── widgets/           # مكونات واجهة مشتركة (حالات، نوافذ تأكيد)
│   ├── data/
│   │   ├── models/            # نماذج البيانات (مريض، مستخدم، موعد...)
│   │   └── repositories/      # طبقة الوصول إلى قاعدة البيانات
│   └── ...
├── assets/
│   └── images/                # صور التطبيق
├── test/                      # الاختبارات
├── windows/                   # ملفات منصة Windows
└── .github/workflows/         # البناء التلقائي
```

---

### 🔒 الخصوصية وأمن البيانات

- جميع البيانات مخزّنة **محلياً** على جهاز العيادة (SQLite)
- **لا يُرسل أي شيء إلى الإنترنت**
- يُنصح بنسخ احتياطي دوري لملف قاعدة البيانات
- كلمات المرور لا تُعرض في أي واجهة

---

### 🗺 خارطة الطريق

- [ ] نسخ احتياطي تلقائي لقاعدة البيانات
- [ ] تذكير بالمواعيد قبل موعدها
- [ ] تصدير التقارير إلى PDF و Excel
- [ ] طباعة السجل الطبي
- [ ] دعم منصات إضافية (Android · Web)
- [ ] إدارة أكثر من عيادة في نفس النظام

---

### 🤝 المساهمة

المساهمات مرحّب بها:

1. اعمل Fork للمستودع
2. أنشئ فرعاً: `git checkout -b feature/new-feature`
3. نفّذ تغييراتك واعمل commit
4. ارفع: `git push origin feature/new-feature`
5. افتح Pull Request

---

### 📄 الترخيص

هذا المشروع مرخّص بموجب [MIT License](LICENSE).

---

### 👨‍💻 المطوّر

**khaledction** — [GitHub](https://github.com/khaledction)

للإبلاغ عن مشكلة أو اقتراح ميزة: [Issues](https://github.com/khaledction/smart-clinic/issues)

---
---

<a name="english"></a>

## 🇬🇧 English

### 📋 About

**Smart Clinic** is a complete clinic management system for Windows desktops, built with Flutter. It is designed to be **specialty-agnostic** — suitable for general practice, dental, pediatric, dermatology, or any other clinic type — with no code changes required.

It replaces paper records and scattered files with a single digital solution that organizes patient data, appointments, medical records, and billing, with a role-based permission system controlling what each user can see or modify.

The app runs **entirely offline** on a local SQLite database, so patient data never leaves the clinic.

---

### ✨ Features

#### 👥 Patient Management
- Add, edit, and archive patient records
- Instant search by name, phone, or file number
- Full patient profile: personal data, medical history, allergies

#### 📅 Appointments
- Daily / weekly scheduling
- Visual status per appointment: **Upcoming · In Progress · Completed · Cancelled**
- Conflict detection before saving
- Today's appointments on the home screen

#### 🩺 Medical Records
- Complete visit history per patient, sorted chronologically
- Diagnosis, notes, and prescription per visit
- Review history before starting an examination

#### 💰 Billing & Payments
- Invoices linked to visits
- Payment status: **Paid · Partially Paid · Unpaid**
- Daily and monthly revenue calculation
- Invoice printing

#### 📊 Reports & Statistics
- Daily and monthly visit / revenue reports
- Peak hours and busiest days
- Overall clinic activity statistics

#### 🔐 Users & Permissions
- Password-protected login
- Multiple roles: **Admin · Doctor · Secretary**
- Per-role permissions
- User account management

#### 🎨 User Experience
- Full Arabic interface with RTL support
- Colour-coded status chips and clear empty states
- Confirmation dialogs before destructive actions
- Ready-to-use demo data

---

### 🛠 Tech Stack

| Technology | Purpose |
|---|---|
| **Flutter** | UI framework |
| **Dart** | Programming language |
| **sqflite / sqflite_common_ffi** | Local SQLite database |
| **path_provider / path** | Database path resolution |
| **GitHub Actions** | Automated Windows build |

---

### ⚙️ Requirements

- **Flutter** 3.x or later
- **Dart** 3.x or later
- **Windows** 10 / 11 (64-bit)
- **Visual Studio 2022** with the *Desktop development with C++* workload

Verify your setup with:
```bash
flutter doctor -v
```

---

### 🚀 Getting Started

```bash
# 1. Clone the repository
git clone https://github.com/khaledction/smart-clinic.git
cd smart-clinic

# 2. Install dependencies
flutter pub get

# 3. Run the app
flutter run -d windows
```

---

### 📦 Build a Release

```bash
flutter build windows --release
```

Output:
```
build\windows\x64\runner\Release\
```

---

### 🧪 Testing

```bash
flutter test
```

---

### 📁 Project Structure

```
smart-clinic/
├── lib/
│   ├── core/
│   │   ├── database/          # Database setup and seed data
│   │   └── widgets/           # Shared UI components
│   ├── data/
│   │   ├── models/            # Data models (patient, user, appointment...)
│   │   └── repositories/      # Data access layer
│   └── ...
├── assets/
│   └── images/                # App images
├── test/                      # Tests
├── windows/                   # Windows platform files
└── .github/workflows/         # CI configuration
```

---

### 🔒 Privacy & Security

- All data is stored **locally** on the clinic machine (SQLite)
- **Nothing is transmitted over the internet**
- Regular database backups are recommended
- Passwords are never displayed in the UI

---

### 🗺 Roadmap

- [ ] Automatic database backup
- [ ] Appointment reminders
- [ ] Export reports to PDF and Excel
- [ ] Print medical records
- [ ] Support for additional platforms (Android · Web)
- [ ] Multi-clinic support

---

### 🤝 Contributing

Contributions are welcome:

1. Fork the repository
2. Create a branch: `git checkout -b feature/new-feature`
3. Commit your changes
4. Push: `git push origin feature/new-feature`
5. Open a Pull Request

---

### 📄 License

Released under the [MIT License](LICENSE).

---

### 👨‍💻 Developer

**khaledction** — [GitHub](https://github.com/khaledction)

Report a bug or request a feature: [Issues](https://github.com/khaledction/smart-clinic/issues)

---

<div align="center">
صُنع بـ ❤️ باستخدام Flutter
</div>
