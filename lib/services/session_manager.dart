import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionManager {
  static const _storage = FlutterSecureStorage();
  static const _keyId = 'id';
  static const _keyRole = 'role';
  static const _keyToken = 'session_token';
  static const _keyLoginAt = 'session_login_at';

  static String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String normalizeRole(String? role) {
    final value = (role ?? '').trim().toLowerCase();
    if (value == 'superadmin' || value == 'administrator' || value == 'admin') {
      return 'superadmin';
    }
    if (value == 'user' || value == 'auditor') {
      return 'auditor';
    }
    return 'auditor';
  }

  static Future<void> saveSession(String id, String role) async {
    final token = _generateToken();
    final loginAt = DateTime.now().toUtc().toIso8601String();
    final normalizedRole = normalizeRole(role);
    await _storage.write(key: _keyId, value: id);
    await _storage.write(key: _keyRole, value: normalizedRole);
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyLoginAt, value: loginAt);
  }

  static Future<Map<String, String?>> getSession() async {
    final id = await _storage.read(key: _keyId);
    final role = await _storage.read(key: _keyRole);
    final token = await _storage.read(key: _keyToken);
    final loginAt = await _storage.read(key: _keyLoginAt);
    return {'id': id, 'role': role, 'token': token, 'loginAt': loginAt};
  }

  static Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
