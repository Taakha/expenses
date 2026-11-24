# MoneyWise

MoneyWise is an offline-first personal finance tracker built with Flutter,
SQLite, and Firebase. It supports multiple accounts and currencies, income and
expense transactions, budgets, savings goals, debts, recurring transactions,
reports, notifications, and local backups. Changes are saved to the local
ledger first and queued for Firestore synchronization when a connection is
available.

Transaction history has no daily, monthly, yearly, or per-account quota. It is
loaded in indexed pages, while balances and reports are calculated from exact
minor-unit values in SQLite. Verified local backups include receipt attachments.

## Firebase setup

1. In Firebase Console, enable **Email/Password** under Authentication providers
   and create a Cloud Firestore database.
2. Select the Firebase project used by the app in the Firebase CLI, then deploy
   the included owner-scoped Firestore rules:

   ```sh
   firebase use --add
   firebase deploy --only firestore:rules
   ```

3. Configure Firebase options for each target with FlutterFire CLI if using a
   different Firebase project. This checkout currently contains options for
   Android, web, and Windows.
4. Install dependencies and run the app:

   ```sh
   flutter pub get
   flutter run
   ```

Each user's profile and financial collections are stored under
`users/{authenticatedUserId}`. The Firestore rules allow authenticated users to
access only their own profile and subcollections.

MoneyWise is a manual tracking tool. It does not connect to banks or provide
financial advice.
