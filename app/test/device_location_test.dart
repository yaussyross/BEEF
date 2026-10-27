import 'dart:async';
import 'package:beef/location/device_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
void main() {
  test('cancelling during permission prompt prevents later native acquisition', () async {
    final permission = Completer<LocationPermission>();
    var reads = 0;
    final source = DeviceLocation(services: () async => true,
      check: () async => LocationPermission.denied, request: () => permission.future,
      positions: () { reads++; return Stream.value(const Coordinates(1, 2)); });
    final result = source.locate();
    await Future<void>.delayed(Duration.zero);
    source.cancel();
    permission.complete(LocationPermission.whileInUse);
    await expectLater(result, throwsA(isA<LocationFailure>()));
    expect(reads, 0);
  });
  test('cancelling active acquisition closes its subscription without a reading', () async {
    var cancelled = 0;
    final positions = StreamController<Coordinates>(onCancel: () { cancelled++; });
    final source = DeviceLocation(services: () async => true,
      check: () async => LocationPermission.whileInUse,
      positions: () => positions.stream);
    final result = source.locate();
    final assertion = expectLater(result, throwsA(isA<LocationFailure>()));
    await Future<void>.delayed(Duration.zero);
    source.cancel(); await assertion;
    expect(cancelled, 1); await positions.close();
  });
  test('disabled service and denied permission never read a position', () async {
    var reads = 0;
    Stream<Coordinates> read() { reads++; return Stream.value(const Coordinates(1, 2)); }
    final disabled = DeviceLocation(services: () async => false,
      check: () async => LocationPermission.whileInUse,
      request: () async => LocationPermission.whileInUse, positions: read);
    await expectLater(disabled.locate(), throwsA(isA<LocationFailure>()));
    final denied = DeviceLocation(services: () async => true,
      check: () async => LocationPermission.denied,
      request: () async => LocationPermission.denied, positions: read);
    await expectLater(denied.locate(), throwsA(isA<LocationFailure>()));
    expect(reads, 0);
  });
  test('permanent denial does not repeat permission request', () async {
    var requests = 0;
    final location = DeviceLocation(services: () async => true,
      check: () async => LocationPermission.deniedForever,
      request: () async { requests++; return LocationPermission.whileInUse; },
      positions: () => Stream.value(const Coordinates(1, 2)));
    await expectLater(location.locate(), throwsA(isA<LocationFailure>()));
    expect(requests, 0);
  });
  test('one explicit locate request produces one reading after permission', () async {
    var reads = 0;
    final location = DeviceLocation(services: () async => true,
      check: () async => LocationPermission.denied,
      request: () async => LocationPermission.whileInUse,
      positions: () { reads++; return Stream.value(const Coordinates(1, 2)); });
    expect(reads, 0);
    final point = await location.locate();
    expect(point.latitude, 1); expect(point.longitude, 2); expect(reads, 1);
  });
}
