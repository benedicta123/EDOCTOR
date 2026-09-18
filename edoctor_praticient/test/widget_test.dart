import 'package:flutter_test/flutter_test.dart';
import 'package:edoctor_praticient/app.dart';

void main() {
  testWidgets('Praticien app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PraticienApp());
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('eDoctor'), findsWidgets);
  });
}
