import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/glass_text_field.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/utils/validators.dart';
import '../../../app/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;
  static const _pages = [
    _OnboardingPageData(
      icon: Icons.insights_rounded,
      eyebrow: 'KNOW YOUR MONEY',
      title: 'Track your spending',
      body: 'Record daily expenses and see where your money goes.',
      color: AppColors.teal,
    ),
    _OnboardingPageData(
      icon: Icons.pie_chart_outline_rounded,
      eyebrow: 'MAKE A PLAN',
      title: 'Build better budgets',
      body: 'Set simple limits and stay ahead of the month.',
      color: AppColors.violet,
    ),
    _OnboardingPageData(
      icon: Icons.savings_outlined,
      eyebrow: 'GROW WITH PURPOSE',
      title: 'Reach your goals',
      body: 'Create savings goals and celebrate your progress.',
      color: AppColors.amber,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('moneywise.onboardingComplete', true);
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _complete, child: const Text('Skip')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final item = _pages[index];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GlassContainer(
                      padding: EdgeInsets.zero,
                      radius: 34,
                      opacity: 0.4,
                      child: Container(
                        width: 246,
                        height: 246,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              item.color.withValues(alpha: 0.2),
                              item.color.withValues(alpha: 0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(item.icon, size: 102, color: item.color),
                            Positioned(
                              right: 35,
                              bottom: 40,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: item.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      item.eyebrow,
                      style: TextStyle(
                        color: item.color,
                        fontSize: 10,
                        letterSpacing: 1.7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(item.body, textAlign: TextAlign.center),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _index ? 21 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: index == _index
                      ? AppColors.tealDark
                      : AppColors.teal.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: _index == _pages.length - 1 ? 'Get started' : 'Next',
              icon: _index == _pages.length - 1 ? Icons.arrow_forward : null,
              onPressed: () {
                if (_index == _pages.length - 1) {
                  _complete();
                } else {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final Color color;
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message = 'Take Control of Your Money'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 92),
            const SizedBox(height: 16),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 5),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            const LoadingIndicator(),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().signIn(
        email: _email.text,
        password: _password.text,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('moneywise.rememberMe', _remember);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        showAppMessage(context, _friendlyAuthError(error), isError: true);
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(context, 'Could not sign in: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().signInWithGoogle();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        showAppMessage(context, _friendlyAuthError(error), isError: true);
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(context, 'Google sign-in failed: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 58)),
                    const SizedBox(height: 15),
                    Text(
                      'Welcome Back!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to continue',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    GlassTextField(
                      controller: _email,
                      label: 'Email address',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 12),
                    GlassTextField(
                      controller: _password,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscure,
                      validator: (value) =>
                          Validators.required(value, 'Password'),
                      suffix: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _remember,
                          visualDensity: VisualDensity.compact,
                          onChanged: (value) =>
                              setState(() => _remember = value ?? false),
                        ),
                        Text(
                          'Remember me',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.forgotPassword,
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ],
                    ),
                    GlassButton(
                      label: 'Login',
                      onPressed: _busy ? null : _signIn,
                      isLoading: _busy,
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GlassButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      outlined: true,
                      onPressed: _busy ? null : _googleSignIn,
                      compact: true,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.register),
                      child: const Text("Don't have an account? Register"),
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _currency = AppConstants.defaultCurrency;
  bool _obscure = true;
  bool _terms = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_terms) {
      showAppMessage(
        context,
        'Please accept the terms to continue.',
        isError: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().register(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
        phoneNumber: _phone.text,
        currencyCode: _currency,
      );
      if (mounted) {
        showAppMessage(
          context,
          'Account created. Verify your email when prompted.',
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        showAppMessage(context, _friendlyAuthError(error), isError: true);
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          'Could not create account: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 52)),
                    const SizedBox(height: 10),
                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Start your financial journey',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    GlassTextField(
                      controller: _name,
                      label: 'Full name',
                      icon: Icons.person_outline,
                      validator: (value) => Validators.required(value, 'Name'),
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: _email,
                      label: 'Email address',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: _phone,
                      label: 'Phone number (optional)',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(
                        labelText: 'Preferred currency',
                        prefixIcon: Icon(Icons.currency_exchange),
                      ),
                      items: AppConstants.supportedCurrencies.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text('${entry.key} · ${entry.value}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _currency = value ?? _currency),
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: _password,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscure,
                      validator: Validators.password,
                      suffix: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassTextField(
                      controller: _confirm,
                      label: 'Confirm password',
                      icon: Icons.lock_outline,
                      obscureText: _obscure,
                      validator: (value) => value != _password.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _terms,
                      onChanged: (value) =>
                          setState(() => _terms = value ?? false),
                      title: const Text(
                        'I agree to the Terms and Conditions',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    GlassButton(
                      label: 'Create Account',
                      onPressed: _busy ? null : _register,
                      isLoading: _busy,
                    ),
                    const SizedBox(height: 8),
                    GlassButton(
                      label: 'Sign up with Google',
                      icon: Icons.g_mobiledata_rounded,
                      outlined: true,
                      compact: true,
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await context
                                    .read<AuthService>()
                                    .signInWithGoogle();
                                if (mounted) {
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);
                                }
                              } catch (error) {
                                if (mounted) {
                                  showAppMessage(
                                    context,
                                    'Google sign-in failed: $error',
                                    isError: true,
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Already have an account? Login'),
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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        showAppMessage(context, _friendlyAuthError(error), isError: true);
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          'Could not send reset email: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassContainer(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 62),
                  const SizedBox(height: 17),
                  Text(
                    'Forgot Password',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sent
                        ? 'Check your inbox for a password reset link.'
                        : "Enter your email and we'll send you a reset link.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 19),
                  if (!_sent) ...[
                    GlassTextField(
                      controller: _email,
                      label: 'Email address',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        label: 'Send Reset Link',
                        onPressed: _busy ? null : _send,
                        isLoading: _busy,
                      ),
                    ),
                  ] else
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 50,
                      color: AppColors.teal,
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyAuthError(FirebaseAuthException error) => switch (error.code) {
  'email-already-in-use' => 'An account already uses this email address.',
  'invalid-email' => 'Enter a valid email address.',
  'weak-password' => 'Use a stronger password with at least 8 characters.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => 'Email or password is incorrect.',
  'too-many-requests' => 'Too many attempts. Wait a little and try again.',
  'network-request-failed' => 'Check your internet connection and try again.',
  _ => error.message ?? 'Authentication failed. Please try again.',
};
