import 'package:flutter_test/flutter_test.dart';
import 'package:edoctor_pharmacy/features/auth/login_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('LoginScreen renders fields and button smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('Portail Pharmacie'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text("Se connecter à l'officine"), findsOneWidget);
  });
}
