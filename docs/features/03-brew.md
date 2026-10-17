# Fitur 03: Seduh (Atur Seduh, sesi, hasil)

**Sprint:** 2 (bagian A), 3 (bagian B dan C)
**Tujuan:** pengguna merencanakan seduhan, menjalankannya dengan timer terpandu, mencatat hasil, dan menyimpannya sebagai entri jurnal dengan hash chain.
**FR terkait:** FR-BREW-01 sampai 09, FR-HASH-01 sampai 03, FR-NOTIF-03 (pemicu stok menipis)
**Dokumen wajib dibaca:** DATA_MODEL.md (brews, brew_stages, bagian 4 dan 5), ARCHITECTURE.md (bagian 5.1)

## Bagian A (Sprint 2): Atur Seduh

### Layar Atur Seduh
1. Pilih biji (daftar biji aktif). Bila biji punya pengaturan terbaik, form terisi otomatis dari seduhan itu dan ada label "dari pengaturan terbaik".
2. Dosis (g), rasio (1:x), suhu air (°C), grind (pilihan enum). Total air terhitung otomatis dan tampil.
3. Jumlah pouring (1-5, bloom dihitung pouring pertama).
4. Daftar tahap: tiap tahap menampilkan nama, waktu mulai, durasi, dan target air (kumulatif dan per tuang). Semua dapat diubah manual. Nilai awal dihitung otomatis dari dosis, rasio, dan jumlah pouring (bloom sekitar 2-3 kali berat kopi, sisa air dibagi rata).
5. Visual plan: timeline horizontal (bar per tahap sesuai durasi dan jeda) dan grafik garis air kumulatif terhadap waktu. Keduanya berubah langsung saat tahap diedit.
6. Tombol "Mulai Sesi". (Tombol "Rekomendasikan dengan AI" ditambahkan di Sprint 5. Sediakan tempatnya, nonaktif.)

Validasi: dosis, rasio, suhu sesuai DATA_MODEL.md bagian 4. Total target air tahap terakhir harus sama dengan total air. Waktu mulai tahap tidak tumpang tindih.

## Bagian B (Sprint 3): Sesi seduh

### Layar Sesi
- Menampilkan tahap aktif (nama, target air, hitung mundur durasi target) dan timer total. Tahap lain terlihat sebagai daftar kecil.
- Tombol besar "Tahap berikutnya". Tiap ketukan mencatat `actual_start_s` tahap berikutnya dan menutup `actual_duration_s` tahap sebelumnya.
- Di tahap terakhir, tombol berubah menjadi "Air habis" untuk mencatat `drawdown_s` dan mengakhiri sesi.
- Getar dan suara pendek saat pergantian tahap atau saat target waktu tahap tercapai.
- Accelerometer: goyang melebihi ambang memulai timer di awal. Di sesi, goyang tidak boleh memicu "tahap berikutnya" tanpa sengaja (hanya mulai dan reset). Beri jeda agar tidak terpicu berulang.
- Tombol batal (dengan konfirmasi). Layar tetap menyala selama sesi.

## Bagian C (Sprint 3): Hasil

### Layar Hasil (urutan dari atas)
1. Ringkasan: biji, dosis, rasio, suhu, grind, total waktu.
2. Tabel plan vs realisasi per tahap: target dan aktual untuk air dan waktu. Kolom **air aktual** diisi manual. Waktu aktual dapat dikoreksi sebelum simpan.
3. Skor rasa (bintang 1-5) dan tag rasa (pilih dari enum, minimal satu).
4. Perbandingan: notes roastery (dari profil biji) berdampingan dengan tag rasa pengguna.
5. Catatan bebas.
6. Biaya seduhan (dosis dikali harga per gram, dalam rupiah). Kosong bila harga tidak ada.
7. Tombol: Simpan. (Tombol "Minta Diagnosa AI" ditambahkan di Sprint 5. Sediakan tempatnya, nonaktif.)

Dialog konfirmasi sebelum simpan: "Data seduhan tidak dapat diubah setelah disimpan."

