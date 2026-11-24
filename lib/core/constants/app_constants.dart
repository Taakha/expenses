import 'package:flutter/material.dart';

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

class CategoryStyle {
  const CategoryStyle(this.icon, this.color);

  final IconData icon;
  final Color color;

  static CategoryStyle forName(String name, {bool income = false}) {
    return switch (name.toLowerCase()) {
      'salary' || 'income' => const CategoryStyle(
        Icons.account_balance_wallet_outlined,
        Color(0xFF31C99A),
      ),
      'food' || 'groceries' => const CategoryStyle(
        Icons.restaurant_outlined,
        Color(0xFFFFB85C),
      ),
      'accommodation' || 'rent' => const CategoryStyle(
        Icons.home_work_outlined,
        Color(0xFF9B8AFB),
      ),
      'transport' => const CategoryStyle(
        Icons.directions_car_outlined,
        Color(0xFF62B5F8),
      ),
      'education' => const CategoryStyle(
        Icons.menu_book_outlined,
        Color(0xFF48C6D9),
      ),
      'communication' => const CategoryStyle(
        Icons.wifi_rounded,
        Color(0xFF71A7FF),
      ),
      'shopping' => const CategoryStyle(
        Icons.shopping_bag_outlined,
        Color(0xFFF579B9),
      ),
      'health' || 'personal care' => const CategoryStyle(
        Icons.favorite_border,
        Color(0xFFF17E83),
      ),
      'entertainment' => const CategoryStyle(
        Icons.movie_outlined,
        Color(0xFFBB8AF5),
      ),
      'bills' => const CategoryStyle(
        Icons.receipt_long_outlined,
        Color(0xFFF89D6B),
      ),
      _ => CategoryStyle(
        income ? Icons.south_west_rounded : Icons.more_horiz_rounded,
        const Color(0xFF69C9A6),
      ),
    };
  }
}
