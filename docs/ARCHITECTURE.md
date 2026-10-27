# ARCHITECTURE: Tetes

Menjelaskan **bagaimana** Tetes dibangun: stack, struktur kode, alur data, kontrak Edge Function, keamanan, dan aturan kerja. Terkait: `PRD.md` (apa yang dibuat), `DATA_MODEL.md` (tabel dan hash), `UI_SPEC.md` (tampilan).

> Nama paket di bawah adalah kandidat. **Versi tidak ditulis di sini.** Tentukan versi saat pertama kali memasang, cek dokumentasi paket, lalu catat di bagian 12 dan kunci.

## 1. Gambaran Besar

```
┌──────────────────────────── HP (Flutter) ────────────────────────────┐
│ UI ─ State ─ Repository ─ SQLite                                     │
│        │                                                             │
│        ├─ Session lokal + biometrik (token di secure storage)        │
│        ├─ Sensor, notifikasi, lokasi, biometrik (paket perangkat)    │
│        ├─ Klien Sinkronisasi ───────────┐                            │
│        └─ Klien Kurs ─────────────┐     │                            │
└───────────────────────────────────┼─────┼────────────────────────────┘
                                    │     │ HTTPS
                       API kurs     │     ▼
                      (publik)  ◄───┘   Supabase
                                         ├─ PostgREST auth ──► Postgres (RLS auth)
                                         └─ Edge Functions
                                            ├─ sync-push/pull ──► Postgres
                                            └─ ai ──► API LLM (key = secret)
```

**Prinsip:**
1. **Offline-first.** Seduh, jurnal, dan biji jalan tanpa internet. SQLite adalah sumber utama di HP.
2. **Server tipis.** Flutter menangani autentikasi; Edge Function memverifikasi sesi dan sinkronisasi serta memegang rahasia AI.
3. **Rahasia hanya di server.** API key LLM dan service role key tidak pernah ada di Flutter atau Git.
4. **Satu sumber aturan.** Format hash dan skema hanya didefinisikan di `DATA_MODEL.md`.

## 2. Stack

| Lapisan | Pilihan | Catatan |
|---|---|---|
| Aplikasi | Flutter (Dart) | Satu basis kode |
| State | Riverpod | Putuskan di Sprint 1, jangan dicampur dengan pustaka state lain |
| Database lokal | SQLite (`sqflite`) | Migrasi bernomor |
| Penyimpanan aman | `flutter_secure_storage` | Token session, waktu kedaluwarsa, dan token pencabutan tertunda |
| Hash password | `cryptography` 2.9.0 + `cryptography_flutter` 2.3.4 | PBKDF2 native Android, fallback Dart di isolate; salt acak per pengguna, jumlah iterasi disimpan per pengguna |
| Hash chain | SHA-256 (`crypto`) | Aturan di `DATA_MODEL.md` |
| UUID | `uuid` | ID data aplikasi dibuat di Flutter; ID pengguna dan session dibuat server |
| Biometrik | `local_auth` | Konfirmasi penyimpanan kredensial dan login di layar Login |
| Sensor | `sensors_plus` | Accelerometer (goyang), gyroscope (game) |
| Umpan balik sesi | `vibration` + `flutter_ringtone_player` | Getar dan nada sistem saat pergantian tahap dan akhir sesi |
| Notifikasi | `flutter_local_notifications` + `timezone` | Lokal, tanpa server |
| Lokasi | `geolocator` | |
| Peta | `flutter_map` + `latlong2` (OpenStreetMap) | Tanpa key |
| Foto | `image_picker` | |
| HTTP | `http` atau `dio` (pilih satu) | |
| Grafik | `fl_chart` atau `CustomPainter` | Grafik air kumulatif dan skor |
| Backend | Supabase: Postgres + Edge Functions | Login tidak lewat Supabase Auth |
| LLM | Gemini atau OpenAI, dipilih oleh `AI_PROVIDER` | Hanya dari Edge Function |
| Kurs | API publik tanpa key (kandidat Frankfurter) | Dipanggil dari Flutter |

Jika sebuah paket bermasalah, ganti dengan alternatif yang setara **dan catat di `DECISIONS.md`**. Jangan menambah paket baru tanpa persetujuan.

## 3. Struktur Kode Flutter

```
lib/
  main.dart
  app/                      router, tema (dari UI_SPEC.md), konfigurasi
  core/
    ui/                     komponen bersama (tombol, kartu, input, dialog, loading, kosong, error)
    utils/                  waktu (UTC <-> zona), format angka, hash (buildHashInput, sha256)
    config/                 konstanta (URL fungsi, batas validasi, ambang default)
  data/
    db/                     pembuka database, migrasi, DAO
    repositories/           BeanRepo, BrewRepo, EventRepo, ScoreRepo, FeedbackRepo, UserRepo
    secure/                 penyimpanan token session dan data sensitif lokal
    sync/                   SyncClient, antrean, pemetaan baris <-> JSON
    remote/                 AuthClient, FxClient, AiClient
  features/
    auth/   beans/   brew/   journal/   explore/   game/   profile/
      (tiap fitur: screens/, widgets/, state/)
supabase/
  functions/
    (auth Edge Function dihapus)
    sync-push/  sync-pull/  ai/
    _shared/                auth, hash.ts (buildHashInput), validasi, klien DB
  migrations/               SQL tabel server
docs/
```

