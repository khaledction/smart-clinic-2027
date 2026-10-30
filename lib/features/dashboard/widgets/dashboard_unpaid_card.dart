import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/treatment_repository.dart';

/// كارت لوحة اليوم: غير مدفوع
class UnpaidCard extends StatefulWidget {
  const UnpaidCard({super.key});
  @override
  State<UnpaidCard> createState() => _UnpaidCardState();
}

class _UnpaidCardState extends State<UnpaidCard> {
  int unpaidVisits = 0;
  int unpaidSessions = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final v = await db.rawQuery("SELECT COUNT(*) as c FROM payments WHERE category='consultation' AND (paid_at IS NULL OR amount=0)");
    final s = await db.rawQuery("SELECT COUNT(*) as c FROM payments WHERE category='session' AND (paid_at IS NULL OR amount=0)");
    if (mounted) setState(() {
      unpaidVisits = (v.first['c'] as int?) ?? 0;
      unpaidSessions = (s.first['c'] as int?) ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (unpaidVisits == 0 && unpaidSessions == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFFCE8E6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEA4335).withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB3261E), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('غير مدفوع: $unpaidVisits زيارات • $unpaidSessions جلسات', style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w700, fontSize: 13))),
          TextButton(onPressed: () async {
            // افتح المالية على تبويب غير مدفوعة
            // يمكن استبدالها بانتقال مباشر
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('افتح المالية → زيارات غير مدفوعة')) );
          }, child: const Text('عرض')),
          FilledButton(onPressed: () async {
            await _load();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحديث')));
          }, child: const Text('تحديث')),
        ],
      ),
    );
  }
}
