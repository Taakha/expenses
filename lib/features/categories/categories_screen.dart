import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/finance_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/screen_header.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _type = 'expense';

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final categories = finance.categories
        .where(
          (category) =>
              category['type'] == _type &&
              (category['is_active'] as int? ?? 1) == 1,
        )
        .toList();
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 26),
        children: [
          ScreenHeader(
            title: 'Categories',
            subtitle: 'Keep transactions easy to organize.',
            trailing: IconButton.filled(
              tooltip: 'Add category',
              onPressed: () => _addCategory(context),
              icon: const Icon(Icons.add_rounded),
            ),
            showBack: true,
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'expense',
                label: Text('Expenses'),
                icon: Icon(Icons.north_east_rounded),
              ),
              ButtonSegment(
                value: 'income',
                label: Text('Income'),
                icon: Icon(Icons.south_west_rounded),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) =>
                setState(() => _type = selection.first),
          ),
          const SizedBox(height: 11),
          if (categories.isEmpty)
            const GlassEmptyState(
              title: 'No categories',
              message: 'Add a category to organize your financial activity.',
              icon: Icons.category_outlined,
            )
          else
            ...categories.map((category) {
              final isDefault = (category['is_default'] as int? ?? 0) == 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: GlassContainer(
                  padding: EdgeInsets.zero,
                  radius: 16,
                  blur: 6,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.teal.withValues(alpha: 0.13),
                      child: const Icon(Icons.sell_outlined, color: AppColors.tealDark),
                    ),
                    title: Text(category['name']! as String),
                    subtitle: Text(isDefault ? 'Built-in category' : 'Custom category'),
                    trailing: isDefault
                        ? null
                        : IconButton(
                            tooltip: 'Archive category',
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                            onPressed: () => _archiveCategory(
                              context,
                              category['id']! as String,
                              category['name']! as String,
                            ),
                          ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 6),
          GlassContainer(
            padding: const EdgeInsets.all(12),
            radius: 15,
            blur: 5,
            child: Text(
              'Archived categories stay on historical transactions but are no longer available for new entries.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _addCategory(BuildContext context) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var type = 'expense';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassTextField(
                controller: controller,
                label: 'Category name',
                icon: Icons.sell_outlined,
                validator: (value) => Validators.required(value, 'Category name'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {type},
                onSelectionChanged: (selection) => setState(() => type = selection.first),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await context.read<FinanceController>().saveCategory(
                  name: controller.text.trim(),
                  type: type,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) showAppMessage(context, 'Category added.');
              } catch (error) {
                if (dialogContext.mounted) showAppMessage(dialogContext, error.toString(), isError: true);
              }
            },
            child: const Text('Add category'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

Future<void> _archiveCategory(
  BuildContext context,
  String id,
  String name,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Archive $name?',
    message: 'Existing transactions in this category will remain unchanged.',
    confirmLabel: 'Archive',
  );
  if (!confirmed || !context.mounted) return;
  try {
    await context.read<FinanceController>().archiveCategory(id);
    if (context.mounted) showAppMessage(context, 'Category archived.');
  } catch (error) {
    if (context.mounted) showAppMessage(context, error.toString(), isError: true);
  }
}
