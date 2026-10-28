import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/clinic_flow_repository.dart';

/// مواعيد يوم محدد.
class AppointmentsProvider extends ChangeNotifier {
  AppointmentsProvider(this._repo, {ClinicFlowRepository? flow})
    : _flow = flow ?? ClinicFlowRepository();

  final AppointmentRepository _repo;
  final ClinicFlowRepository _flow;

  /// يزداد مع كل تحميل؛ تستخدمه بطاقة «المنجزة» لإعادة القراءة.
  int _revision = 0;
  int get revision => _revision;

  DateTime _day = DateTime.now();
  List<Appointment> _items = [];
  bool _loading = false;

  DateTime get day => _day;
  List<Appointment> get items => _items;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _items = await _repo.forDay(_day);
    _loading = false;
    _revision++;
    notifyListeners();
  }

  Future<void> goToDay(DateTime day) async {
    _day = DateTime(day.year, day.month, day.day);
    await load();
  }

  Future<void> goToToday() => goToDay(DateTime.now());

  Future<String?> add(Appointment a) async {
    final conflict = await _repo.findConflict(a.startAt, a.durationMin);
    if (conflict != null) {
      return 'يوجد تعارض مع موعد ${conflict.patientName} الساعة '
          '${conflict.startAt.hour.toString().padLeft(2, '0')}:'
          '${conflict.startAt.minute.toString().padLeft(2, '0')}';
    }
    await _repo.insert(a);
    await load();
    return null;
  }

  Future<void> update(Appointment a) async {
    final conflict = await _repo.findConflict(
      a.startAt,
      a.durationMin,
      exceptId: a.id,
    );
    if (conflict != null) throw StateError('يتعارض الموعد مع موعد قائم');
    await _repo.update(a);
    await load();
  }

  Future<void> setStatus(int id, String status) async {
    await _repo.setStatus(id, status);
    await load();
  }

  /// «تمت الزيارة» / «تمت الجلسة»: ينقل الموعد إلى المنجزة.
  Future<void> markDone(int id) async {
    await _flow.markAppointmentDone(id);
    await load();
  }

  /// مواعيد اليوم غير المنجزة/الملغاة مقسومة حسب النوع.
  List<Appointment> pendingOf(String? kind) => _items
      .where(
        (a) =>
            a.kind == kind &&
            a.status != 'done' &&
            a.status != 'cancelled' &&
            a.status != 'no_show',
      )
      .toList();

  Future<void> remove(int id) async {
    await _repo.delete(id);
    await load();
  }
}

