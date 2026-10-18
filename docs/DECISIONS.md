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
| 2026-10-18 | Pembatasan login dihitung server per username dalam jendela 15 menit | Username yang tidak ada tetap dihitung; kegagalan ke-5 menghasilkan `429` tanpa membocorkan keberadaan akun |
| 2026-10-18 | `sync-pull` menerima lokal kosong atau prefix valid dan menolak cabang | Mendukung perangkat baru tanpa menggabungkan dua riwayat yang berbeda secara otomatis |
| 2026-10-18 | Konflik rantai dapat dipulihkan ulang dari server hanya setelah konfirmasi jumlah data lokal dan pending | Pemulihan bersifat destruktif terhadap data sinkronisasi lokal sehingga harus eksplisit |
| 2026-10-18 | Logout offline menghapus session aktif lokal dan mengantrekan `pending_revoke_token` | Pengguna langsung keluar; pencabutan server dicoba saat online atau sebelum login berikutnya, dengan kedaluwarsa 7 hari sebagai pencadang |