Aturan lapisan:
- **UI** tidak mengakses SQLite atau HTTP langsung. Hanya lewat state yang memanggil repository.
- **Repository** menjadi satu-satunya pintu ke SQLite.
- **Sinkronisasi** hanya membaca dan menulis lewat repository.
- Warna, ukuran, dan gaya teks **hanya** dari tema (`UI_SPEC.md`), tidak ditulis langsung di layar.

## 4. Autentikasi Lokal dengan Data Supabase

Register dan login memerlukan internet. Flutter menghitung PBKDF2-HMAC-SHA256 (600.000 iterasi untuk akun baru, salt 16 byte, hash 32 byte) lewat native Android bila tersedia, dengan fallback Dart di isolate, lalu memakai PostgREST dengan kunci publik. Login akun lama membaca `iterations` dari baris pengguna. Password, salt, dan hash tidak dicatat di log; token sesi asli serta kredensial biometrik yang diaktifkan pengguna disimpan di secure storage. Tanpa Firebase dan tanpa Supabase Auth.

**Register:** validasi input lokal, lalu `POST users?select=id,username,created_at` dengan `Prefer: return=representation` dan header `x-login-username` yang sama dengan username. Setelah user dibuat, Flutter membuat token acak 32 byte base64url tanpa padding, menyimpan SHA-256 hex token melalui `POST sessions`, dan menyimpan token asli di secure storage. Jika POST sesi gagal, akun tetap ada dan layar mengarahkan pengguna ke Login dengan pesan "Akun dibuat. Silakan masuk."

**Login:** `GET users?username=eq.<username>&select=id,username,password_hash,salt,iterations,algo,created_at&limit=1` wajib membawa `x-login-username`. Flutter selalu menghitung PBKDF2, termasuk dengan parameter dummy bila user tidak ada, lalu membandingkan hash dengan waktu konstan. Lima kegagalan per jendela 15 menit per username disimpan lokal sebagai pengaman UX saja; keberhasilan menghapus penghitung. Sesi baru dibuat lewat `POST sessions`.

**Logout:** token lokal dihapus dan pencabutan offline tetap diantrekan. `PATCH sessions?token_hash=eq.<hash>` dengan `x-token-hash` dan body `{"revoked":true}` mencabut sesi; respons sukses tanpa baris terubah tetap dianggap berhasil.

**Buka aplikasi:** sesi lokal yang belum kedaluwarsa langsung membuka Beranda, termasuk saat offline. Sesi yang kedaluwarsa memerlukan login online. Edge Function `sync-push`, `sync-pull`, dan `ai` tetap memeriksa token lewat `_shared/session.ts` dan tabel `sessions`.

**Login biometrik:** setelah login password berhasil, pengguna dapat mengaktifkan sidik jari melalui tawaran sekali atau saklar Profil. Setelah konfirmasi `local_auth`, aplikasi membaca hash, salt, iterasi, dan algoritma user dari PostgREST dan menyimpannya per username di `flutter_secure_storage`. Password tidak disimpan. Tombol sidik jari hanya tampil jika perangkat mendukung, kredensial tersedia, dan flag lokal aktif. Login biometrik membaca user dari jalur PostgREST yang sama, membandingkan hash dengan `constantTimeEquals` tanpa PBKDF2, lalu membuat sesi seperti login password. Hash berubah, user hilang, atau kunci penyimpanan tidak valid akan menghapus kredensial dan mematikan flag. Logout mempertahankan kredensial; saklar Profil yang dimatikan menghapusnya. Penyimpanan hash ini memiliki risiko setara keterbatasan kunci anon yang sudah didokumentasikan.

**Keterbatasan keamanan:** siapa pun yang memiliki kunci publik Supabase dan mengetahui username dapat membaca `id` serta `password_hash` pengguna itu melalui header `x-login-username`, lalu membuat sesi atas `user_id` tersebut tanpa password. Ini celah nyata pada desain login lokal. Grant kolom dan RLS membatasi pembacaan tanpa header, tetapi tidak membuktikan identitas pemanggil.

Migrasi RLS telah disiapkan, tetapi belum diterapkan oleh pemilik. Klien Flutter baru memerlukan migrasi tersebut sebelum alur online dapat diuji.
`SUPABASE_URL` pada `env/app.json` harus menunjuk proyek yang sama dengan `AppConfig.functionsBaseUrl`, karena klien sync dan AI masih memakai alamat Edge Function tersebut dan hanya mengirim `x-session-token` (fungsi dipasang tanpa verifikasi JWT).
## 5. Alur Fitur Inti

