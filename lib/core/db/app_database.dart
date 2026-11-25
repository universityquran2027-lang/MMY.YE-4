import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'schema.dart';

String nowIso() => DateTime.now().toUtc().toIso8601String();
String newId() => const Uuid().v4();

class AppDatabase {
  AppDatabase._(this.db, this.dir);
  final Database db;
  final Directory dir; // مجلد بيانات التطبيق (قاعدة + مرفقات + نسخ احتياطية)

  Directory get attachmentsDir => Directory(p.join(dir.path, 'attachments'));
  Directory get backupsDir => Directory(p.join(dir.path, 'backups'));

  static Future<AppDatabase> open({String? overridePath}) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = overridePath != null
        ? Directory(overridePath)
        : await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final db = await openDatabase(
      p.join(dir.path, 'mmy.db'),
      version: kSchemaVersion,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        final b = d.batch();
        for (final s in kCreateStatements) {
          b.execute(s);
        }
        await b.commit(noResult: true);
        await _seed(d);
      },
      // أي ترقية مستقبلية: أضف هنا هجرة (migration) صريحة دون حذف بيانات.
      onUpgrade: (d, oldV, newV) async {},
    );
    final a = AppDatabase._(db, dir);
    await a.attachmentsDir.create(recursive: true);
    await a.backupsDir.create(recursive: true);
    return a;
  }

  /// بيانات أساسية فقط (أنواع المخرجات والمعايير). ليست بيانات تجريبية.
  static Future<void> _seed(Database d) async {
    final t = nowIso();
    const outputs = [
      ['عدد الدروس', 'count'],
      ['عدد التطبيقات', 'count'],
      ['عدد الأفراد الموثقين', 'count'],
      ['تاريخ تسليم المواد', 'date'],
      ['حجم المواد', 'size_mb'],
    ];
    // معرّفات ثابتة: كي لا تتكرر صفوف البذور ولا يصطدم UNIQUE(name) عند الاستيراد بين جهازين.
    for (var i = 0; i < outputs.length; i++) {
      await d.insert('output_types', {
        'id': 'builtin-output-$i', 'name': outputs[i][0], 'data_type': outputs[i][1],
        'is_builtin': 1, 'updated_at': t,
      });
    }
    // الأوزان المقترحة في الوثيقة (القسم 9.6) - غير معتمدة نهائياً
    const criteria = [
      ['الأداء العام', 'الالتزام بالمهام', 12.0],
      ['الأداء العام', 'جودة العمل', 12.0],
      ['الأداء العام', 'نشاط الإعلاميين', 8.0],
      ['الأداء العام', 'المحافظة على التجهيزات', 8.0],
      ['الأداء العام', 'الإنجاز الميداني', 8.0],
      ['المواد الإعلامية', 'حجم المواد الموردة', 8.0],
      ['المواد الإعلامية', 'الالتزام بمواعيد التوريد', 4.0],
      ['المواد الإعلامية', 'المواد المقبولة والمرفوضة', 10.0],
      ['التوثيق والإنتاج', 'الأفراد الموثقون', 10.0],
      ['التوثيق والإنتاج', 'الدروس', 10.0],
      ['التوثيق والإنتاج', 'التطبيقات', 10.0],
    ];
    for (var i = 0; i < criteria.length; i++) {
      await d.insert('evaluation_criteria', {
        'id': 'builtin-criterion-$i', 'axis': criteria[i][0], 'name': criteria[i][1],
        'weight': criteria[i][2], 'is_final': 0, 'sort_order': i, 'updated_at': t,
      });
    }
    await d.insert('settings',
        {'key': 'channel_name', 'value': 'الإعلام الحربي اليمني', 'updated_at': t});
  }

  Future<void> audit(String? userId, String section, String action, [String? details]) =>
      db.insert('audit_log', {
        'id': newId(), 'user_id': userId, 'section': section,
        'action': action, 'details': details, 'at': nowIso(),
      });

  Future<void> securityEvent(String? username, String event, [String? details]) =>
      db.insert('security_log', {
        'id': newId(), 'username': username, 'event': event,
        'details': details, 'at': nowIso(),
      });

  Future<void> close() => db.close();
}
