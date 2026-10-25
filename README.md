<div align="center">

# 🏥 Smart Clinic 2027

**نظام إدارة عيادات طبية — تطبيق سطح مكتب**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D6?style=flat-square&logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![Database](https://img.shields.io/badge/Database-SQLite-003B57?style=flat-square&logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

[العربية](#العربية) · [English](#english) · [دليل المطور 🛡️](#-دليل-المطور--تعديل-آمن-بدون-مشاكل-مسبقة)

</div>

---

<p align="center">
  <img src="assets/images/my%20clinic.png" alt="Smart Clinic — واجهة التطبيق" width="820">
</p>

---

<a name="العربية"></a>

## 🇸🇦 العربية

### 📋 عن المشروع

**Smart Clinic 2027** نظام إدارة متكامل للعيادات الطبية، يعمل على أجهزة سطح المكتب بنظام Windows. صُمّم ليكون **عاماً لأي تخصص طبي** — عيادة عامة، أسنان، أطفال، جلدية، أو أي تخصص آخر — دون الحاجة لتعديل الكود.

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
| **Flutter 3.47.5 (stable)** | بناء واجهة المستخدم |
| **Dart** | لغة البرمجة |
| **sqflite_common_ffi** | قاعدة بيانات SQLite المحلية |
| **window_manager** | إدارة نافذة Windows |
| **provider** | إدارة الحالة |
| **Inno Setup 6+** | إنشاء مثبّت Windows |
| **GitHub Actions** | بناء تلقائي لنسخة Windows |

---

<a name="-دليل-المطور--تعديل-آمن-بدون-مشاكل-مسبقة"></a>

## 🛡️ دليل المطور — تعديل آمن بدون مشاكل مسبقة

> **اقرأ هذا القسم كاملاً قبل أي تعديل. يمنع 90% من الأخطاء الشائعة.**

### 1) المتطلبات الحقيقية (مثبتة من `.metadata`)

المشروع مبني على:
- **Flutter 3.47.5 channel stable** (revision `6a19cca`)
- **Windows 10/11 64-bit**
- **Visual Studio 2022** مع `Desktop development with C++`

```bash
# تأكد قبل أي شيء
flutter --version
flutter doctor -v
# يجب أن ترى Visual Studio + Windows مثبتين بعلامة ✔
```

> ⚠️ لا تحدّث Flutter لنسخة أحدث بدون اختبار كامل `flutter test` + `flutter analyze`. التحديث قد يكسر `window_manager` أو `sqflite_common_ffi`.

### 2) التشغيل لأول مرة (بعد الـ clone)

```bash
git clone https://github.com/khaledction/smart-clinic-2027.git
cd smart-clinic-2027

flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

إذا فشل `flutter pub get`:
```bash
flutter clean
flutter pub get
```

### 3) القاعدة الذهبية قبل أي تعديل

**لا تعدّل أبداً على `main` مباشرة. اعمل فرع:**

```bash
git checkout main
git pull origin main
git checkout -b feat/اسم-الميزة
# ... عدّل ...
git add .
git commit -m "feat: وصف واضح"
git push -u origin feat/اسم-الميزة
```

ثم افتح Pull Request على GitHub. هذا يحميك من ضياع الكود ويسمح بالمراجعة.

**وقبل أي تعديل على قاعدة البيانات:**
```bash
# انسخ قاعدة البيانات الحالية
# تجدها في: D:\myclinic\ أو C:\myclinic\ أو %APPDATA%
# احتفظ بنسخة خارج المشروع
```

### 4) قواعد قاعدة البيانات — الأخطر!

المشروع يستخدم **schema version = 6** (انظر `lib/core/database/app_database.dart`)

- **ممنوع حذف جدول أو عمود مستخدم** — اعمل migration بإضافة عمود nullable أو جدول جديد
- عند أي تغيير في الجداول، ارفع `schemaVersion` +1 واكتب `onUpgrade` يحافظ على البيانات القديمة
- اختبر الترقية: ثبّت النسخة القديمة، أدخل بيانات، ثم ثبّت نسختك الجديدة وتأكد البيانات لم تضيع
- لا تغيّر `lib/main.dart` تهيئة `AppDatabase.initForDesktop()` بدون فهم

```dart
// مثال آمن لإضافة عمود
onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < 7) {
    await db.execute('ALTER TABLE patients ADD COLUMN new_field TEXT');
  }
}
```

### 5) البناء والمثبّت

```bash
# بناء الإصدار
flutter build windows --release
# الناتج: build/windows/x64/runner/Release/

# إنشاء المثبّت (يتطلب Inno Setup)
# افتح Smart_Clinic_Setup.iss في Inno Setup واضغط Build > Compile
# الناتج: Output/Smart_Clinic_Setup_v2.0.exe
```

> ملاحظة: `Smart_Clinic_Setup.iss` يحتوي مسارات fallback متعددة لـ `SourceFolder`. لو بنيت في مسار مختلف عن `E:\projects\...` سيعمل تلقائياً.

### 6) سير العمل اليومي الموصى به

```bash
# بداية اليوم
git checkout main && git pull origin main
git checkout -b fix/اصلاح-كذا

