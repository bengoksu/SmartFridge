import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Giriş ekranı açılır', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartFridgeApp());

    expect(find.text('Hoş geldin'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
