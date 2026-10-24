import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/app/navigation/app_shell.dart';
import 'package:tetes/app/theme/tokens.dart';
import 'package:tetes/core/notifications/notification_coordinator.dart';
import 'package:tetes/core/notifications/notification_service.dart';
import 'package:tetes/core/ui/app_avatar.dart';
import 'package:tetes/core/ui/app_bottom_nav.dart';
import 'package:tetes/core/ui/bean_icon.dart';
import 'package:tetes/core/ui/rating_stars.dart';
import 'package:tetes/data/db/app_database.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/db/database_provider.dart';
import 'package:tetes/data/repositories/chain_anchor_repo.dart';
import 'package:tetes/data/repositories/user_repo.dart';
import 'package:tetes/features/anchor/state/chain_anchor_status.dart';
import 'package:tetes/data/sync/sync_service.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/features/auth/state/session_controller.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/beans/state/bean_providers.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/brew_plan.dart';
import 'package:tetes/features/explore/event_model.dart';
import 'package:tetes/features/explore/explore_screen.dart';
import 'package:tetes/features/explore/store_location.dart';
import 'package:tetes/features/explore/store_screen.dart';
import 'package:tetes/data/repositories/event_repo.dart';
import 'package:tetes/features/home/home_screen.dart';
import 'package:tetes/features/journal/journal_model.dart';
import 'package:tetes/features/profile/profile_screen.dart';

