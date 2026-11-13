// Scol tutor brain: teaches the lesson in the tutor's own words and answers
// the child's questions. Which AIs it uses is set only by server settings, so
// changing model or company never needs a new app. BRAIN_PROVIDERS_B64 is a
// list of {name, base_url, model, fallback_models, extra, key}; they are tried
// in order, so when one is busy or out of free requests the next one answers.
// Limits protect the bill: BRAIN_DEVICE_LIMIT questions per phone per day,
// BRAIN_DAILY_LIMIT for everyone together.
//
// Two jobs, chosen by "mode" in the request:
//   (none)   answer one question about the lesson
//   "teach"  turn a whole lesson into what the tutor says at each teaching
//            step. The result is kept in the brain_teach table, so a lesson is
//            written once per language, tutor and mood and then served to every
//            phone without asking the AI again (free limits last).

type Provider = {
  name: string;
  base_url: string;
  model: string;
  fallback_models?: string[];
  extra?: Record<string, unknown>;
  key: string;
};

type TeachStep = {
  t: string; // say | ask
  text: string;
  visual?: string; // e.g. "groups 3 4 🥭"
  label?: string; // example | story | picture
  form?: string; // choice | number | think | abacus | measure | build
  answer?: string;
  options?: string[];
};

const PROMPT_VERSION = "teach-v2"; // change this when the teaching prompt changes, so old cached lessons are redone

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
const MALAYALAM = /[ഀ-ൿ]/;

const dbHeaders = () => ({
  apikey: env("SUPABASE_SERVICE_ROLE_KEY"),
  authorization: `Bearer ${env("SUPABASE_SERVICE_ROLE_KEY")}`,
  "content-type": "application/json",
});

async function countHit(device: string): Promise<[number, number]> {
  const res = await fetch(`${env("SUPABASE_URL")}/rest/v1/rpc/brain_hit`, {
    method: "POST",
    headers: dbHeaders(),
    body: JSON.stringify({ p_device: device }),
  });
  if (!res.ok) throw new Error(`usage table: ${res.status}`);
  const row = (await res.json())[0] ?? {};
  return [row.device_count ?? 0, row.total_count ?? 0];
}

/** A lesson already written for this language, tutor and mood, or null. */
async function cachedTeaching(key: string): Promise<Taught[] | null> {
  try {
    const res = await fetch(`${env("SUPABASE_URL")}/rest/v1/brain_teach?key=eq.${key}&select=body`, { headers: dbHeaders() });
    if (!res.ok) return null;
    const rows = await res.json();
    const steps = rows?.[0]?.body?.steps;
    if (!Array.isArray(steps) || !steps.length) return null;
    return steps.map((s: unknown) => {
      const o = (s ?? {}) as Record<string, unknown>;
      return typeof s === "string" ? { say: s, touch: [] } : { say: String(o.say ?? ""), touch: Array.isArray(o.touch) ? (o.touch as number[]) : [] };
    });
  } catch {
    return null;
  }
}

async function rememberTeaching(key: string, steps: Taught[], by: string) {
  try {
    await fetch(`${env("SUPABASE_URL")}/rest/v1/brain_teach`, {
      method: "POST",
      headers: { ...dbHeaders(), prefer: "resolution=merge-duplicates" },
      body: JSON.stringify({ key, body: { steps, by, version: PROMPT_VERSION } }),
    });
  } catch (e) {
    console.error("could not save teaching", String(e).slice(0, 200));
  }
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 40);
}

const TONES: Record<string, string> = {
  happy: "Sound cheerful and excited, with lots of encouragement.",
  normal: "Sound warm and friendly.",
  calm: "Sound calm, gentle and patient.",
  strict: "Sound firm and serious like a strict but fair teacher: short sentences, no jokes, still kind and never insulting.",
};

const languageName = (lang: string) => (lang === "ml" ? "Malayalam (Malayalam script)" : "English");

