// Công trình: một màn cho cả hai bên. Nhà thầu báo xong mốc, đề nghị phát sinh, xác nhận nhận tiền,
// trả lời đánh giá. Chủ nhà duyệt / trả lại mốc, đồng ý / từ chối phát sinh, đánh giá khi xong.

import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../photos.dart';
import '../theme.dart';
import 'account.dart';
import 'common.dart';

typedef Json = Map<String, dynamic>;

const jobStatus = {
  'active': ('Đang thi công', AppColors.primary),
  'completed': ('Đã bàn giao', AppColors.success),
  'cancelled': ('Đã huỷ', AppColors.muted),
};

const _milestoneStatus = {
  'pending': ('Chưa làm', AppColors.muted),
  'submitted': ('Chờ chủ nhà duyệt', AppColors.accent),
  'approved': ('Đã nghiệm thu', AppColors.success),
  'rejected': ('Chủ nhà trả lại', AppColors.error),
};

const _changeStatus = {
  'pending': ('Chờ chủ nhà quyết', AppColors.accent),
  'approved': ('Đã đồng ý', AppColors.success),
  'rejected': ('Không đồng ý', AppColors.muted),
};

(String, Color) _of(Map<String, (String, Color)> m, Object? k) => m[k] ?? ('$k', AppColors.muted);

String jobPlace(Json job) {
  final r = job['request'] as Json? ?? const {};
  final unit = r['unit_type'] as Json?;
  return unit != null ? '${unit['project']['name']} · ${unit['name']}' : '${r['address'] ?? ''}';
}

/// Danh sách công trình của tôi (chủ nhà hoặc nhà thầu, BE trả `role`).
/// Tab Công trình. [role] owner / contractor: tài khoản vừa là chủ nhà vừa là nhà thầu chỉ thấy công trình của chế độ đang dùng.
class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Công trình')),
        body: ValueListenableBuilder(
          valueListenable: api.session,
          builder: (context, session, _) => session == null
              ? EmptyState(
                  icon: Icons.construction_outlined,
                  title: 'Theo dõi thi công ngay trên điện thoại',
                  body: 'Sau khi chọn nhà thầu, bạn nghiệm thu từng mốc bằng ảnh và duyệt mọi phát sinh tại đây.',
                  action: FilledButton(onPressed: () => ensureSignedIn(context), child: const Text('Đăng nhập')),
                )
              : JobsList(
                  key: ValueKey(session.accessToken),
                  role: role,
                  emptyText: role == 'owner'
                      ? 'Chọn một báo giá ở tab Yêu cầu để bắt đầu công trình. Bạn sẽ nghiệm thu từng mốc bằng ảnh tại đây.'
                      : 'Công trình hiện ở đây khi chủ nhà chọn báo giá của bạn.',
                ),
        ),
      );
}

class JobsList extends StatelessWidget {
  const JobsList({super.key, required this.role, this.emptyText = 'Công trình hiện ở đây sau khi chủ nhà chọn báo giá.'});

  final String role;
  final String emptyText;

  @override
  Widget build(BuildContext context) => Loader<List<dynamic>>(
        load: () async => (await api.getAuth('/jobs') as List<dynamic>).where((j) => j['role'] == role).toList(),
        builder: (context, rows, reload) => RefreshIndicator(
          onRefresh: () async => reload(),
          child: rows.isEmpty
              ? ListView(children: [EmptyState(icon: Icons.construction_outlined, title: 'Chưa có công trình', body: emptyText)])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), children: [
                  for (final j in rows.cast<Json>())
                    JobCard(
                      job: j,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => JobScreen(id: j['id'] as String)));
                        reload();
                      },
                    ),
                ]),
        ),
      );
}

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap});

  final Json job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _of(jobStatus, job['status']);
    final p = job['progress'] as Json;
    final other = job['role'] == 'owner' ? (job['contractor'] as Json)['name'] : (job['owner'] as Json)['full_name'];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconBadge(Icons.construction_outlined, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(jobPlace(job), style: Theme.of(context).textTheme.titleMedium),
                  Text('$other · ${vnd(job['total'] as num)}', style: const TextStyle(color: AppColors.muted)),
                ]),
              ),
              Pill(label, color: color),
            ]),
            const SizedBox(height: 12),
            _Progress(done: p['done'] as int, total: p['total'] as int),
          ]),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              backgroundColor: AppColors.field,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('$done/$total mốc', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      ]);
}

