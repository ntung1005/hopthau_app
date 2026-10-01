import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopthau/screens/common.dart';

void main() {
  testWidgets('Loader hiện nội dung khi kết quả là null (chưa đăng ký nhà thầu)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Loader<Map<String, dynamic>?>(
        load: () async => null,
        builder: (context, data, _) => Text(data == null ? 'Form đăng ký' : 'Bảng điều khiển'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Form đăng ký'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Loader vẫn hiện vòng quay khi đang tải và lỗi khi thất bại', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Loader<int>(
          load: () => Future.delayed(const Duration(seconds: 1), () => throw Exception('x')), builder: (_, v, __) => Text('$v')),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
