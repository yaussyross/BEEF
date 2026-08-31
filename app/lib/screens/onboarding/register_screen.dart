import 'package:flutter/material.dart';

import '../../api/http_client.dart';
import '../../auth/auth_scope.dart';
import '../../theme/beef_colors.dart';
import '../../widgets/beef_wordmark.dart';
import '../../widgets/brand_button.dart';

/// Email/password registration. Receives the already-validated birthdate from
/// the age gate and submits it with the credentials to `/api/register`.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.birthdate,
    required this.onBack,
    required this.onHaveAccount,
  });

  final String birthdate;
  final VoidCallback onBack;
  final VoidCallback onHaveAccount;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthScope.read(context).register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        birthdate: widget.birthdate,
      );
      // On success AuthGate swaps to HomeScreen; nothing else to do here.
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error =
              'Could not reach the grill. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const BeefWordmark(compact: true),
                const SizedBox(height: 28),
                Text('Get on the grill.', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Create your cut. Your birthdate is locked in and kept private.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: BeefColors.cream.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (String? value) {
                    final String v = (value ?? '').trim();
                    if (v.isEmpty) return 'Email is required.';
                    if (!_emailRe.hasMatch(v)) {
                      return 'That email does not look right. Try again?';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'At least 8 characters',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (String? value) {
                    final String v = value ?? '';
                    if (v.isEmpty) return 'Password is required.';
                    if (v.length < 8) {
                      return 'Password must be at least 8 characters.';
                    }
                    if (v.length > 128) {
                      return 'Password must be at most 128 characters.';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: BeefColors.sizzle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                BrandButton(
                  label: 'Create my cut',
                  loading: _submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onHaveAccount,
                  child: const Text('Already on the grill? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
