import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/main.dart';
import 'package:moneywise/core/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Firebase setup errors are shown with actionable guidance', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MoneyWiseApp(
        preferences: preferences,
        themeProvider: ThemeProvider(preferences),
        startupError: StateError('missing Firebase options'),
      ),
    );

    expect(find.text('Firebase could not start'), findsOneWidget);
    expect(
      find.text(
        'Check the Firebase configuration for this platform, then restart the app.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('missing Firebase options'), findsOneWidget);
  });
}
