import 'package:flutter/material.dart';

import '../../theme/beef_colors.dart';
import '../../widgets/beef_wordmark.dart';
import '../../widgets/brand_button.dart';

/// Mandatory, non-skippable 18+ gate. Enforces age >= 18 client-side BEFORE any
/// network call; the backend re-checks at `/api/register` (and a DB trigger).
class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({
    super.key,
    required this.onContinue,
    required this.onHaveAccount,
  });

  /// Called with a validated ISO `YYYY-MM-DD` birthdate when the user is 18+.
  final void Function(String birthdate) onContinue;

  /// "Already on the grill?" → switch to login.
  final VoidCallback onHaveAccount;

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  DateTime? _birthdate;
  String? _error;

  Future<void> _pickBirthdate() async {
    final DateTime today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(today.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'When were you born?',
    );
    if (picked == null) return;
    setState(() {
      _birthdate = picked;
      _error = null;
    });
  }

  void _submit() {
    final DateTime? birthdate = _birthdate;
    if (birthdate == null) {
      setState(() {
        _error = 'Tell us your birthdate first — no exceptions.';
      });
      return;
    }
    if (!_isAdult(birthdate)) {
      setState(() {
        _error =
            'BEEF is a strictly 18+ space. Come back when you are of age — '
            'we will keep a seat warm.';
      });
      return;
    }
    widget.onContinue(_isoDate(birthdate));
  }

  static bool _isAdult(DateTime birthdate) {
    final DateTime today = DateTime.now();
    int age = today.year - birthdate.year;
    if (today.month < birthdate.month ||
        (today.month == birthdate.month && today.day < birthdate.day)) {
      age -= 1;
    }
    return age >= 18;
  }

  static String _isoDate(DateTime d) {
    final String mm = d.month.toString().padLeft(2, '0');
    final String dd = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: <Widget>[
              const Spacer(),
              const BeefWordmark(compact: true),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: BeefColors.steak, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '18+',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: BeefColors.steak,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Prove you are legal.',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'BEEF is a strictly 18+ space, no exceptions and no skipping. '
                'Your birthdate stays private — we only use it to keep the '
                'room adults-only.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: BeefColors.cream.withValues(alpha: 0.75),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _pickBirthdate,
                icon: const Icon(Icons.cake_outlined),
                label: Text(
                  _birthdate == null
                      ? 'Choose your birthdate'
                      : _prettyDate(_birthdate!),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BeefColors.cream,
                  side: const BorderSide(color: BeefColors.sizzle, width: 2),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: BeefColors.sizzle,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              BrandButton(
                label: "I'm 18 or older",
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onHaveAccount,
                child: const Text('Already on the grill? Sign in'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  static String _prettyDate(DateTime d) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
