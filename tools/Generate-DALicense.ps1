<#
.SYNOPSIS
    أداة توليد أكواد ترخيص برنامج Smart Clinic لإدارة العيادات الطبية — Loraneem Tech
.DESCRIPTION
    توليد أكواد التفعيل المحددة المدة حصراً:
    1M (شهرية)، 3M (ثلاث أشهر)، 6M (ستة أشهر)، 9M (تسعة أشهر)، 1Y (سنة)، 2Y (سنتان)
    بالإضافة لكود فك القفل (Unlock Code) عند تجاوز محاولتين غير صحيحتين.
.EXAMPLE
    .\Generate-SmartClinicLicense.ps1 -DeviceId "4A2F8B1C9E3D" -Duration "6M"
    .\Generate-SmartClinicLicense.ps1 -DeviceId "4A2F8B1C9E3D" -Unlock
#>

param (
    [string]$DeviceId = "",
    [string]$Duration = "",
    [switch]$Unlock
)

$Salt = "LORANEEM-TECH-CLINIC-2026"

$Durations = @{
    "1M" = @{ Label = "شهرية"; Days = 30; Desc = "شهر واحد (30 يوماً)" }
    "3M" = @{ Label = "ثلاثة أشهر"; Days = 90; Desc = "3 أشهر (90 يوماً)" }
    "6M" = @{ Label = "ستة أشهر"; Days = 180; Desc = "6 أشهر (180 يوماً)" }
    "9M" = @{ Label = "تسعة أشهر"; Days = 270; Desc = "9 أشهر (270 يوماً)" }
    "1Y" = @{ Label = "سنة"; Days = 365; Desc = "سنة كاملة (365 يوماً)" }
    "2Y" = @{ Label = "سنتان"; Days = 730; Desc = "سنتان كاملتان (730 يوماً)" }
    "LT" = @{ Label = "دائم"; Days = 36500; Desc = "ترخيص دائم مدى الحياة" }
}

function Get-RandomToken([int]$len = 4) {
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $bytes = New-Object byte[] $len
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $res = ""
    foreach ($b in $bytes) {
        $res += $chars[$b % $chars.Length]
    }
    return $res
}

function Compute-Sha256Signature([string]$payload) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $hash = $sha.ComputeHash($bytes)
    $hex = ($hash | ForEach-Object { $_.ToString("X2") }) -join ""
    return $hex.Substring(0, 12)
}

function Generate-Code([string]$dev, [string]$dur) {
    $devClean = ($dev -replace '[^A-Za-z0-9]', '').ToUpper()
    $durUpper = $dur.ToUpper()
    if (-not $Durations.ContainsKey($durUpper)) {
        Write-Error "مدة غير صحيحة: $dur. الخيارات المتاحة: 1M, 3M, 6M, 9M, 1Y, 2Y"
        return
    }
    $token = Get-RandomToken 4
    $payload = "$devClean`:$durUpper`:$token`:$Salt"
    $sig = Compute-Sha256Signature $payload
    $formatted = "DA-$durUpper-$token-" + $sig.Substring(0,4) + "-" + $sig.Substring(4,4) + "-" + $sig.Substring(8,4)
    return [PSCustomObject]@{
        Code = $formatted
        DeviceId = $devClean
        Duration = $Durations[$durUpper].Label
        Days = $Durations[$durUpper].Days
        Token = $token
        Expiry = (Get-Date).AddDays($Durations[$durUpper].Days).ToString("yyyy-MM-dd")
    }
}

function Generate-Unlock([string]$dev) {
    $devClean = ($dev -replace '[^A-Za-z0-9]', '').ToUpper()
    $token = "UN" + (Get-RandomToken 2)
    $payload = "$devClean`:UNLOCK`:$token`:$Salt"
    $sig = Compute-Sha256Signature $payload
    $formatted = "DA-UNLOCK-$token-" + $sig.Substring(0,4) + "-" + $sig.Substring(4,4) + "-" + $sig.Substring(8,4)
    return [PSCustomObject]@{
        UnlockCode = $formatted
        DeviceId = $devClean
        Token = $token
    }
}

if ($Unlock) {
    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        $DeviceId = Read-Host "أدخل رمز الجهاز (12 حرفاً)"
    }
    $res = Generate-Unlock $DeviceId
    Write-Host "`nكود فك القفل:" -ForegroundColor Green
    Write-Host $res.UnlockCode -ForegroundColor Yellow
    return
}

if (-not [string]::IsNullOrWhiteSpace($DeviceId) -and -not [string]::IsNullOrWhiteSpace($Duration)) {
    $res = Generate-Code $DeviceId $Duration
    Write-Host $res.Code
    return
}

# وضع الإدخال التفاعلي
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  أداة توليد أكواد ترخيص Smart Clinic (Windows PowerShell)" -ForegroundColor Cyan
Write-Host "  Loraneem Tech — المدد المعتمدة حصراً" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

while ([string]::IsNullOrWhiteSpace($DeviceId) -or $DeviceId.Length -lt 8) {
    $DeviceId = Read-Host "أدخل رمز الجهاز (12 حرفاً)"
}

Write-Host "`nاختر مدة الترخيص المطلوبة حصراً:"
Write-Host "  1) شهرية (1M - 30 يوماً)"
Write-Host "  2) ثلاث أشهر (3M - 90 يوماً)"
Write-Host "  3) ستة أشهر (6M - 180 يوماً)"
Write-Host "  4) تسعة أشهر (9M - 270 يوماً)"
Write-Host "  5) سنة (1Y - 365 يوماً)"
Write-Host "  6) سنتان (2Y - 730 يوماً)"
Write-Host "  7) كود فك القفل للمحاولات الفاشلة (Unlock)"

$choice = Read-Host "`nرقم الخيار [1-7]"
$map = @{
    "1" = "1M"
    "2" = "3M"
    "3" = "6M"
    "4" = "9M"
    "5" = "1Y"
    "6" = "2Y"
}

if ($choice -eq "7") {
    $un = Generate-Unlock $DeviceId
    Write-Host "`nكود فك القفل:" -ForegroundColor Green
    Write-Host $un.UnlockCode -ForegroundColor Yellow
    return
}

if (-not $map.ContainsKey($choice)) {
    Write-Host "خيار غير صحيح!" -ForegroundColor Red
    return
}

$durChoice = $map[$choice]
$info = Generate-Code $DeviceId $durChoice

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  كود التفعيل: " -NoNewline
Write-Host $info.Code -ForegroundColor Yellow
Write-Host "  المدة:       $($info.Duration)"
Write-Host "  رمز الجهاز:  $($info.DeviceId)"
Write-Host "  انتهاء تقريبي: $($info.Expiry)"
Write-Host "==========================================================" -ForegroundColor Green