### 5.1 Seduh
```
Pilih biji ─► Atur Seduh (isi dari pengaturan terbaik, atau dari AI) ─► plan tahap
 ─► Sesi: timer per tahap, ketuk "tahap berikutnya" mencatat waktu aktual
 ─► Hasil: isi berat air aktual (manual), skor, tag rasa, catatan
 ─► Simpan: transaksi SQLite {seq baru, hash, brews, brew_stages}
 ─► jadwalkan cek stok menipis ─► sync_status = pending
```
- Satu transaksi SQLite saat simpan: hitung `seq`, `prev_hash`, `hash`, tulis `brews` dan `brew_stages`. Gagal berarti tidak ada yang tersimpan.
- Dialog konfirmasi sebelum simpan: data inti tidak bisa diubah setelahnya.
- Accelerometer: goyang melebihi ambang memulai atau mereset timer. Beri jeda singkat agar tidak terpicu berulang.

### 5.2 Jurnal
Semua pencarian dan filter lewat query SQLite (contoh di `DATA_MODEL.md` bagian 7). Tidak butuh internet. Entri dibatalkan tidak masuk statistik, stok, pengaturan terbaik, dan data untuk AI.

### 5.3 Event dan notifikasi
- Simpan `start_utc` + `source_zone` (nama zona IANA). Tampilkan di WIB, WITA, WIT, dan London dengan paket `timezone`. **Jangan menyimpan selisih jam tetap** (London berpindah antara GMT dan BST).
- Jadwalkan notifikasi lokal untuk tiap pengingat. ID notifikasi: `notif_base_id * 10 + indeks pengingat`.
- Saat aplikasi dibuka: batalkan lalu jadwalkan ulang semua notifikasi mendatang (event, pengingat seduh), karena notifikasi terjadwal bisa hilang setelah HP restart.
- Minta izin notifikasi saat pertama kali dibutuhkan. Uji izin alarm tepat waktu di Android di HP asli.

### 5.4 Kurs
- Saat input harga biji bermata uang asing: panggil API kurs, hitung `price_idr_per_kg`, simpan `fx_rate` dan `fx_date`.
- Offline: pakai kurs terakhir di `settings.fx_cache` dan tampilkan tanggalnya.
- Kurs referensi, bukan kurs jual-beli. Cukup dicatat di laporan.

### 5.5 LBS
- Ambil lokasi (dengan izin), baca `stores` dari SQLite, hitung jarak, urutkan, tampilkan marker. Ketuk marker untuk detail dan tombol navigasi.
- Jika izin ditolak: tampilkan daftar toko tanpa urutan jarak dan pesan yang menjelaskan.

### 5.6 Game
- Loop per frame: baca sensor, perbarui posisi titik, cek zona, perbarui bar dan akurasi, cek akhir.
- Kontrol gyroscope dengan kalibrasi posisi nol dan peredaman. Jika terlalu sulit dikontrol di HP, cadangan adalah accelerometer untuk game (konfirmasi dulu karena memengaruhi pemenuhan "2 sensor").
- Tidak masuk hash chain dan tidak terhubung ke data seduhan.

## 6. Sinkronisasi

### 6.1 Identitas
- `user_id` berasal dari `users.id` yang dibuat server dan nilainya sama pada SQLite serta Postgres.
- Token session adalah nilai acak 32 byte berformat base64url. Flutter menyimpan token asli di secure storage; server hanya menyimpan SHA-256 token.
- Fungsi terlindungi (`sync-push`, `sync-pull`, `ai`) menerima `x-session-token: <token>`. Auth memakai PostgREST dan header pada bagian 4.
- Token valid bila hash ditemukan, belum dicabut, dan `expires_at` belum lewat.

### 6.2 Urutan
1. Bila perlu menerima data server, jalankan `sync-pull` sebelum push.
2. Kirim data `pending` ke `sync-push` dalam urutan tabel: `beans` → `brews` (+ `brew_stages`) → `events` → `game_scores` → `feedback`.
3. `brews` dikirim urut `seq` naik, per kelompok (misalnya 20). **Jika satu entri ditolak, hentikan kelompok itu**, karena entri sesudahnya pasti gagal.
4. Respons memuat daftar `accepted` dan `rejected`. Tandai `synced` atau `error` dengan pesan yang jelas.
5. Pemicu: otomatis saat online dan ada data pending, serta tombol manual "Sinkronkan sekarang" di Profil.

### 6.3 Idempoten
- Upsert berdasarkan `id`. Mengirim ulang baris yang sama tidak menghasilkan duplikat.
- Entri `brews` yang sudah ada di server dengan `hash` sama dianggap sukses. Hanya field tidak-hash (`notes`, `ai_advice`, `cost_idr`, `status`) yang diperbarui. Jika field yang di-hash berbeda dari yang tersimpan, **tolak** dengan alasan `tamper`.

