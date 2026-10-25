@echo off
chcp 65001 >nul
title بناء برنامج Smart Clinic للعيادات وتحديث الشعار عبر Inno Setup 7
color 0B

echo ===============================================================================
echo            Loraneem Tech — بناء برنامج Smart Clinic لإدارة العيادات الطبية
echo ===============================================================================
echo.

:: 1. التحقق من فلاتر
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    color 0C
    echo [خطأ] أمر flutter غير معرّف في متغيرات البيئة PATH!
    echo يرجى التأكد من تثبيت Flutter SDK وإضافته إلى PATH.
    echo.
    pause
    exit /b 1
)

:: 2. تنظيف الكاش القديم تماماً لضمان إزالة اللوغو القديم نهائياً
echo [1/4] تنظيف الكاش القديم وحذف مجلد البناء السابق (flutter clean)...
call flutter clean
if exist "build" (
    echo جاري حذف مجلد build القديم...
    rmdir /s /q "build" 2>nul
)

echo.
echo [2/4] جلب حزم المشروع (flutter pub get)...
call flutter pub get
if %errorlevel% neq 0 (
    color 0C
    echo [خطأ] فشل في جلب حزم المشروع!
    pause
    exit /b 1
)

echo.
echo [3/4] تجميع التطبيق باللوغو الجديد (Smart-Clinic.exe)...
call flutter build windows --release
if %errorlevel% neq 0 (
    color 0C
    echo [خطأ] فشل تجميع نسخة الويندوز!
    echo تأكد من تثبيت "Desktop development with C++" في Visual Studio.
    pause
    exit /b 1
)

echo.
echo [تم بنجاح] تم تجميع ملف Smart-Clinic.exe بالشعار الجديد في:
echo build\windows\x64\runner\Release\
echo.

:: 4. البحث عن Inno Setup وتجميع ملف التثبيت النهائي
echo [4/4] جاري البحث عن Inno Setup Compiler 7 وتجميع ملف التثبيت...

set "ISCC_PATH="

if exist "C:\Program Files\Inno Setup 7\ISCC.exe" (
    set "ISCC_PATH=C:\Program Files\Inno Setup 7\ISCC.exe"
) else if exist "C:\Program Files (x86)\Inno Setup 7\ISCC.exe" (
    set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 7\ISCC.exe"
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"
) else if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
) else (
    where iscc >nul 2>nul
    if %errorlevel% equ 0 (
        set "ISCC_PATH=iscc"
    )
)

if defined ISCC_PATH (
    echo تم العثور على Inno Setup في: "%ISCC_PATH%"
    echo جاري تجميع ملف الإعداد النهائي بالشعار والأيقونة الجديدة...
    if exist "Smart_Clinic_Setup.iss" (
        "%ISCC_PATH%" "Smart_Clinic_Setup.iss"
    ) else if exist "DA_Clinic_Setup.iss" (
        "%ISCC_PATH%" "DA_Clinic_Setup.iss"
    )
    if %errorlevel% equ 0 (
        color 0A
        echo.
        echo ===============================================================================
        echo   تهانينا! تم تجميع برنامج التثبيت بالشعار الجديد بنجاح:
        echo   المجلد: Output\Smart_Clinic_Setup_v2.0.exe
        echo ===============================================================================
        if exist "Output" explorer Output
    ) else (
        color 0E
        echo [تنبيه] حدث خطأ أثناء تجميع Inno Setup. يمكنك فتح ملف Smart_Clinic_Setup.iss والضغط على Ctrl+F9.
    )
) else (
    color 0E
    echo [تنبيه] لم يتم العثور على مسار ISCC.exe تلقائياً.
    echo يمكنك فتح ملف Smart_Clinic_Setup.iss يدوياً في Inno Setup والضغط على Ctrl+F9.
)

echo.
pause
