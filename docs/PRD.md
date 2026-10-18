# PRD: Tetes

**Tagline:** Jurnal seduh V60
**Jenis:** Aplikasi mobile (Flutter), tugas akhir Pemrograman Aplikasi Mobile
**Status:** Draf 1, siap dipecah menjadi spesifikasi per fitur
**Dokumen terkait (dibuat setelah PRD ini):** `ARCHITECTURE.md`, `DATA_MODEL.md`, `UI_SPEC.md`, `features/*.md`, `PROGRESS.md`, `AGENTS.md`

> Dokumen ini menjelaskan **apa** yang dibuat dan **mengapa**. Detail teknis, tabel, dan layar ada di dokumen terkait. Jika ada konflik antara PRD dan dokumen lain, PRD yang dianggap benar sampai diubah secara eksplisit.

---

## 1. Ringkasan

Tetes membantu homebrewer yang menyeduh V60 secara manual untuk **mencatat tiap seduhan, mengingat pengaturan terbaik untuk tiap biji, dan menyeduh dengan panduan timer bertahap**. Aplikasi ini tidak menyediakan resep bawaan. Isinya adalah data seduhan milik pengguna sendiri.

**Ide inti:** tiap biji kopi berbeda cara seduhnya. Tetes menyimpan profil tiap biji beserta pengaturan yang paling cocok (rasio, suhu, grind, pola tuang), sehingga seduhan berikutnya dimulai dari titik terbaik, bukan dari nol.

## 2. Latar Belakang dan Masalah

Homebrewer biasanya mengatur rasio, suhu, grind, dan pola tuang berdasarkan ingatan atau catatan acak. Masalah yang muncul:

1. Pengaturan terbaik untuk satu biji mudah terlupa, apalagi kalau punya beberapa biji.
2. Sulit membandingkan dua seduhan karena catatannya tidak seragam.
3. Timer dan takaran biasanya dipegang di aplikasi terpisah.
4. Tidak ada tempat untuk membandingkan rasa yang dirasakan dengan tasting notes dari roastery.

## 3. Tujuan

**Tujuan produk**
- Pengguna dapat menyeduh V60 dengan panduan timer dan takaran per tahap.
- Pengguna dapat menyimpan hasil seduhan dan melihat riwayat serta perbandingannya.
- Pengguna mendapat pengaturan awal yang relevan untuk tiap biji, berdasarkan data seduhannya sendiri.

**Tujuan tugas (wajib dipenuhi)**
- Memenuhi seluruh requirement tugas akhir (bagian 8).
- Berbeda jelas dari tema teman sekelas (bagian 6).
- Dapat dibangun dan diuji dalam 8 hari kerja.

**Bukan tujuan**
- Menjadi aplikasi komunitas atau katalog resep.
- Mengukur kualitas seduhan secara ilmiah.
- Menjadi produk komersial yang siap rilis.

## 4. Pengguna

**Pengguna utama:** homebrewer individu yang menyeduh V60 sendiri, ingin konsisten, dan suka bereksperimen dengan biji berbeda.

**Persona singkat:** mahasiswa atau pekerja yang punya 2-4 jenis biji sekaligus, menyeduh hampir setiap hari, kadang membeli biji dari luar kota atau luar negeri, dan ingin tahu kenapa seduhan hari ini lebih enak dari kemarin.

