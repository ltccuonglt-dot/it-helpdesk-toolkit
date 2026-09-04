<#
.SYNOPSIS
    Quét lỗi thực tế trên máy Windows 11 Pro và xuất báo cáo JSON
    để nạp vào IT Helpdesk Toolkit (docs/index.html) tự động khớp lỗi + cách fix.

.DESCRIPTION
    Quét các nguồn sau:
    - Event Viewer (System + Application log) lỗi trong N ngày gần nhất
    - Lịch sử lỗi Windows Update
    - Trạng thái kích hoạt Windows (slmgr)
    - Sức khỏe ổ đĩa (S.M.A.R.T / Reliability Counter)
    - Dung lượng ổ đĩa trống
    - Trạng thái Windows Defender

.PARAMETER Days
    Số ngày gần nhất để quét Event Log. Mặc định 7 ngày.

.PARAMETER OutFile
    Đường dẫn file JSON xuất ra. Mặc định: scan-result.json cùng thư mục script.

.EXAMPLE
    .\Scan-System.ps1
    .\Scan-System.ps1 -Days 14 -OutFile C:\temp\scan.json
#>

param(
    [int]$Days = 7,
    [string]$OutFile = "$PSScriptRoot\scan-result.json"
)

Write-Host "===== IT HELPDESK TOOLKIT — QUÉT LỖI HỆ THỐNG =====" -ForegroundColor Cyan
Write-Host "Đang quét $Days ngày gần nhất...`n" -ForegroundColor Gray

$result = [ordered]@{
    scanDate     = (Get-Date).ToString("o")
    computerName = $env:COMPUTERNAME
    osVersion    = (Get-CimInstance Win32_OperatingSystem).Caption
    buildNumber  = (Get-CimInstance Win32_OperatingSystem).BuildNumber
    findings     = @()
}

function Add-Finding {
    param($Code, $Source, $Message, $Detail)
    $result.findings += [ordered]@{
        code    = $Code
        source  = $Source
        message = $Message
        detail  = $Detail
    }
}

