export const PBKDF2_ITERATIONS = 600_000;
export const PASSWORD_ALGORITHM = "pbkdf2-hmac-sha256";
export const SALT_BYTES = 16;
export const PASSWORD_HASH_BYTES = 32;
export const SESSION_TOKEN_BYTES = 32;
export const SESSION_DURATION_MS = 7 * 24 * 60 * 60 * 1000;

const encoder = new TextEncoder();
const usernamePattern = /^[a-z0-9._]{3,30}$/;

export type RegistrationInput = {
  username: string;
  password: string;
};

export type RegistrationValidation =
  | { valid: true; input: RegistrationInput }
  | {
    valid: false;
    fields: Record<string, string>;
  };

export function validateRegistrationInput(value: unknown): RegistrationValidation {
  const fields: Record<string, string> = {};
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return {
      valid: false,
      fields: { request: "Body harus berupa objek JSON." },
    };
  }

  const body = value as Record<string, unknown>;
  const username = body.username;
  const password = body.password;

  if (typeof username !== "string" || !usernamePattern.test(username)) {
    fields.username =
      "Username harus 3-30 karakter dan hanya berisi huruf kecil, angka, titik, atau garis bawah.";
  }

  if (typeof password !== "string") {
    fields.password = "Password wajib diisi.";
  } else {
    const passwordLength = [...password].length;
    if (passwordLength < 8) {
      fields.password = "Password minimal 8 karakter.";
    } else if (passwordLength > 128) {
      fields.password = "Password maksimal 128 karakter.";
    }
  }

  if (Object.keys(fields).length > 0) {
    return { valid: false, fields };
  }

  return {
    valid: true,
    input: {
      username: username as string,
      password: password as string,
    },
  };
}

export function createSalt(): Uint8Array {
  return crypto.getRandomValues(new Uint8Array(SALT_BYTES));
}

export async function derivePasswordHash(
  password: string,
  salt: Uint8Array,
  iterations = PBKDF2_ITERATIONS,
): Promise<Uint8Array> {
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    encoder.encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      hash: "SHA-256",
      salt,
      iterations,
    },
    keyMaterial,
    PASSWORD_HASH_BYTES * 8,
  );
  return new Uint8Array(bits);
}

export function createSessionToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(SESSION_TOKEN_BYTES));
  return bytesToBase64(bytes)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/u, "");
}

export async function hashSessionToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(token));
  return bytesToHex(new Uint8Array(digest));
}

export function bytesToBase64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes));
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}
