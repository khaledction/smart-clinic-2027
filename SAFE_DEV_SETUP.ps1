# Smart Clinic 2027 - إعداد بيئة تطوير آمنة
# شغّل هذا مرة واحدة بعد الـ clone

Set-Location -Path $PSScriptRoot

Write-Host "=== فحص Flutter ===" -ForegroundColor Cyan
flutter --version
flutter doctor -v

Write-Host "`n=== تثبيت الحزم ===" -ForegroundColor Cyan
flutter pub get

Write-Host "`n=== فحص الكود ===" -ForegroundColor Cyan
flutter analyze

Write-Host "`n=== تشغيل الاختبارات ===" -ForegroundColor Cyan
flutter test

Write-Host "`n=== إنشاء .gitattributes و CONTRIBUTING إن لم تكن موجودة ===" -ForegroundColor Cyan
if (-not (Test-Path ".gitattributes")) { Write-Host "⚠️ انسخ .gitattributes من المستودع" -ForegroundColor Yellow }
if (-not (Test-Path "CONTRIBUTING.md")) { Write-Host "⚠️ انسخ CONTRIBUTING.md من المستودع" -ForegroundColor Yellow }

Write-Host "`n✅ جاهز! شغّل: flutter run -d windows" -ForegroundColor Green
Write-Host "💡 تذكر: لا تعدّل على main مباشرة - اعمل فرع: git checkout -b feat/ميزتي" -ForegroundColor Yellow
