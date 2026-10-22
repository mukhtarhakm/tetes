# Fitur 00: Fondasi proyek

**Sprint:** 1
**Tujuan:** proyek Flutter yang jalan di HP asli, dengan tema, database, dan kerangka navigasi sebagai dasar semua fitur.
**FR terkait:** FR-NAV-01, dasar untuk semua modul
**Dokumen wajib dibaca:** ARCHITECTURE.md (bagian 2, 3, 12), DATA_MODEL.md (bagian 1, 3, 8), UI_SPEC.md

## Layar
- **Splash:** logo atau nama Tetes, memeriksa session, lalu mengarah ke Login atau Beranda.
- **Beranda dengan bottom navigation:** 4 item, yaitu Beranda, Profil, Saran & Kesan, dan Logout, dengan label satu baris. Tiga item pertama berupa tab dalam `IndexedStack`; ikon Profil memakai foto atau inisial pengguna. Logout adalah aksi dialog konfirmasi dengan peringatan data belum sinkron dan tidak mengubah tab aktif. Beranda menjadi hub untuk Biji kopi (satu-satunya daftar biji), Atur Seduh, Jurnal, Agenda Event, Toko Terdekat, Kalkulator Kurs, dan Game sebagai layar penuh.

## Data
- Buka database SQLite dengan `PRAGMA user_version` dan migrasi bernomor.
- Migrasi 1 membuat tabel: `users`, `settings`, `beans`, `brews`, `brew_stages`, `events`, `game_scores`, `feedback`, `stores`, beserta indeks. Persis sesuai DATA_MODEL.md bagian 3.
- Seed `stores` dari berkas aset (boleh kosong dulu).

## Alur
1. Setup proyek dengan package ID `com.raismukhtar.tetes`, nama tampilan "Tetes".
2. Buat tema dari UI_SPEC.md (warna, tipografi, bentuk) dan komponen bersama dasar: tombol, kartu, kolom isian, dialog, indikator memuat, tampilan kosong, tampilan galat.
3. Router dan bottom navigation 4 item: 3 layar tab dalam `IndexedStack` dan 1 aksi Logout.
4. Database dan migrasi.
5. Konfigurasi state management (Riverpod) dan struktur folder sesuai ARCHITECTURE.md bagian 3.

## Keadaan layar dan kasus pinggir
- Database gagal dibuka: tampilkan layar galat dengan tombol coba lagi.
- Rotasi layar: kunci potret (cukup untuk tugas ini).

## JANGAN
- Tidak membuat fitur apa pun (login, biji, dan sebagainya). Hanya fondasi.
- Tidak menambah paket di luar daftar ARCHITECTURE.md bagian 2 tanpa bertanya.
- Tidak menulis warna atau ukuran langsung di layar.

## Boleh menyentuh
`pubspec.yaml`, `android/` dan `ios/` (hanya konfigurasi ID dan nama), `lib/main.dart`, `lib/app/`, `lib/core/`, `lib/data/db/`, `assets/`.

## Acceptance criteria
- [ ] Aplikasi berjalan di HP asli dengan nama "Tetes" dan package ID yang benar
- [ ] `flutter analyze` bersih
- [ ] Tema dipakai oleh semua layar. Mengubah satu warna di tema mengubah seluruh aplikasi
- [ ] Bottom navigation berpindah antar 3 layar tab tanpa error; Logout membuka dialog dengan peringatan data belum sinkron tanpa mengubah tab aktif
- [ ] Database terbuat dengan semua tabel (cek lewat alat inspeksi atau log)
- [ ] Menutup dan membuka aplikasi tidak mereset database

## Cara uji
Jalankan di HP, pindah tab, buka dan tutup dialog Logout, tutup dan buka lagi aplikasi. Cek tabel di database lewat inspeksi.

## Langkah pengerjaan yang disarankan
1. Proyek kosong berjalan di HP. Berhenti.
2. Tema dan komponen dasar, tampil di satu layar contoh. Berhenti.
3. Router dan bottom navigation. Berhenti.
4. Database dan migrasi. Berhenti.
