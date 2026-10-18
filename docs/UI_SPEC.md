# UI_SPEC: Tetes

Aturan tampilan yang berlaku untuk semua layar. **Tema dan komponen dibuat sekali di Sprint 1 (`00-foundation.md`), lalu dipakai ulang.** Layar tidak boleh menulis warna, ukuran, atau gaya teks sendiri.

Terkait: `ARCHITECTURE.md` (struktur `lib/app/` dan `lib/core/ui/`), spec fitur di `features/`.

## 1. Arah Desain

**Suasana:** bersih, lapang, sejuk, ramah. Kartu besar bersudut sangat membulat, chip berbentuk pil, bayangan halus, aksen cyan dan mint, dengan kontras hitam di titik penting.

**Referensi:** satu set tampilan aplikasi kesehatan mental (layar mood gelap, beranda dengan kartu, profil dengan grafik). Dipakai sebagai **acuan gaya, bukan untuk disalin**: jangan memakai ilustrasi, ikon khusus, atau nama dari referensi itu. Semua aset buatan sendiri atau dari sumber berlisensi bebas.

**Prinsip:**
1. Satu aksi utama per layar.
2. Banyak ruang kosong. Tidak ada layar yang padat.
3. Layar fokus (Sesi, Game) berlatar gelap supaya angka besar mudah dibaca saat menuang.
4. Konsisten lebih penting daripada cantik. Jika ragu, pakai komponen yang sudah ada.

## 2. Token Warna

Nilai di bawah adalah **titik awal**. Hex cyan, abu, putih, dan hitam dibaca dari referensi. Mint dan warna turunan adalah perkiraan, cocokkan dengan eyedropper bila ingin persis.

| Token | Nilai | Pemakaian |
|---|---|---|
| `primary` | `#49CBEB` | Aksen utama: tombol aksi bulat, chip terpilih, garis grafik |
| `primaryContainer` | `#9EE3F6` | Latar kartu berwarna, latar tab aktif di bottom nav |
| `accent` | `#7FF0CB` | Aksen kedua: hasil positif, skor tinggi, level selesai |
| `ink` | `#000000` | Teks utama, kartu hitam, tombol utama di layar terang |
| `inkSoft` | `#5B6168` | Teks sekunder, ikon tidak aktif |
| `background` | `#F4F5F6` | Latar layar |
| `surface` | `#FFFFFF` | Kartu, input, bottom nav |
| `surfaceDark` | `#1E1E1E` | Latar layar fokus |
| `chipDark` | `#2E2E2E` | Chip tidak terpilih di layar gelap |
| `onDark` | `#FFFFFF` | Teks di layar gelap |
| `warning` | `#F5A524` | Stok menipis (tambahan, tidak ada di referensi) |
| `error` | `#E5484D` | Galat dan peringatan integritas (tambahan) |
| `divider` | `#E6E8EA` | Garis pemisah dan batas halus |

**Aturan kontras:** teks di atas `primary`, `primaryContainer`, dan `accent` **selalu hitam** (`ink`), bukan putih. Cyan terlalu terang untuk teks putih. Teks sekunder tidak boleh lebih terang dari `inkSoft` di latar putih.

## 3. Tipografi

- **Font:** satu keluarga saja. Default: **Plus Jakarta Sans** (alternatif: Outfit). Keduanya sans geometris gratis yang suasananya dekat dengan font referensi. Cek lisensi sebelum memakai font lain.
- **Dikemas di aset** (`assets/fonts/`), bukan diunduh saat berjalan, karena aplikasi ini offline-first. Jangan menambah paket baru hanya untuk font tanpa bertanya.

| Gaya | Ukuran / bobot | Pemakaian |
|---|---|---|
| `display` | 40 / Bold | Timer besar di Sesi |
| `headline` | 28 / Bold | Judul layar ("Halo, Rais") |
| `title` | 20 / SemiBold | Judul bagian, judul kartu |
| `body` | 16 / Regular | Isi, kolom isian |
| `label` | 14 / Medium | Chip, tombol, label |
| `caption` | 12 / Regular | Keterangan, tanggal, status |

Angka timer dan target air memakai angka dengan lebar tetap (tabular figures) bila tersedia, supaya tidak bergoyang saat berubah.

## 4. Bentuk, Jarak, Bayangan

| Token | Nilai |
|---|---|
| Grid jarak | 4 pt. Skala: 4, 8, 12, 16, 20, 24, 32, 48 |
| Padding layar | 20 horizontal |
| Radius kartu | 24 (kartu dalam: 20) |
| Radius kecil | 12 (kolom isian bertumpuk, gambar kecil) |
| Radius pil | 999 (tombol, chip, search, tombol bulat) |
| Bayangan kartu | blur 24, offset y 8, hitam 6% |
| Area sentuh minimum | 48 × 48 |

