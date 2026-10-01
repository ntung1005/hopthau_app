// Đo nhà: chủ nhà tự đo từng phòng (dài, rộng, cao, cửa), app dựng mặt bằng 2D và khung 3D,
// tính diện tích, rồi gửi kèm yêu cầu báo giá để nhà thầu lên báo giá sơ bộ trước khi khảo sát.
// ponytail: nhập số đo bằng tay; đo bằng camera (ARKit / ARCore / RoomPlan) khi có bản app native.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../measure/model.dart';
import '../measure/painters.dart';
import '../theme.dart';
import 'account.dart';
import 'common.dart';
import 'requests.dart';

typedef Json = Map<String, dynamic>;

String _m(num v) => vnDecimal((v * 100).round() / 100);

/// Danh sách bản đo của tôi.
class MeasurementsScreen extends StatelessWidget {
  const MeasurementsScreen({super.key});

  static Future<void> open(BuildContext context) async {
    if (!await ensureSignedIn(context) || !context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const MeasurementsScreen()));
  }

  Future<void> _create(BuildContext context, VoidCallback reload) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Bắt đầu từ mẫu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Chọn mẫu gần giống nhà bạn, rồi sửa lại theo số đo thật.', style: TextStyle(color: AppColors.muted)),
          ),
          for (final t in planTemplates.keys)
            ListTile(
              leading: const IconBadge(Icons.grid_view_rounded, size: 40),
              title: Text(t),
              onTap: () => Navigator.pop(context, t),
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (name == null || !context.mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => MeasurementEditorScreen(initialPlan: planTemplates[name]!(), initialName: 'Nhà của tôi')));
    reload();
  }

  @override
  Widget build(BuildContext context) => Loader<List<dynamic>>(
        load: () async => await api.getAuth('/measurements') as List<dynamic>,
        builder: (context, rows, reload) => Scaffold(
          appBar: AppBar(
            title: const Text('Bản đo nhà'),
            actions: [
              IconButton(tooltip: 'Cách đo', icon: const Icon(Icons.help_outline), onPressed: () => showMeasureGuide(context))
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => _create(context, reload),
              icon: const Icon(Icons.straighten),
              label: const Text('Đo nhà mới'),
            ),
          ),
          body: rows.isEmpty
              ? ListView(children: [
                  const EmptyState(
                    icon: Icons.straighten,
                    title: 'Tự đo nhà, nhận báo giá sát hơn',
                    body: 'Đo dài, rộng, cao từng phòng và vị trí cửa bằng thước. App dựng mặt bằng, khung 3D và tính diện tích '
                        'để nhà thầu báo giá sơ bộ, đỡ phải đến khảo sát nhiều lần.',
                  ),
                  Center(child: TextButton(onPressed: () => showMeasureGuide(context), child: const Text('Xem cách đo'))),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
                  for (final m in rows.cast<Json>())
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => MeasurementEditorScreen(existing: m)));
                          reload();
                        },
                        child: Row(children: [
                          SizedBox(
                            width: 110,
                            height: 96,
                            child: ColoredBox(
                              color: AppColors.field,
                              child: CustomPaint(painter: FramePainter(Plan.fromJson(m['data'] as Json))),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${m['name']}', style: Theme.of(context).textTheme.titleMedium),
                              Text(
                                '${(m['data']['rooms'] as List).length} phòng · sàn ${_m(m['summary']['floor_m2'] as num)} m²'
                                '${m['unit_type'] != null ? '\n${m['unit_type']['project']['name']} · ${m['unit_type']['name']}' : ''}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                          const SizedBox(width: 8),
                        ]),
                      ),
                    ),
                ]),
        ),
      );
}

