# PROGRESS: Tetes

Perbarui di akhir setiap sesi.

## Status sprint

| Sprint | Fokus | Spec | Status | Catatan |
|---|---|---|---|---|
| 1 | Fondasi, login online buatan sendiri, biometrik, navigasi | 00, 01 | Selesai | Fitur 00 selesai. Fitur 01: server (register, login, logout, pembatasan percobaan) dan Flutter (register, login, session, guard, logout, biometrik) sudah diimplementasikan. Fitur 01 lolos uji di HP  |
| 2 | Profil biji, kurs, Atur Seduh | 02, 03 (bagian A) | Sedang jalan | Fitur 02 Sesi A selesai: repository, form, daftar, dan detail biji tanpa kurs |
| 3 | Sesi, hasil, hash chain | 03 (bagian B, C) | Belum mulai | |
| 4 | Jurnal | 04 | Belum mulai | |
| 5 | Sinkronisasi dan AI | 05 | Belum mulai | |
| 6 | Event, notifikasi, LBS | 06 | Belum mulai | |
| 7 | Game, profil, perapian | 07 | Belum mulai | |
| 8 | Pengujian, laporan, presentasi | - | Belum mulai | |

Status: Belum mulai / Sedang jalan / Selesai (lolos acceptance) / Terblokir

## Terakhir dikerjakan
2026-10-19: Fitur 02 Sesi A selesai diimplementasikan tanpa kurs. Tab Seduh sekarang menampilkan daftar biji aktif dengan keadaan memuat, kosong, galat, dan berhasil. Form tambah/ubah mendukung seluruh field profil, validasi harga dan stok nonnegatif, spesies campuran dengan persen arabika, roasting sendiri, tanggal roasting, serta tag notes yang disimpan terurut. Detail menampilkan profil, stok tersisa dari query seduhan aktif, harga asli, notes, dan pengaturan terbaik sementara. Insert, update, dan arsip selalu memakai `user_id` session aktif, memperbarui `updated_at`, serta menyetel `sync_status = pending`. Biji hanya dapat diarsipkan dan tidak memiliki hard-delete karena tabel `beans` tidak mempunyai kolom `deleted` dan sinkronisasi memerlukan rekam data yang tetap ada. Kolom kurs tetap kosong, termasuk untuk IDR, sampai Sesi B. Seluruh 50 tes lulus dan `flutter analyze` bersih.

## Masalah terbuka
(bug yang belum beres, hal yang menunggu jawaban dosen)

- Guard belum memeriksa ulang masa berlaku session ketika aplikasi kembali dari latar belakang; pengecekan saat resume ditunda ke langkah berikutnya.
- Belum ada tombol untuk mematikan biometrik. Dibuat di layar Profil (Fitur 07).
- Build Android memakai kotlin.incremental=false di android/gradle.properties karena proyek (drive D) dan cache paket (drive C) berbeda drive. Developer Mode Windows aktif. Perbaikan permanen: satukan drive (PUB_CACHE atau lokasi proyek).
- Bersih-bersih akhir proyek: hapus akun uji (misalnya rais_uji) beserta sesi dan baris login_attempts di Supabase, hapus fungsi hello, pastikan tidak ada berkas JSON uji atau rahasia di repo.

## Menunggu jawaban dosen
- [ ] Tema (V60 pelatih/jurnal vs Brewmaster)
- [ ] Apakah login boleh dibuat sendiri di server (Edge Function, hash password dan session buatan sendiri), tanpa Firebase dan tanpa layanan auth siap pakai?
- [ ] Supabase diperbolehkan untuk bagian online
- [x] Penempatan Saran & Kesan dan Logout di bottom navigation: diputuskan mengikuti bunyi slide, tetap boleh dikonfirmasi kepada dosen

## Daftar tangkapan layar untuk laporan
(centang setelah diambil: login, biji, atur seduh, sesi, hasil, jurnal, bandingkan, verifikasi, event, peta, game, profil)
