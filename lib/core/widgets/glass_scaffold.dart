import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    required this.child,
    super.key,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.safeArea = true,
    this.resizeToAvoidBottomInset,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final bool safeArea;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gradient = dark ? AppColors.darkGradient : AppColors.lightGradient;
    final content = Padding(padding: padding, child: child);
    return Scaffold(
      backgroundColor: dark ? AppColors.darkCanvas : AppColors.lightCanvas,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          children: [
            const Positioned(
              top: -72,
              right: -60,
              child: _AmbientGlow(size: 210, color: Color(0xFF42D4BD)),
            ),
            Positioned(
              bottom: -96,
              left: -72,
              child: _AmbientGlow(
                size: 240,
                color: dark ? const Color(0xFF287C96) : const Color(0xFF95B8F4),
              ),
            ),
            safeArea
                ? SafeArea(top: appBar == null, bottom: false, child: content)
                : content,
          ],
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}
