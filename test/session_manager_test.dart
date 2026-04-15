import 'package:flutter_test/flutter_test.dart';
import 'package:tm_audit/services/session_manager.dart';

import 'helpers/flutter_secure_storage_mock.dart';

void main() {
  setUpAll(() {
    FlutterSecureStorageMock.setup();
  });

  setUp(() async {
    FlutterSecureStorageMock.clear();
    await SessionManager.clearSession();
  });

  group('SessionManager role normalization', () {
    test('maps administrator aliases to superadmin', () {
      expect(SessionManager.normalizeRole('administrator'), 'superadmin');
      expect(SessionManager.normalizeRole('admin'), 'superadmin');
      expect(SessionManager.normalizeRole('superadmin'), 'superadmin');
    });

    test('maps auditor aliases to auditor', () {
      expect(SessionManager.normalizeRole('auditor'), 'auditor');
      expect(SessionManager.normalizeRole('user'), 'auditor');
      expect(SessionManager.normalizeRole('USER'), 'auditor');
    });

    test('defaults unknown role to auditor', () {
      expect(SessionManager.normalizeRole('custom-role'), 'auditor');
      expect(SessionManager.normalizeRole(null), 'auditor');
      expect(SessionManager.normalizeRole(''), 'auditor');
    });

    test('saveSession persists normalized role', () async {
      await SessionManager.saveSession('u1', 'administrator');
      final session = await SessionManager.getSession();
      expect(session['id'], 'u1');
      expect(session['role'], 'superadmin');
      expect(session['token'], isNotNull);
      expect(session['loginAt'], isNotNull);
    });
  });
}
