import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';
import '../centers/centers_repository.dart';
import 'staff_profile_screen.dart';
import 'staff_repository.dart';

/// قسم الكادر الإعلامي: جدول بحث وتصفية (مركز/حالة) + إضافة + فتح الملف.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Row user;
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late final repo = StaffRepository(widget.app, widget.user['id'] as String);
  late final role = Role.parse(widget.user['role']);
  String _q = '';
  String? _center, _status;
  Future<List<Row>>? _rows;
  List<Row> _centers = [];

  @override
  void initState() {
    super.initState();
    CentersRepository(widget.app, '').all().then((c) => setState(() => _centers = c));
    _reload();
  }

  void _reload() => setState(() => _rows = repo.list(q: _q, centerId: _center, status: _status));

  Future<void> _add() async {
    if (_centers.isEmpty) {
      toast(context, 'أضف مركزاً أولاً من قسم المراكز ثم أضف الإعلاميين.');
      return;
    }
    final v = await showRecordForm(context,
        title: 'إضافة إعلامي', fields: StaffRepository.formFields(_centers), initial: {'status': 'active'});
    if (v == null) return;
    await repo.save(v);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 280, child: TextField(
            decoration: const InputDecoration(hintText: 'بحث بالاسم أو التخصص أو الجوال', prefixIcon: Icon(Icons.search)),
            onChanged: (v) { _q = v; _reload(); },
          )),
          SizedBox(width: 220, child: DropdownButtonFormField<String?>(
            value: _center, decoration: const InputDecoration(labelText: 'المركز'),
            items: [const DropdownMenuItem(value: null, child: Text('كل المراكز')),
              for (final c in _centers) DropdownMenuItem(value: c['id'] as String, child: Text('${c['name']}'))],
            onChanged: (v) { _center = v; _reload(); },
          )),
          SizedBox(width: 160, child: DropdownButtonFormField<String?>(
            value: _status, decoration: const InputDecoration(labelText: 'الحالة'),
            items: const [DropdownMenuItem(value: null, child: Text('الكل')),
              DropdownMenuItem(value: 'active', child: Text('نشط')),
              DropdownMenuItem(value: 'stopped', child: Text('متوقف'))],
            onChanged: (v) { _status = v; _reload(); },
          )),
          if (role.canEditOperations)
            FilledButton.icon(onPressed: _add, icon: const Icon(Icons.person_add_alt_1), label: const Text('إضافة إعلامي')),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Row>>(
            future: _rows,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final rows = snap.data!;
              if (rows.isEmpty) return const EmptyState('لا يوجد إعلاميون مطابقون.');
              return Card(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text('${r['serial']}')),
                      title: Text('${r['full_name']}'),
                      subtitle: Text('${r['center_name'] ?? '—'}  •  ${r['specialty'] ?? '—'}  •  ${r['phone'] ?? '—'}'),
                      trailing: StatusChip('${r['status']}'),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => StaffProfileScreen(app: widget.app, user: widget.user, staffId: '${r['id']}')));
                        _reload();
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
