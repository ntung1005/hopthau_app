// Chế độ nhà thầu: khách hàng được ghép (báo giá), gói của tôi (tạo, sửa, gửi duyệt); đăng ký / sửa hồ sơ
// (mở từ tab Tài khoản). Chủ nhà không thấy các màn này.

import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../format.dart';
import '../photos.dart';
import '../theme.dart';
import 'account.dart';
import 'common.dart';
import 'jobs.dart';
import '../measure/model.dart';
import 'measure.dart';

typedef Json = Map<String, dynamic>;

const _profileStatus = {
  'pending': ('Chờ xác minh', AppColors.accent),
  'verified': ('Đã xác minh', AppColors.success),
  'rejected': ('Bị từ chối', AppColors.error),
};

const _packageStatus = {
  'draft': ('Nháp', AppColors.muted),
  'pending': ('Chờ duyệt', AppColors.accent),
  'published': ('Đang hiển thị', AppColors.success),
  'hidden': ('Đã ẩn', AppColors.muted),
};

const _leadStatus = {
  'sent': ('Cần báo giá', AppColors.accent),
  'quoted': ('Đã báo giá', AppColors.primary),
  'accepted': ('Khách đã chọn bạn', AppColors.success),
  'declined': ('Khách chọn nhà thầu khác', AppColors.muted),
};

(String, Color) statusOf(Map<String, (String, Color)> map, Object? key) => map[key] ?? ('$key', AppColors.muted);

List<String> _splitList(String s) => s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

/// Mở trang đăng ký làm nhà thầu (từ tab Tài khoản). Đăng ký xong chuyển sang chế độ nhà thầu.
Future<void> openContractorSignup(BuildContext context) async {
  if (!await ensureSignedIn(context) || !context.mounted) return;
  await app.refresh();
  // Vừa đăng nhập bằng tài khoản đã là nhà thầu: chuyển chế độ luôn, không đăng ký lại.
  if (app.isContractor) return app.setMode(AppMode.contractor);
  if (!context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractorSignupScreen()));
}

// Đăng ký / sửa hồ sơ ----------------------------------------------------------

class ContractorSignupScreen extends StatelessWidget {
  const ContractorSignupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Đăng ký làm nhà thầu')),
        body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), children: [
          const Illustration(Icons.handyman_outlined),
          const SizedBox(height: 16),
          Text('Nhận khách đã tự đo nhà', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'Chủ nhà gửi bản đo, khu vực và hạng mục cần làm; bạn nhận yêu cầu đúng tỉnh và đúng việc mình làm, báo giá '
            'sơ bộ ngay trong app. Đội vận hành gọi xác minh giấy phép kinh doanh trước khi gửi khách. Miễn phí giai đoạn đầu.\n'
            'Đã gửi hồ sơ qua web? Đăng ký bằng đúng số điện thoại đó, hồ sơ tự gắn vào tài khoản.',
            style: TextStyle(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _ProfileForm(
            submitLabel: 'Gửi đăng ký',
            onSaved: () async {
              await app.refresh();
              await app.setMode(AppMode.contractor);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ]),
      );
}

/// Sửa hồ sơ nhà thầu (từ tab Tài khoản ở chế độ nhà thầu).
class ContractorProfileEditScreen extends StatelessWidget {
  const ContractorProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Hồ sơ nhà thầu')),
        body: Loader<Json?>(
          load: () async => await api.getAuth('/contractor') as Json?,
          builder: (context, profile, _) => ListView(padding: const EdgeInsets.all(24), children: [
            if (profile != null) ...[
              _VerifyBanner(profile: profile),
              const SizedBox(height: 16),
            ],
            _ProfileForm(initial: profile, submitLabel: 'Lưu', onSaved: () => Navigator.pop(context)),
          ]),
        ),
      );
}

/// Dải trạng thái xác minh, chỉ hiện khi chưa xác minh.
class _VerifyBanner extends StatelessWidget {
  const _VerifyBanner({required this.profile});

  final Json profile;

  @override
  Widget build(BuildContext context) {
    if (profile['status'] == 'verified') return const SizedBox.shrink();
    final (label, color) = statusOf(_profileStatus, profile['status']);
    return InfoPanel(children: [
      Pill(label, color: color),
      const SizedBox(height: 6),
      Text(
        profile['status'] == 'rejected'
            ? 'Hồ sơ chưa được duyệt. Liên hệ đội vận hành để bổ sung giấy tờ.'
            : 'Đội vận hành sẽ gọi xác minh trong 1 ngày làm việc. Gói của bạn hiển thị với chủ nhà sau khi được xác minh.',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    ]);
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.submitLabel, required this.onSaved, this.initial});

