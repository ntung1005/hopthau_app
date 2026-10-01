// Vẽ bản đo: mặt bằng 2D (tường, cửa đi có cung mở, cửa sổ, kích thước) và khung 3D isometric
// kiểu "nhà búp bê" (tường sau dựng đủ cao, tường trước cắt thấp để nhìn vào trong).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';
import 'model.dart';

const _roomColors = {
  'living': Color(0xFFE8ECFF),
  'bedroom': Color(0xFFFFF3D6),
  'kitchen': Color(0xFFE3F5EA),
  'bathroom': Color(0xFFDDF1F8),
  'balcony': Color(0xFFEFEFF2),
  'other': Color(0xFFF4F5F7),
};

Color roomColor(String type) => _roomColors[type] ?? _roomColors['other']!;

/// Mét ↔ điểm ảnh của mặt bằng 2D, để vẽ và để chạm chọn / kéo phòng dùng chung một phép đổi.
class PlanTransform {
  PlanTransform(Plan plan, Size size, {double padding = 28}) {
    final (minX, minY, maxX, maxY) = plan.bounds;
    final w = math.max(maxX - minX, 1.0), h = math.max(maxY - minY, 1.0);
    scale = math.min((size.width - 2 * padding) / w, (size.height - 2 * padding) / h);
    origin = Offset(
      (size.width - w * scale) / 2 - minX * scale,
      (size.height - h * scale) / 2 - minY * scale,
    );
  }

  late final double scale;
  late final Offset origin;

  Offset toScreen(double x, double y) => origin + Offset(x * scale, y * scale);
  Offset toPlan(Offset p) => (p - origin) / scale;
}

class PlanPainter extends CustomPainter {
  PlanPainter(this.plan, {this.selectedId, this.transform});

  final Plan plan;
  final String? selectedId;

  /// Giữ cố định khi đang kéo phòng, để mặt bằng không tự co giãn dưới ngón tay.
  final PlanTransform? transform;

  @override
  void paint(Canvas canvas, Size size) {
    final t = transform ?? PlanTransform(plan, size);
    _grid(canvas, size, t);
    // Phòng đang chọn vẽ sau cùng để viền nổi lên trên.
    final rooms = [...plan.rooms]..sort((a, b) => (a.id == selectedId ? 1 : 0) - (b.id == selectedId ? 1 : 0));
    for (final r in rooms) {
      _room(canvas, t, r, r.id == selectedId);
    }
  }

