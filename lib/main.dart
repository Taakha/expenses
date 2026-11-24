import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';

const _ink = Color(0xFF14251F);
const _green = Color(0xFF1E805B);
const _mint = Color(0xFFE7F4EC);
const _canvas = Color(0xFFF6F8F5);
const _categories = <String>[
  'Food',
  'Transport',
  'Shopping',
  'Bills',
  'Health',
  'Entertainment',
  'Income',
  'Other',
];

final _money = NumberFormat.currency(locale: 'en_US', symbol: '\$');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (error) {
    startupError = error;
  }
  runApp(MoneyWiseApp(startupError: startupError));
}

class MoneyWiseApp extends StatelessWidget {
  const MoneyWiseApp({super.key, this.startupError});

  final Object? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneyWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          primary: _green,
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: _ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
          titleLarge: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: TextStyle(color: Color(0xFF68766F), fontSize: 14),
        ),
      ),
      home: startupError == null
          ? const _AuthGate()
          : _StartupErrorPage(error: startupError!),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BrandMark(size: 66),
                const SizedBox(height: 22),
                Text(
                  'Could not connect to MoneyWise',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Firebase could not be initialized for this platform. Check your Firebase platform configuration and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                SelectableText(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MessagePage(
            title: 'Authentication unavailable',
            message: snapshot.error.toString(),
            icon: Icons.lock_outline,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPage();
        }
        return snapshot.data == null ? const _SignInPage() : const _HomePage();
      },
    );
  }
}

