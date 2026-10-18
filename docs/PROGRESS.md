# PROGRESS: Tetes

Perbarui di akhir setiap sesi.

## Status sprint

| Sprint | Fokus | Spec | Status | Catatan |
|---|---|---|---|---|
| 1 | Fondasi, login online buatan sendiri, biometrik, navigasi | 00, 01 | Sedang jalan | Langkah 1-4 Fitur 00 selesai; berikutnya Langkah 5 state management dan struktur folder |
| 2 | Profil biji, kurs, Atur Seduh | 02, 03 (bagian A) | Belum mulai | |
| 3 | Sesi, hasil, hash chain | 03 (bagian B, C) | Belum mulai | |
| 4 | Jurnal | 04 | Belum mulai | |
| 5 | Sinkronisasi dan AI | 05 | Belum mulai | |
| 6 | Event, notifikasi, LBS | 06 | Belum mulai | |
| 7 | Game, profil, perapian | 07 | Belum mulai | |
| 8 | Pengujian, laporan, presentasi | - | Belum mulai | |

Status: Belum mulai / Sedang jalan / Selesai (lolos acceptance) / Terblokir

## Terakhir dikerjakan
2026-10-18: Langkah 4 Fitur 00 selesai. Ditambahkan pembuka SQLite dengan foreign keys pada setiap koneksi, migrasi bernomor versi 1 untuk sembilan tabel dan empat indeks, seed `stores` dari aset, serta tampilan galat pembukaan database dengan aksi coba lagi tanpa menghapus database. Tes migrasi membuktikan daftar tabel dan indeks, `user_version = 1`, skema cache `users`, penolakan foreign key, dan `UNIQUE (user_id, seq)`. Tes khusus lulus dan `flutter analyze` bersih. Berikutnya: uji di HP, lalu kerjakan Langkah 5 secara terpisah.

## Masalah terbuka
(bug yang belum beres, hal yang menunggu jawaban dosen)

## Menunggu jawaban dosen
- [ ] Tema (V60 pelatih/jurnal vs Brewmaster)
- [ ] Apakah login boleh dibuat sendiri di server (Edge Function, hash password dan session buatan sendiri), tanpa Firebase dan tanpa layanan auth siap pakai?
- [ ] Supabase diperbolehkan untuk bagian online
- [x] Penempatan Saran & Kesan dan Logout di bottom navigation: diputuskan mengikuti bunyi slide, tetap boleh dikonfirmasi kepada dosen

## Daftar tangkapan layar untuk laporan
(centang setelah diambil: login, biji, atur seduh, sesi, hasil, jurnal, bandingkan, verifikasi, event, peta, game, profil)
