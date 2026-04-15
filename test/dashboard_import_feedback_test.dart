import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tm_audit/screens/dashboard_screen.dart';

void main() {
  testWidgets(
    'DashboardScreen shows import error snackbar for invalid/tampered files',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      DashboardScreen.showImportFailureSnackBar(context);
                    },
                    child: const Text('Trigger Import Error'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Import Error'));
      await tester.pump(); // Start snackbar animation

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(DashboardScreen.importFailureMessage), findsOneWidget);
    },
  );
}
