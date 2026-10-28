import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../repositories/logo_repository.dart';
import '../repositories/settings_repository.dart';

/// إعدادات العيادة، تُحمَّل مرة واحدة عند بدء التطبيق.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._repo, {LogoRepository? logoRepo})
    : _logoRepo = logoRepo ?? LogoRepository();

  final SettingsRepository _repo;
  final LogoRepository _logoRepo;

  /// صورة الشعار المخصصة (null = الصورة الافتراضية).
  Uint8List? _logo;
  Uint8List? get logo => _logo;

  ClinicSettings _settings = const ClinicSettings();
  bool _loading = true;

  ClinicSettings get settings => _settings;
  bool get loading => _loading;
  String get clinicName => _settings.clinicName.trim().isEmpty
      ? 'عيادة الأعصاب'
      : _settings.clinicName;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _settings = await _repo.load();
    _loading = false;
    notifyListeners();
    unawaited(loadLogo());
  }

  Future<void> loadLogo() async {
    final bytes = await _logoRepo.load();
    if (!identical(bytes, _logo)) {
      _logo = bytes;
      notifyListeners();
    }
  }

  /// يستبدل صورة الشعار في كل النوافذ.
  Future<void> setLogo(Uint8List bytes) async {
    await _logoRepo.save(bytes);
    _logo = bytes;
    notifyListeners();
  }

  /// يعيد الصورة الافتراضية.
  Future<void> resetLogo() async {
    await _logoRepo.reset();
    _logo = null;
    notifyListeners();
  }

  Future<void> save(ClinicSettings s) async {
    await _repo.save(s);
    _settings = s;
    notifyListeners();
  }
}

