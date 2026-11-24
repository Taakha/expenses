import 'package:flutter/material.dart';

import '../data/models/finance_models.dart';
import '../features/accounts/accounts_screen.dart';
import '../features/authentication/screens/auth_screens.dart';
import '../features/budgets/budgets_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/debts/debts_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/profile/backup_screen.dart';
import '../features/profile/conflicts_screen.dart';
import '../features/recurring/recurring_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/savings/savings_screen.dart';
import '../features/transactions/transaction_details_screen.dart';
import '../features/transactions/transaction_form_screen.dart';
import '../features/transactions/transactions_screen.dart';
import 'navigation.dart';
import 'routes/route_names.dart';

class TransactionFormArguments {
  const TransactionFormArguments({
    this.initialType = TransactionType.expense,
    this.existing,
  });

  final TransactionType initialType;
  final FinancialTransaction? existing;
}

class AppRoutes {
  const AppRoutes._();

  static const home = RouteNames.dashboard;
  static const login = RouteNames.login;
  static const register = RouteNames.register;
  static const forgotPassword = RouteNames.forgotPassword;
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final Widget page;
    switch (settings.name) {
      case RouteNames.dashboard:
        page = const NavigationShell();
        break;
      case RouteNames.login:
        page = const LoginScreen();
        break;
      case RouteNames.register:
        page = const RegisterScreen();
        break;
      case RouteNames.forgotPassword:
        page = const ForgotPasswordScreen();
        break;
      case RouteNames.onboarding:
        page = OnboardingScreen(
          onComplete: () =>
              navigatorKey.currentState?.pushReplacementNamed(RouteNames.login),
        );
        break;
      case RouteNames.accounts:
        page = const AccountsScreen();
        break;
      case RouteNames.transactions:
        page = const TransactionsScreen();
        break;
      case RouteNames.transactionAdd:
        final arguments = settings.arguments;
        final formArguments = arguments is TransactionFormArguments
            ? arguments
            : const TransactionFormArguments();
        page = TransactionFormScreen(
          initialType: formArguments.initialType,
          existing: formArguments.existing,
        );
        break;
      case RouteNames.transactionDetails:
        final transaction = settings.arguments;
        page = transaction is FinancialTransaction
            ? TransactionDetailsScreen(transaction: transaction)
            : const _InvalidRoutePage(
                message: 'Transaction details need a transaction.',
              );
        break;
      case RouteNames.budgets:
        page = const BudgetsScreen();
        break;
      case RouteNames.savings:
        page = const SavingsScreen();
        break;
      case RouteNames.savingsGoalAdd:
        final goal = settings.arguments;
        page = SavingsGoalFormScreen(
          existing: goal is SavingsGoal ? goal : null,
        );
        break;
      case RouteNames.reports:
        page = const ReportsScreen();
        break;
      case RouteNames.profile:
        page = const ProfileScreen();
        break;
      case RouteNames.settings:
        page = const SettingsScreen();
        break;
      case RouteNames.notifications:
        page = const NotificationsScreen();
        break;
      case RouteNames.categories:
        page = const CategoriesScreen();
        break;
      case RouteNames.debts:
        page = const DebtsScreen();
        break;
      case RouteNames.recurring:
        page = const RecurringScreen();
        break;
      case RouteNames.backup:
        page = const BackupScreen();
        break;
      case RouteNames.conflicts:
        page = const ConflictsScreen();
        break;
      default:
        page = _InvalidRoutePage(message: 'Unknown route: ${settings.name}');
        break;
    }
    return MaterialPageRoute<void>(
      builder: (context) => page,
      settings: settings,
    );
  }
}

class _InvalidRoutePage extends StatelessWidget {
  const _InvalidRoutePage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}