  final String submitLabel;
  final VoidCallback onSaved;
  final Json? initial;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final _name = TextEditingController(text: widget.initial?['name'] as String?);
  late final _address = TextEditingController(text: widget.initial?['address'] as String?);
  late var _areas = {...?(widget.initial?['areas'] as List?)?.cast<String>()};
  late var _services = {...?(widget.initial?['services'] as List?)?.cast<String>()};
  late final _years = TextEditingController(text: '${widget.initial?['years_experience'] ?? ''}');
  late final _website = TextEditingController(text: widget.initial?['website'] as String?);
  late final _styles = TextEditingController(text: (widget.initial?['styles'] as List?)?.join(', '));
  late final _bio = TextEditingController(text: widget.initial?['bio'] as String?);
  final _taxCode = TextEditingController();
  var _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final body = {
      'name': _name.text,
      'address': _address.text,
      'areas': _areas.toList(),
      'services': _services.toList(),
      'years_experience': int.tryParse(_years.text.trim()),
      'website': _website.text.trim(),
      'styles': _splitList(_styles.text),
      'bio': _bio.text,
      if (_taxCode.text.trim().isNotEmpty) 'tax_code': _taxCode.text.trim(),
    };
    try {
      widget.initial == null ? await api.postAuth('/contractor', body) : await api.patchAuth('/contractor', body);
      widget.onSaved();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Loader<Json>(
      load: api.meta,
      builder: (context, meta, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên xưởng / công ty')),
        gap,
        TextField(
          controller: _taxCode,
          decoration: InputDecoration(
            labelText: 'Mã số thuế',
            helperText: widget.initial == null ? 'Để xác minh, không hiển thị với chủ nhà' : 'Để trống nếu không đổi',
          ),
        ),
        gap,
        TextField(controller: _address, decoration: const InputDecoration(labelText: 'Địa chỉ xưởng')),
        gap,
        TextField(
          controller: _years,
          decoration: const InputDecoration(labelText: 'Số năm kinh nghiệm'),
          keyboardType: TextInputType.number,
        ),
        gap,
        TextField(
          controller: _website,
          decoration: const InputDecoration(labelText: 'Fanpage / website', hintText: 'facebook.com/xuong-cua-ban'),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 20),
        ChipPicker(
          label: 'Hạng mục nhận làm',
          options: (meta['services'] as List).cast<String>(),
          selected: _services,
          onChanged: (v) => setState(() => _services = v),
        ),
        const SizedBox(height: 20),
        ChipPicker(
          label: 'Tỉnh / thành nhận thi công',
          options: (meta['provinces'] as List).cast<String>(),
          selected: _areas,
          onChanged: (v) => setState(() => _areas = v),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _styles,
          decoration: const InputDecoration(labelText: 'Phong cách', helperText: 'Ví dụ: Hiện đại, Japandi, Tối giản'),
        ),
        gap,
        TextField(
          controller: _bio,
          decoration: const InputDecoration(labelText: 'Giới thiệu', alignLabelWithHint: true),
          maxLines: 3,
          maxLength: 2000,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(widget.submitLabel)),
      ]),
    );
  }
}

// Khách hàng (tab đầu ở chế độ nhà thầu) ---------------------------------------------

/// Khách hàng được ghép: dải trạng thái xác minh, tóm tắt (cần báo giá / đã báo / đã chọn bạn), danh sách.
class ContractorLeadsScreen extends StatelessWidget {
  const ContractorLeadsScreen({super.key});

