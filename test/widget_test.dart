import 'package:flutter_test/flutter_test.dart';
import 'package:alloguinaar/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AlloGuinaarApp());
  });
}