## Data dan hash chain
- Simpan dalam **satu transaksi SQLite**: hitung `seq` (seq terakhir pengguna + 1), ambil `prev_hash` (hash entri terakhir, atau `0`), hitung `hash` dengan `buildHashInput()`, tulis `brews` dan semua `brew_stages`.
- Format hash persis sesuai DATA_MODEL.md bagian 5. Satu fungsi `buildHashInput()` di `lib/core/utils/`.
- Tes unit wajib memakai dua vektor uji di DATA_MODEL.md bagian 5.7.
- Setelah simpan: `sync_status = pending`, perbarui pengaturan terbaik biji (otomatis dari skor tertinggi), cek stok menipis (bandingkan stok tersisa dengan `low_stock_threshold_g`, default 15 g). Pemicu notifikasi stok dikerjakan di Fitur 06, di sini cukup menyediakan fungsi cek dan memanggil penjadwal jika sudah ada.
- Verifikasi integritas (tombol di Profil, boleh disediakan fungsinya dulu): aturan di DATA_MODEL.md bagian 5.8.

## Keadaan layar dan kasus pinggir
- Tidak ada biji: arahkan ke tambah biji.
- Aplikasi ditutup di tengah sesi: sesi yang belum disimpan boleh hilang. Tidak boleh ada entri setengah jadi.
- Tahap terlewat atau lupa menekan tombol: pengguna dapat memperbaiki waktu di layar hasil.
- Air aktual kosong: boleh disimpan, tampilkan sebagai "tidak diisi" dan jangan dihitung selisih.
- Skor atau tag belum diisi: tombol Simpan nonaktif dengan penjelasan.

## JANGAN
- Tidak ada edit atau hapus entri setelah simpan.
- Tidak ada skor stabilitas dari sensor.
- Tidak ada integrasi scale Bluetooth.
- Tidak mengubah format hash atau urutan field.
- Tidak menambah metode seduh selain V60.

## Boleh menyentuh
`lib/features/brew/`, `lib/data/repositories/brew_repo.dart`, `lib/core/utils/hash.dart` (dan tesnya), `lib/core/utils/` (waktu, format), komponen bersama baru yang dibutuhkan.

## Acceptance criteria
**Sprint 2**
- [ ] Mengubah dosis atau rasio memperbarui total air dan target tahap
- [ ] Mengubah jumlah pouring membuat ulang tahap, dan timeline serta grafik ikut berubah
- [ ] Biji dengan pengaturan terbaik mengisi form otomatis
- [ ] Validasi menolak suhu atau rasio di luar batas

**Sprint 3**
- [ ] Sesi berjalan dengan timer tiap tahap, getar dan suara saat ganti tahap
- [ ] Goyang HP memulai timer
- [ ] Waktu aktual tiap tahap tercatat dan tampil di hasil
- [ ] Simpan membuat entri dengan `seq`, `prev_hash`, dan `hash` yang benar
- [ ] Dua entri berturut-turut: `prev_hash` entri kedua sama dengan `hash` entri pertama
- [ ] Tes unit hash memakai kedua vektor uji dan lolos
- [ ] Stok biji berkurang sesuai dosis
- [ ] Mengubah satu nilai langsung di database lalu menjalankan verifikasi menghasilkan "rantai putus"

## Cara uji
Buat tiga seduhan dengan biji berbeda, termasuk satu dengan waktu yang dikoreksi. Periksa tabel `brews` dan `brew_stages`. Uji tamper dengan mengubah `taste_score` lewat alat inspeksi database.

## Langkah pengerjaan yang disarankan
1. Kalkulator dan pembentuk tahap (logika murni, dengan tes unit). Berhenti.
2. Layar Atur Seduh dengan visual. Berhenti.
3. Fungsi hash dengan tes vektor uji. Berhenti.
4. Layar Sesi dengan timer dan tombol. Berhenti.
5. Accelerometer. Berhenti.
6. Layar Hasil dan penyimpanan transaksi. Berhenti.
7. Pembaruan pengaturan terbaik dan stok. Berhenti.
