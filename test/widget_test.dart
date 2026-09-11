import 'package:flutter_test/flutter_test.dart';
import 'package:nuvex/app/app.dart';

void main() {
  testWidgets('NuvexApp smoke test launches cleanly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NuvexApp());
    expect(find.text('Nuvex'), findsWidgets);
    expect(find.text('Your files, your space.'), findsOneWidget);
  });
}