  Future<(Json?, List<Json>)> _load() async {
    final r = await Future.wait([api.getAuth('/contractor'), api.getAuth('/contractor/leads')]);
    return (r[0] as Json?, (r[1] as List).cast<Json>());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Khách hàng')),
        body: Loader<(Json?, List<Json>)>(
          load: _load,
          builder: (context, data, reload) {
            final (profile, rows) = data;
            if (profile == null) {
              return EmptyState(
                icon: Icons.handyman_outlined,
                title: 'Chưa có hồ sơ nhà thầu',
                body: 'Đăng ký hồ sơ để nhận khách và đăng gói.',
                action: FilledButton(onPressed: () => openContractorSignup(context), child: const Text('Đăng ký làm nhà thầu')),
              );
            }
            int count(String s) => rows.where((l) => l['status'] == s).length;
            return RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), children: [
                _VerifyBanner(profile: profile),
                if (profile['status'] != 'verified') const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(children: [
                      for (final (n, label, color) in [
                        (count('sent'), 'cần báo giá', AppColors.accent),
                        (count('quoted'), 'đã báo giá', AppColors.primary),
                        (count('accepted'), 'chọn bạn', AppColors.success),
                      ])
                        Expanded(
                          child: Column(children: [
                            Text('$n', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color)),
                            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ]),
                        ),
                    ]),
                  ),
                ),
                if (rows.isEmpty)
                  const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Chưa có khách',
                    body:
                        'Khi chủ nhà bấm "Nhận tư vấn" ở gói của bạn, hoặc gửi yêu cầu ở khu vực bạn phục vụ, khách sẽ hiện ở đây.',
                  ),
                // Cần báo giá lên trước.
                for (final lead in [...rows]..sort((a, b) => (a['status'] == 'sent' ? 0 : 1) - (b['status'] == 'sent' ? 0 : 1)))
                  _LeadCard(
                    lead: lead,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => LeadScreen(lead: lead)));
                      reload();
                    },
                  ),
              ]),
            );
          },
        ),
      );
}

