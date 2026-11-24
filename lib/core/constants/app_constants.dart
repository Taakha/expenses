import 'package:flutter/material.dart';

import 'app_icons.dart';
import '../theme/app_colors.dart';

class AppConstants {
  const AppConstants._();

  static const appName         = 'Money Wise';
  static const tagline         = 'Take Control of Your Money';
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
  final Color    color;

  static CategoryStyle forName(String name, {bool income = false}) {
    final icon = AppIcons.forCategory(name, income: income);
    final color = switch (name.toLowerCase()) {
      'salary' || 'allowance' || 'allowances' || 'business' || 'freelance'
                              => const Color(0xFF31C99A),
      'scholarship'           => const Color(0xFF48C6D9),
      'gift'                  => const Color(0xFFF579B9),
      'food' || 'groceries'   => const Color(0xFFFFB85C),
      'accommodation' || 'rent' => const Color(0xFF9B8AFB),
      'transport'             => const Color(0xFF62B5F8),
      'education'             => const Color(0xFF48C6D9),
      'communication'         => const Color(0xFF71A7FF),
      'shopping'              => const Color(0xFFF579B9),
      'health' || 'personal care' => const Color(0xFFF17E83),
      'entertainment'         => const Color(0xFFBB8AF5),
      'bills'                 => const Color(0xFFF89D6B),
      _                       => AppColors.teal,
    };
    return CategoryStyle(icon, color);
  }
}
