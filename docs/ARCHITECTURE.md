# ARCHITECTURE: Tetes

Menjelaskan **bagaimana** Tetes dibangun: stack, struktur kode, alur data, kontrak Edge Function, keamanan, dan aturan kerja. Terkait: `PRD.md` (apa yang dibuat), `DATA_MODEL.md` (tabel dan hash), `UI_SPEC.md` (tampilan).

> Nama paket di bawah adalah kandidat. **Versi tidak ditulis di sini.** Tentukan versi saat pertama kali memasang, cek dokumentasi paket, lalu catat di bagian 12 dan kunci.

## 1. Gambaran Besar

```
┌──────────────────────────── HP (Flutter) ────────────────────────────┐
│ UI ─ State ─ Repository ─ SQLite                                     │
│        │                                                             │
│        ├─ Auth lokal (hash+salt, session di secure storage)          │
│        ├─ Sensor, notifikasi, lokasi, biometrik (paket perangkat)    │
│        ├─ Klien Sinkronisasi ───────────┐                            │
│        └─ Klien Kurs ─────────────┐     │                            │
└───────────────────────────────────┼─────┼────────────────────────────┘
                                    │     │ HTTPS
                       API kurs     │     ▼
                      (publik)  ◄───┘   Supabase Edge Functions
                                         ├─ sync-register
                                         ├─ sync-push        ──► Postgres (RLS terkunci)
                                         └─ ai               ──► API LLM (key = secret)
```

**Prinsip:**
1. **Offline-first.** Seduh, jurnal, dan biji jalan tanpa internet. SQLite adalah sumber utama di HP.
2. **Server tipis.** Server hanya memverifikasi, menyimpan cadangan, dan memegang rahasia.
3. **Rahasia hanya di server.** API key LLM dan service role key tidak pernah ada di Flutter atau Git.
4. **Satu sumber aturan.** Format hash dan skema hanya didefinisikan di `DATA_MODEL.md`.

## 2. Stack

| Lapisan | Pilihan | Catatan |
|---|---|---|
| Aplikasi | Flutter (Dart) | Satu basis kode |
| State | Riverpod | Putuskan di Sprint 1, jangan dicampur dengan pustaka state lain |
| Database lokal | SQLite (`sqflite`) | Migrasi bernomor |
| Penyimpanan aman | `flutter_secure_storage` | Session dan `sync_key` |
| Hash password | PBKDF2-HMAC-SHA256 (`cryptography`) | Salt acak 16 byte, iterasi disimpan per pengguna |
| Hash chain | SHA-256 (`crypto`) | Aturan di `DATA_MODEL.md` |
| UUID | `uuid` | ID dibuat di Flutter |
| Biometrik | `local_auth` | Pembuka aplikasi saja |
| Sensor | `sensors_plus` | Accelerometer (goyang), gyroscope (game) |
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
    sync/                   SyncClient, antrean, pemetaan baris <-> JSON
    remote/                 FxClient, AiClient
  features/
    auth/   beans/   brew/   journal/   explore/   game/   profile/
      (tiap fitur: screens/, widgets/, state/)
supabase/
  functions/
    sync-register/  sync-push/  ai/
    _shared/                hash.ts (buildHashInput), validasi, klien DB
  migrations/               SQL tabel server
