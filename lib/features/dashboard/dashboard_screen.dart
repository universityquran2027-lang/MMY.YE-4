import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/db/app_database.dart';
import '../../core/widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.app, required this.user});
  final AppDatabase app;
  final Map<String, Object?> user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<Map<String, int>>? _counts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _counts = _loadCounts();
  }

  Future<Map<String, int>> _loadCounts() async {
    Future<int> count(String table) async =>
        Sqflite.firstIntValue(await widget.app.db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;
    return {
      'الإدارة': await count('admin_profiles'),
      'المراكز': await count('centers'),
      'الكادر الإعلامي': await count('media_staff'),
      'المهام الميدانية': await count('field_tasks'),
      'التجهيزات': await count('inventory_items'),
      'التقييمات': await count('evaluations'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cards = const [
      (Symbols.admin_panel_settings, 'الإدارة'),
      (Symbols.apartment, 'المراكز'),
      (Symbols.groups, 'الكادر الإعلامي'),
      (Symbols.assignment, 'المهام الميدانية'),
      (Symbols.inventory_2, 'التجهيزات'),
      (Symbols.analytics, 'التقييمات'),
    ];
    return RefreshIndicator(
      onRefresh: () async => setState(_reload),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('النظرة العامة', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, int>>(
            future: _counts,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
              }
              final counts = snapshot.data!;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1100 ? 3 : (width >= 650 ? 2 : 1);
                  final cardWidth = (width - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final card in cards)
                        SizedBox(
                          width: cardWidth,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(card.$1, color: Theme.of(context).colorScheme.primary),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(card.$2, style: Theme.of(context).textTheme.titleMedium),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${counts[card.$2] ?? 0}',
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Symbols.info, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('جميع البيانات محفوظة محلياً على هذا الجهاز ولا تتم أي مزامنة تلقائية.'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
