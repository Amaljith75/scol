// Scol tutor brain: explains the lesson and answers the child's questions.
// Which AIs it uses is set only by server settings, so changing model or
// company never needs a new app. BRAIN_PROVIDERS_B64 is a list of
// {name, base_url, model, fallback_models, extra, key}; they are tried in order,
// so when one is busy or out of free requests the next one answers.
// Limits protect the bill: BRAIN_DEVICE_LIMIT questions per phone per day,
// BRAIN_DAILY_LIMIT for everyone together.

type Provider = {
  name: string;
  base_url: string;
  model: string;
  fallback_models?: string[];
  extra?: Record<string, unknown>;
  key: string;
};

const env = (k: string, d = "") => Deno.env.get(k) ?? d;
const providers: Provider[] = (() => {
  try {
    return JSON.parse(atob(env("BRAIN_PROVIDERS_B64")));
  } catch {
    return [];
  }
})();
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

const TONES: Record<string, string> = {
  happy: "Sound cheerful and excited, with lots of encouragement.",
  normal: "Sound warm and friendly.",
  calm: "Sound calm, gentle and patient.",
  strict: "Sound firm and serious like a strict but fair teacher: short sentences, no jokes, still kind and never insulting.",
};

function systemPrompt(tutor: string, lang: string, lesson: string, notes: string, tone: string) {
  const language = lang === "ml" ? "Malayalam (Malayalam script)" : "English";
  return [
    `You are ${tutor}, a tutor inside a learning app for children aged 7 to 9 in Class 3 in Kerala, India.`,
    `The child is on the lesson "${lesson}". What the lesson says:\n${notes}`,
    `Always reply in ${language}, even if the question is in another language, in at most three short, simple sentences a Class 3 child understands.`,
    TONES[tone] ?? TONES.normal,
    "Use simple everyday examples a child knows (home, school, food, play). Every example must be true: do not invent details about festivals, places or customs.",
    "Stay close to what the lesson says; do not add new facts that the lesson does not need.",
    "If the question is about a school topic, answer it correctly; if you are not sure, say so and suggest asking a teacher.",
    "Never describe the app's screen, buttons or colours; you cannot see them.",
    "Never ask for or repeat personal details (name, address, school, phone, photos).",
    "If the question is unsafe, scary, rude, or not suitable for a young child, do not answer it; gently suggest talking to a parent or teacher and bring the child back to the lesson.",
    "Plain text only: no lists, no markdown, no emojis.",
  ].join("\n");
}

async function ask(p: Provider, messages: unknown[]): Promise<string> {
  const models = [p.model, ...(p.fallback_models ?? [])];
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 25000);
  try {
    const res = await fetch(`${p.base_url.replace(/\/$/, "")}/chat/completions`, {
      method: "POST",
      signal: ctrl.signal,
      headers: { authorization: `Bearer ${p.key}`, "content-type": "application/json" },
      body: JSON.stringify({
        model: p.model,
        ...(models.length > 1 ? { models } : {}),
        max_tokens: 700, // room for models that think before answering
        temperature: 0.6,
        messages,
        ...(p.extra ?? {}),
      }),
    });
    if (!res.ok) throw new Error(`${res.status} ${(await res.text()).slice(0, 200)}`);
    const data = await res.json();
    const raw = String(data?.choices?.[0]?.message?.content ?? "").replace(/<think>[\s\S]*?<\/think>/g, "");
    const answer = clip(raw, 600).replace(/[*_#`]/g, "");
    if (!answer) throw new Error("empty answer");
    return answer;
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return reply("ok");
  if (req.method !== "POST") return reply({ error: "POST only" }, 405);
  if (!providers.length) return reply({ error: "not_configured" }, 503);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return reply({ error: "bad_request" }, 400);
  }
  const question = clip(body.question, 500);
  const device = clip(body.device, 64);
  if (question.length < 2 || device.length < 8) return reply({ error: "bad_request" }, 400);
  const lang = body.lang === "ml" ? "ml" : "en";

  try {
    const [mine, all] = await countHit(device);
    if (mine > Number(env("BRAIN_DEVICE_LIMIT", "40"))) return reply({ error: "device_limit" }, 429);
    if (all > Number(env("BRAIN_DAILY_LIMIT", "1000"))) return reply({ error: "daily_limit" }, 429);
  } catch (e) {
    console.error(e);
    return reply({ error: "limits_unavailable" }, 503);
  }

  const messages = [
    {
      role: "system",
      content: systemPrompt(clip(body.tutor, 30) || "Mio", lang, clip(body.lesson, 120), clip(body.notes, 2500), clip(body.tone, 10)),
    },
    { role: "user", content: question },
  ];
  for (const p of providers) {
    try {
      return reply({ answer: await ask(p, messages), by: p.name });
    } catch (e) {
      console.error("provider", p.name, String(e).slice(0, 300)); // busy or out of requests: try the next one
    }
  }
  return reply({ error: "all_busy" }, 503);
});
