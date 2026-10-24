# BrewAnchor (Ethereum Sepolia)

Kontrak ini menyimpan hash kepala rantai seduhan per pengguna. Data seduhan tetap di database. `userKey` adalah `keccak256` dari UUID pengguna yang dihitung di luar kontrak; `headHash` adalah 32 byte dari hash SHA-256 hex kepala rantai, tanpa mengubah format hash seduhan.

## Install dan test

Perlu Node.js 24.14.0 atau versi yang kompatibel dengan paket terkunci. Di PowerShell:

```powershell
cd blockchain
npm ci
npm test
```

`npm test` memakai jaringan lokal bawaan Hardhat. Hasil saat ini: 72.532 gas untuk anchor pertama per pengguna dan 38.332 gas untuk pembaruan pengguna yang sama. Ini estimasi gas transaksi lokal, bukan biaya ETH tetap; biaya Sepolia bergantung pada harga gas saat transaksi.

## Siapkan deploy Sepolia

Salin `.env.example` menjadi `.env`, lalu isi `RPC_URL` dan `DEPLOYER_PRIVATE_KEY` milik akun deploy yang memiliki Sepolia ETH. `.env` diabaikan Git. Jangan bagikan kunci atau URL RPC.

```powershell
Copy-Item .env.example .env
npm run deploy:sepolia
```

Skrip mencetak alamat kontrak dan tautan Etherscan Sepolia. Deploy hanya terjadi saat perintah tersebut dijalankan.

## Verifikasi kontrak (opsional)

Setelah deploy, buka alamat kontrak pada Etherscan Sepolia dan gunakan fitur **Verify and Publish**. Pilih Solidity 0.8.24, lisensi MIT, optimisasi sesuai konfigurasi Hardhat (tidak aktif), dan masukkan sumber `contracts/BrewAnchor.sol`. Kontrak tidak mempunyai argumen constructor. Verifikasi tidak memerlukan plugin tambahan.

## Batasan

Kontrak membuktikan bahwa suatu hash kepala rantai telah dicatat pada waktu blok tertentu. Kontrak tidak memverifikasi isi rantai seduhan. Verifikasi penuh harus menghitung ulang rantai di aplikasi dan membandingkan kepala rantai dengan hash on-chain. Hanya owner yang bisa menulis; perpindahan owner memungkinkan rotasi kunci. Kontrak hanya menyimpan jangkar terbaru per `userKey` (riwayat jangkar dapat dilihat melalui event). Belum ada integrasi Flutter atau Edge Function untuk menulis atau membaca jangkar.
