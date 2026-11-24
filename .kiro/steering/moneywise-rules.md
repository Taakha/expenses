---
inclusion: always
---

# Money Wise – Project Rules and Financial System

## Project Identity
- **App name**: Money Wise
- **Institution**: Metropolitan International University (MIU)
- **Purpose**: Personal finance management for university students
- **Stack**: Flutter · Dart · SQLite (sqflite) · Firebase (Auth, Firestore, Storage)
- **Design**: Compact teal-green glassmorphism
- **State management**: Provider (`FinanceController` as the central `ChangeNotifier`)

## Confirmed Architecture Decisions
| Area | Decision |
|---|---|
| Account management | Multiple financial accounts |
| Default currency | Each user selects their preferred currency during registration |
| Connectivity | Offline-first (SQLite primary, Firestore cloud sync) |
| Local database | sqflite (NOT Drift) |
| Theme | Light, dark and system |
| Navigation | Five-tab bottom navigation |

## Key Files
- `lib/data/local/app_database.dart` — SQLite schema (all 15 tables, version 1)
- `lib/data/models/finance_models.dart` — All domain models
- `lib/data/repositories/finance_repository.dart` — All DB read/write logic and validation
- `lib/core/services/finance_controller.dart` — Central state manager (ChangeNotifier)
- `lib/core/services/financial_calculation_service.dart` — ONLY authoritative calculation engine
- `lib/data/synchronization/sync_service.dart` — Firestore sync logic
- `lib/app/app.dart` — Root widget, Provider tree, AuthGate
- `lib/app/routes.dart` + `lib/app/routes/route_names.dart` — All navigation routes
- `lib/app/navigation.dart` — 5-tab NavigationShell

## Critical Financial Rules (Never Violate)
1. **Single source of truth**: All screens read from the same SQLite ledger via `FinanceController`. Never write independent balance calculations in screen widgets.
2. **`FinancialCalculationService` is the only calculation engine** for balances, budget progress, savings totals and debt outstanding.
3. **Amounts are stored as integers in minor units** (e.g., UGX uses 0 decimal places, so `500000` = UGX 500,000). Never use `double` for monetary values.
4. **Transfers are not income or expenses**. Creating a transfer moves money between owned accounts — net worth does not change.
5. **Savings contributions are not expenses**. They track progress toward a goal but do not reduce account balances unless linked to an actual transfer.
6. **Money borrowed is not income. Money lent is not an expense.**
7. **Never add amounts in different currencies directly.**
8. **Historical transaction amounts never change when exchange rates change.**

## Balance Formula
```
accountBalance = openingBalance + income - expenses + transfersIn - transfersOut
```
Implemented in `FinancialCalculationService.accountBalance()`.

## Transaction Types
`income`, `expense`, `transfer`, `refund`, `adjustment`

## Flutter/Dart API Rules (Flutter 3.47.5, Dart 3.13.4)
- Use `withValues(alpha: x)` NOT `withOpacity(x)` for Color alpha
- `DropdownButtonFormField` supports `initialValue` parameter
- Null-aware list element `?element` is valid Dart syntax (requires Dart 3.12+)
- `google_sign_in` 7.x: use `GoogleSignIn.instance`, `initialize()`, `authenticate()`, `account.authentication.idToken`
- Receipt images are file system paths (use `Image.file(File(path))` not `Image.asset(path)`)

## Currency Precision
| Currency | Decimal places | Minor unit multiplier |
|---|---|---|
| UGX, KES, TZS, JPY | 0 | 1 |
| USD, EUR, GBP, NGN, ZAR | 2 | 100 |

Defined in `lib/core/utils/money.dart` → `currencyFractionDigits()`.

## Supported Currencies
UGX, USD, EUR, GBP, KES, TZS, NGN, ZAR — defined in `AppConstants.supportedCurrencies`.

## Default Categories
**Income**: Salary, Business, Allowance, Scholarship, Freelance, Gift, Other income  
**Expense**: Food, Accommodation, Transport, Education, Communication, Shopping, Personal care, Entertainment, Health, Bills, Other

## Sync Architecture
1. Write to SQLite first
2. Add record to `sync_queue` table
3. When online: upload pending records to Firestore with idempotent upserts
4. Mark as synced only after server confirms
5. Pull remote changes after upload
6. Detect conflicts using `version` field; store in `sync_conflicts` for user resolution

## Screen → Route Map
| Route | Screen |
|---|---|
| `/` | `NavigationShell` (5-tab shell) |
| `/login` | `LoginScreen` |
| `/register` | `RegisterScreen` |
| `/forgot-password` | `ForgotPasswordScreen` |
| `/onboarding` | `OnboardingScreen` |
| `/accounts` | `AccountsScreen` |
| `/transactions` | `TransactionsScreen` |
| `/transactions/add` | `TransactionFormScreen` |
| `/transactions/details` | `TransactionDetailsScreen` |
| `/budgets` | `BudgetsScreen` |
| `/savings` | `SavingsScreen` + `SavingsGoalFormScreen` |
| `/reports` | `ReportsScreen` |
| `/profile` | `ProfileScreen` |
| `/settings` | `SettingsScreen` |
| `/notifications` | `NotificationsScreen` |
| `/categories` | `CategoriesScreen` |
| `/debts` | `DebtsScreen` |
| `/recurring` | `RecurringScreen` |
| `/backup` | `BackupScreen` |
| `/sync-conflicts` | `ConflictsScreen` |

## Reusable Widget Conventions
All screens use:
- `GlassScaffold` — the base screen scaffold with gradient background and ambient glow
- `GlassContainer` — frosted-glass card with blur backdrop
- `GlassTextField` — styled text input
- `GlassButton` — primary/outlined action button
- `ScreenHeader` — consistent page header with optional back button and trailing action
- `GlassEmptyState` — empty state card with icon, title, message and optional action
- `SyncStatusCard` — sync indicator shown on the dashboard
- `TransactionTile` — reusable transaction list item in `lib/shared/components/`
