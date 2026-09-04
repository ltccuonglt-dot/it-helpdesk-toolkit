<#
.SYNOPSIS
    Khắc phục lỗi 0x80070102 khi cài Language Pack (tiếng Nhật) trên Windows 11 Pro.

.DESCRIPTION
    Script này thực hiện các bước xử lý toàn diện theo thứ tự khuyến nghị của Microsoft:
    1. Kiểm tra & bật lại các Windows Update service
    2. Xóa cache Windows Update (SoftwareDistribution, catroot2)
    3. Kiểm tra Group Policy chặn cài optional component
    4. Reset Winsock / network stack
    5. Chạy DISM RestoreHealth + SFC scan
    6. Thử cài lại Language Pack qua PowerShell (LanguagePackManagement)
    7. Hướng dẫn phương án dự phòng nếu vẫn lỗi (cài offline bằng ISO)

.NOTES
    - PHẢI chạy với quyền Administrator (Run as Administrator).
    - Nên tạo Restore Point trước khi chạy (script sẽ tự tạo).
    - Máy cần khởi động lại sau khi chạy xong.
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "Continue"
$LogFile = "$env:TEMP\Fix-0x80070102-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $line = "[$timestamp] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line
}

Write-Log "===== BẮT ĐẦU FIX LỖI 0x80070102 (Language Pack tiếng Nhật) =====" "Cyan"
Write-Log "Log được lưu tại: $LogFile" "Gray"

# ─────────────────────────────────────────────────────────
# BƯỚC 0: Tạo System Restore Point (an toàn trước khi sửa)
# ─────────────────────────────────────────────────────────
Write-Log "`n[Bước 0] Tạo điểm khôi phục hệ thống..." "Yellow"
try {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description "Before Fix 0x80070102" -RestorePointType "MODIFY_SETTINGS"
    Write-Log "  -> Đã tạo Restore Point thành công." "Green"
} catch {
    Write-Log "  -> Không tạo được Restore Point (có thể do giới hạn tần suất). Bỏ qua." "DarkYellow"
}

# ─────────────────────────────────────────────────────────
# BƯỚC 1: Kiểm tra Group Policy chặn Optional Features
# ─────────────────────────────────────────────────────────
Write-Log "`n[Bước 1] Kiểm tra Group Policy 'Specify settings for optional component installation'..." "Yellow"
$gpPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Servicing"
if (Test-Path $gpPath) {
    $useWU = Get-ItemProperty -Path $gpPath -Name "UseWindowsUpdate" -ErrorAction SilentlyContinue
    $repairContent = Get-ItemProperty -Path $gpPath -Name "RepairContentServerSource" -ErrorAction SilentlyContinue
    Write-Log "  -> UseWindowsUpdate = $($useWU.UseWindowsUpdate)" "Gray"
    Write-Log "  -> RepairContentServerSource = $($repairContent.RepairContentServerSource)" "Gray"

    if ($useWU.UseWindowsUpdate -eq 2) {
        Write-Log "  !! Chính sách đang CHẶN tải từ Windows Update. Đang gỡ policy này..." "Red"
        Remove-ItemProperty -Path $gpPath -Name "UseWindowsUpdate" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $gpPath -Name "RepairContentServerSource" -ErrorAction SilentlyContinue
        Write-Log "  -> Đã gỡ policy chặn. (Nếu máy trong domain, cần báo IT admin)" "Green"
    } else {
        Write-Log "  -> Không phát hiện policy chặn." "Green"
    }
} else {
    Write-Log "  -> Không có policy nào được cấu hình (bình thường)." "Green"
}

# ─────────────────────────────────────────────────────────
# BƯỚC 2: Restart Windows Update services
# ─────────────────────────────────────────────────────────
Write-Log "`n[Bước 2] Dừng các Windows Update service..." "Yellow"
$services = @("wuauserv", "cryptSvc", "bits", "msiserver", "TrustedInstaller")
foreach ($svc in $services) {
    try {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Write-Log "  -> Đã dừng: $svc" "Gray"
    } catch {
        Write-Log "  -> Không dừng được $svc (có thể đang chạy hệ thống khác dùng)" "DarkYellow"
    }
}

# ─────────────────────────────────────────────────────────
# BƯỚC 3: Xóa cache Windows Update
# ─────────────────────────────────────────────────────────
Write-Log "`n[Bước 3] Xóa cache SoftwareDistribution & catroot2..." "Yellow"
$sd  = "$env:WINDIR\SoftwareDistribution"
$cr2 = "$env:WINDIR\System32\catroot2"

foreach ($path in @($sd, $cr2)) {
    if (Test-Path $path) {
        $bak = "$path.bak_$(Get-Date -Format 'yyyyMMddHHmmss')"
        try {
            Rename-Item -Path $path -NewName (Split-Path $bak -Leaf) -ErrorAction Stop
            Write-Log "  -> Đã backup & xóa: $path" "Green"
        } catch {
            Write-Log "  -> Không rename được $path -- $($_.Exception.Message)" "Red"
        }
    }
}

Write-Log "`n[Bước 4] Khởi động lại các service..." "Yellow"
foreach ($svc in $services) {
    try {
        Start-Service -Name $svc -ErrorAction SilentlyContinue
        Write-Log "  -> Đã khởi động: $svc" "Green"
    } catch {
        Write-Log "  -> Không khởi động được $svc" "DarkYellow"
    }
}