## 5. Mode Tampilan

- **Dasar: terang.** Tidak ada pengaturan mode gelap sistem (di luar cakupan).
- **Layar fokus gelap:** Sesi seduh, Game, dan bottom sheet pemilih tag rasa memakai tema gelap lewat override tema lokal (`surfaceDark`, `onDark`, `chipDark`). Pembungkusnya satu widget (`FocusDarkTheme`) yang dipakai ulang, bukan tema baru tiap layar.

## 6. Komponen Bersama (`lib/core/ui/`)

Semua layar wajib memakai komponen ini. Tambah komponen baru di sini, jangan membuat varian lokal.

| Komponen | Aturan |
|---|---|
| `AppButton` | Pil. **Primary (layar terang):** isi hitam, teks putih. **Primary (layar gelap):** isi putih, teks hitam. **Secondary:** putih dengan garis tipis. **Text:** tanpa latar. Ada keadaan memuat dan nonaktif |
| `RoundAction` | Tombol bulat 44 berisi ikon, latar `primary`, ikon hitam (seperti tombol play di kartu) |
| `AppCard` | Putih, radius 24, bayangan kartu. Varian `featured` (hitam, teks putih), `tinted` (`primaryContainer`) |
| `AppChip` | Pil. Tidak terpilih: `background` (terang) atau `chipDark` (gelap). Terpilih: `primary`, teks hitam. Dipakai untuk tag rasa, grind, filter, jenis toko |
| `AppTextField` | Pil untuk pencarian (dengan ikon), radius 16 untuk isian biasa. Label di atas, galat di bawah dalam `error` |
| `AppBottomNav` | Putih, 6 item: Seduh, Jurnal, Eksplor, Saran & Kesan, Profil, Logout. Item aktif: ikon di atas label maksimal dua baris, di dalam kotak `primaryContainer` radius 16. Item lain: ikon saja berwarna `inkSoft`. Area sentuh tiap item minimal 48 × 48 dan seluruh bar menghormati safe area bawah. Logout adalah aksi dialog dan tidak pernah menjadi item aktif |
| `AppListRow` | Baris dalam kartu putih: ikon, judul, chevron. Pemisah `divider` dengan inset |
| `SegmentProgress` | Batang bersegmen di atas layar (satu segmen per tahap seduh atau langkah) |
| `ScoreChart` | Garis `primary` tebal 2.5, isian gradien `primary` 25% ke transparan, garis bantu putus-putus `divider`, gelembung keterangan pada titik terpilih |
| `StatusPill` | Pil kecil untuk status sinkronisasi dan stok: tersinkron (mint), menunggu (abu), galat (`error`), menipis (`warning`) |
| `StateViews` | `LoadingView`, `EmptyView`, `ErrorView` |
| `AppDialog`, `AppBottomSheet` | Radius 24, tombol memakai `AppButton` |
| `Avatar` | Bulat, foto atau inisial |

**Ikon:** satu keluarga bawaan Flutter (Material Icons varian rounded atau outlined). Jangan menambah paket ikon baru tanpa bertanya.

## 7. Keadaan Layar (wajib semua)

| Keadaan | Tampilan |
|---|---|
| Memuat | `LoadingView`: indikator di tengah. Daftar boleh memakai kerangka (skeleton) sederhana |
| Kosong | `EmptyView`: ikon dalam lingkaran `primaryContainer`, satu kalimat penjelasan, satu tombol ajakan |
| Galat | `ErrorView`: ikon, pesan dalam bahasa Indonesia yang jelas, tombol "Coba lagi" |
| Berhasil | Konfirmasi singkat (snackbar atau perubahan layar). Tidak ada dialog yang tidak perlu |

## 8. Pola Per Layar

Deskripsi bentuk. Isi dan alur ada di spec fitur.