void showMeasureGuide(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, controller) =>
            ListView(controller: controller, padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
          Text('Cách đo nhà trong 15 phút', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Cần: thước dây hoặc thước laser, điện thoại. Nên đo khi nhà còn trống.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          for (final (i, (title, body)) in const [
            (
              'Đo sát chân tường',
              'Đo chiều dài và chiều rộng phòng ở sát sàn, từ mép tường này sang mép tường kia. Đo 2 lần, lấy số nhỏ hơn.'
            ),
            ('Chiều cao trần', 'Đo từ sàn lên trần ở giữa phòng. Căn hộ thường 2,7 - 3,0 m; WC thấp hơn nếu có trần giả.'),
            (
              'Cửa đi, cửa sổ',
              'Đo khoảng cách từ góc tường tới mép cửa, rồi đo rộng, cao của cửa. Cửa sổ đo thêm từ sàn tới bậu.'
            ),
            ('Xếp phòng', 'Kéo các phòng trên mặt bằng cho sát nhau như thực tế. Phòng tự hít vào mép phòng bên cạnh.'),
            ('Chụp ảnh bổ sung', 'Khi gửi yêu cầu, ghi chú những chỗ đặc biệt: cột, dầm, ống nước, ổ điện cần giữ.'),
          ].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(body, style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          const InfoPanel(children: [
            Text('Số đo để nhà thầu báo giá sơ bộ. Trước khi sản xuất, nhà thầu vẫn đo lại tại nhà để chốt kích thước.',
                style: TextStyle(color: AppColors.primary)),
          ]),
        ]),
      ),
    );

/// Khung vẽ 2D / 3D dùng chung cho trình dựng và màn xem.
class PlanCanvas extends StatefulWidget {
  const PlanCanvas(
      {super.key, required this.plan, required this.threeD, this.selectedId, this.onSelect, this.onChanged, this.height = 320});

  final Plan plan;
  final bool threeD;
  final String? selectedId;
  final ValueChanged<String?>? onSelect;

  /// Có thì cho kéo phòng (chỉ ở 2D).
  final VoidCallback? onChanged;
  final double height;

  @override
  State<PlanCanvas> createState() => _PlanCanvasState();
}

class _PlanCanvasState extends State<PlanCanvas> {
  // Góc nhìn 3D giữ nguyên khi chuyển qua lại 2D / 3D.
  var _view = ViewAngle.initial;
  var _viewAtStart = ViewAngle.initial;

  PlanTransform? _drag;
  Room? _dragRoom;
  Offset _dragDelta = Offset.zero;
  Offset _dragStart = Offset.zero;

  Room? _hit(PlanTransform t, Offset local) {
    final p = t.toPlan(local);
    for (final r in widget.plan.rooms.reversed) {
      if (_inside(r, p.dx, p.dy)) return r;
    }
    return null;
  }

  /// Điểm trong đa giác phòng (tia ngang, đếm số lần cắt cạnh): phần góc đã cắt không bắt chạm.
  bool _inside(Room r, double x, double y) {
    var inside = false;
    for (final e in r.edges) {
      if ((e.y0 > y) != (e.y1 > y) && x < (e.x1 - e.x0) * (y - e.y0) / (e.y1 - e.y0) + e.x0) inside = !inside;
    }
    return inside;
  }

  /// Hít vào mép phòng khác trong 15 cm, còn lại làm tròn 5 cm.
  double _snap(double v, double size, Iterable<double> edges) {
    for (final e in edges) {
      if ((v - e).abs() < 0.15) return e;
      if ((v + size - e).abs() < 0.15) return e - size;
    }
    return (v * 20).round() / 20;
  }

