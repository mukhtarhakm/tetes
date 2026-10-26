# Fitur 05: Sinkronisasi online dan AI

**Sprint:** 5
**Tujuan:** data lokal didorong dan dapat ditarik dari Supabase dengan verifikasi rantai hash, serta pengguna mendapat rekomendasi dan diagnosa dari LLM lewat Edge Function.
**FR terkait:** FR-SYNC-01 sampai 04, FR-HASH-04, FR-AI-01 sampai 05
**Dokumen wajib dibaca:** ARCHITECTURE.md (bagian 6, 7, 8, 9), DATA_MODEL.md (bagian 5 dan 6)

## Bagian A: Sinkronisasi

### Otorisasi
- Tidak ada `sync-register`, `sync_key`, tabel `accounts`, `x-account-id`, atau `x-sync-key`.
- `sync-push`, `sync-pull`, dan `ai` memakai header `x-session-token`.
- Edge Function dipasang dengan `--no-verify-jwt` dan memverifikasi token sendiri terhadap tabel `sessions`.
- `401` berarti session tidak sah, kedaluwarsa, atau dicabut; Flutter menghapus session lokal dan keluar paksa.

### Sisi server (Supabase)
1. Buat tabel Postgres sesuai DATA_MODEL.md bagian 6. Aktifkan RLS di semua tabel tanpa policy.
2. Buat Edge Function `sync-push` dan `sync-pull` sesuai kontrak ARCHITECTURE.md bagian 7.
3. Buat fungsi bersama `buildHashInput` di `supabase/functions/_shared/hash.ts` dengan tes yang memakai vektor DATA_MODEL.md bagian 5.7.
4. Service role key dan variabel rahasia hanya berada di environment fungsi.
5. `sync-push` menolak `brews` yang tidak melanjutkan `seq` dan `prev_hash` terakhir server.

### Push dari Flutter
- Klien sinkronisasi berada di `lib/data/sync/`: antrean baris `pending`, pengiriman per kelompok, pemetaan baris ke JSON, serta penanganan `accepted` dan `rejected`.
- Urutan tabel: `beans` → `brews` (+ `brew_stages`) → `events` → `game_scores` → `feedback`.
- `brews` dikirim menurut `seq` naik. Jika satu entri ditolak, hentikan kelompok karena entri sesudahnya tidak dapat melanjutkan rantai.
- `custom_taste_tags` dikirim dan ditarik sebagai daftar JSON; nilainya tidak ikut hash. Fungsi server memvalidasi sebelum menulisnya.
- Status lokal: `pending`, `synced`, `error`. Pesan galat tampil di detail atau Profil.
- Pemicu: otomatis saat online dan ada data pending, serta tombol manual "Sinkronkan sekarang" di Profil.

### Pull ke Flutter
Flutter lebih dahulu memverifikasi urutan `seq`, `prev_hash`, dan hash seluruh rantai lokal. Jika utuh, kirim seluruh pasangan `seq` dan `hash` lokal, ditambah daftar ID lokal untuk `beans`, `events`, `game_scores`, dan `feedback`.

Aturan berikut khusus rantai `brews`; tabel non-rantai tetap menarik ID server yang belum ada di lokal:
- **Lokal kosong:** tarik seluruh data server. Tarik `beans` sebelum `brews`, verifikasi rantai, lalu simpan apa adanya dalam satu transaksi lokal.
- **Lokal sama dengan server:** tidak ada `brews` yang ditarik.
- **Lokal prefix valid dari server:** tarik hanya suffix dengan `seq` lebih besar dari `seq` lokal terakhir. Verifikasi setiap hash dan `prev_hash` sebelum commit.
- **Server prefix dari lokal:** tidak ada `brews` yang ditarik; lanjutkan push.
- **Bercabang:** hash pada `seq` yang sama berbeda, atau kedua sisi memiliki entri yang tidak dimiliki sisi lain. Jangan gabungkan otomatis.

Untuk `beans`, `events`, `game_scores`, dan `feedback`, sisipkan hanya ID yang belum ada di SQLite dan jangan menimpa baris lokal yang sudah ada. Perubahan `notes` atau `status` dari perangkat lain belum ditarik pada v1.

