import 'package:flutter/material.dart';
import '../api/http_client.dart';
import '../api/location_api.dart';
import '../auth/auth_scope.dart';
import '../config/api_config.dart';

/// Closed-test fixture selection. Never reads the device's real location.
class TestLocationScreen extends StatefulWidget {
  const TestLocationScreen({super.key, this.api});
  final LocationApi? api;
  @override
  State<TestLocationScreen> createState() => _TestLocationScreenState();
}
class _TestLocationScreenState extends State<TestLocationScreen> {
  LocationApi? _api;
  ApiClient? _client;
  bool _busy = false, _disabled = false;
  String? _error, _confirmation;
  int _area = 0;
  static const _points = [(37.7749, -122.4194), (37.7750, -122.4195), (40.7128, -74.0060)];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api != null) return;
    _api = widget.api;
    if (_api == null) {
      _client = ApiClient(baseUrl: ApiConfig.baseUrl, tokenStore: AuthScope.read(context).tokenStore);
      _api = LocationApi(_client!);
    }
  }
  @override
  void dispose() { _client?.close(); super.dispose(); }
  Future<void> _save() async {
    if (_busy || _disabled) return;
    setState(() { _busy = true; _error = null; _confirmation = null; });
    try {
      final point = _points[_area];
      await _api!.update(point.$1, point.$2);
      if (mounted) setState(() => _confirmation = 'Synthetic test area saved. Return to the grid to refresh.');
    } catch (e) {
      if (mounted) setState(() {
        _error = e is ApiException ? e.message : 'Could not confirm the test area. Try again.';
        _disabled = e is ApiException && e.code == 'account_disabled';
      });
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Synthetic test area')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Closed synthetic test only. This sets fictional fixture coordinates on the server. Your device location is never requested. Areas A and B are nearby; Far is outside their discovery radius.'),
      if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
      if (_confirmation != null) Semantics(liveRegion: true, child: Text(_confirmation!)),
      DropdownButton<int>(value: _area, isExpanded: true,
        items: const [DropdownMenuItem(value: 0, child: Text('Test area A')),
          DropdownMenuItem(value: 1, child: Text('Test area B')),
          DropdownMenuItem(value: 2, child: Text('Test area Far'))],
        onChanged: _busy || _disabled ? null : (v) => setState(() { _area = v!; _confirmation = null; })),
      FilledButton(onPressed: _busy || _disabled ? null : _save, child: Text(_busy ? 'Saving…' : 'Use test area')),
    ]),
  );
}
