# DATA_MODEL: Tetes

Dokumen ini adalah sumber kebenaran untuk tabel, tipe data, dan aturan hash chain. **Jangan mengubah nama kolom, format hash, atau urutan field tanpa memperbarui dokumen ini dan kedua sisi (Flutter dan Edge Function) sekaligus.**

Terkait: `PRD.md`, `ARCHITECTURE.md`.

## 1. Konvensi

| Hal | Aturan |
|---|---|
| ID | ID data aplikasi adalah UUID v4 teks huruf kecil yang dibuat di Flutter. `users.id` dan `sessions.id` dibuat server |
| Waktu | Disimpan sebagai teks ISO 8601 **UTC** tanpa milidetik, contoh `2026-10-17T08:30:00Z` |
| Boolean | SQLite: `INTEGER` 0 atau 1. Postgres: `boolean` |
| Uang | `REAL` dalam rupiah (IDR). Harga asli disimpan dalam mata uang aslinya |
| Nama kolom | `snake_case`, bahasa Inggris |
| Nilai enum | Teks huruf kecil, tanpa spasi (contoh `sedang_halus`) |
| Kepemilikan | Tiap tabel data lokal dan server memakai `user_id` yang merujuk pengguna yang sama |
| `sync_status` | `pending`, `synced`, atau `error` (hanya di SQLite) |
| Hapus | Beberapa tabel memakai `deleted` (soft delete). Entri seduhan tidak pernah dihapus |

`user_id` lokal dan server adalah **nilai yang sama**, berasal dari `users.id` yang dibuat server saat register. Baris yang dikirim atau ditarik tidak perlu mengubah ID pengguna.

## 2. Enum

| Nama | Nilai |
|---|---|
| `species` | `arabika`, `robusta`, `campuran` |
| `bean_type` | `single_origin`, `blend` |
| `process` | `washed`, `natural`, `honey`, `lainnya` |
| `roast_level` | `light`, `medium`, `dark` |
| `grind` | `sangat_halus`, `halus`, `sedang_halus`, `sedang`, `sedang_kasar`, `kasar` |
| `taste_tag` | `asam`, `pahit`, `hambar`, `seimbang`, `manis`, `cokelat`, `buah`, `kacang`, `floral`, `karamel`, `rempah` |
| `brew_status` | `aktif`, `dibatalkan` |
| `event_type` | `pameran`, `lomba`, `cupping`, `workshop`, `lainnya` |
| `stage_name` | `bloom`, `pouring_2`, `pouring_3`, `pouring_4`, `pouring_5` |

Daftar `taste_tag` boleh bertambah, tapi **nilai yang sudah dipakai di entri tidak boleh diganti nama**, karena ikut di-hash.

## 3. SQLite (lokal)

