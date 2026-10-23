# PROGRESS: Tetes

## 2026-10-23 - Tanya Barista tanpa UI
- Edge Function chat dan kuota harian terpisah disiapkan; migrasi server belum diterapkan dan fungsi belum di-deploy.
- Klien chat, SQLite `chat_messages` versi 3, repository per pengguna, controller Riverpod, context biji dan lima seduhan terakhir, serta tes Flutter ditambahkan. Layar chat dikerjakan pemilik proyek. Seluruh 308 tes Flutter lulus dan `flutter analyze --no-pub` bersih; integrasi pada HP dan server terpasang belum diuji.

Perbarui di akhir setiap sesi.

## Status sprint

| Sprint | Fokus | Spec | Status | Catatan |
|---|---|---|---|---|
| 1 | Fondasi, login online buatan sendiri, biometrik, navigasi | 00, 01 | Selesai | Fitur 00 selesai. Fitur 01: server (register, login, logout, pembatasan percobaan) dan Flutter (register, login, session, guard, logout, biometrik) sudah diimplementasikan. Fitur 01 lolos uji di HP  |
| 2 | Profil biji, kurs, Atur Seduh | 02, 03 (bagian A) | Sedang jalan | Implementasi fitur 02 dan Atur Seduh ada; uji manual di HP masih menunggu. |
| 3 | Sesi, hasil, hash chain | 03 (bagian B, C) | Sedang jalan | Implementasi dan tes otomatis ada; sensor, getar, suara, serta alur Sesi dan Hasil masih perlu uji HP. |
| 4 | Jurnal | 04 | Sedang jalan | Daftar, detail, bandingkan seduhan, grafik skor, dan verifikasi ada. Pengaturan terbaik manual dan perbandingan dua biji belum selesai. |
| 5 | Sinkronisasi dan AI | 05 | Sedang jalan | Push/pull dan AI diimplementasikan; migrasi/deploy sinkronisasi lanjutan dan uji live/HP masih menunggu. |
| 6 | Event, notifikasi, LBS | 06 | Sedang jalan | Agenda, notifikasi, peta toko, rute, dan kurs ada; uji notifikasi, lokasi, dan peta di HP masih menunggu. |
| 7 | Game, profil, perapian | 07 | Sedang jalan | Game, profil, dan perapian UI diimplementasikan; kalibrasi sensor, kamera, biometrik, dan tampilan di HP masih menunggu. |
| 8 | Pengujian, laporan, presentasi | - | Sedang jalan | Tes otomatis dan analisis dilakukan; uji HP, tangkapan layar, laporan, serta presentasi belum selesai. |

Status: Belum mulai / Sedang jalan / Selesai (lolos acceptance) / Terblokir

## Terakhir dikerjakan
2026-10-23: Daftar Biji kopi menampilkan bagian biji diarsipkan yang tertutup secara default dan tombol Pulihkan. Repository memulihkan flag arsip serta menandai bean pending dengan waktu UTC baru; stok tetap dihitung dari seduhan aktif, sedangkan riwayat dan hash tidak diubah. Seluruh 302 tes Flutter dan `flutter analyze --no-pub` lulus; uji di HP masih menunggu.

2026-10-23: Pengaman stok seduh ditambahkan: dosis di atas sisa stok menampilkan peringatan di Atur Seduh dan menonaktifkan Mulai Sesi; Hasil menonaktifkan Simpan bila stok tidak cukup; repository menolak dalam transaksi tanpa menyimpan seduhan/tahap dan tetap memperbarui status sinkronisasi bean saat berhasil. Form biji menerima stok 0 g dan menolak nilai negatif; edit stok awal tidak boleh lebih kecil dari total dosis seduhan aktif. Pembatalan tetap memulihkan stok lewat perhitungan seduhan aktif. Data lama yang sudah minus tidak diubah otomatis. Tes terarah dan analisis lulus; suite penuh dan uji HP masih menunggu.

