import 'package:flutter_test/flutter_test.dart';
import 'package:edoctor_mobile/app.dart';

void main() {
  testWidgets('EDoctorApp renders SplashScreen smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EDoctorApp());

    expect(find.text('Votre santé, où que vous soyez'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 100));
  });
}