  /// Khung 3D xoay được: kéo ngang xoay quanh trục đứng, kéo dọc đổi góc nghiêng, chụm 2 ngón / cuộn chuột phóng to,
  /// chạm đúp đặt lại. Nút xoay 90° cho người không quen kéo.
  Widget _frame(Size size) {
    Widget button(IconData icon, String tip, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: AppColors.surface,
            shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
            child: IconButton(
              tooltip: tip,
              visualDensity: VisualDensity.compact,
              icon: Icon(icon, size: 20, color: AppColors.primary),
              onPressed: onTap,
            ),
          ),
        );
    return Stack(children: [
      Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            setState(() => _view = _view.copyWith(zoom: _view.zoom * (e.scrollDelta.dy > 0 ? 0.9 : 1.1)));
          }
        },
        child: GestureDetector(
          onDoubleTap: () => setState(() => _view = ViewAngle.initial),
          onScaleStart: (_) => _viewAtStart = _view,
          onScaleUpdate: (d) => setState(() {
            _view = _view.copyWith(
              yaw: _view.yaw - d.focalPointDelta.dx * 0.012,
              pitch: _view.pitch + d.focalPointDelta.dy * 0.006,
              zoom: d.pointerCount > 1 ? _viewAtStart.zoom * d.scale : null,
            );
          }),
          child: CustomPaint(size: size, painter: FramePainter(widget.plan, selectedId: widget.selectedId, view: _view)),
        ),
      ),
      Positioned(
        right: 8,
        bottom: 8,
        child: Row(children: [
          button(Icons.rotate_left_rounded, 'Xoay trái 90°',
              () => setState(() => _view = _view.copyWith(yaw: _view.yaw + math.pi / 2))),
          button(Icons.rotate_right_rounded, 'Xoay phải 90°',
              () => setState(() => _view = _view.copyWith(yaw: _view.yaw - math.pi / 2))),
          button(Icons.center_focus_strong_outlined, 'Góc nhìn ban đầu', () => setState(() => _view = ViewAngle.initial)),
        ]),
      ),
      const Positioned(
        left: 10,
        top: 8,
        child: Text('Kéo để xoay · chụm hoặc cuộn để phóng to', style: TextStyle(color: AppColors.muted, fontSize: 11)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        child: LayoutBuilder(builder: (context, c) {
          final size = Size(c.maxWidth, widget.height);
          if (widget.threeD) return _frame(size);
          final editable = widget.onChanged != null;
          return GestureDetector(
            onTapUp: (d) => widget.onSelect?.call(_hit(PlanTransform(widget.plan, size), d.localPosition)?.id),
            onPanStart: !editable
                ? null
                : (d) {
                    final t = PlanTransform(widget.plan, size);
                    final r = _hit(t, d.localPosition);
                    if (r == null) return;
                    widget.onSelect?.call(r.id);
                    setState(() {
                      _drag = t;
                      _dragRoom = r;
                      _dragStart = Offset(r.x, r.y);
                      _dragDelta = Offset.zero;
                    });
                  },
            onPanUpdate: !editable
                ? null
                : (d) {
                    final r = _dragRoom, t = _drag;
                    if (r == null || t == null) return;
                    _dragDelta += d.delta / t.scale;
                    final others = widget.plan.rooms.where((o) => o != r);
                    r.x = _snap(_dragStart.dx + _dragDelta.dx, r.w, others.expand((o) => [o.x, o.x + o.w]));
                    r.y = _snap(_dragStart.dy + _dragDelta.dy, r.l, others.expand((o) => [o.y, o.y + o.l]));
                    setState(() {});
                    widget.onChanged!();
                  },
            onPanEnd: !editable ? null : (_) => setState(() => _drag = _dragRoom = null),
            child: CustomPaint(size: size, painter: PlanPainter(widget.plan, selectedId: widget.selectedId, transform: _drag)),
          );
        }),
      );
}

class _Summary extends StatelessWidget {
  const _Summary(this.plan);

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    Widget stat(String v, String label) => Expanded(
          child: Column(children: [
            Text(v, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary)),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        );
    final doors = plan.rooms.fold<int>(0, (s, r) => s + r.openings.where((o) => o.isDoor).length);
    final windows = plan.rooms.fold<int>(0, (s, r) => s + r.openings.where((o) => !o.isDoor).length);
    return Row(children: [
      stat('${plan.rooms.length}', 'phòng'),
      stat('${_m(plan.floorArea)} m²', 'sàn'),
      stat('${_m(plan.wallArea)} m²', 'tường (trừ cửa)'),
      stat('$doors · $windows', 'cửa đi · sổ'),
    ]);
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.threeD, required this.onChanged});

  final bool threeD;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Mặt bằng 2D'), icon: Icon(Icons.grid_on)),
          ButtonSegment(value: true, label: Text('Khung 3D'), icon: Icon(Icons.view_in_ar)),
        ],
        selected: {threeD},
        onSelectionChanged: (s) => onChanged(s.first),
      );
}

/// Dựng / sửa bản đo.
class MeasurementEditorScreen extends StatefulWidget {
  const MeasurementEditorScreen({super.key, this.existing, this.initialPlan, this.initialName, this.startThreeD = false});

  final Json? existing;
  final Plan? initialPlan;
  final String? initialName;
  final bool startThreeD;

