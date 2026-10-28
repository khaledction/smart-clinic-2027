import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/visit.dart';
import '../../data/repositories/settings_repository.dart';
import '../utils/date_fmt.dart';
import '../widgets/clinic_brand.dart';

class ClinicPrint {
  static Future<Uint8List> document(
    String title,
    List<String> headers,
    List<List<String>> rows, {
    String? subtitle,
  }) async {
    final settings = await SettingsRepository().load();
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 500,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              settings.clinicName.replaceAll('\n', ' '),
              style: pw.TextStyle(
                fontSize: 19,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(settings.doctorName),
            pw.Text(title, style: pw.TextStyle(fontSize: 16)),
            if (subtitle != null) pw.Text(subtitle),
            pw.Divider(),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(settings.footerNote),
            pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}'),
          ],
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: headers.reversed.toList(),
            data: rows.map((r) => r.reversed.toList()).toList(),
            headerStyle: pw.TextStyle(
              font: font,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: pw.TextStyle(font: font, fontSize: 10),
            cellAlignment: pw.Alignment.centerRight,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(7),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> prescription(Visit v) => document(
    'وصفة طبية',
    ['الدواء', 'الجرعة', 'التكرار', 'المدة', 'التعليمات'],
    [
      for (final p in v.prescriptions)
        [
          p.drug,
          p.dose ?? '',
          p.frequency ?? '',
          p.durationDays == null ? '' : '${p.durationDays} يوم',
          p.notes ?? '',
        ],
    ],
    subtitle:
        '${v.patientName ?? ''} • ${DateFmt.date(v.visitDate)} • زيارة ${v.id}',
  );
  static void preview(
    BuildContext context,
    String title,
    Future<Uint8List> bytes,
  ) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: BrandedAppBar(title: Text(title)),
        body: FutureBuilder<Uint8List>(
          future: bytes,
          builder: (context, s) {
            if (s.hasError) {
              return Center(child: Text('تعذّر إعداد PDF: ${s.error}'));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return PdfPreview(
              build: (_) => s.data!,
              pdfFileName: 'clinic-document.pdf',
              canChangePageFormat: false,
              canChangeOrientation: false,
              allowSharing: false,
            );
          },
        ),
      ),
    ),
  );
}


