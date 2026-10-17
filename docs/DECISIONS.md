# DECISIONS: Tetes

Catat keputusan yang sudah diambil agar tidak diperdebatkan ulang. Format: tanggal, keputusan, alasan.

| Tanggal | Keputusan | Alasan |
|---|---|---|
| (awal) | Nama aplikasi Tetes, tagline "Jurnal seduh V60" | Terhindar dari awalan "Brew" yang dekat dengan Brewmaster |
| (awal) | Hanya V60, tanpa katalog resep, berbagi resep, atau pencari kedai | Menjaga pembeda dari tema Brewmaster |
| (awal) | Login lokal di Flutter (hash + salt, session di secure storage) | Memenuhi aturan tanpa Firebase, hemat waktu. Batasannya dicatat di laporan |
| (awal) | Supabase hanya untuk Postgres dan Edge Function, tanpa Supabase Auth | Menghindari kesan sama dengan Firebase Auth |
| (awal) | Skor stabilitas tuangan dari sensor dibatalkan. Sensor hanya untuk timer dan game | Tidak bisa dipertanggungjawabkan sebagai pengukuran seduhan nyata |
| (awal) | Scale IoT dikeluarkan. Berat air aktual diisi manual | Risiko waktu, protokol tiap merek berbeda |
| (awal) | Ambang stok menipis default 15 g | Satu kali seduh sekitar 15 g |
| (awal) | Stok dihitung (initial_stock_g dikurangi seduhan aktif), tidak disimpan | Konsisten saat seduhan dibatalkan |
| (awal) | Sinkronisasi v1 hanya push | Hemat waktu, cukup untuk persyaratan |
| (awal) | Saran & Kesan dan Logout sementara di Profil | Menunggu jawaban dosen |
| (awal) | State management: Riverpod | Pilih satu di Sprint 1, jangan dicampur |
| (UI) | Gaya UI: bersih, sejuk, kartu bersudut sangat membulat, aksen cyan dan mint, kontras hitam | Satu gaya konsisten dari referensi. Tema dibuat sekali di Sprint 1 |
| (UI) | Font Plus Jakarta Sans dikemas di aset (Zona Pro dari referensi mungkin berbayar) | Offline-first, tanpa paket tambahan, gaya serupa |
| (UI) | Tema dasar terang. Layar fokus (Sesi, Game) gelap lewat override tema lokal | Angka besar terbaca saat menuang. Tidak ada mode gelap sistem |
| (UI) | Teks di atas cyan dan mint selalu hitam | Cyan terlalu terang untuk teks putih |