### 6.4 Pull dan konflik rantai
Sebelum meminta pull, Flutter memverifikasi ulang urutan `seq`, `prev_hash`, dan hash seluruh rantai lokal. `sync-pull` lalu membandingkan pasangan `seq` dan `hash` lokal terhadap rantai server per urutan. Status berikut berlaku untuk rantai `brews`; tabel non-rantai tetap diproses berdasarkan ID yang belum ada.

- **Lokal kosong:** tarik semua data. Tarik `beans` sebelum `brews`, verifikasi seluruh rantai, lalu simpan apa adanya dalam transaksi lokal.
- **Lokal sama dengan server:** tidak ada `brews` yang ditarik.
- **Lokal prefix valid dari server:** tarik suffix server dengan `seq` lebih besar dari `seq` lokal terakhir. Verifikasi hubungan `prev_hash` dan hash setiap entri sebelum menyimpan.
- **Server prefix dari lokal:** tidak ada `brews` yang ditarik; lanjutkan push data lokal yang belum ada di server.
- **Bercabang:** bila hash berbeda pada `seq` yang sama, atau kedua sisi memiliki entri yang tidak dimiliki sisi lain, jangan gabungkan otomatis.

Untuk `beans`, `game_scores`, dan `feedback`, pull hanya menyisipkan ID yang belum ada. Khusus `events`, pull membawa juga baris `deleted` dan memperbarui baris lokal hanya jika `updated_at` server lebih baru serta status lokal bukan `pending`. Tiga tabel ini dipaginasi dengan kursor `(server_updated_at, id)` yang dibuat server, sehingga baris dengan cap waktu klien lama tetap tertarik. Jika `updated_at` event sama, versi yang sudah tersimpan menang. Perubahan `notes` atau `status` seduhan dari perangkat lain belum ditarik pada v1.

Saat rantai bercabang, tampilkan pilihan:
1. **Pulihkan ulang dari server:** konfirmasi eksplisit menyebut jumlah seluruh data lokal yang akan dikosongkan, termasuk jumlah entri `pending`. Setelah pengguna setuju, kosongkan data pengguna yang disinkronkan (`beans`, `brews`, `brew_stages`, `events`, `game_scores`, `feedback`), lalu lakukan pull penuh dan verifikasi sebelum commit.
2. **Batal:** pertahankan data lokal dan jangan lanjutkan sinkronisasi.

### 6.5 Cakupan multi-perangkat v1
- Akun dapat login di lebih dari satu perangkat, tetapi penulisan serentak tidak digabung otomatis.
- Sebelum membuat seduhan di perangkat baru atau tertinggal, tarik data server lebih dahulu.
- Server selalu menolak `brews` baru bila `seq` atau `prev_hash` tidak melanjutkan ujung rantai server.
- Pull menangani rantai kosong atau prefix yang identik, bukan rekonsiliasi dua cabang.

## 7. Kontrak Edge Function

Semua fungsi menerima dan mengembalikan JSON. Kode status: `200` sukses, `400` data tidak valid, `401` kredensial atau session tidak sah, `409` konflik sinkronisasi, `429` batas percobaan atau pemakaian, `500` kesalahan server. Bentuk galat seragam:

```json
{ "error": { "code": "invalid_hash_chain", "message": "…", "details": {} } }
```

Semua Edge Function dipasang dengan `--no-verify-jwt`. Otorisasi fungsi terlindungi dilakukan sendiri melalui `x-session-token`. **Service role key hanya di environment fungsi.** Password dan token tidak pernah ditulis ke log.

Autentikasi tidak lagi memiliki Edge Function. Register, login, dan logout mengikuti alur PostgREST pada bagian 4.

### 7.4 `sync-push`
Header: `x-session-token`.

Permintaan:
```json
{
  "beans":       [ { …kolom beans… } ],
  "brews":       [ { …kolom brews…, "stages": [ { …kolom brew_stages… } ] } ],
  "events":      [ … ],
  "game_scores": [ … ],
  "feedback":    [ … ]
}
```
Validasi untuk `brews`:
1. Ambil `seq` dan `hash` terakhir yang diterima server untuk pengguna dari session.
2. Entri baru harus `seq = last_seq + 1` dan `prev_hash = last_hash` (atau `seq = 1`, `prev_hash = "0"`).
3. Hitung ulang hash dengan `buildHashInput()` dan bandingkan.
4. Entri yang sudah ada: aturan idempoten di 6.3.

Respons:
```json
{
  "accepted": { "beans": ["id"], "brews": ["id"], "events": [], "game_scores": [], "feedback": [] },
  "rejected": [ { "table": "brews", "id": "uuid", "reason": "hash_mismatch | chain_broken | tamper | invalid" } ]
}
```

### 7.5 `sync-pull`
Header: `x-session-token`.

