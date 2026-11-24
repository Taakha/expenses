import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/main.dart';

void main() {
  testWidgets('Firebase setup errors are shown with actionable guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MoneyWiseApp(startupError: StateError('missing Firebase options')),
    );

    expect(find.text('Could not connect to MoneyWise'), findsOneWidget);
    expect(
      find.text(
        'Firebase could not be initialized for this platform. Check your Firebase platform configuration and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('missing Firebase options'), findsOneWidget);
  });
}
