// Membuat dompet uji baru dan menyimpan kunci privatnya ke blockchain/.env.
// Kunci tidak pernah dicetak; hanya alamat publik yang ditampilkan.
const fs = require("fs");
const path = require("path");
const { Wallet } = require("ethers");

const envPath = path.join(__dirname, "..", ".env");
const examplePath = path.join(__dirname, "..", ".env.example");

if (!fs.existsSync(envPath)) fs.copyFileSync(examplePath, envPath);
let text = fs.readFileSync(envPath, "utf8");

if (/^DEPLOYER_PRIVATE_KEY=0x[0-9a-fA-F]{64}\s*$/m.test(text)) {
  console.error(
    "DEPLOYER_PRIVATE_KEY sudah terisi di .env. Hapus barisnya dulu jika ingin membuat dompet baru.",
  );
  process.exit(1);
}

const wallet = Wallet.createRandom();
const line = `DEPLOYER_PRIVATE_KEY=${wallet.privateKey}`;
text = /^DEPLOYER_PRIVATE_KEY=.*$/m.test(text)
  ? text.replace(/^DEPLOYER_PRIVATE_KEY=.*$/m, line)
  : `${text.trimEnd()}\n${line}\n`;
fs.writeFileSync(envPath, text);

console.log(`ALAMAT: ${wallet.address}`);
console.log("Kunci privat disimpan di blockchain/.env (tidak ditampilkan).");