class JobScreen extends StatefulWidget {
  const JobScreen({super.key, required this.id});

  final String id;

  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  var _key = UniqueKey();
  var _busy = false;

  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _run(Future<void> Function() action, [String? done]) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && done != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<T?> _sheet<T>(Widget child) => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: SingleChildScrollView(child: child),
        ),
      );

  // Nhà thầu --------------------------------------------------------------------

  Future<void> _submitMilestone(Json m) async {
    final result = await _sheet<(String, List<String>)>(_MilestoneForm(milestone: m));
    if (result == null) return;
    await _run(() => api.postAuth('/jobs/milestones/${m['id']}/submit', {'note': result.$1, 'photos': result.$2}),
        'Đã báo chủ nhà nghiệm thu');
  }

  Future<void> _proposeChange() async {
    final body = await _sheet<Json>(const _ChangeForm());
    if (body == null) return;
    await _run(() => api.postAuth('/jobs/${widget.id}/changes', body), 'Đã gửi đề nghị phát sinh cho chủ nhà');
  }

  Future<void> _reply(String current) async {
    final text = await _sheet<String>(_TextForm(title: 'Trả lời đánh giá', label: 'Lời trả lời công khai', initial: current));
    if (text == null) return;
    await _run(() => api.postAuth('/jobs/${widget.id}/review/reply', {'reply': text}), 'Đã trả lời');
  }

  // Chủ nhà -----------------------------------------------------------------------

  Future<void> _rejectMilestone(Json m) async {
    final text = await _sheet<String>(_TextForm(title: 'Trả lại mốc "${m['title']}"', label: 'Cần sửa gì?'));
    if (text == null) return;
    await _run(() => api.postAuth('/jobs/milestones/${m['id']}/review', {'approve': false, 'feedback': text}),
        'Đã gửi góp ý cho nhà thầu');
  }

  Future<void> _approveMilestone(Json m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nghiệm thu "${m['title']}"?'),
        content: Text('Xác nhận phần việc này đã xong như cam kết. '
            'Sau đó thanh toán ${vnd(m['amount'] as num)} cho nhà thầu theo thoả thuận.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Để sau')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Nghiệm thu')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => api.postAuth('/jobs/milestones/${m['id']}/review', {'approve': true}), 'Đã nghiệm thu');
  }

  Future<void> _review() async {
    final body = await _sheet<Json>(const _ReviewForm());
    if (body == null) return;
    await _run(() => api.postAuth('/jobs/${widget.id}/review', body), 'Cảm ơn bạn đã đánh giá!');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Công trình')),
        body: Loader<Json>(
          key: _key,
          load: () async => await api.getAuth('/jobs/${widget.id}') as Json,
          builder: (context, job, reload) {
            final isOwner = job['role'] == 'owner';
            final active = job['status'] == 'active';
            final milestones = (job['milestones'] as List).cast<Json>();
            final changes = (job['changes'] as List).cast<Json>();
            final review = job['review'] as Json?;
            final (label, color) = _of(jobStatus, job['status']);
            final other = isOwner ? job['contractor'] as Json : job['owner'] as Json;
            // Mốc đang mở: mốc đầu tiên chưa nghiệm thu.
            final openIndex = milestones.indexWhere((m) => m['status'] != 'approved');
            return RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 48), children: [
                InfoPanel(children: [
                  Text(jobPlace(job), style: Theme.of(context).textTheme.titleMedium),
                  if (job['request']?['package'] != null)
                    Text('Gói: ${job['request']['package']['name']}', style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 4),
                  isOwner
                      ? ContractorLine(other, style: const TextStyle(color: AppColors.text))
                      : Text('Chủ nhà: ${other['full_name']}', style: const TextStyle(color: AppColors.text)),
                  const SizedBox(height: 10),
                  Pill(label, color: color),
                ]),
                if (other['phone'] != null) ...[const SizedBox(height: 12), PhoneRow(phone: other['phone'] as String)],
                const SizedBox(height: 12),
                _SummaryCard(job: job),
                SectionTitle('Mốc thi công (${milestones.where((m) => m['status'] == 'approved').length}/${milestones.length})'),
                for (final (i, m) in milestones.indexed)
                  _MilestoneTile(
                    milestone: m,
                    isLast: i == milestones.length - 1,
                    actions: [
                      if (!isOwner && active && i == openIndex && (m['status'] == 'pending' || m['status'] == 'rejected'))
                        FilledButton(onPressed: _busy ? null : () => _submitMilestone(m), child: const Text('Báo xong mốc này')),
                      if (isOwner && m['status'] == 'submitted') ...[
                        FilledButton(onPressed: _busy ? null : () => _approveMilestone(m), child: const Text('Nghiệm thu')),
                        const SizedBox(height: 8),
                        OutlinedButton(
                            onPressed: _busy ? null : () => _rejectMilestone(m), child: const Text('Trả lại, cần sửa')),
                      ],
                      if (!isOwner && m['status'] == 'approved' && m['paid_at'] == null)
                        OutlinedButton(
                          onPressed:
                              _busy ? null : () => _run(() => api.postAuth('/jobs/milestones/${m['id']}/paid'), 'Đã ghi nhận'),
                          child: const Text('Xác nhận đã nhận tiền'),
                        ),
                    ],
                  ),
                SectionTitle('Phát sinh (${changes.length})'),
                const Text('Mọi thay đổi giá hoặc thời gian chỉ có hiệu lực khi chủ nhà đồng ý trong app.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 8),
                for (final c in changes)
                  _ChangeCard(
                    change: c,
                    onDecide: isOwner && c['status'] == 'pending' && !_busy
                        ? (approve) => _run(() => api.postAuth('/jobs/changes/${c['id']}/decide', {'approve': approve}),
                            approve ? 'Đã đồng ý phát sinh' : 'Đã từ chối phát sinh')
                        : null,
                  ),
                if (!isOwner && active)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _proposeChange,
                    icon: const Icon(Icons.add),
                    label: const Text('Đề nghị phát sinh'),
                  ),
                if (job['status'] == 'completed') ...[
                  const SectionTitle('Đánh giá'),
                  if (review != null)
                    ReviewCard(review: review, onReply: isOwner || _busy ? null : () => _reply(review['reply'] as String? ?? ''))
                  else if (isOwner)
                    FilledButton.icon(
                        onPressed: _busy ? null : _review,
                        icon: const Icon(Icons.star_outline),
                        label: const Text('Đánh giá nhà thầu'))
                  else
                    const Text('Chủ nhà chưa đánh giá.', style: TextStyle(color: AppColors.muted)),
                ],
              ]),
            );
          },
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.job});

  final Json job;

  @override
  Widget build(BuildContext context) {
    final total = job['total'] as num;
    final paid = job['paid_amount'] as num;
    final approved = job['approved_amount'] as num;
    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Text(label, style: const TextStyle(color: AppColors.muted)),
            const Spacer(),
            Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          row('Tổng hợp đồng', vnd(total), color: AppColors.primary),
          if (total != job['price']) row('Giá ban đầu', vnd(job['price'] as num)),
          row('Đã nghiệm thu', vnd(approved)),
          row('Nhà thầu đã nhận', vnd(paid), color: AppColors.success),
          row('Thời gian', '${job['total_days']} ngày'),
          if (job['warranty_until'] != null)
            row('Bảo hành đến', vnDate(job['warranty_until'] as String), color: AppColors.success)
          else
            row('Bảo hành', '${job['warranty_months']} tháng sau bàn giao'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                value: total == 0 ? 0 : (approved / total).clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: AppColors.field),
          ),
        ]),
      ),
    );
  }
}

