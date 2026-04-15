import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FlutterSecureStorageMock {
  static const MethodChannel _channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  static final Map<String, String> _store = <String, String>{};

  static void setup() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'read':
              final key = (methodCall.arguments as Map)['key'] as String?;
              if (key == null) return null;
              return _store[key];
            case 'write':
              final args = methodCall.arguments as Map;
              final key = args['key'] as String?;
              final value = args['value'] as String?;
              if (key != null && value != null) {
                _store[key] = value;
              }
              return null;
            case 'delete':
              final key = (methodCall.arguments as Map)['key'] as String?;
              if (key != null) {
                _store.remove(key);
              }
              return null;
            case 'deleteAll':
              _store.clear();
              return null;
            case 'containsKey':
              final key = (methodCall.arguments as Map)['key'] as String?;
              if (key == null) return false;
              return _store.containsKey(key);
            case 'readAll':
              return Map<String, String>.from(_store);
            default:
              return null;
          }
        });
  }

  static void clear() {
    _store.clear();
  }

  static void setValue(String key, String value) {
    _store[key] = value;
  }

  static String? getValue(String key) {
    return _store[key];
  }
}
