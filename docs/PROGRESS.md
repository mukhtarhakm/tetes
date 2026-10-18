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
2026-10-18: Fitur 01 sisi server langkah 3 siap diuji. Migrasi baru menambahkan RPC atomik `increment_login_attempt(p_username, p_window_start)` khusus service role. `auth-login` memeriksa batas sebelum PBKDF2, memberi lima respons `401` lalu `429`, menjalankan PBKDF2 pura-pura untuk username yang tidak ada, memakai perbandingan waktu-konstan, dan membuat session 7 hari saat berhasil. `auth-logout` mencabut session secara idempoten, sedangkan `_shared/session.ts` menyiapkan validasi session bagi fungsi sinkronisasi dan AI. Belum dilakukan `db push` atau deploy; pengujian dilakukan melalui Supabase CLI dan curl.

## Masalah terbuka
(bug yang belum beres, hal yang menunggu jawaban dosen)

## Menunggu jawaban dosen
- [ ] Tema (V60 pelatih/jurnal vs Brewmaster)
- [ ] Apakah login boleh dibuat sendiri di server (Edge Function, hash password dan session buatan sendiri), tanpa Firebase dan tanpa layanan auth siap pakai?
- [ ] Supabase diperbolehkan untuk bagian online
- [x] Penempatan Saran & Kesan dan Logout di bottom navigation: diputuskan mengikuti bunyi slide, tetap boleh dikonfirmasi kepada dosen

## Daftar tangkapan layar untuk laporan
(centang setelah diambil: login, biji, atur seduh, sesi, hasil, jurnal, bandingkan, verifikasi, event, peta, game, profil)