  @override
  State<MeasurementEditorScreen> createState() => _MeasurementEditorScreenState();
}

class _MeasurementEditorScreenState extends State<MeasurementEditorScreen> {
  late Json? _saved = widget.existing;
  late final Plan _plan = widget.existing != null ? Plan.fromJson(widget.existing!['data'] as Json) : widget.initialPlan!;
  late String _name = widget.existing?['name'] as String? ?? widget.initialName ?? 'Nhà của tôi';
  late String? _selected = _plan.rooms.firstOrNull?.id;
  late var _threeD = widget.startThreeD;
  var _dirty = false;
  var _busy = false;

  Room? get _room => _plan.rooms.where((r) => r.id == _selected).firstOrNull;

  void _changed() => setState(() => _dirty = true);

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final body = {'name': _name, 'data': _plan.toJson(), 'unit_type_id': _saved?['unit_type_id']};
      final res = (_saved == null
          ? await api.postAuth('/measurements', body)
          : await api.putAuth('/measurements/${_saved!['id']}', body)) as Json;
      setState(() {
        _saved = res;
        _dirty = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu bản đo')));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_dirty || _saved == null) await _save();
    if (_saved == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuoteRequestScreen(title: 'Yêu cầu báo giá', measurementId: _saved!['id'] as String)),
    );
  }

