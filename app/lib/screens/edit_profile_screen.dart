import 'package:flutter/material.dart';
import '../api/http_client.dart';
import '../api/profile_api.dart';
import '../auth/auth_scope.dart';
import '../config/api_config.dart';
import '../discovery/discovery_controller.dart' show DiscoveryInterests;
import '../models/intent_tag.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.api});
  final ProfileApi? api;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}
class _EditProfileScreenState extends State<EditProfileScreen> {
  ProfileApi? _api;
  ApiClient? _client;
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _tags = <String>{};
  final _interests = <String>{};
  bool _loading = true, _loaded = false, _busy = false, _disabled = false;
  String? _error, _confirmation;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api != null) return;
    _api = widget.api;
    if (_api == null) {
      _client = ApiClient(baseUrl: ApiConfig.baseUrl, tokenStore: AuthScope.read(context).tokenStore);
      _api = ProfileApi(_client!);
    }
    _load();
  }
  @override
  void dispose() { _name.dispose(); _bio.dispose(); _client?.close(); super.dispose(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await _api!.load();
      if (!mounted) return;
      _name.text = p.displayName ?? ''; _bio.text = p.bio ?? '';
      _tags.addAll(p.intentTags); _interests.addAll(p.interests.map((i) => i.slug));
      _loaded = true;
    } catch (e) { _failed(e); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  void _failed(Object e) {
    if (!mounted) return;
    setState(() {
      _error = e is ApiException ? e.message : 'Could not confirm your changes. Try again.';
      _disabled = e is ApiException && e.code == 'account_disabled';
    });
  }
  void _addPrompt(String prompt) {
    if (_busy || _disabled) return;
    final draft = _bio.text.trimRight();
    final next = '${draft.isEmpty ? '' : '$draft\n\n'}$prompt ';
    if (next.length > 2000) {
      setState(() => _error = 'Make room in About me before adding a starter.');
      return;
    }
    _bio.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
    setState(() { _confirmation = null; _error = null; });
  }
  Future<void> _save() async {
    if (_busy || _disabled) return;
    setState(() { _busy = true; _error = null; _confirmation = null; });
    try {
      await _api!.save(_name.text, _bio.text, _tags, _interests);
      if (mounted) setState(() => _confirmation = 'Profile saved.');
    } catch (e) { _failed(e); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit profile')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24), children: [
        if (!_loaded && _error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (!_loaded) OutlinedButton(onPressed: _disabled ? null : _load, child: const Text('Retry')),
        if (_loaded) ...[
          TextField(controller: _name, enabled: !_busy && !_disabled, maxLength: 80,
            decoration: const InputDecoration(labelText: 'Display name')),
          TextField(controller: _bio, enabled: !_busy && !_disabled, maxLength: 2000, minLines: 2, maxLines: 5,
            decoration: const InputDecoration(labelText: 'About me')),
          const Text('Optional writing starters'),
          const Text('Add a starter, then write your own answer in About me. It is shared on your profile only when you save.'),
          Wrap(spacing: 8, children: [
            for (final prompt in ['My ideal weekend:', 'Ask me about:', 'A small thing I enjoy:'])
              ActionChip(label: Text(prompt), onPressed: _busy || _disabled ? null : () => _addPrompt(prompt)),
          ]),
          const SizedBox(height: 16),
          const Text('Here for'),
          Wrap(spacing: 8, children: [for (final tag in IntentTag.values)
            FilterChip(label: Text(tag.label), selected: _tags.contains(tag.value),
              onSelected: _busy || _disabled ? null : (v) => setState(() { v ? _tags.add(tag.value) : _tags.remove(tag.value); }))]),
          const SizedBox(height: 16), const Text('Interests'),
          Wrap(spacing: 8, children: [for (final i in DiscoveryInterests.all)
            FilterChip(label: Text(i.label), selected: _interests.contains(i.slug),
              onSelected: _busy || _disabled ? null : (v) => setState(() { v ? _interests.add(i.slug) : _interests.remove(i.slug); }))]),
          const SizedBox(height: 16),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          if (_confirmation != null) Semantics(liveRegion: true, child: Text(_confirmation!)),
          FilledButton(onPressed: _busy || _disabled ? null : _save, child: Text(_busy ? 'Saving…' : 'Save profile')),
        ],
      ]),
  );
}
