import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as c;
import 'package:path/path.dart' as p;
import '../../core/db/app_database.dart';
import '../../core/db/schema.dart';
import '../../core/permissions.dart';

/// صيغة النقل اليدوي `.mmy` (لا شبكة ولا مزامنة؛ تبدأ فقط عند اختيار المستخدم):
///
///   ZIP يحتوي:
///     manifest.json      -> الصيغة، إصدار المخطط، التاريخ، إصدار التطبيق، بصمة SHA-256 لكل ملف
///     data.json          -> صفوف كل الجداول (أو الأقسام المختارة)
///     attachments/<file> -> الصور والمرفقات
///
///   وعند تحديد عبارة سرية يُغلَّف الـZIP كاملاً بتشفير AES-256-GCM:
///     "MMYX1" | salt(16) | nonce(12) | cipherText | mac(16)
///
/// يعمل بنفس الشكل على Android وWindows. CSV للتقارير فقط.
const _magic = [0x4D, 0x4D, 0x59, 0x58, 0x31]; // MMYX1
const kAppVersion = '1.0.0';
const _maxPackageBytes = 200 * 1024 * 1024; // حد حجم ملف .mmy
const _maxUnpackedBytes = 600 * 1024 * 1024; // حد الحجم بعد فك الضغط (حماية من zip-bomb)

class ImportSummary {
  ImportSummary(this.tables, this.manifest);
  final Map<String, int> tables; // عدد الصفوف في الملف لكل جدول
  final Map<String, Object?> manifest;
}

enum ConflictPolicy { keepLocal, useImported, keepNewer }

class ImportReport {
  final Map<String, int> inserted = {};
  final Map<String, int> skippedIdentical = {};
  final Map<String, int> conflicts = {};
  final List<String> errors = [];
  String? backupPath;
  bool get ok => errors.isEmpty;
}

class MmyPackage {
  MmyPackage(this.app);
  final AppDatabase app;

  // ---------------------------------------------------------------- تصدير
  Future<File> export({
    required String targetDir,
    List<String>? tables,
    String? passphrase,
  }) async {
    final chosen = tables ?? kTransferTables;
    for (final t in chosen) {
      if (!kTransferTables.contains(t)) throw ArgumentError('جدول غير مسموح بتصديره: $t');
    }
    final data = <String, List<Map<String, Object?>>>{};
    for (final t in chosen) {
      data[t] = await app.db.query(t);
    }
    final archive = Archive();
    final files = <String, String>{};

    final dataBytes = utf8.encode(jsonEncode(data));
    archive.addFile(ArchiveFile('data.json', dataBytes.length, dataBytes));
    files['data.json'] = c.sha256.convert(dataBytes).toString();

    if (data.containsKey('attachments')) {
      for (final a in data['attachments']!) {
        final f = _safeAttachment('${a['relative_path']}');
        if (f != null && await f.exists()) {
          final b = await f.readAsBytes();
          final name = 'attachments/${p.basename(f.path)}';
          archive.addFile(ArchiveFile(name, b.length, b));
          files[name] = c.sha256.convert(b).toString();
        }
      }
    }
    final manifest = {
      'format': 'mmy-export',
      'format_version': 1,
      'schema_version': kSchemaVersion,
      'app_version': kAppVersion,
      'exported_at': nowIso(),
      'encrypted': passphrase != null,
      'tables': {for (final e in data.entries) e.key: e.value.length},
      'files': files,
    };
    final mb = utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
    archive.addFile(ArchiveFile('manifest.json', mb.length, mb));

    var out = ZipEncoder().encode(archive)!;
    if (passphrase != null) out = await _encrypt(out, passphrase);
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File(p.join(targetDir, 'mmy-export-$stamp.mmy'));
    await file.writeAsBytes(out, flush: true);
    return file;
  }

