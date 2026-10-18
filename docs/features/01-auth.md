# Fitur 01: Autentikasi server dan biometrik

**Sprint:** 1
**Tujuan:** pengguna dapat mendaftar dan login melalui backend auth buatan sendiri, mempertahankan session, membuka aplikasi dengan biometrik, dan logout dengan pencabutan session server.
**FR terkait:** FR-AUTH-01 sampai FR-AUTH-07, NAV (aksi logout)
**Dokumen wajib dibaca:** ARCHITECTURE.md (bagian 4, 7, 9, 10), DATA_MODEL.md (users, sessions, login_attempts, settings)

## Layar
**Register:** kolom username, password, konfirmasi password (dengan tombol lihat atau sembunyikan), tombol Daftar, tautan ke Login. Pesan galat per kolom.

**Login:** kolom username dan password, tombol Masuk, tautan ke Register, indikator memuat. Pesan kredensial gagal selalu "Username atau password salah".

**Gerbang biometrik:** muncul saat membuka aplikasi bila biometrik aktif dan session lokal belum kedaluwarsa. Tombol "Pakai password" menuju Login dan memerlukan internet.

**Tawaran biometrik:** dialog setelah login pertama berhasil: "Aktifkan biometrik?" (Ya, Nanti).

**Logout:** aksi pada item Logout di bottom navigation. Item membuka dialog konfirmasi, lalu menghapus session aktif lokal dan mencoba mencabutnya melalui `auth-logout`. Logout bukan layar dan tidak menjadi tab aktif.

## Data

### SQLite
Tabel `users` hanya cache profil:
- `id` dari server.
- `username`.
- `photo_path` lokal.
- `created_at`.
- `last_login_at`.

SQLite **tidak menyimpan** `password_hash`, `salt`, `iterations`, `algo`, atau token session.

### Secure storage
- Session aktif: `session_token`, `user_id`, dan `expires_at`.
- Token session acak 32 byte berformat base64url dan berlaku 7 hari tanpa perpanjangan otomatis.
- `pending_revoke_token`: token lama yang gagal dicabut karena offline.

### Postgres
- `users`: kredensial ter-hash dan profil identitas dasar.
- `sessions`: hash token, waktu dibuat, kedaluwarsa, dan status `revoked`.
- `login_attempts`: `(username, window_start, attempt_count)` dengan primary key `(username, window_start)`.
- Semua tabel memakai RLS aktif tanpa policy dan hanya diakses Edge Function dengan service role.

Hash password memakai PBKDF2-HMAC-SHA256 dari Web Crypto bawaan Deno dengan salt acak per pengguna. Jumlah iterasi **tentukan dari rekomendasi terbaru, perlu dicek sebelum implementasi** dan disimpan per pengguna.

## Edge Function
- `auth-register`: membuat user dan session.
- `auth-login`: memverifikasi password, menerapkan pembatasan percobaan, dan membuat session.
- `auth-logout`: mencabut session berdasarkan `x-session-token`.
- Semua fungsi dipasang dengan `--no-verify-jwt`. Tidak memakai Supabase Auth atau layanan auth siap pakai.

## Alur

**Register:**
1. Memerlukan internet. Validasi input di Flutter dan ulangi validasi di server.
2. `auth-register` memastikan username unik, membuat salt, menghitung hash password, dan menyimpan user.
3. Server membuat token session 32 byte, menyimpan SHA-256 token, lalu mengembalikan profil, token, dan `expires_at`.
4. Flutter menyimpan cache profil di SQLite serta session di secure storage, lalu masuk Beranda.

**Login:**
1. Semua login username/password memerlukan internet.
2. `window_start` dibulatkan ke awal jendela 15 menit menurut waktu server. Percobaan dihitung dari username yang diketik meskipun akunnya tidak ada.
3. Kegagalan ke-5 dalam satu jendela menghasilkan `429` dengan sisa waktu tunggu. Login berhasil menghapus baris jendela tersebut.
4. Password cocok: server membuat session baru. Flutter memperbarui cache profil dan `last_login_at`, menyimpan session, lalu masuk Beranda.

**Buka aplikasi:**
1. Baca `expires_at` dari secure storage dan bandingkan dengan jam perangkat.
2. Session lokal belum kedaluwarsa: aplikasi boleh dibuka offline. Jika biometrik aktif, minta biometrik dahulu.
3. Session kedaluwarsa: ke Login. Jika offline, tampilkan pesan bahwa internet diperlukan; tidak ada mode baca saja.
4. Session yang dicabut server baru diketahui saat fungsi terlindungi berikutnya mengembalikan `401`; hapus session lokal dan keluar paksa.

