import "@nomicfoundation/hardhat-ethers";
import { ethers, network } from "hardhat";

async function main() {
  if (network.name !== "sepolia") throw new Error("Gunakan jaringan sepolia.");
  if (!process.env.RPC_URL || !/^0x[0-9a-fA-F]{64}$/.test(process.env.DEPLOYER_PRIVATE_KEY || "")) {
    throw new Error("Isi RPC_URL dan DEPLOYER_PRIVATE_KEY yang valid di .env.");
  }

  const anchor = await ethers.deployContract("BrewAnchor");
  await anchor.waitForDeployment();
  const address = await anchor.getAddress();
  console.log(`Alamat kontrak: ${address}`);
  console.log(`Etherscan Sepolia: https://sepolia.etherscan.io/address/${address}`);
}

main().catch((error: unknown) => {
  // Hanya kode/ringkasan galat; tidak mencetak URL RPC atau kunci.
  const detail = error as { code?: string; shortMessage?: string; message?: string; name?: string };
  const text = (detail?.shortMessage ?? detail?.message ?? "")
    .replace(/https?:\/\/\S+/g, "[url]")
    .replace(/0x[0-9a-fA-F]{64}/g, "[kunci]")
    .slice(0, 300);
  console.error("Deploy gagal. Periksa konfigurasi jaringan dan saldo akun.");
  console.error(`Rincian: ${detail?.code ?? detail?.name ?? "tidak diketahui"}${text ? ` - ${text}` : ""}`);
  process.exitCode = 1;
});
