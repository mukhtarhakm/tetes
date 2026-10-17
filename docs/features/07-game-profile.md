# Fitur 07: Game, profil, Saran & Kesan

**Sprint:** 7
**Tujuan:** mini game "Steady Pour" berbasis gyroscope, profil pengguna lengkap, dan Saran & Kesan.
**FR terkait:** FR-GAME-01 sampai 05, FR-PROF-01 sampai 04, FR-NAV-02, FR-AUTH-07
**Dokumen wajib dibaca:** ARCHITECTURE.md (bagian 5.6), DATA_MODEL.md (game_scores, feedback, settings)

## Bagian A: Game "Steady Pour"

**Konsep:** pengguna memegang HP seperti memegang teko dan memiringkannya untuk menjaga titik aliran di dalam zona hijau di atas V60 sampai bar air penuh sebelum waktu habis. Ini latihan kestabilan tangan, bukan penilai teknik seduh.

### Layar
- Pemilihan level dengan bintang dan skor tertinggi.
- Layar bermain (tampak atas): zona hijau berbentuk lingkaran, titik aliran digerakkan sensor, bar air, waktu tersisa, tombol jeda, hitung mundur 3-2-1 sebelum mulai.
- Layar hasil: akurasi (persen waktu titik di dalam zona), bintang, tombol ulang dan kembali.

### Level
| Level | Nama | Zona | Prioritas |
|---|---|---|---|
| 1 | Bloom | Besar, diam di tengah, sekitar 15 detik | M |
| 2 | Pouring | Lebih kecil, bergerak pelan melingkar | S |
| 3 | Finish | Kecil, lebih cepat | S |

### Aturan
- Titik di dalam zona: bar naik. Di luar zona: bar berhenti, titik berubah warna, getar pelan.
- Bintang: akurasi ≥ 90% tiga bintang, ≥ 70% dua bintang, selesai satu bintang.
- Level berikutnya terbuka setelah level sebelumnya selesai.
- Skor tertinggi per level disimpan di `game_scores` (lokal, ikut sinkronisasi memakai mekanisme biasa).

### Sensor
- **Gyroscope** sebagai kontrol (integrasikan kecepatan putar menjadi sudut, tambahkan peredaman agar titik tertarik pelan ke tengah dan layar kalibrasi "pegang datar lalu ketuk Mulai").
- Pengaturan sensitivitas (rendah, sedang, tinggi) disimpan di `settings`.
- **Dikerjakan bertahap:** prototipe kasar (titik bergerak mengikuti gyroscope) diuji di HP dulu sebelum zona, bar, dan skor ditambahkan.
- Jika kontrol gyroscope tidak enak setelah dicoba, cadangannya accelerometer untuk game. **Jangan mengganti diam-diam.** Catat di DECISIONS.md dan pastikan dua sensor tetap terpakai di dua fitur berbeda (accelerometer untuk goyang timer di Fitur 03).
- Emulator tidak punya sensor yang berguna. Uji di HP asli.

## Bagian B: Profil

### Layar Profil
- **Header:** foto profil (ambil dari kamera atau galeri, simpan berkas di folder aplikasi dan path di `users.photo_path`), username.
- **Pengaturan:** toggle biometrik, pengingat seduh (aktif, jam, hari), ambang stok menipis (default 15 g).
- **Data:** tombol "Sinkronkan sekarang" dan status terakhir sinkron (dari Fitur 05).
- **Keamanan:** tombol "Verifikasi Integritas Jurnal" menampilkan "utuh (N entri)" atau "rantai putus di entri ke-K".
- **Saran & Kesan** dan **Logout**: ditempatkan sesuai jawaban dosen. Sementara di dalam Profil. Jika dosen meminta terpisah di bottom navigation, tambahkan tab dan jangan ubah struktur data.

## Bagian C: Saran & Kesan
- Dua kolom teks: saran dan kesan untuk mata kuliah Pemrograman Aplikasi Mobile. Tombol Kirim. Riwayat kiriman di bawahnya.
- Disimpan di `feedback`, ikut sinkronisasi.
- Kolom tidak boleh dikirim kosong (minimal salah satu terisi).

## Bagian D: Perapian
- Pembatasan percobaan login (FR-AUTH-07) bila belum ada dari Fitur 01.
- Pesan galat dan keadaan kosong di semua layar diperiksa.
- Konsistensi tema dan komponen.

## Keadaan layar dan kasus pinggir
- Sensor tidak tersedia: tombol game dinonaktifkan dengan pesan jelas.
- Izin kamera atau galeri ditolak: pesan dan tombol pengaturan.
- Foto sangat besar: perkecil sebelum disimpan.
- Aplikasi masuk latar belakang saat bermain: jeda otomatis.
- Verifikasi pada jurnal besar tetap responsif (tampilkan indikator memuat).

## JANGAN
- Tidak ada papan peringkat antar pengguna atau game lain.
- Tidak menghubungkan skor game ke data seduhan atau ke hash chain.
- Tidak mengunggah foto ke server.
- Tidak mengubah format hash saat membuat tombol verifikasi (memakai fungsi dari Fitur 03).

## Boleh menyentuh
`lib/features/game/`, `lib/features/profile/`, `lib/data/repositories/score_repo.dart` dan `feedback_repo.dart`, konfigurasi izin kamera di `android/` dan `ios/`.

## Acceptance criteria
- [ ] Titik bergerak mengikuti kemiringan HP dan zona memberi progres bar
- [ ] Level 1 dapat diselesaikan dan skor serta bintang tersimpan
- [ ] Skor tertinggi bertahan setelah aplikasi ditutup
- [ ] Sensitivitas dapat diubah dan terasa bedanya
- [ ] Foto profil dapat diganti dan tampil di Profil setelah aplikasi dibuka ulang
- [ ] Toggle biometrik, jam seduh, dan ambang stok tersimpan dan dipakai
- [ ] Saran & Kesan tersimpan dan riwayat tampil
- [ ] Verifikasi integritas menyatakan utuh pada data normal dan rantai putus setelah uji tamper
- [ ] Logout bersih dan kembali ke Login

## Cara uji
Mainkan level 1-3 dengan sensitivitas berbeda, ganti foto dari kamera dan galeri, kirim Saran & Kesan, ubah pengaturan dan buka ulang aplikasi, jalankan verifikasi sebelum dan sesudah uji tamper.

## Langkah pengerjaan yang disarankan
1. Prototipe gyroscope: titik bergerak. Uji di HP. Berhenti.
2. Zona, bar, akurasi, dan hasil level 1. Berhenti.
3. Skor tersimpan dan pemilihan level. Berhenti.
4. Level 2 dan 3, sensitivitas, dan kalibrasi (bila waktu). Berhenti.
5. Layar Profil dan foto. Berhenti.
6. Pengaturan, verifikasi integritas, dan Saran & Kesan. Berhenti.
7. Perapian. Berhenti.
