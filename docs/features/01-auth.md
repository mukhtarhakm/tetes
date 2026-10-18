# Fitur 01: Autentikasi lokal dan biometrik

**Sprint:** 1
**Tujuan:** pengguna dapat mendaftar, login, tetap masuk lewat session, membuka aplikasi dengan biometrik, dan logout.
**FR terkait:** FR-AUTH-01 sampai FR-AUTH-07, NAV (aksi logout)
**Dokumen wajib dibaca:** ARCHITECTURE.md (bagian 4, 9, 10), DATA_MODEL.md (users, settings)

## Layar
**Register:** kolom username, password, konfirmasi password (dengan tombol lihat atau sembunyikan), tombol Daftar, tautan ke Login. Pesan galat per kolom.
**Login:** kolom username dan password, tombol Masuk, tautan ke Register, indikator memuat. Pesan galat umum.
**Gerbang biometrik:** muncul saat membuka aplikasi bila biometrik aktif dan session masih valid. Tombol "Pakai password".
**Tawaran biometrik:** dialog setelah login pertama berhasil: "Aktifkan biometrik?" (Ya, Nanti).
**Logout:** aksi pada item Logout di bottom navigation. Item membuka dialog konfirmasi, lalu menghapus session dan kembali ke Login. Logout bukan layar dan tidak menjadi tab aktif.

## Data
- Tabel `users` dan `settings` (`biometric_enabled`).
- Hash password: PBKDF2-HMAC-SHA256, salt acak 16 byte, simpan salt dan jumlah iterasi bersama hash.
- Session di secure storage: `user_id` dan `expires_at` (7 hari).
- `sync_key` (32 byte acak, base64url) dibuat saat register, disimpan di secure storage. Belum dipakai sampai Sprint 5.
- Validasi sesuai DATA_MODEL.md bagian 4.

## Alur
**Register:** validasi, cek username unik, buat `user_id`, salt, hash, `sync_key`, simpan. Lalu langsung login atau arahkan ke Login.
**Login:** ambil pengguna, hitung hash dengan salt dan iterasi tersimpan, bandingkan dengan perbandingan waktu-konstan. Cocok: buat session, tawarkan biometrik bila belum pernah ditanya, masuk Beranda.
**Buka aplikasi:** session valid? tidak: Login. Ya: bila biometrik aktif, minta biometrik, gagal berarti Login. Sukses: Beranda.
**Pembatasan percobaan:** setelah 5 gagal beruntun, kunci beberapa menit dengan pesan waktu tunggu.
**Logout:** hapus session. Data lokal tetap.

## Keadaan layar dan kasus pinggir
- Username sudah dipakai: pesan jelas.
- Password tidak cocok dengan konfirmasi: pesan di kolom konfirmasi.
- HP tanpa biometrik atau belum ada sidik jari terdaftar: jangan tawarkan, sembunyikan toggle.
- Biometrik dibatalkan atau gagal: tawarkan password, jangan crash.
- Session kedaluwarsa: ke Login dengan pesan singkat.
- Pesan galat login selalu "Username atau password salah" (tidak membedakan).

## JANGAN
- Tidak memakai Firebase atau Supabase Auth.
- Tidak menyimpan password asli di mana pun, tidak mengirimnya ke server, tidak mencetaknya di log.
- Tidak memakai SHA-256 polos untuk password.
- Tidak menyimpan session atau `sync_key` di SharedPreferences atau SQLite.
- Tidak membuat fitur lupa password atau login sosial.

## Boleh menyentuh
`lib/features/auth/`, `lib/data/repositories/user_repo.dart`, `lib/core/utils/` (hash password), konfigurasi izin biometrik di `android/` dan `ios/`, router (hanya tambah rute auth dan guard).

## Acceptance criteria
- [ ] Register berhasil dan password di database berupa hash, bukan teks asli
- [ ] Dua akun dengan username sama ditolak
- [ ] Login berhasil, tutup aplikasi, buka lagi: masuk tanpa mengetik password (lewat biometrik bila aktif)
- [ ] Biometrik gagal atau dibatalkan: bisa login dengan password
- [ ] Logout menghapus session. Setelah itu membuka aplikasi menuju Login
- [ ] Lima percobaan gagal memicu penguncian sementara
- [ ] HP tanpa biometrik tidak menampilkan opsinya
- [ ] Tidak ada password atau `sync_key` di log

## Cara uji
Register dua akun, login bergantian, aktifkan biometrik, tutup paksa aplikasi, buka lagi, uji sidik jari salah, logout. Periksa isi tabel `users`.

## Langkah pengerjaan yang disarankan
1. Fungsi hash password dan verifikasi, dengan tes unit. Berhenti.
2. Register dan Login (tanpa session). Berhenti.
3. Session di secure storage dan guard router. Berhenti.
4. Biometrik. Berhenti.
5. Logout dan pembatasan percobaan. Berhenti.