docs/
```

Aturan lapisan:
- **UI** tidak mengakses SQLite atau HTTP langsung. Hanya lewat state yang memanggil repository.
- **Repository** menjadi satu-satunya pintu ke SQLite.
- **Sinkronisasi** hanya membaca dan menulis lewat repository.
- Warna, ukuran, dan gaya teks **hanya** dari tema (`UI_SPEC.md`), tidak ditulis langsung di layar.

## 4. Autentikasi Lokal

**Register**
1. Validasi (lihat `DATA_MODEL.md` bagian 4). Cek username belum dipakai di SQLite.
2. Buat `user_id` (UUID), `salt` (16 byte acak), hitung hash PBKDF2, simpan di `users`.
3. Buat `sync_key` acak (32 byte, base64url) dan simpan di secure storage. Tandai `sync_registered = 0`.

**Login**
1. Ambil pengguna berdasarkan username. Hitung hash dari password input dengan `salt` dan `iterations` tersimpan. Bandingkan dengan perbandingan waktu-konstan.
2. Jika cocok: buat session `{user_id, expires_at}` (7 hari) di secure storage. Pesan gagal selalu umum: "Username atau password salah".
3. Pembatasan percobaan: 5 kali gagal beruntun, kunci beberapa menit (hitungan di memori atau settings).

**Buka aplikasi**
1. Ada session valid? Jika tidak, ke Login.
2. Jika `biometric_enabled`: tampilkan prompt biometrik. Gagal atau dibatalkan, tawarkan "pakai password" (login ulang).
3. Berhasil, masuk Beranda.

**Logout**: hapus session dari secure storage, kembali ke Login. Data lokal tidak dihapus.

**Biometrik** hanya membuka aplikasi yang session-nya masih ada. Ia bukan pengganti login dan tidak berbicara ke server. Cek ketersediaan perangkat sebelum menawarkan. Sembunyikan opsi jika tidak didukung.

**Batasan yang dicatat untuk laporan:** autentikasi lokal, akun tidak berpindah antar HP, keamanan tidak setara autentikasi server.

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
- `account_id` = `user_id` lokal. `sync_key` = rahasia di secure storage.
- Server hanya menyimpan `SHA-256(sync_key)`. Tiap permintaan membawa header:
  - `x-account-id: <uuid>`
  - `x-sync-key: <sync_key>`
- Batas yang dicatat: akun tidak pindah HP. Jika `sync_key` dicuri, pencuri dapat menyinkronkan sebagai pengguna itu.

### 6.2 Urutan
1. `sync-register` sekali (jika `sync_registered = 0`), lalu set `1`.
2. Kirim data `pending` ke `sync-push` dalam urutan tabel: `beans` → `brews` (+ `brew_stages`) → `events` → `game_scores` → `feedback`.
3. `brews` dikirim urut `seq` naik, per kelompok (misalnya 20). **Jika satu entri ditolak, hentikan kelompok itu**, karena entri sesudahnya pasti gagal.
4. Respons memuat daftar `accepted` dan `rejected`. Tandai `synced` atau `error` (dengan pesan).
5. Pemicu: otomatis saat online dan ada data pending, serta tombol manual "Sinkronkan sekarang" di Profil.

### 6.3 Idempoten
- Upsert berdasarkan `id`. Mengirim ulang baris yang sama tidak menghasilkan duplikat.
- Entri `brews` yang sudah ada di server dengan `hash` sama dianggap sukses. Hanya field tidak-hash (`notes`, `ai_advice`, `cost_idr`, `status`) yang diperbarui. Jika field yang di-hash berbeda dari yang tersimpan, **tolak** dengan alasan `tamper`.

### 6.3b Cakupan v1
Hanya **push** (HP ke server). Tidak ada pull otomatis, tidak ada penggabungan dua arah. Unduh penuh saat login di HP lain tidak dikerjakan di versi ini.

## 7. Kontrak Edge Function

Semua fungsi menerima dan mengembalikan JSON. Kode status: `200` sukses, `400` data tidak valid, `401` kunci salah, `429` batas pemakaian, `500` kesalahan server. Bentuk galat seragam:

```json
{ "error": { "code": "invalid_hash_chain", "message": "…", "details": {} } }
```

Catatan konfigurasi: Edge Function bawaan Supabase biasanya meminta token (JWT) di header `Authorization`. Cek dokumentasi: gunakan `anon key` publik di header itu, atau atur fungsi agar tidak memverifikasi JWT. Otorisasi sebenarnya tetap lewat `x-account-id` dan `x-sync-key`. **Service role key hanya di environment fungsi.**

### 7.1 `sync-register`
Permintaan:
```json
{ "account_id": "uuid", "username": "rais", "sync_key": "…" }
```
Perilaku: jika `account_id` belum ada, buat dengan `sync_key_hash`. Jika sudah ada dan hash cocok, sukses (idempoten). Jika sudah ada dan hash tidak cocok, `401`.
Respons: `{ "ok": true }`

### 7.2 `sync-push`
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
1. Ambil `seq` dan `hash` terakhir yang diterima server untuk akun ini.
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

### 7.3 `ai`
Dua jenis permintaan dalam satu fungsi.

Permintaan:
```json
{ "type": "recommend" | "diagnose", "payload": { … } }
```
- `recommend`: profil biji, riwayat seduhan biji itu (paling banyak 5 terbaru dan terbaik), jumlah pouring yang diminta.
- `diagnose`: profil biji, seduhan (termasuk tahap dengan target vs aktual), skor dan tag rasa, catatan, riwayat singkat biji itu.

Perilaku:
1. Verifikasi akun (header kunci).
2. Cek batas pemakaian: **20 panggilan per jam per akun** (tabel `ai_usage`). Lebih dari itu, `429`.
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
| Password | Tidak pernah disimpan, dicatat di log, atau dikirim ke server |
| `sync_key` | Secure storage. Server hanya menyimpan hash-nya |
| HTTPS | Semua panggilan jaringan |
| Batas AI | 20 panggilan per jam per akun |
| Validasi di server | Server memverifikasi hash dan skema, bukan hanya mempercayai aplikasi |
| Log | Jangan mencatat password, key, atau isi lengkap data pribadi |

## 10. Penanganan Galat dan Kondisi Pinggir

Tiap layar punya empat keadaan: **memuat, kosong, galat, berhasil**. Pesan galat dalam bahasa Indonesia yang jelas.

| Kondisi | Perilaku |
|---|---|
| Internet mati | Seduh, jurnal, biji tetap jalan. Sinkronisasi dan AI menunjukkan pesan, AI memakai fallback |
| Izin lokasi ditolak | Daftar toko tanpa jarak + pesan |
| Izin notifikasi ditolak | Tampilkan penjelasan dan cara mengaktifkan |
| Biometrik tidak tersedia | Sembunyikan opsi, tetap bisa pakai password |
| Sensor tidak ada | Pesan jelas, game dan goyang timer dinonaktifkan |
| JSON AI tidak valid | Fallback atau pesan "saran tidak tersedia" |
| Sinkronisasi ditolak | Tandai `error`, tampilkan alasan, jangan gagal diam-diam |
| Token kedaluwarsa | Ke layar Login |
| Aplikasi dimatikan di tengah sesi seduh | Sesi yang belum disimpan boleh hilang. Tidak ada entri setengah jadi karena penyimpanan satu transaksi |

## 11. Pengujian

- **Tes unit wajib:** `buildHashInput` dan `sha256` memakai vektor uji di `DATA_MODEL.md` bagian 5.7 (Flutter **dan** Edge Function). Hitung stok, pengaturan terbaik, total air, dan konversi zona waktu.
- **Uji manual di HP asli:** biometrik, sensor, notifikasi (jadwalkan 2 menit ke depan), lokasi, foto profil, sinkronisasi (nyalakan dan matikan internet).
- **Uji tamper:** ubah satu nilai langsung di database, lalu verifikasi integritas harus menyatakan rantai putus.
- Setiap sprint ditutup dengan acceptance criteria di `PRD.md`/`features/*.md` dan satu commit.

## 12. Lingkungan dan Versi (isi saat setup)

| Item | Nilai |
|---|---|
| Versi Flutter / Dart | (isi) |
| Package ID | `com.raismukhtar.tetes` |
| Versi paket utama | (isi dan kunci setelah pertama kali berjalan) |
| URL proyek Supabase | (isi, bukan rahasia) |
| Model LLM | (isi dari AI Studio, disimpan sebagai environment `AI_MODEL`) |
| API kurs | (isi setelah diuji) |
| Platform uji | HP Android: (isi tipe) |

Environment Edge Function: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `LLM_API_KEY`, `AI_MODEL`. Tidak ada satu pun yang ditulis di kode.

## 13. Aturan Kerja dengan AI

- Satu fitur per sesi, berpegang pada `features/*.md`.
- Rencana dulu (file yang diubah, paket yang dipakai), setuju, baru kode.
- Tidak menambah dependency atau fitur tanpa bertanya.
- Tidak mengubah file di luar yang diizinkan di spec fitur.
- Jalankan `flutter analyze` sebelum menyatakan selesai, lalu uji di HP.
- Perbarui `PROGRESS.md` dan catat keputusan baru di `DECISIONS.md`.
- Format hash, skema, dan kontrak Edge Function **tidak boleh diubah diam-diam**. Perubahan dimulai dari dokumen ini atau `DATA_MODEL.md`.