Untuk tabel `events`, `game_scores`, dan `feedback`, endpoint yang sama menerima `{ "group": "events | game_scores | feedback", "cursor_at": null | "timestamptz", "cursor_id": null | "uuid" }`. Respons memuat `rows` (maksimal 50), `has_more`, dan kursor `(cursor_at, cursor_id)` dari baris terakhir. `server_updated_at` dibuat server dan tidak berasal dari cap waktu klien. Klien meminta halaman berikutnya sampai `has_more = false`.

Permintaan mengirim seluruh ringkasan rantai lokal agar server dapat membuktikan hubungan prefix:
```json
{
  "local_chain": [
    { "seq": 1, "hash": "…" },
    { "seq": 2, "hash": "…" }
  ],
  "local_ids": {
    "beans": ["uuid"],
    "events": [],
    "game_scores": [],
    "feedback": []
  }
}
```

Perilaku:
1. Bandingkan tiap `seq` dan `hash` dengan rantai server.
2. Kembalikan semua data bila lokal kosong, hanya suffix bila lokal prefix server, respons kosong bila sama, atau penanda `server_is_prefix` bila server merupakan prefix lokal.
3. Bila bercabang, kembalikan `409` dengan `code: "sync_conflict"` dan jumlah data server yang relevan. Klien menawarkan pemulihan ulang atau batal.
4. Payload sukses mengurutkan `beans` sebelum `brews`; `beans` memakai ID yang belum ada, sedangkan `events`, `game_scores`, dan `feedback` ditarik dalam halaman terpisah memakai kursor `(server_updated_at, id)`. Pull `events` dapat memperbarui ID lokal yang lebih lama sesuai aturan 6.4.

Respons ringkas:
```json
{
  "relation": "local_empty | equal | local_is_prefix | server_is_prefix",
  "beans": [],
  "brews": [ { "stages": [] } ],
  "events": [],
  "game_scores": [],
  "feedback": []
}
```

### 7.6 `ai`
Header: `x-session-token`.

Dua jenis permintaan dalam satu fungsi.

Permintaan:
```json
{ "type": "recommend" | "diagnose", "payload": { … } }
```
- `recommend`: payload wajib `bean`, `history` (paling banyak 5), dan `pouring_count` (1-5). `preferences` opsional berisi hanya `dose_g` (5-60, maksimal satu desimal), `pouring_count` (1-5, wajib sama dengan payload), dan `wish` (1-200 karakter setelah trim). Objek kosong setara dengan tidak dikirim. Tanpa kunci, AI dapat mengusulkan 1-5 pouring dengan alasan di `note`.
- `diagnose`: profil biji, seduhan (termasuk tahap dengan target vs aktual), skor dan tag rasa, catatan, riwayat singkat biji itu.

Perilaku:
1. Verifikasi session dari header token.
2. Cek batas pemakaian: **20 panggilan per jam per pengguna** (tabel `ai_usage`). Lebih dari itu, `429`.
3. Susun prompt sistem (bagian 8) yang sama untuk kedua penyedia. Batas waktu server 28 detik dipakai bersama oleh maksimal dua percobaan. Gemini memakai `responseSchema` dan `maxOutputTokens: 1024` untuk recommend/diagnose. OpenAI Chat Completions memakai `response_format: json_schema` strict dan `max_completion_tokens` 2048 untuk JSON, 800 untuk chat. Hanya OpenAI mengirim `reasoning_effort` bila secret opsional diisi; tidak ada `temperature`.
4. Normalisasi keluaran secara deterministik sebelum validasi: waktu tahap dibulatkan dan start yang tumpang tindih digeser; air akhir disetel ke dosis × rasio satu desimal bila tetap lebih besar dari tahap sebelumnya. Dosis tidak dipaksa. Teks diagnosa dipangkas, angka string pada `from`/`to` dikonversi, dan daftar penyebab/saran dipotong ke 5/2. **Validasi** keluaran terhadap skema dan kunci preferensi: selisih dosis maksimal 0,05 g dan jumlah pouring harus sama persis. Jika tidak valid, satu kali coba ulang. Jika tetap gagal, `502` dengan `code: "ai_invalid_output"`.
5. Kembalikan JSON tervalidasi. Gemini mengulang sekali setelah HTTP 503; OpenAI mengulang sekali setelah HTTP 429 atau 5xx, dengan jeda singkat selama batas waktu masih tersedia. Log kegagalan hanya memuat penyedia, status, panjang keluaran, alasan selesai, dan metadata aman tanpa isi pengguna atau secret.

Respons `recommend`:
```json
{
  "dose_g": 15, "ratio": 16, "water_temp_c": 92, "grind": "sedang", "pouring_count": 3,
  "stages": [ { "name": "bloom", "start_s": 0, "duration_s": 40, "water_cum_g": 45 }, … ],
  "note": "…"
}
```
Respons `diagnose`:
```json
{
  "diagnosis": "…",
  "likely_causes": ["…"],
  "suggestions": [ { "variable": "water_temp_c", "from": 92, "to": 94, "reason": "…" } ],
  "note": "…"
}
```
Nilai `variable` hanya dari: `dose_g`, `ratio`, `water_temp_c`, `grind`. Nilai suhu 80-100, rasio 10-20, `grind` dari enum.