import '../../core/notifications/fake_notification_service.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('sapaan pukul 01.00 malam dan berganti pagi pukul 05.00', () {
    expect(HomeScreen.greetingForHour(1), 'Selamat malam');
    expect(HomeScreen.greetingForHour(4), 'Selamat malam');
    expect(HomeScreen.greetingForHour(5), 'Selamat pagi');
    expect(HomeScreen.greetingForHour(11), 'Selamat siang');
  });

  test('Beranda membaca keadaan kosong dari SQLite tanpa jaringan', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.schemaVersion,
        onConfigure: AppDatabase.configureDatabase,
        onCreate: DatabaseMigrations.create,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(AsyncData(database)),
        sessionControllerProvider.overrideWith(_AuthenticatedSession.new),
      ],
    );
    try {
      final data = await container.read(homeDataProvider.future);
      expect(data.beans, isEmpty);
      expect(data.latestBrew, isNull);
      expect(data.nextEvent, isNull);
    } finally {
      container.dispose();
      await database.close();
    }
  });
  testWidgets('bar empat item, Logout tidak terpilih, dan avatar berinisial', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final items = [
      const AppBottomNavItem(label: 'Beranda', icon: Icons.home_rounded),
      const AppBottomNavItem(
        label: 'Profil',
        icon: Icons.person_rounded,
        iconWidget: AppAvatar(
          username: 'Rais',
          size: AppSizes.navigationAvatar,
        ),
      ),
      const AppBottomNavItem(
        label: 'Saran & Kesan',
        icon: Icons.rate_review_outlined,
      ),
      const AppBottomNavItem(
        label: 'Logout',
        icon: Icons.logout_rounded,
        isAction: true,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            items: items,
            currentIndex: 1,
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(AppBottomNavItem), findsNothing);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Saran & Kesan'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    for (final label in ['Beranda', 'Profil', 'Saran & Kesan', 'Logout']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
    }
    expect(find.text('R'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Logout' &&
            widget.properties.selected == false,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('avatar Profil memakai foto bila tersedia', (tester) async {
    final file = File('${Directory.systemTemp.path}/tetes_avatar_test.png');
    file.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aZkAAAAASUVORK5CYII=',
      ),
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AppAvatar(
          username: 'Rais',
          photo: file,
          size: AppSizes.navigationAvatar,
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets(
    'Beranda kosong dan terisi tanpa overflow pada 320 dan teks 1,3x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpHome(
        tester,
        const HomeData(
          beans: [],
          latestBrew: null,
          nextEvent: null,
          againPlan: null,
        ),
      );
      expect(find.text('Tambah biji pertamamu'), findsOneWidget);
      expect(find.text('Tambah biji'), findsOneWidget);
      expect(find.text('Seduh lagi, pengaturan terbaik'), findsNothing);
      await tester.scrollUntilVisible(find.text('Semua stok aman'), 150);
      expect(find.text('Semua stok aman'), findsOneWidget);
      expect(find.text('Belum ada event'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      final bean = _bean();
      final brew = _brew();
      await _pumpHome(
        tester,
        HomeData(
          beans: [bean],
          latestBrew: brew,
          nextEvent: EventItem(
            id: 'event-1',
            name: 'Cupping',
            eventType: 'cupping',
            startUtc: DateTime.now().toUtc().add(const Duration(days: 1)),
            sourceZone: 'Asia/Jakarta',
            reminderMinutes: '30',
          ),
          againPlan: BrewCalculator.createDefault(
            beanId: bean.id,
          ).copyWith(ratio: 15.5),
        ),
      );
      expect(find.text('Seduh lagi, pengaturan terbaik'), findsOneWidget);
      expect(find.textContaining('1:15.5'), findsOneWidget);
      expect(find.textContaining('1:15.5.0'), findsNothing);
      expect(find.byType(RatingStars), findsWidgets);
      expect(find.text('4/5'), findsWidgets);
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cupping'), findsOneWidget);
      expect(
        tester.getRect(find.text('Stok menipis')).left,
        greaterThanOrEqualTo(0),
      );
      expect(
        tester.getRect(find.text('Event berikutnya')).right,
        lessThanOrEqualTo(320),
      );
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(BeanIcon), findsOneWidget);
      expect(
        tester.getSize(find.byType(BeanIcon)),
        const Size.square(AppSizes.navigationIcon),
      );
    },
  );

  testWidgets('username panjang dengan underscore tidak meluber pada 320', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpHome(
      tester,
      const HomeData(
        beans: [],
        latestBrew: null,
        nextEvent: null,
        againPlan: null,
      ),
      username: 'pengguna_dengan_nama_sangat_panjang',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Logout tetap di Beranda dan menampilkan jumlah pending', (
    tester,
  ) async {
    final notifications = _LaunchNotificationService();
    await _pumpShell(tester, notifications);
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ada 2 data belum tersinkron. Tetap keluar?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Beranda'), findsOneWidget);
  });

  testWidgets('status sinkron membuka Profil', (tester) async {
    await _pumpShell(tester, _LaunchNotificationService());
    await tester.tap(find.text('Tersinkron'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  for (final (payload, screen) in [
    ('stock', StoreScreen),
    ('event:event-1', EventAgendaScreen),
  ]) {
    testWidgets('payload $payload membuka layar fitur penuh', (tester) async {
      final notifications = _LaunchNotificationService(payload);
      await _pumpShell(tester, notifications);
      expect(find.byType(screen), findsOneWidget);
      expect(find.byType(AppBottomNav), findsNothing);
    });
  }

  testWidgets('payload pengingat seduh membuka Beranda', (tester) async {
    await _pumpShell(tester, _LaunchNotificationService('brew'));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('payload saat aplikasi aktif membuka Agenda dan Toko', (
    tester,
  ) async {
    final notifications = _LaunchNotificationService();
    await _pumpShell(tester, notifications);
    notifications.onTap?.call('event:event-1');
    await tester.pumpAndSettle();
    expect(find.byType(EventAgendaScreen), findsOneWidget);
    notifications.onTap?.call('stock');
    await tester.pumpAndSettle();
    expect(find.byType(StoreScreen), findsOneWidget);
    notifications.onTap?.call('brew');
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(StoreScreen), findsNothing);
  });

  testWidgets('kembali dari Profil dan Saran & Kesan menuju Beranda', (
    tester,
  ) async {
    await _pumpShell(tester, _LaunchNotificationService());
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.text('Saran & Kesan'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  HomeData data, {
  String username = 'Rais',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeDataProvider.overrideWith((ref) async => data),
        homeIdentityProvider.overrideWith(
          (ref) async => HomeIdentity(username, null),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: HomeScreen(
            syncStatus: null,
            syncError: null,
            syncLoading: false,
            onOpenSync: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpShell(
  WidgetTester tester,
  NotificationService notifications,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        appSyncServiceFactoryProvider.overrideWith(
          (ref) =>
              () async => _FakeSyncService(),
        ),
        beanListProvider.overrideWith(_EmptyBeans.new),
        eventRepositoryProvider.overrideWith((ref) async => _EmptyEvents()),
        storeListProvider.overrideWith((ref) async => const []),
        storeLocationProvider.overrideWithValue(_NoLocation()),
        notificationCoordinatorProvider.overrideWith(
          (ref) async => FakeNotificationCoordinator(),
        ),
        sessionControllerProvider.overrideWith(_AuthenticatedSession.new),
        chainAnchorStatusProvider.overrideWith(_IdleChainAnchor.new),
        clearChainAnchorsProvider.overrideWithValue((_) async {}),
        userRepositoryProvider.overrideWith((ref) async => _UserRepository()),
        homeDataProvider.overrideWith(
          (ref) async => const HomeData(
            beans: [],
            latestBrew: null,
            nextEvent: null,
            againPlan: null,
          ),
        ),
        homeIdentityProvider.overrideWith(
          (ref) async => const HomeIdentity('Rais', null),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) => ref
            .watch(sessionControllerProvider)
            .when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (_) => const MaterialApp(home: AppShell()),
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _IdleChainAnchor extends ChainAnchorController {
  @override
  Future<ChainAnchorStatus> build() async =>
      const ChainAnchorStatus(ChainAnchorPhase.noBrews);

  @override
  Future<void> requestAfterPush(String userId) async {}

  @override
  Future<void> resumePending(String userId) async {}
}

class _AuthenticatedSession extends SessionController {
  @override
  Future<SessionState> build() async =>
      const SessionState.authenticated('user-1');
}

class _EmptyBeans extends BeanListController {
  @override
  Future<List<Bean>> build() async => const [];
}

class _EmptyEvents extends Fake implements EventRepository {
  @override
  Future<List<EventItem>> listActive(String userId) async => const [];
}

class _NoLocation extends StoreLocationService {
  @override
  Future<StoreLocationResult> read({bool request = false}) async =>
      const StoreLocationResult(StoreLocationStatus.denied);
}

class _UserRepository extends Fake implements UserRepository {
  @override
  Future<int> countPendingSyncData(String userId) async => 2;
}

class _FakeSyncService extends Fake implements SyncService {
  @override
  Future<SyncStatus> run({
    required String userId,
    bool retryErrors = false,
  }) async => const SyncStatus(pendingCount: 0, errorCount: 0);
  @override
  Future<SyncStatus> status(String userId) async =>
      const SyncStatus(pendingCount: 0, errorCount: 0);
  @override
  void close() {}
}

class _LaunchNotificationService extends FakeNotificationService {
  _LaunchNotificationService([this.payload]);
  final String? payload;
  @override
  Future<String?> launchPayload() async => payload;
}

Bean _bean() => const Bean(
  id: 'bean-1',
  userId: 'user-1',
  name: 'Gayo',
  species: BeanSpecies.arabika,
  isSelfRoasted: false,
  initialStockG: 200,
  remainingStockG: 10,
  roasteryNotesTags: [],
  archived: false,
  createdAt: '2026-10-22T00:00:00Z',
  updatedAt: '2026-10-22T00:00:00Z',
  syncStatus: 'pending',
  brewCount: 1,
);

BrewJournalItem _brew() => const BrewJournalItem(
  id: 'brew-1',
  userId: 'user-1',
  seq: 1,
  beanId: 'bean-1',
  beanName: 'Gayo',
  isBestBrew: true,
  brewedAtUtc: '2026-10-22T00:00:00Z',
  doseG: 15,
  ratio: 16,
  waterTempC: 93,
  grind: Grind.sedang,
  totalTimeS: 180,
  tasteScore: 4,
  tasteTags: ['manis'],
  status: 'aktif',
  syncStatus: 'pending',
  hash: 'hash',
);
