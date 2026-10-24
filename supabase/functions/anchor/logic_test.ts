import { canAnchor, headHashBytes32, reservationExpired, retryAfterSeconds, userKey } from "./logic.ts";

function assert(condition: boolean): void {
  if (!condition) throw new Error("Assertion failed");
}

function assertEquals(actual: unknown, expected: unknown): void {
  assert(actual === expected);
}

function assertThrows(fn: () => unknown): void {
  let threw = false;
  try { fn(); } catch { threw = true; }
  assert(threw);
}

Deno.test("userKey cocok dengan vektor ethers Node", () => {
  assertEquals(userKey("123E4567-E89B-42D3-A456-426614174000"),
    "0xe4cee370379109bb1e94703056146bb95e06df579de2ee6f2af9f719e849b5c5");
  assertThrows(() => userKey("bukan-uuid"));
});

Deno.test("hash kepala dipetakan ke bytes32 tanpa mengubah nilainya", () => {
  assertEquals(headHashBytes32("ab".repeat(32)), `0x${"ab".repeat(32)}`);
  assertThrows(() => headHashBytes32("0x" + "ab".repeat(32)));
  assertThrows(() => headHashBytes32("0".repeat(64)));
  assertThrows(() => headHashBytes32("AA".repeat(32)));
});

Deno.test("seq hanya boleh naik dari nilai on-chain", () => {
  assert(canAnchor(1n, 0n));
  assert(canAnchor(3n, 2n));
  assert(!canAnchor(3n, 3n));
  assert(!canAnchor(2n, 3n));
});

Deno.test("batas lima menit dan reservasi sepuluh menit", () => {
  const start = "2026-10-24T00:00:00.000Z";
  const now = Date.parse(start);
  assertEquals(retryAfterSeconds(start, now), 300);
  assertEquals(retryAfterSeconds(start, now + 299_001), 1);
  assertEquals(retryAfterSeconds(start, now + 300_000), 0);
  assert(!reservationExpired(start, now + 599_999));
  assert(reservationExpired(start, now + 600_000));
});
