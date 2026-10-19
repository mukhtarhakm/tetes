# PROGRESS: Tetes

Perbarui di akhir setiap sesi.

## Status sprint

| Sprint | Fokus | Spec | Status | Catatan |
|---|---|---|---|---|
| 1 | Fondasi, login online buatan sendiri, biometrik, navigasi | 00, 01 | Selesai | Fitur 00 selesai. Fitur 01: server (register, login, logout, pembatasan percobaan) dan Flutter (register, login, session, guard, logout, biometrik) sudah diimplementasikan. Fitur 01 lolos uji di HP  |
| 2 | Profil biji, kurs, Atur Seduh | 02, 03 (bagian A) | Sedang jalan | Fitur 02 tanpa kurs diperbarui dengan ukuran kemasan, proses khusus, dan tag buatan sendiri |
| 3 | Sesi, hasil, hash chain | 03 (bagian B, C) | Belum mulai | |
| 4 | Jurnal | 04 | Belum mulai | |
| 5 | Sinkronisasi dan AI | 05 | Belum mulai | |
| 6 | Event, notifikasi, LBS | 06 | Belum mulai | |
| 7 | Game, profil, perapian | 07 | Belum mulai | |
| 8 | Pengujian, laporan, presentasi | - | Belum mulai | |

Status: Belum mulai / Sedang jalan / Selesai (lolos acceptance) / Terblokir

## Terakhir dikerjakan
2026-10-19: `AppChip` kini mengikuti lebar isi sehingga kelompok chip tersusun berdampingan, dan mata uang pada form biji memakai dropdown pil sejajar dengan harga kemasan.
2026-10-19: Tampilan `AppChip` diperjelas dengan latar `surface` dan garis `divider` pada chip terang yang tidak aktif; seluruh kelompok chip form biji memakai `Wrap` dan jarak token tanpa memotong teks.
2026-10-19: Fitur 02 tanpa kurs diperbarui. Migrasi SQLite v2 menambahkan `pack_size_g` dan `process_custom` tanpa mengubah migrasi 1; instalasi baru dan upgrade v1 menghasilkan skema akhir yang sama. Form mengikuti urutan baru, harga berarti harga satu kemasan, ukuran kemasan dapat dipilih lewat chip atau diisi sendiri, dan stok terisi otomatis sampai diedit manual. Proses Lainnya serta tag notes buatan sendiri divalidasi, disimpan terurut, dan tetap dapat diedit. Detail aman untuk biji lama yang belum memiliki ukuran kemasan. Kolom kurs tetap kosong sampai sesi kurs. Biji tetap hanya dapat diarsipkan, bukan hard-delete. Seluruh 59 tes lulus dan `flutter analyze` bersih.

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
