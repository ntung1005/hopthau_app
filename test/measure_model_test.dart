import 'package:hopthau/measure/model.dart';
import 'package:hopthau/measure/painters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Cùng dữ liệu với hopthau_be/test/measurement.test.ts: hai bên phải ra cùng số.
  final room = Room(id: 'r1', name: 'Phòng khách', type: 'living', x: 0, y: 0, w: 4, l: 5, h: 2.8, openings: [
    Opening(wall: 's', kind: 'door', offset: 0.5, width: 0.9, height: 2.1),
    Opening(wall: 'e', kind: 'window', offset: 1, width: 1.2, height: 1.4, sill: 0.9),
  ]);

  test('diện tích khớp BE', () {
    final plan = Plan([
      room,
      room.copy()
        ..id = 'r2'
        ..openings = []
    ]);
    expect(room.floorArea, 20);
    expect((room.wallArea * 100).round() / 100, 46.83);
    expect(plan.floorArea, 40);
    expect(plan.wallArea, 97.23);
  });

  test('thu nhỏ phòng thì cửa co lại cho vừa tường', () {
    final r = room.copy()
      ..w = 1.0
      ..h = 2.0;
    r.clampOpenings();
    final door = r.openings.first;
    expect(door.offset + door.width <= r.w, isTrue);
    expect(door.height <= r.h, isTrue);
    final window = r.openings.last;
    expect(window.sill + window.height <= r.h, isTrue);
  });

  test('mẫu căn hợp lệ: cửa nằm trong tường, json đi rồi về không đổi', () {
    for (final make in planTemplates.values) {
      final p = make();
      for (final r in p.rooms) {
        for (final o in r.openings) {
          expect(o.offset + o.width <= r.wallLength(o.wall) + 1e-9, isTrue, reason: '${r.name} ${o.wall}');
          expect(o.sill + o.height <= r.h + 1e-9, isTrue);
        }
      }
      expect(Plan.fromJson(p.toJson()).toJson(), p.toJson());
    }
  });

  test('id phòng mới không trùng', () {
    final p = planTemplates.values.first();
    expect(p.rooms.any((r) => r.id == p.newRoomId()), isFalse);
  });

  test('cắt góc khớp BE: cắt vuông giữ chu vi, cắt chéo vát cạnh', () {
    final r = room.copy()
      ..openings = []
      ..cuts = [
        CornerCut(corner: 'nw', kind: 'notch', dx: 0.5, dy: 0.6),
        CornerCut(corner: 'se', kind: 'chamfer', dx: 1, dy: 1),
      ];
    expect((r.floorArea * 100).round() / 100, 19.2);
    expect((r.perimeter * 100).round() / 100, 17.41);
    expect(r.edges.where((e) => e.side == 'cut').length, 3);
    expect(r.wallSpan('n'), (0.5, 4.0));
    expect(r.wallSpan('w'), (0.6, 5.0));
    expect(Room.fromJson(r.toJson()).toJson(), r.toJson());
  });

  test('cắt góc thì cửa bị đẩy ra khỏi đoạn tường đã cắt', () {
    final r = room.copy()
      ..openings = [Opening(wall: 'n', kind: 'door', offset: 0.1, width: 0.9, height: 2.1)]
      ..cuts = [CornerCut(corner: 'nw', kind: 'notch', dx: 0.8, dy: 0.8)];
    r.clampOpenings();
    expect(r.openings.first.offset, 0.8);
  });

  test('góc nhìn 3D: nghiêng và phóng to có giới hạn, xoay thì không', () {
    final v = ViewAngle.initial.copyWith(yaw: 100, pitch: 5, zoom: 99);
    expect(v.yaw, 100);
    expect(v.pitch, 1.4);
    expect(v.zoom, 4);
    expect(ViewAngle.initial.copyWith(pitch: -1, zoom: 0).pitch, 0.2);
    expect(ViewAngle.initial.copyWith(zoom: 0).zoom, 0.5);
  });

  test('đồ cần làm: json đi rồi về, ghi chú trống bỏ đi, đếm theo số lượng', () {
    final plan = planTemplates.values.first();
    plan.rooms[0].items.addAll([Item('Kệ tivi', note: ' '), Item('Tủ giày', qty: 2, note: '1m2')]);
    plan.rooms[1].items.add(Item('Giường'));
    final back = Plan.fromJson(plan.toJson());
    expect(back.rooms[0].items.map((i) => i.toJson()).toList(), [
      {'name': 'Kệ tivi', 'qty': 1},
      {'name': 'Tủ giày', 'qty': 2, 'note': '1m2'},
    ]);
    expect(back.itemCount, 4);
  });

  test('so báo giá theo món với đồ chủ nhà chọn: thêm, đổi số lượng, bỏ', () {
    final asked = [
      {'room': 'PN', 'name': 'Giường', 'qty': 1, 'note': null},
      {'room': 'PN', 'name': 'Tủ', 'qty': 1, 'note': null},
      {'room': 'Khách', 'name': 'Kệ tivi', 'qty': 1, 'note': null},
    ];
    final lines = quoteDiff(asked, [
      {'room': 'PN', 'name': 'Giường', 'qty': 1, 'unit_price': 5},
      {'room': 'PN', 'name': 'Tủ', 'qty': 2, 'unit_price': 7},
      {'room': 'Chung', 'name': 'Nhân công', 'qty': 1, 'unit_price': 3},
    ]);
    expect([
      for (final l in lines) (l.name, l.tag, l.askedQty)
    ], [
      ('Giường', null, 1),
      ('Tủ', 'changed', 1),
      ('Nhân công', 'added', null),
      ('Kệ tivi', 'removed', 1),
    ]);
  });
}