### 7.7 `anchor`

`POST` dengan header `x-session-token`; body diabaikan. Fungsi memakai `requireValidSession`, membaca `seq` dan `hash` seduhan terakhir pengguna dari Postgres, lalu mereservasi `(user_id, seq)` melalui RPC SQL yang hanya dapat dipanggil `service_role`. Tanpa seduhan: `200 {"anchored":false,"reason":"no_brews"}`. Seq yang sudah tercatat: `200` dengan `reason: "already_anchored"`. Pencatatan baru dibatasi satu per pengguna per lima menit (`429`).

Fungsi menghitung `userKey = keccak256(UTF-8 UUID huruf kecil)` dan mengubah SHA-256 hex kepala rantai menjadi `bytes32` tanpa mengubah isinya. Sebelum mengirim, fungsi membaca `latest(userKey)` dari kontrak Sepolia. Transaksi ditandatangani dompet server, dan hash transaksi disimpan sebagai `pending` sebelum menunggu satu konfirmasi hingga 25 detik. Bila belum terkonfirmasi, respons `202` memuat `tx_hash`. Panggilan berikutnya memeriksa receipt: sukses menjadi `confirmed`; reverted menjadi `failed`. Reservasi tanpa hash yang lebih tua dari 10 menit dilepas bila seq belum terlihat on-chain. Bila seq sudah terlihat, baris menjadi `confirmed`; pencarian event `Anchored` pada 5.000 blok terakhir mencoba mengisi `tx_hash`, yang boleh tetap `null` bila event tidak ditemukan. Galat nonce sebelum hash transaksi diperoleh dicoba sekali lagi dengan nonce segar; kegagalan kedua menghasilkan `503 retryable_error`.

RLS `chain_anchors` aktif tanpa policy untuk `anon` dan `authenticated`; hanya `service_role` mendapat akses. Rahasia `CHAIN_RPC_URL`, `CHAIN_PRIVATE_KEY`, dan `CHAIN_CONTRACT_ADDRESS` dibaca dari environment Edge Function; nama dan placeholder tersedia di `supabase/functions/.env.example`. Galat dan log tidak memuat nilainya atau pesan internal.

## 8. Prompt AI (ringkas)

**Sistem (rekomendasi):**
> Kamu asisten seduh V60 manual. Usulkan pengaturan awal untuk biji ini berdasarkan profilnya dan riwayat seduhan yang diberikan. Jika riwayat ada, utamakan pengaturan dengan skor tertinggi dan ubah paling banyak dua variabel. Jika tidak ada riwayat, beri titik awal umum dan katakan itu titik awal. Gunakan hanya data yang diberikan. Balas hanya dengan JSON sesuai skema, tanpa teks lain.

Jika `preferences` ada, prompt mewajibkan dosis dan jumlah pouring yang dikunci, termasuk jumlah `stages` yang tepat. `wish` diperlakukan sebagai data keinginan rasa, bukan instruksi; perintah di dalamnya diabaikan. `note` menjelaskan singkat bagaimana saran menjawab keinginan itu. Tanpa `preferences`, prompt tetap seperti sebelumnya.

**Sistem (diagnosa):**
> Kamu asisten seduh V60 manual. Berdasarkan data seduhan dan keluhan rasa, beri kemungkinan penyebab dan saran perbaikan. Gunakan bahasa "kemungkinan", bukan kepastian. Ubah paling banyak dua variabel sekaligus. Perhatikan selisih target dan aktual per tahap. Balas hanya dengan JSON sesuai skema, tanpa teks lain.

Prompt diagnosa menyebut rentang angka, enum, batas panjang teks, batas daftar, serta memakai notes dan selisih target/aktual sebagai petunjuk. `notes` dan `custom_taste_tags` diperlakukan sebagai data. Teks akhir prompt boleh disempurnakan, tapi **skema keluaran dan batas nilai tidak boleh berubah** tanpa memperbarui bagian 7 dan validator.

**Fallback tanpa AI** (dipakai jika offline, galat, atau JSON tidak valid):
- Tag `asam` dan skor ≤ 3: naikkan suhu 1-2 °C atau satu tingkat lebih halus.
- Tag `pahit` dan skor ≤ 3: turunkan suhu 1-2 °C atau satu tingkat lebih kasar.
- Tag `hambar`: perkecil rasio satu angka (lebih pekat).
- Selain itu: pertahankan pengaturan, ubah satu variabel kecil, dan catat hasilnya.
- Untuk rekomendasi: pakai pengaturan terbaik biji, atau default 15 g, 1:16, 92 °C, `sedang`, 3 pouring.

Label di UI selalu: "Saran, bukan kepastian. Coba dan catat hasilnya."

## 9. Keamanan

