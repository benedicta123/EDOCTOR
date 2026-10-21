import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edoctor_admin/main.dart';

void main() {
  testWidgets('Admin app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EDoctorAdminApp(initialRoute: '/login'));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
