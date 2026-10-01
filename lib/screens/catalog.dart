// Dự án → mẫu căn → danh sách gói (so sánh tối đa 3) → chi tiết gói.

import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';
import 'account.dart';
import 'requests.dart';
import 'common.dart';
import 'contractor_profile.dart';
import '../photos.dart';

typedef Json = Map<String, dynamic>;

List<Json> _list(dynamic data) => (data as List).cast<Json>();

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => await api.get('/projects/$slug') as Json,
        builder: (context, project, _) => Scaffold(
          appBar: AppBar(title: Text(project['name'] as String)),
          body: ListView(children: [
            const SectionTitle('Chọn mẫu căn của bạn'),
            for (final u in _list(project['unit_types']))
              RowCard(
                icon: Icons.space_dashboard_outlined,
                title: u['name'] as String,
                subtitle: '${vnDecimal(u['area_m2'])} m² · ${u['bedrooms']} phòng ngủ · ${u['bathrooms']} WC',
                trailing: FromPrice(u['min_price'] as num?),
                onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PackagesScreen(project: project, unitType: u))),
              ),
          ]),
        ),
      );
}

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key, required this.project, required this.unitType});

  final Json project;
  final Json unitType;

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  static const _maxCompare = 3;
  final _picked = <Json>[];

  void _toggle(Json p) => setState(() {
        final i = _picked.indexWhere((x) => x['id'] == p['id']);
        if (i >= 0) {
          _picked.removeAt(i);
        } else if (_picked.length < _maxCompare) {
          _picked.add(p);
        }
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Gói cho ${widget.unitType['name']}')),
        floatingActionButton: _picked.length < 2
            ? null
            : FloatingActionButton.extended(
                icon: const Icon(Icons.compare_arrows),
                label: Text('So sánh (${_picked.length})'),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CompareScreen(packages: List.of(_picked)))),
              ),
        body: Loader<List<Json>>(
          load: () async => _list(await api.get('/unit-types/${widget.unitType['id']}/packages')),
          builder: (context, packages, _) => packages.isEmpty
              ? const Center(child: Text('Chưa có gói cho mẫu căn này'))
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
                  _Showcase(unitTypeId: widget.unitType['id'] as String),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Text('Chọn 2-3 gói để so sánh', style: TextStyle(color: AppColors.muted)),
                  ),
                  for (final p in packages)
                    _PackageCard(
                      package: p,
                      picked: _picked.any((x) => x['id'] == p['id']),
                      onPick: () => _toggle(p),
                    ),
                ]),
        ),
      );
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, required this.picked, required this.onPick});

  final Json package;
  final bool picked;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = package['contractor'] as Json;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: picked
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
            )
          : null,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PackageScreen(id: package['id'] as String))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Cover(package['images'] as List?),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(package['name'] as String, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(vnd(package['price'] as num), style: text.titleLarge?.copyWith(color: AppColors.primary)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Pill('${package['style']}'),
                  Pill('${package['duration_days']} ngày'),
                  Pill('BH ${package['warranty_months']} tháng'),
                ]),
                const SizedBox(height: 8),
                ContractorLine(c),
              ]),
            ),
            Checkbox(value: picked, onChanged: (_) => onPick()),
          ]),
        ),
      ),
    );
  }
}

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key, required this.packages});

  final List<Json> packages;

  @override
  Widget build(BuildContext context) {
    num price(Json p) => p['price'] as num;
    num days(Json p) => p['duration_days'] as num;
    num warranty(Json p) => p['warranty_months'] as num;
    num rating(Json p) => ((p['contractor'] as Json)['rating'] as num?) ?? 0;
    // Mỗi hàng: nhãn, giá trị hiển thị, và (tuỳ chọn) cách chọn ô tốt nhất để tô màu.
    final rows = <(String, String Function(Json), Json? Function()?)>[
      ('Giá', (p) => vndShort(price(p)), () => _best(price, lower: true)),
      ('Phong cách', (p) => '${p['style']}', null),
      ('Thi công', (p) => '${days(p)} ngày', () => _best(days, lower: true)),
      ('Bảo hành', (p) => '${warranty(p)} tháng', () => _best(warranty)),
      ('Nhà thầu', (p) => '${(p['contractor'] as Json)['name']}', null),
      ('Đánh giá', (p) => '${(p['contractor'] as Json)['rating'] ?? '-'}', () => _best(rating)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('So sánh gói')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Ô xanh là lựa chọn tốt nhất ở mỗi hàng.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Table(
            border: TableBorder.symmetric(inside: const BorderSide(color: AppColors.border)),
            columnWidths: const {0: IntrinsicColumnWidth()},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(decoration: const BoxDecoration(color: AppColors.primarySoft), children: [
                const SizedBox(),
                for (final p in packages) _cell(p['name'] as String, bold: true),
              ]),
              for (final (label, value, best) in rows)
                TableRow(children: [
                  _cell(label, bold: true),
                  for (final p in packages) _cell(value(p), highlight: identical(best?.call(), p)),
                ]),
            ],
          ),
        ),
      ]),
    );
  }

  /// Gói có giá trị tốt nhất theo [key]. Hoà nhau thì không tô ô nào.
  Json? _best(num Function(Json) key, {bool lower = false}) {
    final sorted = [...packages]..sort((a, b) => lower ? key(a).compareTo(key(b)) : key(b).compareTo(key(a)));
    return key(sorted.first) == key(sorted[1]) ? null : sorted.first;
  }

  Widget _cell(String s, {bool bold = false, bool highlight = false}) => Container(
        color: highlight ? AppColors.success.withValues(alpha: 0.1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Text(s,
            style: TextStyle(
              fontWeight: bold || highlight ? FontWeight.w600 : null,
              color: highlight ? AppColors.success : null,
            )),
      );
}

