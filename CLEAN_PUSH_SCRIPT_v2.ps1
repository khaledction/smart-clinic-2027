# Smart Clinic 2027 - تنظيف ورفع للمستودع
Set-Location -Path "E:\projects\final-projects\smart-clinic-2027"

Write-Host "=== بدء تنظيف المشروع ===" -ForegroundColor Cyan

$toDelete = @(
    "node_modules",
    ".next",
    "dist",
    "build",
    "out",
    ".output",
    ".vite",
    ".turbo",
    ".parcel-cache",
    "coverage",
    ".nyc_output",
    "__pycache__",
    ".pytest_cache",
    ".venv",
    "venv",
    ".mypy_cache",
    ".ruff_cache",
    ".cache",
    "logs",
    "npm-debug.log*",
    "yarn-debug.log*",
    "yarn-error.log*",
    ".DS_Store",
    "Thumbs.db"
)

foreach ($item in $toDelete) {
    Get-ChildItem -Path . -Recurse -Force -Include $item -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "حذف: $item" -ForegroundColor Gray
}

# حذف ملفات env المحلية الحساسة فقط - نبقي .env.example
Remove-Item -Force .env.local -ErrorAction SilentlyContinue
Remove-Item -Force .env.development.local -ErrorAction SilentlyContinue
Remove-Item -Force .env.test.local -ErrorAction SilentlyContinue
Remove-Item -Force .env.production.local -ErrorAction SilentlyContinue

if (Test-Path ".git") {
    Remove-Item -Recurse -Force ".git"
    Write-Host "تم حذف .git القديم" -ForegroundColor Yellow
}

Write-Host "=== انتهى التنظيف ===" -ForegroundColor Green

git init
git branch -M main
git add .
git status

Write-Host ""
Write-Host "=== راجع الملفات اعلاه ===" -ForegroundColor Cyan
Write-Host "اذا كل شيء تمام شغل الاوامر التالية:"
Write-Host "git commit -m 'Initial commit: Smart Clinic 2027 - clean version'"
Write-Host "git remote add origin https://github.com/khaledction/smart-clinic-2027.git"
Write-Host "git push -u origin main --force"
