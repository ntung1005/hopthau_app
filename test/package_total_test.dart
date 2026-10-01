import 'package:hopthau/screens/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Cùng dữ liệu với hopthau_be/test/pricing.test.ts: hai bên phải ra cùng một giá.
  final items = [
    {'id': 'a', 'qty': 1, 'unit_price': 12000000, 'is_optional': false},
    {'id': 'b', 'qty': '2.5', 'unit_price': 1000000, 'is_optional': false},
    {'id': 'c', 'qty': 1, 'unit_price': 8000000, 'is_optional': true},
  ];

  test('chỉ tính hạng mục bắt buộc', () => expect(packageTotal(items, {}), 14500000));
  test('cộng hạng mục tuỳ chọn đang chọn', () => expect(packageTotal(items, {'c'}), 22500000));
}
