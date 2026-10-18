import {
  base64ToBytes,
  bytesToBase64,
  constantTimeEquals,
  createSalt,
  createSessionToken,
  derivePasswordHash,
  hashSessionToken,
  PASSWORD_HASH_BYTES,
  PBKDF2_ITERATIONS,
  SALT_BYTES,
  validateRegistrationInput,
} from "./auth.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

Deno.test("validasi register menerima dan menolak batas input", () => {
  assert(
    validateRegistrationInput({
      username: "rais_uji",
      password: "rahasia123",
    }).valid,
    "Input valid harus diterima.",
  );
  assert(
    !validateRegistrationInput({ username: "RAIS", password: "rahasia123" })
      .valid,
    "Username huruf besar harus ditolak.",
  );
  assert(
    !validateRegistrationInput({ username: "rais", password: "pendek" }).valid,
    "Password pendek harus ditolak.",
  );
  assert(
    !validateRegistrationInput({ username: "rais", password: "a".repeat(129) })
      .valid,
    "Password di atas 128 karakter harus ditolak.",
  );
});

Deno.test("PBKDF2 menghasilkan hash 32 byte dan salt 16 byte", async () => {
  const salt = createSalt();
  const hash = await derivePasswordHash("rahasia123", salt);

  assert(salt.length === SALT_BYTES, "Panjang salt harus 16 byte.");
  assert(hash.length === PASSWORD_HASH_BYTES, "Panjang hash harus 32 byte.");
  assert(atob(bytesToBase64(salt)).length === SALT_BYTES, "Salt base64 tidak valid.");
  assert(
    atob(bytesToBase64(hash)).length === PASSWORD_HASH_BYTES,
    "Hash base64 tidak valid.",
  );
  assert(PBKDF2_ITERATIONS === 600_000, "Jumlah iterasi tidak sesuai keputusan.");
});

Deno.test("session token memakai 32 byte base64url dan hash SHA-256", async () => {
  const token = createSessionToken();
  const tokenHash = await hashSessionToken(token);

  assert(/^[A-Za-z0-9_-]{43}$/u.test(token), "Format token session tidak valid.");
  assert(/^[a-f0-9]{64}$/u.test(tokenHash), "Hash token session tidak valid.");
});

Deno.test("base64 dapat dibaca ulang dan hash dibandingkan waktu-konstan", () => {
  const bytes = new Uint8Array([0, 1, 127, 255]);
  const decoded = base64ToBytes(bytesToBase64(bytes));

  assert(constantTimeEquals(bytes, decoded), "Hasil decode harus sama.");
  assert(
    !constantTimeEquals(bytes, new Uint8Array([0, 1, 127, 254])),
    "Byte berbeda harus ditolak.",
  );
  assert(
    !constantTimeEquals(bytes, new Uint8Array([0, 1, 127])),
    "Panjang berbeda harus ditolak.",
  );
});