class _SignInPage extends StatefulWidget {
  const _SignInPage();

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _creatingAccount = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_creatingAccount) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        await credential.user?.updateDisplayName(_nameController.text.trim());
      } else {
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      setState(() => _error = _authError(error));
    } catch (error) {
      setState(
        () => _error = 'Something went wrong. Please try again. ($error)',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
        () => _error = 'Enter your email address above to reset your password.',
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (error) {
      setState(() => _error = _authError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: _BrandMark(size: 72)),
                    const SizedBox(height: 18),
                    Text(
                      _creatingAccount
                          ? 'Make money feel simpler.'
                          : 'Welcome back.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _creatingAccount
                          ? 'Start building healthier money habits today.'
                          : 'Your money, clear and in control.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 34),
                    if (_creatingAccount) ...[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration(
                          'Your name',
                          Icons.person_outline,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        'Email address',
                        Icons.mail_outline,
                      ),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration:
                          _inputDecoration(
                            'Password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (!_creatingAccount)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      _InlineError(message: _error!),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _creatingAccount ? 'Create account' : 'Sign in',
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _creatingAccount = !_creatingAccount;
                              _error = null;
                            }),
                      child: Text(
                        _creatingAccount
                            ? 'Already have an account? Sign in'
                            : 'New to MoneyWise? Create an account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final pages = <Widget>[
      _DashboardPage(onNavigate: (index) => setState(() => _tab = index)),
      const _TransactionsPage(),
      const _BudgetsPage(),
      _ProfilePage(user: user),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: pages),
      ),
      floatingActionButton: _tab == 0 || _tab == 1
          ? FloatingActionButton(
              onPressed: () => _showTransactionEditor(context),
              backgroundColor: _green,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final transactions = _transactions(user.uid);
    final budgets = _budgets(user.uid);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    return StreamBuilder<List<MoneyTransaction>>(
      stream: transactions,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <MoneyTransaction>[];
        final monthly = all.where(
          (item) =>
              !item.date.isBefore(monthStart) &&
              item.date.year == now.year &&
              item.date.month == now.month,
        );
        final expenses = monthly
            .where((item) => !item.isIncome)
            .fold<double>(0, (total, item) => total + item.amount);
        final income = monthly
            .where((item) => item.isIncome)
            .fold<double>(0, (total, item) => total + item.amount);
        final recent = all.take(5).toList();
        final displayName = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim().split(' ').first
            : 'there';
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const _BrandMark(size: 42),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'MoneyWise',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Profile and settings',
                  onPressed: () => onNavigate(3),
                  icon: const Icon(Icons.account_circle_outlined, color: _ink),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Good ${_greeting()}, $displayName',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Your money at a glance',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            _BalanceCard(income: income, expenses: expenses),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly budgets',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => onNavigate(2),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 5),
            StreamBuilder<List<SpendingBudget>>(
              stream: budgets,
              builder: (context, budgetSnapshot) {
                final list = budgetSnapshot.data ?? const <SpendingBudget>[];
                if (budgetSnapshot.hasError) {
                  return _InlineError(
                    message: 'Could not load budgets: ${budgetSnapshot.error}',
                  );
                }
                if (list.isEmpty) {
                  return const _EmptyCard(
                    icon: Icons.savings_outlined,
                    title: 'No budgets yet',
                    message: 'Set a monthly limit to keep spending on track.',
                  );
                }
                return Column(
                  children: list.take(3).map((budget) {
                    final spent = all
                        .where(
                          (item) =>
                              !item.isIncome &&
                              item.category == budget.category &&
                              item.date.year == now.year &&
                              item.date.month == now.month,
                        )
                        .fold<double>(0, (total, item) => total + item.amount);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BudgetTile(budget: budget, spent: spent),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => onNavigate(1),
                  child: const Text('View all'),
                ),
              ],
            ),
            if (snapshot.hasError)
              _InlineError(
                message: 'Could not load transactions: ${snapshot.error}',
              )
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (recent.isEmpty)
              const _EmptyCard(
                icon: Icons.receipt_long_outlined,
                title: 'A fresh start',
                message:
                    'Add your first transaction to see where your money goes.',
              )
            else
              ...recent.map(
                (item) => _TransactionTile(
                  transaction: item,
                  onEdit: () => _showTransactionEditor(context, item),
                  onDelete: () =>
                      _deleteTransaction(context, user.uid, item.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.income, required this.expenses});

  final double income;
  final double expenses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E805B), Color(0xFF15523E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THIS MONTH',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _money.format(income - expenses),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 23),
          Row(
            children: [
              Expanded(
                child: _BalanceStat(
                  label: 'Income',
                  amount: income,
                  icon: Icons.south_west_rounded,
                ),
              ),
              Expanded(
                child: _BalanceStat(
                  label: 'Spent',
                  amount: expenses,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({
    required this.label,
    required this.amount,
    required this.icon,
  });

  final String label;
  final double amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              _money.format(amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TransactionsPage extends StatelessWidget {
  const _TransactionsPage();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<List<MoneyTransaction>>(
      stream: _transactions(uid),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <MoneyTransaction>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 90),
          children: [
            Text('Activity', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text('A clear view of your money in and out.'),
            const SizedBox(height: 20),
            if (snapshot.hasError)
              _InlineError(
                message: 'Could not load transactions: ${snapshot.error}',
              )
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (items.isEmpty)
              const _EmptyCard(
                icon: Icons.receipt_long_outlined,
                title: 'No activity yet',
                message: 'Tap + to add income or an expense.',
              )
            else
              ...items.map(
                (item) => _TransactionTile(
                  transaction: item,
                  onEdit: () => _showTransactionEditor(context, item),
                  onDelete: () => _deleteTransaction(context, uid, item.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BudgetsPage extends StatelessWidget {
  const _BudgetsPage();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<List<SpendingBudget>>(
      stream: _budgets(uid),
      builder: (context, snapshot) {
        final budgets = snapshot.data ?? const <SpendingBudget>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Budgets',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Add budget',
                  onPressed: () => _showBudgetEditor(context),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Monthly limits that make every dollar count.'),
            const SizedBox(height: 20),
            if (snapshot.hasError)
              _InlineError(message: 'Could not load budgets: ${snapshot.error}')
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (budgets.isEmpty)
              const _EmptyCard(
                icon: Icons.savings_outlined,
                title: 'Give your spending a plan',
                message: 'Create a category budget to see how much you have left each month.',
              )
            else
              StreamBuilder<List<MoneyTransaction>>(
                stream: _transactions(uid),
                builder: (context, transactionSnapshot) {
                  final transactions =
                      transactionSnapshot.data ?? const <MoneyTransaction>[];
                  final now = DateTime.now();
                  return Column(
                    children: budgets.map((budget) {
                      final spent = transactions
                          .where(
                            (item) =>
                                !item.isIncome &&
                                item.category == budget.category &&
                                item.date.year == now.year &&
                                item.date.month == now.month,
                          )
                          .fold<double>(
                            0,
                            (total, item) => total + item.amount,
                          );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BudgetTile(
                          budget: budget,
                          spent: spent,
                          onDelete: () =>
                              _deleteBudget(context, uid, budget.id),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'MoneyWise member';
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: _mint,
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      user.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Sign out'),
          subtitle: const Text('Your data stays safely in your account'),
          onTap: () async {
            try {
              await FirebaseAuth.instance.signOut();
            } on FirebaseAuthException catch (error) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(_authError(error))));
            }
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'MoneyWise helps you track your own entries and plan your spending. It does not connect to your bank or provide financial advice.',
          style: TextStyle(fontSize: 12, color: Color(0xFF87938D)),
        ),
      ],
    );
  }
}

class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.isIncome,
    this.note = '',
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final bool isIncome;
  final String note;

  factory MoneyTransaction.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return MoneyTransaction(
      id: document.id,
      title: data['title'] as String? ?? 'Transaction',
      category: data['category'] as String? ?? 'Other',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isIncome: data['isIncome'] as bool? ?? false,
      note: data['note'] as String? ?? '',
    );
  }
}

class SpendingBudget {
  const SpendingBudget({
    required this.id,
    required this.category,
    required this.limit,
  });

  final String id;
  final String category;
  final double limit;

  factory SpendingBudget.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return SpendingBudget(
      id: document.id,
      category: data['category'] as String? ?? 'Other',
      limit: (data['limit'] as num?)?.toDouble() ?? 0,
    );
  }
}

Stream<List<MoneyTransaction>> _transactions(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('transactions')
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(MoneyTransaction.fromDocument).toList(),
      );
}

Stream<List<SpendingBudget>> _budgets(String uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('budgets')
      .orderBy('category')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(SpendingBudget.fromDocument).toList(),
      );
}

CollectionReference<Map<String, dynamic>> _transactionCollection(String uid) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('transactions');

Future<void> _deleteTransaction(
  BuildContext context,
  String uid,
  String id,
) async {
  try {
    await _transactionCollection(uid).doc(id).delete();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not delete transaction: $error')),
    );
  }
}

Future<void> _deleteBudget(BuildContext context, String uid, String id) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(id)
        .delete();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not delete budget: $error')));
  }
}

Future<void> _showTransactionEditor(
  BuildContext context, [
  MoneyTransaction? existing,
]) async {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController(text: existing?.title ?? '');
  final amountController = TextEditingController(
    text: existing == null ? '' : existing.amount.toString(),
  );
  final noteController = TextEditingController(text: existing?.note ?? '');
  var category = existing?.category ?? 'Food';
  var isIncome = existing?.isIncome ?? false;
  var date = existing?.date ?? DateTime.now();
  final uid = FirebaseAuth.instance.currentUser!.uid;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Add transaction' : 'Edit transaction'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Expense'),
                        icon: Icon(Icons.north_east),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Income'),
                        icon: Icon(Icons.south_west),
                      ),
                    ],
                    selected: {isIncome},
                    onSelectionChanged: (value) => setDialogState(() {
                      isIncome = value.first;
                      if (isIncome) category = 'Income';
                      if (!isIncome && category == 'Income') category = 'Food';
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    decoration: _inputDecoration(
                      'Description',
                      Icons.edit_outlined,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Add a description'
                        : value.trim().length > 100
                        ? 'Keep the description under 100 characters'
                        : null,
                    maxLength: 100,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _inputDecoration('Amount', Icons.attach_money),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');
                      return amount == null || amount <= 0
                          ? 'Enter an amount greater than zero'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: _inputDecoration(
                      'Category',
                      Icons.category_outlined,
                    ),
                    items:
                        (isIncome
                                ? const ['Income', 'Other']
                                : _categories.where((item) => item != 'Income'))
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => category = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    decoration: _inputDecoration(
                      'Note (optional)',
                      Icons.notes_outlined,
                    ),
                    maxLines: 2,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 366),
                          ),
                        );
                        if (selected != null) {
                          setDialogState(() => date = selected);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(DateFormat.yMMMd().format(date)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final data = {
                  'title': titleController.text.trim(),
                  'category': category,
                  'amount': double.parse(amountController.text),
                  'date': Timestamp.fromDate(date),
                  'isIncome': isIncome,
                  'note': noteController.text.trim(),
                };
                if (existing == null) {
                  await _transactionCollection(
                    uid,
                  ).add({...data, 'createdAt': FieldValue.serverTimestamp()});
                } else {
                  await _transactionCollection(uid)
                      .doc(existing.id)
                      .update(data);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not ${existing == null ? 'save' : 'update'} transaction: $error',
                    ),
                  ),
                );
              }
            },
            child: Text(existing == null ? 'Save' : 'Update'),
          ),
        ],
      ),
    ),
  );
  titleController.dispose();
  amountController.dispose();
  noteController.dispose();
}

Future<void> _showBudgetEditor(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final limitController = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;
  var category = 'Food';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Create a budget'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: _inputDecoration(
                  'Category',
                  Icons.category_outlined,
                ),
                items: _categories
                    .where((item) => item != 'Income')
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => category = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: limitController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDecoration(
                  'Monthly limit',
                  Icons.attach_money,
                ),
                validator: (value) {
                  final limit = double.tryParse(value ?? '');
                  return limit == null || limit <= 0
                      ? 'Enter a limit greater than zero'
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final reference = FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('budgets')
                    .doc(category);
                await reference.set({
                  'category': category,
                  'limit': double.parse(limitController.text),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Could not save budget: $error')),
                );
              }
            },
            child: const Text('Save budget'),
          ),
        ],
      ),
    ),
  );
  limitController.dispose();
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.budget, required this.spent, this.onDelete});

  final SpendingBudget budget;
  final double spent;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ratio = budget.limit <= 0
        ? 0.0
        : (spent / budget.limit).clamp(0.0, 1.0);
    final over = spent > budget.limit;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _CategoryIcon(category: budget.category, isIncome: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.category,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_money.format(spent)} of ${_money.format(budget.limit)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete budget',
                  onPressed: onDelete,
                  icon: const Icon(Icons.more_vert),
                ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFEDF1ED),
              color: over ? const Color(0xFFD05B4E) : _green,
            ),
          ),
          if (over)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Over budget by ${_money.format(spent - budget.limit)}',
                  style: const TextStyle(
                    color: Color(0xFFB5473B),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    this.onEdit,
    this.onDelete,
  });

  final MoneyTransaction transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 3,
          ),
          leading: _CategoryIcon(
            category: transaction.category,
            isIncome: transaction.isIncome,
          ),
          title: Text(
            transaction.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            '${transaction.category} · ${DateFormat.MMMd().format(transaction.date)}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${transaction.isIncome ? '+' : '−'}${_money.format(transaction.amount)}',
                style: TextStyle(
                  color: transaction.isIncome ? _green : _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: 'Transaction options',
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                  icon: const Icon(Icons.more_horiz, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category, required this.isIncome});

  final String category;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (category) {
      'Food' => (Icons.restaurant_outlined, const Color(0xFFEF9C58)),
      'Transport' => (Icons.directions_car_outlined, const Color(0xFF5C91D5)),
      'Shopping' => (Icons.shopping_bag_outlined, const Color(0xFFAF79CA)),
      'Bills' => (Icons.receipt_outlined, const Color(0xFFE17D74)),
      'Health' => (Icons.favorite_border, const Color(0xFFDF7593)),
      'Entertainment' => (Icons.movie_outlined, const Color(0xFF7F86CE)),
      'Income' => (Icons.south_west_rounded, _green),
      _ => (isIncome ? Icons.south_west_rounded : Icons.more_horiz, _green),
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Icon(
        Icons.account_balance_wallet_outlined,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _mint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _green),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF9B3932), fontSize: 13),
      ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: _green),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

InputDecoration _inputDecoration(String label, IconData icon) =>
    InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE8ECE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _green, width: 1.4),
      ),
    );

String _authError(FirebaseAuthException error) => switch (error.code) {
  'email-already-in-use' =>
    'An account already uses this email. Try signing in.',
  'invalid-email' => 'That email address is not valid.',
  'weak-password' => 'Choose a stronger password with at least 6 characters.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => 'Email or password is incorrect.',
  'too-many-requests' => 'Too many attempts. Wait a little and try again.',
  'network-request-failed' => 'Check your internet connection and try again.',
  _ => error.message ?? 'Authentication failed. Please try again.',
};

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'evening';
}
