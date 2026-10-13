// Responsive helpers shared by all screens.
import 'package:flutter/material.dart';

/// Columns count from available width (phones → 2, tablets → 3-4, desktop → up to 6).
int responsiveColumns(double maxWidth, {double tileMinWidth = 180}) {
  return (maxWidth / tileMinWidth).floor().clamp(2, 6);
}

/// Constrains wide layouts (web/desktop) to a readable max width, centered.
class CenteredConstrained extends StatelessWidget {
  const CenteredConstrained({
    super.key,
    required this.child,
    this.maxWidth = 520,
    this.padding = const EdgeInsets.symmetric(horizontal: 30),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
