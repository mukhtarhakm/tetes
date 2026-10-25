import 'package:sqflite/sqflite.dart';

typedef DatabaseMigration = Future<void> Function(DatabaseExecutor database);

abstract final class DatabaseMigrations {
  static const schemaVersion = 5;

  static final Map<int, DatabaseMigration> _migrations = {
    1: _migration1,
    2: _migration2,
    3: _migration3,
    4: _migration4,
    5: _migration5,
  };

  static Future<void> create(Database database, int version) {
    return migrate(database, 0, version);
  }

  static Future<void> migrate(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      final migration = _migrations[version];
      if (migration == null) {
        throw StateError('Migrasi database versi $version tidak ditemukan.');
      }
      await migration(database);
    }
  }

  static Future<void> _migration1(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        photo_path TEXT,
        created_at TEXT NOT NULL,
        last_login_at TEXT
      )
    ''');

    await database.execute('''
      CREATE TABLE settings (
        user_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (user_id, key)
      )
    ''');

    await database.execute('''
      CREATE TABLE beans (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        species TEXT NOT NULL,
        bean_type TEXT,
        arabica_percent INTEGER,
        roastery TEXT,
        is_self_roasted INTEGER NOT NULL DEFAULT 0,
        origin TEXT,
        process TEXT,
        roast_level TEXT,
        roast_date TEXT,
        price_original REAL,
        currency TEXT,
        fx_rate REAL,
        fx_date TEXT,
        price_idr_per_kg REAL,
        initial_stock_g REAL NOT NULL DEFAULT 0,
        roastery_notes_tags TEXT,
        roastery_notes_text TEXT,
        best_brew_id TEXT,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await database.execute('''
      CREATE TABLE brews (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        seq INTEGER NOT NULL,
        bean_id TEXT NOT NULL REFERENCES beans(id),
        brewed_at_utc TEXT NOT NULL,
        dose_g REAL NOT NULL,
        ratio REAL NOT NULL,
        water_temp_c INTEGER NOT NULL,
        grind TEXT NOT NULL,
        total_time_s INTEGER NOT NULL,
        taste_score INTEGER NOT NULL,
        taste_tags TEXT NOT NULL,
        notes TEXT,
        ai_advice TEXT,
        cost_idr REAL,
        status TEXT NOT NULL DEFAULT 'aktif',
        prev_hash TEXT NOT NULL,
        hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        UNIQUE (user_id, seq)
      )
    ''');

    await database.execute('''
      CREATE TABLE brew_stages (
        id TEXT PRIMARY KEY,
        brew_id TEXT NOT NULL REFERENCES brews(id),
        position INTEGER NOT NULL,
        name TEXT NOT NULL,
        target_start_s INTEGER NOT NULL,
        target_duration_s INTEGER NOT NULL,
        target_water_cum_g REAL NOT NULL,
        target_pour_g REAL NOT NULL,
        actual_start_s INTEGER,
        actual_duration_s INTEGER,
        actual_water_g REAL,
        drawdown_s INTEGER
      )
    ''');

    await database.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        event_type TEXT,
        location TEXT,
        notes TEXT,
        start_utc TEXT NOT NULL,
        source_zone TEXT NOT NULL,
        reminder_minutes TEXT NOT NULL,
        notif_base_id INTEGER,
        deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await database.execute('''
      CREATE TABLE game_scores (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        level INTEGER NOT NULL,
        accuracy REAL NOT NULL,
        stars INTEGER NOT NULL,
        duration_s INTEGER NOT NULL,
        played_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await database.execute('''
      CREATE TABLE feedback (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        suggestion TEXT,
        impression TEXT,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await database.execute('''
      CREATE TABLE stores (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        store_type TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address TEXT,
        notes TEXT
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_brews_user_seq ON brews(user_id, seq)',
    );
    await database.execute('CREATE INDEX idx_brews_bean ON brews(bean_id)');
    await database.execute(
      'CREATE INDEX idx_stages_brew ON brew_stages(brew_id, position)',
    );
    await database.execute(
      'CREATE INDEX idx_events_user_time ON events(user_id, start_utc)',
    );
  }

  static Future<void> _migration2(DatabaseExecutor database) async {
    await database.execute('ALTER TABLE beans ADD COLUMN pack_size_g REAL');
    await database.execute('ALTER TABLE beans ADD COLUMN process_custom TEXT');
  }

  static Future<void> _migration3(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        bean_id TEXT,
        role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('sent', 'failed'))
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_chat_messages_user_time ON chat_messages(user_id, created_at, id)',
    );
  }

  static Future<void> _migration4(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE chain_anchors (
        user_id TEXT NOT NULL,
        seq INTEGER NOT NULL,
        head_hash TEXT,
        user_key TEXT,
        tx_hash TEXT,
        status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed')),
        explorer_url TEXT,
        anchored_at TEXT NOT NULL,
        verified_at TEXT,
        verify_result TEXT CHECK (verify_result IN ('match', 'mismatch', 'not_found', 'unknown')),
        PRIMARY KEY (user_id, seq)
      )
    ''');
    await database.execute('''
      CREATE TABLE chain_anchor_cooldowns (
        user_id TEXT PRIMARY KEY,
        retry_after_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _migration5(DatabaseExecutor database) async {
    await database.execute(
      "ALTER TABLE brews ADD COLUMN custom_taste_tags TEXT NOT NULL DEFAULT '[]'",
    );
  }
}
