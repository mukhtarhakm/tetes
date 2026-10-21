import 'package:flutter/services.dart';

typedef SetGameOrientations =
    Future<void> Function(List<DeviceOrientation> orientations);

class GameOrientationLock {
  GameOrientationLock({SetGameOrientations? setOrientations})
    : _setOrientations =
          setOrientations ?? SystemChrome.setPreferredOrientations;

  final SetGameOrientations _setOrientations;
  Future<void> _pending = Future<void>.value();
  bool _disposed = false;

  Future<void> get settled => _pending;

  void lockPortrait() {
    if (_disposed) return;
    _enqueue(const [DeviceOrientation.portraitUp]);
  }

  void restoreAppOrientation() {
    if (_disposed) return;
    _enqueue(const []);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _enqueue(const []);
  }

  void _enqueue(List<DeviceOrientation> orientations) {
    _pending = _pending
        .then((_) => _setOrientations(orientations))
        .catchError((_) {});
  }
}