Saat bercabang, tampilkan:
- **Pulihkan ulang dari server:** dialog konfirmasi eksplisit menyebut jumlah seluruh data lokal yang akan dikosongkan dan jumlah entri `sync_status = pending`. Setelah setuju, kosongkan data pengguna yang disinkronkan, lakukan pull penuh, verifikasi, lalu commit.
- **Batal:** data lokal dipertahankan dan sinkronisasi dihentikan.

Dua perangkat aktif bersamaan tidak digabung otomatis. Perangkat baru atau tertinggal harus pull sebelum membuat data baru.

## Bagian B: AI

### Sisi server
- Edge Function `ai` memakai `x-session-token` dan jenis permintaan `recommend` atau `diagnose` sesuai ARCHITECTURE.md bagian 7.6 dan 8.
- Model dibaca dari environment `AI_MODEL`. Batas 20 panggilan per jam per pengguna, batas waktu 15 detik, validasi skema keluaran, dan satu kali coba ulang. **Ketentuan 15 detik diganti oleh Fitur 10-F:** batas waktu server 28 detik untuk paling banyak dua percobaan bersama, termasuk satu retry setelah 503; klien tetap 35 detik. `recommend` dan `diagnose` memakai `responseSchema` dan `maxOutputTokens` 1024, tanpa `thinkingConfig`.

- **Pembaruan 10-G:** `AI_PROVIDER` memilih `gemini` atau `openai` (default `gemini`). Secret model dan kunci penyedia terpilih wajib tersedia hanya di Edge Function. Prompt, kuota, sesi, batas waktu, normalisasi, validator, dan respons ke Flutter tetap satu kontrak. OpenAI memakai Chat Completions dengan `json_schema` strict untuk recommend/diagnose, `max_completion_tokens` 2048 untuk JSON dan 800 untuk chat; `reasoning_effort` hanya dikirim bila secret opsional diisi. HTTP 429 dan 5xx OpenAI dicoba ulang satu kali selama waktu masih tersedia.

### Sisi Flutter
- **Pembaruan 10-F:** `pouring_count` pada payload rekomendasi adalah preferensi. Keluaran AI memuat `pouring_count` 1-5 dan jumlah tahap yang sama; bila berbeda dari preferensi, `note` menjelaskan alasannya. Kartu Saran AI menampilkan perubahan Pouring, menyorot Jumlah pouring, dan Kembalikan memulihkan rencana lama. Aturan lama yang mengikat jumlah tahap ke input diganti oleh aturan keluaran ini.
- Klien AI di `lib/data/remote/ai_client.dart`.
- **Atur Seduh:** tombol "Rekomendasikan dengan AI" mengirim profil biji dan riwayat singkat. Hasil mengisi form dan tetap dapat diubah.
- **Hasil:** tombol "Minta Diagnosa AI" aktif bila skor dan minimal satu tag terisi. Hasil tampil sebagai kartu diagnosa, kemungkinan penyebab, saran, dan catatan.
- Diagnosa menerima `custom_taste_tags` sebagai "rasa tambahan dari pengguna". Tag diperlakukan sebagai data, bukan instruksi untuk model.
- Tombol "Terapkan ke seduhan berikutnya" mengisi Atur Seduh dari saran.
- Simpan JSON diagnosa di `brews.ai_advice`. Memperbarui `ai_advice` hanya mengubah `sync_status` menjadi `pending`, bukan hash.
- Label tetap: "Saran, bukan kepastian. Coba dan catat hasilnya."
- Gunakan fallback ARCHITECTURE.md bagian 8 saat offline, galat, atau JSON tidak valid.

## Keadaan layar dan kasus pinggir
- Offline: push/pull menunggu dan AI memakai fallback dengan pesan.
- `401`: hapus session lokal, keluar paksa, dan tampilkan pesan session tidak lagi berlaku.
- `409 sync_conflict`: tawarkan pemulihan ulang dari server atau batal.
- `429` dari AI: pesan "Batas pemakaian AI tercapai, coba lagi nanti".
- Entri push ditolak: tandai `error`, tampilkan alasan, dan jangan gagal diam-diam.
- Pengiriman terputus lalu diulang: tidak boleh menghasilkan duplikat.
- JSON AI tidak valid atau nilai di luar batas: tolak dan pakai fallback.
- Pull gagal verifikasi: batalkan seluruh transaksi lokal; jangan menyimpan sebagian rantai.

