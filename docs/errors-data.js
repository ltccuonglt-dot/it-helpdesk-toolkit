// ============================================================
// Windows 11 Pro Error Knowledge Base
// IT Helpdesk Toolkit — errors database
// Mỗi entry: code, title, category, severity, cause, fix[], refs[]
// ============================================================

const ERROR_CATEGORIES = [
  { id: "update",     label: "Windows Update & OS",   icon: "🔄", color: "#2E75B6" },
  { id: "activation", label: "Kích Hoạt & License",    icon: "🔑", color: "#7952B3" },
  { id: "network",    label: "Mạng & Kết Nối",         icon: "🌐", color: "#0EA5A5" },
  { id: "boot",       label: "Boot / BSOD",            icon: "💥", color: "#C00000" },
  { id: "performance",label: "Hiệu Năng & Hệ Thống",   icon: "⚙️", color: "#FF8C00" },
  { id: "printer",    label: "Máy In & Thiết Bị",      icon: "🖨️", color: "#5B9BD5" },
  { id: "office",     label: "Office & Ứng Dụng",      icon: "📄", color: "#70AD47" },
  { id: "security",   label: "Bảo Mật & Defender",     icon: "🛡️", color: "#C00000" },
  { id: "driver",     label: "Driver & Thiết Bị",      icon: "🔌", color: "#8E44AD" },
  { id: "storage",    label: "Ổ Đĩa & Dữ Liệu",        icon: "💾", color: "#607D8B" },
];

