import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/data/secure/biometric_credential_storage.dart';

void main() {
  test(
    'kredensial tersimpan per username tanpa password dan dapat dihapus',
    () async {
      final secure = _MemoryStorage();
      final storage = BiometricCredentialStorage(secure);
      const credential = BiometricCredential(
        username: 'rais_uji',
        passwordHash: 'hash-base64',
        salt: 'salt-base64',
        iterations: 600000,
        algo: 'pbkdf2-hmac-sha256',
      );
      await storage.save(credential);
      expect(secure.values.keys.single, 'biometric_credential_rais_uji');
      expect(secure.values.values.single, isNot(contains('password":"')));
      expect((await storage.read('rais_uji'))?.passwordHash, 'hash-base64');
      expect(await storage.read('akun_lain'), isNull);
      await storage.delete('rais_uji');
      expect(await storage.read('rais_uji'), isNull);
    },
  );
}

class _MemoryStorage implements FlutterSecureStorage {
  final values = <String, String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String;
    if (invocation.memberName == #read) {
      return Future<String?>.value(values[key]);
    }
    if (invocation.memberName == #write) {
      values[key] = invocation.namedArguments[#value] as String;
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      values.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
