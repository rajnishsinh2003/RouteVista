import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:routevista/main.dart'; // Ensure path is correct

// Mock to prevent UnimplementedError during tests
class MockGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  @override
  Stream<ServiceStatus> getServiceStatusStream() =>
      Stream.value(ServiceStatus.enabled);
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    return Position(
      latitude: 0,
      longitude: 0,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }
}

void main() {
  setUp(() => GeolocatorPlatform.instance = MockGeolocatorPlatform());

  testWidgets('Fixing the crash', (WidgetTester tester) async {
    // UPDATED: Use RouteVistaApp instead of MyApp
    await tester.pumpWidget(const RouteVistaApp(showOnboarding: false, alreadyLoggedIn: false));
    await tester.pumpAndSettle();
  });
}
