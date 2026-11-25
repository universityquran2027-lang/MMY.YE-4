import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import '../auth/auth_service.dart';
import '../auth/biometric_service.dart';
import '../centers/centers_screen.dart';
import '../staff/staff_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../control/control_screen.dart';
import '../management/management_screen.dart';
import '../tasks/tasks_screen.dart';
import '../inventory/inventory_screen.dart';
import '../evaluation/evaluation_screen.dart';

/// القائمة الرئيسية بالترتيب المعتمد في وثيقة «فكرة البرنامج» (7 أقسام).
/// الأقسام ما زالت هياكل فارغة: لا تُعدّ منفذة حتى تُبنى شاشاتها وتُختبر.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.app, required this.auth, required this.bio, required this.user});
  final AppDatabase app;
  final AuthService auth;
  final BiometricService bio;
  final Map<String, Object?> user;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Section {
  const _Section(this.title, this.subtitle, this.icon);
  final String title, subtitle;
  final IconData icon;
}

const _sections = [
  _Section('النظرة العامة', 'ملخص شامل للبرنامج', Symbols.dashboard),
  _Section('الإدارة', 'المدير ومساعد المدير والأرشيف', Symbols.admin_panel_settings),
  _Section('المراكز', 'إدارة المراكز الإعلامية', Symbols.apartment),
  _Section('المهام الميدانية', 'إنشاء المهام ومتابعة تنفيذها', Symbols.assignment),
  _Section('الكادر الإعلامي', 'ملفات الإعلاميين وتوزيعهم', Symbols.groups),
  _Section('التقييم', 'تقييم أداء المراكز', Symbols.analytics),
  _Section('لوحة التحكم', 'الحماية والحسابات والهوية والإعدادات', Symbols.settings),
];

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = _sections[_index];
    final Widget body = switch (_index) {
      2 => CentersScreen(key: const ValueKey('centers'), app: widget.app, user: widget.user),
      4 => StaffScreen(key: const ValueKey('staff'), app: widget.app, user: widget.user),
      0 => DashboardScreen(app: widget.app, user: widget.user),
      1 => ManagementScreen(app: widget.app, user: widget.user),
      3 => TasksScreen(app: widget.app, user: widget.user),
      5 => EvaluationScreen(app: widget.app, user: widget.user),
      6 => ControlScreen(app: widget.app, user: widget.user),
      _ => _placeholder(s),
    };
    return _scaffold(body);
  }

  Widget _placeholder(_Section s) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(s.icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(s.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${s.subtitle}\n(قيد البناء)', textAlign: TextAlign.center),
        ]),
      );

  Widget _scaffold(Widget body) {
    final wide = MediaQuery.sizeOf(context).width >= 900; // Windows / لوحي أندرويد أفقي
    final s = _sections[_index];
    final destinations = [
      for (var i = 0; i < _sections.length; i++)
        NavigationRailDestination(icon: Icon(_sections[i].icon), label: Text(_sections[i].title)),
    ];
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            extended: true,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ClipOval(child: Container(
                color: Colors.white, width: 72, height: 72, padding: const EdgeInsets.all(8),
                child: SvgPicture.asset('assets/brand/logo.svg'),
              )),
            ),
            destinations: destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [for (final d in _sections) NavigationDestination(icon: Icon(d.icon), label: d.title)],
      ),
    );
  }
}
