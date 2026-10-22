import 'dart:math' as math;

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/tokens.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_chip.dart';
import '../../core/ui/app_dialog.dart';
import '../../core/ui/state_views.dart';
import '../../data/db/database_provider.dart';
import '../../data/repositories/store_repo.dart';
import 'map_navigation.dart';
import 'store_distance.dart';
import 'store_location.dart';
import 'store_model.dart';
import 'store_route.dart';
import 'store_map_tiles.dart';

final storeRepositoryProvider = FutureProvider<StoreRepository>(
  (ref) async => StoreRepository(await ref.watch(databaseProvider.future)),
);
final storeListProvider = FutureProvider<List<StoreItem>>(
  (ref) async => (await ref.watch(storeRepositoryProvider.future)).list(),
);
final storeLocationProvider = Provider<StoreLocationService>(
  (ref) => const StoreLocationService(),
);
final mapNavigationProvider = Provider<MapNavigation>(
  (ref) => const MapNavigation(),
);
final storeRouteServiceProvider = Provider<StoreRouteService>(
  (ref) => const StoreRouteService(),
);

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with WidgetsBindingObserver {
  static const _yogyakarta = LatLng(-7.7956, 110.3695);
  static const _zoom = 12.0;
  static const _filters = [('', 'Semua'), ('biji', 'Biji'), ('alat', 'Alat')];

  final _mapController = MapController();
  ScrollController? _sheetScrollController;
  final _sheetController = DraggableScrollableController();
  double _sheetFraction = AppSizes.mapSheetInitial;
  double _bodyHeight = 0;

  List<StoreItem>? _stores;
  StoreLocationResult? _location;
  String? _loadError;
  String _filter = '';
  StoreItem? _selectedStore;
  StoreRoute? _route;
  String? _routeError;
  bool _routeLoading = false;
  bool _routeConsent = false;
  bool _walking = false;
  double _rotation = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sheetController.addListener(_sheetChanged);
    _load();
  }

  void _sheetChanged() {
    if (mounted) setState(() => _sheetFraction = _sheetController.size);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _showRoute(StoreItem store) async {
    final location = _location;
    if (location?.hasPosition != true) return;
    if (!_routeConsent) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AppDialog(
          title: 'Lihat rute?',
          message:
              'Posisi saat ini dan titik tujuan dikirim ke layanan rute OSRM publik untuk menghitung rute. Koordinat tidak disimpan.',
          primaryLabel: 'Lanjut',
          onPrimaryPressed: () => Navigator.pop(dialog, true),
          secondaryLabel: 'Batal',
          onSecondaryPressed: () => Navigator.pop(dialog, false),
        ),
      );
      if (accepted != true || !mounted) return;
      _routeConsent = true;
    }
    await _fetchRoute(store);
  }

  void _focusStore(StoreItem store) {
    setState(() => _selectedStore = store);
    _mapController.move(LatLng(store.latitude, store.longitude), 15);
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        AppSizes.mapSheetDetail,
        duration: AppDurations.feedback,
        curve: Curves.easeOut,
      );
    }
    if (_sheetScrollController?.hasClients == true) {
      _sheetScrollController!.jumpTo(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
    if (state == AppLifecycleState.resumed) {
      ref
          .read(storeLocationProvider)
          .read()
          .then((location) {
            if (mounted) setState(() => _location = location);
          })
          .catchError((Object _) {});
    }
  }

  Future<void> _load() async {
    try {
      final stores = await ref.read(storeListProvider.future);
      final location = await ref.read(storeLocationProvider).read();
      if (mounted) {
        setState(() {
          _stores = stores;
          _location = location;
          _loadError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Toko gagal dimuat. Coba lagi.');
    }
  }

  Future<void> _requestLocation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AppDialog(
        title: 'Gunakan lokasi?',
        message:
            'Tetes memakai lokasi saat ini untuk menghitung jarak ke toko. Lokasi tidak disimpan.',
        primaryLabel: 'Lanjutkan',
        onPrimaryPressed: () => Navigator.pop(dialog, true),
        secondaryLabel: 'Nanti',
        onSecondaryPressed: () => Navigator.pop(dialog, false),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await ref.read(storeLocationProvider).read(request: true);
      if (mounted) setState(() => _location = result);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _location = const StoreLocationResult(StoreLocationStatus.denied),
        );
      }
    }
  }

  Future<void> _openNavigation(StoreItem store) async {
    final opened = await ref
        .read(mapNavigationProvider)
        .open(store.latitude, store.longitude, store.name);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada aplikasi peta yang dapat membuka navigasi.'),
        ),
      );
    }
  }

  Widget _storeDetail(StoreItem store) {
    final location = _location;
    final distance = location?.hasPosition == true
        ? StoreDistance.haversineMeters(
            location!.latitude!,
            location.longitude!,
            store.latitude,
            store.longitude,
          )
        : null;
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _storeIcon(store.type),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  store.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Tutup detail',
                onPressed: () => setState(() {
                  _selectedStore = null;
                  _route = null;
                }),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(store.typeLabel),
          if (store.address?.isNotEmpty == true) Text(store.address!),
          if (store.notes?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(store.notes!),
          ],
          if (distance != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text('Jarak ${StoreDistance.label(distance)}'),
          ],
          DropdownButton<bool>(
            value: _walking,
            items: const [
              DropdownMenuItem(value: false, child: Text('Motor/Mobil')),
              DropdownMenuItem(value: true, child: Text('Jalan kaki')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _walking = value);
            },
          ),
          const SizedBox(height: AppSpacing.s20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Buka navigasi',
                  onPressed: () => _openNavigation(store),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: AppButton(
                  label: 'Lihat rute',
                  onPressed: location?.hasPosition == true
                      ? () => _showRoute(store)
                      : null,
                ),
              ),
            ],
          ),
          if (location?.hasPosition != true)
            const Text('Aktifkan izin lokasi untuk melihat rute.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Toko Terdekat')),
        body: ErrorView(message: _loadError!, onRetry: _load),
      );
    }
    if (_stores == null || _location == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Toko Terdekat')),
        body: const LoadingView(),
      );
    }

    final location = _location!;
    final center =
        location.hasPosition &&
            StoreDistance.isInDiy(location.latitude!, location.longitude!)
        ? LatLng(location.latitude!, location.longitude!)
        : _yogyakarta;
    final filtered = _stores!.where(
      (store) =>
          _filter.isEmpty ||
          (_filter == 'biji' && store.type != 'toko_alat') ||
          (_filter == 'alat' && store.type == 'toko_alat'),
    );
    final stores = StoreDistance.sorted(
      filtered,
      latitude: location.latitude,
      longitude: location.longitude,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Toko Terdekat')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _bodyHeight = constraints.maxHeight;
          final panelHeight = _bodyHeight * _sheetFraction;
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _zoom,
                  onPositionChanged: (camera, _) {
                    if ((_rotation - camera.rotation).abs() > 0.1) {
                      setState(() => _rotation = camera.rotation);
                    }
                  },
                ),
                children: [
                  const StoreMapTiles(),
                  if (_route != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _route!.points,
                          color: AppColors.primary,
                          strokeWidth: AppSizes.mapRouteWidth,
                          borderColor: AppColors.surface,
                          borderStrokeWidth: AppSizes.mapRouteBorderWidth,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (final store in stores.where(
                        (item) => item.id != _selectedStore?.id,
                      ))
                        Marker(
                          point: LatLng(store.latitude, store.longitude),
                          width: AppSizes.mapMarker,
                          height: AppSizes.mapMarker,
                          rotate: true,
                          child: Semantics(
                            button: true,
                            label: '${store.name}, ${store.typeLabel}',
                            child: GestureDetector(
                              onTap: () => _focusStore(store),
                              child: _storeIcon(store.type),
                            ),
                          ),
                        ),
                      if (_selectedStore != null &&
                          stores.any((item) => item.id == _selectedStore!.id))
                        Marker(
                          point: LatLng(
                            _selectedStore!.latitude,
                            _selectedStore!.longitude,
                          ),
                          width: AppSizes.mapMarkerSelected,
                          height: AppSizes.mapMarkerSelected,
                          rotate: true,
                          child: GestureDetector(
                            onTap: () => _focusStore(_selectedStore!),
                            child: _storeIcon(
                              _selectedStore!.type,
                              selected: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (location.hasPosition && _foreground)
                    CurrentLocationLayer(
                      positionStream: Stream.value(
                        LocationMarkerPosition(
                          latitude: location.latitude!,
                          longitude: location.longitude!,
                          accuracy: double.nan,
                        ),
                      ),
                      headingStream:
                          FlutterCompass.events?.map((event) {
                            final degrees = event.heading;
                            if (degrees == null) return null;
                            return LocationMarkerHeading(
                              heading:
                                  (degrees * math.pi / 180) % (2 * math.pi),
                              accuracy: double.nan,
                            );
                          }) ??
                          const Stream<LocationMarkerHeading?>.empty(),
                      style: const LocationMarkerStyle(
                        headingSectorColor: AppColors.primaryContainer,
                        showAccuracyCircle: false,
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: panelHeight + AppSpacing.s8,
                    ),
                    child: RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      showFlutterMapAttribution: false,
                      attributions: const [
                        TextSourceAttribution('OpenStreetMap contributors'),
                        TextSourceAttribution('OpenFreeMap'),
                      ],
                      openButton: (context, open) => IconButton.filledTonal(
                        tooltip: 'Atribusi peta',
                        onPressed: open,
                        icon: const Icon(Icons.info_outline),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: AppSpacing.s8,
                left: AppSpacing.s8,
                right: AppSpacing.s8,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (value, label) in _filters) ...[
                        AppChip(
                          label: label,
                          icon: value == ''
                              ? null
                              : value == 'biji'
                              ? Icons.coffee_rounded
                              : Icons.storefront_rounded,
                          selected: _filter == value,
                          onSelected: (_) => setState(() {
                            _filter = value;
                            _selectedStore = null;
                            _route = null;
                            if (_sheetScrollController?.hasClients == true) {
                              _sheetScrollController!.jumpTo(0);
                            }
                          }),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.s8,
                top: AppSpacing.s8,
                bottom: panelHeight + AppSpacing.s8,
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_rotation.abs() > 0.1)
                        IconButton.filledTonal(
                          tooltip: 'Kembali ke utara',
                          onPressed: () => _mapController.rotate(0),
                          icon: Transform.rotate(
                            angle: _rotation * math.pi / 180,
                            child: const Icon(Icons.explore_rounded),
                          ),
                        ),
                      IconButton.filledTonal(
                        tooltip: 'Perbesar peta',
                        onPressed: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        ),
                        icon: const Icon(Icons.add),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Perkecil peta',
                        onPressed: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        ),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Ke posisiku',
                        onPressed: location.hasPosition
                            ? () => _mapController.move(
                                LatLng(location.latitude!, location.longitude!),
                                15,
                              )
                            : null,
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
              ),
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: AppSizes.mapSheetInitial,
                minChildSize: AppSizes.mapSheetMinimum,
                maxChildSize: AppSizes.mapSheetMaximum,
                builder: (context, scrollController) {
                  _sheetScrollController = scrollController;
                  return Material(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.card),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                      controller: scrollController,
                      padding: AppInsets.screen,
                      children: [
                        Center(
                          child: Container(
                            width: AppSizes.mapSheetHandleWidth,
                            height: AppSizes.mapSheetHandleHeight,
                            decoration: BoxDecoration(
                              color: AppColors.divider,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          'Daftar toko',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        if (_selectedStore != null) ...[
                          _storeDetail(_selectedStore!),
                          const SizedBox(height: AppSpacing.s12),
                        ],
                        if (_routeLoading) const LinearProgressIndicator(),
                        if (_routeError != null) Text(_routeError!),
                        if (_route != null) _routePanel(),
                        _locationPrompt(location.status),
                        if (stores.isEmpty)
                          const EmptyView(
                            title: 'Tidak ada toko',
                            message: 'Tidak ada toko untuk filter ini.',
                            icon: Icons.store_outlined,
                          ),
                        for (final store in stores) ...[
                          AppCard(
                            padding: AppInsets.mapListCard,
                            child: InkWell(
                              onTap: () => _focusStore(store),
                              child: Row(
                                children: [
                                  _storeIcon(store.type),
                                  const SizedBox(width: AppSpacing.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          store.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        Text(store.typeLabel),
                                        if (location.hasPosition)
                                          AppChip(
                                            label: StoreDistance.label(
                                              StoreDistance.haversineMeters(
                                                location.latitude!,
                                                location.longitude!,
                                                store.latitude,
                                                store.longitude,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _locationPrompt(StoreLocationStatus status) {
    if (status == StoreLocationStatus.available) return const SizedBox.shrink();
    final message = switch (status) {
      StoreLocationStatus.gpsOff =>
        'GPS mati. Aktifkan lokasi untuk melihat jarak toko.',
      StoreLocationStatus.denied =>
        'Izin lokasi ditolak. Toko ditampilkan tanpa urutan jarak.',
      StoreLocationStatus.deniedForever =>
        'Izin lokasi ditolak permanen. Toko ditampilkan tanpa urutan jarak.',
      StoreLocationStatus.available => '',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            const SizedBox(height: AppSpacing.s8),
            AppButton(
              label: status == StoreLocationStatus.denied
                  ? 'Aktifkan lokasi'
                  : 'Buka pengaturan',
              onPressed: () async {
                final service = ref.read(storeLocationProvider);
                if (status == StoreLocationStatus.denied) {
                  await _requestLocation();
                } else if (status == StoreLocationStatus.gpsOff) {
                  await service.openLocationSettings();
                } else {
                  await service.openAppSettings();
                }
              },
            ),
            if (status == StoreLocationStatus.denied) ...[
              const SizedBox(height: AppSpacing.s8),
              AppButton(
                label: 'Buka pengaturan',
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    ref.read(storeLocationProvider).openAppSettings(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _routePanel() {
    final route = _route!;
    return SizedBox(
      height: AppSizes.routePanelHeight,
      child: AppCard(
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rute ${StoreDistance.label(route.distanceMeters)} · '
                    '${(route.durationSeconds / 60).ceil()} menit',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _route = null),
                  child: const Text('Hapus rute'),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Moda: '),
                DropdownButton<bool>(
                  value: _walking,
                  items: const [
                    DropdownMenuItem(value: false, child: Text('Motor/Mobil')),
                    DropdownMenuItem(value: true, child: Text('Jalan kaki')),
                  ],
                  onChanged: (value) {
                    if (value == null || _selectedStore == null) return;
                    setState(() => _walking = value);
                    _fetchRoute(_selectedStore!);
                  },
                ),
              ],
            ),
            for (final step in route.steps) Text('• $step'),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchRoute(StoreItem store) async {
    final location = _location;
    if (location?.hasPosition != true) return;
    setState(() {
      _routeLoading = true;
      _routeError = null;
      _route = null;
    });
    try {
      final route = await ref
          .read(storeRouteServiceProvider)
          .fetch(
            latitude: location!.latitude!,
            longitude: location.longitude!,
            destinationLatitude: store.latitude,
            destinationLongitude: store.longitude,
            walking: _walking,
          );
      if (!mounted) return;
      setState(() {
        _route = route;
        _routeError = route == null ? 'Rute tidak ditemukan.' : null;
      });
      if (route != null) {
        if (_sheetController.isAttached) {
          await _sheetController.animateTo(
            AppSizes.mapSheetDetail,
            duration: AppDurations.feedback,
            curve: Curves.easeOut,
          );
        }
        if (!mounted) return;
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: route.points,
            padding: EdgeInsets.only(
              left: AppSpacing.s20,
              right: AppSpacing.s20,
              top: AppSpacing.s20,
              bottom: _bodyHeight * _sheetFraction + AppSpacing.s20,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _routeError =
              'Rute gagal dimuat. Periksa internet lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  Widget _storeIcon(String type, {bool selected = false}) {
    final isBean = type != 'toko_alat';
    return Container(
      width: selected ? AppSizes.mapMarkerSelected : AppSizes.mapMarker,
      height: selected ? AppSizes.mapMarkerSelected : AppSizes.mapMarker,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isBean ? AppColors.primary : AppColors.accent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.surface,
          width: AppSizes.mapMarkerBorder,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Icon(
        isBean ? Icons.coffee_rounded : Icons.storefront_rounded,
        color: AppColors.ink,
      ),
    );
  }
}
