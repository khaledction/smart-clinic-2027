import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../data/models/appointment.dart';
import '../../data/repositories/appointment_repository.dart';

/// V7 — تذكير مواعيد كل دقيقة للـ 30 دقيقة القادمة
class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();

  Timer? _timer;
  final ValueNotifier<List<Appointment>> upcoming = ValueNotifier([]);

  void start() {
    _timer?.cancel();
    _check(); // فحص فوري
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    debugPrint('⏰ ReminderService started');
  }

  void stop() => _timer?.cancel();

  Future<void> _check() async {
    try {
      final now = DateTime.now();
      final until = now.add(const Duration(minutes: 30));
      // ignore: unused_local_variable
  final db = await AppDatabase.instance.database;
      final repo = AppointmentRepository();
      // استخدم repo.between
      final list = await repo.between(now, until);
      final filtered = list.where((a) => a.status == 'scheduled' && a.startAt.isAfter(now)).toList();
      upcoming.value = filtered;
      if (filtered.isNotEmpty) debugPrint('⏰ ${filtered.length} مواعيد قادمة');
    } catch (e) {
      debugPrint('Reminder error: $e');
    }
  }

  Future<void> markArrived(int appointmentId) async {
    // ignore: unused_local_variable
  final db = await AppDatabase.instance.database;
    await db.update('appointments', {'status': 'arrived'}, where: 'id=?', whereArgs: [appointmentId]);
    await _check();
  }

  Future<void> dismiss(int appointmentId) async {
    // ignore: unused_local_variable
  final db = await AppDatabase.instance.database;
    try {
      await db.insert('reminder_dismissed', {'appointment_id': appointmentId, 'dismissed_at': DateTime.now().toIso8601String()});
    } catch (_) {}
    upcoming.value = upcoming.value.where((a) => a.id != appointmentId).toList();
  }
}

/// ودجت جرس التذكير للـ AppBar
class ReminderBell extends StatelessWidget {
  const ReminderBell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Appointment>>(
      valueListenable: ReminderService.instance.upcoming,
      builder: (context, list, _) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_active, color: Colors.amber),
              tooltip: '${list.length} مواعيد قادمة',
              onPressed: () => _showSheet(context, list),
            ),
            Positioned(
              right: 6, top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('${list.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSheet(BuildContext context, List<Appointment> list) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('تذكير مواعيد (خلال 30 دقيقة)', style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          ...list.map((a) => ListTile(
                title: Text(a.patientName ?? 'مريض #${a.patientId}'),
                subtitle: Text('${a.startAt.hour.toString().padLeft(2,'0')}:${a.startAt.minute.toString().padLeft(2,'0')} - ${a.reason ?? a.kindLabel}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(onPressed: () { ReminderService.instance.markArrived(a.id!); Navigator.pop(context); }, child: const Text('وصل')),
                  IconButton(icon: const Icon(Icons.close), onPressed: () { ReminderService.instance.dismiss(a.id!); }),
                ]),
              )),
        ],
      ),
    );
  }
}



