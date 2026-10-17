# Fitur 05: Sinkronisasi online dan AI

**Sprint:** 5
**Tujuan:** data lokal tersalin ke Supabase dengan verifikasi hash di server, dan pengguna mendapat rekomendasi serta diagnosa dari LLM lewat Edge Function.
**FR terkait:** FR-SYNC-01 sampai 04, FR-HASH-04, FR-AI-01 sampai 05
**Dokumen wajib dibaca:** ARCHITECTURE.md (bagian 6, 7, 8, 9), DATA_MODEL.md (bagian 5 dan 6)

## Bagian A: Sinkronisasi

### Sisi server (Supabase)
1. Buat tabel Postgres sesuai DATA_MODEL.md bagian 6. **Aktifkan RLS di semua tabel tanpa policy.**
2. Edge Function `sync-register` dan `sync-push` sesuai kontrak ARCHITECTURE.md bagian 7.
3. Fungsi bersama `buildHashInput` di `supabase/functions/_shared/hash.ts` dengan tes yang memakai vektor uji DATA_MODEL.md bagian 5.7.
4. Service role key dan variabel lain hanya di environment fungsi.

### Sisi Flutter
- **Klien sinkronisasi** di `lib/data/sync/`: antrean baris `pending` per tabel, pengiriman per kelompok, pemetaan baris ke JSON, penanganan respons (`accepted` dan `rejected`).
- Urutan tabel: beans, brews (+ stages), events, game_scores, feedback. `brews` urut `seq`, berhenti bila satu entri ditolak.
- Pemicu: otomatis saat ada data pending dan internet tersedia, serta tombol manual "Sinkronkan sekarang" di Profil dengan status terakhir sinkron.
- Status per baris: `pending`, `synced`, `error`, dan pesan galat ditampilkan (di detail entri atau di Profil).
- `sync-register` dipanggil sekali (`settings.sync_registered`).

## Bagian B: AI

### Sisi server
- Edge Function `ai` (jenis `recommend` dan `diagnose`) sesuai ARCHITECTURE.md bagian 7.3 dan 8.
- Model dibaca dari environment `AI_MODEL`. Batas 20 panggilan per jam per akun. Batas waktu 15 detik. Validasi skema keluaran dan satu kali coba ulang.

### Sisi Flutter
- Klien AI di `lib/data/remote/ai_client.dart`.
- **Atur Seduh:** tombol "Rekomendasikan dengan AI". Mengirim profil biji dan riwayat singkat. Hasil mengisi form (dosis, rasio, suhu, grind, tahap), tetap dapat diubah.
- **Hasil:** tombol "Minta Diagnosa AI", aktif bila skor dan minimal satu tag terisi. Hasil tampil sebagai kartu: diagnosa, kemungkinan penyebab, saran (variabel, dari, ke, alasan), catatan. Tombol "Terapkan ke seduhan berikutnya" mengisi Atur Seduh dari saran.
- Simpan JSON diagnosa di `brews.ai_advice` (tidak ikut hash). Karena entri sudah tersimpan, memperbarui `ai_advice` hanya mengubah `sync_status` menjadi pending, bukan hash.
- Label tetap: "Saran, bukan kepastian. Coba dan catat hasilnya."
- **Fallback** tanpa AI sesuai ARCHITECTURE.md bagian 8 bila offline, galat, atau JSON tidak valid.

## Keadaan layar dan kasus pinggir
- Offline: sinkronisasi menunggu, AI memakai fallback dengan pesan.
- `401` (kunci salah): pesan jelas, arahkan ke Profil.
- `429`: pesan "batas pemakaian AI tercapai, coba lagi nanti".
- Entri ditolak server: tandai `error` dan tampilkan alasan. Jangan gagal diam-diam.
- Pengiriman terputus lalu diulang: tidak boleh menghasilkan duplikat.
- JSON AI tidak valid atau nilai di luar batas: tolak, pakai fallback.

## JANGAN
- Tidak memanggil LLM dari Flutter. Tidak ada API key di Flutter.
- Tidak membuat policy RLS yang membuka tabel. Tidak mengakses tabel server langsung dari Flutter.
- Tidak membuat pull otomatis atau penggabungan dua arah (di luar cakupan v1).
- Tidak menerapkan saran AI ke seduhan tanpa tindakan pengguna.
- Tidak mencatat password, key, atau isi data pribadi di log.

## Boleh menyentuh
`supabase/` (functions, migrations), `lib/data/sync/`, `lib/data/remote/ai_client.dart`, layar Atur Seduh dan Hasil (hanya menambah tombol dan kartu AI), layar Profil (status dan tombol sinkron), `lib/core/config/`.

## Acceptance criteria
**Sinkronisasi**
- [ ] Register akun lalu `sync-register` sukses, dan ulangi tidak membuat duplikat
- [ ] Data pending terkirim, statusnya menjadi `synced`, dan baris muncul di Postgres
- [ ] Hash di server dihitung ulang dan cocok dengan vektor uji
- [ ] Entri dengan hash sengaja dirusak ditolak dan ditandai `error` dengan alasan
- [ ] Mengirim ulang data yang sama tidak membuat duplikat
- [ ] Tabel tidak dapat dibaca dari luar tanpa fungsi (uji dengan permintaan langsung ke tabel, harus ditolak)
- [ ] Sinkronisasi manual dan status terakhir sinkron tampil di Profil

**AI**
- [ ] Rekomendasi mengisi form dan dapat diubah
- [ ] Diagnosa tampil sebagai kartu dengan saran, dan "Terapkan" mengisi Atur Seduh
- [ ] Mode pesawat memunculkan fallback, bukan galat mentah
- [ ] Batas 20 per jam menghasilkan pesan yang jelas
- [ ] API key tidak ditemukan di kode Flutter maupun repositori

## Cara uji
Dua akun di dua HP atau dua instalasi, sinkronkan, periksa di dashboard Supabase. Lakukan uji tamper (ubah `taste_score` di SQLite lokal lalu sinkronkan). Matikan internet saat menekan tombol AI.

## Langkah pengerjaan yang disarankan
1. Tabel server dan RLS. Berhenti.
2. `sync-register` dengan uji manual. Berhenti.
3. `buildHashInput` di server dengan tes vektor uji. Berhenti.
4. `sync-push` dengan uji manual. Berhenti.
5. Klien sinkronisasi di Flutter dan status. Berhenti.
6. Edge Function `ai` dengan uji manual. Berhenti.
7. Integrasi AI di Atur Seduh, lalu Hasil, lalu fallback. Berhenti.