String _leadPlace(Json request) => requestPlace(request, withArea: true);

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead, required this.onTap});

  final Json lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = lead['request'] as Json;
    final owner = lead['owner'] as Json;
    final (label, color) = statusOf(_leadStatus, lead['status']);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IconBadge(Icons.person_outline),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((owner['full_name'] as String).isEmpty ? 'Chủ nhà' : owner['full_name'] as String,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  [
                    _leadPlace(r),
                    if (servicesLine(r).isNotEmpty) servicesLine(r),
                    if (r['package'] != null) 'Gói: ${r['package']['name']}',
                    if (r['measurement'] != null) 'Có bản đo nhà',
                    if (lead['mode'] == 'offline' && lead['status'] != 'sent') 'Bạn đề nghị làm việc trực tiếp',
                    if (lead['price'] != null) 'Bạn báo: ${vnd(lead['price'] as num)}',
                  ].join('\n'),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Pill(label, color: color),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

/// Chi tiết khách: thông tin yêu cầu, gửi hoặc sửa báo giá.
class LeadScreen extends StatefulWidget {
  const LeadScreen({super.key, required this.lead});

  final Json lead;

  @override
  State<LeadScreen> createState() => _LeadScreenState();
}

class _LeadScreenState extends State<LeadScreen> {
  late final _price =
      TextEditingController(text: widget.lead['price'] == null ? '' : vnDecimal((widget.lead['price'] as num) / 1000000));
  late final _days = TextEditingController(text: '${widget.lead['duration_days'] ?? ''}');
  late final _message = TextEditingController(text: widget.lead['message'] as String?);
  late var _offline = widget.lead['mode'] == 'offline';
  var _busy = false;

  /// Đồ chủ nhà chọn trong bản đo (để đánh dấu món bạn thêm / bỏ) và tên các phòng.
  var _asked = <Json>[];
  var _rooms = <String>[];

  /// Món đang báo: bắt đầu từ báo giá cũ, chưa báo thì từ đồ chủ nhà chọn (đơn giá để trống).
  final _lines = <_QuoteLineEdit>[];

  Json get _request => widget.lead['request'] as Json;

  @override
  void initState() {
    super.initState();
    for (final i in (widget.lead['items'] as List? ?? const []).cast<Json>()) {
      _lines.add(_QuoteLineEdit.from(i));
    }
    _loadMeasurement();
  }

  Future<void> _loadMeasurement() async {
    final id = _request['measurement']?['id'] as String?;
    if (id == null) return;
    try {
      final plan = Plan.fromJson((await api.getAuth('/measurements/$id') as Json)['data'] as Json);
      if (!mounted) return;
      setState(() {
        _asked = plan.askedItems;
        _rooms = [for (final r in plan.rooms) r.name];
        if (_lines.isEmpty) _lines.addAll(_asked.map(_QuoteLineEdit.from));
      });
    } catch (_) {
      // Không tải được bản đo thì vẫn báo giá trọn gói được.
    }
  }

  int? get _total {
    var sum = 0;
    for (final l in _lines) {
      final p = parseMillions(l.price.text);
      if (p == null) return null;
      sum += p * l.qty;
    }
    return sum;
  }

  Future<void> _submit() async {
    final days = int.tryParse(_days.text.trim());
    final Map<String, Object?> body;
    if (_offline) {
      if (_message.text.trim().isEmpty) return showError(context, const ApiException(400, 'missing_message'));
      body = {'mode': 'offline', 'message': _message.text, if (days != null) 'duration_days': days};
    } else {
      if (days == null || days <= 0) return showError(context, const ApiException(400, 'invalid_duration_days'));
      if (_lines.isEmpty) {
        final price = parseMillions(_price.text);
        if (price == null) return showError(context, const ApiException(400, 'invalid_price'));
        body = {'mode': 'in_app', 'price': price, 'duration_days': days, 'message': _message.text};
      } else {
        if (_total == null) return showError(context, const ApiException(400, 'invalid_price'));
        body = {
          'mode': 'in_app',
          'duration_days': days,
          'message': _message.text,
          'items': [for (final l in _lines) l.toJson()],
        };
      }
    }
    setState(() => _busy = true);
    try {
      await api.postAuth('/contractor/leads/${_request['id']}/quote', body);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_offline ? 'Đã gửi đề nghị làm việc trực tiếp' : 'Đã gửi báo giá cho chủ nhà')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addLine([Json? restore]) async {
    if (restore != null) return setState(() => _lines.add(_QuoteLineEdit.from(restore)));
    final rooms = [..._rooms, 'Chung'];
    var room = rooms.first;
    final name = TextEditingController(), note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đề xuất thêm món'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: room,
            decoration: const InputDecoration(labelText: 'Phòng'),
            items: [for (final r in rooms) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => room = v ?? room,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            autofocus: true,
            maxLength: 50,
            decoration: const InputDecoration(labelText: 'Tên món', hintText: 'Ví dụ: Nhân công lắp đặt'),
          ),
          TextField(controller: note, maxLength: 100, decoration: const InputDecoration(labelText: 'Ghi chú')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Thêm')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    setState(() => _lines.add(_QuoteLineEdit(room, name.text.trim(), 1, note.text.trim().isEmpty ? null : note.text.trim())));
  }

  Widget _itemEditor() {
    final diff = quoteDiff(_asked, [for (final l in _lines) l.toJson()]);
    final total = _total;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Sửa số lượng, bỏ hoặc đề xuất thêm món; nhập đơn giá từng món. Tổng giá tự cộng.',
          style: TextStyle(color: AppColors.muted, fontSize: 13)),
      const SizedBox(height: 8),
      for (final (i, l) in _lines.indexed)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text([l.room, if (l.note != null) l.note].join(' · '),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  if (diff[i].tag == 'added') const Pill('Bạn đề xuất thêm', color: AppColors.success),
                  if (diff[i].tag == 'changed') Pill('Khách chọn ${diff[i].askedQty}', color: AppColors.accent),
                ]),
              ),
              IconButton(
                tooltip: l.qty > 1 ? 'Bớt' : 'Bỏ món',
                icon: Icon(l.qty > 1 ? Icons.remove_circle_outline : Icons.delete_outline),
                onPressed: () => setState(() => l.qty > 1 ? l.qty-- : _lines.remove(l)),
              ),
              Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                tooltip: 'Thêm',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: l.qty >= 99 ? null : () => setState(() => l.qty++),
              ),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: l.price,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'Giá', suffixText: 'tr', isDense: true),
                ),
              ),
            ]),
          ),
        ),
      for (final d in diff.where((d) => d.tag == 'removed'))
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('${d.name} × ${d.qty}',
              style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.muted)),
          subtitle: Text('${d.room} · khách chọn, bạn đã bỏ'),
          trailing: TextButton(
            onPressed: () => _addLine({'room': d.room, 'name': d.name, 'qty': d.qty, 'note': d.note}),
            child: const Text('Thêm lại'),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: () => _addLine(), icon: const Icon(Icons.add), label: const Text('Đề xuất thêm món')),
      ),
      InfoPanel(children: [
        Row(children: [
          const Text('Tổng báo giá', style: TextStyle(color: AppColors.muted)),
          const Spacer(),
          Text(total == null ? 'Nhập đủ đơn giá' : vnd(total),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary)),
        ]),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final r = _request;
    final owner = lead['owner'] as Json;
    final (label, color) = statusOf(_leadStatus, lead['status']);
    final canQuote = r['status'] == 'open' && (lead['status'] == 'sent' || lead['status'] == 'quoted');
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu của khách')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        InfoPanel(children: [
          Text((owner['full_name'] as String).isEmpty ? 'Chủ nhà' : owner['full_name'] as String,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(_leadPlace(r), style: const TextStyle(color: AppColors.muted)),
          if (servicesLine(r).isNotEmpty) Text(servicesLine(r), style: const TextStyle(color: AppColors.muted)),
          if (r['package'] != null) Text('Gói: ${r['package']['name']}', style: const TextStyle(color: AppColors.muted)),
          if (r['budget'] != null) Text('Ngân sách ${vnd(r['budget'] as num)}', style: const TextStyle(color: AppColors.muted)),
          if ((r['note'] as String?)?.isNotEmpty ?? false) ...[const SizedBox(height: 6), Text('${r['note']}')],
          const SizedBox(height: 10),
          Pill(label, color: color),
        ]),
        if (r['measurement'] != null) ...[
          const SizedBox(height: 12),
          Card(
            color: AppColors.primarySoft,
            child: ListTile(
              leading: const IconBadge(Icons.view_in_ar, size: 40),
              title: const Text('Khách đã tự đo nhà', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Mặt bằng, khung 3D, diện tích${_asked.isEmpty ? '' : ', ${_asked.length} món đồ khách chọn'}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => MeasurementViewerScreen.open(context, r['measurement']['id'] as String),
            ),
          ),
        ],
        if (r['job'] != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => JobScreen(id: r['job']['id'] as String))),
            icon: const Icon(Icons.construction_outlined),
            label: const Text('Mở công trình'),
          ),
        ],
        if (owner['phone'] != null) ...[
          const SectionTitle('Liên hệ khách'),
          PhoneRow(phone: owner['phone'] as String),
        ] else if (lead['status'] != 'declined')
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child:
                Text('Số điện thoại của khách hiện khi khách chọn bạn.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
        if (canQuote) ...[
          SectionTitle(lead['status'] == 'quoted' ? 'Sửa trả lời' : 'Trả lời khách'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Báo giá trong app'), icon: Icon(Icons.request_quote_outlined)),
              ButtonSegment(value: true, label: Text('Làm việc trực tiếp'), icon: Icon(Icons.handshake_outlined)),
            ],
            selected: {_offline},
            onSelectionChanged: (s) => setState(() => _offline = s.first),
          ),
          gap,
          if (_offline)
            const Text(
                'Bạn và khách tự gặp, khảo sát và thoả thuận giá bên ngoài. Nếu khách chọn bạn, hai bên thấy số điện thoại; '
                'app chỉ theo dõi tiến độ 4 mốc (báo xong kèm ảnh, khách nghiệm thu), không ghi nhận tiền.',
                style: TextStyle(color: AppColors.muted, fontSize: 13))
          else if (_lines.isNotEmpty || _asked.isNotEmpty)
            _itemEditor()
          else
            TextField(
              controller: _price,
              decoration:
                  const InputDecoration(labelText: 'Giá trọn gói (triệu đồng)', prefixIcon: Icon(Icons.payments_outlined)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          gap,
          TextField(
            controller: _days,
            decoration: InputDecoration(
              labelText: 'Số ngày thi công',
              helperText: _offline ? 'Không bắt buộc' : null,
              prefixIcon: const Icon(Icons.schedule_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          gap,
          TextField(
            controller: _message,
            decoration: InputDecoration(
              labelText: _offline ? 'Lời nhắn cho khách (bắt buộc)' : 'Lời nhắn cho khách',
              hintText:
                  _offline ? 'Lịch hẹn khảo sát, cách làm việc...' : 'Lịch khảo sát, vật liệu đề xuất, điều kiện thanh toán...',
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            maxLength: 2000,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_offline ? 'Gửi đề nghị làm việc trực tiếp' : 'Gửi báo giá'),
          ),
        ],
      ]),
    );
  }
}

