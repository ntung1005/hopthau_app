// Chủ nhà: gửi yêu cầu báo giá, danh sách yêu cầu, xem và chọn báo giá của nhà thầu.

import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../theme.dart';
import 'account.dart';
import 'common.dart';
import 'contractor_profile.dart';
import 'jobs.dart';
import '../measure/model.dart';
import 'measure.dart';

/// Gửi yêu cầu báo giá. Có [packageId] khi đi từ một gói; không có thì là yêu cầu
/// tự do theo địa chỉ (nhà không thuộc dự án có sẵn).
class QuoteRequestScreen extends StatefulWidget {
  const QuoteRequestScreen({
    super.key,
    required this.title,
    this.unitTypeId,
    this.packageId,
    this.measurementId,
    this.initialNote = '',
  });

  final String title;
  final String? unitTypeId;
  final String? packageId;
  final String? measurementId;
  final String initialNote;

  @override
  State<QuoteRequestScreen> createState() => _QuoteRequestScreenState();
}

class _QuoteRequestScreenState extends State<QuoteRequestScreen> {
  late final _note = TextEditingController(text: widget.initialNote);
  final _budget = TextEditingController();
  final _address = TextEditingController();
  late String? _measurementId = widget.measurementId;
  String? _province;
  var _services = <String>{};
  var _busy = false;

  bool get _freeForm => widget.unitTypeId == null;

  Future<void> _submit() async {
    // Mẫu căn đã biết tỉnh của dự án; yêu cầu tự do cần tỉnh để ghép nhà thầu cùng khu vực.
    if (_freeForm && _province == null) {
      showError(context, const ApiException(400, 'missing_province'));
      return;
    }
    setState(() => _busy = true);
    final millions = int.tryParse(_budget.text.trim());
    try {
      final sent = await api.postAuth('/quote-requests', {
        if (widget.unitTypeId != null) 'unit_type_id': widget.unitTypeId,
        if (widget.packageId != null) 'package_id': widget.packageId,
        if (_freeForm) 'province': _province,
        if (_freeForm && _address.text.trim().isNotEmpty) 'address': _address.text.trim(),
        'services': _services.toList(),
        if (millions != null) 'budget': millions * 1000000,
        if (_measurementId != null) 'measurement_id': _measurementId,
        'note': _note.text,
      });
      if (!mounted) return;
      final matched = (sent['quotes'] as List).length;
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => _SentScreen(matched: matched)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Loader<Map<String, dynamic>>(
        load: api.meta,
        builder: (context, meta, _) => ListView(padding: const EdgeInsets.all(24), children: [
          Text(
            _freeForm
                ? 'Chọn khu vực và việc cần làm, chúng tôi gửi tới tối đa 5 nhà thầu đã xác minh phù hợp.'
                : 'Nhà thầu sẽ liên hệ để khảo sát và chốt báo giá cho căn của bạn.',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          if (_freeForm) ...[
            DropdownButtonFormField<String>(
              initialValue: _province,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tỉnh / thành phố', prefixIcon: Icon(Icons.map_outlined)),
              items: [
                for (final p in (meta['provinces'] as List).cast<String>()) DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (v) => setState(() => _province = v),
            ),
            gap,
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ',
                hintText: 'Phường / xã, toà nhà',
                helperText: 'Không bắt buộc, chỉ gửi cho nhà thầu được ghép',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              maxLength: 300,
            ),
            gap,
          ],
          ChipPicker(
            label: 'Cần làm những gì?',
            options: (meta['services'] as List).cast<String>(),
            selected: _services,
            onChanged: (v) => setState(() => _services = v),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _budget,
            decoration: const InputDecoration(
              labelText: 'Ngân sách (triệu đồng)',
              prefixIcon: Icon(Icons.payments_outlined),
              helperText: 'Không bắt buộc',
            ),
            keyboardType: TextInputType.number,
          ),
          gap,
          MeasurementPicker(value: _measurementId, onChanged: (v) => setState(() => _measurementId = v)),
          gap,
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'Ngày nhận nhà, số phòng cần làm, phong cách...',
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            maxLength: 2000,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Gửi yêu cầu')),
        ]),
      ),
    );
  }
}

class _SentScreen extends StatelessWidget {
  const _SentScreen({required this.matched});

  final int matched;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            const Illustration(Icons.mark_email_read_outlined),
            const SizedBox(height: 24),
            Text('Đã gửi yêu cầu', style: text.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              matched > 0
                  ? 'Đã gửi tới $matched nhà thầu phù hợp. Họ xem bản đo và báo giá, thường trong 24 giờ. '
                      'Theo dõi ở mục Yêu cầu.'
                  : 'Chưa có nhà thầu đã xác minh khớp khu vực của bạn. Đội vận hành sẽ tìm và ghép trong 24 giờ. '
                      'Theo dõi ở mục Yêu cầu.',
              style: const TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
          ]),
        ),
      ),
    );
  }
}

