import 'package:flutter/foundation.dart';

import '../../core/services/developer_mode.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

/// الجلسة الحالية: من هو المستخدم الداخل الآن.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._repo);

  final AuthRepository _repo;

  User? _user;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // حساب المبرمج (غير مخزَّن في قاعدة البيانات).
      final dev = DeveloperMode.tryLogin(username, password);
      if (dev != null) {
        _user = dev;
        return true;
      }
      if (DeveloperMode.isReserved(username)) {
        _error = 'اسم المستخدم أو كلمة المرور غير صحيحة';
        return false;
      }
      final user = await _repo.login(username, password);
      if (user == null) {
        _error = 'اسم المستخدم أو كلمة المرور غير صحيحة';
        return false;
      }
      _user = user;
      return true;
    } catch (e) {
      _error = 'تعذّر تسجيل الدخول: $e';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void logout() {
    _user = null;
    DeveloperMode.lock();
    notifyListeners();
  }
}

