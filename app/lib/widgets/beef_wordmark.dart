import 'package:flutter/material.dart';

import '../theme/beef_colors.dart';

/// The Otter Wink wordmark + tagline, reused across splash/onboarding/home.
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
          'Otter Wink',
          textAlign: TextAlign.center,
          style: (compact
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.displayLarge)
              ?.copyWith(
            color: BeefColors.cream,
            fontWeight: FontWeight.w900,
            letterSpacing: compact ? 0 : 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Make a connection.',
          style: theme.textTheme.titleLarge?.copyWith(
            color: BeefColors.cream.withValues(alpha: 0.9),
            fontStyle: FontStyle.italic,
          ),
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            '(a wink is a good start)',
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
