import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _encryptionKeyKey = 'db_encryption_key';
  static const String _saltKey = 'db_salt';

  // Generate a secure encryption key for the database
  static Future<String> _generateEncryptionKey() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  // Get or create encryption key
  static Future<String> getEncryptionKey() async {
    String? key = await _storage.read(key: _encryptionKeyKey);

    if (key == null) {
      // Generate new encryption key
      key = await _generateEncryptionKey();
      await _storage.write(key: _encryptionKeyKey, value: key);
    }

    return key;
  }

  // Get or create salt for additional security
  static Future<String> getSalt() async {
    String? salt = await _storage.read(key: _saltKey);

    if (salt == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (i) => random.nextInt(256));
      salt = base64Url.encode(bytes);
      await _storage.write(key: _saltKey, value: salt);
    }

    return salt;
  }

  // Create a derived key using salt for extra security
  static Future<String> getDerivedKey() async {
    final baseKey = await getEncryptionKey();
    final salt = await getSalt();

    // Create a derived key using PBKDF2-like approach
    final combined = utf8.encode(baseKey + salt);
    final hash = sha256.convert(combined);

    return base64Url.encode(hash.bytes);
  }

  // Change encryption key (for security rotation)
  static Future<void> rotateEncryptionKey() async {
    final newKey = await _generateEncryptionKey();
    await _storage.write(key: _encryptionKeyKey, value: newKey);
  }

  // Clear encryption keys (for app uninstall simulation)
  static Future<void> clearEncryptionKeys() async {
    await _storage.delete(key: _encryptionKeyKey);
    await _storage.delete(key: _saltKey);
  }

  // Check if encryption is properly set up
  static Future<bool> isEncryptionReady() async {
    final key = await _storage.read(key: _encryptionKeyKey);
    final salt = await _storage.read(key: _saltKey);
    return key != null && salt != null;
  }
}
