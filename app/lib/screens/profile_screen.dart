import 'package:flutter/material.dart';

import '../api/discovery_api.dart';
import '../api/http_client.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_scope.dart';
import '../config/api_config.dart';
import '../models/public_profile.dart';
import '../theme/beef_colors.dart';

/// Another guy's profile (`GET /api/profile/:id`).
///
/// Privacy invariants (enforced server-side, respected here): renders display
/// name, bio, intent tags, interests, verification badge, and `age_bucket`
/// only. NEVER a birthdate and NEVER any location — the API does not even
/// return them, and this screen has no fields for them.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  PublicProfile? _profile;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Read the session without subscribing (event handler, not build).
      final AuthController auth = AuthScope.read(context);
      final ApiClient client = ApiClient(
        baseUrl: ApiConfig.baseUrl,
        tokenStore: auth.tokenStore,
      );
      final PublicProfile profile =
          await DiscoveryApi(client).profile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.displayName ?? 'PROFILE'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: BeefColors.lime),
              )
            : _error != null
                ? _ProfileError(message: _error, onRetry: _load)
                : _profile == null
                    ? _ProfileError(
                        message: 'Profile not found.',
                        onRetry: _load,
                      )
                    : _ProfileBody(
                        profile: _profile!,
                        theme: theme,
                      ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.person_off_outlined,
              size: 56,
              color: BeefColors.sizzle,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not carve that profile.',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Give it another go.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BeefColors.cream.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile, required this.theme});

  final PublicProfile profile;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final String initial = _initial(profile.displayName);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: <Widget>[
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: <Widget>[
              CircleAvatar(
                radius: 56,
                backgroundColor: BeefColors.berry,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: BeefColors.cream,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (profile.photoVerificationStatus == 'verified')
                Container(
                  decoration: const BoxDecoration(
                    color: BeefColors.lime,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.check,
                    size: 20,
                    color: BeefColors.char,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                profile.displayName?.isNotEmpty == true
                    ? profile.displayName!
                    : 'Fresh cut',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (profile.photoVerificationStatus == 'verified') ...<Widget>[
              const SizedBox(width: 8),
              const _CertifiedCutBadge(),
            ],
          ],
        ),
        if (profile.ageBucket != null) ...<Widget>[
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Age ${profile.ageBucket}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BeefColors.cream.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (profile.intentTags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String tag in profile.intentTags)
                _TagPill(label: _capitalise(tag)),
            ],
          ),
        ],
        if (profile.bio?.isNotEmpty == true) ...<Widget>[
          const SizedBox(height: 24),
          Text(
            'ON THE MENU',
            style: theme.textTheme.labelLarge?.copyWith(
              color: BeefColors.sizzle,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.bio!,
            style: theme.textTheme.bodyLarge,
          ),
        ],
        if (profile.interests.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          Text(
            'INTO',
            style: theme.textTheme.labelLarge?.copyWith(
              color: BeefColors.sizzle,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final interest in profile.interests)
                _TagPill(label: '#${interest.label}', berry: true),
            ],
          ),
        ],
      ],
    );
  }

  static String _initial(String? displayName) {
    if (displayName == null || displayName.isEmpty) return '?';
    return displayName.characters.first.toUpperCase();
  }

  static String _capitalise(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

/// "Certified Cut" — the photo-verification badge from the feature pack.
class _CertifiedCutBadge extends StatelessWidget {
  const _CertifiedCutBadge();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: BeefColors.lime.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: BeefColors.lime),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.verified,
            size: 14,
            color: BeefColors.lime,
          ),
          const SizedBox(width: 4),
          Text(
            'Certified Cut',
            style: theme.textTheme.labelSmall?.copyWith(
              color: BeefColors.lime,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, this.berry = false});

  final String label;
  final bool berry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color base = berry ? BeefColors.berry : BeefColors.steak;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: base.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: BeefColors.cream,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
