# Fitur 02: Profil biji dan kurs

**Sprint:** 2
**Tujuan:** pengguna dapat mengelola koleksi biji beserta stok, tasting notes roastery, dan harga yang dikonversi ke rupiah.
**FR terkait:** FR-BEAN-01 sampai 05, FR-CUR-01 sampai 05
**Dokumen wajib dibaca:** DATA_MODEL.md (beans, aturan turunan, validasi), ARCHITECTURE.md (bagian 5.4)

## Layar
**Daftar biji** (di Jurnal sub-tab Biji, sementara boleh ditaruh di tab Seduh): kartu biji dengan nama, roastery, spesies, tingkat sangrai, stok tersisa (g), hari sejak roasting, ringkasan pengaturan terbaik bila ada, tanda stok menipis. Tombol tambah.
**Form biji:** urutan field:
1. Nama biji (wajib)
2. Asal dengan label "Asal (negara atau daerah)"
3. Roastery dengan toggle "Roasting sendiri" (toggle aktif mengisi roastery otomatis dan menonaktifkan kolomnya)
4. Spesies (wajib): arabika, robusta, campuran
5. Tipe: single origin atau blend
6. Persen arabika bila spesies campuran
7. Proses: washed, natural, honey, atau Lainnya. Lainnya membuka teks bebas maksimal 40 karakter
8. Tingkat sangrai
9. Tanggal roasting
10. Ukuran kemasan: chip 100, 150, 200, 250, 500, 1000 g, atau Lainnya
11. Harga satu kemasan dan mata uang, lalu tampilan hasil rupiah per kg otomatis
12. Stok awal (g)
13. Tasting notes roastery: pilihan tag bawaan, tag buatan sendiri, dan teks bebas
Tombol Simpan dan Batal.
**Detail biji:** semua profil, proses termasuk teks proses khusus, ukuran kemasan, harga satu kemasan, kurs saat input, harga rupiah per kg, stok tersisa, pengaturan terbaik dan tombol "Seduh dengan ini" (aktif setelah Fitur 03 ada), tombol ubah dan arsipkan. Biji lama tanpa `pack_size_g` menampilkan "Ukuran kemasan belum diisi".

## Data
- Tabel `beans`. Validasi dan enum sesuai DATA_MODEL.md.
- `price_original` menyimpan harga satu kemasan. Harga rupiah per kg dihitung dengan `price_original * fx_rate / pack_size_g * 1000`.
- Ukuran kemasan disimpan di `pack_size_g`. Memilih ukuran otomatis mengisi stok awal selama stok belum pernah diubah manual; pada form edit stok dianggap sudah diubah agar data lama tidak tertimpa.
- Proses khusus disimpan dengan `process = 'lainnya'` dan teks di `process_custom`. Mengganti proses mengosongkan `process_custom`.
- Tag bawaan dan tag sendiri disimpan bersama di `roastery_notes_tags`, huruf kecil, unik, urut abjad, dipisah koma, dan maksimal 10 tag total.
- Stok tersisa dihitung, tidak disimpan (query di DATA_MODEL.md bagian 7).
- Kurs: pilih mata uang minimal IDR, USD, EUR, JPY. Panggil API kurs, hitung `price_idr_per_kg`, simpan `fx_rate` dan `fx_date`. Simpan juga cache kurs terakhir di `settings.fx_cache`.
- Biji yang sudah punya seduhan tidak boleh dihapus, hanya diarsipkan (`archived = 1`).

## API kurs (hasil uji manual 2026-10-19)
Alamat dasar (satu konstanta di lib/core/config/app_config.dart):
https://api.frankfurter.dev/v1

Permintaan: GET /latest?base=USD&symbols=IDR,EUR,JPY
Parameter memakai `base` dan `symbols` (bukan from dan to).

Contoh respons asli:

```json
{"amount":1.0,"base":"USD","date":"2026-10-16","rates":{"EUR":0.88865,"IDR":18031,"JPY":158.02}}
```