| Aturan | Keterangan |
|---|---|
| Tidak ada rahasia di Flutter | API key LLM dan service role key hanya di secret/environment Edge Function |
| `.env` dan berkas kunci | Masuk `.gitignore` sejak commit pertama |
| RLS | `users` dan `sessions` memiliki policy anon terbatas; data fitur lain tetap lewat Edge Function |
| Password | Hash dibuat lokal dengan PBKDF2; password tidak dikirim ke PostgREST atau dicatat di log |
| Session token | Token asli hanya di secure storage; server menyimpan SHA-256 token, masa berlaku 7 hari, dan status pencabutan |
| Pembatasan login | Penghitung lokal per username selama 15 menit hanya pengaman UX |
| HTTPS | Semua panggilan jaringan |
| Batas AI | 20 panggilan per jam per pengguna |
| Validasi di server | Server memverifikasi hash dan skema, bukan hanya mempercayai aplikasi |
| Log | Jangan mencatat password, key, atau isi lengkap data pribadi |

## 10. Penanganan Galat dan Kondisi Pinggir

Tiap layar punya empat keadaan: **memuat, kosong, galat, berhasil**. Pesan galat dalam bahasa Indonesia yang jelas.

| Kondisi | Perilaku |
|---|---|
| Internet mati | Session lokal yang belum kedaluwarsa tetap membuka seduh, jurnal, dan biji. Login/register tertahan; sinkronisasi menunggu dan AI memakai fallback |
| Logout saat offline | Hapus session aktif lokal, simpan `pending_revoke_token`, dan jelaskan bahwa pencabutan server dilakukan saat tersambung |
| Izin lokasi ditolak | Daftar toko tanpa jarak + pesan |
| Izin notifikasi ditolak | Tampilkan penjelasan dan cara mengaktifkan |
| Biometrik tidak tersedia | Sembunyikan opsi, tetap bisa pakai password |
| Sensor tidak ada | Pesan jelas, game dan goyang timer dinonaktifkan |
| JSON AI tidak valid | Fallback atau pesan "saran tidak tersedia" |
| Rantai sinkronisasi bercabang | Jangan gabung otomatis; tawarkan "Pulihkan ulang dari server" dengan jumlah data lokal dan pending, atau Batal |
| Sinkronisasi ditolak | Tandai `error`, tampilkan alasan, jangan gagal diam-diam |
| Session kedaluwarsa saat offline | Ke layar Login dengan pesan bahwa internet diperlukan; tidak ada mode baca saja |
| Session dicabut server | Permintaan berikutnya mendapat `401`; hapus session lokal dan keluar paksa |
| Aplikasi dimatikan di tengah sesi seduh | Sesi yang belum disimpan boleh hilang. Tidak ada entri setengah jadi karena penyimpanan satu transaksi |

## 11. Jangkar hash Sepolia

`blockchain/contracts/BrewAnchor.sol` menyimpan pasangan hash kepala rantai dan `seq` terbaru per pengguna pada Ethereum Sepolia, chainId 11155111, alamat `0x8d80e52E86BDc990f6787D7DD5faF46BeC369324`. Kunci mapping adalah `keccak256` UUID pengguna yang dihitung off-chain; hash kepala rantai berasal dari SHA-256 hex 32 byte sesuai `DATA_MODEL.md`. Data seduhan lengkap tetap di SQLite/Postgres karena biaya dan privasi. Dompet server adalah pengirim transaksi; hanya alamat owner kontrak boleh menulis, dan owner dapat dipindah untuk rotasi kunci. Event menyimpan riwayat jangkar. Kontrak hanya membuktikan hash tercatat pada waktu tertentu, bukan memverifikasi isi rantai. Verifikasi penuh kelak menghitung ulang rantai di aplikasi dan membandingkan kepala rantai dengan nilai on-chain. Kontrak telah di-deploy; Edge Function dan migrasi masih perlu diterapkan.

**Batas skala kelas:** nonce dompet server yang dipakai lintas pengguna dapat bertabrakan saat permintaan serentak. Fungsi mencoba ulang galat nonce sekali, lalu mengembalikan `503`; ini belum rancangan antrean transaksi untuk produksi besar. Saat RPC menerima transaksi tetapi jawaban hilang sebelum `tx_hash` tersimpan, reservasi bertahan sampai pengecekan on-chain dan batas 10 menit; percobaan ulang dapat mengirim transaksi kedua yang akan ditolak kontrak jika seq pertama sudah tercatat. Pencarian event dibatasi 5.000 blok, jadi `tx_hash` hasil pemulihan dapat `null`. Jika nilai on-chain sudah melampaui seq yang direservasi dan event untuk seq lama tidak ditemukan, status pemulihan `confirmed` hanya menunjukkan rantai telah maju, bukan membuktikan hash pada baris lama pernah dicatat. Nilai `anchored_at` di database adalah waktu server mengonfirmasi, bukan cap waktu blok.


### 11.1 Sisi aplikasi

