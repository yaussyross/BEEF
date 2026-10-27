import 'package:flutter/material.dart';
import '../api/http_client.dart';
import '../api/safety_api.dart';
import '../auth/auth_scope.dart';
import '../config/api_config.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key, this.api});
  final SafetyApi? api;
  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}
class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  SafetyApi? _api;
  ApiClient? _client;
  List<BlockedUser>? _users;
  bool _loading = true, _busy = false, _disabled = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api != null) return;
    _api = widget.api;
    if (_api == null) {
      _client = ApiClient(baseUrl: ApiConfig.baseUrl, tokenStore: AuthScope.read(context).tokenStore);
      _api = SafetyApi(_client!);
    }
    _load();
  }
  @override
  void dispose() { _client?.close(); super.dispose(); }
  void _failed(Object e) {
    if (!mounted) return;
    setState(() {
      _error = e is ApiException ? e.message : 'Could not confirm that change. Try again.';
      _disabled = e is ApiException && e.code == 'account_disabled';
    });
  }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final users = await _api!.blockedUsers(); if (mounted) setState(() => _users = users); }
    catch (e) { _failed(e); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _unblock(BlockedUser user) async {
    if (_busy || _disabled) return;
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Unblock this user?'),
      content: const Text('This removes your block. You may see and message each other again unless they have also blocked you.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm unblock'))],
    ));
    if (!mounted) return;
    if (confirmed == true) {
      try {
        await _api!.unblock(user.userId);
        if (mounted) setState(() { _users!.removeWhere((u) => u.userId == user.userId); _error = null; });
      } catch (e) { _failed(e); }
    }
    if (mounted) setState(() => _busy = false);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blocked users')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(24), children: [
        const Text('Blocked profiles stay private. Entries show the account ID and the date you blocked them.'),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (_users == null) OutlinedButton(onPressed: _disabled ? null : _load, child: const Text('Retry')),
        if (_users?.isEmpty == true) const Text('No blocked users.'),
        for (final u in _users ?? <BlockedUser>[]) ListTile(
          title: Text(u.userId), subtitle: Text(u.blockedAt),
          trailing: TextButton(onPressed: _busy || _disabled ? null : () => _unblock(u), child: const Text('Unblock'))),
      ]),
  );
}
