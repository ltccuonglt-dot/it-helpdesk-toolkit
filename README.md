# 🖥️ IT Helpdesk Toolkit — Windows 11 Pro Error Center

Công cụ tra cứu & xử lý lỗi Windows 11 Pro dành cho IT helpdesk. Tra lỗi theo mã/từ khóa,
xem nguyên nhân + hướng dẫn xử lý từng bước — và có thể **quét lỗi thật trên máy** bằng script
PowerShell đi kèm, rồi tự động khớp với cơ sở dữ liệu lỗi.

## 🔗 Demo
Mở trực tiếp: [`docs/index.html`](docs/index.html) (double-click hoặc mở bằng browser).
Nếu deploy GitHub Pages: `https://<username>.github.io/<repo-name>/`

## ✨ Tính năng

- **Tra cứu lỗi**: tìm theo mã lỗi (VD: `0x80070102`), tên lỗi, hoặc từ khóa (VD: "wifi", "in ấn")
- **Lọc theo danh mục**: Windows Update, Kích hoạt, Mạng, Boot/BSOD, Hiệu năng, Máy in, Office, Bảo mật, Driver, Ổ đĩa
- **Chi tiết đầy đủ** mỗi lỗi: nguyên nhân + các bước xử lý cụ thể
- **Quét lỗi trên máy**: chạy `scripts/Scan-System.ps1` → xuất `scan-result.json` → tải lên tool để tự động khớp lỗi phát hiện với hướng xử lý trong KB
- 100% chạy client-side (không cần server/database) — mở file HTML là dùng được ngay

## 📁 Cấu trúc project

```
IT-Helpdesk-Toolkit/
├── docs/
│   ├── index.html          # Tool web chính (mở file này để dùng)
│   └── errors-data.js       # Cơ sở dữ liệu lỗi (danh mục + chi tiết fix)
├── scripts/
│   ├── Scan-System.ps1       # Script quét lỗi thật trên máy Windows
│   └── Fix-Error-0x80070102.ps1  # Script fix riêng cho lỗi Language Pack
└── README.md
```

## 🚀 Cách dùng

### 1. Tra cứu lỗi (không cần cài gì)
Mở `docs/index.html` bằng bất kỳ browser nào. Gõ từ khóa hoặc lọc theo danh mục.

### 2. Fix ngầm tự động (không cần theo dõi)
```powershell
# Chạy Administrator PowerShell, tự fix TẤT CẢ lỗi an toàn ở background:
.\scripts\Fix-Runner.ps1 -All -Background

# Hoặc fix ngầm 1 lỗi cụ thể theo mã:
.\scripts\Fix-Runner.ps1 -Code "0x80070102" -Background

# Xem log sau khi chạy xong (script không hiện gì trên màn hình lúc chạy):
Get-Content "$env:TEMP\FixRunner-*.log" -Tail 50
```
Chỉ tự động chạy các remediation **an toàn** (restart service, xóa cache, reset DNS/IP...).
Lỗi rủi ro cao (BSOD, ổ cứng hỏng, nghi nhiễm mã độc, kích hoạt Windows) sẽ **không tự chạy** —
script chỉ ghi log khuyến nghị bạn tự xử lý theo hướng dẫn trong `docs/index.html`.

### 3. Quét lỗi thật trên máy
```powershell
# Chạy với quyền Administrator
.\scripts\Scan-System.ps1
```
Script quét Event Viewer, lịch sử Windows Update, activation status, sức khỏe ổ đĩa,
dung lượng trống, và trạng thái Windows Defender — xuất ra `scan-result.json`.

Sau đó mở `docs/index.html` > nhấn **"🩺 Quét lỗi trên máy"** > chọn file `scan-result.json`
vừa tạo. Tool sẽ tự động khớp các dấu hiệu lỗi phát hiện với cơ sở dữ liệu và hiện cách xử lý.

## ➕ Thêm lỗi mới vào cơ sở dữ liệu

Mở `docs/errors-data.js`, thêm 1 object vào mảng `ERRORS_DB`:

```js
{
  code: "0xXXXXXXXX", title: "Tên ngắn gọn của lỗi",
  category: "update",              // xem danh sách category id trong ERROR_CATEGORIES
  severity: "Cao",                  // Thấp | Trung bình | Cao | Nghiêm trọng
  cause: "Nguyên nhân gây ra lỗi.",
  fix: [
    "Bước 1...",
    "Bước 2...",
  ],
},
```

## 🌐 Deploy lên GitHub Pages

1. Push repo này lên GitHub
2. Vào **Settings > Pages** > Source: chọn branch `main`, folder `/docs`
3. Sau ~1 phút, trang sẽ có ở `https://<username>.github.io/<repo-name>/`

## 📌 Lưu ý

- Đây là công cụ **tham khảo & hỗ trợ xử lý**, không thay thế đánh giá chuyên môn khi gặp lỗi
  nghiêm trọng (mất dữ liệu, bảo mật, phần cứng hỏng).
- Trình duyệt không thể tự quét hệ thống Windows do giới hạn bảo mật — đây là lý do cần chạy
  `Scan-System.ps1` riêng rồi import kết quả vào tool.
