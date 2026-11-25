import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../../core/permissions.dart';
import '../../core/widgets.dart';
import 'center_detail_screen.dart';
import 'centers_repository.dart';

const centerFields = [
  FieldSpec('name', 'اسم المركز', required: true),
  FieldSpec('governorate', 'المحافظة'),
  FieldSpec('district', 'المديرية'),
  FieldSpec('area', 'المنطقة'),
  FieldSpec('address', 'العنوان التفصيلي'),
  FieldSpec('phone', 'الهاتف الرسمي', type: FieldType.phone),
  FieldSpec('manager_name', 'اسم المسؤول'),
  FieldSpec('manager_phone', 'رقم جوال المسؤول', type: FieldType.phone),
  FieldSpec('founded_at', 'تاريخ التأسيس', type: FieldType.date),
  FieldSpec('status', 'الحالة', type: FieldType.dropdown, required: true,
      options: [('active', 'نشط'), ('stopped', 'متوقف')]),
  FieldSpec('notes', 'ملاحظات', type: FieldType.multiline),
];

/// قسم المراكز: بطاقات بدائرة نسبة التقييم. أيقونة المركز موحدة ولا يتغير لونها بالتقييم.
class CentersScreen extends StatefulWidget {
  const CentersScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Row user;
  @override
  State<CentersScreen> createState() => _CentersScreenState();
}

class _CentersScreenState extends State<CentersScreen> {
  late final repo = CentersRepository(widget.app, widget.user['id'] as String);
  late final role = Role.parse(widget.user['role']);
  String _q = '';
  late Future<List<Row>> _rows = repo.list();

  void _reload() => setState(() => _rows = repo.list(q: _q));

  Future<void> _add() async {
    final v = await showRecordForm(context,
        title: 'إضافة مركز', fields: centerFields, initial: {'status': 'active'});
    if (v == null) return;
    await repo.save(v);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(child: TextField(
            decoration: const InputDecoration(hintText: 'بحث باسم المركز أو الموقع', prefixIcon: Icon(Icons.search)),
            onChanged: (v) { _q = v; _reload(); },
          )),
          if (role.canEditOperations) ...[
            const SizedBox(width: 12),
            FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add_business), label: const Text('إضافة مركز')),
          ],
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Row>>(
            future: _rows,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final rows = snap.data!;
              if (rows.isEmpty) return const EmptyState('لا توجد مراكز بعد. أضف أول مركز من زر «إضافة مركز».');
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360, mainAxisExtent: 170, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final r = rows[i];
                  final score = (r['last_score'] as num?)?.toDouble();
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => CenterDetailScreen(app: widget.app, user: widget.user, centerId: '${r['id']}')));
                        _reload();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(Icons.apartment, color: cs.primary), // أيقونة موحدة ثابتة اللون
                              const SizedBox(width: 8),
                              Expanded(child: Text('${r['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium)),
                            ]),
                            const SizedBox(height: 6),
                            Text([r['governorate'], r['district']].where((e) => e != null).join(' - '),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const Spacer(),
                            Wrap(spacing: 8, children: [
                              StatusChip('${r['status']}'),
                              Chip(label: Text('${r['staff_count']} إعلامي'), visualDensity: VisualDensity.compact),
                            ]),
                          ])),
                          const SizedBox(width: 12),
                          _ScoreRing(score),
                        ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing(this.score);
  final double? score;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64, height: 64,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(child: CircularProgressIndicator(
          value: score == null ? 0 : (score! / 100).clamp(0, 1),
          strokeWidth: 6, backgroundColor: cs.outline, color: cs.primary)),
        Text(score == null ? '—' : '${score!.round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
