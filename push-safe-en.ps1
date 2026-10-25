# =============================================================
#  push-safe-en.ps1   (ASCII-only fallback - works on ALL PowerShell versions)
#  Push Flutter project E:\projects\smart-clinic
#  to  https://github.com/khaledction/smart-clinic  (private + empty)
#
#  Run:  powershell -ExecutionPolicy Bypass -File .\push-safe-en.ps1
# =============================================================

$ErrorActionPreference = "Continue"

$ProjectPath = "E:\projects\smart-clinic"
$RepoUrl     = "https://github.com/khaledction/smart-clinic.git"
$Branch      = "main"

function Ok   ($m) { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Info ($m) { Write-Host "  [INFO] $m" -ForegroundColor Cyan }
function Warn ($m) { Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Err  ($m) { Write-Host "  [ERR]  $m" -ForegroundColor Red }
function Step ($n, $m) { Write-Host ""; Write-Host "--- ($n/9) $m ---" -ForegroundColor Magenta }

Write-Host ""
Write-Host "=============================================================" -ForegroundColor DarkCyan
Write-Host "   Smart Clinic  ->  github.com/khaledction/smart-clinic" -ForegroundColor DarkCyan
Write-Host "   Flutter | HTTPS | private+empty repo" -ForegroundColor DarkCyan
Write-Host "=============================================================" -ForegroundColor DarkCyan

# ---------- 1) Check git ----------
Step 1 "Check Git installation"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Err "Git is not installed. Download: https://git-scm.com/download/win"
    Read-Host "Press Enter to close"; exit 1
}
Ok (git --version)

# ---------- 2) Check project folder ----------
Step 2 "Check project folder"
if (-not (Test-Path $ProjectPath)) {
    Err "Folder not found: $ProjectPath"
    $alt = Read-Host "Enter correct path (or blank to cancel)"
    if (-not $alt) { Read-Host "Press Enter to close"; exit 1 }
    $ProjectPath = $alt
}
Set-Location $ProjectPath
Ok "Working directory: $ProjectPath"

if (-not (Test-Path "pubspec.yaml")) {
    Warn "pubspec.yaml not found - this may not be a Flutter project."
    $c = Read-Host "Continue anyway? (y/n)"
    if ($c -ne "y") { Read-Host "Press Enter to close"; exit 1 }
} else {
    Ok "pubspec.yaml found (Flutter project)"
}

# ---------- 3) Identity ----------
Step 3 "Check Git identity"
$uName = git config --global user.name
$uMail = git config --global user.email
if (-not $uName -or -not $uMail) {
    Warn "Git identity not configured."
    $uName = Read-Host "Your Git username (e.g. khaledction)"
    $uMail = Read-Host "Your GitHub email"
    git config --global user.name  "$uName"
    git config --global user.email "$uMail"
    Ok "Identity saved"
} else {
    Ok "user.name  = $uName"
    Ok "user.email = $uMail"
}

# ---------- 4) .gitignore for Flutter ----------
Step 4 "Set up .gitignore"
if (-not (Test-Path ".gitignore")) {
    $rules = @'
# ===== Flutter / Dart =====
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
*.iml
*.ipr
*.iws
.idea/
.vscode/
*.class
*.log
*.pyc
*.swp
.DS_Store
.atom/
.buildlog/
.history/
.svn/
migrate_working_dir/

# ===== Android =====
android/.gradle/
android/local.properties
android/key.properties
android/app/debug
android/app/profile
android/app/release
android/build/
android/app/build/
android/.idea/
android/captures/
android/gradle/
*.jks
*.keystore
!android/app/debug.keystore

# ===== iOS / macOS =====
ios/Pods/
ios/.symlinks/
ios/Flutter/flutter_export_environment.sh
ios/Flutter/Generated.xcconfig
ios/Runner/GeneratedPluginRegistrant.*
ios/*.xcworkspace/xcuserdata/
ios/*.xcodeproj/xcuserdata/
macos/Pods/
macos/Flutter/GeneratedPluginRegistrant.*

# ===== Windows / Linux / Web =====
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugins.cmake
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugins.cmake

# ===== Secrets =====
.env
.env.*
secrets.dart
**/secrets.dart
**/api_keys.dart
**/keys.dart
*.jks
*.p12
*.pem
google-services.json
GoogleService-Info.plist
'@
    $rules | Out-File -FilePath ".gitignore" -Encoding ascii
    Ok "Created Flutter .gitignore"
} else {
    Ok ".gitignore already exists"
    $gi = Get-Content ".gitignore" -Raw
    if ($gi -notmatch "\.dart_tool") {
        Warn "Existing .gitignore may not cover Flutter files."
    }
}

# ---------- 5) Secret scan ----------
Step 5 "Scanning for hardcoded secrets"
$patterns = @("AIza[0-9A-Za-z_-]{35}", "sk-[A-Za-z0-9]{32,}", "ghp_[A-Za-z0-9]{36}", "github_pat_[A-Za-z0-9_]{50,}", "AKIA[0-9A-Z]{16}")
$hits = @()
foreach ($p in $patterns) {
    $found = Get-ChildItem -Recurse -File -Include *.dart,*.json,*.yaml,*.properties,*.gradle -ErrorAction SilentlyContinue |
             Select-String -Pattern $p -List -ErrorAction SilentlyContinue
    foreach ($f in $found) { $hits += "$($f.Path):$($f.LineNumber)" }
}
if ($hits.Count -gt 0) {
    Warn "Possible secrets detected in:"
    $hits | Select-Object -First 10 | ForEach-Object { Write-Host "       $_" -ForegroundColor Red }
    $c = Read-Host "Continue anyway? (y/n)"
    if ($c -ne "y") {
        Write-Host "       Move them to .env or --dart-define, then retry." -ForegroundColor Yellow
        Read-Host "Press Enter to close"; exit 1
    }
} else {
    Ok "No obvious secrets found"
}

# ---------- 6) git init ----------
Step 6 "Initialize local repository"
if (-not (Test-Path ".git")) {
    git init | Out-Null
    Ok "git init done"
} else {
    Ok "Repository already initialized"
}
git branch -M $Branch | Out-Null
Ok "Branch: $Branch"

# ---------- 7) Remote ----------
Step 7 "Configure remote"
$remote = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0 -or -not $remote) {
    git remote add origin $RepoUrl
    Ok "Added origin -> $RepoUrl"
} elseif ($remote -ne $RepoUrl) {
    git remote set-url origin $RepoUrl
    Ok "Fixed origin -> $RepoUrl"
} else {
    Ok "origin already set: $RepoUrl"
}

