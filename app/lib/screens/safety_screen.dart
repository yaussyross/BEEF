import 'package:flutter/material.dart';

import '../api/http_client.dart';
import '../api/safety_api.dart';
import '../auth/auth_scope.dart';
import '../config/api_config.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key, required this.userId, this.threadId, this.api});
  final String userId;
  final String? threadId;
  final SafetyApi? api;

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  SafetyApi? _api;
  ApiClient? _ownedClient;
  final _reason = TextEditingController();
  ReportKind? _kind;
  bool _busy = false;
  bool _disabled = false;
  bool _reported = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api != null) return;
    if (widget.api != null) {
      _api = widget.api;
    } else {
      _ownedClient = ApiClient(baseUrl: ApiConfig.baseUrl,
        tokenStore: AuthScope.read(context).tokenStore);
      _api = SafetyApi(_ownedClient!);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _ownedClient?.close();
    super.dispose();
  }

  void _failed(Object error, String fallback) {
    setState(() {
      _error = error is ApiException ? error.message : fallback;
      _disabled = error is ApiException && error.code == 'account_disabled';
    });
  }

  Future<void> _report() async {
    if (_busy || _disabled || _reported || _kind == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _api!.report(widget.userId, _kind!, _reason.text, threadId: widget.threadId);
      if (mounted) setState(() => _reported = true);
    } catch (error) {
      if (mounted) _failed(error, 'Could not confirm your report. You can try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _block() async {
    if (_busy || _disabled) return;
    setState(() => _busy = true);
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Block this user?'),
      content: const Text('You will no longer see each other on the grid or be able to message each other.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block')),
      ],
    ));
    if (!mounted) return;
    if (confirmed != true) { setState(() => _busy = false); return; }
    setState(() => _error = null);
    try {
      await _api!.block(widget.userId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _failed(error, 'Could not block this user. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Safety options')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
      OutlinedButton.icon(onPressed: _busy || _disabled ? null : _block,
        icon: const Icon(Icons.block), label: const Text('Block user')),
      const SizedBox(height: 24),
      Text('Report a concern', style: Theme.of(context).textTheme.titleLarge),
      if (_reported)
        Semantics(liveRegion: true, child: const Text('Your report was received for review.'))
      else ...[
        DropdownButton<ReportKind>(
          value: _kind, isExpanded: true,
          hint: const Text('Choose a reason'),
          items: ReportKind.values.map((kind) => DropdownMenuItem(value: kind, child: Text(kind.label))).toList(),
          onChanged: _busy || _disabled ? null : (kind) => setState(() => _kind = kind),
        ),
        TextField(controller: _reason, enabled: !_busy && !_disabled,
          maxLength: 1000, minLines: 2, maxLines: 5,
          decoration: const InputDecoration(labelText: 'Details (optional)'),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy || _disabled || _kind == null ? null : _report,
          child: Text(_busy ? 'Working…' : 'Submit report')),
      ],
    ])),
  );
}
