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
                      (publik)  ◄───┘   Supabase Edge Functions
                                         ├─ auth-register/login/logout
                                         ├─ sync-push/pull   ──► Postgres (RLS terkunci)
                                         └─ ai               ──► API LLM (key = secret)
```

**Prinsip:**
1. **Offline-first.** Seduh, jurnal, dan biji jalan tanpa internet. SQLite adalah sumber utama di HP.
2. **Server tipis.** Server menangani autentikasi, memverifikasi sinkronisasi, menyimpan cadangan, dan memegang rahasia.
3. **Rahasia hanya di server.** API key LLM dan service role key tidak pernah ada di Flutter atau Git.
4. **Satu sumber aturan.** Format hash dan skema hanya didefinisikan di `DATA_MODEL.md`.

## 2. Stack

| Lapisan | Pilihan | Catatan |
|---|---|---|
| Aplikasi | Flutter (Dart) | Satu basis kode |
| State | Riverpod | Putuskan di Sprint 1, jangan dicampur dengan pustaka state lain |
| Database lokal | SQLite (`sqflite`) | Migrasi bernomor |
| Penyimpanan aman | `flutter_secure_storage` | Token session, waktu kedaluwarsa, dan token pencabutan tertunda |
| Hash password | PBKDF2-HMAC-SHA256 (Web Crypto bawaan Deno) | Hanya di Edge Function; salt acak per pengguna, jumlah iterasi disimpan per pengguna |
| Hash chain | SHA-256 (`crypto`) | Aturan di `DATA_MODEL.md` |
| UUID | `uuid` | ID data aplikasi dibuat di Flutter; ID pengguna dan session dibuat server |
| Biometrik | `local_auth` | Pembuka aplikasi saja |
| Sensor | `sensors_plus` | Accelerometer (goyang), gyroscope (game) |
| Umpan balik sesi | `vibration` + `flutter_ringtone_player` | Getar dan nada sistem saat pergantian tahap dan akhir sesi |
| Notifikasi | `flutter_local_notifications` + `timezone` | Lokal, tanpa server |
| Lokasi | `geolocator` | |
| Peta | `flutter_map` + `latlong2` (OpenStreetMap) | Tanpa key |
| Foto | `image_picker` | |
| HTTP | `http` atau `dio` (pilih satu) | |
| Grafik | `fl_chart` atau `CustomPainter` | Grafik air kumulatif dan skor |
| Backend | Supabase: Postgres + Edge Functions | Login tidak lewat Supabase Auth |
| LLM | Gemini lewat Google AI Studio | Hanya dari Edge Function |
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
    auth-register/  auth-login/  auth-logout/
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

## 4. Autentikasi Online Buatan Sendiri

Autentikasi berjalan lewat Edge Function dan Postgres sendiri, tanpa Firebase, Supabase Auth, atau layanan auth siap pakai. Semua fungsi dipasang dengan `--no-verify-jwt`; fungsi terlindungi memverifikasi header `x-session-token` terhadap hash token di tabel `sessions`.

**Register**
1. Flutter memvalidasi bentuk input, lalu mengirim `username` dan password melalui HTTPS ke `auth-register`.
2. Edge Function memvalidasi ulang, memastikan username unik, membuat salt acak, dan menghitung PBKDF2-HMAC-SHA256 memakai Web Crypto bawaan Deno.
3. Password di-hash dengan PBKDF2-HMAC-SHA256 sebanyak **600.000 iterasi**, salt acak 16 byte, dan keluaran 32 byte. Salt dan hash disimpan sebagai base64; jumlah iterasi serta nama algoritma disimpan per pengguna.
4. Server membuat `users.id`, membuat session, dan mengembalikan profil pengguna, token acak 32 byte berformat base64url, serta `expires_at`.
5. Flutter menyimpan cache profil di SQLite. Token session dan `expires_at` hanya disimpan di secure storage.

**Login**
1. Login username/password selalu membutuhkan internet dan memanggil `auth-login`.
2. Pembatasan dilakukan berdasarkan username yang diketik, termasuk username yang tidak ada. Jendela 15 menit dibulatkan ke awal jendela dan disimpan di `login_attempts(username, window_start, attempt_count)`.
3. Hitung ulang PBKDF2 memakai parameter pengguna dan bandingkan hasil hash dengan cara waktu-konstan.
4. Lima percobaan gagal pertama dalam jendela masing-masing menghasilkan `401` dan menaikkan penghitung. Permintaan berikutnya ditolak dengan `429` dan sisa waktu tunggu sebelum PBKDF2 dijalankan. Pesan kredensial gagal tetap "Username atau password salah".
5. Login berhasil menghapus baris percobaan pada jendela itu, membuat session baru, lalu mengembalikan profil, token, dan `expires_at`.

**Buka aplikasi**
1. Baca token dan `expires_at` dari secure storage. Kedaluwarsa dibandingkan dengan jam perangkat; keterbatasan ini diterima untuk v1.
2. Jika session lokal belum kedaluwarsa, aplikasi boleh dibuka saat offline. Jika biometrik aktif, minta biometrik sebelum membuka Beranda.
3. Jika session kedaluwarsa, arahkan ke Login. Saat offline, tampilkan pesan bahwa internet diperlukan; tidak ada mode baca saja.
4. Session yang dicabut server diketahui pada permintaan terlindungi berikutnya melalui `401`; hapus session lokal dan keluar paksa.
5. Session berlaku 7 hari tanpa perpanjangan otomatis pada v1.

**Logout**
1. Jika ada baris `sync_status = pending`, dialog konfirmasi wajib menyebut jumlahnya. Data lokal tetap disimpan setelah logout.
2. Hapus session aktif dari secure storage seketika dan kembali ke Login.
3. Panggil `auth-logout`. Jika gagal karena offline, simpan token lama di kunci secure storage terpisah `pending_revoke_token`.
4. Coba pencabutan lagi saat aplikasi dibuka dengan internet atau sebelum login berikutnya. Jika sukses atau token sudah tidak sah, hapus `pending_revoke_token`.
5. Bila pencabutan belum terkirim, jelaskan bahwa session server akan dicabut saat tersambung. Batas cadangan adalah kedaluwarsa 7 hari di server.

**Biometrik** hanya membuka aplikasi saat session lokal masih valid. Biometrik bukan autentikasi server dan tidak menggantikan login username/password. Cek ketersediaan perangkat sebelum menawarkan dan sembunyikan opsi bila tidak didukung.

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
- Fungsi terlindungi (`auth-logout`, `sync-push`, `sync-pull`, `ai`) menerima `x-session-token: <token>`. `auth-register` dan `auth-login` tidak memerlukan header ini.
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

Untuk `beans`, `events`, `game_scores`, dan `feedback`, pull hanya menyisipkan baris yang belum ada di SQLite dan tidak menimpa baris yang sudah ada. Perubahan `notes` atau `status` dari perangkat lain belum ditarik pada v1.

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

### 7.1 `auth-register`
Permintaan:
```json
{ "username": "rais", "password": "…" }
```
Perilaku: validasi input, pastikan username unik melalui constraint database, hash password dengan PBKDF2-HMAC-SHA256 melalui Web Crypto Deno memakai 600.000 iterasi, salt acak 16 byte, dan keluaran 32 byte, lalu buat user dan session. Password harus 8-128 karakter.

Respons:
```json
{
  "user": { "id": "uuid", "username": "rais", "created_at": "…" },
  "session_token": "base64url",
  "expires_at": "…"
}
```

Untuk pengukuran saat pengujian, lama PBKDF2 dicatat sebagai `duration_ms` di log tanpa data sensitif. Bila permintaan membawa `x-debug-timing: 1`, respons sukses juga memuat field `duration_ms`; field ini tidak dikirim pada permintaan biasa.

### 7.2 `auth-login`
Permintaan:
```json
{ "username": "rais", "password": "…" }
```
Perilaku:
1. Tentukan `window_start` dengan membulatkan waktu server ke awal jendela 15 menit.
2. Hitung percobaan berdasarkan username input, termasuk username yang tidak terdaftar.
3. Periksa batas sebelum menjalankan PBKDF2. Lima kegagalan pertama pada jendela yang sama menghasilkan `401`; permintaan berikutnya menghasilkan `429` dengan `details.retry_after_s`.
4. Username yang tidak ditemukan tetap menjalankan satu PBKDF2 pura-pura dengan konstanta 600.000 iterasi. Hash pengguna yang ditemukan dihitung memakai nilai `iterations` pada baris pengguna dan dibandingkan dengan cara waktu-konstan.
5. Kegagalan menaikkan penghitung secara atomik melalui RPC `increment_login_attempt(p_username, p_window_start)` yang hanya dapat dijalankan service role. Login berhasil menghapus baris `login_attempts` untuk username dan jendela itu, lalu membuat session baru.

Respons sama dengan `auth-register`.

### 7.3 `auth-logout`
Header: `x-session-token`.

Perilaku: tandai session terkait `revoked = true`. Operasi idempoten; token yang tidak dikenal, sudah dicabut, atau kedaluwarsa tetap menghasilkan respons sukses yang sama sehingga klien boleh menghapus `pending_revoke_token`.

Helper bersama `_shared/session.ts` memvalidasi `x-session-token` dengan mencari hash token yang belum dicabut dan belum kedaluwarsa, lalu mengembalikan `user_id`. Helper ini dipakai oleh fungsi terlindungi `sync-push`, `sync-pull`, dan `ai`.

Respons: `{ "ok": true }`.

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
4. Payload sukses mengurutkan `beans` sebelum `brews`; `beans`, `events`, `game_scores`, dan `feedback` hanya memuat baris server yang ID-nya belum ada pada `local_ids`.

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
- `recommend`: profil biji, riwayat seduhan biji itu (paling banyak 5 terbaru dan terbaik), jumlah pouring yang diminta.
- `diagnose`: profil biji, seduhan (termasuk tahap dengan target vs aktual), skor dan tag rasa, catatan, riwayat singkat biji itu.

Perilaku:
1. Verifikasi session dari header token.
2. Cek batas pemakaian: **20 panggilan per jam per pengguna** (tabel `ai_usage`). Lebih dari itu, `429`.
3. Susun prompt sistem (bagian 8) dan panggil LLM dengan batas waktu 15 detik, suhu rendah, dan minta keluaran JSON.
4. **Validasi** keluaran terhadap skema. Jika tidak valid, satu kali coba ulang. Jika tetap gagal, `500` dengan `code: "ai_invalid_output"`.
5. Kembalikan JSON tervalidasi.

Respons `recommend`:
```json
{
  "dose_g": 15, "ratio": 16, "water_temp_c": 92, "grind": "sedang",
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

## 8. Prompt AI (ringkas)

**Sistem (rekomendasi):**
> Kamu asisten seduh V60 manual. Usulkan pengaturan awal untuk biji ini berdasarkan profilnya dan riwayat seduhan yang diberikan. Jika riwayat ada, utamakan pengaturan dengan skor tertinggi dan ubah paling banyak dua variabel. Jika tidak ada riwayat, beri titik awal umum dan katakan itu titik awal. Gunakan hanya data yang diberikan. Balas hanya dengan JSON sesuai skema, tanpa teks lain.

**Sistem (diagnosa):**
> Kamu asisten seduh V60 manual. Berdasarkan data seduhan dan keluhan rasa, beri kemungkinan penyebab dan saran perbaikan. Gunakan bahasa "kemungkinan", bukan kepastian. Ubah paling banyak dua variabel sekaligus. Perhatikan selisih target dan aktual per tahap. Balas hanya dengan JSON sesuai skema, tanpa teks lain.

Teks akhir prompt boleh disempurnakan, tapi **skema keluaran dan batas nilai tidak boleh berubah** tanpa memperbarui bagian 7 dan validator.

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
| RLS aktif tanpa policy | Semua tabel Postgres. Akses hanya lewat Edge Function |
| Password | Dikirim hanya melalui HTTPS ke fungsi auth, tidak pernah disimpan atau dicatat di log; hash hanya dibuat di server |
| Session token | Token asli hanya di secure storage; server menyimpan SHA-256 token, masa berlaku 7 hari, dan status pencabutan |
| Pembatasan login | Server menghitung kegagalan per username dalam jendela 15 menit, termasuk username yang tidak ada |
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

## 11. Pengujian

- **Tes unit wajib:** `buildHashInput` dan `sha256` memakai vektor uji di `DATA_MODEL.md` bagian 5.7 (Flutter **dan** Edge Function). Hitung stok, pengaturan terbaik, total air, dan konversi zona waktu.
- **Tes auth server wajib:** register unik, hash PBKDF2 dan verifikasi, session kedaluwarsa/dicabut, lima kegagalan login menghasilkan `401`, serta permintaan berikutnya dalam jendela 15 menit menghasilkan `429`.
- **Tes sinkronisasi wajib:** pull penuh, prefix lokal, prefix server, rantai sama, rantai bercabang, dan pemulihan ulang dengan data pending.
- **Uji manual di HP asli:** biometrik, sensor, notifikasi (jadwalkan 2 menit ke depan), lokasi, foto profil, sinkronisasi (nyalakan dan matikan internet).
- **Uji tamper:** ubah satu nilai langsung di database, lalu verifikasi integritas harus menyatakan rantai putus.
- Setiap sprint ditutup dengan acceptance criteria di `PRD.md`/`features/*.md` dan satu commit.

## 12. Lingkungan dan Versi (isi saat setup)

| Item | Nilai |
|---|---|
| Versi Flutter / Dart | Flutter 3.44.8 / Dart 3.12.2 |
| Package ID | `com.raismukhtar.tetes` |
| Versi paket utama | `flutter_riverpod` 3.4.3, `sqflite` 2.4.4+2, `path` 1.9.1, `http` 1.6.0, `flutter_secure_storage` 11.2.0; tes database: `sqflite_common_ffi` 2.4.4 |
| URL proyek Supabase | `https://osqznapcbeceaizpvccc.supabase.co` (bukan rahasia) |
| Model LLM | (isi dari AI Studio, disimpan sebagai environment `AI_MODEL`) |
| API kurs | (isi setelah diuji) |
| Platform uji | HP Android 16 (API 36) |

Environment Edge Function: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `LLM_API_KEY`, `AI_MODEL`. Tidak ada satu pun yang ditulis di kode.

## 13. Aturan Kerja dengan AI

- Satu fitur per sesi, berpegang pada `features/*.md`.
- Rencana dulu (file yang diubah, paket yang dipakai), setuju, baru kode.
- Tidak menambah dependency atau fitur tanpa bertanya.
- Tidak mengubah file di luar yang diizinkan di spec fitur.
- Jalankan `flutter analyze` sebelum menyatakan selesai, lalu uji di HP.
- Perbarui `PROGRESS.md` dan catat keputusan baru di `DECISIONS.md`.
- Format hash, skema, dan kontrak Edge Function **tidak boleh diubah diam-diam**. Perubahan dimulai dari dokumen ini atau `DATA_MODEL.md`.