const ERRORS_DB = [
  // ── WINDOWS UPDATE & OS ─────────────────────────────────
  {
    code: "0x80070102", title: "Lỗi cài Language Pack / Optional Feature",
    category: "update", severity: "Cao",
    cause: "Windows Update cache hỏng, Group Policy chặn optional component, hoặc firewall/proxy chặn kết nối tới Microsoft Update servers.",
    fix: [
      "Chạy Settings > Windows Update > Troubleshoot",
      "Dừng service wuauserv, cryptSvc, bits, msiserver rồi xóa %WINDIR%\\SoftwareDistribution và catroot2 (backup trước khi xóa)",
      "Kiểm tra Group Policy: gpedit.msc > Computer Config > Admin Templates > System > Specify settings for optional component installation — set về 'Not Configured'",
      "Chạy DISM /Online /Cleanup-Image /RestoreHealth rồi sfc /scannow",
      "Reset Winsock: netsh winsock reset && netsh int ip reset, sau đó khởi động lại máy",
      "Thử lại: Settings > Time & Language > Language & region > Add a language",
    ],
  },
  {
    code: "0x8007000D", title: "Windows Update báo lỗi file XML/cấu hình hỏng",
    category: "update", severity: "Trung bình",
    cause: "File cấu hình update (INI/XML) bị lỗi định dạng dữ liệu.",
    fix: [
      "Chạy Windows Update Troubleshooter tích hợp",
      "Xóa cache SoftwareDistribution",
      "Chạy DISM /RestoreHealth + SFC /scannow",
      "Cập nhật thủ công qua Microsoft Update Catalog nếu vẫn lỗi",
    ],
  },
  {
    code: "0x80240034", title: "Update Service Handler không hợp lệ / kết nối bị ngắt",
    category: "update", severity: "Trung bình",
    cause: "Ngắt kết nối giữa lúc đang tải update, hoặc BITS service lỗi.",
    fix: [
      "Restart service Windows Update & BITS",
      "Kiểm tra kết nối mạng ổn định",
      "Chạy lại Windows Update sau khi restart service",
    ],
  },
  {
    code: "0x800F0922", title: "Không cài được Update / .NET Framework do thiếu dung lượng hoặc VPN",
    category: "update", severity: "Trung bình",
    cause: "Ổ đĩa hệ thống thiếu dung lượng trống, hoặc VPN/proxy can thiệp vào quá trình cài đặt.",
    fix: [
      "Giải phóng ít nhất 10GB dung lượng ổ C:",
      "Tắt VPN tạm thời trong khi cập nhật",
      "Chạy Disk Cleanup + xóa Windows.old nếu có",
    ],
  },
  {
    code: "0xc1900101", title: "Lỗi khi Upgrade phiên bản Windows (feature update)",
    category: "update", severity: "Cao",
    cause: "Driver không tương thích, thiết bị ngoại vi gây conflict trong quá trình upgrade.",
    fix: [
      "Gỡ các thiết bị ngoại vi không cần thiết (USB, máy in...) trước khi upgrade",
      "Cập nhật driver card đồ họa & chipset lên bản mới nhất",
      "Chạy Windows Update Assistant thay vì upgrade qua Settings",
      "Kiểm tra SetupDiag log để xác định driver gây lỗi cụ thể",
    ],
  },

  // ── ACTIVATION & LICENSE ────────────────────────────────
  {
    code: "0xC004F074", title: "Không kích hoạt được Windows (KMS/Volume License)",
    category: "activation", severity: "Cao",
    cause: "Máy không liên lạc được với KMS server nội bộ, hoặc key volume license hết hạn.",
    fix: [
      "Kiểm tra máy có trong mạng nội bộ / VPN kết nối tới KMS server",
      "Chạy: slmgr /ato để kích hoạt lại",
      "Kiểm tra slmgr /dlv xem trạng thái license hiện tại",
      "Liên hệ IT admin xác nhận KMS server còn hoạt động",
    ],
  },
  {
    code: "0x8007232B", title: "DNS Name Does Not Exist khi kích hoạt",
    category: "activation", severity: "Trung bình",
    cause: "Máy không tìm được KMS server qua DNS SRV record.",
    fix: [
      "Kiểm tra kết nối DNS: nslookup _vlmcs._tcp",
      "Cấu hình KMS server thủ công: slmgr /skms <server>:<port>",
      "Kích hoạt lại: slmgr /ato",
    ],
  },
  {
    code: "0xC004C003", title: "Product key không hợp lệ hoặc đã bị block",
    category: "activation", severity: "Cao",
    cause: "Key bị dùng vượt số lượng cho phép, hoặc key giả/vi phạm license.",
    fix: [
      "Kiểm tra tính hợp lệ key qua Microsoft Volume Licensing Center",
      "Liên hệ bộ phận mua sắm/IT để xác nhận key chính chủ",
      "Không dùng key crack/third-party — vi phạm pháp lý và không ổn định",
    ],
  },

  // ── NETWORK & CONNECTIVITY ──────────────────────────────
  {
    code: "DNS_PROBE_FINISHED_NXDOMAIN", title: "Không truy cập được website / DNS lỗi",
    category: "network", severity: "Trung bình",
    cause: "DNS server không phản hồi hoặc cache DNS bị lỗi.",
    fix: [
      "Chạy: ipconfig /flushdns",
      "Đổi DNS sang 8.8.8.8 / 1.1.1.1 trong Network Adapter settings",
      "Restart router/modem",
      "Chạy Network Troubleshooter trong Settings",
    ],
  },
  {
    code: "0x80070035", title: "The network path was not found (không truy cập share folder)",
    category: "network", severity: "Trung bình",
    cause: "SMB protocol bị tắt, firewall chặn, hoặc share permission sai.",
    fix: [
      "Bật lại SMB: Control Panel > Programs > Turn Windows features on/off > SMB 1.0 (nếu cần cho máy cũ)",
      "Kiểm tra Firewall cho phép File and Printer Sharing",
      "Ping tới IP máy chủ để xác nhận kết nối mạng",
      "Kiểm tra quyền share trên máy chủ (Sharing + NTFS permissions)",
    ],
  },
  {
    code: "Wifi Limited/No Connectivity", title: "Wifi kết nối nhưng không vào mạng được",
    category: "network", severity: "Cao",
    cause: "Driver Wifi lỗi, IP conflict, hoặc router DHCP hết địa chỉ IP.",
    fix: [
      "Chạy: ipconfig /release && ipconfig /renew",
      "Update driver Wifi adapter",
      "Restart router, kiểm tra DHCP pool còn trống",
      "Quên mạng Wifi và kết nối lại từ đầu",
    ],
  },
  {
    code: "VPN Error 809", title: "Không kết nối được VPN công ty",
    category: "network", severity: "Cao",
    cause: "Firewall/NAT chặn port VPN, hoặc thiếu cấu hình GRE/PPTP.",
    fix: [
      "Kiểm tra Windows Firewall không chặn VPN client",
      "Nếu dùng PPTP: bật GRE protocol (port 47) trên router",
      "Thử đổi sang VPN protocol khác (L2TP/IKEv2) nếu công ty hỗ trợ",
      "Restart VPN service: Services > Remote Access Connection Manager",
    ],
  },

  // ── BOOT / BSOD ──────────────────────────────────────────
  {
    code: "CRITICAL_PROCESS_DIED", title: "Màn hình xanh (BSOD) khi khởi động",
    category: "boot", severity: "Nghiêm trọng",
    cause: "File hệ thống bị lỗi/hỏng, driver không tương thích, hoặc RAM lỗi.",
    fix: [
      "Boot vào Safe Mode (nhấn Shift + Restart 3 lần liên tiếp để vào WinRE)",
      "Chạy: sfc /scannow và DISM /RestoreHealth trong Safe Mode",
      "Gỡ driver/phần mềm mới cài gần nhất",
      "Test RAM bằng Windows Memory Diagnostic",
      "Nếu vẫn lỗi: System Restore về điểm khôi phục trước đó",
    ],
  },
  {
    code: "INACCESSIBLE_BOOT_DEVICE", title: "Không boot vào được Windows",
    category: "boot", severity: "Nghiêm trọng",
    cause: "Boot record hỏng, driver ổ đĩa (AHCI/RAID) lỗi, hoặc đổi chế độ BIOS đột ngột.",
    fix: [
      "Boot từ USB installation media > Repair your computer > Troubleshoot > Advanced options > Command Prompt",
      "Chạy: bootrec /fixmbr, bootrec /fixboot, bootrec /rebuildbcd",
      "Kiểm tra chế độ SATA trong BIOS (AHCI vs RAID/IDE) — đảm bảo không đổi sau khi cài Windows",
      "Chạy chkdsk /f /r trên ổ đĩa hệ thống",
    ],
  },
  {
    code: "Black Screen After Login", title: "Màn hình đen sau khi đăng nhập",
    category: "boot", severity: "Cao",
    cause: "Explorer.exe crash, driver màn hình lỗi, hoặc update Windows chưa hoàn tất.",
    fix: [
      "Nhấn Ctrl+Shift+Esc mở Task Manager > File > Run new task > explorer.exe",
      "Update/rollback driver card màn hình",
      "Kiểm tra máy đang cập nhật Windows Update ngầm — đợi hoàn tất",
      "Boot vào Safe Mode để kiểm tra và gỡ phần mềm gây conflict",
    ],
  },

  // ── PERFORMANCE ──────────────────────────────────────────
  {
    code: "High CPU/Disk Usage 100%", title: "Máy chạy chậm, CPU/Disk luôn 100%",
    category: "performance", severity: "Trung bình",
    cause: "Windows Search Indexing, Superfetch, hoặc malware chạy ngầm chiếm tài nguyên.",
    fix: [
      "Task Manager > kiểm tra process nào chiếm tài nguyên nhất",
      "Tắt tạm Windows Search: services.msc > Windows Search > Stop",
      "Tắt SysMain (Superfetch) nếu dùng SSD: services.msc > SysMain > Disable",
      "Quét virus/malware bằng Windows Defender Offline Scan",
      "Kiểm tra Startup apps: Task Manager > Startup > Disable app không cần thiết",
    ],
  },
  {
    code: "Memory Leak / RAM đầy", title: "RAM sử dụng tăng dần theo thời gian không giảm",
    category: "performance", severity: "Trung bình",
    cause: "Ứng dụng bị memory leak (thường do driver hoặc phần mềm lỗi).",
    fix: [
      "Resource Monitor (resmon) > xác định process leak",
      "Update ứng dụng/driver liên quan lên bản mới nhất",
      "Restart máy định kỳ nếu chưa fix được gốc rễ",
      "Báo lỗi cho vendor phần mềm nếu là ứng dụng bên thứ 3",
    ],
  },

  // ── PRINTER & DEVICES ────────────────────────────────────
  {
    code: "Printer Offline", title: "Máy in hiển thị Offline dù đã kết nối",
    category: "printer", severity: "Thấp",
    cause: "Print Spooler service bị treo, hoặc driver máy in lỗi.",
    fix: [
      "Restart Print Spooler: services.msc > Print Spooler > Restart",
      "Xóa cache: %WINDIR%\\System32\\spool\\PRINTERS (xóa hết file trong đây khi Spooler đã dừng)",
      "Gỡ và cài lại driver máy in bản mới nhất từ NSX",
      "Set lại máy in làm Default printer",
    ],
  },
  {
    code: "0x00000709", title: "Không set được máy in mặc định (Print margin error)",
    category: "printer", severity: "Thấp",
    cause: "Registry key cấu hình máy in default bị lỗi.",
    fix: [
      "Settings > Bluetooth & devices > Printers > tắt 'Let Windows manage my default printer'",
      "Chọn lại máy in > Set as default",
      "Nếu vẫn lỗi: gỡ hoàn toàn driver + Add printer lại từ đầu",
    ],
  },
  {
    code: "USB Device Not Recognized", title: "Cắm USB không nhận thiết bị",
    category: "printer", severity: "Thấp",
    cause: "Driver USB controller lỗi, hoặc cổng USB hỏng vật lý.",
    fix: [
      "Device Manager > gỡ driver USB Controller > Scan for hardware changes",
      "Thử cổng USB khác / cáp khác để loại trừ lỗi vật lý",
      "Update chipset driver từ trang chủ mainboard/laptop",
    ],
  },

  // ── OFFICE & APPS ────────────────────────────────────────
  {
    code: "0x8004210A", title: "Outlook lỗi kết nối server / timeout gửi mail",
    category: "office", severity: "Trung bình",
    cause: "Kết nối mạng chậm/timeout, hoặc file OST/PST bị lỗi.",
    fix: [
      "Kiểm tra kết nối mạng ổn định",
      "Outlook > File > Account Settings > Repair",
      "Tạo lại profile Outlook mới nếu file OST hỏng nặng",
      "Chạy ScanPST.exe để sửa file PST bị lỗi",
    ],
  },
  {
    code: "Office Activation Error", title: "Office báo 'Unlicensed Product'",
    category: "office", severity: "Trung bình",
    cause: "License Office hết hạn, hoặc mất kết nối tới Microsoft 365 account.",
    fix: [
      "Mở bất kỳ ứng dụng Office > File > Account > Sign in lại đúng tài khoản công ty",
      "Kiểm tra subscription Microsoft 365 còn hạn tại admin.microsoft.com",
      "Chạy Office Repair: Settings > Apps > Microsoft Office > Modify > Online Repair",
    ],
  },
  {
    code: "Excel File Corrupted", title: "File Excel/Word báo lỗi không mở được",
    category: "office", severity: "Trung bình",
    cause: "File bị hỏng do tắt máy đột ngột, hoặc lỗi đồng bộ OneDrive.",
    fix: [
      "Mở Excel > File > Open > chọn file > mũi tên cạnh Open > 'Open and Repair'",
      "Kiểm tra thư mục OneDrive > Version History để lấy bản trước đó",
      "Dùng file backup tự động (AutoRecover) trong %APPDATA%\\Microsoft\\Excel",
    ],
  },
  {
    code: "Excel không phản hồi (Not Responding)", title: "Excel treo/đứng khi mở file lớn hoặc có Add-in",
    category: "office", severity: "Trung bình",
    cause: "Add-in xung đột, file chứa quá nhiều công thức/macro nặng, hoặc conflict với antivirus.",
    fix: [
      "Mở Excel ở Safe Mode: giữ Ctrl khi mở Excel, hoặc chạy 'excel.exe /safe'",
      "File > Options > Add-ins > Manage: COM Add-ins > Go... > tắt hết add-in > mở lại file bình thường",
      "Kiểm tra file có vòng lặp công thức (circular reference) — Formulas > Error Checking",
      "Update Office lên bản mới nhất: File > Account > Update Options > Update Now",
    ],
  },
  {
    code: "0x800A03EC", title: "Lỗi công thức Excel / VBA khi mở file (Run-time error)",
    category: "office", severity: "Thấp",
    cause: "Công thức tham chiếu sai vùng, hoặc macro VBA gọi hàm không tồn tại.",
    fix: [
      "Kiểm tra công thức bị lỗi: Formulas > Show Formulas để xem toàn bộ",
      "Nếu do macro: Alt+F11 mở VBA Editor > Debug để xác định dòng lỗi",
      "Kiểm tra Regional Settings (dấu phẩy/chấm) khớp với định dạng công thức trong file",
    ],
  },
  {
    code: "Word: Lỗi khi lưu file (Cannot save)", title: "Word báo lỗi không lưu được file",
    category: "office", severity: "Trung bình",
    cause: "Thư mục lưu bị mất quyền, đường dẫn quá dài, hoặc OneDrive đang đồng bộ conflict.",
    fix: [
      "Thử Save As với tên/vị trí khác (VD: lưu ra Desktop) để loại trừ lỗi quyền truy cập",
      "Tắt tạm đồng bộ OneDrive rồi lưu lại",
      "Kiểm tra đường dẫn file không vượt quá 260 ký tự",
      "Chạy Word ở Safe Mode nếu add-in gây lỗi: winword /safe",
    ],
  },
  {
    code: "Outlook: PST/OST quá lớn chậm/crash", title: "Outlook chạy chậm hoặc crash do file dữ liệu quá lớn",
    category: "office", severity: "Trung bình",
    cause: "File OST/PST vượt quá dung lượng khuyến nghị (thường >20-50GB tùy phiên bản).",
    fix: [
      "Dùng Mailbox Cleanup: File > Tools > Mailbox Cleanup để xem/dọn dung lượng",
      "Archive email cũ: File > Tools > Clean Up Old Items",
      "Xóa và đồng bộ lại OST: đóng Outlook > xóa file .ost trong %LOCALAPPDATA%\\Microsoft\\Outlook > mở lại Outlook để tự tạo mới",
      "Với PST: dùng ScanPST.exe để compact và sửa lỗi file",
    ],
  },
  {
    code: "Outlook: Send/Receive Error 0x8004010F", title: "Không đồng bộ được mail (Send/Receive error)",
    category: "office", severity: "Trung bình",
    cause: "Offline Address Book lỗi, hoặc thư mục Outlook Data File không truy cập được.",
    fix: [
      "Send/Receive > Download Address Book > tick 'Download changes since last Send/Receive'",
      "Kiểm tra kết nối Exchange/Microsoft 365: Ctrl+Click icon Outlook trên taskbar > Test E-mail AutoConfiguration",
      "Tạo lại Outlook profile: Control Panel > Mail > Show Profiles > Add mới",
    ],
  },
  {
    code: "Ứng dụng Store bị lỗi/crash", title: "App (Calculator, Photos, Teams...) không mở được hoặc crash liên tục",
    category: "office", severity: "Thấp",
    cause: "Cache app bị hỏng, hoặc app cần re-register lại với hệ thống sau update Windows.",
    fix: [
      "Settings > Apps > tìm app > Advanced options > Repair, nếu không được thì Reset",
      "Re-register toàn bộ Microsoft Store apps (PowerShell as Admin):",
      "Get-AppXPackage -AllUsers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register \"$($_.InstallLocation)\\AppXManifest.xml\"}",
      "Nếu vẫn lỗi: gỡ và cài lại app từ Microsoft Store",
    ],
  },
  {
    code: "Teams: Không load được / màn hình trắng", title: "Microsoft Teams bị treo hoặc màn hình trắng khi mở",
    category: "office", severity: "Thấp",
    cause: "Cache Teams bị hỏng, thường gặp sau update lớn.",
    fix: [
      "Đóng hoàn toàn Teams (Task Manager > End Task, kiểm tra không còn process Teams)",
      "Xóa cache: %APPDATA%\\Microsoft\\Teams (đổi tên thành Teams.old thay vì xóa hẳn để backup)",
      "Mở lại Teams để tự tạo cache mới và đăng nhập lại",
    ],
  },

  // ── SECURITY ─────────────────────────────────────────────
  {
    code: "Windows Defender Turned Off by Group Policy", title: "Không bật được Windows Defender",
    category: "security", severity: "Cao",
    cause: "Policy công ty tắt Defender do dùng antivirus thứ 3, hoặc registry bị chỉnh sai.",
    fix: [
      "Kiểm tra có antivirus thứ 3 đang chạy (Defender tự tắt khi có AV khác) — bình thường",
      "gpedit.msc > Computer Config > Admin Templates > Windows Components > Microsoft Defender Antivirus — set Not Configured nếu muốn Defender hoạt động",
      "Nếu bị policy domain khóa, liên hệ IT admin xác nhận có chủ đích",
    ],
  },
  {
    code: "Ransomware/Malware Alert", title: "Nghi ngờ máy bị nhiễm ransomware/malware",
    category: "security", severity: "Nghiêm trọng",
    cause: "Click link lạ, mở file đính kèm độc hại, hoặc lỗ hổng phần mềm chưa patch.",
    fix: [
      "NGẮT KẾT NỐI MẠNG NGAY (rút cáp/tắt wifi) để tránh lây lan",
      "KHÔNG tắt máy nếu đang mã hóa — báo ngay cho team Security",
      "Chạy Windows Defender Offline Scan từ máy khác/USB sạch",
      "Khôi phục từ backup sạch gần nhất sau khi xác nhận máy đã sạch",
      "Đổi toàn bộ password liên quan sau khi xử lý xong",
    ],
  },

  // ── DRIVER ───────────────────────────────────────────────
  {
    code: "Code 43", title: "Device Manager báo 'Windows has stopped this device (Code 43)'",
    category: "driver", severity: "Trung bình",
    cause: "Driver lỗi, thiết bị bị treo, hoặc conflict phần cứng.",
    fix: [
      "Device Manager > gỡ driver thiết bị > Restart máy để Windows tự cài lại",
      "Update driver từ trang chủ nhà sản xuất (không dùng driver Windows Update mặc định nếu vẫn lỗi)",
      "Kiểm tra thiết bị trên máy khác để loại trừ lỗi phần cứng",
    ],
  },
  {
    code: "Code 10", title: "Device cannot start (Code 10)",
    category: "driver", severity: "Trung bình",
    cause: "Driver không tương thích với phiên bản Windows hiện tại.",
    fix: [
      "Update driver lên bản tương thích Windows 11",
      "Rollback driver về bản cũ nếu vừa update gây lỗi (Driver tab > Roll Back Driver)",
      "Kiểm tra BIOS/UEFI có cần update firmware cho thiết bị (đặc biệt thiết bị onboard)",
    ],
  },

  // ── STORAGE ──────────────────────────────────────────────
  {
    code: "S.M.A.R.T. Failure Warning", title: "Cảnh báo ổ cứng có nguy cơ hỏng",
    category: "storage", severity: "Nghiêm trọng",
    cause: "Ổ cứng/SSD xuống cấp vật lý, bad sector tăng dần.",
    fix: [
      "BACKUP DỮ LIỆU NGAY LẬP TỨC — đây là cảnh báo phần cứng thật, không phải lỗi phần mềm",
      "Chạy chkdsk /f /r để kiểm tra và cách ly bad sector",
      "Dùng CrystalDiskInfo để xem chi tiết chỉ số S.M.A.R.T.",
      "Lên kế hoạch thay ổ đĩa mới trong thời gian sớm nhất",
    ],
  },
  {
    code: "0x80070570", title: "The file or directory is corrupted and unreadable",
    category: "storage", severity: "Cao",
    cause: "Lỗi hệ thống file (NTFS), bad sector, hoặc quá trình copy bị gián đoạn.",
    fix: [
      "Chạy: chkdsk C: /f /r (cần restart để chạy full scan)",
      "Chạy DISM /RestoreHealth + SFC /scannow",
      "Nếu copy từ USB/ổ ngoài: kiểm tra thiết bị nguồn không bị lỗi",
      "Backup dữ liệu quan trọng trước khi format/reinstall nếu lỗi lặp lại",
    ],
  },
  {
    code: "Disk Full C:", title: "Ổ C: báo đầy dung lượng dù chưa cài nhiều",
    category: "storage", severity: "Thấp",
    cause: "File temp, Windows Update cache, System Restore points chiếm dung lượng lớn.",
    fix: [
      "Settings > System > Storage > Temporary files > xóa cache",
      "Disk Cleanup > chọn 'Clean up system files' > xóa Windows Update Cleanup",
      "Kiểm tra & xóa Windows.old nếu vừa upgrade Windows",
      "Giảm dung lượng System Restore: vssadmin resize shadowstorage",
    ],
  },
];