2026-10-23: Dokumen navigasi dan Profil diselaraskan untuk empat item: Beranda sebagai hub fitur dengan satu daftar biji, ikon Profil berupa foto atau inisial, label satu baris, Logout sebagai dialog dengan peringatan data belum sinkron, dan Profil berisi header statistik, Keamanan, Sinkronisasi, Pengingat, serta Tentang dengan atribusi OpenStreetMap dan OpenFreeMap. Uji di HP tetap menunggu.

2026-10-23: Visual Beranda mengikuti mockup: header dua baris dengan chip sinkron sejajar, kartu putih Mulai seduh/Seduh lagi, ringkasan tetap tanpa gulir horizontal, serta satu grid enam Pintasan. Bar bawah memakai area ikon seragam dan label satu baris. Bintang rating memakai komponen ikon bersama di Beranda dan kartu Jurnal; rasio 1:15 dan 1:15.5 memakai pemformat yang sama. Sapaan 00.00–04.59 diperbaiki menjadi Selamat malam. Ikon biji kopi bergaris dipakai konsisten pada pintasan, kartu tambah biji, dan Seduh lagi. UI_SPEC diselaraskan dan token warna rating ditambah. Seluruh 292 tes Flutter lulus, termasuk batas jam sapaan, lebar 320 dengan teks 1,3×, dan username panjang; `flutter analyze --no-pub` bersih. Uji visual di HP masih menunggu.

2026-10-23: Navigasi diringkas menjadi Beranda, Profil, Saran & Kesan, dan aksi Logout. Beranda menampilkan sapaan, status sinkron, Mulai seduh/Seduh lagi, tiga ringkasan data lokal, dan enam pintasan. Jurnal, Biji kopi, Agenda Event, Toko Terdekat, Kalkulator Kurs, serta Game dibuka penuh dari Beranda; payload stok, event, dan pengingat seduh diarahkan ke tujuan yang sama saat aplikasi dibuka atau aktif. Dokumen PRD, UI_SPEC, dan Fitur 00 diselaraskan. Seluruh 289 tes Flutter lulus, termasuk SQLite offline, layar 320 dengan teks 1,3×, tombol kembali, dan payload notifikasi; `flutter analyze` bersih. Uji HP masih menunggu.

2026-10-22: Perapian UI: tooltip ScoreChart memakai tipografi tema dan bintang `★` terverifikasi; nama layar Hasil dan semua rujukan kode/tes tidak lagi memakai `placeholder`; form biji memiliki judul Info biji, Pengolahan, Pembelian, dan Rasa; jarak dan pembungkusan teks di Hasil, Atur Seduh, serta tombol bersama dirapikan. Audit `lib/` tidak menemukan karakter encoding rusak, TODO aktif, atau nilai warna/font/jarak/radius langsung di layar yang perlu dipindahkan. Widget test pada lebar 320 dan teks 1,3× lulus; seluruh 277 tes Flutter dan `flutter analyze` bersih. `graphify update .` berhasil. Uji tampilan dan alur di HP masih menunggu.

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
- Build Android masih memakai kotlin.incremental=false di android/gradle.properties; setelah proyek dipindah ke C:\src\tetes, opsi ini belum diuji ulang untuk dihapus.
- Bersih-bersih akhir proyek: hapus akun uji (misalnya rais_uji) beserta sesi dan baris login_attempts di Supabase, hapus fungsi hello, pastikan tidak ada berkas JSON uji atau rahasia di repo.
- uji live diagnosa dan penyimpanan ai_advice menunggu Gemini stabil; server dan klien sudah menangani 503 (percobaan ulang, pesan sibuk, cooldown, fallback).” Fitur AI tetap bisa dipakai lewat fallback aturan sederhana, jadi aplikasi tidak rusak.

## Status pertanyaan dosen
- [x] Tema (V60 pelatih/jurnal vs Brewmaster): sudah aman menurut pembaruan status proyek.
- [x] Login buatan sendiri di server tanpa Firebase atau layanan auth siap pakai: sudah aman menurut pembaruan status proyek.
- [x] Supabase untuk bagian online: sudah aman menurut pembaruan status proyek.
- [x] Penempatan menu di bottom navigation: sudah aman menurut pembaruan status proyek; Beranda, Profil, Saran & Kesan, dan aksi Logout.

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