# أثناء العمل - احفظ كل ساعة
git add -A
git commit -m "wip: تقدم في ..."

# قبل الدفع - افحص
flutter analyze   # يجب أن يكون بدون أخطاء
flutter test      # كل الاختبارات خضراء (36 اختبار حالياً)

# ادفع
git push
```

### 7) ما لا ترفعه أبداً إلى GitHub

`.gitignore` الحالي يمنع هذه تلقائياً:

| ممنوع رفعه | السبب |
|---|---|
| `build/` , `.dart_tool/` , `build/windows/` | مخرجات بناء - ضخمة |
| `.env` , `*.jks` , `*.keystore` , `android/key.properties` | مفاتيح سرية |
| `D:\myclinic\*.db` , `*.db` , `backups/` | بيانات مرضى حقيقية |
| `Output/*.exe` , `*.zip` , `*.rar` | ملفات تثبيت - ارفعها كـ Release فقط |
| `android/local.properties` | مسارات محلية |

> **تحذير خصوصية:** مجلدات النسخ الاحتياطي `D:\myclinic\backups` قد تحتوي بيانات مرضى. لا ترفعها أبداً.

### 8) حلول سريعة لأشهر المشاكل

| المشكلة | الحل |
|---|---|
| `flutter run` يعطي خطأ C++ | ثبّت Visual Studio 2022 + Desktop development with C++ وأعد `flutter doctor` |
| `sqflite` خطأ في Windows | تأكد من `sqflite_common_ffi` في `pubspec.yaml` و `AppDatabase.initForDesktop()` يُستدعى أولاً |
| النافذة لا تظهر / بيضاء | احذف `build/` ثم `flutter clean && flutter pub get && flutter run -d windows` |
| تعارض مواعيد لا يُكشف | لا تغيّر منطق `AppointmentRepository` بدون تشغيل `flutter test` |
| المثبّت لا يجد الـ exe | ابنِ أولاً `flutter build windows --release` ثم افتح الـ iss |
| `git push` مرفوض | `git pull --rebase origin main` ثم `git push` |
| قاعدة البيانات اختفت بعد التحديث | راجع PATIENT_FILE_V6.md - المثبّت لا يمس `D:\myclinic` إذا التزمت بـ migration الصحيح |

### 9) الاختبارات قبل كل Push

```bash
flutter analyze   # صفر Issues
flutter test      # 36 passed
flutter build windows --release  # يبني بدون أخطاء
```

إذا كسرت اختباراً، لا تدفع حتى تصلحه.

### 10) الإصدارات والتحديثات التراكمية

- كل تحديث V1..V6 كان **تراكمي** — المثبّت الجديد يقبل بيانات V1-V5
- حافظ على هذا: أي V7 يجب أن يقبل بيانات V6 وما قبلها
- وثّق كل إصدار في `PATIENT_FILE_V6.md` (انسخه إلى `PATIENT_FILE_V7.md` للتحديث القادم) واذكر: ما تغيّر، التوافق، طريقة التثبيت، وطريقة الرجوع

---

### ⚙️ المتطلبات

- **Flutter** 3.47.5 (stable) — نفس نسخة `.metadata`
- **Dart** 3.x
- **Windows** 10 / 11 (64-bit)
- **Visual Studio 2022** مع عبء العمل *Desktop development with C++*

للتحقق:
```bash
flutter doctor -v
```

---

### 🚀 التشغيل السريع

```bash
# 1. استنساخ
git clone https://github.com/khaledction/smart-clinic-2027.git
cd smart-clinic-2027

# 2. تثبيت الحزم
flutter pub get

# 3. تشغيل
flutter run -d windows
```

---

### 📦 بناء نسخة إصدار

```bash
flutter build windows --release
# الناتج: build\windows\x64\runner\Release\
```

لإنشاء المثبّت: افتح `Smart_Clinic_Setup.iss` في **Inno Setup 6** > Compile

---

### 🧪 الاختبارات

```bash
flutter analyze
flutter test
```

---

### 📁 بنية المشروع

```
smart-clinic-2027/
├── lib/
│   ├── core/
│   │   ├── database/          # تهيئة قاعدة البيانات والبيانات الأولية
│   │   ├── services/          # DeviceActivation, AppFolders, AutoBackup
│   │   ├── theme/             # AppTheme
│   │   └── widgets/           # AppShell, WindowControls, FrameTrail
│   ├── data/
│   │   ├── models/            # Patient, Appointment, Visit...
│   │   ├── providers/         # Session, Patients, Appointments, Settings
│   │   └── repositories/      # PatientRepository, AppointmentRepository...
│   ├── features/
│   │   ├── activation/        # شاشة التفعيل
│   │   ├── login/             # تسجيل الدخول
│   │   └── ...                # باقي الشاشات
│   └── main.dart              # نقطة الانطلاق + WindowManager + RTL
├── assets/
│   └── images/                # صور التطبيق
├── test/                      # 36 اختبار
├── windows/                   # إعدادات Windows
├── installer/ / tools/        # أدوات التثبيت
├── Smart_Clinic_Setup.iss     # سكربت Inno Setup
├── PATIENT_FILE_V6.md         # توثيق التحديث الحالي
└── .github/workflows/         # بناء تلقائي Windows
```

---

### 🔒 الخصوصية وأمن البيانات

- جميع البيانات مخزّنة **محلياً** على جهاز العيادة (SQLite في `D:\myclinic` أو `C:\myclinic`)
- **لا يُرسل أي شيء إلى الإنترنت**
- النسخ الاحتياطي التلقائي يعمل عبر `AutoBackup` - لا تعتمد عليه وحده، انسخ يدوياً قبل أي تحديث
- كلمات المرور لا تُعرض في أي واجهة

---

### 🗺 خارطة الطريق

- [x] نظام مواعيد كامل مع كشف التعارض
- [x] زيارات اليوم المنجزة + فرز
- [x] ترويسات موحدة + تجربة RTL كاملة
- [ ] ربط المالية بالزيارات المنجزة
- [ ] نسخ احتياطي تلقائي مجدول
- [ ] تصدير التقارير إلى PDF و Excel
- [ ] تذكير بالمواعيد
- [ ] دعم Android / Web

---

### 🤝 المساهمة

1. Fork للمستودع
2. أنشئ فرعاً: `git checkout -b feat/my-feature`
3. `flutter analyze && flutter test` قبل الـ commit
4. `git push` وافتح Pull Request

راجع [CONTRIBUTING.md](CONTRIBUTING.md) للتفاصيل.

---

### 📄 الترخيص

[MIT License](LICENSE)

---

### 👨‍💻 المطوّر

**khaledction** — [GitHub](https://github.com/khaledction)

للإبلاغ عن مشكلة: [Issues](https://github.com/khaledction/smart-clinic-2027/issues)

---

---

<a name="english"></a>

## 🇬🇧 English

### 📋 About

**Smart Clinic 2027** is a complete clinic management system for Windows desktops, built with Flutter 3.47.5. It is **specialty-agnostic** — suitable for general practice, dental, pediatric, dermatology, or any clinic type — with no code changes required.

It replaces paper records with a single digital solution for patients, appointments, medical records, and billing, with role-based permissions. Runs **entirely offline** on SQLite — patient data never leaves the clinic.

### ✨ Features

- **Patient Management** — CRUD + instant search + archiving
- **Appointments** — daily/weekly view, status chips, conflict detection
- **Medical Records** — chronological visit history, diagnosis & prescriptions
- **Billing** — invoices linked to visits, paid/partial/unpaid, revenue reports
- **Reports** — daily/monthly visits & revenue, peak hours
- **Users & Permissions** — Admin/Doctor/Secretary roles
- **UX** — Full Arabic RTL, color-coded chips, confirmation dialogs, demo data

### 🛠 Tech Stack

| Technology | Purpose |
|---|---|
| Flutter 3.47.5 stable | UI |
| Dart | Language |
| sqflite_common_ffi | Local SQLite |
| window_manager | Window handling |
| provider | State management |
| Inno Setup 6 | Windows installer |
| GitHub Actions | CI |

### 🛡️ Developer Guide — Safe Editing

1. **Never edit `main` directly** — create a feature branch
2. **DB rule:** bump `schemaVersion` and write `onUpgrade` that preserves old data
3. **Before pushing:** `flutter analyze && flutter test && flutter build windows --release`
4. **Never commit:** `build/`, `.dart_tool/`, `*.db`, `*.env`, `Output/*.exe`
5. Back up `D:\myclinic\` before any DB change

See Arabic developer guide above for full details.

### ⚙️ Requirements

- Flutter 3.47.5 stable, Dart 3.x, Windows 10/11 64-bit, Visual Studio 2022 (Desktop C++)

```bash
flutter doctor -v
```

### 🚀 Getting Started

```bash
git clone https://github.com/khaledction/smart-clinic-2027.git
cd smart-clinic-2027
flutter pub get
flutter run -d windows
```

### 📦 Build

```bash
flutter build windows --release
# Output: build\windows\x64\runner\Release\
```

### 🧪 Testing

```bash
flutter analyze
flutter test
```

### 🔒 Privacy

All data stored locally (SQLite). Nothing sent to internet.

### 📄 License

[MIT License](LICENSE)

---

<div align="center">
صُنع بـ ❤️ باستخدام Flutter — جاهز للتطوير الآمن بدون مشاكل مسبقة
</div>
