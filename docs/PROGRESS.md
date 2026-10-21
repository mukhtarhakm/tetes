# PROGRESS: Tetes

Perbarui di akhir setiap sesi.

## Status sprint

| Sprint | Fokus | Spec | Status | Catatan |
|---|---|---|---|---|
| 1 | Fondasi, login online buatan sendiri, biometrik, navigasi | 00, 01 | Selesai | Fitur 00 selesai. Fitur 01: server (register, login, logout, pembatasan percobaan) dan Flutter (register, login, session, guard, logout, biometrik) sudah diimplementasikan. Fitur 01 lolos uji di HP  |
| 2 | Profil biji, kurs, Atur Seduh | 02, 03 (bagian A) | Sedang jalan | Fitur 02 dan implementasi Fitur 03 bagian A selesai; tahap tanpa jeda memakai warna konsisten pada kartu, timeline, dan grafik; Atur Seduh menunggu uji manual di HP |
| 3 | Sesi, hasil, hash chain | 03 (bagian B, C) | Selesai | Sesi B dan C selesai: tahap otomatis/drawdown/timer aktif, layar Hasil, penyimpanan atomik dengan hash chain, pengaturan terbaik, biaya, dan stok |
| 4 | Jurnal | 04 | Sedang jalan | Fitur 04 Sesi A & B selesai: tab Jurnal (sub-tab Seduhan & Biji, perbandingan 2 seduhan dengan ringkasan murni & sorotan beda, grafik skor fl_chart tanpa seduhan dibatalkan, pembacaan stok & ambang batas tanpa N+1). Sesi berikutnya: jadikan pengaturan terbaik manual & bandingkan dua biji |
| 5 | Sinkronisasi dan AI | 05 | Belum mulai | |
| 6 | Event, notifikasi, LBS | 06 | Belum mulai | |
| 7 | Game, profil, perapian | 07 | Belum mulai | |
| 8 | Pengujian, laporan, presentasi | - | Belum mulai | |

Status: Belum mulai / Sedang jalan / Selesai (lolos acceptance) / Terblokir

