import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DataEncryptionService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _encryptionKeyKey = 'data_encryption_key';
  static const String _exportEnvelopeKind = 'tm_audit_export';
  static const String _exportEnvelopeVersion = '2.0.0';
  static const String _algorithmName = 'AES-256-GCM';

  // Generate a secure encryption key
  static Future<String> _generateKey() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  // Get or create encryption key
  static Future<String> _getEncryptionKey() async {
    String? key = await _storage.read(key: _encryptionKeyKey);

    if (key == null) {
      key = await _generateKey();
      await _storage.write(key: _encryptionKeyKey, value: key);
    }

    return key;
  }

  static Future<SecretKey> _getSecretKey() async {
    final key = await _getEncryptionKey();
    return SecretKey(base64Url.decode(key));
  }

  // Encrypt sensitive data
  static Future<String> encryptData(String data) async {
    if (data.isEmpty) return data;

    final algorithm = AesGcm.with256bits();
    final secretKey = await _getSecretKey();
    final random = Random.secure();
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final dataBytes = utf8.encode(data);
    final box = await algorithm.encrypt(
      dataBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = <String, dynamic>{
      'v': 2,
      'alg': _algorithmName,
      'n': base64Url.encode(nonce),
      'c': base64Url.encode(box.cipherText),
      't': base64Url.encode(box.mac.bytes),
    };
    return base64Url.encode(utf8.encode(jsonEncode(envelope)));
  }

  static Map<String, dynamic>? _decodeAesEnvelope(String encryptedData) {
    try {
      final decoded = utf8.decode(base64Url.decode(encryptedData));
      final parsed = jsonDecode(decoded);
      if (parsed is! Map<String, dynamic>) return null;
      final hasFields = parsed['v'] == 2 &&
          parsed['alg'] == _algorithmName &&
          parsed['n'] is String &&
          parsed['c'] is String &&
          parsed['t'] is String;
      return hasFields ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _decryptAesEnvelope(
    Map<String, dynamic> envelope,
  ) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = await _getSecretKey();
    final nonce = base64Url.decode(envelope['n'] as String);
    final cipherText = base64Url.decode(envelope['c'] as String);
    final macBytes = base64Url.decode(envelope['t'] as String);
    final clearBytes = await algorithm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: secretKey,
    );
    return utf8.decode(clearBytes);
  }

  static Future<String> _decryptLegacyXor(String encryptedData) async {
    final key = await _getEncryptionKey();
    final keyBytes = utf8.encode(key);
    final combinedBytes = base64Url.decode(encryptedData);
    if (combinedBytes.length < 17) {
      throw const FormatException('Legacy payload is too short.');
    }
    final ivBytes = combinedBytes.sublist(0, 16);
    final encryptedBytes = combinedBytes.sublist(16);
    final decryptedBytes = List<int>.generate(encryptedBytes.length, (i) {
      return encryptedBytes[i] ^
          keyBytes[i % keyBytes.length] ^
          ivBytes[i % ivBytes.length];
    });
    return utf8.decode(decryptedBytes);
  }

  // Decrypt sensitive data (backward compatible mode)
  static Future<String> decryptData(String encryptedData) async {
    if (encryptedData.isEmpty) return encryptedData;

    try {
      final aesEnvelope = _decodeAesEnvelope(encryptedData);
      if (aesEnvelope != null) {
        return _decryptAesEnvelope(aesEnvelope);
      }
      return _decryptLegacyXor(encryptedData);
    } catch (_) {
      // Keep legacy behavior for existing plaintext values.
      return encryptedData;
    }
  }

  // Decrypt sensitive data in strict mode (fails on invalid/tampered payload)
  static Future<String> decryptDataStrict(String encryptedData) async {
    if (encryptedData.isEmpty) {
      throw const FormatException('Encrypted payload is empty.');
    }
    final aesEnvelope = _decodeAesEnvelope(encryptedData);
    if (aesEnvelope != null) {
      return _decryptAesEnvelope(aesEnvelope);
    }
    return _decryptLegacyXor(encryptedData);
  }

  static Future<String> createExportEnvelope(String plainJsonPayload) async {
    final encryptedPayload = await encryptData(plainJsonPayload);
    final envelope = <String, dynamic>{
      'kind': _exportEnvelopeKind,
      'version': _exportEnvelopeVersion,
      'algorithm': _algorithmName,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'payload': encryptedPayload,
    };
    return jsonEncode(envelope);
  }

  static Future<String> openExportEnvelope(String envelopeText) async {
    final parsed = jsonDecode(envelopeText);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Export file format is invalid.');
    }
    final kind = parsed['kind']?.toString() ?? '';
    final version = parsed['version']?.toString() ?? '';
    final payload = parsed['payload']?.toString() ?? '';

    if (kind != _exportEnvelopeKind) {
      throw const FormatException('Unsupported export file type.');
    }
    if (version != _exportEnvelopeVersion) {
      throw const FormatException('Unsupported export file version.');
    }
    if (payload.isEmpty) {
      throw const FormatException('Export payload is empty.');
    }
    return decryptDataStrict(payload);
  }

  // Encrypt sensitive fields in a map
  static Future<Map<String, dynamic>> encryptSensitiveFields(
      Map<String, dynamic> data) async {
    final encryptedData = Map<String, dynamic>.from(data);

    // Define sensitive fields that should be encrypted
    const sensitiveFields = ['name', 'ic', 'fullName', 'remark', 'members'];

    for (final field in sensitiveFields) {
      if (encryptedData.containsKey(field) && encryptedData[field] != null) {
        final value = encryptedData[field].toString();
        if (value.isNotEmpty) {
          encryptedData[field] = await encryptData(value);
        }
      }
    }

    return encryptedData;
  }

  // Decrypt sensitive fields in a map
  static Future<Map<String, dynamic>> decryptSensitiveFields(
      Map<String, dynamic> data) async {
    final decryptedData = Map<String, dynamic>.from(data);

    // Define sensitive fields that should be decrypted
    const sensitiveFields = ['name', 'ic', 'fullName', 'remark', 'members'];

    for (final field in sensitiveFields) {
      if (decryptedData.containsKey(field) && decryptedData[field] != null) {
        final value = decryptedData[field].toString();
        if (value.isNotEmpty) {
          decryptedData[field] = await decryptData(value);
        }
      }
    }

    return decryptedData;
  }

  // Check if data is encrypted
  static bool isEncrypted(String data) {
    if (data.isEmpty) return false;
    return _decodeAesEnvelope(data) != null;
  }

  // Rotate encryption keys (for security)
  static Future<void> rotateKeys() async {
    final newKey = await _generateKey();
    await _storage.write(key: _encryptionKeyKey, value: newKey);
  }

  // Clear encryption keys
  static Future<void> clearKeys() async {
    await _storage.delete(key: _encryptionKeyKey);
  }
}