Catatan:
- `rates["IDR"]` berarti 1 unit mata uang `base` = nilai itu rupiah. Untuk base selain USD, ganti `base` (contoh base=EUR&symbols=IDR). Jika mata uang asal sudah IDR, tidak perlu memanggil API.
- Kurs referensi harian hari kerja (tanggal bisa hari Jumat saat akhir pekan), bukan kurs jual-beli.
- Parser harus tahan banting: jika `rates` tidak memuat mata uang yang diminta, atau respons rusak atau bukan JSON, tampilkan galat jelas, bukan crash.
- Jangan menebak alamat atau bentuk respons dari ingatan. Gunakan contoh di atas.
- Simpan contoh ini sebagai data uji (fixture) untuk tes parser.

## Alur
Tambah biji, isi form dan ukuran kemasan, pilih mata uang asing, aplikasi mengambil kurs dan menampilkan hasil rupiah per kg, simpan. Ubah biji tidak mengubah `fx_rate` lama kecuali pengguna mengubah harga, ukuran kemasan, atau mata uang.

## Keadaan layar dan kasus pinggir
- Daftar kosong: ajakan menambah biji pertama.
- Offline saat input harga asing: pakai kurs cache dengan penanda tanggal. Bila cache kosong, tampilkan pesan dan izinkan simpan tanpa rupiah (kolom hasil kosong).
- API kurs galat atau mata uang tidak didukung: pesan jelas.
- Persen arabika hanya muncul bila spesies campuran. Mengganti spesies menghapus nilainya.
- Harga, stok, dan ukuran kemasan yang diisi harus lebih dari nol. Harga memerlukan mata uang dan ukuran kemasan.
- Memilih ukuran kemasan mengisi stok awal dengan nilai yang sama sampai pengguna mengubah stok secara manual.
- Memilih proses Lainnya mewajibkan teks proses maksimal 40 karakter; pindah proses menghapus teks itu.
- Tag sendiri di-trim dan dijadikan huruf kecil, tidak boleh mengandung koma, maksimal 30 karakter, tidak boleh kembar, dan ikut dihitung dalam batas 10 tag bersama tag bawaan. Tombol tambah nonaktif saat batas tercapai.
- Biji lama dengan harga tetapi tanpa ukuran kemasan tetap dapat dibuka; ukuran kemasan wajib dilengkapi bila form disimpan selama harga masih terisi.

## JANGAN
- Tidak ada fitur pelacakan asal, sertifikasi, lahan, atau rantai pasok. Asal hanya teks.
- Tidak ada fitur berbagi biji atau profil.
- Tidak menyimpan stok tersisa sebagai kolom.
- Tidak menghapus biji yang memiliki seduhan.

## Boleh menyentuh
`lib/features/beans/`, `lib/data/repositories/bean_repo.dart`, `lib/data/remote/fx_client.dart`, `lib/core/utils/` (format uang), komponen bersama yang dibutuhkan (tambah, jangan ubah yang ada tanpa izin).

## Acceptance criteria
- [ ] Tambah biji dengan semua field opsional dan hanya field wajib, keduanya berhasil
- [ ] Harga kemasan 10 USD dengan ukuran kemasan menghasilkan harga rupiah per kg sesuai kurs yang tersimpan, dan nilainya tidak berubah saat kurs berganti kemudian
- [ ] Mode pesawat: input harga asing memakai kurs cache dengan tanggalnya
- [ ] Toggle "Roasting sendiri" mengisi roastery otomatis
- [ ] Slider persen hanya muncul untuk spesies campuran
- [ ] Ukuran kemasan mengisi stok awal otomatis sampai stok diubah manual
- [ ] Proses dan tag buatan sendiri tersimpan dan dapat diubah tanpa kehilangan nilai
- [ ] Biji lama tanpa ukuran kemasan tetap dapat dibuka tanpa crash
- [ ] Biji tidak punya tombol hapus bila sudah ada seduhan, hanya arsipkan
- [ ] Data bertahan setelah aplikasi ditutup

## Cara uji
Tambah tiga biji (arabika single origin, campuran 70/30, roasting sendiri), ubah satu, coba mata uang USD, EUR, JPY, uji offline.

## Langkah pengerjaan yang disarankan
1. Repository dan form biji tanpa kurs. Berhenti.
2. Daftar dan detail biji. Berhenti.
3. Klien kurs dan cache. Berhenti.
4. Integrasi kurs ke form, arsip, dan tampilan stok. Berhenti.
