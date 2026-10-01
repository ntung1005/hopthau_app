// Bản đo nhà: phòng hình chữ nhật trên mặt bằng (mét), cửa đi / cửa sổ trên tường.
// Cùng định dạng và công thức với BE (hopthau_be/src/measurement.ts):
// x sang phải, y xuống dưới, phòng đặt ở góc trên trái; tường n / s dài w, tường e / w dài l.

import 'dart:math' as math;

const roomTypes = {
  'living': 'Phòng khách',
  'bedroom': 'Phòng ngủ',
  'kitchen': 'Bếp',
  'bathroom': 'WC',
  'balcony': 'Ban công',
  'other': 'Khác',
};

const wallNames = {'n': 'Tường trên', 'e': 'Tường phải', 's': 'Tường dưới', 'w': 'Tường trái'};

const cornerNames = {'nw': 'Góc trên trái', 'ne': 'Góc trên phải', 'se': 'Góc dưới phải', 'sw': 'Góc dưới trái'};

const cutKinds = {
  'notch': 'Cắt vuông (cột, hộp kỹ thuật)',
  'chamfer': 'Cắt chéo (góc vát)',
};

/// Góc phòng bị cắt: khoét hình chữ nhật dx × dy (notch) hoặc vát chéo (chamfer). dx theo chiều rộng, dy theo chiều dài.
class CornerCut {
  CornerCut({required this.corner, required this.kind, required this.dx, required this.dy});

  factory CornerCut.fromJson(Map<String, dynamic> j) => CornerCut(
        corner: j['corner'] as String,
        kind: j['kind'] as String,
        dx: (j['dx'] as num).toDouble(),
        dy: (j['dy'] as num).toDouble(),
      );

  String corner;
  String kind;
  double dx;
  double dy;

  Map<String, dynamic> toJson() => {'corner': corner, 'kind': kind, 'dx': _r2(dx), 'dy': _r2(dy)};
}

/// Một cạnh của đa giác phòng. side: n / e / s / w là phần tường chính (có thể có cửa), cut là cạnh do cắt góc.
class Edge {
  const Edge(this.x0, this.y0, this.x1, this.y1, this.side);

  final double x0, y0, x1, y1;
  final String side;

  double get length => math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));

  /// Pháp tuyến hướng ra ngoài phòng (đa giác theo chiều kim đồng hồ, trục y hướng xuống).
  (double, double) get outward {
    final len = length;
    return len == 0 ? (0, 0) : ((y1 - y0) / len, -(x1 - x0) / len);
  }
}

double _r2(num v) => (v * 100).round() / 100;

class Opening {
  Opening(
      {required this.wall, required this.kind, required this.offset, required this.width, required this.height, this.sill = 0});

  factory Opening.fromJson(Map<String, dynamic> j) => Opening(
        wall: j['wall'] as String,
        kind: j['kind'] as String,
        offset: (j['offset'] as num).toDouble(),
        width: (j['width'] as num).toDouble(),
        height: (j['height'] as num).toDouble(),
        sill: (j['sill'] as num? ?? 0).toDouble(),
      );

  /// Cửa đi mặc định 0,9 × 2,1 m; cửa sổ 1,2 × 1,4 m cách sàn 0,9 m.
  factory Opening.door(String wall, double offset) => Opening(wall: wall, kind: 'door', offset: offset, width: 0.9, height: 2.1);
  factory Opening.window(String wall, double offset) =>
      Opening(wall: wall, kind: 'window', offset: offset, width: 1.2, height: 1.4, sill: 0.9);

  String wall;
  String kind;
  double offset;
  double width;
  double height;
  double sill;

  bool get isDoor => kind == 'door';

  Map<String, dynamic> toJson() =>
      {'wall': wall, 'kind': kind, 'offset': _r2(offset), 'width': _r2(width), 'height': _r2(height), 'sill': _r2(sill)};

  Opening copy() => Opening.fromJson(toJson());
}

