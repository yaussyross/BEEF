import 'package:flutter/material.dart';
import '../api/http_client.dart';
import '../api/location_api.dart';
import '../auth/auth_scope.dart';
import '../config/api_config.dart';
import '../location/device_location.dart';

/// Disabled in closed synthetic builds; enabling real data needs separate approval.
class DeviceLocationScreen extends StatefulWidget {
  const DeviceLocationScreen({super.key});
  @override
  State<DeviceLocationScreen> createState() => _DeviceLocationScreenState();
}
class _DeviceLocationScreenState extends State<DeviceLocationScreen> with WidgetsBindingObserver {
  int _generation = 0;
  DeviceLocation? _location;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { _generation++; _location?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inactive includes the OS permission prompt; paused/hidden/detached
    // indicate leaving the foreground and cancel the pending acquisition.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached) {
      _generation++; _location?.cancel();
    }
  }
  bool _busy = false, _disabled = false;
  String? _message;
  Future<void> _update() async {
    if (!ApiConfig.deviceLocationEnabled || _busy || _disabled) return;
    final generation = ++_generation;
    setState(() { _busy = true; _message = null; });
    final client = ApiClient(baseUrl: ApiConfig.baseUrl, tokenStore: AuthScope.read(context).tokenStore);
    final location = DeviceLocation();
    _location = location;
    try {
      final point = await location.locate();
      if (!mounted || generation != _generation) return;
      await LocationApi(client).update(point.latitude, point.longitude);
      if (mounted) setState(() => _message = 'Location updated. Your privacy preferences are unchanged.');
    } catch (e) {
      if (mounted) {
        setState(() {
        _message = e is LocationFailure ? e.message : e is ApiException ? e.message : 'Could not update location. Try again.';
        _disabled = e is ApiException && e.code == 'account_disabled';
        });
      }
    } finally { location.cancel(); _location = null; client.close(); if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Update location')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      if (!ApiConfig.deviceLocationEnabled)
        const Text('Real device location is disabled in this synthetic test build.')
      else ...[
        const Text('Tap below to request one location reading while this screen is open. BEEF sends it to its server for discovery; other users receive only your chosen distance display. There is no continuous location tracking.'),
        if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
        FilledButton(onPressed: _busy || _disabled ? null : _update, child: Text(_busy ? 'Updating…' : 'Update my location')),
      ],
    ]),
  );
}
