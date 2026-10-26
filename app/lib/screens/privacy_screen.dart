import 'package:flutter/material.dart';

import '../api/http_client.dart';
import '../api/privacy_api.dart';
import '../auth/auth_scope.dart';
import '../config/api_config.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key, this.api});
  final PrivacyApi? api;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  PrivacyApi? _api;
  ApiClient? _ownedClient;
  String? _mode;
  bool _hide = false;
  bool _loading = true;
  bool _saving = false;
  bool _disabled = false;
  String? _error;
  String? _confirmation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api != null) return;
    if (widget.api != null) {
      _api = widget.api;
    } else {
      _ownedClient = ApiClient(baseUrl: ApiConfig.baseUrl,
        tokenStore: AuthScope.read(context).tokenStore);
      _api = PrivacyApi(_ownedClient!);
    }
    _load();
  }

  @override
  void dispose() { _ownedClient?.close(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final settings = await _api!.load();
      if (mounted) setState(() { _mode = settings.mode; _hide = settings.hideDistance; });
    } catch (error) {
      if (mounted) setState(() {
        _mode = null;
        _error = error is ApiException ? error.message : 'Could not load privacy settings. Try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _disabled || _mode == null) return;
    setState(() { _saving = true; _error = null; _confirmation = null; });
    try {
      final settings = await _api!.save(_mode!, _hide);
      if (mounted) setState(() {
        _mode = settings.mode; _hide = settings.hideDistance;
        _confirmation = 'Privacy settings saved.';
      });
    } catch (error) {
      if (mounted) setState(() {
        _error = error is ApiException ? error.message : 'Could not confirm your changes. Try again.';
        _disabled = error is ApiException && error.code == 'account_disabled';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy settings')),
    body: SafeArea(child: _loading ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(24), children: [
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (_confirmation != null) Semantics(liveRegion: true, child: Text(_confirmation!)),
        if (_mode == null)
          OutlinedButton(onPressed: _load, child: const Text('Retry'))
        else ...[
          const Text('Location precision'),
          DropdownButton<String>(value: _mode, isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'city', child: Text('City — approximate')),
              DropdownMenuItem(value: 'region', child: Text('Region — broader area')),
              DropdownMenuItem(value: 'exact', child: Text('Exact — opt in')),
            ],
            onChanged: _saving || _disabled ? null : (value) => setState(() { _mode = value; _confirmation = null; }),
          ),
          const Text('Exact mode uses your precise location for discovery and can show distance rounded to 0.1 miles. Your coordinates are not sent to other users.'),
          SwitchListTile(contentPadding: EdgeInsets.zero,
            title: const Text('Hide my distance'), value: _hide,
            subtitle: const Text('Show “nearby” instead of a distance.'),
            onChanged: _saving || _disabled ? null : (value) => setState(() { _hide = value; _confirmation = null; }),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving || _disabled ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save privacy settings')),
        ],
      ])),
  );
}