/// Giá = tổng hạng mục bắt buộc + hạng mục tuỳ chọn đang chọn. Cùng công thức với BE (src/pricing.ts).
num packageTotal(List<Json> items, Set<String> chosen) => items
    .where((i) => i['is_optional'] != true || chosen.contains(i['id']))
    .fold<num>(0, (sum, i) => sum + (num.parse('${i['qty']}') * (i['unit_price'] as num)).round());

class PackageScreen extends StatefulWidget {
  const PackageScreen({super.key, required this.id});

  final String id;

  @override
  State<PackageScreen> createState() => _PackageScreenState();
}

class _PackageScreenState extends State<PackageScreen> {
  final _chosen = <String>{};

  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => await api.get('/packages/${widget.id}') as Json,
        builder: (context, pkg, _) {
          final items = _list(pkg['items']);
          final total = packageTotal(items, _chosen);
          final rooms = <String, List<Json>>{};
          for (final i in items) {
            rooms.putIfAbsent(i['room'] as String, () => []).add(i);
          }
          final unit = pkg['unit_type'] as Json;
          final c = pkg['contractor'] as Json;
          return Scaffold(
            appBar: AppBar(title: Text(pkg['name'] as String)),
            body: ListView(padding: const EdgeInsets.only(bottom: 160), children: [
              if ((pkg['images'] as List).isNotEmpty) _Gallery((pkg['images'] as List).cast<String>()),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${(unit['project'] as Json)['name']} · ${unit['name']}',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => ContractorProfileScreen.open(context, c['id'] as String),
                    child: Row(children: [
                      Flexible(child: ContractorLine(c, style: Theme.of(context).textTheme.titleMedium)),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  Text('${pkg['style']} · ${pkg['duration_days']} ngày thi công · bảo hành ${pkg['warranty_months']} tháng',
                      style: const TextStyle(color: AppColors.muted)),
                ]),
              ),
              for (final MapEntry(key: room, value: list) in rooms.entries) ...[
                SectionTitle(room),
                for (final i in list)
                  i['is_optional'] == true
                      ? CheckboxListTile(
                          value: _chosen.contains(i['id']),
                          onChanged: (v) => setState(() => v! ? _chosen.add(i['id'] as String) : _chosen.remove(i['id'])),
                          title: Text('${i['name']} (tuỳ chọn)'),
                          subtitle: Text(_itemLine(i)),
                        )
                      : ListTile(title: Text('${i['name']}'), subtitle: Text(_itemLine(i))),
              ],
            ]),
            bottomSheet: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: SafeArea(
                top: false,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Text('Tổng trọn gói', style: TextStyle(color: AppColors.muted)),
                    const Spacer(),
                    Text(vnd(total), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _requestQuote(context, pkg, items),
                    child: const Text('Nhận tư vấn gói này'),
                  ),
                ]),
              ),
            ),
          );
        },
      );

  String _itemLine(Json i) => [
        if (i['material'] != null) i['material'],
        if (i['size'] != null) i['size'],
        '${i['qty']} ${i['unit']} × ${vnd(i['unit_price'] as num)}',
      ].join(' · ');

  Future<void> _requestQuote(BuildContext context, Json pkg, List<Json> items) async {
    if (!await ensureSignedIn(context) || !context.mounted) return;
    final options = items.where((i) => _chosen.contains(i['id'])).map((i) => i['name']).join(', ');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuoteRequestScreen(
          unitTypeId: (pkg['unit_type'] as Json)['id'] as String,
          packageId: pkg['id'] as String,
          title: pkg['name'] as String,
          initialNote: options.isEmpty ? '' : 'Thêm tuỳ chọn: $options',
        ),
      ),
    );
  }
}