```sql
CREATE TABLE users (
  id              TEXT PRIMARY KEY,
  username        TEXT NOT NULL UNIQUE,
  photo_path      TEXT,
  created_at      TEXT NOT NULL,
  last_login_at   TEXT
);

CREATE TABLE settings (
  user_id  TEXT NOT NULL,
  key      TEXT NOT NULL,
  value    TEXT NOT NULL,
  PRIMARY KEY (user_id, key)
);
-- key yang dipakai:
--   biometric_enabled        '0' | '1'
--   brew_reminder_enabled    '0' | '1'
--   brew_reminder_time       'HH:MM' (waktu lokal)
--   brew_reminder_days       '1,2,3,4,5,6,7' (1 = Senin)
--   low_stock_threshold_g    default '15'
--   last_sync_at             waktu UTC
--   fx_cache                 JSON kurs terakhir + tanggal

CREATE TABLE beans (
  id                   TEXT PRIMARY KEY,
  user_id              TEXT NOT NULL,
  name                 TEXT NOT NULL,
  species              TEXT NOT NULL,          -- enum species
  bean_type            TEXT,                   -- enum bean_type
  arabica_percent      INTEGER,                -- 0-100, hanya jika species='campuran'
  roastery             TEXT,                   -- boleh kosong
  is_self_roasted      INTEGER NOT NULL DEFAULT 0,
  origin               TEXT,                   -- teks bebas, bukan fitur pelacakan
  process              TEXT,                   -- enum process; 'lainnya' memakai process_custom
  process_custom       TEXT,                   -- proses bebas, maksimal 40 karakter
  roast_level          TEXT,                   -- enum roast_level
  roast_date           TEXT,                   -- tanggal (YYYY-MM-DD)
  pack_size_g          REAL,                   -- ukuran satu kemasan dalam gram
  price_original       REAL,                   -- harga satu kemasan dalam mata uang asli
  currency             TEXT,                   -- kode ISO: IDR, USD, EUR, JPY, ...
  fx_rate              REAL,                   -- 1 unit currency = fx_rate IDR, saat input
  fx_date              TEXT,                   -- tanggal kurs
  price_idr_per_kg     REAL,
  initial_stock_g      REAL NOT NULL DEFAULT 0,-- total gram yang dimiliki
  roastery_notes_tags  TEXT,                   -- tag dipisah koma, urut abjad
  roastery_notes_text  TEXT,
  best_brew_id         TEXT,                   -- menunjuk brews.id, boleh kosong
  archived             INTEGER NOT NULL DEFAULT 0,
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL,
  sync_status          TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE brews (
  id                 TEXT PRIMARY KEY,
  user_id            TEXT NOT NULL,
  seq                INTEGER NOT NULL,         -- urutan rantai per user, mulai 1, tanpa celah
  bean_id            TEXT NOT NULL REFERENCES beans(id),
  brewed_at_utc      TEXT NOT NULL,
  dose_g             REAL NOT NULL,
  ratio              REAL NOT NULL,            -- 16 berarti 1:16
  water_temp_c       INTEGER NOT NULL,
  grind              TEXT NOT NULL,            -- enum grind
  total_time_s       INTEGER NOT NULL,         -- detik aktif dari mulai sampai sesi berakhir; tidak termasuk jeda
  taste_score        INTEGER NOT NULL,         -- 1-5
  taste_tags         TEXT NOT NULL,            -- dipisah koma, urut abjad
  notes              TEXT,                     -- tidak ikut hash
  ai_advice          TEXT,                     -- JSON, tidak ikut hash
  cost_idr           REAL,                     -- tidak ikut hash
  status             TEXT NOT NULL DEFAULT 'aktif',  -- tidak ikut hash
  prev_hash          TEXT NOT NULL,            -- '0' untuk seq = 1
  hash               TEXT NOT NULL,            -- SHA-256 hex huruf kecil
  created_at         TEXT NOT NULL,
  sync_status        TEXT NOT NULL DEFAULT 'pending',
  UNIQUE (user_id, seq)
);

CREATE TABLE brew_stages (
  id                     TEXT PRIMARY KEY,
  brew_id                TEXT NOT NULL REFERENCES brews(id),
  position               INTEGER NOT NULL,     -- 1, 2, 3, ...
  name                   TEXT NOT NULL,        -- enum stage_name
  target_start_s         INTEGER NOT NULL,
  target_duration_s      INTEGER NOT NULL,
  target_water_cum_g     REAL NOT NULL,        -- air kumulatif target
  target_pour_g          REAL NOT NULL,
  actual_start_s         INTEGER,              -- selalu NULL; waktu aktual tahap tidak dicatat
  actual_duration_s      INTEGER,              -- selalu NULL; waktu aktual tahap tidak dicatat
  actual_water_g         REAL,                 -- diisi manual
  drawdown_s             INTEGER               -- hanya di tahap terakhir; NULL jika Lewati atau batas 10 menit
);

`brews.total_time_s` adalah jumlah detik dari mulai sampai sesi berakhir, **tidak termasuk waktu jeda**. Aturan ini berlaku untuk akhir melalui **Air habis**, **Lewati**, dan **batas drawdown 10 menit**. Nilai `total_time_s` ikut di-hash sesuai bagian 5.3. `brew_stages.actual_start_s` dan `actual_duration_s` selalu `NULL`; `drawdown_s` hanya diisi pada tahap terakhir bila pengguna menekan Air habis, dihitung dari akhir tuangan terakhir.

CREATE TABLE events (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL,
  name              TEXT NOT NULL,
  event_type        TEXT,
  location          TEXT,
  notes             TEXT,
  start_utc         TEXT NOT NULL,
  source_zone       TEXT NOT NULL,             -- nama IANA: Asia/Jakarta, Asia/Makassar, Asia/Jayapura, Europe/London
  reminder_minutes  TEXT NOT NULL,             -- contoh '1440,180,30'
  notif_base_id     INTEGER,                   -- dasar ID notifikasi lokal
  deleted           INTEGER NOT NULL DEFAULT 0,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL,
  sync_status       TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE game_scores (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL,
  level         INTEGER NOT NULL,
  accuracy      REAL NOT NULL,                 -- 0.0 sampai 1.0
  stars         INTEGER NOT NULL,              -- 1-3
  duration_s    INTEGER NOT NULL,
  played_at     TEXT NOT NULL,
  sync_status   TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE feedback (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL,
  suggestion    TEXT,
  impression    TEXT,
  created_at    TEXT NOT NULL,
  sync_status   TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE stores (                           -- data toko untuk LBS, diisi manual
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  store_type  TEXT NOT NULL,                    -- 'toko_biji' | 'toko_alat' | 'roastery'
  latitude    REAL NOT NULL,
  longitude   REAL NOT NULL,
  address     TEXT,
  notes       TEXT
);

CREATE INDEX idx_brews_user_seq   ON brews(user_id, seq);
CREATE INDEX idx_brews_bean       ON brews(bean_id);
CREATE INDEX idx_stages_brew      ON brew_stages(brew_id, position);
CREATE INDEX idx_events_user_time ON events(user_id, start_utc);
```