**User stories utama**
1. Sebagai homebrewer, saya ingin menyimpan profil tiap biji agar saya tahu detail dan stoknya.
2. Sebagai homebrewer, saya ingin mengatur rencana seduh (rasio, suhu, jumlah pouring, waktu) dan melihatnya secara visual sebelum mulai.
3. Sebagai homebrewer, saya ingin timer yang memandu tiap tahap sehingga saya fokus menuang.
4. Sebagai homebrewer, saya ingin mencatat hasil dan rasa, lalu melihat saran perbaikan.
5. Sebagai homebrewer, saya ingin aplikasi mengingat pengaturan terbaik tiap biji dan mengisinya otomatis.
6. Sebagai homebrewer, saya ingin mencari dan membandingkan seduhan lama.
7. Sebagai homebrewer, saya ingin mencatat harga biji impor dan melihatnya dalam rupiah.
8. Sebagai homebrewer, saya ingin mencatat event kopi yang saya minati dan diingatkan, dengan jam yang sudah dikonversi ke zona waktu saya.
9. Sebagai homebrewer, saya ingin tahu toko biji atau alat seduh terdekat saat stok menipis.

## 5. Alur Utama Produk

```
Profil Biji ──► Atur Seduh (+ rekomendasi AI) ──► Sesi (timer terpandu)
     ▲                                                  │
     │                                                  ▼
Pengaturan terbaik ◄── Jurnal ◄── Simpan ◄── Hasil (+ diagnosa AI)
```

Alurnya melingkar: tiap seduhan yang disimpan memperbaiki seduhan berikutnya.

## 6. Pembeda dari Tema Lain

Tema teman yang dekat dengan kopi: **Brewmaster** (resep kopi, berbagi resep, pencari kedai), **BeanOrigin** (rantai pasok dan verifikasi ekspor), **Cafflow** (operasional dan penggajian kafe).

| Aspek | Brewmaster | Tetes |
|---|---|---|
| Inti | Katalog resep dan komunitas | Jurnal pribadi dan alat bantu seduh |
| Isi | Resep dari aplikasi dan pengguna lain | Data seduhan milik pengguna sendiri |
| Sosial | Berbagi resep | Tidak ada |
| Kedai kopi | Fitur utama (LBS) | Tidak ada. LBS hanya untuk toko biji dan alat |
| Nilai | "Apa yang harus diseduh" | "Bagaimana seduhan saya, dan apa pengaturan terbaik biji ini" |

**Batas yang tidak boleh dilanggar:**
- Tidak ada katalog resep bawaan.
- Tidak ada fitur berbagi resep atau data seduhan ke pengguna lain.
- Tidak ada pencari kedai kopi.
- Tidak ada pelacakan asal biji, sertifikasi, atau rantai distribusi (wilayah BeanOrigin). Asal biji hanya catatan teks.
- Tidak ada penjualan tiket event (wilayah tema tiket lain).
- Tidak ada fitur payroll atau manajemen operasional (wilayah Cafflow).

## 7. Cakupan Fitur

Prioritas: **M** = wajib, **S** = sebaiknya, **C** = bila sempat. Kode modul (AUTH, BEAN, dan seterusnya) dipakai di FR di `features/*.md`.

### Akun dan keamanan (AUTH)
- **M** Register dan login lokal, password disimpan sebagai hash dengan salt.
- **M** Session disimpan di secure storage, masa berlaku 7 hari.
- **M** Login biometrik sebagai pembuka aplikasi.
- **M** Logout.
- **S** Pembatasan percobaan login.

### Profil biji (BEAN)
- **M** Tambah, lihat, ubah, hapus biji.
- **M** Field wajib: nama dan spesies (arabika, robusta, campuran).
- **M** Field opsional: roastery (atau "roasting sendiri"), tipe (single origin atau blend), persen arabika untuk campuran, asal (teks bebas), proses, tingkat sangrai, tanggal roasting, harga per kg dan mata uang, tasting notes roastery.
- **M** Stok biji (gram), berkurang otomatis tiap seduhan tersimpan.
- **M** Pengaturan terbaik per biji (otomatis dari skor tertinggi, dapat ditimpa).

### Kurs (CUR)
- **M** Harga biji dalam mata uang asing dikonversi ke rupiah (minimal USD, EUR, JPY).
- **M** Kurs saat input disimpan agar nilai biji lama tidak berubah.
- **M** Biaya per seduhan.
- **S** Kalkulator kurs sederhana.

