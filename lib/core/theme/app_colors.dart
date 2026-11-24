import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const teal = Color(0xFF0BA98D);
  static const tealDark = Color(0xFF087E70);
  static const tealDeep = Color(0xFF064B4C);
  static const aqua = Color(0xFF8DE9D7);
  static const seafoam = Color(0xFFB8F4E9);
  static const mint = Color(0xFFE0F8F1);
  static const coral = Color(0xFFFF777C);
  static const amber = Color(0xFFFFC46B);
  static const violet = Color(0xFF8C84F7);
  static const income = Color(0xFF168A67);
  static const expense = Color(0xFFE05F68);
  static const lightText = Color(0xFF6D8885);
  static const lightTextStrong = Color(0xFF264D4B);
  static const darkText = Color(0xFFEAF7F4);
  static const darkMuted = Color(0xFFA8C4BF);
  static const lightCanvas = Color(0xFFEAF8F6);
  static const darkCanvas = Color(0xFF071F23);

  static const lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE5FBF6), Color(0xFFCDF3EC), Color(0xFFEFF6FC)],
  );
  static const darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF052A2C), Color(0xFF0B3B40), Color(0xFF10283A)],
  );
}
