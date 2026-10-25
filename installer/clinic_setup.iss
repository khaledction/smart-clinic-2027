; =====================================================================
;  برنامج التنصيب — برنامج عيادتي الذكي - عيادة د.طارق مقلد
;  يُبنى بـ Inno Setup 6 (مجاني): https://jrsoftware.org/isdl.php
;  الخطوات:
;    1) flutter build windows --no-pub
;    2) افتح هذا الملف في Inno Setup ثم Build > Compile
;       (أو: ISCC.exe installer\clinic_setup.iss)
;    3) يظهر ملف التنصيب MyClinic-Setup.exe على سطح المكتب
;  عند التنصيب:
;    - أيقونة على سطح المكتب + في قائمة ابدأ
;    - يُنشأ المجلد D:\myclinic\backups (وإن لم يوجد القرص D: C:\myclinic\backups)
;    - إلغاء التنصيب لا يحذف مجلد myclinic ولا قاعدة البيانات
; =====================================================================

#define AppName "برنامج عيادتي الذكي - عيادة د.طارق مقلد"
#define AppExe "neuro_clinic.exe"
#define AppVersion "0.1.0"
#define BuildDir "..\build\windows\x64\runner\Release"

; مكتبات Visual C++ التي يحتاجها البرنامج على حاسوب جديد (تُنسخ من حاسوب البناء).
#if DirExists(GetEnv("windir") + "\Sysnative")
  #define SysDir GetEnv("windir") + "\Sysnative"
#else
  #define SysDir GetEnv("windir") + "\System32"
#endif

[Setup]
AppId={{8C1B6F3E-4A7D-4C2B-9E51-2F7A9D3C6B10}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Loraneem Tech - 0933713023
DefaultDirName={autopf}\MyClinic
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir={#GetEnv("USERPROFILE")}\Desktop
OutputBaseFilename=MyClinic-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
LicenseFile=license.txt
WizardImageFile=wizard_logo.bmp

[Messages]
FinishedHeadingLabel=loraneem tech : للتواصل المباشر مع فريق التطوير والدعم
FinishedLabel=تم تثبيت البرنامج بنجاح.%n%nخالد جمال أبو فخر - 0933713023%nهادي فيصل البتي - 0930720434%nloraneemtech@gmail.com
FinishedLabelNoIcons=تم تثبيت البرنامج بنجاح.%n%nخالد جمال أبو فخر - 0933713023%nهادي فيصل البتي - 0930720434%nloraneemtech@gmail.com

[Tasks]
; مفعّل تلقائياً (يمكن إلغاء التحديد أثناء التنصيب).
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SysDir}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SysDir}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SysDir}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Dirs]
; مجلد النسخ الاحتياطية — لا يُحذف عند إلغاء التنصيب.
Name: "D:\myclinic"; Check: DriveDExists; Flags: uninsneveruninstall
Name: "D:\myclinic\backups"; Check: DriveDExists; Flags: uninsneveruninstall
Name: "D:\myclinic\backups\daily"; Check: DriveDExists; Flags: uninsneveruninstall
Name: "D:\myclinic\backups\monthly"; Check: DriveDExists; Flags: uninsneveruninstall
Name: "D:\myclinic\backups\manual"; Check: DriveDExists; Flags: uninsneveruninstall
; لا يوجد قرص D ← نفس التسمية على القرص C.
Name: "C:\myclinic"; Check: not DriveDExists; Flags: uninsneveruninstall
Name: "C:\myclinic\backups"; Check: not DriveDExists; Flags: uninsneveruninstall
Name: "C:\myclinic\backups\daily"; Check: not DriveDExists; Flags: uninsneveruninstall
Name: "C:\myclinic\backups\monthly"; Check: not DriveDExists; Flags: uninsneveruninstall
Name: "C:\myclinic\backups\manual"; Check: not DriveDExists; Flags: uninsneveruninstall

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,MyClinic}"; Flags: nowait postinstall skipifsilent

[Code]
var
  InfoText, SumText: String;

function DriveDExists(): Boolean;
begin
  Result := DirExists('D:\');
end;

procedure InitializeWizard;
begin
  InfoText := 'معلومات البرنامج'#13#10 +
    ''#13#10 +
    'برنامج عيادتي الذكي'#13#10 +
    'عيادة الدكتور طارق نجم مقلد — اختصاصي جراحة عصبية ومجهرية'#13#10 +
    'نسخة 0.1.0 — بيئة التشغيل: Windows'#13#10 +
    ''#13#10 +
    'الميزات الرئيسية:'#13#10 +
    '• تخزين آمن لبيانات المرضى مع وصول سريع.'#13#10 +
    '• حجز المواعيد وتعديلها وإلغاؤها.'#13#10 +
    '• مسار زمني كامل لكل مريض: الفحوصات، التشخيصات، الوصفات.'#13#10 +
    '• توثيق الأدوية والأمراض السابقة.'#13#10 +
    '• بحث متقدم وسريع مع إتمام تلقائي.'#13#10 +
    '• إدارة كاملة للإيرادات حسب النوع والتاريخ.'#13#10 +
    '• نسخ احتياطي تلقائي ويدوي، واسترجاع النسخ السابقة.'#13#10 +
    '• حفظ صور الأشعة والفحوصات ضمن ملف المريض.'#13#10 +
    '• تصدير الملفات والتقارير إلى ملفات CSV (تفتح مباشرة في Excel).';
  SumText := 'برنامج عيادتي الذكي'#13#10 +
    ''#13#10 +
    'عيادة الدكتور طارق نجم مقلد — اختصاصي جراحة عصبية ومجهرية'#13#10 +
    'نسخة 0.1.0 — بيئة التشغيل: Windows'#13#10 +
    ''#13#10 +
    'ملخص عام'#13#10 +
    ''#13#10 +
    'برنامج عصري لإدارة العيادات، مُعدّ خصيصاً لعيادتك، يعمل على حاسوب Windows'#13#10 +
    'ودون الحاجة إلى اتصال بالإنترنت. هدفه تنظيم كامل لبيانات المرضى والمواعيد'#13#10 +
    'والوصفات والإيرادات في مكان واحد، بحيث يتحول العمل اليومي إلى خطوات'#13#10 +
    'بسيطة وسريعة.';
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    MsgBox(InfoText, mbInformation, MB_OK);
    MsgBox(SumText, mbInformation, MB_OK);
  end;
end;
