# Fitur 06: Eksplor (agenda event, notifikasi, LBS, kalkulator kurs)

**Sprint:** 6
**Tujuan:** pengguna mencatat event kopi dengan konversi zona waktu dan pengingat, menerima notifikasi seduh dan stok, serta menemukan toko biji atau alat seduh terdekat.
**FR terkait:** FR-EVT-01 sampai 04, FR-NOTIF-01 sampai 04, FR-LBS-01 sampai 03, FR-CUR-04
**Dokumen wajib dibaca:** DATA_MODEL.md (events, stores), ARCHITECTURE.md (bagian 5.3, 5.4, 5.5, 10)

## Layar
Tab Eksplor berisi empat bagian: **Agenda Event**, **Toko Terdekat**, **Kalkulator Kurs**, **Game** (Game dikerjakan di Fitur 07, sediakan tempatnya).

### Agenda Event
- Daftar event mendatang (terdekat dahulu) dan event lampau (terpisah). Kartu menampilkan nama, jenis, lokasi, dan jam di **WIB, WITA, WIT, dan London**.
- Tombol tambah. **Form event:** nama (wajib), jenis, tanggal dan jam mulai (wajib), zona waktu event (wajib: WIB, WITA, WIT, London, atau zona lain), lokasi, catatan, pengingat (pilihan: 1 hari, 3 jam, 30 menit, boleh lebih dari satu, maksimal tiga).
- Detail event: semua informasi, tombol ubah dan hapus. Tombol "Buka lokasi di peta" bila lokasi berupa alamat (opsional).

### Toko Terdekat (LBS)
- Peta OpenStreetMap dengan posisi pengguna dan marker toko dari tabel `stores` (toko biji, toko alat seduh, roastery). Filter jenis toko.
- Daftar di bawah peta, diurutkan menurut jarak. Ketuk marker atau item untuk detail dan tombol "Buka navigasi" (membuka aplikasi peta di perangkat).
- Hanya toko biji, toko alat seduh, dan roastery. **Bukan kedai kopi.**

### Kalkulator Kurs (prioritas S)
- Input jumlah, pilih mata uang asal dan tujuan (minimal IDR, USD, EUR, JPY), hasil, dan tanggal kurs. Memakai klien kurs dan cache dari Fitur 02.

## Data
- Tabel `events`. Simpan `start_utc` dan `source_zone` (nama IANA: `Asia/Jakarta`, `Asia/Makassar`, `Asia/Jayapura`, `Europe/London`). **Jangan menyimpan selisih jam tetap.**
- Tampilan: konversi dari UTC ke empat zona dengan paket `timezone`.
- Edit dan hapus event bebas (tidak ikut hash). Hapus memakai `deleted = 1`.
- Notifikasi: ID = `notif_base_id * 10 + indeks pengingat`. Saat aplikasi dibuka, batalkan lalu jadwalkan ulang semua notifikasi mendatang.

## Notifikasi
| Jenis | Pemicu | Isi |
|---|---|---|
| Event | Sesuai pengingat event | Nama event dan sisa waktu |
| Seduh harian | Jam dan hari yang diatur di Profil | "Waktunya seduh" |
| Stok menipis | Stok tersisa di bawah ambang saat seduhan disimpan | "Stok [biji] tinggal X g", ketuk membuka peta Toko Terdekat |

- **Ambang stok default 15 g**, dapat diubah di Profil (`low_stock_threshold_g`).
- Minta izin notifikasi saat pertama dibutuhkan. Jelaskan alasannya sebelum meminta.
- Pengingat seduh harian hanya jadwal lokal berulang. Pengaturannya (jam, hari, aktif atau tidak) ada di Profil (Fitur 07), fungsi penjadwalnya dibuat di sini.

## Keadaan layar dan kasus pinggir
- Event kosong: ajakan menambah event pertama.
- Izin lokasi ditolak: daftar toko tanpa urutan jarak, dengan penjelasan dan cara mengaktifkan.
- Izin notifikasi ditolak: penjelasan, jangan menjadwalkan diam-diam.
- Tanggal event sudah lewat: tolak pengingat yang waktunya sudah lampau.
- Perubahan jam musim: aman karena disimpan UTC dan zona IANA.
- Android: uji izin alarm tepat waktu di HP asli. Bila notifikasi telat, catat di PROGRESS.md.
- HP restart: jadwalkan ulang saat aplikasi dibuka.

## JANGAN
- Tidak ada fitur berbagi event, penjualan tiket, atau pembayaran.
- Tidak ada pencari kedai kopi.
- Tidak mengambil data event dari API eksternal.
- Tidak menyimpan waktu event sebagai teks lokal tanpa zona.
- Tidak memasukkan event ke hash chain.

## Boleh menyentuh
`lib/features/explore/`, `lib/data/repositories/event_repo.dart`, `lib/core/utils/` (zona waktu), `lib/core/notifications/` (penjadwal), konfigurasi izin di `android/` dan `ios/`, aset seed `stores`.

## Acceptance criteria
- [ ] Event pukul 14.00 di zona London tampil benar di WIB, WITA, WIT, dan London
- [ ] Event dengan pengingat 2 menit ke depan memunculkan notifikasi
- [ ] Mengubah atau menghapus event membatalkan notifikasi lama
- [ ] Menutup lalu membuka aplikasi tidak menghilangkan notifikasi mendatang (dijadwalkan ulang)
- [ ] Notifikasi stok menipis muncul saat stok turun di bawah 15 g, dan ketuk mengarah ke peta
- [ ] Ambang stok yang diubah di Profil dipakai
- [ ] Peta menampilkan posisi dan marker toko, daftar terurut jarak
- [ ] Izin lokasi ditolak tidak menyebabkan crash
- [ ] Kalkulator kurs mengonversi minimal tiga mata uang

## Cara uji
Buat tiga event (WIB, London, WIT), uji notifikasi dengan waktu dekat, ubah dan hapus event, restart HP, tolak izin lokasi lalu aktifkan. Gunakan 10-15 toko seed.

## Langkah pengerjaan yang disarankan
1. Utilitas zona waktu dengan tes unit. Berhenti.
2. CRUD event dan tampilan empat zona. Berhenti.
3. Penjadwal notifikasi dan pengingat event. Berhenti.
4. Notifikasi stok menipis dan pengingat seduh. Berhenti.
5. Peta dan toko terdekat. Berhenti.
6. Kalkulator kurs. Berhenti.