class Room {
  Room({
    required this.id,
    required this.name,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.l,
    this.h = 2.8,
    List<Opening>? openings,
    List<CornerCut>? cuts,
  })  : openings = openings ?? [],
        cuts = cuts ?? [];

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String? ?? 'other',
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        l: (j['l'] as num).toDouble(),
        h: (j['h'] as num? ?? 2.8).toDouble(),
        openings: [for (final o in (j['openings'] as List? ?? const [])) Opening.fromJson(o as Map<String, dynamic>)],
        cuts: [for (final c in (j['cuts'] as List? ?? const [])) CornerCut.fromJson(c as Map<String, dynamic>)],
      );

  String id;
  String name;
  String type;
  double x;
  double y;
  double w;
  double l;
  double h;
  List<Opening> openings;
  List<CornerCut> cuts;

  double wallLength(String wall) => wall == 'n' || wall == 's' ? w : l;

  CornerCut? cut(String corner) => cuts.where((c) => c.corner == corner).firstOrNull;

  (double, double) _cutSize(String corner) {
    final c = cut(corner);
    return c == null ? (0, 0) : (c.dx, c.dy);
  }

  /// Đoạn tường còn lại (theo offset của cửa) sau khi cắt hai góc ở hai đầu tường. Cùng công thức với BE (wallSpan).
  (double, double) wallSpan(String wall) => switch (wall) {
        'n' => (_cutSize('nw').$1, w - _cutSize('ne').$1),
        's' => (_cutSize('sw').$1, w - _cutSize('se').$1),
        'w' => (_cutSize('nw').$2, l - _cutSize('sw').$2),
        _ => (_cutSize('ne').$2, l - _cutSize('se').$2),
      };

  /// Các cạnh đa giác phòng (m), chiều kim đồng hồ từ góc trên trái. Cùng thuật toán với BE (outline).
  List<Edge> get edges {
    final pts = <(double, double, String)>[]; // điểm và nhãn cạnh đi ra từ điểm đó
    void corner(String k, (double, double) at, (double, double) pin, (double, double) mid, (double, double) pout, String next) {
      final c = cut(k);
      if (c == null) {
        pts.add((at.$1, at.$2, next));
        return;
      }
      pts.add((pin.$1, pin.$2, 'cut'));
      if (c.kind == 'notch') pts.add((mid.$1, mid.$2, 'cut'));
      pts.add((pout.$1, pout.$2, next));
    }

    final (nw, ne, se, sw) = (_cutSize('nw'), _cutSize('ne'), _cutSize('se'), _cutSize('sw'));
    corner('nw', (x, y), (x, y + nw.$2), (x + nw.$1, y + nw.$2), (x + nw.$1, y), 'n');
    corner('ne', (x + w, y), (x + w - ne.$1, y), (x + w - ne.$1, y + ne.$2), (x + w, y + ne.$2), 'e');
    corner('se', (x + w, y + l), (x + w, y + l - se.$2), (x + w - se.$1, y + l - se.$2), (x + w - se.$1, y + l), 's');
    corner('sw', (x, y + l), (x + sw.$1, y + l), (x + sw.$1, y + l - sw.$2), (x, y + l - sw.$2), 'w');
    return [
      for (var i = 0; i < pts.length; i++)
        Edge(pts[i].$1, pts[i].$2, pts[(i + 1) % pts.length].$1, pts[(i + 1) % pts.length].$2, pts[i].$3),
    ];
  }

  /// Diện tích sàn theo đa giác (công thức shoelace).
  double get floorArea {
    var a = 0.0;
    for (final e in edges) {
      a += e.x0 * e.y1 - e.x1 * e.y0;
    }
    return a.abs() / 2;
  }

  double get perimeter => edges.fold<double>(0, (s, e) => s + e.length);

  /// Diện tích tường đã trừ cửa: để bóc khối lượng sơn, ốp.
  double get wallArea => perimeter * h - openings.fold<double>(0, (s, o) => s + o.width * o.height);

  /// Góc cắt và cửa nằm gọn trong phòng, không cao hơn trần. Gọi sau khi đổi kích thước phòng hoặc góc cắt.
  void clampOpenings() {
    // Như BE: hai góc cùng một cạnh chừa ít nhất 10 cm tường.
    const alongX = {'nw': 'ne', 'ne': 'nw', 'sw': 'se', 'se': 'sw'};
    const alongY = {'nw': 'sw', 'sw': 'nw', 'ne': 'se', 'se': 'ne'};
    for (final c in cuts) {
      c.dx = c.dx.clamp(0.05, math.max(0.05, w - 0.1 - _cutSize(alongX[c.corner]!).$1)).toDouble();
      c.dy = c.dy.clamp(0.05, math.max(0.05, l - 0.1 - _cutSize(alongY[c.corner]!).$2)).toDouble();
    }
    for (final o in openings) {
      final (from, to) = wallSpan(o.wall);
      o.width = o.width.clamp(0.2, math.max(0.2, to - from)).toDouble();
      o.offset = o.offset.clamp(from, math.max(from, to - o.width)).toDouble();
      o.height = o.height.clamp(0.2, h).toDouble();
      o.sill = o.sill.clamp(0, math.max(0, h - o.height)).toDouble();
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'x': _r2(x),
        'y': _r2(y),
        'w': _r2(w),
        'l': _r2(l),
        'h': _r2(h),
        'openings': [for (final o in openings) o.toJson()],
        'cuts': [for (final c in cuts) c.toJson()],
      };

  Room copy() => Room.fromJson(toJson());
}