## Terakhir dikerjakan
2026-10-20: Penyempurnaan Fitur 04: sub-tab Biji dicabut dari tab Jurnal sehingga menjadi satu daftar seduhan tunggal; tombol pemicu mode perbandingan diubah menjadi "Bandingkan" dengan ikon perbandingan; bar aksi perbandingan dipindahkan ke bawah di atas bottom nav dengan padding dinamis dari tinggi bar dan reset otomatis saat berpindah tab; kartu seduhan ditata ulang dengan judul di baris sendiri, pil status terpisah dengan Wrap, dan parameter fleksibel tahan pembesaran font. Seluruh 164 tes unit/widget lulus dan flutter analyze bersih.
2026-10-20: Fitur 04 Sesi B selesai: tab Jurnal memiliki sub-tab Seduhan dan Biji; mode pilih pada sub-tab Seduhan membatasi tepat dua entri dan menolak entri ke-3 dengan pesan singkat; layar Bandingkan menyajikan dua kolom berdampingan (seduhan lama di kiri, baru di kanan), menyoroti baris berbeda dengan token tema (primaryContainer & pill Beda), dan kalimat ringkasan dibuat dengan fungsi murni tanpa AI; sub-tab Biji menampilkan daftar biji aktif milik pengguna dengan sisa stok dan pengaturan terbaik aktif tanpa N+1 query (JOIN/subquery), serta StatusPill stok menipis berdasarkan setting user; layar detail biji diperkaya dengan ScoreChart tren skor rasa dari seduhan aktif (minimal dua titik data) menggunakan fl_chart dan riwayat seduhan biji terkait. Seluruh 163 tes unit/widget lulus dan flutter analyze bersih.
2026-10-20: Fitur 04 Sesi A selesai: tab Jurnal seduhan menggantikan tampilan sementara di AppShell; query SQLite aman di BrewRepository dengan parameter terikat dan batas user_id aktif; pencarian ber-escape ('\' untuk '%' dan '_'); filter kombinasi (biji, skor minimal, tag rasa utuh, rentang tanggal lokal-ke-UTC inklusif sampai akhir hari, dan urutan dengan cost_idr null di akhir); kartu seduhan menampilkan waktu lokal, rasio, suhu, skor rasa, tag rasa, StatusPill, badge "Terbaik", dan tampilan pudar bila dibatalkan; detail seduhan memuat ringkasan, tabel tahap, tag rasa vs roastery berdampingan, catatan, saran AI, integritas (seq & 8 karakter pertama hash); aksi "Seduh lagi" memuat parameter tahap tanpa mengubah logika sesi (menolak jika biji terarsip); aksi "Tandai dibatalkan" dalam satu transaksi tanpa menyentuh rantai hash dan menghitung ulang pengaturan terbaik serta stok. Seluruh 150 tes lulus dan `flutter analyze` bersih.
2026-10-20: `hashEntry` dan `verifyChain` kini memverifikasi rantai termasuk entri dibatalkan, melaporkan seq yang hilang, dan menerima daftar kosong; seluruh 129 tes lulus serta `flutter analyze` bersih.
2026-10-20: Penyempurnaan Fitur 03 Sesi: tahap berganti pada `target_start_s`, tanpa tombol manual atau waktu aktual tahap. Fase drawdown dimulai setelah tuangan terakhir, lalu berakhir lewat Air habis, Lewati, atau batas 10 menit. Jeda menghentikan waktu aktif sehingga `total_time_s` dan tenggat tahap tidak menghitung jeda; kembali dari latar belakang merekonsiliasi tahap tanpa umpan balik yang terlewat. Placeholder hasil menerima `total_time_s` dan `drawdown_s`. Seluruh 124 tes lulus dan `flutter analyze` bersih; uji manual di HP masih menunggu.
2026-10-19: Penyempurnaan Fitur 03 Sesi selesai: warna tahap kini diterapkan pada kartu tahap aktif, kartu waktu total, baris aktif, dan penanda tiap tahap melalui pemetaan token terpusat. Semua pergantian tahap memakai satu getar panjang dan nada sistem pendek; akhir sesi memakai getar lebih panjang dan nada alarm yang berbeda, dapat dibatalkan saat tahap berubah atau layar ditutup. Tahap terakhir kini berakhir otomatis pada tenggat atau lebih awal lewat tombol “Selesai”; `total_time_s` mengikuti waktu akhir aktual/tenggat dan `drawdown_s` selalu `null`. Rekonsiliasi setelah latar belakang menutup sesi pada tenggat tahap terakhir tanpa memutar ulang umpan balik tahap yang terlewat. Implementasi ini sengaja berbeda dari `03-brew.md` bagian B: perpindahan tahap dan akhir sesi otomatis, tanpa jeda, serta drawdown tidak dicatat. Dependensi `vibration` dan `flutter_ringtone_player` ditambahkan; subproject `flutter_ringtone_player` dipaksa memakai compile SDK 36 melalui `finalizeDsl`. APK debug berhasil dibangun, seluruh 118 tes lulus, dan `flutter analyze` bersih; warna, suara, getar, sensor, dan perilaku latar belakang menunggu uji manual di HP.
2026-10-19: Penyempurnaan Fitur 03 Sesi A dan B selesai: konsep jeda dihapus dari model, kalkulator, penyuntingan, visual, pembacaan pengaturan terbaik, dan tes; lima token warna tahap dipakai konsisten pada kartu, timeline, dan grafik garis linear. Sesi berpindah otomatis berdasarkan `actual_start_s + target_duration_s`, tombol manual menggeser tenggat berikutnya, dan rekonsiliasi setelah latar belakang menutup tahap terlewat pada tenggatnya tanpa mengulang umpan balik. Pola getar tahap memakai jumlah getar sesuai nomor tahap dengan interval bernama 200 ms, dapat dibatalkan, sementara “Air habis” memakai getar kuat. Implementasi ini sengaja berbeda dari `03-brew.md` bagian B: perpindahan tahap otomatis dan tanpa jeda. Seluruh 114 tes lulus dan `flutter analyze` bersih; warna, suara, pola getar, sensor, dan rekonsiliasi latar belakang menunggu uji manual di HP.
2026-10-19: Fitur 03 Sesi B diimplementasikan: format input hash tunggal dan SHA-256 lolos dua vektor uji, sesi seduh memakai Stopwatch, pergantian tahap manual, waktu aktual dan drawdown direkam di memori, countdown tidak memajukan tahap, getar/suara memberi tanda, goyang hanya memulai timer, wakelock aktif selama sesi, pembatalan memakai konfirmasi, dan hasil diteruskan ke placeholder. Seluruh 108 tes lulus dan `flutter analyze` bersih; sensor, wakelock, suara, getar, dan perilaku latar belakang menunggu uji manual di HP.
2026-10-19: Fitur 03 Sesi A diimplementasikan: kalkulator dan validasi rencana seduh murni, pengeditan tahap dengan sisa otomatis, pembacaan pengaturan terbaik secara hanya-baca, layar Atur Seduh dengan empat keadaan, timeline, grafik air kumulatif, placeholder sesi, serta pintu masuk dari tab Seduh dan detail biji. Seluruh 90 tes lulus dan `flutter analyze` bersih; uji manual di HP belum dilakukan.
2026-10-19: Fitur 02 Sesi B selesai: kurs IDR/asing, cache per mata uang, fallback offline, pratinjau rupiah, preservasi kurs saat input harga tidak berubah, dan detail harga rupiah telah diimplementasikan; seluruh 71 tes lulus dan `flutter analyze` bersih.
2026-10-19: `AppChip` kini mengikuti lebar isi sehingga kelompok chip tersusun berdampingan, dan mata uang pada form biji memakai dropdown pil sejajar dengan harga kemasan.
2026-10-19: Tampilan `AppChip` diperjelas dengan latar `surface` dan garis `divider` pada chip terang yang tidak aktif; seluruh kelompok chip form biji memakai `Wrap` dan jarak token tanpa memotong teks.
2026-10-19: Fitur 02 tanpa kurs diperbarui. Migrasi SQLite v2 menambahkan `pack_size_g` dan `process_custom` tanpa mengubah migrasi 1; instalasi baru dan upgrade v1 menghasilkan skema akhir yang sama. Form mengikuti urutan baru, harga berarti harga satu kemasan, ukuran kemasan dapat dipilih lewat chip atau diisi sendiri, dan stok terisi otomatis sampai diedit manual. Proses Lainnya serta tag notes buatan sendiri divalidasi, disimpan terurut, dan tetap dapat diedit. Detail aman untuk biji lama yang belum memiliki ukuran kemasan. Kolom kurs tetap kosong sampai sesi kurs. Biji tetap hanya dapat diarsipkan, bukan hard-delete. Seluruh 59 tes lulus dan `flutter analyze` bersih.

## Masalah terbuka
(bug yang belum beres, hal yang menunggu jawaban dosen)

- Guard belum memeriksa ulang masa berlaku session ketika aplikasi kembali dari latar belakang; pengecekan saat resume ditunda ke langkah berikutnya.
- Belum ada tombol untuk mematikan biometrik. Dibuat di layar Profil (Fitur 07).
- Build Android memakai kotlin.incremental=false di android/gradle.properties karena proyek (drive D) dan cache paket (drive C) berbeda drive. Developer Mode Windows aktif. Perbaikan permanen: satukan drive (PUB_CACHE atau lokasi proyek).
- Bersih-bersih akhir proyek: hapus akun uji (misalnya rais_uji) beserta sesi dan baris login_attempts di Supabase, hapus fungsi hello, pastikan tidak ada berkas JSON uji atau rahasia di repo.
- Perapian layout (nanti, tahap perapian): layar Hasil dan Atur Seduh; ganti nama berkas brew_result_placeholder_screen.dart karena sudah bukan placeholder.
- Judul bagian di form biji ("Info biji", "Pengolahan", "Kemasan dan harga").

## Menunggu jawaban dosen
- [ ] Tema (V60 pelatih/jurnal vs Brewmaster)
- [ ] Apakah login boleh dibuat sendiri di server (Edge Function, hash password dan session buatan sendiri), tanpa Firebase dan tanpa layanan auth siap pakai?
- [ ] Supabase diperbolehkan untuk bagian online
- [x] Penempatan Saran & Kesan dan Logout di bottom navigation: diputuskan mengikuti bunyi slide, tetap boleh dikonfirmasi kepada dosen

## Daftar tangkapan layar untuk laporan
(centang setelah diambil: login, biji, atur seduh, sesi, hasil, jurnal, bandingkan, verifikasi, event, peta, game, profil)

- 2026-10-20: Fitur 03 Sesi C selesai: layar Hasil, penyimpanan seduhan atomik dengan hash chain, pengaturan terbaik, biaya, dan pengecekan stok tersedia.

## 2026-10-20 - Fitur 05 langkah 1
- Migrasi baru menyiapkan tabel beans, brews, brew_stages serta RPC atomik untuk upsert biji dan insert seduhan.
- Edge Function sync-push dan helper hash server dengan dua vektor uji disiapkan; belum diterapkan ke server dan menunggu uji deploy/curl.

## 2026-10-20 - Fitur 05 langkah 2
- Klien push Flutter untuk beans, brews, dan brew_stages selesai: batch 100/50, status lokal, ringkasan UTC, dan penanganan galat/401.
- Profil menampilkan status dan tombol sinkron manual; pemicu otomatis aktif saat session valid dan setelah seduhan disimpan atau dibatalkan.
- Sinkronisasi pull, AI, events, game_scores, dan feedback belum dikerjakan.

## 2026-10-21 - Fitur 05 langkah 3
- Edge Function sync-pull disiapkan untuk membaca beans dan rantai brews bertahap dengan pemeriksaan session, prefix hash, batas 500 biji, urutan stages, serta waktu seduh asli untuk verifikasi hash klien.
- Konfigurasi fungsi memakai verify_jwt=false. sync-pull sudah di-deploy dan skenario status, respons tanpa user_id, serta tipe angka lulus uji curl. Uji di HP dan kecocokan brewed_at_utc dengan data asli sync-push belum dibuktikan.

## 2026-10-21 - Fitur 05 langkah 3b
- Klien pull untuk beans, brews, dan brew_stages selesai: session token, verifikasi hash sebelum tulis, transaksi per halaman, lanjut dari prefix lokal setelah halaman berikutnya gagal, dan ringkasan pull di settings.
- Pull otomatis senyap sekali setelah login/register baru bila belum ada seduhan lokal; tombol tarik manual dan hasil terakhir tampil di Profil. Best brew dihitung ulang dari seduhan aktif lokal setelah pull selesai.
- Tes SQLite dalam memori mencakup halaman jamak, prefix, hash salah, rollback, kegagalan halaman kedua lalu lanjut, konflik, isolasi pengguna, 401, dan kunci push/pull. Uji di HP masih menunggu.