# ---------- 8) Commit ----------
Step 8 "Stage and commit"
git add -A
$staged = git diff --cached --name-only
if (-not $staged) {
    Warn "No new files staged (maybe already pushed)."
    $c = Read-Host "Continue and push anyway? (y/n)"
    if ($c -ne "y") { Read-Host "Press Enter to close"; exit 1 }
} else {
    $count = ($staged | Measure-Object).Count
    Ok "Staged $count file(s)"
    Write-Host "       Sample:" -ForegroundColor DarkGray
    $staged | Select-Object -First 10 | ForEach-Object { Write-Host "         - $_" -ForegroundColor DarkGray }
    if ($count -gt 10) { Write-Host "         ... and $($count - 10) more" -ForegroundColor DarkGray }
}

git rev-parse --verify HEAD 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    git commit -q -m "feat: initial commit - Smart Clinic Flutter app"
    Ok "Created initial commit"
} else {
    git commit -q -m "chore: update Smart Clinic project" 2>$null
    Ok "Created commit"
}

# ---------- 9) Push ----------
Step 9 "Push to GitHub"
Write-Host ""
Info "Pushing... (authentication handled by Git Credential Manager)"
git push -u origin $Branch

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Green
    Write-Host "     PUSHED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "     https://github.com/khaledction/smart-clinic" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Err "Push failed."
    Write-Host ""
    Write-Host "  Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1) Make sure repo 'smart-clinic' exists under khaledction" -ForegroundColor Yellow
    Write-Host "   2) Run:  git credential-manager github login" -ForegroundColor Yellow
    Write-Host "   3) Then: git push -u origin main" -ForegroundColor Yellow
    Write-Host "   4) If remote has files:" -ForegroundColor Yellow
    Write-Host "      git pull origin main --rebase --allow-unrelated-histories" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "Press Enter to close"
