// Đăng nhập / đăng ký, tài khoản.

import 'package:flutter/material.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import 'common.dart';
import 'contractor.dart';
import 'contractor_profile.dart';
import 'measure.dart';

/// Chưa đăng nhập thì mở màn đăng nhập. true khi đã đăng nhập xong.
Future<bool> ensureSignedIn(BuildContext context) async {
  if (api.session.value != null) return true;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  return api.session.value != null;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  var _register = false;
  var _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      _register ? await api.register(_phone.text, _password.text, _name.text) : await api.login(_phone.text, _password.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
        const Illustration(Icons.chair_outlined),
        const SizedBox(height: 24),
        Text(_register ? 'Tạo tài khoản Hợp Thầu' : 'Chào mừng trở lại', style: text.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          _register
              ? 'Lưu gói bạn thích, gửi yêu cầu và theo dõi báo giá của nhà thầu.'
              : 'Đăng nhập để gửi yêu cầu và xem báo giá của bạn.',
          style: text.bodyMedium?.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        if (_register) ...[
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Họ tên', prefixIcon: Icon(Icons.person_outline)),
            textCapitalization: TextCapitalization.words,
          ),
          gap,
        ],
        TextField(
          controller: _phone,
          decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_outlined)),
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
        gap,
        TextField(
          controller: _password,
          decoration: const InputDecoration(labelText: 'Mật khẩu', prefixIcon: Icon(Icons.lock_outline)),
          obscureText: true,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_register ? 'Tạo tài khoản' : 'Đăng nhập'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : () => setState(() => _register = !_register),
          child: Text(_register ? 'Tôi đã có tài khoản' : 'Tạo tài khoản mới'),
        ),
      ]),
    );
  }
}

/// Tab Tài khoản: tên, số điện thoại, vai trò, đăng xuất.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _editName(BuildContext context, String current, VoidCallback reload) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Họ tên'),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Lưu')),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    try {
      await api.patchAuth('/me', {'full_name': name});
      reload();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  // ignore: unused_element
  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá tài khoản?'),
        content: const Text('Không khôi phục được. Hồ sơ nhà thầu và gói (nếu có) sẽ bị ẩn. '
            'Công trình và đánh giá đã có vẫn được giữ lại, không kèm tên và số điện thoại của bạn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xoá vĩnh viễn'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await api.deleteAuth('/me');
      await api.logout();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: app.me,
        builder: (context, me, _) => Scaffold(
          appBar: AppBar(title: const Text('Tài khoản')),
          body: me == null
              ? ListView(padding: const EdgeInsets.only(bottom: 110), children: [
                  EmptyState(
                    icon: Icons.person_outline,
                    title: 'Bạn chưa đăng nhập',
                    body: 'Đăng nhập bằng số điện thoại để gửi yêu cầu, nhận báo giá và theo dõi công trình.',
                    action: FilledButton(onPressed: () => ensureSignedIn(context), child: const Text('Đăng nhập')),
                  ),
                  RowCard(
                    icon: Icons.handyman_outlined,
                    title: 'Bạn là nhà thầu, xưởng nội thất?',
                    subtitle: 'Đăng nhập rồi đăng ký hồ sơ để đăng gói, nhận khách',
                    onTap: () => openContractorSignup(context),
                  ),
                ])
              : ValueListenableBuilder(
                  valueListenable: app.mode,
                  builder: (context, mode, _) => _AccountBody(me: me, mode: mode, parent: this),
                ),
        ),
      );
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({required this.me, required this.mode, required this.parent});

  final Map<String, dynamic> me;
  final AppMode mode;
  final AccountScreen parent;

  @override
  Widget build(BuildContext context) {
    final name = me['full_name'] as String;
    final phone = me['phone'] as String;
    final contractorMode = mode == AppMode.contractor;
    return ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 110), children: [
      // Thẻ tài khoản + chế độ đang dùng.
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  name.isEmpty ? '?' : name.trim().split(' ').last.characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 22, color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isEmpty ? 'Chưa đặt tên' : name, style: Theme.of(context).textTheme.titleMedium),
                  Text('0${phone.substring(2)}', style: const TextStyle(color: AppColors.muted)),
                ]),
              ),
              Pill(contractorMode ? 'Nhà thầu' : 'Chủ nhà', color: contractorMode ? AppColors.accent : AppColors.primary),
            ]),
          ),
        ),
      ),
      if (app.isContractor) ...[
        const SectionTitle('Chế độ sử dụng'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<AppMode>(
            segments: const [
              ButtonSegment(value: AppMode.owner, label: Text('Chủ nhà'), icon: Icon(Icons.home_outlined)),
              ButtonSegment(value: AppMode.contractor, label: Text('Nhà thầu'), icon: Icon(Icons.handyman_outlined)),
            ],
            selected: {mode},
            onSelectionChanged: (s) => app.setMode(s.first),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
              'Chủ nhà: tìm gói, xin báo giá, theo dõi nhà mình. Nhà thầu: nhận khách, báo giá, quản lý gói và công trình.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ],
      SectionTitle(contractorMode ? 'Nhà thầu' : 'Nhà của tôi'),
      if (contractorMode) ...[
        RowCard(
          icon: Icons.storefront_outlined,
          title: 'Hồ sơ nhà thầu',
          subtitle: 'Tên xưởng, khu vực, phong cách, giới thiệu',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractorProfileEditScreen())),
        ),
        RowCard(
          icon: Icons.visibility_outlined,
          title: 'Xem hồ sơ công khai',
          subtitle: 'Như chủ nhà nhìn thấy (khi đã xác minh)',
          onTap: () async {
            final c = await api.getAuth('/contractor') as Map<String, dynamic>?;
            if (c != null && context.mounted) ContractorProfileScreen.open(context, c['id'] as String);
          },
        ),
      ] else ...[
        RowCard(
          icon: Icons.straighten_rounded,
          title: 'Bản đo nhà của tôi',
          subtitle: 'Mặt bằng, khung 3D, diện tích để gửi nhà thầu',
          onTap: () => MeasurementsScreen.open(context),
        ),
        if (!app.isContractor)
          RowCard(
            icon: Icons.handyman_outlined,
            title: 'Trở thành nhà thầu',
            subtitle: 'Bạn là xưởng, nhà thầu nội thất? Đăng gói theo mẫu căn, nhận khách',
            onTap: () => openContractorSignup(context),
          ),
      ],
      const SectionTitle('Tài khoản'),
      RowCard(
        icon: Icons.edit_outlined,
        title: 'Đổi họ tên',
        subtitle: name.isEmpty ? 'Tên hiển thị với nhà thầu / chủ nhà' : name,
        onTap: () => parent._editName(context, name, app.refresh),
      ),
      RowCard(icon: Icons.logout_rounded, title: 'Đăng xuất', subtitle: 'Đăng xuất khỏi máy này', onTap: api.logout),
      // ponytail: tạm ẩn "Xoá tài khoản" theo yêu cầu. App Store bắt buộc có xoá tài khoản trong app nếu cho đăng ký:
      // bật lại trước khi nộp bản iOS (hàm _deleteAccount và API DELETE /me vẫn giữ nguyên).
    ]);
  }
}
