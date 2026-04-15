import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tm_audit/services/data_encryption_service.dart';

import 'helpers/flutter_secure_storage_mock.dart';

void main() {
  setUpAll(() {
    FlutterSecureStorageMock.setup();
  });

  setUp(() async {
    FlutterSecureStorageMock.clear();
    await DataEncryptionService.clearKeys();
  });

  group('DataEncryptionService export envelope', () {
    test('creates and opens v2 export envelope', () async {
      const payload = '{"hello":"world"}';
      final envelope = await DataEncryptionService.createExportEnvelope(payload);

      final parsed = jsonDecode(envelope) as Map<String, dynamic>;
      expect(parsed['kind'], 'tm_audit_export');
      expect(parsed['version'], '2.0.0');
      expect(parsed['algorithm'], 'AES-256-GCM');
      expect(parsed['payload'], isA<String>());

      final opened = await DataEncryptionService.openExportEnvelope(envelope);
      expect(opened, payload);
    });

    test('rejects tampered payload in strict open', () async {
      const payload = '{"docId":"abc"}';
      final envelope = await DataEncryptionService.createExportEnvelope(payload);
      final parsed = jsonDecode(envelope) as Map<String, dynamic>;
      final encryptedPayload = parsed['payload'] as String;

      final wrapped = jsonDecode(
        utf8.decode(base64Url.decode(encryptedPayload)),
      ) as Map<String, dynamic>;
      final cipherText = wrapped['c'] as String;
      wrapped['c'] = cipherText.substring(0, cipherText.length - 1) +
          (cipherText.endsWith('A') ? 'B' : 'A');
      parsed['payload'] = base64Url.encode(utf8.encode(jsonEncode(wrapped)));

      await expectLater(
        DataEncryptionService.openExportEnvelope(jsonEncode(parsed)),
        throwsA(isA<Object>()),
      );
    });

    test('supports decrypting legacy xor payloads in strict mode', () async {
      const plain = '{"legacy":true}';
      const keyName = 'data_encryption_key';
      final knownKey = base64Url.encode(List<int>.generate(32, (i) => i + 17));
      FlutterSecureStorageMock.setValue(keyName, knownKey);

      final legacyKeyBytes = utf8.encode(knownKey);
      final ivBytes = List<int>.generate(16, (i) => i + 11);
      final plainBytes = utf8.encode(plain);
      final encryptedBytes = List<int>.generate(plainBytes.length, (i) {
        return plainBytes[i] ^
            legacyKeyBytes[i % legacyKeyBytes.length] ^
            ivBytes[i % ivBytes.length];
      });

      final combined = base64Url.encode(ivBytes + encryptedBytes);
      final decrypted = await DataEncryptionService.decryptDataStrict(combined);
      expect(decrypted, plain);
    });
  });
}
