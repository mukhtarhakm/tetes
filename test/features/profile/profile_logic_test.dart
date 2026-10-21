import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/core/ui/app_avatar.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/remote/auth_client.dart';
import 'package:tetes/data/repositories/user_repo.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/biometric/biometric_authenticator.dart';
import 'package:tetes/features/profile/profile_photo_service.dart';
import 'package:tetes/features/profile/profile_screen.dart';

void main() {
  late Database database;
  late UserRepository repository;
  late Directory directory;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseMigrations.create(database, DatabaseMigrations.schemaVersion);
    directory = await Directory.systemTemp.createTemp('tetes-profile-');
    await database.insert('users', {
      'id': 'u1',
      'username': 'Satu',
      'created_at': '2026-10-20T00:00:00Z',
    });
    await database.insert('users', {
      'id': 'u2',
      'username': 'Dua',
      'created_at': '2026-10-20T00:00:00Z',
    });
    repository = UserRepository(
      database,
      AuthClient(client: MockClient((_) async => http.Response('', 500))),
      const _UnusedSessionStorage(),
    );
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'foto baru disimpan per pengguna lalu foto lama dihapus; batal aman',
    () async {
      final old = File('${directory.path}${Platform.pathSeparator}old.jpg');
      await old.writeAsBytes([1, 2]);
      await repository.savePhotoPath('u1', 'old.jpg');
      final picked = File(
        '${directory.path}${Platform.pathSeparator}picked.jpg',
      );
      await picked.writeAsBytes([3, 4]);
      final picker = _FakePicker(XFile(picked.path));
      final service = ProfilePhotoService(
        picker: picker,
        documentsDirectory: () async => directory,
      );
      final name = await service.replace(
        userId: 'u1',
        previousName: 'old.jpg',
        source: ImageSource.gallery,
        repository: repository,
      );
      expect(name, contains('u1'));
      expect(
        await File(
          '${directory.path}${Platform.pathSeparator}$name',
        ).readAsBytes(),
        [3, 4],
      );
      expect(await old.exists(), isFalse);
      expect((await repository.profile('u1'))?['photo_path'], name);
      expect((await repository.profile('u2'))?['photo_path'], isNull);
      picker.file = null;
      expect(
        await service.replace(
          userId: 'u1',
          previousName: name,
          source: ImageSource.camera,
          repository: repository,
        ),
        isNull,
      );
      expect((await repository.profile('u1'))?['photo_path'], name);
    },
  );

  test('gagal salin tidak menghapus foto lama atau mengganti path', () async {
    final old = File('${directory.path}${Platform.pathSeparator}old.jpg');
    await old.writeAsBytes([1]);
    await repository.savePhotoPath('u1', 'old.jpg');
    final service = ProfilePhotoService(
      picker: _FakePicker(
        XFile('${directory.path}${Platform.pathSeparator}missing.jpg'),
      ),
      documentsDirectory: () async => directory,
    );
    await expectLater(
      service.replace(
        userId: 'u1',
        previousName: 'old.jpg',
        source: ImageSource.gallery,
        repository: repository,
      ),
      throwsA(anything),
    );
    expect(await old.exists(), isTrue);
    expect((await repository.profile('u1'))?['photo_path'], 'old.jpg');
  });

  test('gagal menyimpan photo_path tidak menghapus foto lama', () async {
    final old = File('${directory.path}${Platform.pathSeparator}old.jpg');
    await old.writeAsBytes([1]);
    final picked = File('${directory.path}${Platform.pathSeparator}picked.jpg');
    await picked.writeAsBytes([2]);
    final service = ProfilePhotoService(
      picker: _FakePicker(XFile(picked.path)),
      documentsDirectory: () async => directory,
    );
    await expectLater(
      service.replace(userId: 'missing', previousName: 'old.jpg',
        source: ImageSource.gallery, repository: repository),
      throwsStateError,
    );
    expect(await old.exists(), isTrue);
    expect(await directory.list().where((item) => item.path.contains('profile_missing_')).isEmpty,
      isTrue);
  });

  testWidgets('berkas foto hilang memakai inisial', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppAvatar(
            username: 'Rais',
            photo: File(
              '${directory.path}${Platform.pathSeparator}missing.jpg',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('R'), findsOneWidget);
  });

  test(
    'biometrik butuh sukses untuk menyalakan dan mati tanpa autentikasi',
    () async {
      final fake = _FakeBiometric();
      fake.outcome = BiometricAuthenticationOutcome.failed;
      await updateBiometricSetting(
        repository: repository,
        authenticator: fake,
        userId: 'u1',
        enabled: true,
      );
      expect(await repository.isBiometricEnabled('u1'), isFalse);
      fake.outcome = BiometricAuthenticationOutcome.success;
      await updateBiometricSetting(
        repository: repository,
        authenticator: fake,
        userId: 'u1',
        enabled: true,
      );
      expect(await repository.isBiometricEnabled('u1'), isTrue);
      expect(await repository.isBiometricEnabled('u2'), isFalse);
      await updateBiometricSetting(
        repository: repository,
        authenticator: fake,
        userId: 'u1',
        enabled: false,
      );
      expect(await repository.isBiometricEnabled('u1'), isFalse);
      expect(fake.calls, 2);
    },
  );
}

class _FakePicker extends ImagePicker {
  _FakePicker(this.file);
  XFile? file;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => file;
}

class _FakeBiometric implements BiometricAuthenticator {
  int calls = 0;
  BiometricAuthenticationOutcome outcome =
      BiometricAuthenticationOutcome.success;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<BiometricAuthenticationOutcome> authenticate() async {
    calls++;
    return outcome;
  }
}

class _UnusedSessionStorage implements SessionStorage {
  const _UnusedSessionStorage();
  @override
  Future<void> clearSession() async {}
  @override
  Future<List<String>> readPendingRevokeTokens() async => const [];
  @override
  Future<StoredSession?> readSession() async => null;
  @override
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  }) async {}
  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {}
}