# ── 1. Event Viewer — System & Application errors ──────────────
Write-Host "[1/6] Quét Event Viewer (System + Application)..." -ForegroundColor Yellow
$since = (Get-Date).AddDays(-$Days)
try {
    $events = Get-WinEvent -FilterHashtable @{LogName='System','Application'; Level=2; StartTime=$since} -MaxEvents 500 -ErrorAction Stop
    $grouped = $events | Group-Object -Property Id | Sort-Object Count -Descending | Select-Object -First 15
    foreach ($g in $grouped) {
        $sample = $g.Group[0]
        # Try to extract hex error code from message if present
        $hexMatch = [regex]::Match($sample.Message, '0x[0-9A-Fa-f]{8}')
        $code = if ($hexMatch.Success) { $hexMatch.Value } else { "EventID-$($g.Name)" }
        Add-Finding -Code $code -Source "EventLog:$($sample.LogName)" `
            -Message ($sample.Message.Split("`n")[0]) `
            -Detail "Xuất hiện $($g.Count) lần trong $Days ngày qua. Provider: $($sample.ProviderName)"
    }
    Write-Host "  -> Tìm thấy $($events.Count) event lỗi, đã nhóm thành $($grouped.Count) nhóm." -ForegroundColor Green
} catch {
    Write-Host "  -> Không đọc được Event Log: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

# ── 2. Windows Update history — lỗi ────────────────────────────
Write-Host "[2/6] Kiểm tra lịch sử Windows Update..." -ForegroundColor Yellow
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $historyCount = $searcher.GetTotalHistoryCount()
    $history = $searcher.QueryHistory(0, [Math]::Min($historyCount, 50))
    $failedUpdates = $history | Where-Object { $_.ResultCode -eq 4 -or $_.ResultCode -eq 5 }
    foreach ($f in $failedUpdates) {
        $hresult = '0x{0:X8}' -f $f.HResult
        Add-Finding -Code $hresult -Source "WindowsUpdate" `
            -Message $f.Title `
            -Detail "Update thất bại ngày $($f.Date). ResultCode=$($f.ResultCode)"
    }
    Write-Host "  -> $($failedUpdates.Count) update thất bại được ghi nhận." -ForegroundColor Green
} catch {
    Write-Host "  -> Không đọc được lịch sử Windows Update: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

# ── 3. Activation status ────────────────────────────────────────
Write-Host "[3/6] Kiểm tra trạng thái kích hoạt Windows..." -ForegroundColor Yellow
try {
    $license = Get-CimInstance SoftwareLicensingProduct -Filter "Name like 'Windows%' AND PartialProductKey IS NOT NULL"
    foreach ($lic in $license) {
        if ($lic.LicenseStatus -ne 1) {
            $statusMap = @{0="Unlicensed"; 1="Licensed"; 2="OOBGrace"; 3="OOTGrace"; 4="NonGenuineGrace"; 5="Notification"; 6="ExtendedGrace"}
            Add-Finding -Code "ActivationStatus-$($lic.LicenseStatus)" -Source "Activation" `
                -Message "Windows chưa được kích hoạt đầy đủ" `
                -Detail "LicenseStatus: $($statusMap[[int]$lic.LicenseStatus])"
        }
    }
    Write-Host "  -> Đã kiểm tra activation status." -ForegroundColor Green
} catch {
    Write-Host "  -> Không kiểm tra được activation: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

# ── 4. Disk health (S.M.A.R.T / Reliability) ────────────────────
Write-Host "[4/6] Kiểm tra sức khỏe ổ đĩa..." -ForegroundColor Yellow
try {
    $disks = Get-PhysicalDisk -ErrorAction Stop
    foreach ($d in $disks) {
        if ($d.HealthStatus -ne "Healthy") {
            Add-Finding -Code "S.M.A.R.T. Failure Warning" -Source "Storage" `
                -Message "Ổ đĩa $($d.FriendlyName) có tình trạng: $($d.HealthStatus)" `
                -Detail "MediaType: $($d.MediaType), Size: $([math]::Round($d.Size/1GB,1))GB"
        }
    }
    Write-Host "  -> Đã kiểm tra $($disks.Count) ổ đĩa." -ForegroundColor Green
} catch {
    Write-Host "  -> Không đọc được thông tin ổ đĩa: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

# ── 5. Disk space ─────────────────────────────────────────────
Write-Host "[5/6] Kiểm tra dung lượng ổ đĩa..." -ForegroundColor Yellow
try {
    $sysDrive = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))
    $freeGB = [math]::Round($sysDrive.Free / 1GB, 1)
    if ($freeGB -lt 15) {
        Add-Finding -Code "Disk Full C:" -Source "Storage" `
            -Message "Ổ $($env:SystemDrive) chỉ còn $freeGB GB trống" `
            -Detail "Khuyến nghị tối thiểu 15GB trống để Windows Update hoạt động ổn định."
    }
    Write-Host "  -> Ổ hệ thống còn $freeGB GB trống." -ForegroundColor Green
} catch {
    Write-Host "  -> Lỗi kiểm tra dung lượng: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

# ── 6. Windows Defender status ──────────────────────────────────
Write-Host "[6/6] Kiểm tra trạng thái Windows Defender..." -ForegroundColor Yellow
try {
    $defender = Get-MpComputerStatus -ErrorAction Stop
    if (-not $defender.RealTimeProtectionEnabled -and -not $defender.AntivirusEnabled) {
        Add-Finding -Code "Windows Defender Turned Off by Group Policy" -Source "Security" `
            -Message "Windows Defender đang tắt (Real-time protection: OFF)" `
            -Detail "Nếu không có antivirus thứ 3 đang chạy, đây là rủi ro bảo mật."
    }
    Write-Host "  -> Defender RealTimeProtection: $($defender.RealTimeProtectionEnabled)" -ForegroundColor Green
} catch {
    Write-Host "  -> Không đọc được trạng thái Defender: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

# ── Xuất kết quả ──────────────────────────────────────────────
$result.findings = @($result.findings)  # ensure array even if empty/single
$result | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutFile -Encoding utf8

Write-Host "`n===== HOÀN TẤT =====" -ForegroundColor Cyan
Write-Host "Tổng số dấu hiệu lỗi phát hiện: $($result.findings.Count)" -ForegroundColor $(if($result.findings.Count -gt 0){"Yellow"}else{"Green"})
Write-Host "Kết quả đã lưu tại: $OutFile" -ForegroundColor Cyan
Write-Host "`nBước tiếp theo: Mở docs/index.html > nhấn 'Quét lỗi trên máy' > chọn file $OutFile" -ForegroundColor Cyan