/// Một món đang sửa trong báo giá; đơn giá nhập theo triệu đồng.
class _QuoteLineEdit {
  _QuoteLineEdit(this.room, this.name, this.qty, this.note, [int? unitPrice])
      : price = TextEditingController(text: unitPrice == null || unitPrice == 0 ? '' : vnDecimal(unitPrice / 1000000));

  factory _QuoteLineEdit.from(Json j) => _QuoteLineEdit(j['room'] as String? ?? 'Chung', j['name'] as String,
      (j['qty'] as num? ?? 1).toInt(), j['note'] as String?, (j['unit_price'] as num?)?.toInt());

  final String room;
  final String name;
  int qty;
  final String? note;
  final TextEditingController price;

  Json toJson() =>
      {'room': room, 'name': name, 'qty': qty, 'unit_price': parseMillions(price.text) ?? 0, if (note != null) 'note': note};
}

// Gói của tôi ---------------------------------------------------------------------

/// Gói của tôi (chế độ nhà thầu). Tạo gói bằng nút giữa thanh điều hướng.
class ContractorPackagesScreen extends StatelessWidget {
  const ContractorPackagesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Gói của tôi')),
        body: ValueListenableBuilder(
          valueListenable: app.packagesVersion,
          builder: (context, version, _) => Loader<List<dynamic>>(
            key: ValueKey(version),
            load: () async => await api.getAuth('/contractor/packages') as List<dynamic>,
            builder: (context, rows, reload) {
              Future<void> open(Json? pkg) async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => PackageEditorScreen(initial: pkg)));
                reload();
              }

