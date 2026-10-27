import 'dart:async';
import 'package:geolocator/geolocator.dart';

class Coordinates {
  const Coordinates(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}
class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;
}

/// One explicit reading. Cancels the native subscription after the first result,
/// timeout, leaving the screen or backgrounding; never starts a background task.
class DeviceLocation {
  DeviceLocation({Future<bool> Function()? services,
    Future<LocationPermission> Function()? check,
    Future<LocationPermission> Function()? request,
    Stream<Coordinates> Function()? positions})
      : _services = services ?? Geolocator.isLocationServiceEnabled,
        _check = check ?? Geolocator.checkPermission,
        _request = request ?? Geolocator.requestPermission,
        _positions = positions ?? _nativePositions;
  final Future<bool> Function() _services;
  final Future<LocationPermission> Function() _check, _request;
  final Stream<Coordinates> Function() _positions;
  bool _cancelled = false;
  StreamSubscription<Coordinates>? _subscription;
  Completer<Coordinates>? _pending;

  static Stream<Coordinates> _nativePositions() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium))
      .map((p) => Coordinates(p.latitude, p.longitude));
  void _ensureActive() {
    if (_cancelled) throw const LocationFailure('Location update cancelled.');
  }
  void cancel() {
    _cancelled = true;
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const LocationFailure('Location update cancelled.'));
    }
    // _readOne's finally block owns subscription cancellation.
  }
  Future<Coordinates> _readOne() async {
    _ensureActive();
    final pending = Completer<Coordinates>();
    _pending = pending;
    final timer = Timer(const Duration(seconds: 20), () {
      if (!pending.isCompleted) pending.completeError(const LocationFailure('Location took too long. Try again.'));
    });
    try {
      _subscription = _positions().listen((point) {
        if (!pending.isCompleted) pending.complete(point);
      }, onError: (Object error, StackTrace stack) {
        if (!pending.isCompleted) pending.completeError(error, stack);
      }, onDone: () {
        if (!pending.isCompleted) pending.completeError(const LocationFailure('A location could not be obtained. Try again.'));
      });
      return await pending.future;
    } finally {
      timer.cancel();
      await _subscription?.cancel();
      _subscription = null; _pending = null;
    }
  }
  Future<Coordinates> locate() async {
    _ensureActive();
    final enabled = await _services();
    _ensureActive();
    if (!enabled) throw const LocationFailure('Location services are off. Enable them in device settings, then try again.');
    var permission = await _check();
    _ensureActive();
    if (permission == LocationPermission.denied) permission = await _request();
    _ensureActive();
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure('Location permission is disabled in device settings. You can keep using the app without updating your location.');
    }
    if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
      throw const LocationFailure('Location permission was not granted. No location was sent.');
    }
    final point = await _readOne();
    _ensureActive();
    if (!point.latitude.isFinite || !point.longitude.isFinite || point.latitude.abs() > 90 || point.longitude.abs() > 180) {
      throw const LocationFailure('A valid location could not be obtained. Try again.');
    }
    return point;
  }
}