| Layar | Pola |
|---|---|
| **Splash** | Latar `background`, nama "Tetes" besar di tengah |
| **Login / Register** | Judul besar, isian bertumpuk, satu `AppButton` primary penuh lebar, tautan teks di bawah |
| **Seduh (beranda tab)** | Sapaan `headline` + tombol lonceng, kolom pencarian pil, dua `AppCard` sejajar (kartu hitam: biji aktif atau terakhir; kartu putih: aksi cepat), lalu bagian "Pengaturan terbaik" dengan `tinted` card dan `RoundAction` |
| **Daftar biji** | `AppCard` per biji, chip kecil untuk spesies dan sangrai, `StatusPill` untuk stok |
| **Form biji** | Isian bertumpuk, `AppChip` untuk pilihan (spesies, proses, sangrai), slider untuk persen arabika |
| **Atur Seduh** | Isian angka besar, chip grind, daftar tahap sebagai kartu, `ScoreChart` atau grafik air di atas atau bawah kartu tahap, tombol "Mulai Sesi" di dasar layar |
| **Sesi (layar gelap)** | `SegmentProgress` di atas, nama tahap dan target air, **timer `display`**, tombol putih besar "Tahap berikutnya" di bawah, tombol batal berupa teks |
| **Hasil** | Kartu ringkasan, tabel plan vs realisasi di dalam kartu, bintang 1-5 atau wajah sederhana untuk skor rasa, chip tag rasa (boleh dalam bottom sheet gelap), kartu notes roastery vs rasa, tombol simpan |
| **Jurnal** | Sub-tab sebagai chip bertumpuk di atas, kolom cari, baris chip filter, kartu seduhan |
| **Detail seduhan** | Seperti Hasil, ditambah `StatusPill` integritas |
| **Bandingkan** | Dua kolom dalam satu kartu, baris yang berbeda memakai latar `primaryContainer` lembut |
| **Eksplor** | Kartu-kartu menu (Agenda, Toko, Kurs, Game), tiap kartu satu ikon dan satu kalimat |
| **Agenda event** | Kartu event dengan empat jam (WIB, WITA, WIT, London) sebagai baris kecil |
| **Peta toko** | Peta penuh lebar, daftar di bottom sheet yang bisa ditarik, chip filter jenis toko |
| **Game (layar gelap)** | Zona hijau `accent`, titik aliran putih, bar air `primary`, angka waktu `display` |
| **Saran & Kesan** | Layar tab sendiri: dua kolom teks untuk saran dan kesan, tombol Kirim, lalu riwayat kiriman |
| **Profil** | Avatar besar di tengah, nama, `ScoreChart` ringkas bila ada data, dan kartu daftar pengaturan (`AppListRow`). Tidak memuat Saran & Kesan atau Logout |
| **Logout (aksi navigasi)** | Tidak memiliki layar. Ketuk item membuka `AppDialog` konfirmasi; menutup dialog mengembalikan pengguna ke tab aktif sebelumnya |

## 9. Gerak dan Umpan Balik

- Animasi singkat saja: 200 ms, kurva ease-out. Tidak ada animasi dekoratif yang berat.
- **Getar** (haptic) saat ganti tahap seduh dan saat titik keluar zona di game.
- Tombol memberi umpan balik tekan (perubahan opasitas atau ukuran kecil).
- Perpindahan tab tanpa animasi geser yang rumit.

## 10. Bahasa dan Nada Teks

- Bahasa Indonesia, santai tapi jelas, menyapa dengan "kamu".
- Kalimat pendek. Tombol berupa kata kerja ("Simpan", "Mulai Sesi", "Bandingkan").
- Galat menjelaskan apa yang terjadi dan apa yang bisa dilakukan. Contoh: "Tidak ada internet. Saran AI diganti aturan sederhana."
- Teks saran AI selalu berlabel: "Saran, bukan kepastian. Coba dan catat hasilnya."

## 11. Aksesibilitas Dasar

- Area sentuh minimum 48 × 48.
- Kontras sesuai aturan di bagian 2.
- Teks tetap terbaca saat ukuran font sistem dibesarkan (hindari tinggi tetap pada teks).
- Jangan menyampaikan informasi hanya dengan warna (status juga punya teks atau ikon).

## 12. Kerangka Kode Tema (acuan untuk AI)

Letakkan di `lib/app/theme/`. Semua nilai di bagian 2-4 dipusatkan di sini, dan layar hanya membaca dari tema.

```dart
// lib/app/theme/tokens.dart (kerangka, nilai mengikuti tabel di atas)
class AppColors {
  static const primary = Color(0xFF49CBEB);
  static const primaryContainer = Color(0xFF9EE3F6);
  static const accent = Color(0xFF7FF0CB);
  static const ink = Color(0xFF000000);
  static const inkSoft = Color(0xFF5B6168);
  static const background = Color(0xFFF4F5F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const chipDark = Color(0xFF2E2E2E);
  static const warning = Color(0xFFF5A524);
  static const error = Color(0xFFE5484D);
  static const divider = Color(0xFFE6E8EA);
}

class AppSpacing { static const s4 = 4.0; /* 8, 12, 16, 20, 24, 32, 48 */ }
class AppRadius { static const card = 24.0; static const small = 12.0; static const pill = 999.0; }
```

Aturan: tidak ada `Color(0x...)`, angka jarak, atau `TextStyle(fontSize: ...)` langsung di folder `features/`. Semua lewat `AppColors`, `AppSpacing`, `AppRadius`, dan `Theme.of(context).textTheme`.

## 13. Referensi Visual

Simpan tangkapan referensi di `docs/ui-reference/` (folder terpisah dari kode). Gunakan hanya sebagai acuan suasana saat meminta AI membuat layar, bersama deskripsi teks di spec fitur.
