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
| `rating` | `#F5B83D` | Bintang skor seduhan; bintang kosong memakai `divider` |
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
| `AppChip` | Pil. Tidak terpilih: `surface` dengan garis tipis `divider` pada layar terang, atau `chipDark` pada layar gelap. Terpilih: `primary` dengan teks `ink`. Lebar mengikuti teks tanpa memotong label. Dipakai untuk tag rasa, grind, filter, jenis toko |
| `AppTextField` | Pil untuk pencarian (dengan ikon), radius 16 untuk isian biasa. Label di atas, galat di bawah dalam `error` |
| `AppBottomNav` | Putih, 4 item: Beranda, Profil, Saran & Kesan, Logout. Label selalu tampak dalam satu baris. Item aktif memakai pil `primaryContainer` dengan teks dan ikon hitam; Profil memakai foto kecil atau inisial pengguna dengan cincin saat aktif. Area sentuh tiap item minimal 48 × 48 dan bar menghormati safe area bawah. Logout dipisah tipis, berwarna netral, berupa aksi dialog konfirmasi dengan peringatan data belum sinkron dan tidak pernah aktif |
| `AppListRow` | Baris dalam kartu putih: ikon, judul, chevron. Pemisah `divider` dengan inset |
| `SegmentProgress` | Batang bersegmen di atas layar (satu segmen per tahap seduh atau langkah) |
| `ScoreChart` | Garis `primary` tebal 2.5, isian gradien `primary` 25% ke transparan, garis bantu putus-putus `divider`, gelembung keterangan pada titik terpilih |
| `StatusPill` | Pil kecil untuk status sinkronisasi dan stok: tersinkron (mint), menunggu (abu), galat (`error`), menipis (`warning`) |
| `RatingStars` | Ikon bintang bulat untuk skor 1–5, warna `rating`, nilai `n/5` tetap tertulis dan diumumkan pembaca layar; mode ringkas memakai satu ikon |
| `StateViews` | `LoadingView`, `EmptyView`, `ErrorView` |
| `TetesLogo`, `TetesBrand` | Logo buatan sendiri (kotak hitam dengan kerucut V60 putih dan setetes cyan) digambar dengan `CustomPainter`, tanpa aset gambar atau paket. `TetesBrand` menambah nama "Tetes" dan tagline; dipakai di Login dan Register |
| `ChainAnchorCard` | Status jangkar Sepolia. Mode `compact`: satu baris (ikon, judul, keterangan, chevron) yang membuka kartu lengkap di bottom sheet; mode penuh memuat teks penjelasan, tombol Verifikasi, dan Etherscan. Garis tepi `primary` bila cocok, `error` bila tidak cocok atau tidak ditemukan; tersembunyi bila belum ada seduhan |
| `CustomTasteChip`, `AddCustomTasteChip` | Rasa buatan sendiri: chip kuning (`stage3Soft` dengan garis `stage3`) berikon x untuk menghapus, dan chip putus-putus "Rasa lain" dengan ikon plus untuk menambah. Tinggi 36, tidak dipakai untuk tag bawaan |
| `AppDialog`, `AppBottomSheet` | Radius 24, tombol memakai `AppButton` |
| `Avatar` | Bulat, foto atau inisial |

