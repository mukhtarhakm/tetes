import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/explore/map_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.raismukhtar.tetes/map_navigation');

  test('tidak ada aplikasi peta mengembalikan false', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    expect(await const MapNavigation().open(-7.8, 110.4, 'Toko'), isFalse);
  });
}
