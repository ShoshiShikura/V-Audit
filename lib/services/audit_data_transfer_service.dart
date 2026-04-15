import 'dart:convert';

import 'data_encryption_service.dart';

class AuditDataImportResult {
  final Map<String, dynamic> data;
  final bool importedFromLegacyFormat;

  const AuditDataImportResult({
    required this.data,
    required this.importedFromLegacyFormat,
  });
}

class AuditDataTransferService {
  static Future<String> buildExportFileContent(
    Map<String, dynamic> exportData,
  ) async {
    final jsonStr = jsonEncode(exportData);
    return DataEncryptionService.createExportEnvelope(jsonStr);
  }

  static Future<AuditDataImportResult> decodeImportFileContent(
    String rawFileText,
  ) async {
    try {
      final decrypted = await DataEncryptionService.openExportEnvelope(
        rawFileText,
      );
      final data = jsonDecode(decrypted);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Decrypted content must be a JSON object.');
      }
      return AuditDataImportResult(
        data: data,
        importedFromLegacyFormat: false,
      );
    } catch (_) {
      final decryptedLegacy =
          await DataEncryptionService.decryptDataStrict(rawFileText);
      final data = jsonDecode(decryptedLegacy);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Legacy content must be a JSON object.');
      }
      return AuditDataImportResult(
        data: data,
        importedFromLegacyFormat: true,
      );
    }
  }
}
