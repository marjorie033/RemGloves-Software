import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RoundedBody extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  const RoundedBody({
    super.key,
    required this.child,
    this.borderRadius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}