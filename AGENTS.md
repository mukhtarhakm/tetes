# AGENTS.md: aturan kerja untuk AI (Tetes)

Berkas ini dibaca di awal setiap sesi. Jika alatmu memakai nama lain (CLAUDE.md, .cursorrules, dan sebagainya), salin isinya ke berkas tersebut.

## Proyek
Tetes: jurnal dan alat bantu seduh V60 (Flutter). Tugas kuliah dengan batas waktu 8 hari. Pemilik: Rais Mukhtar Hakim. Package ID: `com.raismukhtar.tetes`.

## Urutan membaca (setiap sesi)
1. `docs/PRD.md`: apa yang dibuat dan apa yang TIDAK dibuat
2. `docs/ARCHITECTURE.md`: stack, struktur kode, alur, kontrak Edge Function
3. `docs/DATA_MODEL.md`: tabel dan aturan hash chain
4. `docs/UI_SPEC.md`: tema dan komponen (jika sudah ada)
5. Spec fitur yang disebut di pesan ini: `docs/features/NN-*.md`
6. `docs/PROGRESS.md` dan `docs/DECISIONS.md`

Jika dokumen saling bertentangan atau ambigu: **berhenti dan tanya**. Jangan menebak.

## Aturan utama
- Kerjakan **hanya** fitur yang disebut di pesan ini. Jangan menambah fitur, layar, atau field di luar spec.
- **Rencana dulu.** Sebelum menulis kode, tulis: file yang akan dibuat atau diubah, paket yang akan dipakai, dan langkah-langkahnya. Tunggu persetujuan.
- **Langkah kecil.** Selesaikan satu langkah yang bisa dijalankan, lalu berhenti agar saya uji di HP.
- **Dependency:** jangan menambah atau memperbarui paket tanpa bertanya. Sebutkan nama dan alasannya. Jangan mengarang nama paket atau versi. Jika tidak yakin, katakan.
- **File:** hanya ubah file yang diizinkan di bagian "Boleh menyentuh" pada spec fitur. Jangan menulis ulang file yang bukan bagian tugas.
- **Larangan keras:**
  - Tanpa Firebase dan tanpa Supabase Auth. Register, login, session, dan logout dibuat sendiri lewat Edge Function; hash password tidak boleh dilakukan atau disimpan di Flutter.
  - Tidak ada rahasia (API key LLM, service role key) di kode Flutter, di Git, atau di log.
  - Tidak ada katalog resep, berbagi resep, atau pencari kedai kopi.
  - Tidak ada edit atau hapus entri `brews`. Hanya status dibatalkan.
  - Jangan mengubah format hash, nama kolom, enum, atau kontrak Edge Function tanpa instruksi eksplisit.
- **ID data aplikasi** adalah UUID v4 yang dibuat di Flutter. `users.id` dan `sessions.id` dibuat server. Waktu disimpan sebagai UTC ISO 8601 tanpa milidetik.
- **UI:** semua warna, ukuran, jarak, dan gaya teks diambil dari tema. Jangan menulis nilai gaya langsung di layar. Pakai komponen bersama di `lib/core/ui/`. Setiap layar punya empat keadaan: memuat, kosong, galat, berhasil.
- **Layering:** UI tidak mengakses SQLite atau HTTP langsung. Alurnya UI, state, repository.
- **Teks antarmuka** dalam bahasa Indonesia. Pesan galat jelas dan tidak membocorkan detail teknis atau rahasia.
- **Kode:** nama berkas, kelas, dan variabel dalam bahasa Inggris. Komentar singkat hanya untuk logika yang tidak jelas.

## Definition of Done (setiap langkah)
- [ ] Jalan di HP asli (bukan hanya emulator) untuk fitur yang memakai sensor, biometrik, notifikasi, atau lokasi
- [ ] `flutter analyze` bersih
- [ ] Acceptance criteria di spec fitur terpenuhi
- [ ] Kasus pinggir di spec ditangani (izin ditolak, offline, data kosong)
- [ ] Tidak ada perubahan di luar "Boleh menyentuh"
- [ ] `docs/PROGRESS.md` diperbarui, keputusan baru dicatat di `docs/DECISIONS.md`

## Format jawaban setelah selesai
1. Ringkasan apa yang diubah (daftar berkas)
2. Cara menguji (langkah manual)
3. Hal yang belum dikerjakan atau diasumsikan
4. Pertanyaan yang tersisa (jika ada)

## Saat ada bug
Jelaskan dulu penyebabnya berdasarkan pesan error lengkap, lalu beri perbaikan sekecil mungkin. Jangan merombak banyak berkas untuk satu bug.

## Saat ragu
Tanya. Lebih baik satu pertanyaan singkat daripada seratus baris kode yang salah arah.