### Seduh (BREW)
- **M** Atur Seduh: pilih biji, dosis, rasio, suhu, grind, jumlah pouring (1-5), durasi tiap tahap.
- **M** Visual plan: timeline dan grafik air kumulatif.
- **M** Sesi seduh dengan timer bertahap, getar dan suara saat ganti tahap.
- **M** Waktu aktual tiap tahap terekam otomatis. Berat air aktual diisi manual.
- **M** Accelerometer: goyang HP untuk memulai atau mereset timer.
- **M** Layar hasil: plan vs realisasi, skor rasa, tag rasa, perbandingan dengan notes roastery, catatan, biaya.

### AI (AI)
- **M** Rekomendasi pengaturan seduh dari profil biji dan riwayatnya.
- **M** Diagnosa seduhan dari hasil dan keluhan rasa, dengan saran perbaikan.
- **M** Validasi keluaran AI di kode, dan aturan cadangan jika AI tidak tersedia.

### Jurnal (JRN) dan integritas (HASH)
- **M** Daftar seduhan, pencarian, filter, urutkan.
- **M** Detail seduhan dan perbandingan dua seduhan.
- **M** Entri tidak dapat diedit atau dihapus, hanya ditandai dibatalkan.
- **M** Hash chain pada tiap entri dan tombol verifikasi integritas.
- **S** Sub-tab biji dengan grafik skor. **C** Perbandingan dua biji.

### Sinkronisasi (SYNC)
- **M** Data disimpan lokal dulu (SQLite), lalu dikirim ke server saat online.
- **M** Server memverifikasi hash chain dan menolak entri yang tidak cocok.
- **M** Tombol sinkronkan manual dan status sinkronisasi.

### Event dan waktu (EVT)
- **M** Agenda event pribadi (pameran, lomba, cupping, workshop).
- **M** Tiap event tampil di WIB, WITA, WIT, dan London.
- **M** Pengingat event.

### Notifikasi (NOTIF)
- **M** Pengingat event, pengingat seduh harian, dan stok menipis.
- **M** Ambang stok menipis default **15 g**, dapat diubah di Profil.

### LBS
- **M** Peta toko biji, toko alat seduh, dan roastery terdekat.
- **M** Urutan berdasarkan jarak dan tombol navigasi.

### Game (GAME)
- **M** "Steady Pour": mini game dengan kontrol gyroscope.
- **M** Skor akurasi, bintang, dan skor tertinggi lokal.
- **S** Level 2 dan 3, kalibrasi dan sensitivitas.

### Profil (PROF) dan navigasi (NAV)
- **M** Bottom navigation: Seduh, Jurnal, Eksplor, Saran & Kesan, Profil, Logout.
- **M** Profil: foto profil, pengaturan, verifikasi integritas, dan sinkronkan sekarang.
- **M** Saran & Kesan menjadi layar tab sendiri untuk mengirim dan melihat riwayat masukan.
- **M** Logout menjadi aksi di bottom navigation yang meminta konfirmasi, bukan layar tersendiri.

## 8. Pemenuhan Requirement Tugas

| Requirement dosen | Dipenuhi oleh |
|---|---|
| Konsep proyek akhir | PRD ini |
| Login terenkripsi + session (tanpa Firebase) | AUTH: hash dengan salt, session lokal |
| Login biometrik | AUTH: biometrik pembuka aplikasi |
| Penyimpanan lokal dan online | SQLite + Supabase Postgres |
| Web service/API | Edge Function sendiri + API kurs |
| LBS terkait tema | LBS: toko biji dan alat seduh |
| Bottom navigation: profil (ada gambar), saran dan kesan, logout | NAV: enam item; Profil dan Saran & Kesan berupa layar, Logout berupa aksi konfirmasi |
| Konversi mata uang (min. 3) | CUR: harga biji impor |
| Konversi waktu (WIB, WIT, WITA, London) | EVT: agenda event |
| Min. 2 sensor | Accelerometer (goyang timer) dan gyroscope (game) |
| AI/LLM | AI: rekomendasi dan diagnosa |
| Mini game | GAME: Steady Pour |
| Pencarian dan pemilihan | JRN: pencarian, filter, pilih untuk dibandingkan |
| Notifikasi | NOTIF |
| Blockchain sederhana | HASH: hash chain pada jurnal |
| Laporan | Bagian 13 |

