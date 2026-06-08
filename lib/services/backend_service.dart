import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../db/database_helper.dart';

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
  // Default fallback
  static String _baseUrl = 'http://10.70.213.77/vaudit_api';

  static void setBaseUrl(String url) {
    _baseUrl = url;
  }

  static String get baseUrl => _baseUrl;

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
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 401) {
        String msg = 'Incorrect password';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            msg = decoded['message'].toString();
          }
        } catch (_) {}
        return OnlineAuthResult(ok: false, message: msg);
      }

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
    try {
      final url = Uri.parse('$_baseUrl/upsert_user.php');
      final response = await http.post(
        url,
        body: {
          'id': id,
          'password': passwordSha256Hex,
          'role': role,
          'fullName': fullName,
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        debugPrint('upsertUserToServer HTTP Error: ${response.statusCode} - ${response.body}');
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      return decoded['ok'] == true || decoded['success'] == true;
    } catch (e) {
      debugPrint('upsertUserToServer Exception: $e');
      return false;
    }
  }

  static Future<void> testConnection(BuildContext context) async {
    final url = Uri.parse('$_baseUrl/ping.php');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));

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

  /// Fetches all users from the central MySQL database.
  /// Returns a list of {id, role, fullName} maps, or null on failure.
  static Future<List<Map<String, dynamic>>?> fetchUsersFromServer() async {
    final url = Uri.parse('$_baseUrl/list_users.php');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      if (decoded['ok'] != true) return null;
      final users = decoded['users'];
      if (users is! List) return null;
      return users.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Deletes a user from the central MySQL database on XAMPP.
  /// Returns true if the server confirmed deletion, false otherwise.
  static Future<bool> deleteUserFromServer(String id) async {
    final url = Uri.parse('$_baseUrl/delete_user.php');
    try {
      final response = await http.post(
        url,
        body: {'id': id},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      return decoded['ok'] == true || decoded['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Requests a password reset for the specified username.
  /// Server endpoint: POST $_baseUrl/request_password_reset.php
  static Future<bool> requestPasswordReset(String username) async {
    final url = Uri.parse('$_baseUrl/request_password_reset.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      return decoded['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  // ── Company Management ─────────────────────────────────────────────

  /// Deletes a company from the central MySQL database on XAMPP.
  static Future<bool> deleteCompanyFromServer(String companyName) async {
    final url = Uri.parse('$_baseUrl/delete_company.php');
    try {
      final response = await http.post(
        url,
        body: {'name': companyName},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return false;
      return decoded['ok'] == true || decoded['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── Worker Management ─────────────────────────────────────────────

  /// Adds a worker to the central MySQL database on XAMPP.
  static Future<bool> addWorkerToServer({
    required String userId,
    required String name,
    required String ic,
    required String companies,
    required String status,
  }) async {
    final url = Uri.parse('$_baseUrl/add_worker.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'name': name,
          'ic': ic,
          'companies': companies,
          'status': status,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['ok'] == true || decoded['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a worker from the central MySQL database on XAMPP.
  static Future<bool> deleteWorkerFromServer(String userId) async {
    final url = Uri.parse('$_baseUrl/delete_worker.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['ok'] == true || decoded['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Synchronization to XAMPP ─────────────────────────────────────────

  /// Pushes all offline documents, templates, and evidence metadata to XAMPP.
  static Future<bool> syncAuditDataToXampp() async {
    final url = Uri.parse('$_baseUrl/sync_audit.php');
    try {
      final data = await DatabaseHelper().getAllDataForSync();

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body);
      if (decoded['ok'] == true) {
        await DatabaseHelper().clearDeletedDocuments();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Sync Audit Error: $e');
      return false;
    }
  }

  /// Pulls all audit data from XAMPP and imports it to the local SQLite DB.
  static Future<bool> pullAuditDataFromXampp(String currentUserId) async {
    final url = Uri.parse('$_baseUrl/pull_audit.php');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(response.body);
      if (decoded['ok'] == true && decoded['data'] != null) {
        final rawJsonList = decoded['data'] as List;
        for (var rawJsonStr in rawJsonList) {
          try {
            // Check if it's a string, then parse it, or if it's already a map
            final Map<String, dynamic> docData = rawJsonStr is String ? jsonDecode(rawJsonStr) : rawJsonStr;
            await DatabaseHelper().importRawAuditData(docData, currentUserId);
          } catch (e) {
            debugPrint('Failed to process pulled document: $e');
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Sync Pull Error: $e');
      return false;
    }
  }

  /// Finds newly captured evidence images and uploads them safely.
  static Future<bool> syncEvidenceImagesToXampp() async {
    final url = Uri.parse('$_baseUrl/upload_evidence.php');
    try {
      final unsynced = await DatabaseHelper().getUnsyncedEvidence();
      bool allSuccessful = true;

      for (var record in unsynced) {
        String teamId = record['teamId'];
        String attachPath = record['attachmentPath'];

        final file = File(attachPath);
        if (!await file.exists()) continue;

        var request = http.MultipartRequest('POST', url);
        request.files.add(
          await http.MultipartFile.fromPath('evidence_image', file.path),
        );

        final response =
            await request.send().timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final resBody = await response.stream.bytesToString();
          final decoded = jsonDecode(resBody);
          if (decoded['ok'] == true) {
            // Update local SQLite to point to new server path securely
            await DatabaseHelper().updateEvidencePath(teamId, decoded['path']);
          } else {
            allSuccessful = false;
          }
        } else {
          allSuccessful = false;
        }
      }
      return allSuccessful;
    } catch (e) {
      debugPrint('Evidence Sync Error: $e');
      return false;
    }
  }
}