  // ---------------------------------------------------------------- فحص قبل الاستيراد
  /// يتحقق من سلامة الملف (بصمات SHA-256 وإصدار المخطط) ويرجع ملخصاً دون أي تعديل.
  Future<ImportSummary> inspect(File file, {String? passphrase}) async {
    final z = await _open(file, passphrase);
    return ImportSummary(
      (z.manifest['tables'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      z.manifest,
    );
  }

  // ---------------------------------------------------------------- استيراد
  /// دمج وليس استبدال: لا يُحذف شيء موجود. السجل الجديد يُضاف، والمطابق يُتجاوز،
  /// والمختلف يُعدّ تعارضاً يُحل بحسب [policy] (الافتراضي: إبقاء المحلي).
  /// تُؤخذ نسخة احتياطية من القاعدة قبل أي كتابة، وكل الكتابة داخل معاملة واحدة.
  Future<ImportReport> import(
    File file, {
    required Role actor,
    String? passphrase,
    ConflictPolicy policy = ConflictPolicy.keepLocal,
    bool backupFirst = true,
  }) async {
    // الاستيراد يكتب فوق بيانات تشغيلية: للمدير وحده (لا يكفي إخفاء الزر في الواجهة).
    if (!actor.canConfigureSecurity) {
      throw StateError('الاستيراد مسموح للمدير فقط');
    }
    final report = ImportReport();
    final z = await _open(file, passphrase);
    if (backupFirst) report.backupPath = (await createBackup()).path;

    try {
      await app.db.transaction((txn) async {
        await txn.execute('PRAGMA defer_foreign_keys = ON');
        for (final t in kTransferTables) {
          final rows = z.data[t];
          if (rows == null) continue;
          // الأعمدة المسموحة = أعمدة الجدول المحلي فقط (تمنع حقن أسماء الأعمدة)
          final allowed = (await txn.rawQuery('PRAGMA table_info($t)'))
              .map((c) => c['name'] as String)
              .toSet();
          for (final r in rows) {
            final row = Map<String, Object?>.from(r);
            final unknown = row.keys.where((k) => !allowed.contains(k));
            if (unknown.isNotEmpty) {
              throw FormatException('عمود غير معروف في $t: ${unknown.first}');
            }
            if (t == 'attachments' && _safeAttachment('${row['relative_path']}') == null) {
              throw FormatException('مسار مرفق غير آمن: ${row['relative_path']}');
            }
            final id = row['id'] ?? row['key'];
            final pk = t == 'settings' ? 'key' : 'id';
            final local = await txn.query(t, where: '$pk = ?', whereArgs: [id], limit: 1);
            if (local.isEmpty) {
              await txn.insert(t, row);
              report.inserted[t] = (report.inserted[t] ?? 0) + 1;
              continue;
            }
            if (_sameRow(local.first, row)) {
              report.skippedIdentical[t] = (report.skippedIdentical[t] ?? 0) + 1;
              continue;
            }
            report.conflicts[t] = (report.conflicts[t] ?? 0) + 1;
            final useImported = switch (policy) {
              ConflictPolicy.keepLocal => false,
              ConflictPolicy.useImported => true,
              ConflictPolicy.keepNewer =>
                ((row['updated_at'] ?? '') as String).compareTo((local.first['updated_at'] ?? '') as String) > 0,
            };
            if (useImported) {
              await txn.update(t, row, where: '$pk = ?', whereArgs: [id]);
            }
          }
        }
        for (final entry in z.files.entries) {
          final dest = File(p.join(app.attachmentsDir.path, p.basename(entry.key)));
          if (!await dest.exists()) await dest.writeAsBytes(entry.value, flush: true);
        }
      });
    } catch (e) {
      report.errors.add('فشل الاستيراد وتم التراجع عن كل التغييرات: $e');
    }
    return report;
  }

  // ---------------------------------------------------------------- نسخ احتياطي / استعادة
  Future<File> createBackup() async {
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final out = File(p.join(app.backupsDir.path, 'backup-$stamp.mmy'));
    final f = await export(targetDir: app.backupsDir.path);
    return f.renameSync(out.path);
  }

  // ---------------------------------------------------------------- داخلي
  /// يرجع ملف المرفق فقط إذا كان مساره نسبياً وداخل مجلد المرفقات؛ وإلا null.
  File? _safeAttachment(String rel) {
    if (rel.isEmpty || p.isAbsolute(rel)) return null;
    final full = p.normalize(p.join(app.dir.path, rel));
    return p.isWithin(app.attachmentsDir.path, full) ? File(full) : null;
  }

  bool _sameRow(Map<String, Object?> a, Map<String, Object?> b) {
    for (final k in b.keys) {
      if ('${a[k]}' != '${b[k]}') return false;
    }
    return true;
  }

  Future<_Opened> _open(File file, String? passphrase) async {
    if (await file.length() > _maxPackageBytes) {
      throw const FormatException('الملف أكبر من الحد المسموح');
    }
    var bytes = await file.readAsBytes();
    final encrypted = bytes.length > 5 && List.generate(5, (i) => bytes[i]).join() == _magic.join();
    if (encrypted) {
      if (passphrase == null) throw const FormatException('الملف مشفّر ويحتاج عبارة سرية');
      bytes = await _decrypt(bytes, passphrase);
    }
    final zip = ZipDecoder().decodeBytes(bytes);
    var unpacked = 0;
    for (final f in zip) {
      unpacked += f.size;
      if (unpacked > _maxUnpackedBytes) {
        throw const FormatException('محتوى الملف أكبر من الحد المسموح');
      }
    }
    ArchiveFile? find(String n) {
      for (final f in zip) {
        if (f.name == n) return f;
      }
      return null;
    }

    final mf = find('manifest.json');
    final df = find('data.json');
    if (mf == null || df == null) throw const FormatException('ملف غير صالح: manifest.json أو data.json مفقود');
    final manifest = jsonDecode(utf8.decode(mf.content as List<int>)) as Map<String, Object?>;
    if (manifest['format'] != 'mmy-export') throw const FormatException('صيغة ملف غير معروفة');
    if ((manifest['schema_version'] as int) > kSchemaVersion) {
      throw const FormatException('الملف أحدث من هذه النسخة من البرنامج؛ حدّث البرنامج أولاً');
    }
    final hashes = (manifest['files'] as Map).cast<String, String>();
    final files = <String, List<int>>{};
    for (final f in zip) {
      if (!f.isFile || f.name == 'manifest.json') continue;
      final content = f.content as List<int>;
      if (c.sha256.convert(content).toString() != hashes[f.name]) {
        throw FormatException('فشل التحقق من سلامة الملف: ${f.name}');
      }
      if (f.name.startsWith('attachments/')) files[f.name] = content;
    }
    final raw = jsonDecode(utf8.decode(df.content as List<int>)) as Map<String, Object?>;
    final data = raw.map((k, v) => MapEntry(
        k, (v as List).map((e) => (e as Map).cast<String, Object?>()).toList()));
    return _Opened(manifest, data, files);
  }

  Future<List<int>> _key(String pass, List<int> salt) async {
    final k = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 210000, bits: 256)
        .deriveKeyFromPassword(password: pass, nonce: salt);
    return k.extractBytes();
  }

  Future<List<int>> _encrypt(List<int> plain, String pass) async {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final key = SecretKey(await _key(pass, salt));
    final box = await AesGcm.with256bits().encrypt(plain, secretKey: key);
    return [..._magic, ...salt, ...box.nonce, ...box.cipherText, ...box.mac.bytes];
  }

  Future<List<int>> _decrypt(List<int> data, String pass) async {
    final salt = data.sublist(5, 21);
    final nonce = data.sublist(21, 33);
    final cipher = data.sublist(33, data.length - 16);
    final mac = Mac(data.sublist(data.length - 16));
    final key = SecretKey(await _key(pass, salt));
    try {
      return await AesGcm.with256bits()
          .decrypt(SecretBox(cipher, nonce: nonce, mac: mac), secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const FormatException('العبارة السرية خاطئة أو الملف تالف');
    }
  }
}

class _Opened {
  _Opened(this.manifest, this.data, this.files);
  final Map<String, Object?> manifest;
  final Map<String, List<Map<String, Object?>>> data;
  final Map<String, List<int>> files;
}