              return RefreshIndicator(
                onRefresh: () async => reload(),
                child: rows.isEmpty
                    ? ListView(children: [
                        EmptyState(
                          icon: Icons.chair_outlined,
                          title: 'Chưa có gói nào',
                          body: 'Tạo gói cho một mẫu căn: liệt kê hạng mục, vật liệu, đơn giá. Giá gói tự cộng từ hạng mục.',
                          action: FilledButton.icon(
                            onPressed: () => open(null),
                            icon: const Icon(Icons.add),
                            label: const Text('Tạo gói đầu tiên'),
                          ),
                        ),
                      ])
                    : ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 110), children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Text('Bấm nút + ở giữa để tạo gói mới. Sửa gói đang hiển thị thì gói chờ duyệt lại.',
                              style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        ),
                        for (final p in rows.cast<Json>())
                          RowCard(
                            icon: Icons.chair_outlined,
                            title: p['name'] as String,
                            subtitle: '${p['unit_type']['project']['name']} · ${p['unit_type']['name']}\n'
                                '${vnd(p['price'] as num)} · ${statusOf(_packageStatus, p['status']).$1}',
                            trailing: Icon(Icons.circle, size: 10, color: statusOf(_packageStatus, p['status']).$2),
                            onTap: () => open(p),
                          ),
                      ]),
              );
            },
          ),
        ),
      );
}

/// Tạo / sửa gói: chọn dự án và mẫu căn, thông tin chung, danh sách hạng mục.
/// Lưu là lưu cả gói trong một lần (BE: save_package). Sửa gói đang hiển thị thì gói về chờ duyệt.
class PackageEditorScreen extends StatefulWidget {
  const PackageEditorScreen({super.key, this.initial});

  final Json? initial;

  @override
  State<PackageEditorScreen> createState() => _PackageEditorScreenState();
}

