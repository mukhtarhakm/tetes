Deno.serve(() => {
  return new Response(
    JSON.stringify({ ok: true, message: "hello dari Tetes" }),
    { headers: { "Content-Type": "application/json" } },
  );
});