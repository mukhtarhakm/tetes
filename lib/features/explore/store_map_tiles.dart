import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

class StoreMapTiles extends StatefulWidget {
  const StoreMapTiles({this.styleLoader, super.key});

  final Future<Style> Function()? styleLoader;

  @override
  State<StoreMapTiles> createState() => _StoreMapTilesState();
}

class _StoreMapTilesState extends State<StoreMapTiles> {
  static const _userAgent = 'com.raismukhtar.tetes';
  Style? _style;
  bool _vectorFailed = false;
  bool _vectorTileLoaded = false;
  bool _osmFailed = false;
  Timer? _tileTimeout;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    try {
      final style =
          await (widget.styleLoader?.call() ??
                  StyleReader(
                    uri: 'https://tiles.openfreemap.org/styles/liberty',
                    httpHeaders: const {'User-Agent': _userAgent},
                  ).read())
              .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() => _style = style);
      _tileTimeout = Timer(const Duration(seconds: 10), () {
        if (mounted && !_vectorTileLoaded) setState(() => _vectorFailed = true);
      });
    } catch (_) {
      if (mounted) setState(() => _vectorFailed = true);
    }
  }

  void _tileLoaded() {
    _vectorTileLoaded = true;
    _tileTimeout?.cancel();
  }

  void _tileFailed() {
    if (mounted && !_vectorFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _vectorFailed = true);
      });
    }
  }

  @override
  void dispose() {
    _tileTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: _userAgent,
        errorTileCallback: (_, _, _) {
          if (!_osmFailed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _osmFailed = true);
            });
          }
        },
      ),
      if (_style != null && !_vectorFailed)
        VectorTileLayer(
          theme: _style!.theme,
          sprites: _style!.sprites,
          tileProviders: TileProviders({
            for (final entry in _style!.providers.tileProviderBySource.entries)
              entry.key: _ObservedTileProvider(
                entry.value,
                _tileLoaded,
                _tileFailed,
              ),
          }),
        ),
      if (_vectorFailed && _osmFailed)
        const Align(
          alignment: Alignment.center,
          child: Text('Peta belum dapat dimuat. Daftar toko tetap tersedia.'),
        ),
    ],
  );
}

class _ObservedTileProvider extends VectorTileProvider {
  _ObservedTileProvider(this.delegate, this.onLoaded, this.onFailed);

  final VectorTileProvider delegate;
  final VoidCallback onLoaded;
  final VoidCallback onFailed;

  @override
  int get maximumZoom => delegate.maximumZoom;
  @override
  int get minimumZoom => delegate.minimumZoom;
  @override
  TileOffset get tileOffset => delegate.tileOffset;
  @override
  TileProviderType get type => delegate.type;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    try {
      final bytes = await delegate.provide(tile);
      if (delegate.type == TileProviderType.vector) {
        onLoaded();
      }
      return bytes;
    } catch (_) {
      if (delegate.type == TileProviderType.vector) {
        onFailed();
      }
      rethrow;
    }
  }
}
