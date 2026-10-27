import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/foundation.dart';

const passwordIterations = 600000;
const passwordAlgorithm = 'pbkdf2-hmac-sha256';

Future<List<int>> derivePasswordHash(
  String password,
  List<int> salt,
  int iterations, {
  bool forceFallback = false,
  cryptography.Pbkdf2? algorithmOverride,
}) async {
  if (salt.length != 16 || iterations < 1) {
    throw ArgumentError('Parameter PBKDF2 tidak valid.');
  }
  final stopwatch = Stopwatch()..start();
  List<int>? result;
  var path = 'fallback';
  final algorithm =
      algorithmOverride ??
      cryptography.Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
  if (!forceFallback &&
      (algorithmOverride != null ||
          algorithm is FlutterPbkdf2 && algorithm.isSupported)) {
    try {
      final key = await algorithm.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      final bytes = await key.extractBytes();
      if (bytes.length != 32) throw StateError('Panjang hash tidak valid.');
      result = bytes;
      path = algorithm is FlutterPbkdf2 ? 'native' : 'package';
    } catch (_) {
      // Kripto platform bisa tidak tersedia; pakai cadangan isolate.
    }
  }
  final List<int> output;
  if (result != null) {
    output = result;
  } else {
    output = await Isolate.run(() => _pbkdf2(password, salt, iterations));
  }
  if (kDebugMode ||
      (kProfileMode && const bool.fromEnvironment('AUTH_HASH_TIMING'))) {
    debugPrint(
      'PBKDF2 path=$path duration_ms=${stopwatch.elapsedMilliseconds}',
    );
  }
  return output;
}

List<int> _pbkdf2(String password, List<int> salt, int iterations) {
  if (iterations < 1) throw ArgumentError.value(iterations, 'iterations');
  final hmac = Hmac(sha256, utf8.encode(password));
  final block = [...salt, 0, 0, 0, 1];
  var previous = hmac.convert(block).bytes;
  final result = List<int>.from(previous);
  for (var i = 1; i < iterations; i++) {
    previous = hmac.convert(previous).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= previous[j];
    }
  }
  return result;
}

bool constantTimeEquals(List<int> left, List<int> right) {
  var difference = left.length ^ right.length;
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    difference |=
        (i < left.length ? left[i] : 0) ^ (i < right.length ? right[i] : 0);
  }
  return difference == 0;
}
