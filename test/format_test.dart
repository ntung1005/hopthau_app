import 'package:hopthau/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vnd nhóm hàng nghìn bằng dấu chấm', () {
    expect(vnd(0), '0 đ');
    expect(vnd(999), '999 đ');
    expect(vnd(1000), '1.000 đ');
    expect(vnd(31960000), '31.960.000 đ');
    expect(vnd(-1500000), '-1.500.000 đ');
  });

  test('vndShort theo triệu', () {
    expect(vndShort(500000), '500.000 đ');
    expect(vndShort(32000000), '32 triệu');
    expect(vndShort(31960000), '32 triệu');
    expect(vndShort(31940000), '31,9 triệu');
    expect(vndShort(150000000), '150 triệu');
  });

  test('vnDate', () {
    expect(vnDate('2026-12-15'), '15/12/2026');
    expect(vnDate('2027-03-01'), '01/03/2027');
    expect(vnDate('abc'), 'abc');
  });

  test('parseMillions', () {
    expect(parseMillions('13'), 13000000);
    expect(parseMillions('13,5'), 13500000);
    expect(parseMillions(' 0.25 '), 250000);
    expect(parseMillions('abc'), null);
    expect(parseMillions('-1'), null);
  });

  test('foldVietnamese', () {
    expect(foldVietnamese('NOXH Sông Hồng, Thủ Đức'), 'noxh song hong, thu duc');
    expect(foldVietnamese('Ỷ Lan Đường'), 'y lan duong');
  });
}
