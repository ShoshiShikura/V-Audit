import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tm_audit/screens/company_name_screen.dart';

void main() {
  testWidgets('CompanyNameScreen builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CompanyNameScreen(documentId: 'doc_1', userId: 'test', role: 'admin'),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);
  });
}