**Logout:**
1. Hitung data lokal dengan `sync_status = pending`. Jika ada, dialog konfirmasi menyebut jumlahnya dan menegaskan data tetap tersimpan tetapi belum terkirim.
2. Setelah dikonfirmasi, hapus session aktif dari secure storage seketika. Data SQLite tidak dihapus.
3. Panggil `auth-logout`. Jika offline, simpan token lama sebagai `pending_revoke_token` dan tampilkan pesan bahwa session server dicabut saat tersambung.
4. Coba `pending_revoke_token` saat aplikasi dibuka dengan internet atau sebelum login berikutnya. Jika pencabutan berhasil atau token sudah tidak sah, hapus kunci tersebut.
5. Pencadang terakhir adalah masa berlaku session 7 hari di server.

## Keadaan layar dan kasus pinggir
- Username sudah dipakai: pesan jelas.
- Password tidak cocok dengan konfirmasi: pesan di kolom konfirmasi.
- Register atau login saat offline: tetap di layar auth dengan pesan "Internet diperlukan untuk masuk atau mendaftar."
- Pesan login gagal tidak membedakan username tidak ada dan password salah.
- Percobaan gagal ke-5: tampilkan sisa waktu tunggu dari respons `429`.
- HP tanpa biometrik atau belum ada sidik jari terdaftar: jangan tawarkan, sembunyikan toggle.
- Biometrik dibatalkan atau gagal: tawarkan login password; bila offline jelaskan bahwa internet diperlukan.
- Session lokal kedaluwarsa saat offline: tertahan di Login tanpa mode baca saja.
- `401` dari fungsi terlindungi: hapus session lokal dan keluar paksa dengan pesan singkat.
- Logout offline: data lokal tetap ada dan token pencabutan tidak dicatat di log.

## JANGAN
- Tidak memakai Firebase, Supabase Auth, atau layanan auth siap pakai.
- Tidak menghitung atau menyimpan hash password di Flutter.
- Tidak menyimpan password asli di mana pun atau mencetak password/token di log.
- Tidak memakai SHA-256 polos untuk password.
- Tidak menyimpan session token di SharedPreferences atau SQLite.
- Tidak membuat fitur lupa password, perpanjangan session otomatis, atau login sosial pada v1.

## Boleh menyentuh
`supabase/functions/auth-register/`, `supabase/functions/auth-login/`, `supabase/functions/auth-logout/`, helper auth bersama di `supabase/functions/_shared/`, migrasi auth di `supabase/migrations/`, `lib/features/auth/`, `lib/data/remote/auth_client.dart`, `lib/data/repositories/user_repo.dart`, helper secure storage, konfigurasi izin biometrik di `android/` dan `ios/`, router/guard, serta penyambungan aksi Logout di shell navigasi.

## Acceptance criteria
- [ ] Register online berhasil dan Postgres hanya menyimpan hash PBKDF2, salt, iterasi, dan algo—bukan password asli
- [ ] SQLite `users` hanya berisi cache profil tanpa data hash password
- [ ] Dua akun dengan username sama ditolak
- [ ] Login online berhasil dan pesan kredensial gagal selalu umum
- [ ] Kegagalan ke-5 dalam jendela 15 menit menghasilkan `429` dan sisa waktu tunggu
- [ ] Login berhasil menghapus baris percobaan untuk jendela aktif
- [ ] Session berlaku 7 hari tanpa perpanjangan otomatis
- [ ] Dengan session valid, tutup aplikasi lalu buka offline: masuk tanpa password, lewat biometrik bila aktif
- [ ] Session kedaluwarsa saat offline tertahan di Login dengan pesan membutuhkan internet
- [ ] Biometrik gagal atau dibatalkan: bisa menuju login password
- [ ] Logout online mencabut session server dan menghapus session lokal tanpa menghapus data SQLite
- [ ] Logout offline menyimpan `pending_revoke_token`, lalu mencabutnya saat internet kembali atau sebelum login berikutnya
- [ ] Logout dengan data pending menampilkan jumlahnya sebelum konfirmasi
- [ ] Session yang dicabut menghasilkan `401` pada permintaan berikutnya dan memaksa logout
- [ ] Tidak ada password, token session, atau hash token di log

## Cara uji
Register dua akun, coba username duplikat, lakukan lima login gagal dalam jendela yang sama, lalu login benar setelah jendela berganti. Aktifkan biometrik, buka ulang aplikasi saat offline dengan session valid, uji session kedaluwarsa saat offline, logout dengan data pending, logout offline lalu sambungkan internet, dan pastikan session lama ditolak server.

## Langkah pengerjaan yang disarankan
1. Migrasi tabel auth dan helper PBKDF2/session di Edge Function, dengan tes. Berhenti.
2. `auth-register` dan layar Register. Berhenti.
3. `auth-login`, pembatasan percobaan, dan layar Login. Berhenti.
4. Penyimpanan session, cache profil, dan guard router termasuk alur offline. Berhenti.
5. Biometrik. Berhenti.
6. Logout, data pending, dan pencabutan tertunda. Berhenti.