## 9. Keputusan Teknis (ringkas)

Detail ada di `ARCHITECTURE.md`.

- **Aplikasi:** Flutter. **Lokal:** SQLite.
- **Login:** lokal di Flutter (hash + salt, session di secure storage). Tanpa Firebase dan tanpa Supabase Auth.
- **Online:** Supabase Postgres dengan RLS aktif tanpa policy, diakses hanya lewat Edge Function.
- **Edge Function:** `sync-register`, `sync-push`, `ai`.
- **LLM:** dipanggil hanya dari Edge Function. API key disimpan sebagai secret, tidak ada di kode Flutter.
- **Kurs:** API kurs publik tanpa key (kandidat: Frankfurter), dipanggil dari Flutter. Kurs terakhir disimpan untuk mode offline.
- **Peta:** OpenStreetMap. Data toko diisi manual 10-15 titik.
- **ID:** semua ID berupa UUID yang dibuat di Flutter.

**Keterbatasan yang jujur (untuk laporan):** autentikasi bersifat lokal di perangkat, akun tidak berpindah antar HP, dan keamanannya tidak setara autentikasi server. Hash chain bersifat tamper-evident (perubahan terdeteksi), bukan tamper-proof, dan bukan blockchain terdistribusi.

## 10. Kriteria Keberhasilan

Aplikasi dianggap berhasil jika:
1. Seluruh item bertanda **M** berjalan di HP asli tanpa error pada jalur utama.
2. Alur demo 3 menit dapat dijalankan dari awal sampai akhir:
   login biometrik → pilih biji → atur seduh (rekomendasi AI) → sesi timer → hasil dan diagnosa → simpan → jurnal (cari, filter, bandingkan) → verifikasi integritas → agenda event → peta toko → game → logout.
3. Mengubah satu data langsung di database membuat verifikasi integritas melaporkan rantai putus.
4. Aplikasi tetap dapat dipakai untuk seduh dan jurnal saat offline.
5. Tidak ada rahasia (API key, service key) di kode Flutter atau di repositori.
6. Laporan lengkap dan dicetak dengan halaman pengesahan sebelum UAS.

## 11. Di Luar Cakupan

- Resep bawaan, berbagi resep, komunitas, papan peringkat.
- Pencari kedai kopi.
- Pelacakan asal biji, sertifikasi, rantai pasok.
- Penjualan tiket atau pembayaran.
- Integrasi scale Bluetooth atau IoT lain (bonus jika waktu sisa, tidak direncanakan).
- Skor stabilitas tuangan dari sensor pada seduhan nyata (sensor hanya dipakai untuk timer dan game).
- Sinkronisasi dua arah dengan penggabungan data, akun lintas perangkat, mode gelap.
- Dukungan metode seduh selain V60.

## 12. Asumsi, Risiko, dan Pertanyaan Terbuka

**Asumsi**
- Pengguna menyeduh V60 dengan ketel dan, idealnya, scale terpisah. Berat air aktual diisi manual.
- Pengguna bersedia mengisi skor dan tag rasa setelah seduh.

