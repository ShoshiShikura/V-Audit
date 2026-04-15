import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tm_audit/services/audit_data_transfer_service.dart';
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

  group('AuditDataTransferService .auditdata flow', () {
    test('exports then imports full data object (v2 envelope)', () async {
      final exportData = <String, dynamic>{
        'meta': {
          'docId': 'doc-1',
          'docTitle': 'Audit One',
          'exportVersion': '1.1.0',
        },
        'document': {'id': 'doc-1', 'title': 'Audit One'},
        'teams': [
          {'id': 't1', 'documentId': 'doc-1'},
        ],
      };

      final fileContent = await AuditDataTransferService.buildExportFileContent(
        exportData,
      );
      final decoded = await AuditDataTransferService.decodeImportFileContent(
        fileContent,
      );

      expect(decoded.importedFromLegacyFormat, isFalse);
      expect(decoded.data['meta']['docId'], 'doc-1');
      expect(decoded.data['document']['title'], 'Audit One');
      expect((decoded.data['teams'] as List).length, 1);
    });

    test('rejects unsupported envelope version', () async {
      final exportData = <String, dynamic>{
        'meta': {'docId': 'doc-v'},
        'document': {'id': 'doc-v'},
      };
      final fileContent = await AuditDataTransferService.buildExportFileContent(
        exportData,
      );
      final parsed = jsonDecode(fileContent) as Map<String, dynamic>;
      parsed['version'] = '9.9.9';

      await expectLater(
        AuditDataTransferService.decodeImportFileContent(jsonEncode(parsed)),
        throwsA(isA<Object>()),
      );
    });

    test('rejects malformed envelope payload', () async {
      final malformed = jsonEncode({
        'kind': 'tm_audit_export',
        'version': '2.0.0',
        'algorithm': 'AES-256-GCM',
        'payload': 'not-base64',
      });

      await expectLater(
        AuditDataTransferService.decodeImportFileContent(malformed),
        throwsA(isA<Object>()),
      );
    });

    test('rejects tampered encrypted payload', () async {
      final exportData = <String, dynamic>{
        'meta': {'docId': 'doc-t'},
        'document': {'id': 'doc-t'},
      };
      final fileContent = await AuditDataTransferService.buildExportFileContent(
        exportData,
      );
      final envelope = jsonDecode(fileContent) as Map<String, dynamic>;
      final encryptedPayload = envelope['payload'] as String;
      final wrapped = jsonDecode(
        utf8.decode(base64Url.decode(encryptedPayload)),
      ) as Map<String, dynamic>;
      final tag = wrapped['t'] as String;
      wrapped['t'] =
          '${tag.substring(0, tag.length - 1)}${tag.endsWith('A') ? 'B' : 'A'}';
      envelope['payload'] = base64Url.encode(utf8.encode(jsonEncode(wrapped)));

      await expectLater(
        AuditDataTransferService.decodeImportFileContent(jsonEncode(envelope)),
        throwsA(isA<Object>()),
      );
    });

    test('imports legacy encrypted payload and marks compatibility mode', () async {
      const keyName = 'data_encryption_key';
      final knownKey = base64Url.encode(List<int>.generate(32, (i) => i + 9));
      FlutterSecureStorageMock.setValue(keyName, knownKey);

      final legacyJson = jsonEncode({
        'meta': {'docId': 'doc-legacy'},
        'document': {'id': 'doc-legacy', 'title': 'Legacy'},
      });

      final keyBytes = utf8.encode(knownKey);
      final ivBytes = List<int>.generate(16, (i) => i + 5);
      final plainBytes = utf8.encode(legacyJson);
      final encryptedBytes = List<int>.generate(plainBytes.length, (i) {
        return plainBytes[i] ^
            keyBytes[i % keyBytes.length] ^
            ivBytes[i % ivBytes.length];
      });
      final legacyPayload = base64Url.encode(ivBytes + encryptedBytes);

      final decoded = await AuditDataTransferService.decodeImportFileContent(
        legacyPayload,
      );
      expect(decoded.importedFromLegacyFormat, isTrue);
      expect(decoded.data['document']['title'], 'Legacy');
    });
  });
}
