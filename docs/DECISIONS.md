# DECISIONS: Tetes

Catat keputusan yang sudah diambil agar tidak diperdebatkan ulang. Format: tanggal, keputusan, alasan.

| Tanggal | Keputusan | Alasan |
|---|---|---|
| (awal) | Nama aplikasi Tetes, tagline "Jurnal seduh V60" | Terhindar dari awalan "Brew" yang dekat dengan Brewmaster |
| (awal) | Hanya V60, tanpa katalog resep, berbagi resep, atau pencari kedai | Menjaga pembeda dari tema Brewmaster |
| (awal) | Login lokal di Flutter (hash + salt, session di secure storage) | Digantikan keputusan autentikasi server pada 2026-10-18 |
| (awal) | Supabase hanya untuk Postgres dan Edge Function, tanpa Supabase Auth | Menghindari kesan sama dengan Firebase Auth |
| (awal) | Skor stabilitas tuangan dari sensor dibatalkan. Sensor hanya untuk timer dan game | Tidak bisa dipertanggungjawabkan sebagai pengukuran seduhan nyata |
| (awal) | Scale IoT dikeluarkan. Berat air aktual diisi manual | Risiko waktu, protokol tiap merek berbeda |
| (awal) | Ambang stok menipis default 15 g | Satu kali seduh sekitar 15 g |
| (awal) | Stok dihitung (initial_stock_g dikurangi seduhan aktif), tidak disimpan | Konsisten saat seduhan dibatalkan |
| (awal) | Sinkronisasi v1 hanya push | Digantikan keputusan `sync-pull` prefix pada 2026-10-18 |
| (awal) | Saran & Kesan dan Logout sementara di Profil | Keputusan sementara sebelum bunyi slide diterapkan; digantikan keputusan 2026-10-18 |
| (awal) | State management: Riverpod | Pilih satu di Sprint 1, jangan dicampur |
| (UI) | Gaya UI: bersih, sejuk, kartu bersudut sangat membulat, aksen cyan dan mint, kontras hitam | Satu gaya konsisten dari referensi. Tema dibuat sekali di Sprint 1 |
| (UI) | Font Plus Jakarta Sans dikemas di aset (Zona Pro dari referensi mungkin berbayar) | Offline-first, tanpa paket tambahan, gaya serupa |
| (UI) | Tema dasar terang. Layar fokus (Sesi, Game) gelap lewat override tema lokal | Angka besar terbaca saat menuang. Tidak ada mode gelap sistem |
| (UI) | Teks di atas cyan dan mint selalu hitam | Cyan terlalu terang untuk teks putih |
| 2026-10-18 | Bottom navigation berisi Seduh, Jurnal, Eksplor, Saran & Kesan, Profil, dan Logout | Mengikuti bunyi slide tugas: Saran & Kesan menjadi tab sendiri, Profil tetap memuat foto, dan Logout menjadi aksi konfirmasi tanpa layar |
| 2026-10-18 | Register dan login dibuat online lewat Edge Function sendiri, tanpa Firebase atau Supabase Auth | Password di-hash dengan PBKDF2-HMAC-SHA256 memakai Web Crypto Deno; Flutter tidak menghitung atau menyimpan hash password |
| 2026-10-18 | Session memakai token acak 32 byte, server menyimpan SHA-256 token, berlaku 7 hari tanpa perpanjangan otomatis | Session valid dapat membuka aplikasi offline; pencabutan server diketahui pada permintaan terlindungi berikutnya |
| 2026-10-18 | Pembatasan login dihitung server per username dalam jendela 15 menit | Username yang tidak ada tetap dihitung; lima kegagalan menghasilkan `401` dan permintaan berikutnya `429` tanpa membocorkan keberadaan akun |
| 2026-10-18 | Risiko penguncian akun melalui percobaan pada username orang lain diterima untuk v1 | Pembatasan berbasis username dapat disalahgunakan untuk membuat akun lain terkena jeda 15 menit, tetapi dipilih sebagai kompromi lingkup tugas dan wajib dievaluasi lagi setelah v1 |
| 2026-10-18 | `sync-pull` menerima lokal kosong atau prefix valid dan menolak cabang | Mendukung perangkat baru tanpa menggabungkan dua riwayat yang berbeda secara otomatis |
| 2026-10-18 | Konflik rantai dapat dipulihkan ulang dari server hanya setelah konfirmasi jumlah data lokal dan pending | Pemulihan bersifat destruktif terhadap data sinkronisasi lokal sehingga harus eksplisit |
| 2026-10-18 | Logout offline menghapus session aktif lokal dan mengantrekan `pending_revoke_token` | Pengguna langsung keluar; pencabutan server dicoba saat online atau sebelum login berikutnya, dengan kedaluwarsa 7 hari sebagai pencadang |
| 2026-10-18 | Migrasi SQLite diuji di host dengan `sqflite_common_ffi` sebagai dev dependency | `sqflite` tetap dipakai di aplikasi Android, sedangkan FFI memungkinkan tes migrasi, foreign key, dan constraint berjalan tanpa mengubah database produksi |
| 2026-10-18 | Password server memakai PBKDF2-HMAC-SHA256 dengan 600.000 iterasi, salt acak 16 byte, dan keluaran 32 byte | Mengikuti rekomendasi OWASP yang dipilih untuk tugas; parameter disimpan per pengguna agar dapat dinaikkan pada masa depan |
| 2026-10-19 | Klien HTTP Flutter memakai paket `http` | Kebutuhan auth hanya POST JSON sederhana; API kecil, mudah diinjeksi untuk tes, dan tidak menambah kompleksitas interceptor yang belum diperlukan |
| 2026-10-19 | kotlin.incremental=false di android/gradle.properties | Proyek di drive D dan cache paket di drive C membuat Kotlin gagal ("different roots"). Workaround, build sedikit lebih lambat |
| 2026-10-19 | PBKDF2-HMAC-SHA256 dengan 600.000 iterasi di Edge Function | Mengikuti rekomendasi OWASP. Terukur sekitar 110 ms, jadi tidak perlu diturunkan |
| 2026-10-19 | Biometrik hanya membuka aplikasi lokal. "Pakai password" memakai alur logout yang sama | Menghindari token yatim di server. Tidak ada data biometrik yang disimpan atau dikirim |
| 2026-10-19 | API kurs: Frankfurter v1, https://api.frankfurter.dev/v1/latest?base=USD&symbols=IDR,EUR,JPY | Gratis, tanpa key, memuat IDR, USD, EUR, JPY. Alamat lama api.frankfurter.app mengalihkan (301). v1 disebut sudah digantikan v2 tapi masih berjalan, jadi alamat dasar dijadikan satu konstanta di app_config.dart. Kurs referensi harian hari kerja, bukan kurs jual-beli |
| 2026-10-20 | Sesi seduh memakai pergantian tahap otomatis, jeda waktu aktif, dan fase drawdown maksimal 10 menit; waktu aktual tahap selalu NULL | Target waktu tetap konsisten saat jeda atau kembali dari latar belakang, sementara Air habis/Lewati/batas waktu memberi total_time_s yang dapat di-hash tanpa mengubah skema |
