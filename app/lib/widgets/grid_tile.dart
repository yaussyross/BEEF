import 'package:flutter/material.dart';

import '../models/grid_profile.dart';
import '../theme/beef_colors.dart';

/// One guy on the grid. An original BEEF tile — rounded char card with a
/// lime initial medallion, display name, bucketed distance label, and a single
/// intent tag — not anyone else's trade dress.
class GridTile extends StatelessWidget {
  const GridTile({super.key, required this.profile, required this.onTap});

  final GridProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String initial = _initial(profile.displayName);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: BeefColors.cream.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: profile.isVerified
                ? BeefColors.lime.withValues(alpha: 0.55)
                : BeefColors.cream.withValues(alpha: 0.12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Stack(
                alignment: Alignment.bottomRight,
                children: <Widget>[
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: BeefColors.berry,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: BeefColors.cream,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (profile.isVerified)
                    const _VerifiedDot(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                profile.displayLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: BeefColors.cream,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: BeefColors.sizzle,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      profile.distance,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BeefColors.sizzle,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (profile.intentTags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                _IntentPill(tag: profile.intentTags.first),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String? displayName) {
    if (displayName == null || displayName.isEmpty) return '?';
    return displayName.characters.first.toUpperCase();
  }
}

class _VerifiedDot extends StatelessWidget {
  const _VerifiedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: BeefColors.lime,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(2),
      child: const Icon(
        Icons.check,
        size: 12,
        color: BeefColors.char,
      ),
    );
  }
}

/// Single intent tag pill (first tag only on the tile; the full set lives on
/// the profile view).
class _IntentPill extends StatelessWidget {
  const _IntentPill({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: BeefColors.steak.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: BeefColors.steak.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        _label(tag),
        style: theme.textTheme.labelSmall?.copyWith(
          color: BeefColors.cream,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static String _label(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
