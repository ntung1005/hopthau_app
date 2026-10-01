import 'package:flutter_test/flutter_test.dart';
import 'package:hopthau/app_state.dart';

void main() {
  test('chủ nhà luôn ở chế độ chủ nhà, kể cả khi còn lưu chế độ nhà thầu cũ', () {
    expect(AppState.chooseMode(isContractor: false), AppMode.owner);
    expect(AppState.chooseMode(isContractor: false, saved: 'contractor'), AppMode.owner);
  });

  test('nhà thầu mặc định chế độ nhà thầu, nhớ lựa chọn chủ nhà', () {
    expect(AppState.chooseMode(isContractor: true), AppMode.contractor);
    expect(AppState.chooseMode(isContractor: true, saved: 'contractor'), AppMode.contractor);
    expect(AppState.chooseMode(isContractor: true, saved: 'owner'), AppMode.owner);
  });
}
