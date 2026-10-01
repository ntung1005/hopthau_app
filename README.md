# Hợp Thầu app

Một app cho cả chủ nhà và nhà thầu, tách thành **hai chế độ**, mỗi chế độ một bộ tab (không lẫn tính năng). Chỉ gọi REST API của [hopthau_be](../hopthau_be).

| Chế độ | Tab | Nút giữa |
|---|---|---|
| Chủ nhà (mặc định) | Khám phá · Yêu cầu · Công trình · Tài khoản | Đo nhà |
| Nhà thầu | Khách hàng · Công trình · Gói của tôi · Tài khoản | Tạo gói |

Đăng ký làm nhà thầu và chuyển chế độ đều ở tab **Tài khoản**. Tài khoản có vai trò nhà thầu mở app sẽ vào chế độ nhà thầu (nhớ lựa chọn lần trước).

- **Chủ nhà:** tìm dự án (không cần gõ dấu) → mẫu căn (giá "từ") → so sánh tối đa 3 gói (tô ô tốt nhất) → xem hạng mục, chọn tuỳ chọn → nhận tư vấn. Nút + ở giữa: yêu cầu theo địa chỉ. Tab Yêu cầu: xem báo giá, chọn nhà thầu, thấy số điện thoại sau khi chọn.
- **Nhà thầu (chế độ nhà thầu):** đăng ký hồ sơ, tạo và sửa gói (hạng mục, đơn giá, tuỳ chọn, ảnh), gửi duyệt; khách hàng được ghép, gửi báo giá; công trình.
- **Công trình (cả hai bên):** 4 mốc trên dòng thời gian, báo xong kèm ảnh / nghiệm thu / trả lại, xác nhận nhận tiền, phát sinh cần chủ nhà đồng ý, bảo hành, đánh giá và trả lời.
- **Tự đo nhà:** bắt đầu từ mẫu (căn 1PN, 2PN, một phòng), nhập rộng / dài / cao từng phòng và cửa đi, cửa sổ trên từng tường; cắt góc phòng (cắt vuông cho cột, hộp kỹ thuật; cắt chéo cho góc vát) có xem trước, diện tích và chu vi tính theo đa giác; kéo thả xếp phòng (tự hít vào mép phòng bên cạnh). App vẽ mặt bằng 2D có kích thước và khung 3D xoay được (kéo để xoay / nghiêng, chụm hoặc cuộn chuột để phóng to, nút xoay 90°, chạm đúp để đặt lại), tính diện tích sàn, tường trừ cửa. Gửi kèm yêu cầu báo giá; nhà thầu mở ra xem 2D / 3D và bảng khối lượng từng phòng. Có hướng dẫn cách đo. Đo bằng camera (AR) để dành cho bản native.
- **Trang chủ:** tìm dự án, lối tắt (tự đo nhà, xin báo giá, công trình, cách đo), banner đo nhà, dự án có giá "từ", gói nổi bật có ảnh, căn đã làm thực tế, vì sao chọn Hợp Thầu. Nút giữa thanh điều hướng mở đo nhà.
- **Tin cậy:** hồ sơ nhà thầu công khai (điểm, số căn đã bàn giao, đánh giá), "Căn đã làm thực tế" theo mẫu căn, ảnh gói. Tài khoản: xoá tài khoản.

## Chạy

```bash
./scripts/setup.sh           # lần đầu: tạo android/ios/web, pub get
flutter run -d chrome        # mặc định gọi BE ở 127.0.0.1:8788 (máy ảo Android: 10.0.2.2:8788)
flutter test
```

Đổi BE: `--dart-define=API_URL=...` hoặc `--dart-define-from-file=env/local.json` (mẫu: [env/local.example.json](env/local.example.json)).

## Source

| File | Nội dung |
|---|---|
| [lib/api.dart](lib/api.dart) | Client REST: phiên đăng nhập (lưu `shared_preferences`), tự làm mới token |
| [lib/screens/catalog.dart](lib/screens/catalog.dart) | Dự án, mẫu căn, danh sách gói, so sánh, chi tiết gói |
| [lib/screens/requests.dart](lib/screens/requests.dart) | Gửi yêu cầu, yêu cầu của tôi, chi tiết và chọn báo giá |
| [lib/screens/contractor.dart](lib/screens/contractor.dart) | Khu vực nhà thầu: hồ sơ, khách hàng, báo giá, trình soạn gói |
| [lib/screens/jobs.dart](lib/screens/jobs.dart) | Công trình: mốc, phát sinh, đánh giá (cả hai vai trò) |
| [lib/screens/contractor_profile.dart](lib/screens/contractor_profile.dart) | Hồ sơ nhà thầu công khai |
| [lib/screens/home.dart](lib/screens/home.dart) | Trang chủ |
| [lib/screens/measure.dart](lib/screens/measure.dart) | Đo nhà: danh sách, trình dựng, màn xem cho nhà thầu, hướng dẫn |
| [lib/measure/model.dart](lib/measure/model.dart), [painters.dart](lib/measure/painters.dart) | Mô hình bản đo (cùng công thức với BE), vẽ mặt bằng 2D và khung 3D |
| [lib/photos.dart](lib/photos.dart) | Chọn và upload ảnh (`image_picker` → URL ký sẵn của BE), lưới ảnh |
| [lib/screens/account.dart](lib/screens/account.dart) | Đăng nhập / đăng ký, tab Tài khoản, xoá tài khoản |
| [lib/screens/common.dart](lib/screens/common.dart) | Widget dùng chung: `Loader`, `RowCard`, `Pill`, `EmptyState`, `InfoPanel`, `PhoneRow` |
| [lib/theme.dart](lib/theme.dart) | Design tokens (màu, bo góc), theme Material, widget dùng chung: `IconBadge`, `Illustration`, `ContractorLine` |
| [lib/format.dart](lib/format.dart) | Định dạng tiền, ngày, câu báo lỗi |

## Giao diện

Theo UI kit [Coinpay (Figma community)](https://www.figma.com/design/gbyujmfMTix7m5PBOmVVgH/Coinpay-Fintech-Finance-Mobile-App-UI-kit--Community---Community-?node-id=142-3631): xanh royal `#304FFE`, nền trắng, nút bo tròn cao 56, ô nhập nền xám nhạt, card bo 16, header xanh bo góc dưới, bottom nav có nút giữa nổi (gửi yêu cầu báo giá).

Token hiện lấy từ ảnh chụp của kit. Khi đọc được file Figma, chỉ cần sửa `AppColors` / `AppRadius` trong `theme.dart`. Minh hoạ đang dùng icon trên vòng tròn đồng tâm (`Illustration`); thay bằng ảnh line-art xuất từ kit khi có asset. Font đang là font hệ thống.

Chưa dùng state management hay router riêng: màn hình ít, `Navigator` + `FutureBuilder` là đủ. Thêm Riverpod / go_router khi có vai trò nhà thầu và deep link.
