# Hợp Thầu app (Next.js)

Bản web Next.js của [hopthau_app](../hopthau_app) (Flutter), đủ tính năng cho cả chủ nhà và nhà thầu. Chạy hoàn toàn trên trình duyệt, chỉ gọi REST API của [hopthau_be](../hopthau_be) (phiên đăng nhập lưu ở localStorage, tự làm mới token).

## Chạy

```bash
npm install
npm run dev          # http://localhost:3001 (3000 là hopthau_web)
npm test             # kiểm tra mô hình bản đo + định dạng (node --test)
npm run build
```

BE mặc định `http://127.0.0.1:8788`; đổi bằng `NEXT_PUBLIC_API_URL` (mẫu: [.env.example](.env.example)). BE cần `CORS_ORIGIN` cho phép (mặc định `*`).

## Màn hình ↔ đường dẫn

| Chế độ | Tab | Đường dẫn |
|---|---|---|
| Chủ nhà | Khám phá · Yêu cầu · [Đo nhà] · Công trình · Tài khoản | `/` · `/yeu-cau` · `/do-nha` · `/cong-trinh` · `/tai-khoan` |
| Nhà thầu | Khách hàng · Công trình · [Tạo gói] · Gói của tôi · Tài khoản | `/khach-hang` · `/cong-trinh` · `/goi-cua-toi/moi` · `/goi-cua-toi` · `/tai-khoan` |

Màn chi tiết: `/du-an/[slug]` → `/du-an/[slug]/[unitId]` (danh sách gói) → `/so-sanh?unit=&ids=` · `/goi/[id]` · `/nha-thau/[id]` · `/yeu-cau/moi?unit=&package=&measurement=` · `/yeu-cau/[id]` · `/cong-trinh/[id]` · `/khach-hang/[requestId]` · `/goi-cua-toi/[id]` · `/do-nha/[id]` (trình dựng; `moi` = bản nháp) · `/ban-do/[id]` (xem bản đo) · `/dang-nhap?next=` · `/tai-khoan/dang-ky-nha-thau` · `/tai-khoan/ho-so-nha-thau`.

## Source

| File | Nội dung (tương ứng bên Flutter) |
|---|---|
| [src/lib/api.ts](src/lib/api.ts) | Client REST, phiên, upload ảnh (nén trước khi gửi) — `api.dart`, `photos.dart` |
| [src/lib/format.ts](src/lib/format.ts) | Tiền, ngày, câu báo lỗi — `format.dart` |
| [src/lib/measure.ts](src/lib/measure.ts) | Mô hình bản đo, cùng công thức với BE — `measure/model.dart` |
| [src/lib/draw.ts](src/lib/draw.ts) | Vẽ mặt bằng 2D và khung 3D lên canvas — `measure/painters.dart` |
| [src/ui/app.tsx](src/ui/app.tsx) | Tài khoản, chế độ chủ nhà / nhà thầu, thông báo, `useLoad` — `app_state.dart` |
| [src/ui/shell.tsx](src/ui/shell.tsx) | Thanh tab + nút giữa theo chế độ — `main.dart` |
| [src/ui/kit.tsx](src/ui/kit.tsx), [shared.tsx](src/ui/shared.tsx), [plan-canvas.tsx](src/ui/plan-canvas.tsx) | Thành phần dùng chung — `common.dart`, `theme.dart` |
| [src/app/**/page.tsx](src/app) | Mỗi màn một trang |

Khác bản Flutter: hộp xác nhận / đổi tên dùng `confirm` / `prompt` của trình duyệt; số điện thoại bấm để gọi (`tel:`); bảng thông số trong trình dựng bản đo thu gọn bằng nút thay cho kéo.
