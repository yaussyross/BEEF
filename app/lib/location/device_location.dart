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

/// One foreground reading on an explicit action. No stream or background task.
class DeviceLocation {
  DeviceLocation({Future<bool> Function()? services,
    Future<LocationPermission> Function()? check,
    Future<LocationPermission> Function()? request,
    Future<Coordinates> Function()? position})
      : _services = services ?? Geolocator.isLocationServiceEnabled,
        _check = check ?? Geolocator.checkPermission,
        _request = request ?? Geolocator.requestPermission,
        _position = position ?? _read;
  final Future<bool> Function() _services;
  final Future<LocationPermission> Function() _check, _request;
  final Future<Coordinates> Function() _position;
  static Future<Coordinates> _read() async {
    final point = await Geolocator.getCurrentPosition(locationSettings:
      const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)));
    return Coordinates(point.latitude, point.longitude);
  }
  Future<Coordinates> locate() async {
    if (!await _services()) throw const LocationFailure('Location services are off. Enable them in device settings, then try again.');
    var permission = await _check();
    if (permission == LocationPermission.denied) permission = await _request();
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure('Location permission is disabled in device settings. You can keep using the app without updating your location.');
    }
    if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
      throw const LocationFailure('Location permission was not granted. No location was sent.');
    }
    try {
      final point = await _position();
      if (!point.latitude.isFinite || !point.longitude.isFinite || point.latitude.abs() > 90 || point.longitude.abs() > 180) {
        throw const LocationFailure('A valid location could not be obtained. Try again.');
      }
      return point;
    } on TimeoutException {
      throw const LocationFailure('Location took too long. Check your connection and try again.');
    }
  }
}
