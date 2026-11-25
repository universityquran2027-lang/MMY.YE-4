import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/db/app_database.dart';

class ReportService {
  ReportService(this.app);
  final AppDatabase app;

  Future<Uint8List> buildMonthlyCenterReport({
    required String centerId,
    required int year,
    required int month,
  }) async {
    final centerRows = await app.db.query(
      'centers',
      where: 'id = ?',
      whereArgs: [centerId],
      limit: 1,
    );
    if (centerRows.isEmpty) throw Exception('المركز غير موجود');
    final center = centerRows.first;
    final evaluations = await app.db.query(
      'evaluations',
      where: 'center_id = ? AND year = ? AND month = ?',
      whereArgs: [centerId, year, month],
      limit: 1,
    );
    final tasks = await app.db.query(
      'field_tasks',
      where: 'center_id = ?',
      whereArgs: [centerId],
    );
    final staff = await app.db.query(
      'media_staff',
      where: 'center_id = ?',
      whereArgs: [centerId],
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.green900),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'الإعلام الحربي اليمني',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'التقرير الشهري للمركز',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text('اسم المركز: ${center['name']}'),
          pw.Text('المحافظة: ${center['governorate'] ?? '—'}'),
          pw.Text('الفترة: $month/$year'),
          pw.SizedBox(height: 12),
          pw.Text('الإعلاميون المرتبطون: ${staff.length}'),
          pw.Text('المهام المسندة: ${tasks.length}'),
          pw.SizedBox(height: 12),
          pw.Text(
            evaluations.isEmpty
                ? 'نتيجة التقييم: لم يعتمد تقييم لهذه الفترة'
                : 'نتيجة التقييم: ${evaluations.first['total_score'] ?? '—'}%',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text('المهام الميدانية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('عنوان المهمة')),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('الحالة')),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('الإنجاز')),
                ],
              ),
              for (final task in tasks)
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${task['title']}')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${task['status']}')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${task['progress_percent'] ?? 0}%')),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> printCenterReport({
    required String centerId,
    required int year,
    required int month,
  }) async {
    final bytes = await buildMonthlyCenterReport(
      centerId: centerId,
      year: year,
      month: month,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
