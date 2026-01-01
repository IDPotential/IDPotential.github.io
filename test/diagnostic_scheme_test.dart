import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_diagnostic_app/widgets/diagnostic_scheme.dart';

void main() {
  testWidgets('DiagnosticSchemeWidget renders correctly', (WidgetTester tester) async {
    // Mock data
    final numbers = [1, 1, 2, 4, 20, 2, 3, 19, 5, 6, 11, 12, 9, 21];
    
    // Pump widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500, // Constrain size
            child: DiagnosticSchemeWidget(
              numbers: numbers,
              gender: 'М',
              name: 'Ivan',
              birthDate: '01.01.2000',
            ),
          ),
        ),
      ),
    );

    // Verify Name and Date text
    expect(find.text('Ivan (01.01.2000)'), findsOneWidget);
    
    // Verify some numbers
    expect(find.text('1'), findsAtLeastNWidgets(1));
    expect(find.text('21'), findsOneWidget);
    
    // Verify Image asset is present (it won't load in test environment without setup, but the widget structure should be there)
    expect(find.byType(Image), findsOneWidget);
  });
}