const requestStatus = {
  'open': ('Đang nhận báo giá', AppColors.accent),
  'matched': ('Đã chọn nhà thầu', AppColors.success),
  'closed': ('Đã đóng', AppColors.muted),
};

const _quoteStatus = {
  'sent': ('Chờ báo giá', AppColors.muted),
  'quoted': ('Đã báo giá', AppColors.primary),
  'offline': ('Muốn gặp trực tiếp', AppColors.accent),
  'accepted': ('Bạn đã chọn', AppColors.success),
  'declined': ('Không chọn', AppColors.muted),
};

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: api.session,
        builder: (context, session, _) => Scaffold(
          appBar: AppBar(title: const Text('Yêu cầu của tôi')),
          body: session == null
              ? EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Đăng nhập để xem yêu cầu',
                  body: 'Báo giá của nhà thầu sẽ hiện ở đây.',
                  action: FilledButton(onPressed: () => ensureSignedIn(context), child: const Text('Đăng nhập')),
                )
              : Loader<List<dynamic>>(
                  // Đăng nhập tài khoản khác thì tải lại.
                  key: ValueKey(session.accessToken),
                  load: () async => await api.getAuth('/quote-requests') as List<dynamic>,
                  builder: (context, rows, reload) => RefreshIndicator(
                    onRefresh: () async => reload(),
                    child: rows.isEmpty
                        ? ListView(children: const [
                            EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'Chưa có yêu cầu nào',
                              body: 'Chọn một gói ở mục Khám phá, hoặc bấm nút + để gửi yêu cầu theo địa chỉ.',
                            ),
                          ])
                        : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
                            for (final r in rows.cast<Map<String, dynamic>>())
                              _RequestCard(
                                request: r,
                                onTap: () async {
                                  await Navigator.push(
                                      context, MaterialPageRoute(builder: (_) => RequestDetailScreen(id: r['id'] as String)));
                                  reload();
                                },
                              ),
                          ]),
                  ),
                ),
        ),
      );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final Map<String, dynamic> request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final (label, color) = requestStatus[r['status']] ?? ('${r['status']}', AppColors.muted);
    final quoted = (r['quotes'] as List).where((q) => q['price'] != null).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IconBadge(Icons.home_work_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['package']?['name'] as String? ?? 'Yêu cầu báo giá', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  [
                    requestPlace(r),
                    if (servicesLine(r).isNotEmpty) servicesLine(r),
                    if (r['budget'] != null) 'Ngân sách ${vndShort(r['budget'] as num)}',
                  ].join('\n'),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  Pill(label, color: color),
                  if (r['job'] != null)
                    Pill(jobStatus[r['job']['status']]?.$1 ?? '', color: jobStatus[r['job']['status']]?.$2)
                  else
                    Pill(quoted == 0 ? 'Chưa có báo giá' : '$quoted báo giá'),
                ]),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