  Future<void> _rename() async {
    final c = TextEditingController(text: _name);
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tên bản đo'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Đổi')),
        ],
      ),
    );
    if (v != null && v.isNotEmpty) {
      setState(() {
        _name = v;
        _dirty = true;
      });
    }
  }

  void _addRoom() {
    final (_, _, maxX, _) = _plan.bounds;
    final r = Room(
        id: _plan.newRoomId(),
        name: 'Phòng mới',
        type: 'other',
        x: _plan.rooms.isEmpty ? 0 : maxX,
        y: 0,
        w: 3,
        l: 3,
        openings: [Opening.door('w', 1)]);
    setState(() {
      _plan.rooms.add(r);
      _selected = r.id;
      _dirty = true;
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá bản đo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true || _saved == null) return;
    try {
      await api.deleteAuth('/measurements/${_saved!['id']}');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _editCut(Room r, [CornerCut? existing]) async {
    final free = cornerNames.keys.where((k) => r.cut(k) == null || r.cut(k) == existing).toList();
    if (free.isEmpty) return;
    final result = await showModalBottomSheet<(String, CornerCut?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CornerSheet(room: r, initial: existing, corners: free),
    );
    if (result == null) return;
    setState(() {
      r.cuts.removeWhere((c) => c.corner == result.$1 || identical(c, existing));
      if (result.$2 != null) r.cuts.add(result.$2!);
      r.clampOpenings();
      _dirty = true;
    });
  }

  Future<void> _editOpening(Room r, [Opening? existing]) async {
    final draft = existing?.copy() ?? Opening.door('s', 0.3);
    final result = await showModalBottomSheet<Opening?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OpeningSheet(room: r, opening: draft, isNew: existing == null),
    );
    if (result == null) return;
    setState(() {
      if (identical(result, _OpeningSheet.deleted)) {
        r.openings.remove(existing);
      } else if (existing == null) {
        r.openings.add(result);
      } else {
        r.openings[r.openings.indexOf(existing)] = result;
      }
      r.clampOpenings();
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _room;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Chưa lưu thay đổi'),
            content: const Text('Thoát mà không lưu?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ở lại')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Thoát')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(onTap: _rename, child: Text(_name)),
          actions: [
            IconButton(tooltip: 'Cách đo', icon: const Icon(Icons.help_outline), onPressed: () => showMeasureGuide(context)),
            if (_saved != null) IconButton(tooltip: 'Xoá bản đo', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 150), children: [
          _ViewToggle(threeD: _threeD, onChanged: (v) => setState(() => _threeD = v)),
          const SizedBox(height: 12),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: PlanCanvas(
              plan: _plan,
              threeD: _threeD,
              selectedId: _selected,
              onSelect: (id) => setState(() => _selected = id ?? _selected),
              onChanged: _changed,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
                _threeD
                    ? 'Khung dựng từ số đo. Tường phía trước cắt thấp để nhìn vào trong; kéo để xoay.'
                    : 'Chạm để chọn phòng, kéo để xếp phòng.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: _Summary(_plan))),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final room in _plan.rooms)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(room.name),
                    selected: room.id == _selected,
                    onSelected: (_) => setState(() => _selected = room.id),
                    avatar: CircleAvatar(backgroundColor: roomColor(room.type), radius: 8),
                  ),
                ),
              ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Thêm phòng'), onPressed: _addRoom),
            ]),
          ),
          if (r != null)
            _RoomPanel(
              key: ValueKey(r.id),
              room: r,
              onChanged: _changed,
              onEditOpening: (o) => _editOpening(r, o),
              onEditCut: (c) => _editCut(r, c),
              onDelete: _plan.rooms.length <= 1
                  ? null
                  : () => setState(() {
                        _plan.rooms.remove(r);
                        _selected = _plan.rooms.first.id;
                        _dirty = true;
                      }),
            ),
        ]),
        bottomSheet: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || (!_dirty && _saved != null) ? null : _save,
                  child: Text(_dirty || _saved == null ? 'Lưu' : 'Đã lưu'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Gửi nhà thầu báo giá'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RoomPanel extends StatelessWidget {
  const _RoomPanel({
    super.key,
    required this.room,
    required this.onChanged,
    required this.onEditOpening,
    required this.onEditCut,
    this.onDelete,
  });

  final Room room;
  final VoidCallback onChanged;
  final void Function(Opening? existing) onEditOpening;
  final void Function(CornerCut? existing) onEditCut;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final r = room;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: r.name,
                decoration: const InputDecoration(labelText: 'Tên phòng'),
                onChanged: (v) {
                  r.name = v.trim().isEmpty ? 'Phòng' : v.trim();
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: r.type,
                decoration: const InputDecoration(labelText: 'Loại'),
                items: [for (final e in roomTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) {
                  r.type = v ?? r.type;
                  onChanged();
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: MeterField(
                    label: 'Rộng (ngang)',
                    value: r.w,
                    min: 0.3,
                    max: 30,
                    onChanged: (v) {
                      r.w = v;
                      r.clampOpenings();
                      onChanged();
                    })),
            const SizedBox(width: 8),
            Expanded(
                child: MeterField(
                    label: 'Dài (dọc)',
                    value: r.l,
                    min: 0.3,
                    max: 30,
                    onChanged: (v) {
                      r.l = v;
                      r.clampOpenings();
                      onChanged();
                    })),
            const SizedBox(width: 8),
            Expanded(
                child: MeterField(
                    label: 'Cao trần',
                    value: r.h,
                    min: 1.8,
                    max: 6,
                    onChanged: (v) {
                      r.h = v;
                      r.clampOpenings();
                      onChanged();
                    })),
          ]),
          const SizedBox(height: 8),
          Text('Sàn ${_m(r.floorArea)} m² · chu vi ${_m(r.perimeter)} m · tường ${_m(r.wallArea)} m²',
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
          Text('Góc phòng', style: Theme.of(context).textTheme.titleSmall),
          const Text('Góc có cột, hộp kỹ thuật hoặc bị vát thì cắt bớt để diện tích đúng thực tế.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          for (final c in r.cuts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(c.kind == 'notch' ? Icons.crop_square_rounded : Icons.change_history_rounded, color: AppColors.primary),
              title: Text('${cornerNames[c.corner]} · ${c.kind == 'notch' ? 'cắt vuông' : 'cắt chéo'}'),
              subtitle: Text('${_m(c.dx)} m theo chiều rộng × ${_m(c.dy)} m theo chiều dài'),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => onEditCut(c),
            ),
          if (r.cuts.length < 4)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  onPressed: () => onEditCut(null), icon: const Icon(Icons.content_cut_rounded), label: const Text('Cắt góc')),
            ),
          const Divider(),
          const SizedBox(height: 8),
          Text('Cửa (${r.openings.length})', style: Theme.of(context).textTheme.titleSmall),
          for (final o in r.openings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(o.isDoor ? Icons.door_front_door_outlined : Icons.window_outlined, color: AppColors.primary),
              title: Text('${o.isDoor ? 'Cửa đi' : 'Cửa sổ'} · ${wallNames[o.wall]}'),
              subtitle: Text('cách góc ${_m(o.offset)} m · rộng ${_m(o.width)} × cao ${_m(o.height)} m'
                  '${o.isDoor ? '' : ' · bậu ${_m(o.sill)} m'}'),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => onEditOpening(o),
            ),
          Row(children: [
            TextButton.icon(onPressed: () => onEditOpening(null), icon: const Icon(Icons.add), label: const Text('Thêm cửa')),
            const Spacer(),
            if (onDelete != null)
              TextButton.icon(
                onPressed: onDelete,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Xoá phòng'),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Ô nhập số mét ("3,45"); chỉ báo khi số hợp lệ trong [min, max].
class MeterField extends StatefulWidget {
  const MeterField(
      {super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  State<MeterField> createState() => _MeterFieldState();
}

class _MeterFieldState extends State<MeterField> {
  late final _c = TextEditingController(text: _m(widget.value));
  String? _error;

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: widget.label, suffixText: 'm', errorText: _error),
        onChanged: (s) {
          final v = double.tryParse(s.trim().replaceAll(',', '.'));
          final ok = v != null && v >= widget.min && v <= widget.max;
          setState(() => _error = ok ? null : '${_m(widget.min)} - ${_m(widget.max)} m');
          if (ok) widget.onChanged(v);
        },
      );
}

/// Cắt một góc phòng: chọn góc, kiểu cắt, kích thước; xem trước hình phòng.
/// Trả về (góc, cắt); cắt null nghĩa là bỏ cắt góc đó.
class _CornerSheet extends StatefulWidget {
  const _CornerSheet({required this.room, required this.corners, this.initial});

  final Room room;
  final List<String> corners;
  final CornerCut? initial;

  @override
  State<_CornerSheet> createState() => _CornerSheetState();
}

class _CornerSheetState extends State<_CornerSheet> {
  late String _corner = widget.initial?.corner ?? widget.corners.first;
  late String _kind = widget.initial?.kind ?? 'notch';
  late double _dx = widget.initial?.dx ?? 0.4;
  late double _dy = widget.initial?.dy ?? 0.4;

  /// Phòng xem trước: bản sao đặt ở gốc toạ độ, thay góc đang sửa bằng giá trị trong form.
  Room get _preview {
    final r = widget.room.copy()
      ..x = 0
      ..y = 0
      ..openings = [];
    r.cuts
      ..removeWhere((c) => c.corner == _corner || c.corner == widget.initial?.corner)
      ..add(CornerCut(corner: _corner, kind: _kind, dx: _dx, dy: _dy));
    r.clampOpenings();
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final cut = preview.cut(_corner)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.initial == null ? 'Cắt góc phòng' : 'Sửa góc cắt', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${widget.room.name}: ${_m(widget.room.w)} × ${_m(widget.room.l)} m. Sàn còn ${_m(preview.floorArea)} m².',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(AppRadius.field)),
              child: CustomPaint(painter: PlanPainter(Plan([preview]), selectedId: preview.id)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Góc', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                // Lưới 2 × 2 đúng vị trí góc trên mặt bằng.
                for (final row in const [
                  ['nw', 'ne'],
                  ['sw', 'se'],
                ])
                  Wrap(spacing: 6, children: [
                    for (final k in row)
                      ChoiceChip(
                        label: Text(cornerNames[k]!.replaceFirst('Góc ', '')),
                        selected: _corner == k,
                        onSelected: widget.corners.contains(k) ? (_) => setState(() => _corner = k) : null,
                      ),
                  ]),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'notch', label: Text('Cắt vuông'), icon: Icon(Icons.crop_square_rounded)),
              ButtonSegment(value: 'chamfer', label: Text('Cắt chéo'), icon: Icon(Icons.change_history_rounded)),
            ],
            selected: {_kind},
            onSelectionChanged: (v) => setState(() => _kind = v.first),
          ),
          const SizedBox(height: 6),
          Text(cutKinds[_kind]!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: MeterField(
                  label: 'Theo chiều rộng',
                  value: _dx,
                  min: 0.05,
                  max: widget.room.w - 0.1,
                  onChanged: (v) => setState(() => _dx = v)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MeterField(
                  label: 'Theo chiều dài',
                  value: _dy,
                  min: 0.05,
                  max: widget.room.l - 0.1,
                  onChanged: (v) => setState(() => _dy = v)),
            ),
          ]),
          if ((cut.dx - _dx).abs() > 1e-9 || (cut.dy - _dy).abs() > 1e-9)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Góc bên cạnh cũng đã cắt nên kích thước được giới hạn còn ${_m(cut.dx)} × ${_m(cut.dy)} m.',
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context, (_corner, cut)), child: const Text('Cắt góc')),
          if (widget.initial != null)
            TextButton(
              onPressed: () => Navigator.pop(context, (widget.initial!.corner, null)),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Bỏ cắt góc này'),
            ),
        ]),
      ),
    );
  }
}

