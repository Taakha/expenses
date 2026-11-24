import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/app/app.dart';
import 'package:moneywise/core/theme/app_theme.dart';
import 'package:moneywise/core/theme/theme_provider.dart';
import 'package:moneywise/core/widgets/glass_container.dart';
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

  testWidgets('glass panels provide a Material surface for list tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: GlassContainer(
            child: CheckboxListTile(
              dense: true,
              value: false,
              onChanged: (_) {},
              title: const Text('Terms'),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