function systemPrompt(tutor: string, lang: string, lesson: string, notes: string, tone: string) {
  return [
    `You are ${tutor}, a tutor inside a learning app for children aged 7 to 9 in Class 3 in Kerala, India.`,
    `The child is on the lesson "${lesson}". What the lesson says:\n${notes}`,
    `Always reply in ${languageName(lang)}, even if the question is in another language, in at most three short, simple sentences a Class 3 child understands.`,
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

/** The picture on the board, in words the AI can point at, with its touchable items numbered. */
function describeVisual(spec: string): string {
  const [kind, ...a] = spec.split(/\s+/);
  const numbered = (items: string[]) => items.map((x, i) => `${i + 1}=${x}`).join(", ");
  switch (kind) {
    case "groups":
      return `${a[0]} groups with ${a[1]} ${a[2] ?? "things"} in each; items: ${numbered(Array.from({ length: Number(a[0]) || 0 }, (_, i) => `group ${i + 1}`))}`;
    case "array":
      return `${a[0]} rows with ${a[1]} ${a[2] ?? "things"} in each row; items: ${numbered(Array.from({ length: Number(a[0]) || 0 }, (_, i) => `row ${i + 1}`))}`;
    case "count":
      return `${a[0]} ${a[1] ?? "things"} in a row; items 1 to ${a[0]} are the ${a[1] ?? "things"} from left to right`;
    case "numberline":
      return `a number line from ${a[0]} to ${a[1]}${a[2] ? ` with ${a[2]} marked` : ""}; items are the numbers on it from left to right`;
    case "shapes": {
      const items: string[] = [];
      a.forEach((sh) => items.push(sh));
      a.forEach((sh) => {
        const corners = sh === "triangle" ? 3 : sh === "circle" ? 0 : 4;
        for (let k = 1; k <= corners; k++) items.push(`corner ${k} of the ${sh}`);
      });
      return `shapes; items: ${numbered(items)}`;
    }
    case "sticks":
      return `${a[0]} small sticks; items 1 to ${a[0]} are the sticks`;
    case "place":
      return `an abacus showing ${a[0]} hundreds, ${a[1]} tens and ${a[2]} ones; items: 1=hundreds rod, 2=tens rod, 3=ones rod`;
    case "notes":
      return `money: ${numbered(a.map((x) => `a ${x} rupee note or coin`))}`;
    case "ruler":
      return `a scale with a ${a[0]} cm ${a[1] ?? "object"} lying on it; items: 1=the ${a[1] ?? "object"}, 2=the scale`;
    case "pattern":
      return `a row of cards: ${numbered(a)} (? is the missing one)`;
    case "split":
      return `the number ${a[0]} split into ${a[1]} and ${a[2]}; items: 1=${a[0]}, 2=${a[1]}, 3=${a[2]}`;
    case "steps":
      return `working shown line by line; items: ${numbered(a.join(" ").split(" / "))}`;
    case "text":
      return `big text: ${a.join(" ")}; item 1 is the text`;
    case "emoji":
    case "picture":
      return a.length ? `pictures; items: ${numbered(a)}` : "a cartoon picture of this step; item 1 is the picture";
    case "image":
      return "a picture; item 1 is the picture";
    default:
      return spec;
  }
}

function teachPrompt(tutor: string, about: string, lang: string, tone: string, sayCount: number) {
  return [
    `You are ${tutor}, a tutor inside a learning app for children aged 7 to 9 in Class 3 in Kerala, India. ${about}`.trim(),
    "You teach one child, one to one, speaking aloud, while floating next to a board. Below is a lesson written and checked by teachers: numbered teaching steps (SAY) and the questions the child will answer afterwards (ASK). Each SAY step has a picture on the board, described in brackets, with its touchable items numbered.",
    "Your job: for each SAY step, write exactly what you say aloud to TEACH that step like a good tutor, never like someone reading a book, and which items on the board you touch while saying it.",
    "Rules for every SAY step:",
    "- Explain the idea in your own words in 2 to 4 short sentences a child of 8 understands. Start from something the child knows from home, school, food or play, then explain.",
    "- Many children find the language itself hard. Use the simplest everyday words, one idea per sentence, and say the key word of the step in two different ways. When you name a thing that is on the board, touch it (see below), so the child understands even if a word is new.",
    "- Keep every fact, every number and every key word from the written step (for example 'equal groups'), so the questions afterwards make sense. Add no new facts, no facts from later steps, and nothing that is not true.",
    "- End with a tiny check or a bridge, such as \"Can you see that?\" or \"Now let us look at...\". Never ask a question that needs an answer: the ASK steps do that.",
    "- Never give away the answers to the ASK questions.",
    "- Do not greet the child or say hello: the app does that before you start. A step marked (example) is a worked example: walk through it slowly.",
    "Touching the board: for each step give \"touch\", the numbers of the board items you float to and touch, in the order you mention them, so your movement matches your words. Count things by touching them one by one (3 groups: touch 1, 2, 3; a triangle's corners: touch its three corners while counting). Name things by touching each as you name it. Give 0 to 8 touches per step; an empty list is fine when nothing on the board is named.",
    `Write only in ${languageName(lang)}. Write numbers as digits.`,
    TONES[tone] ?? TONES.normal,
    "Never describe the app's screen, buttons or colours; never ask for personal details.",
    "Plain text only inside the strings: no lists, no markdown, no emojis, no stage directions, no sentence numbering.",
    `Reply with JSON only, exactly this shape: {"steps": [{"say": "what you say for SAY 1", "touch": [1, 2]}, {"say": "what you say for SAY 2", "touch": []}, ...]} with exactly ${sayCount} items, one per SAY step, in order.`,
  ].join("\n");
}

function teachLessonText(title: string, objective: string, steps: TeachStep[]): string {
  const lines = [`Lesson: ${title}`];
  if (objective) lines.push(`Goal: ${objective}`);
  let say = 0;
  steps.forEach((s, i) => {
    const bits: string[] = [];
    if (s.t === "say") {
      say++;
      bits.push(`SAY ${say}`);
      if (s.label) bits.push(`(${s.label})`);
      if (s.visual) bits.push(`[board: ${describeVisual(s.visual)}]`);
    } else {
      bits.push("ASK");
      bits.push(`(${s.form || "choice"}; answer: ${s.answer ?? ""}${s.options?.length ? `; options: ${s.options.join(" | ")}` : ""})`);
    }
    lines.push(`${i + 1}. ${bits.join(" ")}: ${s.text}`);
  });
  return lines.join("\n");
}

type Taught = { say: string; touch: number[] };

/** Pulls {"steps": [...]} out of whatever the model wrote and checks it is usable. */
function parseTeaching(raw: string, want: number, lang: string): Taught[] {
  const text = raw.replace(/<think>[\s\S]*?<\/think>/g, "");
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) throw new Error("no JSON in answer");
  const data = JSON.parse(text.slice(start, end + 1));
  const list = Array.isArray(data) ? data : data?.steps;
  if (!Array.isArray(list)) throw new Error("no steps in answer");
  const steps: Taught[] = list.map((s: unknown) => {
    const o = (s ?? {}) as Record<string, unknown>;
    const t = typeof s === "string" ? s : String(o.say ?? o.text ?? "");
    const touch = Array.isArray(o.touch)
      ? (o.touch as unknown[]).map((x) => Number(x)).filter((x) => Number.isInteger(x) && x >= 1 && x <= 60).slice(0, 8)
      : [];
    return { say: clip(t, 700).replace(/[*_#`]/g, ""), touch };
  });
  if (steps.length !== want) throw new Error(`wanted ${want} steps, got ${steps.length}`);
  for (const s of steps) {
    if (s.say.length < 15) throw new Error("a step is empty");
    if (lang === "ml" && !MALAYALAM.test(s.say)) throw new Error("a step is not in Malayalam");
    if (lang === "en" && MALAYALAM.test(s.say)) throw new Error("a step is not in English");
  }
  return steps;
}

async function ask(p: Provider, messages: unknown[], maxTokens = 700): Promise<string> {
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
        max_tokens: maxTokens, // room for models that think before answering
        temperature: 0.6,
        messages,
        ...(p.extra ?? {}),
      }),
    });
    if (!res.ok) throw new Error(`${res.status} ${(await res.text()).slice(0, 200)}`);
    const data = await res.json();
    const raw = String(data?.choices?.[0]?.message?.content ?? "");
    if (!raw.trim()) throw new Error("empty answer");
    return raw;
  } finally {
    clearTimeout(timer);
  }
}

