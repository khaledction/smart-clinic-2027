import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../models/user.dart';

/// تسجيل الدخول وإدارة المستخدمين.
class AuthRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// يُعيد المستخدم إذا كانت البيانات صحيحة، وإلا null.
  Future<User?> login(String username, String password) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final hash = rows.first['password_hash'] as String? ?? '';
    if (!BCrypt.checkpw(password, hash)) return null;

    return User.fromMap(rows.first);
  }

  /// المستخدم الفعّال بهذا الاسم (لاستعادة كلمة المرور).
  Future<User?> findActive(String username) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<List<User>> all() async {
    final db = await _db;
    final rows = await db.query('users', orderBy: 'id ASC');
    return rows.map(User.fromMap).toList();
  }

  /// إنشاء مستخدم جديد (كلمة المرور تُشفَّر بـ bcrypt قبل التخزين).
  Future<int> create({
    required String username,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final db = await _db;
    return db.insert('users', {
      'username': username.trim(),
      'password_hash': BCrypt.hashpw(password, BCrypt.gensalt()),
      'full_name': fullName,
      'role': role,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> changePassword(int userId, String newPassword) async {
    final db = await _db;
    return db.update(
      'users',
      {'password_hash': BCrypt.hashpw(newPassword, BCrypt.gensalt())},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> setActive(int userId, bool active) async {
    final db = await _db;
    return db.update(
      'users',
      {'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> delete(int userId) async {
    final db = await _db;
    return db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }
}

