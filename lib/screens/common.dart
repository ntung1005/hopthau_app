import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';

/// Tải dữ liệu, hiện vòng quay khi chờ, lỗi thì có nút thử lại.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _future,
        builder: (context, snap) {
          // Tải xong mà không lỗi thì hiện nội dung, kể cả khi kết quả là null (ví dụ GET /contractor khi
          // chưa đăng ký làm nhà thầu). snap.hasData coi null là "chưa có dữ liệu" nên không dùng được ở đây.
          if (snap.connectionState == ConnectionState.done && !snap.hasError) {
            return widget.builder(context, snap.data as T, _reload);
          }
          if (snap.hasError) {
            final err = snap.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.muted),
                  const SizedBox(height: 12),
                  Text(errorMessage(err is ApiException ? err.code : 'internal'), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _reload, child: const Text('Thử lại')),
                ]),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
}

void showError(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e is ApiException ? e.code : 'internal'))));

/// Tiêu đề nhóm trong danh sách.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

/// Màn trống: minh hoạ, tiêu đề, mô tả, tuỳ chọn một nút.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
        child: Column(children: [
          Illustration(icon),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: AppColors.muted), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ]),
      );
}

/// Một dòng danh sách dạng card: icon tròn, tiêu đề, mô tả, mũi tên.
class RowCard extends StatelessWidget {
  const RowCard({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap, this.trailing});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: IconBadge(icon),
            title: Text(title, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: AppColors.muted)),
            onTap: onTap,
          ),
        ),
      );
}

/// Nhãn nhỏ nền xám (phong cách, số ngày...). [color] cho nhãn trạng thái.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.12) ?? AppColors.field,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, color: color ?? AppColors.text, fontWeight: color == null ? null : FontWeight.w600)),
      );
}

/// Khung nền xanh nhạt tóm tắt thông tin ở đầu màn chi tiết.
class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

/// Số điện thoại hiện sau khi hai bên đã chốt, bấm để sao chép.
/// ponytail: chưa có nút gọi (cần url_launcher), thêm khi chạy trên máy thật.
class PhoneRow extends StatelessWidget {
  const PhoneRow({super.key, required this.phone});

  /// Dạng 84xxxxxxxxx từ BE.
  final String phone;

  String get _local => phone.startsWith('84') ? '0${phone.substring(2)}' : phone;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: ListTile(
          leading: const Icon(Icons.phone_outlined),
          title: Text(_local, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Bấm để sao chép'),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: _local));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép số điện thoại')));
            }
          },
        ),
      );
}

/// "từ 32 triệu" ở cuối dòng dự án / mẫu căn. Chưa có gói: mũi tên.
class FromPrice extends StatelessWidget {
  const FromPrice(this.price, {super.key});

  final num? price;

  @override
  Widget build(BuildContext context) => price == null
      ? const Icon(Icons.chevron_right_rounded, color: AppColors.muted)
      : Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('từ', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          Text(vndShort(price!), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        ]);
}
