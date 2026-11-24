# MoneyWise

MoneyWise is a personal spending tracker built with Flutter and Firebase. It
includes email/password accounts, a monthly income and expense overview,
transaction history, category budgets, and password reset.

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

Transactions and budgets are stored under
`users/{authenticatedUserId}/transactions` and
`users/{authenticatedUserId}/budgets`. Firestore rules prevent users from
accessing another account's records.

MoneyWise is a manual tracking tool. It does not connect to banks or provide
financial advice.
