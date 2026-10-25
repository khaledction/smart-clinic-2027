; =============================================================================
;  Inno Setup 7 Script — برنامج Smart Clinic لإدارة العيادات الطبية
;  فريق التطوير: Loraneem Tech © 2026
;  مسار المشروع: C:\smart-clinic
; =============================================================================

#define MyAppName "برنامج Smart Clinic لإدارة العيادات الطبية"
#define MyAppEnglishName "Smart Clinic Manager"
#define MyAppVersion "2.0"
#define MyAppPublisher "Loraneem Tech"
#define MyAppURL "https://loraneemtech.com"

; تحديد مسار مجلد المخرجات التنفيذية لفلاتر
#if DirExists("C:\smart-clinic\build\windows\x64\runner\Release")
  #define SourceFolder "C:\smart-clinic\build\windows\x64\runner\Release"
#elif DirExists("C:\smart-clinic\build\windows\runner\Release")
  #define SourceFolder "C:\smart-clinic\build\windows\runner\Release"
#elif DirExists("build\windows\x64\runner\Release")
  #define SourceFolder "build\windows\x64\runner\Release"
#elif DirExists("build\windows\runner\Release")
  #define SourceFolder "build\windows\runner\Release"
#else
  #define SourceFolder "C:\smart-clinic\build\windows\x64\runner\Release"
#endif

; تحديد اسم الملف التنفيذي تلقائياً
#if FileExists(SourceFolder + "\Smart-Clinic.exe")
  #define ExeFileName "Smart-Clinic.exe"
#elif FileExists(SourceFolder + "\DA-Clinic.exe")
  #define ExeFileName "DA-Clinic.exe"
#elif FileExists(SourceFolder + "\neuro_clinic.exe")
  #define ExeFileName "neuro_clinic.exe"
#else
  #define ExeFileName "Smart-Clinic.exe"
#endif

[Setup]
AppId={{D41C89F3-7B8A-42CE-91E2-A5E81C09DA26}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; مسار التثبيت الافتراضي على أجهزة ويندوز
DefaultDirName={autopf}\Smart Clinic
DefaultGroupName=برنامج Smart Clinic لإدارة العيادات
AllowNoIcons=yes

; ملف التثبيت المخرَج ومكانه
OutputDir=Output
OutputBaseFilename=Smart_Clinic_Setup_v{#MyAppVersion}

#if FileExists("C:\smart-clinic\app_icon.ico")
SetupIconFile=C:\smart-clinic\app_icon.ico
#elif FileExists("app_icon.ico")
SetupIconFile=app_icon.ico
#endif

UninstallDisplayIcon={app}\{#ExeFileName}

; الضغط والمعمارية (64-bit فائق السرعة)
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; المظهر العصري
WizardStyle=modern
DisableWelcomePage=no
DisableProgramGroupPage=yes

[Languages]
Name: "default"; MessagesFile: "compiler:Default.isl"

[Messages]
SetupWindowTitle=تثبيت - %1
ButtonBack=< &السابق
ButtonNext=&التالي >
ButtonInstall=&تثبيت
ButtonOK=موافق
ButtonCancel=إلغاء الأمر
ButtonClose=&إغلاق
SelectDirBrowseLabel=للمتابعة انقر «التالي». إذا كنت ترغب في اختيار مجلد مختلف، انقر «استعراض».
SelectDirLabel3=سيقوم برنامج الإعداد بتثبيت [name] في المجلد التالي:
ReadyLabel1=برنامج الإعداد جاهز الآن لبدء تثبيت [name] على جهاز الكمبيوتر الخاص بك.
FinishedHeadingLabel=اكتمل تثبيت [name] بنجاح
FinishedLabel=تم تثبيت [name] بنجاح على جهاز الكمبيوتر الخاص بك. تم إنشاء اختصار سطح المكتب.
ClickFinish=انقر فوق «إنهاء» للخروج من برنامج الإعداد.
LaunchProgram=تشغيل برنامج %1
CreateDesktopIcon=إنشاء أيقونة على &سطح المكتب
StatusInstalling=جاري تثبيت ملفات البرنامج...
StatusExtractingFiles=جاري استخراج الملفات...

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "أيقونات إضافية:"; Flags: unchecked

[Dirs]
Name: "D:\myclinic"; Permissions: admins-full users-modify authusers-modify; Flags: uninsneveruninstall
Name: "D:\myclinic\backups"; Permissions: admins-full users-modify authusers-modify; Flags: uninsneveruninstall
Name: "D:\myclinic\attachments"; Permissions: admins-full users-modify authusers-modify; Flags: uninsneveruninstall
Name: "C:\myclinic"; Permissions: admins-full users-modify authusers-modify; Flags: uninsneveruninstall
Name: "C:\myclinic\backups"; Permissions: admins-full users-modify authusers-modify; Flags: uninsneveruninstall
Name: "C:\myclinic\attachments"; Permissions: admins-full users-modify authusers-modify; Flags: uninsneveruninstall

[Files]
Source: "{#SourceFolder}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#if FileExists("C:\smart-clinic\app_icon.ico")
Source: "C:\smart-clinic\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion
#elif FileExists("app_icon.ico")
Source: "app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion
#endif

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#ExeFileName}"
Name: "{group}\إلغاء تثبيت برنامج Smart Clinic"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#ExeFileName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#ExeFileName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  AppPath: String;
begin
  if CurStep = ssPostInstall then
  begin
    AppPath := ExpandConstant('{app}');
    
    // ضمان توفر Smart-Clinic.exe إن كان اسم الملف الخارج مختلفاً
    if FileExists(AppPath + '\neuro_clinic.exe') and not FileExists(AppPath + '\Smart-Clinic.exe') then
    begin
      FileCopy(AppPath + '\neuro_clinic.exe', AppPath + '\Smart-Clinic.exe', False);
    end;
    if FileExists(AppPath + '\DA-Clinic.exe') and not FileExists(AppPath + '\Smart-Clinic.exe') then
    begin
      FileCopy(AppPath + '\DA-Clinic.exe', AppPath + '\Smart-Clinic.exe', False);
    end;

    // تجهيز مجلدات قاعدة البيانات الطبية وحمايتها
    if DirExists('D:\') then
    begin
      ForceDirectories('D:\myclinic');
      ForceDirectories('D:\myclinic\backups');
      ForceDirectories('D:\myclinic\attachments');
    end
    else
    begin
      ForceDirectories('C:\myclinic');
      ForceDirectories('C:\myclinic\backups');
      ForceDirectories('C:\myclinic\attachments');
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    MsgBox('تم إلغاء تثبيت ملفات برنامج Smart Clinic بنجاح.' + #13#10 + 
           'تنبيه أمان: قاعدة بيانات المرضى في D:\myclinic تم الاحتفاظ بها كاملة لحمايتها من الضياع.', 
           mbInformation, MB_OK);
  end;
end;
