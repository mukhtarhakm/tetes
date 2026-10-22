import 'package:geolocator/geolocator.dart';

enum StoreLocationStatus { available, gpsOff, denied, deniedForever }

class StoreLocationResult {
  const StoreLocationResult(this.status, {this.latitude, this.longitude});

  final StoreLocationStatus status;
  final double? latitude;
  final double? longitude;

  bool get hasPosition => latitude != null && longitude != null;
}

class StoreLocationService {
  const StoreLocationService();

  Future<StoreLocationResult> read({bool request = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const StoreLocationResult(StoreLocationStatus.gpsOff);
      }
      var permission = await Geolocator.checkPermission();
      if (request && permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const StoreLocationResult(StoreLocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const StoreLocationResult(StoreLocationStatus.denied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return StoreLocationResult(
        StoreLocationStatus.available,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return const StoreLocationResult(StoreLocationStatus.gpsOff);
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
