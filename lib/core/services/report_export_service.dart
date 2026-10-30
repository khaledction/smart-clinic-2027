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

/// V7 — تصدير PDF و Excel — إصلاح العربية والحفظ في المكان المختار
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

      pw.Font? ttf;
      pw.Font? ttfBold;
      try {
        final data = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
        final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
        ttf = pw.Font.ttf(data);
        ttfBold = pw.Font.ttf(boldData);
      } catch (_) {}

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          // مهم للعربية
          theme: ttf != null ? pw.ThemeData.withFont(base: ttf, bold: ttfBold ?? ttf) : null,
          build: (ctx) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text('تقرير يومي - ${DateFormat('yyyy-MM-dd').format(day)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 8),
                pw.Text('عدد الزيارات: ${visits.length}  |  الإيرادات: $total ج.م', style: const pw.TextStyle(fontSize: 12), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: ['التاريخ', 'التشخيص', 'المريض'],
                  data: visits.map((v) => [(v['visit_date'] as String).substring(0,10), v['diagnosis'] ?? '-', v['full_name'] ?? '-']).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignment: pw.Alignment.center,
                  headerAlignment: pw.Alignment.center,
                ),
              ],
            ),
          ),
        ),
      );

      final bytes = await pdf.save();

      // احفظ حيث يختار المستخدم تماماً
      String? outPath = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ تقرير PDF',
        fileName: 'تقرير-${DateFormat('yyyy-MM-dd').format(day)}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (outPath != null) {
        // FilePicker على Windows قد يعيد المسار بدون كتابة الملف، نكتبه يدوياً
        final file = File(outPath);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsBytes(bytes);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ في: $outPath')));
        }
      } else {
        // المستخدم ألغى
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإلغاء')));
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

      String? outPath = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ تقرير Excel',
        fileName: 'تقرير-${DateFormat('yyyy-MM-dd').format(day)}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );
      if (outPath != null) {
        final file = File(outPath);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsBytes(bytes);
        }
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ في: $outPath')));
      } else {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإلغاء')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ Excel: $e')));
    }
  }
}