## 2026-10-21 - Fitur 05 langkah 4
- Migrasi ai_usage dan RPC increment_ai_usage dibuat dengan RLS tanpa policy serta hak eksekusi hanya service_role.
- Edge Function ai untuk recommend/diagnose dibuat dengan validasi input dan keluaran, batas 20 permintaan per jam, Gemini dari environment, timeout 15 detik, retry keluaran sekali, dan log terbatas pada jenis/durasi/kode. Uji live diagnose menghasilkan 200 dan input suhu di luar batas menghasilkan 400; uji di HP menunggu.
- Tes validator Deno disiapkan; kasus keluaran dan alur permintaan diuji dengan runtime Node karena Deno tidak tersedia lokal.
- Perbaikan review: prompt recommend meminta jumlah tahap sesuai pouring_count, validator menolak jumlah yang berbeda, dan retry tetap memakai satu pemanggilan ai_usage per permintaan. Sepuluh tes validator dan alur lulus lewat Node; Deno belum tersedia lokal.
- Setelah uji live recommend menghasilkan ai_invalid_output, prompt Gemini diperjelas agar mengikuti seluruh batas dan bentuk JSON yang sudah diwajibkan validator tanpa melonggarkannya. Tes mock memeriksa instruksi dan application/json yang benar-benar dikirim, keluaran sah setelah retry, serta satu pemanggilan ai_usage; uji live ulang belum dilakukan.

## 2026-10-21 - Fitur 05 langkah 5
- AiClient Flutter mengirim recommend/diagnose dengan session token dari secure storage, batas 35 detik, pemetaan galat bahasa Indonesia dan keluar paksa pada 401. Riwayat AI dibatasi lima seduhan aktif milik pengguna dan biji terkait (seduhan terbaik serta terbaru).
- Atur Seduh menerapkan rekomendasi hanya setelah tombol ditekan dan validasi rencana lokal lulus. Hasil menampilkan diagnosa serta saran yang dapat diterapkan secara manual ke seduhan berikutnya; hasil AI yang tidak bisa menjadi rencana lokal memakai fallback dengan pesan jelas. Tahap rencana berikutnya dihitung ulang. Respons terlambat setelah form berubah atau layar ditinggalkan tidak mengubah isian; 401 tetap mengakhiri sesi bila akun permintaan masih aktif.
- Diagnosa AI yang valid disimpan sebagai teks JSON di brews.ai_advice saat seduhan disimpan, di luar hash, lalu dibaca sebagai saran di detail Jurnal. Jalur sync-push meneruskan teks JSON ini tanpa mengubahnya.
- Seluruh 211 tes Flutter lulus dan flutter analyze bersih melalui runtime Flutter yang terpasang, termasuk tes 401 terlambat dan perubahan akun. Uji langsung di HP belum dilakukan. Pembuatan diagnosa dari Jurnal setelah seduhan tersimpan tidak termasuk langkah ini.
- 2026-10-21: Atur Seduh kini menampilkan kartu ringkas perubahan rekomendasi AI, penanda kolom, dan pemulihan rencana lengkap; galat jaringan atau layanan memicu hitungan mundur 30 detik, status upstream 503/429 mendapat pesan sibuk, dan uji HP masih menunggu.

- Diagnosa AI dipindah ke Detail setelah seduhan tersimpan; Hasil hanya menyimpan seduhan, dan saran AI aktif disimpan tanpa mengubah rantai hash (uji HP masih diperlukan).

- Fungsi AI kini menghapus temperature Gemini, membatasi total dua percobaan dalam 15 detik bersama, mencoba ulang HTTP 503 sekali, dan mencatat metadata kegagalan terbatas tanpa data pengguna.