class _OpeningSheet extends StatefulWidget {
  const _OpeningSheet({required this.room, required this.opening, required this.isNew});

  final Room room;
  final Opening opening;
  final bool isNew;

  /// Trả về khi người dùng xoá cửa.
  static final deleted = Opening(wall: 'n', kind: 'door', offset: 0, width: 0, height: 0);

  @override
  State<_OpeningSheet> createState() => _OpeningSheetState();
}

class _OpeningSheetState extends State<_OpeningSheet> {
  late final Opening o = widget.opening;
  var _rev = 0; // đổi loại / tường thì dựng lại các ô số với giá trị mới

  void _kind(String kind) => setState(() {
        final d = kind == 'door' ? Opening.door(o.wall, o.offset) : Opening.window(o.wall, o.offset);
        o
          ..kind = kind
          ..width = d.width
          ..height = d.height
          ..sill = d.sill;
        _rev++;
      });

  @override
  Widget build(BuildContext context) {
    final (from, to) = widget.room.wallSpan(o.wall);
    final len = widget.room.wallLength(o.wall);
    final trimmed = from > 0 || to < len;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.isNew ? 'Thêm cửa' : 'Sửa cửa', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'door', label: Text('Cửa đi'), icon: Icon(Icons.door_front_door_outlined)),
              ButtonSegment(value: 'window', label: Text('Cửa sổ'), icon: Icon(Icons.window_outlined)),
            ],
            selected: {o.kind},
            onSelectionChanged: (s) => _kind(s.first),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              for (final e in wallNames.entries) ButtonSegment(value: e.key, label: Text(e.value.replaceFirst('Tường ', '')))
            ],
            selected: {o.wall},
            onSelectionChanged: (s) => setState(() {
              o.wall = s.first;
              _rev++;
            }),
          ),
          const SizedBox(height: 6),
          Text(
              '${wallNames[o.wall]} dài ${_m(len)} m${trimmed ? ', đặt cửa được từ ${_m(from)} đến ${_m(to)} m (phần còn lại đã cắt góc)' : ''}. '
              'Khoảng cách tính từ góc trái (tường trên / dưới) hoặc góc trên (tường trái / phải).',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(key: ValueKey(_rev), children: [
            Expanded(child: MeterField(label: 'Cách góc', value: o.offset, min: from, max: to, onChanged: (v) => o.offset = v)),
            const SizedBox(width: 8),
            Expanded(child: MeterField(label: 'Rộng', value: o.width, min: 0.2, max: to - from, onChanged: (v) => o.width = v)),
            const SizedBox(width: 8),
            Expanded(
                child: MeterField(label: 'Cao', value: o.height, min: 0.2, max: widget.room.h, onChanged: (v) => o.height = v)),
            if (!o.isDoor) ...[
              const SizedBox(width: 8),
              Expanded(child: MeterField(label: 'Bậu', value: o.sill, min: 0, max: widget.room.h, onChanged: (v) => o.sill = v)),
            ],
          ]),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context, o), child: const Text('Xong')),
          if (!widget.isNew)
            TextButton(
              onPressed: () => Navigator.pop(context, _OpeningSheet.deleted),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Xoá cửa'),
            ),
        ]),
      ),
    );
  }
}