/// Ảnh bìa gói trong danh sách; chưa có ảnh thì icon.
class _Cover extends StatelessWidget {
  const _Cover(this.images);

  final List? images;

  @override
  Widget build(BuildContext context) => images == null || images!.isEmpty
      ? const IconBadge(Icons.chair_outlined)
      : ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: Image.network('${images!.first}',
              width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const IconBadge(Icons.chair_outlined)),
        );
}

/// Ảnh gói, vuốt ngang.
class _Gallery extends StatefulWidget {
  const _Gallery(this.urls);

  final List<String> urls;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  var _page = 0;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(children: [
              PageView(
                onPageChanged: (i) => setState(() => _page = i),
                children: [for (final u in widget.urls) Image.network(u, fit: BoxFit.cover)],
              ),
              if (widget.urls.length > 1)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Pill('${_page + 1}/${widget.urls.length}'),
                ),
            ]),
          ),
        ),
      );
}

/// "Căn đã làm thực tế": ảnh từ công trình đã bàn giao cùng mẫu căn (học Ohouse). Không có thì không hiện.
class _Showcase extends StatefulWidget {
  const _Showcase({required this.unitTypeId});

  final String unitTypeId;

  @override
  State<_Showcase> createState() => _ShowcaseState();
}

class _ShowcaseState extends State<_Showcase> {
  late final _future = api.get('/unit-types/${widget.unitTypeId}/showcase');

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _future,
        builder: (context, snap) {
          final items = (snap.data as List?)?.cast<Json>() ?? const [];
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text('Căn đã làm thực tế (${items.length})', style: Theme.of(context).textTheme.titleLarge),
            ),
            SizedBox(
              height: 190,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final it in items)
                  Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SingleChildScrollView(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  ContractorLine(it['contractor'] as Json, style: Theme.of(context).textTheme.titleMedium),
                                  if (it['review']?['content'] != null) ...[
                                    const SizedBox(height: 8),
                                    Text('"${it['review']['content']}"'),
                                  ],
                                  const SizedBox(height: 12),
                                  PhotoGrid((it['photos'] as List).cast<String>(), size: 110),
                                ]),
                              ),
                            ),
                          ),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: (it['photos'] as List).isEmpty
                                ? Container(color: AppColors.primarySoft, child: const Center(child: Icon(Icons.home_outlined)))
                                : Image.network('${(it['photos'] as List).first}', width: 220, fit: BoxFit.cover),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: ContractorLine(it['contractor'] as Json),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ]);
        },
      );
}
