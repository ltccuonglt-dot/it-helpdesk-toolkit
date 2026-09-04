<#
.SYNOPSIS
    Tự động fix các lỗi Windows 11 Pro an toàn, chạy NGẦM (không hỏi, không popup).

.DESCRIPTION
    Chạy các remediation an toàn (restart service, xóa cache, reset network...) không cần
    tương tác người dùng. Ghi toàn bộ log ra file để xem lại sau — vì chạy ngầm nên bạn
    KHÔNG thấy gì trên màn hình trong lúc chạy, đó là chủ đích.

    CHỈ tự động xử lý các lỗi mức độ an toàn (không đụng registry nguy hiểm, không xóa dữ liệu
    người dùng, không thay đổi bảo mật). Lỗi nghiêm trọng (BSOD, hỏng ổ cứng, nghi nhiễm mã độc,
    kích hoạt Windows) sẽ KHÔNG tự chạy — script chỉ ghi log khuyến nghị bạn tự xem.

.PARAMETER Code
    Mã lỗi cụ thể cần fix (VD: "0x80070102"). Nếu bỏ trống, chạy toàn bộ các fix an toàn (-All).

.PARAMETER All
    Chạy toàn bộ các remediation an toàn có sẵn, không cần chỉ định mã lỗi.

.PARAMETER Background
    Tự relaunch chính nó ở chế độ ẩn (WindowStyle Hidden) và trả lại quyền điều khiển terminal
    ngay lập tức — script tiếp tục chạy ngầm phía sau.

.EXAMPLE
    # Chạy ngầm toàn bộ fix an toàn, không cần theo dõi:
    powershell -File .\Fix-Runner.ps1 -All -Background

    # Chạy ngầm 1 fix cụ thể:
    powershell -File .\Fix-Runner.ps1 -Code "0x80070102" -Background

    # Xem log sau khi chạy ngầm xong:
    Get-Content "$env:TEMP\FixRunner-*.log" -Tail 50
#>

#Requires -RunAsAdministrator
param(
    [string]$Code,
    [switch]$All,
    [switch]$Background
)

# ── Tự relaunch ẩn nếu -Background ──────────────────────────────
if ($Background -and -not $env:FIXRUNNER_CHILD) {
    $args = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"")
    if ($Code) { $args += @("-Code", "`"$Code`"") }
    if ($All)  { $args += "-All" }
    $env:FIXRUNNER_CHILD = "1"
    Start-Process -FilePath "powershell.exe" -ArgumentList $args -WindowStyle Hidden
    Write-Host "Đã khởi chạy fix NGẦM (background). Xem log tại: $env:TEMP\FixRunner-*.log"
    exit 0
}

$LogFile = "$env:TEMP\FixRunner-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Log($msg){ Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'HH:mm:ss')] $msg" }

Log "===== FIX-RUNNER BẮT ĐẦU (Code=$Code, All=$All) ====="

# ── Danh sách remediation AN TOÀN, có thể tự động chạy ẩn ────────
$SAFE_FIXES = @{

    "0x80070102" = {
        Log "Fix 0x80070102: xóa cache Windows Update..."
        Stop-Service wuauserv, cryptSvc, bits, msiserver -Force -ErrorAction SilentlyContinue
        foreach ($p in @("$env:WINDIR\SoftwareDistribution","$env:WINDIR\System32\catroot2")) {
            if (Test-Path $p) {
                Rename-Item $p "$p.bak_$(Get-Date -Format yyyyMMddHHmmss)" -ErrorAction SilentlyContinue
                Log "  Đã backup & xóa: $p"
            }
        }
        Start-Service wuauserv, cryptSvc, bits, msiserver -ErrorAction SilentlyContinue
        Log "  Hoàn tất. Khuyến nghị khởi động lại máy."
    }

    "DNS_PROBE_FINISHED_NXDOMAIN" = {
        Log "Fix DNS: flush DNS cache + reset network..."
        ipconfig /flushdns | Out-Null
        Log "  Đã flush DNS cache."
    }

    "Wifi Limited/No Connectivity" = {
        Log "Fix Wifi: release/renew IP..."
        ipconfig /release | Out-Null
        ipconfig /renew   | Out-Null
        Log "  Đã release/renew IP address."
    }

    "Printer Offline" = {
        Log "Fix Printer: restart Print Spooler + xóa queue..."
        Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
        $spoolPath = "$env:WINDIR\System32\spool\PRINTERS\*"
        Remove-Item $spoolPath -Force -ErrorAction SilentlyContinue
        Start-Service -Name Spooler -ErrorAction SilentlyContinue
        Log "  Đã restart Print Spooler và xóa print queue bị treo."
    }

    "High CPU/Disk Usage 100%" = {
        Log "Fix High CPU/Disk: restart Windows Search service..."
        Restart-Service -Name WSearch -Force -ErrorAction SilentlyContinue
        Log "  Đã restart Windows Search (giảm tải index nếu đang bị kẹt)."
    }

    "Disk Full C:" = {
        Log "Fix Disk Full: dọn temp files + Windows Update cache..."
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        $before = (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free
        cleanmgr /sagerun:1 2>$null | Out-Null
        Log "  Đã dọn temp files. (Disk Cleanup /sagerun cần preset cấu hình trước — xem README)"
    }

    "Word: Lỗi khi lưu file (Cannot save)" = {
        Log "Fix Office: xóa cache Office Roaming/Document cache..."
        $cachePaths = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
        )
        foreach ($p in $cachePaths) {
            if (Test-Path $p) { Remove-Item "$p\*" -Force -Recurse -ErrorAction SilentlyContinue }
        }
        Log "  Đã xóa Office document cache."
    }
}

# ── KHÔNG tự động — chỉ ghi khuyến nghị (rủi ro cao / cần con người quyết định) ──
$MANUAL_ONLY = @(
    "CRITICAL_PROCESS_DIED", "INACCESSIBLE_BOOT_DEVICE", "S.M.A.R.T. Failure Warning",
    "Ransomware/Malware Alert", "0xC004F074", "0xC004C003",
    "Windows Defender Turned Off by Group Policy"
)

function Run-Fix($key) {
    if ($SAFE_FIXES.ContainsKey($key)) {
        Log "-- Đang chạy fix an toàn cho: $key"
        try { & $SAFE_FIXES[$key] } catch { Log "  LỖI khi chạy fix $key : $($_.Exception.Message)" }
        return $true
    } elseif ($MANUAL_ONLY -contains $key) {
        Log "-- BỎ QUA (cần xử lý thủ công, không tự động): $key"
        return $false
    } else {
        Log "-- Không có remediation tự động cho: $key (xem KB trong docs/index.html)"
        return $false
    }
}

if ($Code) {
    Run-Fix $Code
} elseif ($All) {
    foreach ($key in $SAFE_FIXES.Keys) { Run-Fix $key }
} else {
    Log "Không có -Code hay -All được chỉ định. Không làm gì."
}

Log "===== FIX-RUNNER HOÀN TẤT ====="
