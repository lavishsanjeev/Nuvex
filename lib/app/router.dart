import 'package:flutter/material.dart';

/// Central route names for Nuvex.
abstract class NuvexRoutes {
  static const String initial = '/';
  static const String gettingStarted = '/getting-started';
  static const String credentials = '/credentials';
  static const String home = '/home';
}

/// Simple declarative navigation route generator.
abstract class NuvexRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case NuvexRoutes.initial:
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const _PlaceholderLandingPage(),
        );
    }
  }
}

/// Baseline starter landing page for Phase 1.
class _PlaceholderLandingPage extends StatelessWidget {
  const _PlaceholderLandingPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.cloud_outlined,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nuvex',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your files, your space.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Getting Started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
