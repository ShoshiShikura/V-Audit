import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tm_audit/screens/edit_template_screen.dart';

void main() {
  testWidgets('EditTemplateScreen builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EditTemplateScreen(userId: 'test', role: 'admin'),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);
  });
}
