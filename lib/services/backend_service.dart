import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class OnlineAuthResult {
  final bool ok;
  final String? role;
  final String? fullName;
  final String? message;

  const OnlineAuthResult({
    required this.ok,
    this.role,
    this.fullName,
    this.message,
  });
}

class BackendService {
  // Android emulator → your PC's localhost
  static const String _baseUrl = 'http://10.0.2.2/vaudit_api';

  /// First-time verification against a remote MySQL-backed API.
  ///
  /// Expected response JSON (example):
  /// { "ok": true, "role": "auditor", "fullName": "Jane Doe" }
  /// or { "ok": false, "message": "Invalid credentials" }
  static Future<OnlineAuthResult> verifyFirstLogin({
    required String id,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/login.php');
    try {
      final response = await http.post(
        url,
        body: {'id': id, 'password': password},
      );

      if (response.statusCode != 200) {
        return OnlineAuthResult(
          ok: false,
          message: 'Server error ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const OnlineAuthResult(ok: false, message: 'Invalid response');
      }

      final ok = decoded['ok'] == true || decoded['success'] == true;
      if (!ok) {
        return OnlineAuthResult(
          ok: false,
          message: (decoded['message'] ?? 'Invalid credentials').toString(),
        );
      }

      return OnlineAuthResult(
        ok: true,
        role: decoded['role']?.toString(),
        fullName: decoded['fullName']?.toString(),
        message: decoded['message']?.toString(),
      );
    } catch (e) {
      return OnlineAuthResult(ok: false, message: e.toString());
    }
  }

  /// Best-effort user upsert to server so MySQL stays in sync.
  ///
  /// Server endpoint: POST $_baseUrl/upsert_user.php
  /// Expected response JSON: { "ok": true } or { "ok": false, "message": "..." }
  static Future<bool> upsertUserToServer({
    required String id,
    required String passwordSha256Hex,
    required String role,
    required String fullName,
  }) async {
    final url = Uri.parse('$_baseUrl/upsert_user.php');
    final response = await http.post(
      url,
      body: {
        'id': id,
        'password': passwordSha256Hex,
        'role': role,
        'fullName': fullName,
      },
    );

    if (response.statusCode != 200) return false;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return false;
    return decoded['ok'] == true || decoded['success'] == true;
  }

  static Future<void> testConnection(BuildContext context) async {
    final url = Uri.parse('$_baseUrl/ping.php');

    try {
      final response = await http.get(url);

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('XAMPP OK: ${data.toString()}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'XAMPP error ${response.statusCode}: ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: $e')),
      );
    }
  }

  /// Best-effort template publish to server.
  /// Non-blocking — template is saved locally regardless of server response.
  static Future<bool> publishTemplate({
    required String templateId,
    required String name,
    required int itemCount,
  }) async {
    final url = Uri.parse('$_baseUrl/publish_template.php');
    try {
      final response = await http.post(
        url,
        body: {
          'templateId': templateId,
          'name': name,
          'itemCount': itemCount.toString(),
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      return decoded['ok'] == true || decoded['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
