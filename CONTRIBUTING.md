# المساهمة في Smart Clinic 2027 — دليل آمن

## القاعدة الذهبية
> **لا تدفع مباشرة على `main`. دائماً اعمل فرع جديد.**

## سير العمل

### 1. ابدأ من main نظيف
```bash
git checkout main
git pull origin main
git checkout -b feat/ميزة-جديدة
# أو fix/اصلاح-مشكلة
```

### 2. اعمل commit واضح
```bash
git add .
git commit -m "feat: إضافة تصدير PDF للتقارير"
# أنواع: feat, fix, docs, chore, refactor, test
```

### 3. افحص قبل الدفع
```bash
flutter analyze
flutter test
flutter build windows --release
```
إذا أي أمر فشل، لا تدفع.

### 4. ادفع وافتح PR
```bash
git push -u origin feat/ميزة-جديدة
```
ثم على GitHub: Compare & pull request → اشرح التغيير + صور إن أمكن.

## قواعد قاعدة البيانات
- لا تحذف عمود/جدول مستخدم
- زد `schemaVersion` في `app_database.dart`
- اكتب `onUpgrade` يحافظ على البيانات القديمة
- اختبر: ثبّت نسخة قديمة + أدخل بيانات + ثبّت نسختك = البيانات موجودة؟

## ما لا يُسمح به في PR
- ملفات `build/`, `.dart_tool/`, `*.db`, `Output/*.exe`
- بيانات مرضى حقيقية
- مفاتيح `*.jks`, `.env`
- تعديل `Smart_Clinic_Setup.iss` بدون اختبار المثبّت

## تسمية الفروع
- `feat/xxx` ميزة جديدة
- `fix/xxx` إصلاح
- `docs/xxx` توثيق
- `chore/xxx` صيانة

## مراجعة PR
- كود نظيف ومقروء
- `flutter analyze` بدون تحذيرات
- الاختبارات خضراء
