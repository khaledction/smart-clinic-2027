import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/database/app_database.dart';

/// V7 — تصدير التقارير PDF و Excel مع دعم العربية — مُصلح لـ excel 4.0.6
class ReportExportService {
  static Future<void> exportDailyPdf(BuildContext context, DateTime day) async {
    try {
      final db = await AppDatabase.instance.database;
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));

      final visits = await db.rawQuery(
        'SELECT v.*, p.full_name FROM visits v JOIN patients p ON p.id=v.patient_id WHERE v.visit_date>=? AND v.visit_date<? ORDER BY v.visit_date',
        [start.toIso8601String(), end.toIso8601String()],
      );
      final payments = await db.rawQuery(
        'SELECT SUM(amount) as total FROM payments WHERE paid_at>=? AND paid_at<?',
        [start.toIso8601String(), end.toIso8601String()],
      );
      final total = (payments.first['total'] as num?)?.toDouble() ?? 0.0;

      pw.Font? arabicFont;
      try {
        final data = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
        arabicFont = pw.Font.ttf(data);
      } catch (_) {}

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          theme: arabicFont != null ? pw.ThemeData.withFont(base: arabicFont) : null,
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('تقرير يومي - ${DateFormat('yyyy-MM-dd').format(day)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('عدد الزيارات: ${visits.length}  |  الإيرادات: $total ج.م', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: ['المريض', 'التشخيص', 'التاريخ'],
                data: visits.map((v) => [v['full_name'] ?? '-', v['diagnosis'] ?? '-', (v['visit_date'] as String).substring(0,10)]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                cellAlignment: pw.Alignment.centerRight,
              ),
            ],
          ),
        ),
      );

      final bytes = await pdf.save();
      final outPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ تقرير PDF',
        fileName: 'تقرير-${DateFormat('yyyy-MM-dd').format(day)}.pdf',
        bytes: bytes,
      );
      if (outPath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ: ${p.basename(outPath)}')));
      } else if (outPath == null) {
        await Printing.sharePdf(bytes: bytes, filename: 'report.pdf');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ التصدير: $e')));
    }
  }

  static Future<void> exportDailyExcel(BuildContext context, DateTime day) async {
    try {
      final db = await AppDatabase.instance.database;
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));

      final rows = await db.rawQuery(
        'SELECT v.visit_date, p.full_name, p.phone, v.diagnosis, v.plan FROM visits v JOIN patients p ON p.id=v.patient_id WHERE v.visit_date>=? AND v.visit_date<?',
        [start.toIso8601String(), end.toIso8601String()],
      );

      final excel = Excel.createExcel();
      final sheet = excel['التقرير اليومي'];
      // excel 4.0.6: استخدم TextCellValue
      sheet.appendRow(<CellValue>[TextCellValue('التاريخ'), TextCellValue('المريض'), TextCellValue('الهاتف'), TextCellValue('التشخيص'), TextCellValue('الخطة')]);
      for (final r in rows) {
        sheet.appendRow(<CellValue>[
          TextCellValue((r['visit_date'] as String?)?.substring(0,10) ?? ''),
          TextCellValue(r['full_name'] as String? ?? ''),
          TextCellValue(r['phone'] as String? ?? ''),
          TextCellValue(r['diagnosis'] as String? ?? ''),
          TextCellValue(r['plan'] as String? ?? ''),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('فشل إنشاء Excel');

      final outPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ تقرير Excel',
        fileName: 'تقرير-${DateFormat('yyyy-MM-dd').format(day)}.xlsx',
        bytes: Uint8List.fromList(bytes),
      );
      if (outPath == null) {
        final tmp = File('${Directory.systemTemp.path}/report-${DateTime.now().millisecondsSinceEpoch}.xlsx');
        await tmp.writeAsBytes(bytes);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ المؤقت: ${tmp.path}')));
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ: ${p.basename(outPath)}')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ Excel: $e')));
    }
  }
}