## 2026-10-21 - Fitur 06 sesi A
- Tab Eksplor dan agenda event lokal selesai: tambah, ubah, hapus lunak, detail, daftar mendatang/lampau, serta tampilan WIB, WITA, WIT, dan London.
- Zona IANA memakai timezone 0.11.2; jam London yang ambigu atau tidak ada ditolak dengan arahan memilih jam lain. Pengingat 1–3 pilihan disimpan berurutan menurun, belum dijadwalkan.
- Tes waktu dan repository mencakup pergantian jam London, isolasi pengguna, status sinkronisasi, serta hapus lunak. Seluruh 220 tes Flutter lulus dan `flutter analyze` bersih; uji langsung di HP masih menunggu.

- 2026-10-21: Tampilan Agenda Event diringkas dengan waktu zona asal, WIB, penanda beda hari, hitung mundur, dan detail empat zona; tes utilitas serta analisis lulus, uji HP menunggu.

- 2026-10-21: Fitur 06 sesi B menambahkan pengingat event dan seduh, notifikasi stok saat melintasi ambang, izin dan pengaturan Profil, serta pembatalan saat logout; build Android debug dan tes otomatis lulus, sedangkan uji notifikasi di HP asli masih menunggu.

## 2026-10-21 - Fitur 07 sesi A, prototipe kontrol
- Kartu Game di Eksplor membuka layar kalibrasi dan titik kontrol gyroscope. Kecepatan putar diintegrasikan memakai selisih cap waktu sensor, dengan peredaman, batas sudut, dan tiga sensitivitas yang tersimpan per pengguna di settings.
- Sensor dibatalkan saat layar ditutup atau aplikasi ke latar belakang; game jeda dan meminta kalibrasi ulang saat dilanjutkan. Jika sensor gagal atau tidak mengirim data selama dua detik, game dinonaktifkan dengan pesan jelas. Belum ada level, zona, bar, getar/suara, skor, atau sinkronisasi.
- Uji di HP asli untuk rasa kontrol dan ketersediaan gyroscope masih menunggu masukan pengguna sebelum melanjutkan.
- Seluruh 233 tes Flutter lulus dan `flutter analyze --no-pub` bersih. Konfigurasi Android dan daftar paket tidak berubah.

## 2026-10-21 - Fitur 07 sesi A, level dan skor lokal
- Tiga level Steady Pour selesai dengan zona tetap/bergerak, hitung mundur, bar air, batas waktu, akurasi, bintang, hasil, penguncian level, dan skor tertinggi per pengguna.
- Waktu game dan gerak zona memakai dt dari cap waktu gyroscope yang dibatasi saat ada jeda besar. Hanya keberhasilan sebelum batas waktu masuk game_scores dengan UUID v4, waktu UTC tanpa milidetik, dan sync_status pending; kegagalan tidak disimpan.
- Jeda membatalkan langganan sensor dan umpan balik, lalu meminta kalibrasi ulang. Tes logika, sensor palsu, dan SQLite dalam memori mencakup batas waktu, ambang bintang, penyimpanan, MAX, dan isolasi pengguna. Seluruh 242 tes Flutter lulus; uji level di HP asli masih menunggu.
- 2026-10-21: Arah kontrol Steady Pour kini mempertahankan horizontal dan membalik vertikal, Cara main serta petunjuk level 1 ditambahkan, orientasi potret dipulihkan ke aturan aplikasi saat latar belakang atau keluar, dan 247 tes Flutter serta flutter analyze lulus.

## 2026-10-22 - Fitur 07 sesi B
- Profil kini menampilkan foto lokal dan akun, sakelar biometrik per pengguna, verifikasi integritas jurnal, serta kartu Sinkronisasi dan Notifikasi yang dipakai ulang; Saran & Kesan menyimpan dan menampilkan riwayat lokal per pengguna tanpa sinkronisasi server. Foto lama baru dihapus setelah foto baru dan path tersimpan. Seluruh 255 tes Flutter dan flutter analyze lulus; uji kamera, galeri, dan biometrik di HP asli masih menunggu.