/// Chi tiết yêu cầu: các báo giá nhận được, chọn một nhà thầu.
/// Số điện thoại nhà thầu chỉ hiện sau khi chọn (BE ẩn trước đó).
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  var _key = UniqueKey();
  var _busy = false;

  Future<void> _accept(Map<String, dynamic> quote) async {
    final c = quote['contractor'] as Map<String, dynamic>;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chọn ${c['name']}?'),
        content: Text(
            '${quote['mode'] == 'offline' ? 'Làm việc trực tiếp: hai bên tự khảo sát và thoả thuận giá, app theo dõi tiến độ các mốc.' : 'Báo giá ${vnd(quote['price'] as num)}, ${quote['duration_days']} ngày thi công.'} '
            'Hai bên sẽ thấy số điện thoại của nhau, các nhà thầu khác sẽ được báo là bạn không chọn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Để sau')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Chọn')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await api.postAuth('/quote-requests/${widget.id}/accept', {'contractor_id': c['id']});
      if (mounted) setState(() => _key = UniqueKey());
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Yêu cầu báo giá')),
        body: Loader<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
          key: _key,
          load: () async {
            final r = await api.getAuth('/quote-requests/${widget.id}') as Map<String, dynamic>;
            // Đồ đã chọn trong bản đo, để thấy nhà thầu thêm / bớt món nào.
            final mid = r['measurement']?['id'] as String?;
            final asked = mid == null
                ? <Map<String, dynamic>>[]
                : Plan.fromJson((await api.getAuth('/measurements/$mid') as Map<String, dynamic>)['data'] as Map<String, dynamic>)
                    .askedItems;
            return (r, asked);
          },
          builder: (context, data, reload) {
            final (r, asked) = data;
            final (label, color) = requestStatus[r['status']] ?? ('${r['status']}', AppColors.muted);
            final quotes = (r['quotes'] as List).cast<Map<String, dynamic>>()
              ..sort((a, b) => ((a['price'] ?? 1 << 62) as num).compareTo((b['price'] ?? 1 << 62) as num));
            final open = r['status'] == 'open';
            return RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                InfoPanel(children: [
                  Text(r['package']?['name'] as String? ?? 'Yêu cầu theo địa chỉ',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(requestPlace(r), style: const TextStyle(color: AppColors.muted)),
                  if (servicesLine(r).isNotEmpty) Text(servicesLine(r), style: const TextStyle(color: AppColors.muted)),
                  if (r['budget'] != null)
                    Text('Ngân sách ${vnd(r['budget'] as num)}', style: const TextStyle(color: AppColors.muted)),
                  if ((r['note'] as String?)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 6),
                    Text('${r['note']}'),
                  ],
                  const SizedBox(height: 10),
                  Pill(label, color: color),
                ]),
                if (r['measurement'] != null) ...[
                  const SizedBox(height: 12),
                  RowCard(
                    icon: Icons.straighten,
                    title: 'Bản đo đính kèm: ${r['measurement']['name']}',
                    subtitle: 'Nhà thầu dùng để báo giá sơ bộ',
                    onTap: () => MeasurementViewerScreen.open(context, r['measurement']['id'] as String),
                  ),
                ],
                if (r['job'] != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => JobScreen(id: r['job']['id'] as String))),
                    icon: const Icon(Icons.construction_outlined),
                    label: const Text('Theo dõi công trình'),
                  ),
                ],
                SectionTitle(quotes.isEmpty ? 'Đang tìm nhà thầu' : 'Báo giá (${quotes.length})'),
                if (quotes.isEmpty)
                  const Text('Chúng tôi đang ghép nhà thầu phù hợp, thường trong 24 giờ.',
                      style: TextStyle(color: AppColors.muted)),
                for (final q in quotes) _QuoteCard(quote: q, asked: asked, canAccept: open && !_busy, onAccept: () => _accept(q)),
              ]),
            );
          },
        ),
      );
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.asked, required this.canAccept, required this.onAccept});

  final Map<String, dynamic> quote;
  final List<Map<String, dynamic>> asked;
  final bool canAccept;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final c = q['contractor'] as Map<String, dynamic>;
    final offline = q['mode'] == 'offline';
    final (label, color) =
        _quoteStatus[offline && q['status'] == 'quoted' ? 'offline' : q['status']] ?? ('${q['status']}', AppColors.muted);
    final items = (q['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    final accepted = q['status'] == 'accepted';
    return Card(
      shape: accepted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.success, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconBadge(Icons.handyman_outlined, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => ContractorProfileScreen.open(context, c['id'] as String),
                child: ContractorLine(c, style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            Pill(label, color: color),
          ]),
          if (q['price'] != null) ...[
            const SizedBox(height: 12),
            Text(vnd(q['price'] as num), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary)),
            Text('${q['duration_days']} ngày thi công', style: const TextStyle(color: AppColors.muted)),
          ],
          if (offline && q['status'] != 'sent') ...[
            const SizedBox(height: 10),
            const Text(
                'Nhà thầu muốn gặp để khảo sát và thoả thuận giá trực tiếp. Chọn thì hai bên thấy số điện thoại; '
                'app theo dõi tiến độ các mốc, không ghi nhận tiền.',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
          if (items.isNotEmpty) _QuoteItems(lines: quoteDiff(asked, items)),
          if (q['message'] != null) ...[const SizedBox(height: 8), Text('${q['message']}')],
          if (accepted && c['phone'] != null) ...[
            const SizedBox(height: 12),
            PhoneRow(phone: c['phone'] as String),
          ],
          if (canAccept && q['status'] == 'quoted') ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAccept, child: Text(offline ? 'Chọn, làm việc trực tiếp' : 'Chọn nhà thầu này')),
          ],
        ]),
      ),
    );
  }
}

/// Báo giá theo món: mỗi món kèm thành tiền; đánh dấu món nhà thầu thêm, đổi số lượng hoặc bỏ so với đồ bạn chọn.
class _QuoteItems extends StatelessWidget {
  const _QuoteItems({required this.lines});

  final List<QuoteLine> lines;

  @override
  Widget build(BuildContext context) {
    final changed = lines.where((l) => l.tag != null).length;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: changed > 0,
        title: Text('Chi tiết ${lines.where((l) => l.tag != 'removed').length} món'),
        subtitle:
            changed == 0 ? null : Text('$changed thay đổi so với đồ bạn chọn', style: const TextStyle(color: AppColors.accent)),
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${l.name} × ${l.qty}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: l.tag == 'removed' ? TextDecoration.lineThrough : null,
                          color: l.tag == 'removed' ? AppColors.muted : null,
                        )),
                    Text([l.room, if (l.note != null) l.note].join(' · '),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    if (l.tag == 'added') const Pill('Nhà thầu đề xuất thêm', color: AppColors.success),
                    if (l.tag == 'changed') Pill('Bạn chọn ${l.askedQty}', color: AppColors.accent),
                    if (l.tag == 'removed') const Pill('Nhà thầu bỏ', color: AppColors.error),
                  ]),
                ),
                if (l.unitPrice != null) Text(vnd(l.unitPrice! * l.qty)),
              ]),
            ),
        ],
      ),
    );
  }
}