/// Xem bản đo (nhà thầu, hoặc chủ nhà xem lại): 2D / 3D, bảng số liệu từng phòng.
class MeasurementViewerScreen extends StatefulWidget {
  const MeasurementViewerScreen({super.key, required this.id});

  final String id;

  static void open(BuildContext context, String id) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => MeasurementViewerScreen(id: id)));

  @override
  State<MeasurementViewerScreen> createState() => _MeasurementViewerScreenState();
}

class _MeasurementViewerScreenState extends State<MeasurementViewerScreen> {
  var _threeD = true;
  String? _selected;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bản đo của khách')),
        body: Loader<Json>(
          load: () async => await api.getAuth('/measurements/${widget.id}') as Json,
          builder: (context, m, _) {
            final plan = Plan.fromJson(m['data'] as Json);
            final summary = m['summary'] as Json;
            return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
              InfoPanel(children: [
                Text('${m['name']}', style: Theme.of(context).textTheme.titleMedium),
                const Text('Chủ nhà tự đo bằng thước. Dùng để báo giá sơ bộ, đo lại tại nhà trước khi sản xuất.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ]),
              const SizedBox(height: 12),
              _ViewToggle(threeD: _threeD, onChanged: (v) => setState(() => _threeD = v)),
              const SizedBox(height: 12),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: PlanCanvas(
                    plan: plan, threeD: _threeD, selectedId: _selected, onSelect: (id) => setState(() => _selected = id)),
              ),
              const SizedBox(height: 12),
              Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: _Summary(plan))),
              const SectionTitle('Khối lượng từng phòng'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Table(
                  columnWidths: const {0: FlexColumnWidth(2.2)},
                  border: const TableBorder(horizontalInside: BorderSide(color: AppColors.border)),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: AppColors.primarySoft),
                      children: [
                        for (final h in const ['Phòng', 'Kích thước', 'Sàn', 'Tường']) _cell(h, bold: true)
                      ],
                    ),
                    for (final (i, row) in (summary['rooms'] as List).cast<Json>().indexed)
                      TableRow(
                        decoration: BoxDecoration(
                            color: plan.rooms[i].id == _selected ? AppColors.primarySoft.withValues(alpha: 0.5) : null),
                        children: [
                          _cell('${row['name']}'),
                          _cell('${_m(plan.rooms[i].w)} × ${_m(plan.rooms[i].l)} × ${_m(plan.rooms[i].h)}'),
                          _cell('${_m(row['floor_m2'] as num)} m²'),
                          _cell('${_m(row['wall_m2'] as num)} m²'),
                        ],
                      ),
                    TableRow(children: [
                      _cell('Tổng', bold: true),
                      _cell(''),
                      _cell('${_m(summary['floor_m2'] as num)} m²', bold: true),
                      _cell('${_m(summary['wall_m2'] as num)} m²', bold: true),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text('Kích thước: rộng × dài × cao (m). Tường đã trừ diện tích cửa đi, cửa sổ.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ]);
          },
        ),
      );

  Widget _cell(String s, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(s, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w600 : null)),
      );
}

/// Chọn bản đo để đính kèm yêu cầu báo giá.
class MeasurementPicker extends StatefulWidget {
  const MeasurementPicker({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<MeasurementPicker> createState() => _MeasurementPickerState();
}

class _MeasurementPickerState extends State<MeasurementPicker> {
  late Future<dynamic> _future = api.getAuth('/measurements');

  String? get value => widget.value;
  ValueChanged<String?> get onChanged => widget.onChanged;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _future,
        builder: (context, snap) {
          final rows = (snap.data as List?)?.cast<Json>() ?? const [];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String?>(
              key: ValueKey('${rows.length}-$value'),
              initialValue: rows.any((m) => m['id'] == value) ? value : null,
              decoration: const InputDecoration(labelText: 'Đính kèm bản đo nhà', prefixIcon: Icon(Icons.straighten)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Không đính kèm')),
                for (final m in rows)
                  DropdownMenuItem(
                      value: m['id'] as String, child: Text('${m['name']} · ${_m(m['summary']['floor_m2'] as num)} m²')),
              ],
              onChanged: onChanged,
            ),
            if (rows.isEmpty && snap.hasData)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await MeasurementsScreen.open(context);
                    if (mounted) setState(() => _future = api.getAuth('/measurements'));
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Tự đo nhà để báo giá sát hơn'),
                ),
              ),
          ]);
        },
      );
}
