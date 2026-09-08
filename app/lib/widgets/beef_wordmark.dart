import 'package:flutter/material.dart';

import '../theme/beef_colors.dart';

/// The BEEF wordmark + tagline, reused across splash/onboarding/home.
class BeefWordmark extends StatelessWidget {
  const BeefWordmark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'BEEF',
          style: (compact
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.displayLarge)
              ?.copyWith(
            color: BeefColors.cream,
            fontWeight: FontWeight.w900,
            letterSpacing: compact ? 2 : 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A cut above the rest.',
          style: theme.textTheme.titleLarge?.copyWith(
            color: BeefColors.cream.withValues(alpha: 0.9),
            fontStyle: FontStyle.italic,
          ),
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            '(well-marbled, obviously)',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: BeefColors.lime,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