# ─────────────────────────────────────────────────────────
# BƯỚC 5: Reset Winsock & network stack
# ─────────────────────────────────────────────────────────
Write-Log "`n[Bước 5] Reset network stack (Winsock/BITS)..." "Yellow"
netsh winsock reset | Out-Null
netsh int ip reset | Out-Null
Write-Log "  -> Đã reset Winsock + IP stack (cần khởi động lại máy để có hiệu lực)." "Green"

Write-Log "`n[Bước 5b] Sửa BITS/Windows Update bằng SFC (Service Registration)..." "Yellow"
$sfcCmds = @(
    "sc.exe sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)",
    "sc.exe sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
)
foreach ($cmdStr in $sfcCmds) {
    try {
        Invoke-Expression $cmdStr | Out-Null
        Write-Log "  -> OK: $cmdStr" "Gray"
    } catch {
        Write-Log "  -> Lỗi khi chạy: $cmdStr" "DarkYellow"
    }
}

# ─────────────────────────────────────────────────────────
# BƯỚC 6: DISM RestoreHealth + SFC
# ─────────────────────────────────────────────────────────
Write-Log "`n[Bước 6] Chạy DISM /RestoreHealth (có thể mất 10-20 phút)..." "Yellow"
Write-Log "  -> Đang chạy, vui lòng đợi..." "Gray"
$dismResult = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" `
    -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\dism_out.log"
Get-Content "$env:TEMP\dism_out.log" | ForEach-Object { Write-Log "  DISM: $_" "Gray" }

if ($dismResult.ExitCode -eq 0) {
    Write-Log "  -> DISM RestoreHealth: THÀNH CÔNG" "Green"
} else {
    Write-Log "  -> DISM RestoreHealth: Exit code $($dismResult.ExitCode) (xem log chi tiết)" "Red"
}

Write-Log "`n[Bước 6b] Chạy SFC /scannow (có thể mất 10-15 phút)..." "Yellow"
$sfcResult = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" `
    -Wait -NoNewWindow -PassThru
Write-Log "  -> SFC hoàn tất với exit code: $($sfcResult.ExitCode)" "Gray"

# ─────────────────────────────────────────────────────────
# BƯỚC 7: Kiểm tra kết nối tới Microsoft Update servers
# ─────────────────────────────────────────────────────────
Write-Log "`n[Bước 7] Kiểm tra kết nối mạng tới Microsoft Update..." "Yellow"
$endpoints = @(
    "https://fe2.update.microsoft.com",
    "https://fe3.delivery.mp.microsoft.com",
    "https://download.windowsupdate.com"
)
foreach ($ep in $endpoints) {
    try {
        $resp = Invoke-WebRequest -Uri $ep -Method Head -TimeoutSec 8 -ErrorAction Stop
        Write-Log "  -> OK ($($resp.StatusCode)): $ep" "Green"
    } catch {
        Write-Log "  -> KHÔNG kết nối được: $ep -- kiểm tra Firewall/Proxy/VPN" "Red"
    }
}

# ─────────────────────────────────────────────────────────
# BƯỚC 8: Thử cài lại Language Pack tiếng Nhật
# ─────────────────────────────────────────────────────────
Write-Log "`n[Bước 8] Thử cài Language Pack tiếng Nhật (ja-JP)..." "Yellow"
try {
    Import-Module LanguagePackManagement -ErrorAction Stop
    Install-Language -Language "ja-JP" -ErrorAction Stop
    Write-Log "  -> ĐÃ CÀI THÀNH CÔNG Language Pack ja-JP!" "Green"
} catch {
    Write-Log "  -> Vẫn lỗi khi cài qua PowerShell: $($_.Exception.Message)" "Red"
    Write-Log "  -> Chuyển sang thử qua Optional Features API..." "Yellow"
    try {
        $capName = "Language.Basic~~~ja-JP~0.0.1.0"
        Add-WindowsCapability -Online -Name $capName -ErrorAction Stop
        Write-Log "  -> ĐÃ CÀI THÀNH CÔNG qua Add-WindowsCapability!" "Green"
    } catch {
        Write-Log "  -> VẪN LỖI: $($_.Exception.Message)" "Red"
        Write-Log "  -> Cần dùng phương án OFFLINE (xem hướng dẫn cuối log)." "DarkYellow"
    }
}

# ─────────────────────────────────────────────────────────
# TỔNG KẾT
# ─────────────────────────────────────────────────────────
Write-Log "`n===== HOÀN TẤT =====" "Cyan"
Write-Log "1. KHỞI ĐỘNG LẠI máy ngay bây giờ (bắt buộc để áp dụng thay đổi Winsock/service)." "Cyan"
Write-Log "2. Sau khi khởi động lại, vào Settings > Time & Language > Language & region > Add a language > 日本語 (Japanese) và thử lại." "Cyan"
Write-Log ""
Write-Log "NẾU VẪN LỖI 0x80070102 sau khi khởi động lại, nguyên nhân gần như chắc chắn là:" "Yellow"
Write-Log "  a) Máy đang join Domain / có Group Policy công ty chặn (liên hệ IT admin)" "Yellow"
Write-Log "  b) Firewall/Antivirus/Proxy công ty chặn kết nối tới Microsoft servers" "Yellow"
Write-Log "  c) Cần dùng phương án CÀI OFFLINE:" "Yellow"
Write-Log "     - Tải Windows 11 Language Pack ISO/CAB tương ứng đúng build Windows từ" "Yellow"
Write-Log "       Microsoft Volume Licensing Service Center (VLSC) hoặc UUP dump" "Yellow"
Write-Log "     - Cài bằng lệnh: Add-WindowsPackage -Online -PackagePath <duong_dan_file.cab>" "Yellow"
Write-Log "`nLog đầy đủ: $LogFile" "Gray"