Data toko (`stores`) bukan data pengguna. Tabel ini diisi dari berkas seed bawaan aplikasi (10-15 titik), tanpa sinkronisasi dan tanpa `user_id`. Hanya toko biji, toko alat seduh, dan roastery. **Bukan kedai kopi.**

Hal yang disimpan di luar database:
- Session aktif: token, `user_id`, dan `expires_at` di secure storage, bukan SQLite.
- `pending_revoke_token`: token session lama yang belum berhasil dicabut karena offline, di secure storage terpisah.
- Foto profil: berkas di folder aplikasi, SQLite hanya menyimpan path.

## 4. Aturan Turunan

**Stok tersisa (g)** = `initial_stock_g` − jumlah `dose_g` seluruh `brews` aktif untuk biji itu. Dihitung lewat query, **tidak disimpan**, supaya konsisten saat seduhan dibatalkan. Notifikasi stok menipis dipicu saat hasil ini di bawah `low_stock_threshold_g` (default 15 g).

**Harga per kg (IDR)** = `price_original` × `fx_rate` ÷ `pack_size_g` × 1000. `price_original` adalah harga satu kemasan dalam mata uang asli, bukan harga per kg.

**Biaya seduhan (IDR)** = `dose_g` × `price_idr_per_kg` ÷ 1000. Disimpan di `brews.cost_idr` saat simpan.

**Pengaturan terbaik biji:** di antara seduhan aktif biji itu, skor `taste_score` tertinggi. Jika seri, pilih yang terbaru. Otomatis dihitung ulang setiap seduhan disimpan atau dibatalkan. Pengguna boleh menimpa manual (`best_brew_id`). Jika seduhan terpilih dibatalkan, hitung ulang otomatis.

**Hari sejak roasting** = tanggal hari ini − `roast_date`, dihitung saat ditampilkan.

**Total air** = `dose_g` × `ratio`.

**Validasi:**

| Field | Aturan |
|---|---|
| `username` | 3-30 karakter, huruf kecil, angka, titik, garis bawah. Unik |
| password | 8 sampai 128 karakter |
| `dose_g` | 5 sampai 60 |
| `ratio` | 10 sampai 20 |
| `water_temp_c` | 80 sampai 100 |
| `taste_score` | 1 sampai 5 |
| jumlah pouring | 1 sampai 5 |
| `arabica_percent` | 0 sampai 100, hanya jika `species = campuran` |
| `pack_size_g` | Jika diisi harus > 0; wajib bila `price_original` diisi |
| `price_original` | Jika diisi harus > 0 dan memerlukan `currency` serta `pack_size_g` |
| `initial_stock_g` | > 0 |
| `process_custom` | Wajib bila `process = lainnya`, maksimal 40 karakter; kosong untuk proses lain |
| `roastery_notes_tags` | Maksimal 10 tag total; tag sendiri di-trim, huruf kecil, tanpa koma, maksimal 30 karakter, dan tidak boleh kembar |
| pengingat event | Setidaknya satu, maksimal tiga |

Angka batas ini adalah default awal, boleh disesuaikan, tapi ubah di sini dulu.

## 5. Hash Chain

### 5.1 Cakupan

Hash chain hanya untuk tabel **`brews`**. Tabel lain tidak ikut.

### 5.2 Rantai per pengguna

Entri diurutkan menurut `seq` (1, 2, 3, ...). Tidak boleh ada celah. `seq` baru = `seq` terakhir pengguna + 1, dihitung di dalam transaksi SQLite yang sama dengan penyimpanan entri.

- Entri pertama (`seq = 1`): `prev_hash = "0"`.
- Entri berikutnya: `prev_hash` = `hash` entri dengan `seq` sebelumnya, **termasuk entri berstatus dibatalkan**. Entri dibatalkan tetap bagian rantai.

### 5.3 Teks yang di-hash

Sepuluh field, digabung dengan karakter `|`, dalam urutan ini, tanpa spasi tambahan dan tanpa baris baru:

