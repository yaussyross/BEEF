import 'package:beef/location/device_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
void main() {
  test('disabled service and denied permission never read a position', () async {
    var reads = 0;
    Future<Coordinates> read() async { reads++; return const Coordinates(1, 2); }
    final disabled = DeviceLocation(services: () async => false,
      check: () async => LocationPermission.whileInUse,
      request: () async => LocationPermission.whileInUse, position: read);
    await expectLater(disabled.locate(), throwsA(isA<LocationFailure>()));
    final denied = DeviceLocation(services: () async => true,
      check: () async => LocationPermission.denied,
      request: () async => LocationPermission.denied, position: read);
    await expectLater(denied.locate(), throwsA(isA<LocationFailure>()));
    expect(reads, 0);
  });
  test('permanent denial does not repeat permission request', () async {
    var requests = 0;
    final location = DeviceLocation(services: () async => true,
      check: () async => LocationPermission.deniedForever,
      request: () async { requests++; return LocationPermission.whileInUse; },
      position: () async => const Coordinates(1, 2));
    await expectLater(location.locate(), throwsA(isA<LocationFailure>()));
    expect(requests, 0);
  });
  test('one explicit locate request produces one reading after permission', () async {
    var reads = 0;
    final location = DeviceLocation(services: () async => true,
      check: () async => LocationPermission.denied,
      request: () async => LocationPermission.whileInUse,
      position: () async { reads++; return const Coordinates(1, 2); });
    expect(reads, 0);
    final point = await location.locate();
    expect(point.latitude, 1); expect(point.longitude, 2); expect(reads, 1);
  });
}
