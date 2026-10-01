#!/usr/bin/env bash
# Tạo thư mục nền tảng Android/iOS/web. Chạy một lần sau khi clone: ./scripts/setup.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Chưa cài Flutter: https://docs.flutter.dev/get-started/install"; exit 1; }

# Không ghi đè file đã có trong lib/.
flutter create --org vn.hopthau --project-name hopthau --platforms=android,ios,web .

# flutter create sinh test mẫu cho app counter, không dùng được với app này.
if grep -q "MyApp" test/widget_test.dart 2>/dev/null; then
  rm test/widget_test.dart
fi

# Android: Internet (bản release cần khai báo).
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  perl -0pi -e 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi

# Bản debug gọi BE local qua HTTP.
DEBUG_MANIFEST=android/app/src/debug/AndroidManifest.xml
if [ -f "$DEBUG_MANIFEST" ] && ! grep -q "usesCleartextTraffic" "$DEBUG_MANIFEST"; then
  perl -0pi -e 's#</manifest>#    <application android:usesCleartextTraffic="true"/>\n</manifest>#' "$DEBUG_MANIFEST"
fi

# Tên hiển thị có dấu (flutter create chỉ đặt theo tên project không dấu).
PLIST=ios/Runner/Info.plist
perl -0pi -e 's#android:label="[^"]*"#android:label="Hợp Thầu"#' "$MANIFEST"
if [ -f "$PLIST" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Hợp Thầu" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Hợp Thầu" "$PLIST"
fi
perl -0pi -e 's#<title>[^<]*</title>#<title>Hợp Thầu</title>#; s#content="[^"]*" name="apple-mobile-web-app-title"#content="Hợp Thầu" name="apple-mobile-web-app-title"#' web/index.html
perl -0pi -e 's#"name": "[^"]*"#"name": "Hợp Thầu"#; s#"short_name": "[^"]*"#"short_name": "Hợp Thầu"#; s#"description": "[^"]*"#"description": "Thầu hợp căn, hợp giá, hợp ý"#' web/manifest.json

flutter pub get
echo "Xong. Chạy app: flutter run -d chrome"