## 2026-10-22 - Fitur 06 langkah 5 dan 6
- Seed 15 toko lokal tanpa menimpa data lama, peta dan daftar toko dengan filter, jarak, izin lokasi, navigasi, serta kalkulator kurs melalui cache Fitur 02 selesai. Tile mengikuti area peta terlihat dan peta hanya berpusat pada lokasi pengguna dalam batas DIY. Uji di HP asli masih menunggu.
- Tampilan toko memakai tile CARTO Voyager, filter Biji/Alat, ikon toko konsisten, kontrol zoom/posisi/kompas, kerucut arah bila sensor tersedia, dan rute OSRM dengan persetujuan, moda serta langkah bahasa Indonesia. Uji langsung di HP masih menunggu.
- Perbaikan peta: OpenFreeMap liberty menggantikan CARTO, tile OSM standar selalu tersedia di bawahnya dan mengambil alih saat gaya/tile vektor gagal; gaya membalas HTTP 200 tanpa key dari mesin kerja. Atribusi popup dan Profil Tentang ditambah. Peta kini memenuhi layar dengan satu sheet tarik untuk daftar, detail, serta rute; kontrol mengikuti tepi sheet dan kamera rute memperhitungkan area tertutup. Seluruh 270 tes Flutter dan flutter analyze lulus; uji visual tile vektor di HP masih menunggu.

## 2026-10-22 - Fitur 05 sinkronisasi lanjutan
- Events, game_scores, dan feedback disiapkan untuk push/pull dengan kursor waktu server, validasi per baris, tombstone event, status Profil, dan penjadwalan ulang notifikasi. Seluruh 275 tes Flutter dan flutter analyze lulus; validasi server diuji dengan Node karena Deno tidak tersedia. Migrasi, deploy, dan uji HP masih menunggu.

## 2026-10-23 - Auth lokal, langkah SQL
- Migrasi baru menyiapkan grant kolom dan policy RLS untuk akses anon ke users dan sessions berdasarkan header permintaan; login_attempts serta RPC penghitung lama dihapus. Tidak ada trigger atau RPC auth baru.
- Test SQL untuk akses tanpa header, header salah, pembacaan baris lain, pencabutan sesi sendiri, larangan mengaktifkan ulang sesi, dan larangan DELETE disiapkan. Migrasi dan test belum dijalankan pada PostgreSQL; db push dan perubahan Flutter menunggu peninjauan pemilik.
- Review test menambah kasus INSERT anon dan kecocokan header untuk `INSERT users ... RETURNING`; dokumen mencatat header wajib dan celah pemalsuan sesi yang nyata. Eksekusi PostgreSQL tetap menunggu lingkungan database uji.

## 2026-10-23 - Auth lokal, langkah Flutter
- AuthClient sekarang memakai PostgREST untuk dua POST register, GET login, dan PATCH logout; hash PBKDF2 dijalankan di isolate, penghitung gagal lokal disimpan di secure storage, dan kegagalan membuat sesi setelah akun jadi mengarahkan ke Login.
- Tiga Edge Function auth dihapus dari repo; `_shared/auth.ts` dan `_shared/session.ts` tetap dipakai validasi sesi fitur lain. Konfigurasi auth dibaca dari `--dart-define-from-file=env/app.json`; file lokal diabaikan Git.
- Vektor PBKDF2 dari Node.js mencakup ASCII, Unicode, 128 karakter, dan 600.000 iterasi. `flutter analyze --no-pub` bersih dan seluruh 311 test Flutter lulus. Migrasi/deploy dan pengukuran profile di HP belum dilakukan.
- Pengukuran profile di Samsung SM-A546E menghasilkan 6.834 ms untuk PBKDF2 Dart murni. Jalur native Android dari `cryptography_flutter` ditambahkan dengan fallback Dart dalam isolate; iterasi tetap 600.000. Pengukuran native di HP masih menunggu.
- `flutter pub get` berhasil dengan `cryptography` 2.9.0 dan `cryptography_flutter` 2.3.4. Vektor Node.js lulus pada jalur paket dan fallback, termasuk 600.000 iterasi; galat jalur utama juga jatuh ke fallback. `flutter analyze --no-pub` bersih dan seluruh 316 test Flutter lulus. Jalur native Android belum diuji di HP.
