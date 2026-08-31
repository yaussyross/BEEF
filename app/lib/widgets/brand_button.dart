import 'package:flutter/material.dart';

import '../theme/beef_colors.dart';

/// Primary BEEF call-to-action with an inline loading state.
class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.accent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Lime-on-char secondary style; defaults to the steak-red primary.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: accent
            ? FilledButton.styleFrom(
                backgroundColor: BeefColors.lime,
                foregroundColor: BeefColors.char,
              )
            : null,
        child: loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accent ? BeefColors.char : BeefColors.cream,
                ),
              )
            : Text(label),
      ),
    );
  }
}