```
bean_id | dose_g | ratio | water_temp_c | grind | total_time_s | taste_score | taste_tags | brewed_at_utc | prev_hash
```

Aturan format tiap field:

| Field | Format |
|---|---|
| `bean_id` | UUID huruf kecil |
| `dose_g` | **Selalu satu angka desimal**: `15.0`, `18.5`, `20.0` |
| `ratio` | `1:` diikuti angka. Bilangan bulat tanpa desimal (`1:16`). Jika ada desimal, tepat satu angka (`1:15.5`) |
| `water_temp_c` | Bilangan bulat, `92` |
| `grind` | Nilai enum, `sedang` |
| `total_time_s` | Bilangan bulat |
| `taste_score` | Bilangan bulat 1-5 |
| `taste_tags` | Tag diurutkan abjad, dipisah koma tanpa spasi: `asam,cokelat` |
| `brewed_at_utc` | `YYYY-MM-DDTHH:MM:SSZ` |
| `prev_hash` | 64 karakter hex huruf kecil, atau `0` |

Karakter `|` dan koma tidak boleh muncul di dalam nilai field. `taste_tags` hanya berisi nilai dari enum, jadi aman.

### 5.4 Perhitungan

```
hash = SHA-256( UTF-8( teks_yang_di_hash ) )   // hasil: 64 karakter hex huruf kecil
```

### 5.5 Field yang tidak ikut hash (boleh berubah)

`notes`, `ai_advice`, `cost_idr`, `status`, `sync_status`, `created_at`. Field di tabel `brew_stages` juga tidak ikut hash.

### 5.6 Larangan

- Tidak ada edit atau hapus entri `brews`. Koreksi dilakukan dengan `status = dibatalkan`.
- Tidak ada layar yang boleh mengubah 10 field yang di-hash setelah disimpan.
- Satu fungsi `buildHashInput()` dipakai di Flutter dan di Edge Function. Jangan menulis ulang format di tempat lain.

### 5.7 Vektor uji (wajib lolos di Flutter dan Edge Function)

**Entri 1** (`seq = 1`)

```
bean_id       = 11111111-1111-4111-8111-111111111111
dose_g        = 15.0
ratio         = 16
water_temp_c  = 92
grind         = sedang
total_time_s  = 195
taste_score   = 3
taste_tags    = asam,cokelat
brewed_at_utc = 2026-10-17T08:30:00Z
prev_hash     = 0
```

Teks:
```
11111111-1111-4111-8111-111111111111|15.0|1:16|92|sedang|195|3|asam,cokelat|2026-10-17T08:30:00Z|0
```
Hash yang benar:
```
bff83b62a198e4eeb8feb965b721030ae4e0c6c4122cf8c2e6acf8481bd00e34
```

**Entri 2** (`seq = 2`)

```
bean_id       = 11111111-1111-4111-8111-111111111111
dose_g        = 15.0
ratio         = 15
water_temp_c  = 90
grind         = sedang
total_time_s  = 185
taste_score   = 4
taste_tags    = cokelat,seimbang
brewed_at_utc = 2026-10-18T08:30:00Z
prev_hash     = bff83b62a198e4eeb8feb965b721030ae4e0c6c4122cf8c2e6acf8481bd00e34
```

Teks:
```
11111111-1111-4111-8111-111111111111|15.0|1:15|90|sedang|185|4|cokelat,seimbang|2026-10-18T08:30:00Z|bff83b62a198e4eeb8feb965b721030ae4e0c6c4122cf8c2e6acf8481bd00e34
```
Hash yang benar:
```
2fbdd892eb66dc64c4436c654ad6ada4c6eaaf50252f9cf21c5adb05105fdd3c
```

Dua hash ini dihitung dengan `sha256sum` pada teks di atas. Tes unit di Flutter dan di Edge Function harus menghasilkan nilai yang persis sama. Jika berbeda, periksa format angka, urutan field, dan encoding sebelum yang lain.

### 5.8 Verifikasi

Untuk semua `brews` milik pengguna, urut `seq` naik:
1. `seq` harus berurutan tanpa celah dari 1.
2. `prev_hash` entri ke-n harus sama dengan `hash` entri ke-(n−1) (entri pertama: `0`).
3. Hitung ulang hash dari 10 field. Harus sama dengan `hash` tersimpan.

Hasil: **utuh (N entri)** atau **rantai putus di seq K** (K = entri pertama yang gagal salah satu pemeriksaan).

## 6. Postgres (Supabase)

Semua tabel: **aktifkan Row Level Security tanpa membuat policy apa pun.** Hanya Edge Function (service role) yang mengakses. Aplikasi tidak pernah menyentuh tabel langsung.

