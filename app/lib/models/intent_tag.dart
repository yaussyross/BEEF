/// The four intent tags — mirrors the backend's `INTENT_TAGS` constant in
/// `src/lib/privacy.ts`. Used by later slices (grid filters, profile editing);
/// the wire format is the plain lowercase string in `value`.
enum IntentTag {
  friends('friends', 'Friends'),
  chat('chat', 'Chat'),
  date('date', 'Date'),
  hookup('hookup', 'Hookup');

  const IntentTag(this.value, this.label);

  /// The on-the-wire value (`friends`, `chat`, `date`, `hookup`).
  final String value;

  /// Human-facing label for UI chips.
  final String label;

  static IntentTag? fromValue(String value) {
    for (final IntentTag tag in IntentTag.values) {
      if (tag.value == value) return tag;
    }
    return null;
  }
}