Alur: seduhan baru, sinkronisasi push sukses, lalu `ChainAnchorController.requestAfterPush` memanggil `AnchorClient.requestAnchor()` di latar belakang (`POST /functions/v1/anchor`, header `x-session-token`, timeout 40 detik). Hanya satu permintaan berjalan sekaligus. Hasil dipetakan ke `Confirmed`, `Pending`, `NothingToAnchor`, `RateLimited`, `Unauthorized`, atau `Failed`, lalu disimpan di tabel lokal `chain_anchors` (versi SQLite 4). `RateLimited` menyimpan `retry_after_at` di `chain_anchor_cooldowns`; permintaan berikutnya menghormatinya, termasuk setelah aplikasi dibuka ulang. Jangkar `pending` diperiksa lagi saat aplikasi dibuka atau setelah sinkronisasi berikutnya, tanpa timer. Sebelum menulis hasil, controller memastikan pengguna aktif masih sama; hasil permintaan lama dibuang bila akun berganti. Logout menghapus baris jangkar dan cooldown pengguna itu.

Verifikasi (`verifyNow()`): `ChainVerifier` memanggil `eth_call` `latest(bytes32)` (selector `0x79feb107`) pada kontrak lewat RPC publik Sepolia (`AppConfig.chainRpcUrl`, dapat dioverride dengan `CHAIN_RPC_URL`), memakai `user_key` yang disimpan dari respons server. `BrewRepository.verifiedHashAtSeq` memverifikasi seluruh rantai lokal lalu mengembalikan hash pada seq on-chain. Hasil `match`, `mismatch`, `not_found`, atau `unknown` disimpan di `verify_result` bersama `verified_at`. Aplikasi tidak memegang kunci privat dan tidak pernah mengirim transaksi.

## 12. Pengujian

- **Tes unit wajib:** `buildHashInput` dan `sha256` memakai vektor uji di `DATA_MODEL.md` bagian 5.7 (Flutter **dan** Edge Function). Hitung stok, pengaturan terbaik, total air, dan konversi zona waktu.
- **Tes auth server wajib:** register unik, hash PBKDF2 dan verifikasi, session kedaluwarsa/dicabut, lima kegagalan login menghasilkan `401`, serta permintaan berikutnya dalam jendela 15 menit menghasilkan `429`.
- **Tes sinkronisasi wajib:** pull penuh, prefix lokal, prefix server, rantai sama, rantai bercabang, dan pemulihan ulang dengan data pending.
- **Uji manual di HP asli:** biometrik, sensor, notifikasi (jadwalkan 2 menit ke depan), lokasi, foto profil, sinkronisasi (nyalakan dan matikan internet).
- **Uji tamper:** ubah satu nilai langsung di database, lalu verifikasi integritas harus menyatakan rantai putus.
- Setiap sprint ditutup dengan acceptance criteria di `PRD.md`/`features/*.md` dan satu commit.

## 13. Lingkungan dan Versi (isi saat setup)

| Item | Nilai |
|---|---|
| Versi Flutter / Dart | Flutter 3.44.8 / Dart 3.12.2 |
| Package ID | `com.raismukhtar.tetes` |
| Versi paket utama | `flutter_riverpod` 3.4.3, `sqflite` 2.4.4+2, `path` 1.9.1, `http` 1.6.0, `flutter_secure_storage` 11.2.0; tes database: `sqflite_common_ffi` 2.4.4 |
| URL proyek Supabase | `https://osqznapcbeceaizpvccc.supabase.co` (bukan rahasia) |
| Model LLM | Gemini: `AI_MODEL`; OpenAI: `OPENAI_MODEL` (rencana `gpt-5-nano`) |
| API kurs | (isi setelah diuji) |
| Platform uji | HP Android 16 (API 36) |

Environment Edge Function: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`; fungsi `ai`: `AI_PROVIDER` (`gemini` atau `openai`, kosong berarti `gemini`), `LLM_API_KEY` dan `AI_MODEL` untuk Gemini, `OPENAI_API_KEY` dan `OPENAI_MODEL` untuk OpenAI, serta `OPENAI_REASONING_EFFORT` opsional; khusus `anchor`: `CHAIN_RPC_URL`, `CHAIN_PRIVATE_KEY`, `CHAIN_CONTRACT_ADDRESS`. Tidak ada nilai rahasia yang ditulis di kode.

## 14. Aturan Kerja dengan AI

- Satu fitur per sesi, berpegang pada `features/*.md`.
- Rencana dulu (file yang diubah, paket yang dipakai), setuju, baru kode.
- Tidak menambah dependency atau fitur tanpa bertanya.
- Tidak mengubah file di luar yang diizinkan di spec fitur.
- Jalankan `flutter analyze` sebelum menyatakan selesai, lalu uji di HP.
- Perbarui `PROGRESS.md` dan catat keputusan baru di `DECISIONS.md`.
- Format hash, skema, dan kontrak Edge Function **tidak boleh diubah diam-diam**. Perubahan dimulai dari dokumen ini atau `DATA_MODEL.md`.
