import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Duplicate DropdownMenuItem throws error when value is different', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DropdownButtonFormField<String>(
          value: 'A',
          items: const [
            DropdownMenuItem(value: 'A', child: Text('A')),
            DropdownMenuItem(value: 'B', child: Text('B')),
            DropdownMenuItem(value: 'B', child: Text('B')),
          ],
          onChanged: (val) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  });
}