/** One question, up to three sentences. */
function answerText(raw: string): string {
  const answer = clip(raw.replace(/<think>[\s\S]*?<\/think>/g, ""), 600).replace(/[*_#`]/g, "");
  if (!answer) throw new Error("empty answer");
  return answer;
}

async function withinLimits(device: string): Promise<Response | null> {
  try {
    const [mine, all] = await countHit(device);
    if (mine > Number(env("BRAIN_DEVICE_LIMIT", "40"))) return reply({ error: "device_limit" }, 429);
    if (all > Number(env("BRAIN_DAILY_LIMIT", "1000"))) return reply({ error: "daily_limit" }, 429);
  } catch (e) {
    console.error(e);
    return reply({ error: "limits_unavailable" }, 503);
  }
  return null;
}

async function teach(body: Record<string, unknown>, device: string, lang: string): Promise<Response> {
  const rawSteps = Array.isArray(body.steps) ? (body.steps as unknown[]).slice(0, 40) : [];
  const steps: TeachStep[] = rawSteps.map((s) => {
    const o = (s ?? {}) as Record<string, unknown>;
    return {
      t: o.t === "ask" ? "ask" : "say",
      text: clip(o.text, 600),
      visual: clip(o.visual, 120) || undefined,
      label: clip(o.label, 20) || undefined,
      form: clip(o.form, 10) || undefined,
      answer: clip(o.answer, 60) || undefined,
      options: Array.isArray(o.options) ? (o.options as unknown[]).slice(0, 8).map((x) => clip(x, 60)) : undefined,
    };
  });
  const sayCount = steps.filter((s) => s.t === "say").length;
  if (!sayCount || steps.some((s) => !s.text)) return reply({ error: "bad_request" }, 400);
  const tutor = clip(body.tutor, 30) || "Mio";
  const about = clip(body.about, 200);
  const tone = TONES[clip(body.tone, 10)] ? clip(body.tone, 10) : "normal";
  const title = clip(body.lesson, 120);
  const objective = clip(body.objective, 200);
  const lessonText = teachLessonText(title, objective, steps);
  const key = await sha256([PROMPT_VERSION, lang, tutor, tone, lessonText].join("\n"));

  const cached = await cachedTeaching(key);
  if (cached && cached.length === sayCount) return reply({ steps: cached, by: "cache" });

  const limited = await withinLimits(device);
  if (limited) return limited;

  const messages = [
    { role: "system", content: teachPrompt(tutor, about, lang, tone, sayCount) },
    { role: "user", content: lessonText },
  ];
  for (const p of providers) {
    try {
      // Malayalam needs many more tokens than English for the same words.
      const written = parseTeaching(await ask(p, messages, lang === "ml" ? 4000 : 2500), sayCount, lang);
      await rememberTeaching(key, written, p.name);
      return reply({ steps: written, by: p.name });
    } catch (e) {
      console.error("teach provider", p.name, String(e).slice(0, 300)); // busy, out of requests or wrote badly: try the next one
    }
  }
  return reply({ error: "all_busy" }, 503);
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
  const device = clip(body.device, 64);
  if (device.length < 8) return reply({ error: "bad_request" }, 400);
  const lang = body.lang === "ml" ? "ml" : "en";

  if (body.mode === "teach") return teach(body, device, lang);

  const question = clip(body.question, 500);
  if (question.length < 2) return reply({ error: "bad_request" }, 400);
  const limited = await withinLimits(device);
  if (limited) return limited;

  const messages = [
    {
      role: "system",
      content: systemPrompt(clip(body.tutor, 30) || "Mio", lang, clip(body.lesson, 120), clip(body.notes, 2500), clip(body.tone, 10)),
    },
    { role: "user", content: question },
  ];
  for (const p of providers) {
    try {
      return reply({ answer: answerText(await ask(p, messages)), by: p.name });
    } catch (e) {
      console.error("provider", p.name, String(e).slice(0, 300)); // busy or out of requests: try the next one
    }
  }
  return reply({ error: "all_busy" }, 503);
});
