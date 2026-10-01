// Trang chủ: lời chào, tìm dự án, lối tắt, banner tự đo nhà, dự án, gói nổi bật, căn đã làm thực tế, cam kết.

import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../measure/model.dart';
import '../measure/painters.dart';
import '../theme.dart';
import 'account.dart';
import 'catalog.dart';
import 'common.dart';
import 'measure.dart';
import 'requests.dart';

typedef Json = Map<String, dynamic>;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _query = '';

  Future<(List<Json>, List<Json>, List<Json>)> _load() async {
    final r = await Future.wait([api.get('/projects'), api.get('/packages/featured'), api.get('/showcase')]);
    return ((r[0] as List).cast<Json>(), (r[1] as List).cast<Json>(), (r[2] as List).cast<Json>());
  }

  /// So khớp không dấu: "song hong" tìm được "Sông Hồng".
  bool _matches(Json p) {
    if (_query.isEmpty) return true;
    final hay = foldVietnamese('${p['name']} ${p['address'] ?? ''} ${p['province']}');
    return foldVietnamese(_query).split(' ').every(hay.contains);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Loader<(List<Json>, List<Json>, List<Json>)>(
          load: _load,
          builder: (context, data, reload) {
            final (projects, featured, showcase) = data;
            final shown = projects.where(_matches).toList();
            return RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
                _Header(onSearch: (q) => setState(() => _query = q.trim())),
                const _QuickActions(),
                if (_query.isEmpty) const _MeasureBanner(),
                _SectionHeader(_query.isEmpty ? 'Dự án đang có gói' : 'Kết quả tìm "$_query"'),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Chưa có dự án này. Bấm + để gửi yêu cầu theo địa chỉ, hoặc tự đo nhà để nhận báo giá.',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                for (final p in shown) _ProjectCard(project: p),
                if (_query.isEmpty && featured.isNotEmpty) ...[
                  const _SectionHeader('Gói nổi bật'),
                  SizedBox(
                    height: 262,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [for (final p in featured) _FeaturedPackage(package: p)],
                    ),
                  ),
                ],
                if (_query.isEmpty && showcase.isNotEmpty) ...[
                  const _SectionHeader('Căn đã làm thực tế'),
                  SizedBox(
                    height: 210,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [for (final s in showcase) _ShowcaseCard(item: s)],
                    ),
                  ),
                ],
                if (_query.isEmpty) const _WhyUs(),
              ]),
            );
          },
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color(0xFF1E37D8)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.chair_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Hợp Thầu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
            const Spacer(),
            ValueListenableBuilder(
              valueListenable: api.session,
              builder: (context, s, _) => s == null
                  ? TextButton(
                      onPressed: () => ensureSignedIn(context),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Đăng nhập'),
                    )
                  : const Icon(Icons.notifications_none_rounded, color: Colors.white),
            ),
          ]),
          const SizedBox(height: 22),
          const Text('Kết nối chủ nhà với thầu nội thất', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text('Thầu hợp căn, hợp giá, hợp ý', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
          const SizedBox(height: 18),
          TextField(
            onChanged: onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm dự án, quận, thành phố',
              prefixIcon: const Icon(Icons.search_rounded),
              fillColor: Colors.white,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.field),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ]),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    Future<void> needLogin(Widget screen) async {
      if (!await ensureSignedIn(context) || !context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    final actions = <(IconData, String, VoidCallback)>[
      (Icons.straighten_rounded, 'Tự đo nhà', () => MeasurementsScreen.open(context)),
      (Icons.request_quote_outlined, 'Xin báo giá', () => needLogin(const QuoteRequestScreen(title: 'Yêu cầu báo giá'))),
      (Icons.menu_book_outlined, 'Cách đo', () => showMeasureGuide(context)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 4),
      child: Row(children: [
        for (final (icon, label, onTap) in actions)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Banner giới thiệu tính năng tự đo nhà, có khung 3D thu nhỏ vẽ từ mẫu căn.
class _MeasureBanner extends StatelessWidget {
  const _MeasureBanner();

  static final _preview = planTemplates.values.first();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Material(
          color: const Color(0xFFFFF6DE),
          borderRadius: BorderRadius.circular(AppRadius.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => MeasurementsScreen.open(context),
            child: Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 4, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Pill('Mới', color: Color(0xFFB07A00)),
                    const SizedBox(height: 8),
                    Text('Tự đo nhà, nhận báo giá sát hơn', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    const Text('Nhập số đo từng phòng, app dựng khung 3D và tính diện tích gửi nhà thầu.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    const SizedBox(height: 10),
                    const Row(children: [
                      Text('Bắt đầu đo', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
                    ]),
                  ]),
                ),
              ),
              SizedBox(width: 130, height: 150, child: CustomPaint(painter: FramePainter(_preview))),
            ]),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Json project;

  @override
  Widget build(BuildContext context) {
    final p = project;
    final handover = p['handover_date'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectScreen(slug: p['slug'] as String))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primarySoft, Color(0xFFD7DEFF)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (p['is_social_housing'] == true) ...[
                      const Pill('NOXH', color: AppColors.primary),
                      const SizedBox(width: 6)
                    ],
                    Text('${p['unit_type_count']} mẫu căn', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${p['name']}', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${p['address'] ?? p['province']}${handover == null ? '' : ' · bàn giao ${vnDate(handover)}'}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ]),
              ),
              FromPrice(p['min_price'] as num?),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FeaturedPackage extends StatelessWidget {
  const _FeaturedPackage({required this.package});

  final Json package;

  @override
  Widget build(BuildContext context) {
    final p = package;
    final images = (p['images'] as List).cast<String>();
    final unit = p['unit_type'] as Json;
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12, bottom: 4),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PackageScreen(id: p['id'] as String))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: images.isEmpty
                  ? Container(
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.chair_outlined, color: AppColors.primary, size: 40),
                    )
                  : Image.network(images.first, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['name']}',
                    style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${unit['project']['name']} · ${unit['name']}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(vnd(p['price'] as num),
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                ContractorLine(p['contractor'] as Json),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({required this.item});

  final Json item;

  @override
  Widget build(BuildContext context) {
    final photos = (item['photos'] as List).cast<String>();
    final unit = item['unit_type'] as Json?;
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(fit: StackFit.expand, children: [
          photos.isEmpty ? Container(color: AppColors.primarySoft) : Image.network(photos.first, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
                stops: [0.45, 1],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (unit != null)
                Text('${unit['project']['name']} · ${unit['name']}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ContractorLine(item['contractor'] as Json, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const Positioned(top: 10, left: 10, child: Pill('Đã bàn giao', color: AppColors.success)),
        ]),
      ),
    );
  }
}

class _WhyUs extends StatelessWidget {
  const _WhyUs();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user_outlined, 'Nhà thầu đã xác minh', 'Kiểm tra giấy phép trước khi hiển thị'),
      (Icons.receipt_long_outlined, 'Giá theo hạng mục', 'Vật liệu, số lượng, đơn giá rõ ràng'),
      (Icons.photo_camera_outlined, 'Nghiệm thu bằng ảnh', '4 mốc, tiền đi theo tiến độ'),
      (Icons.gpp_good_outlined, 'Không phát sinh ngầm', 'Thay đổi phải được bạn đồng ý'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader('Vì sao chọn Hợp Thầu'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            for (final (icon, title, body) in items)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconBadge(icon, size: 36),
                  const Spacer(),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(body, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
              ),
          ],
        ),
      ),
    ]);
  }
}
