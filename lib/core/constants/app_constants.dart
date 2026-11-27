import 'package:flutter/material.dart';

import 'app_icons.dart';
import '../theme/app_colors.dart';

class AppConstants {
  const AppConstants._();

  static const appName = 'Money Wise';
  static const tagline = 'Take Control of Your Money';
  static const defaultCurrency = 'UGX';

  static const supportedCurrencies = <String, String>{
    'UGX': 'Ugandan Shilling',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'KES': 'Kenyan Shilling',
    'TZS': 'Tanzanian Shilling',
    'NGN': 'Nigerian Naira',
    'ZAR': 'South African Rand',
  };

  static const incomeCategories = <String>[
    'Salary',
    'Business',
    'Allowance',
    'Scholarship',
    'Freelance',
    'Gift',
    'Other income',
  ];

  static const expenseCategories = <String>[
    'Food',
    'Accommodation',
    'Transport',
    'Education',
    'Communication',
    'Shopping',
    'Personal care',
    'Entertainment',
    'Health',
    'Bills',
    'Other',
  ];

  static const accountTypes = <String>[
    'Cash',
    'Mobile Money',
    'Bank',
    'Savings',
    'Other',
  ];

  static const paymentMethods = <String>[
    'Cash',
    'Bank transfer',
    'Mobile Money',
    'Card',
    'Other',
  ];
}

/// Provides the Bootstrap icon and teal-palette colour for a category name.
class CategoryStyle {
  const CategoryStyle(this.icon, this.color);

  final IconData icon;
  final Color color;

  static CategoryStyle forName(String name, {bool income = false}) {
    final icon = AppIcons.forCategory(name, income: income);
    final color = switch (name.toLowerCase()) {
      'salary' ||
      'allowance' ||
      'allowances' ||
      'business' ||
      'freelance' => AppColors.income,
      'scholarship' => AppColors.accent,
      'gift' => AppColors.tealDark,
      'food' || 'groceries' => AppColors.amber,
      'accommodation' || 'rent' => AppColors.tealDark,
      'transport' => AppColors.teal,
      'education' => AppColors.accent,
      'communication' => AppColors.tealDark,
      'shopping' => AppColors.expense,
      'health' || 'personal care' => AppColors.expense,
      'entertainment' => AppColors.accent,
      'bills' => AppColors.amber,
      _ => AppColors.teal,
    };
    return CategoryStyle(icon, color);
  }
}
