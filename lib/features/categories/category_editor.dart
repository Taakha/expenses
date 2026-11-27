import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_icons.dart';
import '../../core/services/finance_controller.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/glass_text_field.dart';

const categoryIconOptions = <String, IconData>{
  'food': AppIcons.catFood,
  'accommodation': AppIcons.catAccom,
  'transport': AppIcons.catTransport,
  'education': AppIcons.catEducation,
  'communication': AppIcons.catComms,
  'shopping': AppIcons.catShopping,
  'personal': AppIcons.catPersonal,
  'entertainment': AppIcons.catEntertain,
  'health': AppIcons.catHealth,
  'bills': AppIcons.catBills,
  'income': AppIcons.catSalary,
  'gift': AppIcons.catGift,
  'other': AppIcons.catOther,
};

IconData categoryIcon(String? key) =>
    categoryIconOptions[key] ?? AppIcons.category;

Future<String?> showCategoryEditor(
  BuildContext context, {
  Map<String, Object?>? existing,
  String initialType = 'expense',
}) async {
  final name = TextEditingController(text: existing?['name'] as String? ?? '');
  final formKey = GlobalKey<FormState>();
  var type = existing?['type'] as String? ?? initialType;
  final existingIcon = existing?['icon'] as String? ?? 'other';
  var icon = categoryIconOptions.containsKey(existingIcon)
      ? existingIcon
      : 'other';

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Add category' : 'Edit category'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassTextField(
                  controller: name,
                  label: 'Category name',
                  icon: AppIcons.category,
                  validator: (value) =>
                      Validators.required(value, 'Category name'),
                ),
                const SizedBox(height: 12),
                if (existing == null)
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'expense',
                        child: Text('Expense'),
                      ),
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                    ],
                    onChanged: (value) => setState(() => type = value ?? type),
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Type'),
                    child: Text(type == 'income' ? 'Income' : 'Expense'),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: icon,
                  decoration: const InputDecoration(labelText: 'Icon'),
                  items: categoryIconOptions.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(entry.value),
                              const SizedBox(width: 9),
                              Text(
                                entry.key[0].toUpperCase() +
                                    entry.key.substring(1),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => icon = value ?? icon),
                ),
              ],
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
                final id = await context.read<FinanceController>().saveCategory(
                  id: existing?['id'] as String?,
                  name: name.text.trim(),
                  type: type,
                  icon: icon,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, id);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
            child: Text(existing == null ? 'Add category' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  return result;
}
