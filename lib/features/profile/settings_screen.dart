import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/finance_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/screen_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final String _email;
  late String _currency;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _name = TextEditingController(text: user?.displayName ?? '');
    _phone = TextEditingController(text: user?.phoneNumber ?? '');
    _email = user?.email ?? '';
    _currency = context.read<FinanceController>().preferredCurrency;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().updateProfile(
        fullName: _name.text.trim(),
        phoneNumber: _phone.text.trim(),
        currencyCode: _currency,
      );
      await context.read<FinanceController>().setCurrency(_currency);
      if (mounted) showAppMessage(context, 'Profile updated.');
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final finance = context.watch<FinanceController>();
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 26),
        children: [
          const ScreenHeader(
            title: 'Settings',
            subtitle: 'Make Money Wise work for you.',
            showBack: true,
          ),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            radius: 20,
            blur: 8,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Profile details', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  GlassTextField(
                    controller: _name,
                    label: 'Full name',
                    icon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => Validators.required(value, 'Full name'),
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(
                    initialValue: _email,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    readOnly: true,
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: _phone,
                    label: 'Phone number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: AppConstants.supportedCurrencies.containsKey(_currency)
                        ? _currency
                        : 'UGX',
                    decoration: const InputDecoration(labelText: 'Preferred currency'),
                    items: AppConstants.supportedCurrencies.entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text('${entry.key} · ${entry.value}'),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _currency = value ?? _currency),
                  ),
                  const SizedBox(height: 13),
                  GlassButton(
                    label: 'Save profile',
                    onPressed: _busy ? null : _saveProfile,
                    isLoading: _busy,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            radius: 20,
            blur: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 9),
                DropdownButtonFormField<AppThemeMode>(
                  initialValue: theme.mode,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: const [
                    DropdownMenuItem(value: AppThemeMode.system, child: Text('Use device setting')),
                    DropdownMenuItem(value: AppThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(value: AppThemeMode.dark, child: Text('Dark')),
                  ],
                  onChanged: (value) {
                    if (value != null) theme.setMode(value);
                  },
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(Icons.cloud_sync_outlined, color: AppColors.tealDark),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cloud synchronization', style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '${finance.syncState.name} · ${finance.pendingSyncCount} pending',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sync now',
                      onPressed: finance.syncNow,
                      icon: const Icon(Icons.sync_rounded),
                    ),
                  ],
                ),
                if (finance.syncError != null)
                  Text(finance.syncError!, style: const TextStyle(color: AppColors.expense, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 11),
          GlassContainer(
            padding: const EdgeInsets.all(13),
            radius: 16,
            blur: 5,
            child: Text(
              'Money Wise stores financial records locally first. Your ledger remains usable offline and syncs when connectivity returns.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
