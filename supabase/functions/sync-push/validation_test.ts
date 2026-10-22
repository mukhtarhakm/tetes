import { validateEvent, validateFeedback, validateScore } from "./validation.ts";

function assert(value: boolean, message: string): void {
  if (!value) throw new Error(message);
}

const now = Date.parse("2026-10-22T10:00:00Z");
const id = "11111111-1111-4111-8111-111111111111";
const event = {
  id, name: "Workshop", event_type: "workshop", location: null, notes: null,
  start_utc: "2026-10-22T10:00:00Z", source_zone: "Asia/Jakarta",
  reminder_minutes: "30", deleted: false, created_at: "2026-10-22T09:00:00Z",
  updated_at: "2026-10-22T09:00:00Z",
};

Deno.test("event UTC, zona, batas waktu dan panjang divalidasi per baris", () => {
  assert(validateEvent(event, now), "event valid ditolak");
  assert(validateEvent({ ...event, start_utc: "2026-10-23T10:00:00Z" }, now), "event besok ditolak");
  assert(!validateEvent({ ...event, source_zone: "GMT+7" }, now), "zona invalid diterima");
  assert(!validateEvent({ ...event, start_utc: "2032-10-22T10:00:00Z" }, now), "event terlalu jauh diterima");
  assert(!validateEvent({ ...event, updated_at: "2026-10-22T11:00:00Z" }, now), "updated_at satu jam ke depan diterima");
  assert(!validateEvent({ ...event, notes: "x".repeat(501) }, now), "teks panjang diterima");
});

Deno.test("skor dan feedback menerima data valid dan menolak perubahan batas", () => {
  const score = { id, level: 1, accuracy: 0.8, stars: 2, duration_s: 20,
    played_at: "2026-10-22T09:00:00Z" };
  assert(validateScore(score, now), "skor valid ditolak");
  assert(!validateScore({ ...score, accuracy: 1.1 }, now), "akurasi invalid diterima");
  assert(!validateScore({ ...score, stars: 4 }, now), "bintang invalid diterima");
  assert(!validateScore({ ...score, stars: 3 }, now), "bintang tidak sesuai akurasi diterima");
  assert(!validateScore({ ...score, duration_s: 31 }, now), "durasi level berlebih diterima");
  const feedback = { id, suggestion: "Bagus", impression: null, created_at: "2026-10-22T09:00:00Z" };
  assert(validateFeedback(feedback, now), "feedback valid ditolak");
  assert(!validateFeedback({ ...feedback, suggestion: "x".repeat(501) }, now), "feedback panjang diterima");
  assert(!validateFeedback({ ...feedback, suggestion: " " }, now), "feedback kosong diterima");
});
