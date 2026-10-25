# Fitur 04: Jurnal

**Sprint:** 4
**Tujuan:** pengguna melihat, mencari, memfilter, dan membandingkan seduhan serta mengelola status entri.
**FR terkait:** FR-JRN-01 sampai 08, FR-BEAN-04, FR-HASH-03 (tombol verifikasi)
**Dokumen wajib dibaca:** DATA_MODEL.md (brews, query contoh), ARCHITECTURE.md (bagian 5.2)

## Layar
Tab Jurnal berupa satu daftar seduhan (sub-tab Biji dihapus, daftar biji tetap di tab Seduh).

### Sub-tab Seduhan
- **Daftar:** kartu per seduhan: tanggal dan jam, nama biji, rasio dan suhu, skor rasa, tag, status sinkronisasi (tersinkron, menunggu, galat), penanda pengaturan terbaik, tampilan pudar bila dibatalkan. Terbaru di atas.
- **Pencarian:** satu kolom, mencari di nama biji, roastery, tag bawaan dan buatan sendiri, serta catatan.
- **Filter:** biji (satu atau banyak), skor minimal, tag rasa, rentang tanggal (7 hari, 30 hari, pilih sendiri). Tombol reset dan jumlah hasil. Urutkan: terbaru, skor tertinggi, biaya.
- **Detail seduhan:** ringkasan, tabel plan vs realisasi, rasa bawaan dan rasa buatan sendiri (chip kuning) vs notes roastery, catatan, saran AI bila ada, biaya, status integritas (hash dan penanda), aksi: "Seduh lagi dengan pengaturan ini", "Jadikan pengaturan terbaik", "Pilih untuk dibandingkan", "Tandai dibatalkan".
- **Bandingkan:** pilih tepat dua entri lewat kotak centang lalu "Bandingkan". Dua kolom berdampingan (biji, rasio, suhu, grind, waktu total, skor, tag, biaya). Baris yang berbeda disorot. Satu kalimat ringkasan dibuat dengan aturan sederhana, bukan AI (contoh: "Skor naik 1 setelah suhu turun 2°C dan rasio diperkecil"). Bila bijinya berbeda, beri catatan "biji berbeda".

### Sub-tab Biji
- Daftar biji (dari Fitur 02), dengan pengaturan terbaik, stok, dan tanda menipis.
- Detail biji ditambah grafik skor dari seduhan ke seduhan dan daftar seduhan biji itu. (Prioritas S.)
- Bandingkan dua biji. (Prioritas C, dikerjakan bila sempat.)

## Data
- Semua dari SQLite lewat query. Tanpa internet.
- Entri dibatalkan: `status = dibatalkan`. Tidak masuk statistik, stok, pengaturan terbaik, dan data AI. Tetap tampil di daftar dengan tampilan pudar dan tetap menjadi bagian rantai hash.
- Menandai dibatalkan mengubah `status` dan `sync_status = pending`, tanpa mengubah `hash`.
- Jika seduhan yang dibatalkan adalah pengaturan terbaik biji, hitung ulang pengaturan terbaik.

## Alur
Buka Jurnal, cari dan filter, buka detail, pilih dua entri, bandingkan. Dari detail, ketuk "Seduh lagi" untuk mengisi Atur Seduh dari entri itu.

## Keadaan layar dan kasus pinggir
- Jurnal kosong: ajakan menyeduh.
- Hasil filter kosong: pesan khusus dan tombol reset.
- Memilih lebih dari dua entri untuk dibandingkan: tolak dengan pesan.
- Entri dengan hash bermasalah: tampilkan penanda peringatan, jangan sembunyikan.

## JANGAN
- Tidak ada tombol edit atau hapus entri. Hanya "tandai dibatalkan".
- Tidak mengubah field yang di-hash dari layar mana pun.
- Tidak memakai AI untuk ringkasan perbandingan.
- Tidak menambah fitur berbagi atau ekspor ke pengguna lain.

## Boleh menyentuh
`lib/features/journal/`, `lib/data/repositories/brew_repo.dart` dan `bean_repo.dart` (tambah query), komponen bersama baru yang dibutuhkan.

## Acceptance criteria
- [ ] Pencarian menemukan entri berdasarkan nama biji, tag, atau catatan
- [ ] Filter dapat digabung dan tombol reset mengembalikan semuanya
- [ ] Bandingkan dua entri menyorot baris yang berbeda
- [ ] Menandai dibatalkan membuat entri pudar, stok bertambah kembali, dan pengaturan terbaik dihitung ulang
- [ ] Rantai hash tetap utuh setelah ada entri dibatalkan (verifikasi lulus)
- [ ] "Seduh lagi" mengisi Atur Seduh dengan nilai entri tersebut
- [ ] Jurnal dapat dibuka dan dicari saat mode pesawat

## Cara uji
Isi minimal 8 entri dengan variasi biji, skor, dan tanggal. Uji semua filter, satu perbandingan, satu pembatalan (cek stok dan pengaturan terbaik), lalu jalankan verifikasi.

## Langkah pengerjaan yang disarankan
1. Query daftar dan kartu. Berhenti.
2. Pencarian dan filter. Berhenti.
3. Detail seduhan dan aksi. Berhenti.
4. Bandingkan dua seduhan. Berhenti.
5. Pembatalan dan perhitungan ulang. Berhenti.
6. Sub-tab Biji (grafik skor bila sempat). Berhenti.