/// Một mốc trên dòng thời gian: vòng số thứ tự + đường nối, nội dung, ảnh, nút hành động.
class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone, required this.isLast, required this.actions});

  final Json milestone;
  final bool isLast;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final m = milestone;
    final (label, color) = _of(_milestoneStatus, m['status']);
    final done = m['status'] == 'approved';
    final photos = (m['photos'] as List).cast<String>();
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: done ? AppColors.success : AppColors.primarySoft,
            child: done
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text('${m['seq']}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          if (!isLast) Expanded(child: Container(width: 2, color: done ? AppColors.success : AppColors.border)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${m['title']}', style: Theme.of(context).textTheme.titleMedium)),
                Text(vnd(m['amount'] as num), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill(label, color: color),
                if (m['paid_at'] != null) const Pill('Đã thanh toán', color: AppColors.success),
              ]),
              if (m['note'] != null) ...[const SizedBox(height: 8), Text('${m['note']}')],
              if (photos.isNotEmpty) ...[const SizedBox(height: 8), PhotoGrid(photos, size: 72)],
              if (m['owner_feedback'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                  child: Text('Chủ nhà: ${m['owner_feedback']}'),
                ),
              ],
              if (actions.isNotEmpty) ...[const SizedBox(height: 12), ...actions],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.change, required this.onDecide});

  final Json change;
  final void Function(bool approve)? onDecide;

  @override
  Widget build(BuildContext context) {
    final c = change;
    final (label, color) = _of(_changeStatus, c['status']);
    final amount = c['amount'] as num;
    final days = c['days_delta'] as num;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${c['title']}', style: Theme.of(context).textTheme.titleMedium)),
            Pill(label, color: color),
          ]),
          const SizedBox(height: 4),
          Text(
            '${amount >= 0 ? '+' : '−'}${vnd(amount.abs())}${days == 0 ? '' : ' · ${days > 0 ? '+' : ''}$days ngày'}',
            style: TextStyle(fontWeight: FontWeight.w600, color: amount >= 0 ? AppColors.error : AppColors.success),
          ),
          if (c['description'] != null) ...[const SizedBox(height: 6), Text('${c['description']}')],
          if (onDecide != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => onDecide!(false), child: const Text('Từ chối'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () => onDecide!(true), child: const Text('Đồng ý'))),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Đánh giá: điểm 4 tiêu chí, nội dung, ảnh, trả lời của nhà thầu. Dùng cả ở hồ sơ nhà thầu.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.onReply});

  final Json review;
  final VoidCallback? onReply;

  static const criteria = {
    'quality': 'Chất lượng',
    'punctuality': 'Đúng hạn',
    'price_honesty': 'Đúng giá',
    'attitude': 'Thái độ',
  };

  @override
  Widget build(BuildContext context) {
    final r = review;
    final avg = criteria.keys.map((k) => r[k] as num).reduce((a, b) => a + b) / criteria.length;
    final photos = (r['photos'] as List? ?? const []).cast<String>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text((r['owner_name'] as String?)?.isNotEmpty == true ? r['owner_name'] as String : 'Chủ nhà',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const Icon(Icons.star_rounded, color: AppColors.accent, size: 20),
            Text(' ${vnDecimal(avg.toStringAsFixed(1))}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final MapEntry(:key, :value) in criteria.entries) Pill('$value ${r[key]}/5'),
          ]),
          if (r['content'] != null) ...[const SizedBox(height: 8), Text('${r['content']}')],
          if (photos.isNotEmpty) ...[const SizedBox(height: 8), PhotoGrid(photos, size: 72)],
          if (r['reply'] != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(AppRadius.field)),
              child: Text('Nhà thầu trả lời: ${r['reply']}'),
            ),
          ],
          if (onReply != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onReply, child: Text(r['reply'] == null ? 'Trả lời' : 'Sửa trả lời')),
            ),
        ]),
      ),
    );
  }
}

