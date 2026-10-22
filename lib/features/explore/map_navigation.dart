import 'package:flutter/services.dart';

class MapNavigation {
  const MapNavigation();

  static const _channel = MethodChannel('com.raismukhtar.tetes/map_navigation');

  Future<bool> open(double latitude, double longitude, String name) async {
    try {
      return await _channel.invokeMethod<bool>('open', {
            'latitude': latitude,
            'longitude': longitude,
            'name': name,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
