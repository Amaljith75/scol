// Scol tutor brain: answers a child's question about the lesson they are on.
// The AI provider is set only by server settings (secrets), so changing model
// or company never needs a new app:
//   BRAIN_API_KEY   the provider's key
//   BRAIN_BASE_URL  an OpenAI-compatible address, e.g. https://api.moonshot.ai/v1
//   BRAIN_MODEL     e.g. kimi-k2.6
// Limits protect the bill: BRAIN_DEVICE_LIMIT questions per phone per day,
// BRAIN_DAILY_LIMIT for everyone together.

const env = (k: string, d = "") => Deno.env.get(k) ?? d;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "content-type": "application/json" } });

const clip = (v: unknown, n: number) => String(v ?? "").replace(/\s+/g, " ").trim().slice(0, n);

async function countHit(device: string): Promise<[number, number]> {
  const res = await fetch(`${env("SUPABASE_URL")}/rest/v1/rpc/brain_hit`, {
    method: "POST",
    headers: {
      apikey: env("SUPABASE_SERVICE_ROLE_KEY"),
      authorization: `Bearer ${env("SUPABASE_SERVICE_ROLE_KEY")}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ p_device: device }),
  });
  if (!res.ok) throw new Error(`usage table: ${res.status}`);
  const row = (await res.json())[0] ?? {};
  return [row.device_count ?? 0, row.total_count ?? 0];
}

function systemPrompt(tutor: string, lang: string, lesson: string, notes: string) {
  const language = lang === "ml" ? "Malayalam" : "English";
  return [
    `You are ${tutor}, a kind tutor inside a learning app for children aged 7 to 9 in Class 3 in Kerala, India.`,
    `The child is on the lesson "${lesson}". What the lesson says:\n${notes}`,
    `Answer the child's question in ${language}, in at most three short, simple sentences a Class 3 child understands.`,
    "Use everyday examples from a child's life in Kerala. Be warm and encouraging.",
    "If the question is about a school topic, answer it correctly; if you are not sure, say so and suggest asking a teacher.",
    "Never describe the app's screen, buttons or colours; you cannot see them.",
    "Never ask for or repeat personal details (name, address, school, phone, photos).",
    "If the question is unsafe, scary, rude, or not suitable for a young child, do not answer it; gently suggest talking to a parent or teacher and bring the child back to the lesson.",
    "Plain text only: no lists, no markdown, no emojis.",
  ].join("\n");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return reply("ok");
  if (req.method !== "POST") return reply({ error: "POST only" }, 405);
  if (!env("BRAIN_API_KEY")) return reply({ error: "not_configured" }, 503);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return reply({ error: "bad_request" }, 400);
  }
  const question = clip(body.question, 300);
  const device = clip(body.device, 64);
  if (question.length < 2 || device.length < 8) return reply({ error: "bad_request" }, 400);
  const lang = body.lang === "ml" ? "ml" : "en";

  try {
    const [mine, all] = await countHit(device);
    if (mine > Number(env("BRAIN_DEVICE_LIMIT", "40"))) return reply({ error: "device_limit" }, 429);
    if (all > Number(env("BRAIN_DAILY_LIMIT", "1500"))) return reply({ error: "daily_limit" }, 429);
  } catch (e) {
    console.error(e);
    return reply({ error: "limits_unavailable" }, 503);
  }

  const res = await fetch(`${env("BRAIN_BASE_URL", "https://api.moonshot.ai/v1").replace(/\/$/, "")}/chat/completions`, {
    method: "POST",
    headers: { authorization: `Bearer ${env("BRAIN_API_KEY")}`, "content-type": "application/json" },
    body: JSON.stringify({
      model: env("BRAIN_MODEL", "kimi-k3"),
      max_tokens: 220,
      temperature: 0.6,
      messages: [
        { role: "system", content: systemPrompt(clip(body.tutor, 30) || "Mio", lang, clip(body.lesson, 120), clip(body.notes, 2500)) },
        { role: "user", content: question },
      ],
    }),
  });
  if (!res.ok) {
    console.error("provider", res.status, (await res.text()).slice(0, 300));
    return reply({ error: "provider_error" }, 502);
  }
  const data = await res.json();
  const answer = clip(data?.choices?.[0]?.message?.content, 600).replace(/[*_#`]/g, "");
  if (!answer) return reply({ error: "empty_answer" }, 502);
  return reply({ answer });
});
