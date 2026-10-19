# PROGRESS: Tetes

Perbarui di akhir setiap sesi.

## Status sprint

| Sprint | Fokus | Spec | Status | Catatan |
|---|---|---|---|---|
| 1 | Fondasi, login online buatan sendiri, biometrik, navigasi | 00, 01 | Sedang jalan | Fitur 00 selesai dan sudah memakai Riverpod; berikutnya Fitur 01 autentikasi |
| 2 | Profil biji, kurs, Atur Seduh | 02, 03 (bagian A) | Belum mulai | |
| 3 | Sesi, hasil, hash chain | 03 (bagian B, C) | Belum mulai | |
| 4 | Jurnal | 04 | Belum mulai | |
| 5 | Sinkronisasi dan AI | 05 | Belum mulai | |
| 6 | Event, notifikasi, LBS | 06 | Belum mulai | |
| 7 | Game, profil, perapian | 07 | Belum mulai | |
| 8 | Pengujian, laporan, presentasi | - | Belum mulai | |

Status: Belum mulai / Sedang jalan / Selesai (lolos acceptance) / Terblokir

## Terakhir dikerjakan
2026-10-19: Fitur 01 sisi Flutter untuk Register dan Login selesai diimplementasikan. `AuthClient` memanggil Edge Function tanpa `apikey` atau header debug, memetakan galat server/jaringan/timeout, dan memakai batas waktu 20 detik. Register serta login sukses meng-upsert cache profil SQLite, menyimpan token, `user_id`, dan `expires_at` melalui secure storage, lalu membuka shell utama. Form memakai validasi klien, komponen bersama, state Riverpod tanpa password, serta pesan `429` dalam menit. Seluruh 19 tes lulus, `flutter analyze` bersih, dan APK debug berhasil dibangun tanpa perubahan konfigurasi Gradle. Guard session penuh, biometrik, dan logout nyata belum dikerjakan.

## Masalah terbuka
(bug yang belum beres, hal yang menunggu jawaban dosen)

## Menunggu jawaban dosen
- [ ] Tema (V60 pelatih/jurnal vs Brewmaster)
- [ ] Apakah login boleh dibuat sendiri di server (Edge Function, hash password dan session buatan sendiri), tanpa Firebase dan tanpa layanan auth siap pakai?
- [ ] Supabase diperbolehkan untuk bagian online
- [x] Penempatan Saran & Kesan dan Logout di bottom navigation: diputuskan mengikuti bunyi slide, tetap boleh dikonfirmasi kepada dosen

## Daftar tangkapan layar untuk laporan
(centang setelah diambil: login, biji, atur seduh, sesi, hasil, jurnal, bandingkan, verifikasi, event, peta, game, profil)
