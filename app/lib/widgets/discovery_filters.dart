import 'package:flutter/material.dart';

import '../discovery/discovery_controller.dart' show DiscoveryInterests;
import '../models/intent_tag.dart';
import '../theme/beef_colors.dart';

/// Intent-tag filter chips (All + Friends·Chat·Date·Hookup) feeding the
/// server-side `intent` query param, plus the "A Plate of Mates" friends-only
/// lane toggle and the "The Menu" interest chips row.
class DiscoveryFilters extends StatelessWidget {
  const DiscoveryFilters({
    super.key,
    required this.selectedIntent,
    required this.matesOnly,
    required this.selectedInterests,
    required this.onIntent,
    required this.onMates,
    required this.onInterest,
  });

  final String? selectedIntent;
  final bool matesOnly;
  final Set<String> selectedInterests;
  final ValueChanged<IntentTag?> onIntent;
  final ValueChanged<bool> onMates;
  final ValueChanged<String> onInterest;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _FilterChip(
                label: 'All',
                selected: selectedIntent == null,
                onTap: () => onIntent(null),
              ),
              for (final IntentTag tag in IntentTag.values)
                _FilterChip(
                  label: tag.label,
                  selected: selectedIntent == tag.value,
                  onTap: () => onIntent(tag),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'The Menu — find your flavour',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: BeefColors.cream.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            _MatesToggle(value: matesOnly, onChanged: onMates),
          ],
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final InterestOption option in DiscoveryInterests.all)
                _InterestChip(
                  label: option.label,
                  selected: selectedInterests.contains(option.slug),
                  onTap: () => onInterest(option.slug),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: BeefColors.steak,
        backgroundColor: BeefColors.cream.withValues(alpha: 0.08),
        labelStyle: TextStyle(
          color: selected
              ? BeefColors.cream
              : BeefColors.cream.withValues(alpha: 0.75),
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: selected
                ? BeefColors.steak
                : BeefColors.cream.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('#$label'),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: BeefColors.berry.withValues(alpha: 0.55),
        backgroundColor: BeefColors.cream.withValues(alpha: 0.08),
        labelStyle: TextStyle(
          color: selected
              ? BeefColors.cream
              : BeefColors.cream.withValues(alpha: 0.75),
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: selected
                ? BeefColors.berry
                : BeefColors.cream.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}

/// "A Plate of Mates" — the friends-only lane toggle. Friendly copy, backed by
/// `intent=friends` on the grid request.
class _MatesToggle extends StatelessWidget {
  const _MatesToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: value
              ? BeefColors.lime.withValues(alpha: 0.2)
              : BeefColors.cream.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: value
                ? BeefColors.lime
                : BeefColors.cream.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              value ? Icons.group : Icons.group_outlined,
              size: 16,
              color: value
                  ? BeefColors.lime
                  : BeefColors.cream.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'A Plate of Mates',
              style: theme.textTheme.labelMedium?.copyWith(
                color: value
                    ? BeefColors.lime
                    : BeefColors.cream.withValues(alpha: 0.7),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