class Plan {
  Plan(this.rooms);

  factory Plan.fromJson(Map<String, dynamic> j) =>
      Plan([for (final r in (j['rooms'] as List? ?? const [])) Room.fromJson(r as Map<String, dynamic>)]);

  final List<Room> rooms;

  double get floorArea => _r2(rooms.fold<double>(0, (s, r) => s + r.floorArea));
  double get wallArea => _r2(rooms.fold<double>(0, (s, r) => s + r.wallArea));

  /// Khung bao (mét) của mọi phòng: (minX, minY, maxX, maxY).
  (double, double, double, double) get bounds {
    if (rooms.isEmpty) return (0, 0, 1, 1);
    return (
      rooms.map((r) => r.x).reduce(math.min),
      rooms.map((r) => r.y).reduce(math.min),
      rooms.map((r) => r.x + r.w).reduce(math.max),
      rooms.map((r) => r.y + r.l).reduce(math.max),
    );
  }

  Map<String, dynamic> toJson() => {
        'rooms': [for (final r in rooms) r.toJson()]
      };

  Plan copy() => Plan.fromJson(toJson());

  String newRoomId() {
    var i = rooms.length + 1;
    while (rooms.any((r) => r.id == 'r$i')) {
      i++;
    }
    return 'r$i';
  }
}

/// Mẫu để bắt đầu: kích thước điển hình của căn NOXH, người dùng sửa theo số đo thật.
final planTemplates = <String, Plan Function()>{
  'Căn 2 phòng ngủ (~56 m²)': () => Plan([
        Room(id: 'r1', name: 'Phòng khách + bếp', type: 'living', x: 0, y: 0, w: 4.0, l: 6.0, openings: [
          Opening.door('s', 0.4),
          Opening.window('w', 1.5),
        ]),
        Room(id: 'r2', name: 'Phòng ngủ 1', type: 'bedroom', x: 4.0, y: 0, w: 3.2, l: 3.4, openings: [
          Opening.door('w', 2.3),
          Opening.window('n', 1.0),
        ]),
        Room(id: 'r3', name: 'Phòng ngủ 2', type: 'bedroom', x: 4.0, y: 3.4, w: 3.2, l: 2.9, openings: [
          Opening.door('w', 0.2),
          Opening.window('e', 0.9),
        ]),
        Room(id: 'r4', name: 'WC', type: 'bathroom', x: 4.0, y: 6.3, w: 1.8, l: 2.0, h: 2.6, openings: [
          Opening.door('n', 0.4),
        ]),
        Room(id: 'r5', name: 'Ban công', type: 'balcony', x: 0, y: 6.0, w: 4.0, l: 1.3, openings: [
          Opening.door('n', 0.4),
        ]),
      ]),
  'Căn 1 phòng ngủ (~42 m²)': () => Plan([
        Room(id: 'r1', name: 'Phòng khách + bếp', type: 'living', x: 0, y: 0, w: 4.2, l: 5.0, openings: [
          Opening.door('s', 0.5),
          Opening.window('w', 1.8),
        ]),
        Room(id: 'r2', name: 'Phòng ngủ', type: 'bedroom', x: 4.2, y: 0, w: 3.2, l: 3.6, openings: [
          Opening.door('w', 2.5),
          Opening.window('e', 1.2),
        ]),
        Room(id: 'r3', name: 'WC', type: 'bathroom', x: 4.2, y: 3.6, w: 1.8, l: 2.2, h: 2.6, openings: [
          Opening.door('w', 0.6),
        ]),
        Room(id: 'r4', name: 'Ban công', type: 'balcony', x: 0, y: 5.0, w: 4.2, l: 1.2, openings: [
          Opening.door('n', 0.5),
        ]),
      ]),
  'Một phòng (đo lẻ từng phòng)': () => Plan([
        Room(id: 'r1', name: 'Phòng ngủ', type: 'bedroom', x: 0, y: 0, w: 3.5, l: 4.0, openings: [
          Opening.door('s', 0.3),
          Opening.window('n', 1.1),
        ]),
      ]),
};
