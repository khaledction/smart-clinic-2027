import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// تصدير أي جدول إلى ملف CSV يفتح مباشرة في Excel بترميز صحيح للعربية.
class CsvExporter {
  CsvExporter._();

  /// يعرض نافذة "حفظ باسم" ويكتب الملف. يُعيد المسار أو null في حال الإلغاء.
  static Future<String?> save({
    required String suggestedName,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ الملف',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return null;

    final buffer = StringBuffer();
    buffer.write(_escapeRow(headers));
    for (final row in rows) {
      buffer.write(_escapeRow(row.map((e) => e?.toString() ?? '').toList()));
    }

    // BOM ضروري ليتعرّف Excel على UTF-8 ويقرأ العربية بشكل صحيح
    final file = File(path);
    await file.writeAsBytes(
      const [0xEF, 0xBB, 0xBF] + utf8.encode(buffer.toString()),
    );
    return path;
  }

  static String _escapeRow(List<String> values) {
    final escaped = values.map((raw) {
      final v = RegExp(r'^[=+@\-\t\r]').hasMatch(raw) ? "'$raw" : raw;
      final needsQuotes =
          v.contains(',') || v.contains('"') || v.contains('\n');
      final inner = v.replaceAll('"', '""');
      return needsQuotes ? '"$inner"' : inner;
    });
    return '${escaped.join(',')}\r\n';
  }
}

