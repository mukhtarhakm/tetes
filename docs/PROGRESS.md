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
2026-10-18: Langkah 5 Fitur 00 selesai. Aplikasi dibungkus `ProviderScope`, pembukaan database memakai satu `databaseProvider`, dan `DatabaseGate` menangani status memuat, galat, serta retry melalui invalidasi provider tanpa menutup database. Pembukaan singleton diamankan agar pemanggilan bersamaan memakai future atau koneksi yang sama. Kerangka folder arsitektur dibuat tanpa implementasi fitur. Seluruh 4 tes lulus, termasuk smoke test dengan database FFI in-memory, dan `flutter analyze` bersih. Berikutnya: uji di HP, lalu mulai Fitur 01 secara terpisah.

## Masalah terbuka
(bug yang belum beres, hal yang menunggu jawaban dosen)

## Menunggu jawaban dosen
- [ ] Tema (V60 pelatih/jurnal vs Brewmaster)
- [ ] Apakah login boleh dibuat sendiri di server (Edge Function, hash password dan session buatan sendiri), tanpa Firebase dan tanpa layanan auth siap pakai?
- [ ] Supabase diperbolehkan untuk bagian online
- [x] Penempatan Saran & Kesan dan Logout di bottom navigation: diputuskan mengikuti bunyi slide, tetap boleh dikonfirmasi kepada dosen

## Daftar tangkapan layar untuk laporan
(centang setelah diambil: login, biji, atur seduh, sesi, hasil, jurnal, bandingkan, verifikasi, event, peta, game, profil)
