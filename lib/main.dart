import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'app_state.dart';
import 'env.dart';
import 'screens/account.dart';
import 'screens/contractor.dart';
import 'screens/home.dart';
import 'screens/jobs.dart';
import 'screens/measure.dart';
import 'screens/requests.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  api = Api(Env.apiUrl, prefs);
  app = AppState(prefs);
  await app.refresh();
  runApp(const HopThauApp());
}

class HopThauApp extends StatelessWidget {
  const HopThauApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Hợp Thầu',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeShell(),
      );
}

typedef _Tab = (IconData icon, IconData selected, String label, Widget screen);

/// Khung chính: bộ tab và nút giữa theo chế độ.
/// Chủ nhà: Khám phá · Yêu cầu · [Đo nhà] · Công trình · Tài khoản.
/// Nhà thầu: Khách hàng · Công trình · [Tạo gói] · Gói của tôi · Tài khoản.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: app.mode,
        // Đổi chế độ thì dựng lại từ đầu, về tab đầu tiên.
        builder: (context, mode, _) => _Shell(key: ValueKey(mode), mode: mode),
      );
}

class _Shell extends StatefulWidget {
  const _Shell({super.key, required this.mode});

  final AppMode mode;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  var _tab = 0;

  bool get _contractor => widget.mode == AppMode.contractor;

  late final List<_Tab> _tabs = _contractor
      ? const [
          (Icons.inbox_outlined, Icons.inbox, 'Khách hàng', ContractorLeadsScreen()),
          (Icons.construction_outlined, Icons.construction, 'Công trình', JobsScreen(role: 'contractor')),
          (Icons.chair_outlined, Icons.chair, 'Gói của tôi', ContractorPackagesScreen()),
          (Icons.person_outline, Icons.person, 'Tài khoản', AccountScreen()),
        ]
      : const [
          (Icons.home_outlined, Icons.home, 'Khám phá', HomeScreen()),
          (Icons.receipt_long_outlined, Icons.receipt_long, 'Yêu cầu', MyRequestsScreen()),
          (Icons.construction_outlined, Icons.construction, 'Công trình', JobsScreen(role: 'owner')),
          (Icons.person_outline, Icons.person, 'Tài khoản', AccountScreen()),
        ];

  Future<void> _center() async {
    if (!_contractor) return MeasurementsScreen.open(context);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PackageEditorScreen()));
    app.packagesVersion.value++;
  }

  Widget _tabButton(int index) {
    final (icon, selectedIcon, label, _) = _tabs[index];
    final selected = _tab == index;
    final color = selected ? AppColors.primary : AppColors.muted;
    return Expanded(
      child: InkResponse(
        onTap: () => setState(() => _tab = index),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(selected ? selectedIcon : icon, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: selected ? FontWeight.w600 : null)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _tab, children: [for (final t in _tabs) t.$4]),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton(
          tooltip: _contractor ? 'Tạo gói mới' : 'Tự đo nhà',
          elevation: 2,
          backgroundColor: _contractor ? AppColors.accent : AppColors.primary,
          foregroundColor: _contractor ? AppColors.text : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onPressed: _center,
          child: Icon(_contractor ? Icons.add_rounded : Icons.straighten_rounded),
        ),
        bottomNavigationBar: BottomAppBar(
          color: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.black26,
          height: 68,
          child: Row(children: [
            _tabButton(0),
            _tabButton(1),
            const SizedBox(width: 72),
            _tabButton(2),
            _tabButton(3),
          ]),
        ),
      );
}
