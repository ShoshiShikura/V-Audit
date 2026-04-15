import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class DocumentStorage {
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<Directory> get _auditDocumentsFolder async {
    final localPath = await _localPath;
    final folder = Directory(path.join(localPath, 'audit_documents'));

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  static Future<File> createDocumentFile(String fileName) async {
    final folder = await _auditDocumentsFolder;
    return File(path.join(folder.path, fileName));
  }

  static Future<List<File>> getDocumentFiles() async {
    final folder = await _auditDocumentsFolder;
    return folder.list().where((file) => file is File).cast<File>().toList();
  }

  static Future<void> deleteDocumentFile(String fileName) async {
    final folder = await _auditDocumentsFolder;
    final file = File(path.join(folder.path, fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