// Form trong bottom sheet -----------------------------------------------------------

class _MilestoneForm extends StatefulWidget {
  const _MilestoneForm({required this.milestone});

  final Json milestone;

  @override
  State<_MilestoneForm> createState() => _MilestoneFormState();
}

class _MilestoneFormState extends State<_MilestoneForm> {
  late final _note = TextEditingController(text: widget.milestone['note'] as String?);
  late var _photos = (widget.milestone['photos'] as List).cast<String>();

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Báo xong: ${widget.milestone['title']}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('Chụp ảnh thực tế để chủ nhà nghiệm thu từ xa.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Ghi chú', alignLabelWithHint: true),
          maxLines: 3,
          maxLength: 2000,
        ),
        PhotoPicker(photos: _photos, onChanged: (p) => setState(() => _photos = p)),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.pop(context, (_note.text, _photos)), child: const Text('Gửi chủ nhà nghiệm thu')),
      ]);
}

class _ChangeForm extends StatefulWidget {
  const _ChangeForm();

  @override
  State<_ChangeForm> createState() => _ChangeFormState();
}

class _ChangeFormState extends State<_ChangeForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _days = TextEditingController(text: '0');
  var _reduce = false;

  void _done() {
    final amount = parseMillions(_amount.text);
    final days = int.tryParse(_days.text.trim());
    if (_title.text.trim().isEmpty) return showError(context, const ApiException(400, 'missing_title'));
    if (amount == null) return showError(context, const ApiException(400, 'invalid_amount'));
    if (days == null) return showError(context, const ApiException(400, 'invalid_days_delta'));
    Navigator.pop(context, {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'amount': _reduce ? -amount : amount,
      'days_delta': days,
    });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Đề nghị phát sinh', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Nội dung', hintText: 'Thêm kệ ban công')),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          decoration: const InputDecoration(labelText: 'Lý do, chi tiết', alignLabelWithHint: true),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Tăng tiền'), icon: Icon(Icons.add)),
            ButtonSegment(value: true, label: Text('Giảm tiền'), icon: Icon(Icons.remove)),
          ],
          selected: {_reduce},
          onSelectionChanged: (s) => setState(() => _reduce = s.first),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'Số tiền (triệu)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _days,
              decoration: const InputDecoration(labelText: 'Thêm ngày'),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        FilledButton(onPressed: _done, child: const Text('Gửi chủ nhà')),
      ]);
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm();

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final _scores = {for (final k in ReviewCard.criteria.keys) k: 5};
  final _content = TextEditingController();
  var _photos = <String>[];

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Đánh giá nhà thầu', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('Đánh giá hiển thị công khai trên hồ sơ nhà thầu.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        for (final MapEntry(:key, :value) in ReviewCard.criteria.entries)
          Row(children: [
            Expanded(child: Text(value)),
            for (var i = 1; i <= 5; i++)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '$i sao',
                onPressed: () => setState(() => _scores[key] = i),
                icon: Icon(i <= _scores[key]! ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.accent),
              ),
          ]),
        const SizedBox(height: 8),
        TextField(
          controller: _content,
          decoration: const InputDecoration(labelText: 'Chia sẻ trải nghiệm', alignLabelWithHint: true),
          maxLines: 4,
          maxLength: 3000,
        ),
        PhotoPicker(photos: _photos, onChanged: (p) => setState(() => _photos = p)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pop(context, {..._scores, 'content': _content.text, 'photos': _photos}),
          child: const Text('Gửi đánh giá'),
        ),
      ]);
}

class _TextForm extends StatefulWidget {
  const _TextForm({required this.title, required this.label, this.initial = ''});

  final String title;
  final String label;
  final String initial;

  @override
  State<_TextForm> createState() => _TextFormState();
}

class _TextFormState extends State<_TextForm> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.label, alignLabelWithHint: true),
          maxLines: 4,
          maxLength: 2000,
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => _text.text.trim().isEmpty ? null : Navigator.pop(context, _text.text.trim()),
          child: const Text('Gửi'),
        ),
      ]);
}