class _PackageEditorScreenState extends State<PackageEditorScreen> {
  late Json? _pkg = widget.initial;
  late final _name = TextEditingController(text: _pkg?['name'] as String?);
  late final _style = TextEditingController(text: _pkg?['style'] as String?);
  late final _days = TextEditingController(text: '${_pkg?['duration_days'] ?? ''}');
  late final _warranty = TextEditingController(text: '${_pkg?['warranty_months'] ?? ''}');
  late final List<Json> _items = [
    for (final i in (_pkg?['items'] as List? ?? const []).cast<Json>()) {...i, 'qty': num.parse('${i['qty']}')},
  ];
  late var _images = ((_pkg?['images'] as List?) ?? const []).cast<String>();
  late String? _projectSlug = (_pkg?['unit_type']?['project'] as Json?)?['slug'] as String?;
  late String? _unitTypeId = _pkg?['unit_type']?['id'] as String?;
  late final Future<List<dynamic>> _projects = api.get('/projects').then((v) => v as List<dynamic>);
  Future<Json>? _project;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    if (_projectSlug != null) _project = _loadProject(_projectSlug!);
  }

  Future<Json> _loadProject(String slug) => api.get('/projects/$slug').then((v) => v as Json);

  String get _pkgStatus => _pkg?['status'] as String? ?? 'draft';

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
        final body = {
          'unit_type_id': _unitTypeId,
          'name': _name.text,
          'style': _style.text,
          'duration_days': int.tryParse(_days.text.trim()),
          'warranty_months': int.tryParse(_warranty.text.trim()),
          'images': _images,
          'items': [
            for (final i in _items)
              {
                for (final k in const ['room', 'name', 'material', 'size', 'qty', 'unit', 'unit_price', 'is_optional']) k: i[k]
              },
          ],
        };
        final saved = (_pkg == null
            ? await api.postAuth('/contractor/packages', body)
            : await api.putAuth('/contractor/packages/${_pkg!['id']}', body)) as Json;
        setState(() => _pkg = saved);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(saved['status'] == 'pending' && widget.initial?['status'] == 'published'
                  ? 'Đã lưu. Gói tạm ẩn chờ duyệt lại vì có thay đổi.'
                  : 'Đã lưu gói')));
        }
      });

  Future<void> _submit() => _run(() async {
        final saved = await api.postAuth('/contractor/packages/${_pkg!['id']}/submit') as Json;
        setState(() => _pkg = saved);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã gửi duyệt. Thường duyệt trong 1 ngày làm việc.')));
        }
      });

  Future<void> _delete() => _run(() async {
        await api.deleteAuth('/contractor/packages/${_pkg!['id']}');
        if (mounted) Navigator.pop(context);
      });

  Future<void> _editItem([int? index]) async {
    final result = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ItemSheet(initial: index == null ? null : _items[index]),
    );
    if (result == null) return;
    setState(() {
      if (result['_delete'] == true) {
        _items.removeAt(index!);
      } else if (index == null) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _items
        .where((i) => i['is_optional'] != true)
        .fold<num>(0, (s, i) => s + ((i['qty'] as num) * (i['unit_price'] as num)).round());
    final (label, color) = statusOf(_packageStatus, _pkgStatus);
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(_pkg == null ? 'Gói mới' : 'Sửa gói'),
        actions: [
          if (_pkg != null && (_pkgStatus == 'draft' || _pkgStatus == 'pending'))
            IconButton(tooltip: 'Xoá gói', icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 180), children: [
        if (_pkg != null) Align(alignment: Alignment.centerLeft, child: Pill(label, color: color)),
        const SectionTitle('Mẫu căn'),
        FutureBuilder<List<dynamic>>(
          future: _projects,
          builder: (context, snap) => DropdownButtonFormField<String>(
            initialValue: _projectSlug,
            decoration: const InputDecoration(labelText: 'Dự án'),
            items: [
              for (final p in (snap.data ?? const []).cast<Json>())
                DropdownMenuItem(value: p['slug'] as String, child: Text(p['name'] as String)),
            ],
            onChanged: (slug) => setState(() {
              _projectSlug = slug;
              _unitTypeId = null;
              _project = slug == null ? null : _loadProject(slug);
            }),
          ),
        ),
        gap,
        FutureBuilder<Json>(
          future: _project,
          builder: (context, snap) => DropdownButtonFormField<String>(
            key: ValueKey(_projectSlug),
            initialValue: _unitTypeId,
            decoration: const InputDecoration(labelText: 'Mẫu căn'),
            items: [
              for (final u in ((snap.data?['unit_types'] as List?) ?? const []).cast<Json>())
                DropdownMenuItem(
                  value: u['id'] as String,
                  child: Text('${u['name']} · ${vnDecimal(u['area_m2'])} m²'),
                ),
            ],
            onChanged: (id) => setState(() => _unitTypeId = id),
          ),
        ),
        const SectionTitle('Thông tin gói'),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên gói', hintText: 'Gói Cơ Bản')),
        gap,
        TextField(controller: _style, decoration: const InputDecoration(labelText: 'Phong cách', hintText: 'Hiện đại')),
        gap,
        Row(children: [
          Expanded(
            child: TextField(
              controller: _days,
              decoration: const InputDecoration(labelText: 'Ngày thi công'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _warranty,
              decoration: const InputDecoration(labelText: 'Bảo hành (tháng)'),
              keyboardType: TextInputType.number,
            ),
          ),
        ]),
        const SectionTitle('Ảnh gói'),
        const Text('Ảnh render hoặc ảnh công trình thực tế của gói này. Ảnh đầu tiên làm ảnh bìa.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 8),
        PhotoPicker(photos: _images, onChanged: (p) => setState(() => _images = p)),
        SectionTitle('Hạng mục (${_items.length})'),
        for (final (i, it) in _items.indexed)
          Card(
            child: ListTile(
              title: Text('${it['room']} · ${it['name']}${it['is_optional'] == true ? ' (tuỳ chọn)' : ''}'),
              subtitle: Text('${vnDecimal(it['qty'])} ${it['unit'] ?? 'bộ'} × ${vnd(it['unit_price'] as num)}'),
              trailing: Text(vnd(((it['qty'] as num) * (it['unit_price'] as num)).round()),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => _editItem(i),
            ),
          ),
        OutlinedButton.icon(onPressed: () => _editItem(), icon: const Icon(Icons.add), label: const Text('Thêm hạng mục')),
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
              const Text('Giá trọn gói', style: TextStyle(color: AppColors.muted)),
              const Spacer(),
              Text(vnd(total), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FilledButton(onPressed: _busy ? null : _save, child: const Text('Lưu'))),
              if (_pkg != null && (_pkgStatus == 'draft' || _pkgStatus == 'hidden')) ...[
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton(onPressed: _busy ? null : _submit, child: const Text('Gửi duyệt'))),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Thêm / sửa một hạng mục. Trả về hạng mục mới, hoặc {'_delete': true}.
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({this.initial});

  final Json? initial;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _room = TextEditingController(text: widget.initial?['room'] as String?);
  late final _name = TextEditingController(text: widget.initial?['name'] as String?);
  late final _material = TextEditingController(text: widget.initial?['material'] as String?);
  late final _size = TextEditingController(text: widget.initial?['size'] as String?);
  late final _qty = TextEditingController(text: widget.initial == null ? '1' : vnDecimal(widget.initial!['qty']));
  late final _unit = TextEditingController(text: widget.initial?['unit'] as String? ?? 'bộ');
  late final _price =
      TextEditingController(text: widget.initial == null ? '' : vnDecimal((widget.initial!['unit_price'] as num) / 1000000));
  late var _optional = widget.initial?['is_optional'] == true;

  void _done() {
    final qty = num.tryParse(_qty.text.trim().replaceAll(',', '.'));
    final price = parseMillions(_price.text);
    if (_room.text.trim().isEmpty || _name.text.trim().isEmpty) {
      return showError(context, const ApiException(400, 'missing_name'));
    }
    if (qty == null || qty <= 0) return showError(context, const ApiException(400, 'invalid_qty'));
    if (price == null) return showError(context, const ApiException(400, 'invalid_price'));
    Navigator.pop(context, {
      'room': _room.text.trim(),
      'name': _name.text.trim(),
      'material': _material.text.trim(),
      'size': _size.text.trim(),
      'qty': qty,
      'unit': _unit.text.trim(),
      'unit_price': price,
      'is_optional': _optional,
    });
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.initial == null ? 'Thêm hạng mục' : 'Sửa hạng mục', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: _room, decoration: const InputDecoration(labelText: 'Phòng', hintText: 'Bếp'))),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
                    controller: _name, decoration: const InputDecoration(labelText: 'Hạng mục', hintText: 'Tủ bếp dưới'))),
          ]),
          gap,
          Row(children: [
            Expanded(child: TextField(controller: _material, decoration: const InputDecoration(labelText: 'Vật liệu'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _size, decoration: const InputDecoration(labelText: 'Kích thước'))),
          ]),
          gap,
          Row(children: [
            Expanded(
              child: TextField(
                controller: _qty,
                decoration: const InputDecoration(labelText: 'Số lượng'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child:
                    TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Đơn vị', hintText: 'bộ, md, m²'))),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _price,
                decoration: const InputDecoration(labelText: 'Đơn giá (triệu)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _optional,
            onChanged: (v) => setState(() => _optional = v),
            title: const Text('Hạng mục tuỳ chọn'),
            subtitle: const Text('Không tính vào giá trọn gói, chủ nhà tự chọn thêm'),
          ),
          gap,
          FilledButton(onPressed: _done, child: const Text('Xong')),
          if (widget.initial != null)
            TextButton(
              onPressed: () => Navigator.pop(context, {'_delete': true}),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Xoá hạng mục'),
            ),
        ]),
      ),
    );
  }
}
