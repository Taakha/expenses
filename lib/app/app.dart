import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/auth_service.dart';
import '../core/services/finance_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../core/widgets/glass_button.dart';
import '../core/widgets/glass_scaffold.dart';
import '../features/authentication/screens/auth_screens.dart';
import 'navigation.dart';
import 'routes.dart';
import 'routes/route_names.dart';

class MoneyWiseApp extends StatelessWidget {
  const MoneyWiseApp({
    required this.preferences,
    required this.themeProvider,
    super.key,
    this.startupError,
  });

  final SharedPreferences preferences;
  final ThemeProvider themeProvider;
  final Object? startupError;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: preferences),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<FinanceController>(
          create: (_) => FinanceController(),
        ),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Money Wise',
          debugShowCheckedModeBanner: false,
          navigatorKey: AppRoutes.navigatorKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.themeMode,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: startupError == null
              ? const _AuthGate()
              : _StartupErrorScreen(error: startupError!),
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<bool> _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _onboardingComplete = Future.value(
      context.read<SharedPreferences>().getBool(
            'moneywise.onboardingComplete',
          ) ??
          false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.read<AuthService>().authChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupErrorScreen(error: snapshot.error!);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(message: 'Loading your account...');
        }
        final user = snapshot.data;
        if (user != null) {
          return _FinanceSession(key: ValueKey(user.uid), user: user);
        }
        return FutureBuilder<bool>(
          future: _onboardingComplete,
          builder: (context, completed) {
            if (!completed.hasData) {
              return const SplashScreen(message: 'Getting things ready...');
            }
            if (completed.data == false) {
              return OnboardingScreen(
                onComplete: () => AppRoutes.navigatorKey.currentState
                    ?.pushReplacementNamed(RouteNames.login),
              );
            }
            return const LoginScreen();
          },
        );
      },
    );
  }
}

class _FinanceSession extends StatefulWidget {
  const _FinanceSession({required this.user, super.key});

  final User user;

  @override
  State<_FinanceSession> createState() => _FinanceSessionState();
}

class _FinanceSessionState extends State<_FinanceSession> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initialize());
    });
  }

  Future<void> _initialize() {
    return context.read<FinanceController>().initialize(
      uid: widget.user.uid,
      email: widget.user.email ?? '',
      fullName: widget.user.displayName ?? '',
      phoneNumber: widget.user.phoneNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceController>(
      builder: (context, finance, _) {
        if (finance.isReadyFor(widget.user.uid)) {
          return const NavigationShell();
        }
        if (finance.isLoading) {
          return const SplashScreen(
            message: 'Preparing your offline ledger...',
          );
        }
        return GlassScaffold(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load your financial data',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  finance.lastError ?? 'The local ledger is unavailable.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                GlassButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: () => unawaited(_initialize()),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await context.read<AuthService>().signOut();
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 15),
              Text(
                'Firebase could not start',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Check the Firebase configuration for this platform, then restart the app.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SelectableText(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