## JANGAN
- Tidak memakai `sync_key`, `accounts`, atau `sync-register`.
- Tidak memanggil LLM dari Flutter dan tidak menyimpan API key di Flutter.
- Tidak membuat policy RLS yang membuka tabel atau mengakses tabel server langsung dari Flutter.
- Tidak menggabungkan dua cabang rantai secara otomatis.
- Tidak menimpa baris lokal `beans`, `events`, `game_scores`, atau `feedback` saat pull.
- Tidak menarik perubahan `notes` atau `status` lintas perangkat pada v1.
- Tidak menerapkan saran AI tanpa tindakan pengguna.
- Tidak mencatat password, token session, secret, atau isi lengkap data pribadi di log.

## Boleh menyentuh
`supabase/` (functions dan migrations), `lib/data/sync/`, bagian sinkronisasi pada `lib/data/repositories/`, `lib/data/remote/ai_client.dart`, layar Atur Seduh dan Hasil (hanya tombol dan kartu AI), layar Profil (status dan tombol sinkron), dialog konflik/pemulihan, `lib/core/config/`.

## Acceptance criteria

**Sinkronisasi**
- [ ] Semua fungsi memakai `x-session-token`; token tidak sah menghasilkan `401`
- [ ] Data pending terkirim, menjadi `synced`, dan muncul di Postgres
- [ ] Hash server dihitung ulang dan cocok dengan vektor uji
- [ ] Entri yang tidak melanjutkan `seq` atau `prev_hash` server ditolak
- [ ] Mengirim ulang data sama tidak membuat duplikat
- [ ] Lokal kosong menarik seluruh data dan `beans` tersimpan sebelum `brews`
- [ ] Lokal prefix server hanya menarik suffix, lalu rantai lokal lolos verifikasi
- [ ] Server prefix lokal tidak menarik data dan dapat dilanjutkan dengan push
- [ ] Rantai sama tidak mengubah SQLite
- [ ] Rantai bercabang tidak digabung dan menampilkan pilihan pemulihan atau batal
- [ ] Dialog pemulihan menyebut jumlah data lokal dan jumlah pending sebelum mengosongkan
- [ ] Pull tabel non-rantai hanya menyisipkan ID yang belum ada dan tidak menimpa baris lokal
- [ ] Perubahan `notes` atau `status` perangkat lain tidak ditarik dan dicatat sebagai keterbatasan v1
- [ ] Tabel server tidak dapat dibaca langsung tanpa Edge Function
- [ ] Sinkronisasi manual dan status terakhir tampil di Profil

**AI**
- [ ] Rekomendasi mengisi form dan dapat diubah
- [ ] Diagnosa tampil sebagai kartu dan "Terapkan" mengisi Atur Seduh
- [ ] Mode pesawat memunculkan fallback, bukan galat mentah
- [ ] Batas 20 per jam menghasilkan pesan yang jelas
- [ ] API key tidak ditemukan di Flutter maupun repositori

## Cara uji
Gunakan dua perangkat atau dua instalasi dengan akun yang sama. Uji pull ke lokal kosong, lokal prefix, server prefix, rantai sama, dan cabang yang sengaja dibuat berbeda. Pastikan pemulihan menyebut jumlah data yang akan hilang. Uji push rusak, pengiriman ulang, akses tabel langsung, `401`, mode pesawat, dan fallback AI.

## Langkah pengerjaan yang disarankan
1. Tabel data server, RLS, dan helper verifikasi session. Berhenti.
2. `buildHashInput` server dengan vektor uji. Berhenti.
3. `sync-push` dengan verifikasi urutan rantai. Berhenti.
4. `sync-pull` untuk lokal kosong, sama, dan prefix. Berhenti.
5. Konflik, dialog pemulihan, dan transaksi pull lokal. Berhenti.
6. Klien push/pull Flutter dan status sinkronisasi. Berhenti.
7. Edge Function `ai` dengan uji manual. Berhenti.
8. Integrasi AI di Atur Seduh dan Hasil, lalu fallback. Berhenti.