```sql
CREATE TABLE users (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username       text NOT NULL UNIQUE,
  password_hash  text NOT NULL,           -- base64, 32 byte hasil PBKDF2-HMAC-SHA256
  salt           text NOT NULL,           -- base64, 16 byte acak per pengguna
  iterations     integer NOT NULL,        -- 600000
  algo           text NOT NULL,           -- 'pbkdf2-hmac-sha256'
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id),
  token_hash  text NOT NULL UNIQUE,        -- SHA-256 hex dari token 32 byte base64url
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL,
  revoked     boolean NOT NULL DEFAULT false
);

CREATE TABLE login_attempts (
  username       text NOT NULL,
  window_start   timestamptz NOT NULL,     -- awal jendela 15 menit menurut waktu server
  attempt_count  integer NOT NULL DEFAULT 0,
  PRIMARY KEY (username, window_start)
);

CREATE TABLE ai_usage (
  user_id       uuid NOT NULL REFERENCES users(id),
  window_start  timestamptz NOT NULL,    -- awal jam
  call_count    integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, window_start)
);
```

Aturan `login_attempts`:
- `window_start` dibulatkan ke awal jendela 15 menit.
- Hitung percobaan berdasarkan username input meskipun username tidak terdaftar.
- Lima percobaan gagal pertama dalam jendela masing-masing menghasilkan `401`; permintaan berikutnya ditolak dengan `429` dan `details.retry_after_s` sebelum PBKDF2 dijalankan.
- Kenaikan `attempt_count` dilakukan atomik melalui RPC `increment_login_attempt(p_username, p_window_start)` dengan `INSERT ... ON CONFLICT DO UPDATE`; hak eksekusi hanya diberikan kepada service role.
- Login berhasil menghapus baris untuk `(username, window_start)` tersebut.
- Pesan kredensial gagal selalu "Username atau password salah".

Tabel data (`beans`, `brews`, `brew_stages`, `events`, `game_scores`, `feedback`) memiliki **kolom yang sama dengan SQLite** dengan perbedaan:
- `user_id` bertipe `uuid NOT NULL REFERENCES users(id)` dan namanya tidak berubah.
- Kolom `sync_status` dihilangkan.
- Kolom waktu memakai `timestamptz`. Untuk `brews.brewed_at_utc`, simpan **juga** teks aslinya di kolom `brewed_at_text` agar verifikasi hash memakai string yang persis sama, bukan hasil format ulang.
- `brews` memiliki `UNIQUE (user_id, seq)` dan `UNIQUE (id)`.
- Boolean memakai tipe `boolean`.
- `brew_stages` memiliki `user_id` juga, supaya pemeriksaan kepemilikan sederhana.

Tabel `stores` tidak ada di server.

## 7. Contoh Query yang Sering Dipakai (SQLite)

```sql
-- Stok tersisa satu biji
SELECT b.initial_stock_g - COALESCE(SUM(br.dose_g), 0) AS stock_g
FROM beans b
LEFT JOIN brews br ON br.bean_id = b.id AND br.status = 'aktif'
WHERE b.id = ?;

-- Pengaturan terbaik otomatis satu biji
SELECT * FROM brews
WHERE bean_id = ? AND status = 'aktif'
ORDER BY taste_score DESC, brewed_at_utc DESC
LIMIT 1;

-- Jurnal dengan filter (contoh)
SELECT br.*, b.name AS bean_name
FROM brews br JOIN beans b ON b.id = br.bean_id
WHERE br.user_id = ?
  AND br.status = 'aktif'
  AND br.taste_score >= ?
  AND (b.name LIKE ? OR b.roastery LIKE ? OR br.taste_tags LIKE ? OR br.notes LIKE ?)
ORDER BY br.brewed_at_utc DESC;

-- Seduhan yang belum tersinkron, berurutan
SELECT * FROM brews
WHERE user_id = ? AND sync_status = 'pending'
ORDER BY seq ASC;
```

## 8. Catatan Migrasi

- Versi skema SQLite disimpan lewat `PRAGMA user_version`. Tiap perubahan skema = migrasi bernomor, bukan menghapus database.
- Migrasi 2 menambahkan `beans.pack_size_g REAL` dan `beans.process_custom TEXT` melalui dua perintah `ALTER TABLE`; data biji lama dibiarkan bernilai `NULL`.
- Menambah kolom opsional aman. Mengubah atau menghapus kolom yang ikut hash **dilarang** setelah ada data.
- Setelah Sprint 3, perubahan pada format hash harus dianggap perubahan besar dan dikonfirmasi dulu.
