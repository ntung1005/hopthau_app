// Hồ sơ nhà thầu công khai: điểm, số công trình đã bàn giao, gói đang bán, đánh giá (chỉ từ công trình đã xong).

import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';
import 'catalog.dart';
import 'common.dart';
import 'jobs.dart' show ReviewCard;

class ContractorProfileScreen extends StatelessWidget {
  const ContractorProfileScreen({super.key, required this.id});

  final String id;

  static void open(BuildContext context, String id) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ContractorProfileScreen(id: id)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nhà thầu')),
        body: Loader<Map<String, dynamic>>(
          load: () async => await api.get('/contractors/$id') as Map<String, dynamic>,
          builder: (context, c, _) {
            final packages = (c['packages'] as List).cast<Map<String, dynamic>>();
            final reviews = (c['reviews'] as List).cast<Map<String, dynamic>>();
            Widget stat(String value, String label) => Expanded(
                  child: Column(children: [
                    Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary)),
                    Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ]),
                );
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 48), children: [
              InfoPanel(children: [
                ContractorLine(c, style: Theme.of(context).textTheme.titleLarge),
                if (c['address'] != null) ...[
                  const SizedBox(height: 4),
                  Text('${c['address']}', style: const TextStyle(color: AppColors.muted)),
                ],
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  const Pill('Đã xác minh', color: AppColors.primary),
                  for (final s in (c['styles'] as List).cast<String>()) Pill(s),
                  for (final a in (c['areas'] as List).cast<String>()) Pill(a),
                ]),
              ]),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    stat(c['rating'] == null ? '-' : vnDecimal(c['rating']), 'điểm'),
                    stat('${c['review_count']}', 'đánh giá'),
                    stat('${c['completed_jobs']}', 'căn đã bàn giao'),
                  ]),
                ),
              ),
              if ((c['bio'] as String?)?.isNotEmpty ?? false) ...[
                const SectionTitle('Giới thiệu'),
                Text('${c['bio']}'),
              ],
              SectionTitle('Gói đang bán (${packages.length})'),
              for (final p in packages)
                Card(
                  child: ListTile(
                    leading: const IconBadge(Icons.chair_outlined, size: 40),
                    title: Text('${p['name']}'),
                    subtitle: Text('${p['unit_type']['project']['name']} · ${p['unit_type']['name']}'),
                    trailing: Text(vndShort(p['price'] as num),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PackageScreen(id: p['id'] as String))),
                  ),
                ),
              SectionTitle('Đánh giá (${reviews.length})'),
              if (reviews.isEmpty)
                const Text('Chưa có đánh giá. Đánh giá chỉ đến từ công trình đã bàn giao qua Hợp Thầu.',
                    style: TextStyle(color: AppColors.muted)),
              for (final r in reviews) ReviewCard(review: r),
            ]);
          },
        ),
      );
}
