import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// صورة الشعار التي يختارها الطبيب من الإعدادات.
/// تُحفظ ملفاً بجانب قاعدة البيانات (لا تغيير في جداول القاعدة)،
/// وعند غيابها تُستخدم الصورة الافتراضية المرفقة مع البرنامج.
class LogoRepository {
  /// مجلد الحفظ. قابل للاستبدال في الاختبارات.
  static Future<Directory> Function() directory =
      getApplicationSupportDirectory;

  static const fileName = 'clinic_logo.img';

  /// الحد الأقصى لحجم الصورة المرفوعة.
  static const maxBytes = 8 * 1024 * 1024;

  Future<File> _file() async =>
      File(p.join((await directory()).path, fileName));

  /// يعيد الصورة المخصصة، أو null لاستخدام الافتراضية.
  Future<Uint8List?> load() async {
    try {
      final f = await _file();
      if (await f.exists()) return await f.readAsBytes();
    } catch (_) {
      // لا مجلد متاح (مثلاً في الاختبارات) ← الصورة الافتراضية.
    }
    return null;
  }

  Future<void> save(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw ArgumentError('حجم الصورة يجب ألا يتجاوز 8 ميغابايت');
    }
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  /// يحذف الصورة المخصصة فتعود الصورة الافتراضية.
  Future<void> reset() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}

