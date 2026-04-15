import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  static Future<bool> requestStoragePermission() async {
    // For Android 13+ (API 33+)
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    // For older versions (API < 33)
    if (await Permission.storage.request().isGranted) {
      return true;
    }

    // Check if permanently denied
    if (await Permission.storage.isPermanentlyDenied ||
        await Permission.manageExternalStorage.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }
}
