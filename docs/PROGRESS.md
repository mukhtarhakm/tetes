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
2026-10-19: Fitur 01 sisi Flutter untuk Logout nyata selesai diimplementasikan. Dialog Logout menghitung data `sync_status = pending` milik pengguna aktif pada tabel `beans`, `brews`, `events`, `game_scores`, dan `feedback`, lalu menyebut jumlahnya sebelum konfirmasi. Token session dimasukkan lebih dahulu ke antrean `pending_revoke_token` di secure storage, session aktif dihapus, state dan seluruh tumpukan navigasi diganti ke Login, kemudian `auth-logout` dipanggil di latar belakang. Antrean berupa daftar maksimal lima token dan hanya menghapus token setelah respons `200`; kegagalan jaringan, timeout, atau status lain mempertahankannya. Antrean dicoba ulang tanpa menahan guard saat startup dan selama maksimal tiga detik sebelum login. Startup juga menyelesaikan logout yang terputus setelah token sempat diantrekan. Keluar paksa akibat `401` tidak mengantrekan token. Data SQLite tidak dihapus dan token tidak masuk state, SQLite, atau log. Seluruh 36 tes lulus dan `flutter analyze` bersih. Biometrik belum dikerjakan.

## Masalah terbuka
(bug yang belum beres, hal yang menunggu jawaban dosen)

- Guard belum memeriksa ulang masa berlaku session ketika aplikasi kembali dari latar belakang; pengecekan saat resume ditunda ke langkah berikutnya.

## Menunggu jawaban dosen
- [ ] Tema (V60 pelatih/jurnal vs Brewmaster)
- [ ] Apakah login boleh dibuat sendiri di server (Edge Function, hash password dan session buatan sendiri), tanpa Firebase dan tanpa layanan auth siap pakai?
- [ ] Supabase diperbolehkan untuk bagian online
- [x] Penempatan Saran & Kesan dan Logout di bottom navigation: diputuskan mengikuti bunyi slide, tetap boleh dikonfirmasi kepada dosen

## Daftar tangkapan layar untuk laporan
(centang setelah diambil: login, biji, atur seduh, sesi, hasil, jurnal, bandingkan, verifikasi, event, peta, game, profil)
