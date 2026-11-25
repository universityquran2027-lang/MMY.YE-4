import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/security/password_hasher.dart';
import '../../core/widgets.dart';
import '../transfer/transfer_screen.dart';
import '../inventory/inventory_screen.dart';
import '../reports/report_service.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final role = Role.parse(widget.user['role']);
    final tabs = [
      ('الحسابات', Symbols.manage_accounts),
      ('الحماية', Symbols.shield),
      ('هوية القناة', Symbols.badge),
      ('صور النظرة العامة', Symbols.photo_library),
      ('المخزن والتجهيزات', Symbols.inventory_2),
      ('تصدير واستيراد', Symbols.swap_horiz),
      ('التقارير', Symbols.print),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('لوحة التحكم', style: Theme.of(context).textTheme.headlineSmall),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: [
              for (var i = 0; i < tabs.length; i++)
                ButtonSegment(
                  value: i,
                  icon: Icon(tabs[i].$2),
                  label: Text(tabs[i].$1),
                ),
            ],
            selected: {_tab},
            onSelectionChanged: (value) => setState(() => _tab = value.first),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: switch (_tab) {
            0 => _accounts(role),
            4 => InventoryScreen(app: widget.app, user: widget.user),
            5 => TransferScreen(app: widget.app, user: widget.user),
            6 => _reports(),
            _ => _placeholder(role),
          },
        ),
      ],
    );
  }

  Widget _accounts(Role role) {
    if (!role.canManageAccounts) {
      return const Center(child: Text('لا تملك صلاحية إدارة الحسابات.'));
    }
    return FutureBuilder<List<Map<String, Object?>>>(
      future: widget.app.db.query('users', orderBy: 'serial'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: Text('الحسابات الإدارية', style: Theme.of(context).textTheme.titleLarge)),
                if (users.length < 3)
                  FilledButton.icon(
                    onPressed: _addAccount,
                    icon: const Icon(Symbols.person_add),
                    label: const Text('إضافة حساب'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final u in users)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Symbols.person)),
                  title: Text('${u['full_name']}'),
                  subtitle: Text('${u['username']} • ${_roleLabel('${u['role']}')}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      StatusChip('${u['status']}'),
                      PopupMenuButton<String>(
                        onSelected: (action) => _accountAction(u, action),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'password', child: Text('تغيير كلمة المرور')),
                          PopupMenuItem(
                            value: u['status'] == 'active' ? 'suspend' : 'activate',
                            child: Text(u['status'] == 'active' ? 'إيقاف الحساب' : 'إعادة تفعيل الحساب'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _roleLabel(String role) => switch (role) {
        'manager' => 'المدير',
        'assistant' => 'مساعد المدير',
        'archivist' => 'موظف الأرشيف',
        _ => role,
      };

  Future<void> _addAccount() async {
    final existing = await widget.app.db.query('users');
    final used = existing.map((u) => '${u['role']}').toSet();
    final options = <(String, String)>[
      if (!used.contains('assistant')) ('assistant', 'مساعد المدير'),
      if (!used.contains('archivist')) ('archivist', 'موظف الأرشيف'),
      if (!used.contains('manager')) ('manager', 'المدير'),
    ];
    if (options.isEmpty) return;
    final values = await showRecordForm(
      context,
      title: 'إضافة حساب إداري',
      fields: [
        const FieldSpec('full_name', 'الاسم الكامل', required: true),
        const FieldSpec('username', 'اسم المستخدم', required: true),
        const FieldSpec('password', 'كلمة المرور الابتدائية', required: true),
        FieldSpec('role', 'المنصب', type: FieldType.dropdown, required: true, options: options),
      ],
    );
    if (values == null) return;
    final roleName = values['role'] as String;
    final username = (values['username'] as String).trim();
    final password = values['password'] as String;
    final policyError = PasswordPolicy.validate(password, username: username);
    if (policyError != null) {
      toast(context, policyError);
      return;
    }
    final roleConflict = await widget.app.db.query('users', where: 'role = ?', whereArgs: [roleName], limit: 1);
    if (roleConflict.isNotEmpty) {
      toast(context, 'يوجد حساب مسنداً لهذا المنصب بالفعل.');
      return;
    }
    final t = nowIso();
    final id = newId();
    await widget.app.db.insert('users', {
      'id': id,
      'serial': existing.length + 1,
      'username': username,
      'password_hash': await PasswordHasher().hash(password),
      'full_name': values['full_name'],
      'role': roleName,
      'status': 'active',
      'must_change_password': 1,
      'created_at': t,
      'updated_at': t,
    });
    await widget.app.audit('${widget.user['id']}', 'users', 'add_account', username);
    if (mounted) setState(() {});
  }

  Future<void> _accountAction(Map<String, Object?> user, String action) async {
    final id = '${user['id']}';
    if (action == 'password') {
      final values = await showRecordForm(
        context,
        title: 'تغيير كلمة مرور ${user['full_name']}',
        fields: const [
          FieldSpec('password', 'كلمة المرور الجديدة', required: true),
          FieldSpec('confirm', 'تأكيد كلمة المرور', required: true),
        ],
      );
      if (values == null) return;
      if (values['password'] != values['confirm']) {
        toast(context, 'تأكيد كلمة المرور غير مطابق.');
        return;
      }
      final password = values['password'] as String;
      final policyError = PasswordPolicy.validate(password, username: '${user['username']}');
      if (policyError != null) {
        toast(context, policyError);
        return;
      }
      await widget.app.db.update(
        'users',
        {
          'password_hash': await PasswordHasher().hash(password),
          'must_change_password': 1,
          'failed_attempts': 0,
          'locked_until': null,
          'updated_at': nowIso(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await widget.app.audit('${widget.user['id']}', 'users', 'change_password', '${user['username']}');
    } else {
      final suspend = action == 'suspend';
      if (suspend && !await confirm(context, 'سيتم إيقاف الدخول لهذا الحساب مع الاحتفاظ بجميع بياناته وعملياته.')) {
        return;
      }
      await widget.app.db.update(
        'users',
        {'status': suspend ? 'suspended' : 'active', 'updated_at': nowIso()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await widget.app.audit('${widget.user['id']}', 'users', suspend ? 'suspend' : 'activate', '${user['username']}');
    }
    if (mounted) setState(() {});
  }

  Widget _reports() => FutureBuilder<List<Map<String, Object?>>>(
        future: widget.app.db.query('centers', orderBy: 'serial'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final centers = snapshot.data!;
          if (centers.isEmpty) return const Center(child: Text('لا توجد مراكز لإنشاء التقارير.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('التقارير الشهرية', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final center in centers)
                Card(
                  child: ListTile(
                    leading: const Icon(Symbols.apartment),
                    title: Text('${center['name']}'),
                    trailing: FilledButton.tonalIcon(
                      onPressed: () => ReportService(widget.app).printCenterReport(
                        centerId: '${center['id']}',
                        year: DateTime.now().year,
                        month: DateTime.now().month,
                      ),
                      icon: const Icon(Symbols.print),
                      label: const Text('طباعة التقرير الشهري'),
                    ),
                  ),
                ),
            ],
          );
        },
      );

  Widget _placeholder(Role role) {
    final titles = ['إدارة الحسابات والصلاحيات', 'إعدادات الحماية', 'هوية القناة', 'صور النظرة العامة'];
    final descriptions = [
      'إيقاف وإعادة تفعيل الحسابات وتغيير كلمات المرور وفق صلاحيات المدير.',
      'محاولات الدخول المؤقتة والإيقاف والسجل الأمني.',
      'اسم القناة والشعار ومعاينة الهوية في واجهات النظام والتقارير.',
      'إضافة وترتيب وحذف صور النظرة العامة في السلايدر.',
    ];
    final i = _tab;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titles[i], style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(descriptions[i]),
                const SizedBox(height: 12),
                Text(
                  role.canManageAccounts
                      ? 'هذه النافذة جاهزة للربط بعد استكمال المستودعات النهائية.'
                      : 'لا تملك صلاحية إدارة هذه النافذة.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