  void _grid(Canvas canvas, Size size, PlanTransform t) {
    final p = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final start = t.toPlan(Offset.zero), end = t.toPlan(Offset(size.width, size.height));
    for (var x = start.dx.floorToDouble(); x <= end.dx; x += 1) {
      final sx = t.toScreen(x, 0).dx;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), p);
    }
    for (var y = start.dy.floorToDouble(); y <= end.dy; y += 1) {
      final sy = t.toScreen(0, y).dy;
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), p);
    }
  }

  void _room(Canvas canvas, PlanTransform t, Room r, bool selected) {
    final rect = Rect.fromPoints(t.toScreen(r.x, r.y), t.toScreen(r.x + r.w, r.y + r.l));
    final shape = Path()..addPolygon([for (final e in r.edges) t.toScreen(e.x0, e.y0)], true);
    canvas.drawPath(shape, Paint()..color = roomColor(r.type));
    final wall = Paint()
      ..color = selected ? AppColors.primary : AppColors.text
      ..strokeWidth = selected ? 4 : 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(shape, wall);
    // Phần bị cắt góc: gạch chéo nhẹ để thấy đó là cột / hộp kỹ thuật, không phải khoảng trống.
    if (r.cuts.isNotEmpty) {
      canvas.save();
      canvas.clipPath(Path.combine(PathOperation.difference, Path()..addRect(rect), shape));
      final hatch = Paint()
        ..color = AppColors.muted.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      for (var d = -rect.height; d < rect.width; d += 6) {
        canvas.drawLine(rect.topLeft + Offset(d, rect.height), rect.topLeft + Offset(d + rect.height, 0), hatch);
      }
      canvas.restore();
    }

    for (final o in r.openings) {
      final (a, b, inward) = _openingSegment(t, r, o);
      // Xoá đoạn tường chỗ cửa, rồi vẽ ký hiệu.
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = roomColor(r.type)
            ..strokeWidth = 6);
      if (o.isDoor) {
        final swing = Paint()
          ..color = AppColors.muted
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        final len = (b - a).distance;
        canvas.drawLine(a, a + inward * len, swing);
        final angle = math.atan2((b - a).dy, (b - a).dx);
        final sweep = (inward.dx * (b - a).dy - inward.dy * (b - a).dx) > 0 ? -math.pi / 2 : math.pi / 2;
        canvas.drawArc(Rect.fromCircle(center: a, radius: len), angle, sweep, false, swing);
      } else {
        final glass = Paint()
          ..color = const Color(0xFF3AA0E0)
          ..strokeWidth = 2;
        final n = Offset(-(b - a).dy, (b - a).dx) / (b - a).distance * 2.5;
        canvas.drawLine(a + n, b + n, glass);
        canvas.drawLine(a - n, b - n, glass);
      }
    }

    _label(canvas, rect, r, selected);
    if (selected) _dimensions(canvas, rect, r);
  }

  /// Đoạn cửa trên tường (điểm ảnh) và hướng vào trong phòng.
  (Offset, Offset, Offset) _openingSegment(PlanTransform t, Room r, Opening o) => switch (o.wall) {
        'n' => (t.toScreen(r.x + o.offset, r.y), t.toScreen(r.x + o.offset + o.width, r.y), const Offset(0, 1)),
        's' => (t.toScreen(r.x + o.offset, r.y + r.l), t.toScreen(r.x + o.offset + o.width, r.y + r.l), const Offset(0, -1)),
        'w' => (t.toScreen(r.x, r.y + o.offset), t.toScreen(r.x, r.y + o.offset + o.width), const Offset(1, 0)),
        _ => (t.toScreen(r.x + r.w, r.y + o.offset), t.toScreen(r.x + r.w, r.y + o.offset + o.width), const Offset(-1, 0)),
      };

  void _label(Canvas canvas, Rect rect, Room r, bool selected) {
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: '${r.name}\n',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? AppColors.primary : AppColors.text),
        ),
        TextSpan(text: '${vnDecimal(_fmt(r.floorArea))} m²', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      ]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: math.max(rect.width - 6, 10));
    if (tp.height > rect.height - 4) return; // phòng quá nhỏ trên màn hình: bỏ nhãn
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _dimensions(Canvas canvas, Rect rect, Room r) {
    void text(String s, Offset at, {bool vertical = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(at.dx, at.dy);
      if (vertical) canvas.rotate(-math.pi / 2);
      final box = Rect.fromCenter(center: Offset.zero, width: tp.width + 10, height: tp.height + 4);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(6)), Paint()..color = AppColors.primary);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    text('${vnDecimal(_fmt(r.w))} m', rect.topCenter - const Offset(0, 14));
    text('${vnDecimal(_fmt(r.l))} m', rect.centerLeft - const Offset(14, 0), vertical: true);
  }

  @override
  bool shouldRepaint(PlanPainter old) => true;
}

String _fmt(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : (v * 10 == (v * 10).roundToDouble() ? 1 : 2));

/// Góc nhìn khung 3D: xoay quanh trục đứng (yaw), nghiêng xuống (pitch), phóng to (zoom).
class ViewAngle {
  const ViewAngle({this.yaw = math.pi / 4, this.pitch = 0.6155, this.zoom = 1});

  /// Mặc định: nhìn chéo từ góc dưới phải, nghiêng 35,3° (đúng isometric).
  static const initial = ViewAngle();

  final double yaw;
  final double pitch;
  final double zoom;

  ViewAngle copyWith({double? yaw, double? pitch, double? zoom}) => ViewAngle(
        yaw: yaw ?? this.yaw,
        pitch: (pitch ?? this.pitch).clamp(0.2, 1.4).toDouble(),
        zoom: (zoom ?? this.zoom).clamp(0.5, 4).toDouble(),
      );
}

/// Khung 3D: sàn theo màu phòng, tường dựng theo cạnh đa giác, cửa khoét trên tường. Xoay được theo [view].
class FramePainter extends CustomPainter {
  FramePainter(this.plan, {this.selectedId, this.view = ViewAngle.initial});

  final Plan plan;
  final String? selectedId;
  final ViewAngle view;

  /// Tường quay về phía người xem chỉ dựng tới độ cao này (m) để nhìn thấy trong phòng.
  static const _cutaway = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    if (plan.rooms.isEmpty) return;
    final (minX, minY, maxX, maxY) = plan.bounds;
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final (cosY, sinY) = (math.cos(view.yaw), math.sin(view.yaw));
    final (cosP, sinP) = (math.cos(view.pitch), math.sin(view.pitch));

    /// Xoay mặt bằng quanh tâm: X ngang màn hình, D độ sâu (lớn là gần người xem).
    (double, double) rot(double x, double y) {
      final dx = x - cx, dy = y - cy;
      return (dx * cosY - dy * sinY, dx * sinY + dy * cosY);
    }