**Ikon:** satu keluarga bawaan Flutter (Material Icons varian rounded atau outlined). Jangan menambah paket ikon baru tanpa bertanya.
Pintasan Biji kopi memakai `BeanIcon` bergaris hitam berukuran sama dengan ikon pintasan lain di dalam lingkaran cyan; kartu biji pada Beranda memakai ikon yang sama.

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
| **Splash** | Native: latar `background` dengan logo di tengah (Android 12+: ikon aplikasi di latar `background`). Flutter: `TetesSplash` dengan logo 104, nama, tagline, dan tiga titik berdenyut selama memeriksa sesi |
| **Login / Register** | `TetesBrand` di atas, judul, isian bertumpuk, satu `AppButton` primary penuh lebar, tautan teks di bawah. Login menambah pembatas "atau" dan tombol sekunder "Masuk dengan sidik jari" bila perangkat dan akun mendukung |
| **Beranda (tab)** | Tanggal kecil di atas sapaan dua baris dan status sinkron di sisi kanan; kartu putih berisi tombol Mulai seduh dan baris Seduh lagi hanya bila ada pengaturan; ringkasan Seduhan terakhir selebar layar di atas pasangan Stok menipis dan Event berikutnya; satu bagian Pintasan dengan enam kartu dua kolom. Layar fitur dibuka penuh tanpa bottom navigation |
| **Daftar biji** | Kolom cari pil (nama, roastery, asal), chip filter Semua/Stok menipis/Roasting sendiri, jumlah hasil, lalu `AppCard` per biji dengan chip spesies dan sangrai serta `StatusPill` stok |
| **Form biji** | Isian bertumpuk; setiap kelompok `AppChip` memakai `Wrap` dengan jarak horizontal dan vertikal dari token `AppSpacing`, sehingga chip berpindah baris tanpa memotong teks; slider untuk persen arabika |
| **Atur Seduh** | Isian angka besar, chip grind, daftar tahap sebagai kartu, `ScoreChart` atau grafik air di atas atau bawah kartu tahap, tombol "Mulai Sesi" di dasar layar. Tombol AI membuka lembar bawah "Sebelum AI menyarankan": judul, teks bantu "Semua opsional", kolom Dosis kopi (g) di kanan label, chip Jumlah pouring ("Biar AI pilih" dan 1-5), kolom Keinginanmu tiga baris dengan penghitung 200, lalu tombol sekunder Lewati dan primary Minta saran berdampingan. Kartu Saran AI menampilkan satu baris ringkasan preferensi berwarna `inkSoft` di bawah judul |
| **Sesi (layar gelap)** | `SegmentProgress` di atas, nama tahap dan target air, **timer `display`**, tombol putih besar "Tahap berikutnya" di bawah, tombol batal berupa teks |
| **Hasil** | Dirancang muat dalam satu layar, tombol Simpan menempel di bawah. Kartu ringkasan kecil (nama biji, biaya, empat angka Dosis/Rasio/Suhu/Waktu yang turun baris bila sempit), lima tombol skor 1-5 (wajib), chip tag rasa bawaan (wajib minimal satu) ditambah chip rasa buatan maksimal tiga, satu baris teks bantu "Kata roastery ... Rasamu ...", kartu "Timbangan tiap tahap" (opsional) berisi angka kumulatif di timbangan per tahap dengan target sebagai petunjuk, dan Catatan yang dilipat. Tuangan per tahap dihitung dari selisih angka kumulatif; angka tidak boleh turun. Angka bulat tampil tanpa ".0" |
| **Jurnal** | Baris jangkar ringkas (`ChainAnchorCard` mode `compact`) di atas, lalu kolom cari, tombol filter, kartu seduhan; baris jangkar dibuka sebagai bottom sheet. Daftar biji hanya ada di layar Biji kopi dari Beranda |
| **Detail seduhan** | Seperti Hasil, ditambah `StatusPill` integritas dan chip rasa buatan di samping tag bawaan |
| **Bandingkan** | Dua kolom dalam satu kartu, baris yang berbeda memakai latar `primaryContainer` lembut |
| **Pintasan fitur** | Agenda, Toko, Kurs, dan Game dibuka dari Beranda sebagai layar penuh, masing-masing mempertahankan isi fiturnya |
| **Cek Harga Biji** | Kartu hitam (`FocusDarkTheme`): angka harga besar, chip mata uang dan isi kemasan, hasil rupiah besar warna `accent`, harga per gram dan per seduhan. Kartu putih "Dibanding biji kamu" dengan kalimat selisih persen dan batang per biji. Baris kecil kurs dan tanggal di bawah |
| **Agenda event** | Kartu event dengan empat jam (WIB, WITA, WIT, London) sebagai baris kecil |
| **Peta toko** | Peta penuh lebar, daftar di bottom sheet yang bisa ditarik, chip filter jenis toko |
| **Game (layar gelap)** | Zona hijau `accent`, titik aliran putih, bar air `primary`, angka waktu `display` |
| **Saran & Kesan** | Layar tab sendiri: dua kolom teks untuk saran dan kesan, tombol Kirim, lalu riwayat kiriman |
| **Profil** | Header dengan foto, nama, dan statistik; bagian Keamanan, Sinkronisasi, Pengingat, serta Tentang dengan atribusi OpenStreetMap dan OpenFreeMap. Tidak memuat Saran & Kesan atau Logout |
| **Logout (aksi navigasi)** | Tidak memiliki layar dan tidak pernah terpilih. Ketuk item membuka `AppDialog` konfirmasi dengan peringatan data belum sinkron; menutup dialog mengembalikan pengguna ke tab aktif sebelumnya |

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
