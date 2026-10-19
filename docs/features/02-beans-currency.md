# Fitur 02: Profil biji dan kurs

**Sprint:** 2
**Tujuan:** pengguna dapat mengelola koleksi biji beserta stok, tasting notes roastery, dan harga yang dikonversi ke rupiah.
**FR terkait:** FR-BEAN-01 sampai 05, FR-CUR-01 sampai 05
**Dokumen wajib dibaca:** DATA_MODEL.md (beans, aturan turunan, validasi), ARCHITECTURE.md (bagian 5.4)

## Layar
**Daftar biji** (di Jurnal sub-tab Biji, sementara boleh ditaruh di tab Seduh): kartu biji dengan nama, roastery, spesies, tingkat sangrai, stok tersisa (g), hari sejak roasting, ringkasan pengaturan terbaik bila ada, tanda stok menipis. Tombol tambah.
**Form biji:** urutan field:
1. Nama (wajib)
2. Spesies (wajib): arabika, robusta, campuran. Bila campuran: slider persen arabika
3. Tipe: single origin atau blend
4. Roastery (teks) dengan toggle "Roasting sendiri" (toggle aktif mengisi roastery otomatis dan menonaktifkan kolomnya)
5. Asal (teks bebas), proses, tingkat sangrai, tanggal roasting
6. Harga per kg, mata uang, tampilan hasil rupiah otomatis
7. Stok awal (g)
8. Tasting notes roastery: pilihan tag + teks bebas
Tombol Simpan dan Batal.
**Detail biji:** semua profil, harga asli, kurs saat input, harga rupiah, stok tersisa, pengaturan terbaik dan tombol "Seduh dengan ini" (aktif setelah Fitur 03 ada), tombol ubah dan arsipkan.

## Data
- Tabel `beans`. Validasi dan enum sesuai DATA_MODEL.md.
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
Tambah biji, isi form, pilih mata uang asing, aplikasi mengambil kurs dan menampilkan hasil rupiah, simpan. Ubah biji tidak mengubah `fx_rate` lama kecuali pengguna mengubah harga atau mata uang.

## Keadaan layar dan kasus pinggir
- Daftar kosong: ajakan menambah biji pertama.
- Offline saat input harga asing: pakai kurs cache dengan penanda tanggal. Bila cache kosong, tampilkan pesan dan izinkan simpan tanpa rupiah (kolom hasil kosong).
- API kurs galat atau mata uang tidak didukung: pesan jelas.
- Persen arabika hanya muncul bila spesies campuran. Mengganti spesies menghapus nilainya.
- Harga dan stok tidak boleh negatif.

## JANGAN
- Tidak ada fitur pelacakan asal, sertifikasi, lahan, atau rantai pasok. Asal hanya teks.
- Tidak ada fitur berbagi biji atau profil.
- Tidak menyimpan stok tersisa sebagai kolom.
- Tidak menghapus biji yang memiliki seduhan.

## Boleh menyentuh
`lib/features/beans/`, `lib/data/repositories/bean_repo.dart`, `lib/data/remote/fx_client.dart`, `lib/core/utils/` (format uang), komponen bersama yang dibutuhkan (tambah, jangan ubah yang ada tanpa izin).

## Acceptance criteria
- [ ] Tambah biji dengan semua field opsional dan hanya field wajib, keduanya berhasil
- [ ] Harga 10 USD per kg menghasilkan rupiah sesuai kurs yang tersimpan, dan nilainya tidak berubah saat kurs berganti kemudian
- [ ] Mode pesawat: input harga asing memakai kurs cache dengan tanggalnya
- [ ] Toggle "Roasting sendiri" mengisi roastery otomatis
- [ ] Slider persen hanya muncul untuk spesies campuran
- [ ] Biji tidak punya tombol hapus bila sudah ada seduhan, hanya arsipkan
- [ ] Data bertahan setelah aplikasi ditutup

## Cara uji
Tambah tiga biji (arabika single origin, campuran 70/30, roasting sendiri), ubah satu, coba mata uang USD, EUR, JPY, uji offline.

## Langkah pengerjaan yang disarankan
1. Repository dan form biji tanpa kurs. Berhenti.
2. Daftar dan detail biji. Berhenti.
3. Klien kurs dan cache. Berhenti.
4. Integrasi kurs ke form, arsip, dan tampilan stok. Berhenti.