    // Co theo đường tròn bao mặt bằng (không theo khung sau khi xoay), để xoay không làm hình phình ra co lại.
    final radius = math.max(0.5, math.sqrt(math.pow(maxX - minX, 2) + math.pow(maxY - minY, 2)) / 2);
    final height = plan.rooms.map((r) => r.h).reduce(math.max);
    const pad = 16.0;
    final spanY = 2 * radius * sinP + height * cosP;
    final s = math.min((size.width - 2 * pad) / (2 * radius), (size.height - 2 * pad) / spanY) * view.zoom;
    // Toạ độ màn hình chạy từ -radius·sin(pitch) - cao·cos(pitch) (đỉnh tường xa) tới radius·sin(pitch) (sàn gần):
    // cộng cao·cos(pitch)/2 trong p() để khoảng đó nằm giữa khung.
    final origin = Offset(size.width / 2, size.height / 2);
    Offset p(double x, double y, double z) {
      final (X, D) = rot(x, y);
      return origin + Offset(X, D * sinP - z * cosP + (height * cosP) / 2) * s;
    }

    // Mặt phẳng cần vẽ, sắp theo độ sâu (x + y lớn là gần người xem): thuật toán hoạ sĩ.
    final faces = <(double, VoidCallback)>[];

    for (final r in plan.rooms) {
      final selected = r.id == selectedId;
      faces.add((
        -1e9,
        () {
          final floor = Path()..addPolygon([for (final e in r.edges) p(e.x0, e.y0, 0)], true);
          canvas.drawPath(floor, Paint()..color = roomColor(r.type));
          canvas.drawPath(
              floor,
              Paint()
                ..color = AppColors.border
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1);
        }
      ));

      for (final e in r.edges) {
        if (e.length < 1e-6) continue;
        // Tường có pháp tuyến quay về phía người xem (sau khi xoay) cắt thấp để nhìn vào trong.
        final (nx, ny) = e.outward;
        final (nX, nD) = (nx * cosY - ny * sinY, nx * sinY + ny * cosY);
        final front = nD > 0.01;
        final top = front ? math.min(_cutaway, r.h) : r.h;
        final depth = rot((e.x0 + e.x1) / 2, (e.y0 + e.y1) / 2).$2 + (front ? 0.3 : 0);
        faces.add((
          depth,
          () {
            // Ánh sáng từ bên trái màn hình: tường càng quay sang phải càng tối.
            final shade = Color.lerp(const Color(0xFFFFFFFF), const Color(0xFFE3E7F0), (nX + 1) / 2)!;
            final quad = Path()..addPolygon([p(e.x0, e.y0, 0), p(e.x1, e.y1, 0), p(e.x1, e.y1, top), p(e.x0, e.y0, top)], true);
            canvas.drawPath(
                quad, Paint()..color = e.side == 'cut' ? const Color(0xFFE4E7EE) : shade.withValues(alpha: front ? 0.92 : 1));
            // Cửa trên tường chính: khung chữ nhật tô màu, cắt theo chiều cao tường đang dựng.
            for (final o in r.openings.where((o) => o.wall == e.side)) {
              final z0 = o.sill, z1 = math.min(o.sill + o.height, top);
              if (z1 <= z0) continue;
              final (a, b) = switch (o.wall) {
                'n' => ((r.x + o.offset, r.y), (r.x + o.offset + o.width, r.y)),
                's' => ((r.x + o.offset, r.y + r.l), (r.x + o.offset + o.width, r.y + r.l)),
                'w' => ((r.x, r.y + o.offset), (r.x, r.y + o.offset + o.width)),
                _ => ((r.x + r.w, r.y + o.offset), (r.x + r.w, r.y + o.offset + o.width)),
              };
              final hole = Path()..addPolygon([p(a.$1, a.$2, z0), p(b.$1, b.$2, z0), p(b.$1, b.$2, z1), p(a.$1, a.$2, z1)], true);
              canvas.drawPath(hole, Paint()..color = o.isDoor ? const Color(0xFFB98A5E) : const Color(0xFF9FD3F2));
              canvas.drawPath(
                  hole,
                  Paint()
                    ..color = AppColors.text.withValues(alpha: 0.5)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1);
            }
            canvas.drawPath(
              quad,
              Paint()
                ..color = selected ? AppColors.primary : AppColors.text.withValues(alpha: 0.75)
                ..style = PaintingStyle.stroke
                ..strokeWidth = selected ? 2.2 : 1.4,
            );
          }
        ));
      }
    }

    faces.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in faces) {
      draw();
    }
  }

  @override
  bool shouldRepaint(FramePainter old) => true;
}