**Risiko**
| Risiko | Mitigasi |
|---|---|
| Dosen menilai tema terlalu mirip Brewmaster | Konfirmasi di awal. Jaga batas di bagian 6. Tabel pembeda masuk laporan |
| Dosen tidak menerima login lokal atau Supabase | Konfirmasi di awal. Cadangan: backend sendiri (Express) |
| Rasa kontrol gyroscope tidak enak | Prototipe kasar dulu, uji di HP asli. Cadangan: accelerometer untuk game |
| Hash tidak cocok antara aplikasi dan server | Satu fungsi format, satu data contoh uji untuk dua sisi |
| Notifikasi dan biometrik berbeda antar HP | Uji di HP demo sejak awal |
| Batas gratis layanan (Supabase, LLM, API kurs) berubah | Cek sebelum Sprint 5, jalankan semuanya sehari sebelum demo |
| Waktu 8 hari terlalu singkat | Urutan pemotongan di bagian 14 |

**Pertanyaan ke dosen (kirim sekaligus)**
1. Apakah aplikasi pelatih dan jurnal seduh V60, tanpa katalog resep, berbagi resep, dan pencari kedai, dianggap berbeda dari tema resep dan pencari kedai kopi?
2. Apakah login boleh sepenuhnya lokal (hash + salt, session)?
3. Apakah boleh memakai Supabase (database dan Edge Function) untuk bagian online?
4. **Sudah diputuskan mengikuti bunyi slide:** Saran & Kesan menjadi tab sendiri dan Logout menjadi aksi di bottom navigation; Profil tetap menjadi tab dengan foto pengguna. Keputusan ini tetap boleh dikonfirmasi kepada dosen untuk memastikan interpretasinya tepat.

**Keputusan yang masih menunggu**
- Nama dan tagline: **Tetes**, "Jurnal seduh V60" (belum dicek kemiripannya di toko aplikasi).
- Package ID: `com.raismukhtar.tetes` (ditetapkan oleh Rais Mukhtar Hakim; jangan diubah setelah Sprint 1 dimulai).
- Gaya UI: menunggu referensi dan style guide (`UI_SPEC.md`).

## 13. Laporan

Struktur sesuai slide: cover, halaman pengesahan, daftar isi, landasan teori dan tema (termasuk tabel pembeda di bagian 6), perancangan (RPL/RBPL), implementasi dan penjelasan source code dengan screenshot, lembar evaluasi pengujian, penutup. Laporan diunggah dan dicetak dengan halaman pengesahan sebelum UAS.

## 14. Rencana dan Prioritas

Pengerjaan 8 hari, satu sprint per hari:

| Sprint | Fokus |
|---|---|
| 1 | Fondasi, tema UI, login lokal, biometrik, bottom navigation |
| 2 | Profil biji, kurs, Atur Seduh |
| 3 | Sesi timer, hasil, hash chain |
| 4 | Jurnal |
| 5 | Sinkronisasi online dan AI |
| 6 | Event, notifikasi, LBS |
| 7 | Game, profil, perapian |
| 8 | Pengujian, laporan, presentasi |

**Jika waktu mepet, potong urut ini:** perbandingan dua biji dan grafik skor, level 2 dan 3 game, kalkulator kurs terpisah, filter lanjutan jurnal, pembatasan percobaan login.

**Jangan dipotong:** semua yang diminta slide (login, biometrik, SQLite dan online, LBS, kurs, waktu, dua sensor, AI, mini game, pencarian, notifikasi, blockchain, bottom navigation).

## 15. Glosarium

- **Bloom:** tahap awal V60, sedikit air untuk melepas gas dari bubuk kopi.
- **Pouring/pulse:** satu tahap penuangan air.
- **Drawdown:** waktu sampai semua air habis turun melewati bubuk kopi.
- **Rasio:** perbandingan kopi dan air (misalnya 1:16).
- **Grind:** tingkat kehalusan gilingan.
- **Pengaturan terbaik:** seduhan dengan skor rasa tertinggi untuk satu biji.
- **Hash chain:** rangkaian entri yang tiap entrinya menyimpan hash entri sebelumnya, sehingga perubahan terdeteksi.
