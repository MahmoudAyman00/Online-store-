import 'package:flutter/material.dart';
import 'theme.dart';

/// Shared stateless UI pieces: loading / empty / error + entrance animation.
/// Using them everywhere is what makes the app feel like ONE product.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class AppEmpty extends StatelessWidget {
  const AppEmpty({super.key, required this.message, this.icon = Icons.inbox});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: context.line),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  fontSize: 16, color: context.muted)),
        ],
      ),
    );
  }
}

class AppError extends StatelessWidget {
  const AppError({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 64, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  fontSize: 16, color: context.muted)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Subtle staggered fade+slide entrance for list/grid items.
/// Purely visual — never affects layout or logic.
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration(milliseconds: (widget.index * 60).clamp(0, 600)),
      () {
        if (mounted) setState(() => _visible = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
