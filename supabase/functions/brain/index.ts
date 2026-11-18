// Scol tutor brain: teaches the lesson in the tutor's own words and answers
// the child's questions. Which AIs it uses is set only by server settings, so
// changing model or company never needs a new app. BRAIN_PROVIDERS_B64 is a
// list of {name, base_url, model, fallback_models, extra, key}; they are tried
// in order, so when one is busy or out of free requests the next one answers.
// Limits protect the bill: BRAIN_DEVICE_LIMIT questions per phone per day,
// BRAIN_DAILY_LIMIT for everyone together.
//
// The tutor's rules live in rules.ts and apply to every mode and every AI.
// Jobs, chosen by "mode" in the request:
//   (none)    a live conversation turn: the child's question, with the last few
//             turns ("history") so the talk is two-way, and the lesson notes
//   "teach"   turn a whole lesson into what the tutor says at each teaching
//             step. The result is kept in the brain_teach table, so a lesson is
//             written once per language, tutor and mood and then served to every
//             phone without asking the AI again (free limits last).
//   "report"  read the child's progress aloud as the tutor would tell a parent
//             or the child; the name arrives as {name} and is put back on the phone.
//   "speak"   a line in the character's own Gemini voice. Each line is made once
//             and kept in the public "voices" storage bucket, so every later phone
//             gets the same file at once.
// The Gemini key (BRAIN_GEMINI_KEY) is only on this server, never in the app.
import { charter, languageName, TONES } from "./rules.ts";

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

const PROMPT_VERSION = "teach-v4"; // change this when the teaching prompt changes, so old cached lessons are redone

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
  const res = await fetch(`${env("SUPABASE_URL")}/rest/v1/rpc/brain_hit2`, {
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
      return typeof s === "string"
        ? { say: s, touch: [] }
        : { say: String(o.say ?? ""), touch: Array.isArray(o.touch) ? (o.touch as number[]) : [], at: Array.isArray(o.at) ? (o.at as string[]) : [] };
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

function systemPrompt(tutor: string, about: string, lang: string, lesson: string, notes: string, tone: string, child: string, progress: string) {
  return [
    ...charter(tutor, about, lang, tone),
    child ? `The child's first name is ${child}.` : "",
    lesson ? `The child is on the lesson "${lesson}". What the lesson says:\n${notes}` : "The child is on the home screen, between lessons.",
    progress ? `How the child is doing lately (for you only; mention it when it helps or when asked):\n${progress}` : "",
    "This is a spoken conversation. Answer in at most three short sentences a Class 3 child understands, then, when it fits, one short question back.",
    "If the child asks about a school topic, answer it correctly and simply. If the child just chats, chat warmly for a moment and bring them back to learning.",
  ].filter(Boolean).join("\n");
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

function teachPrompt(tutor: string, about: string, lang: string, tone: string, sayCount: number, variant = 0) {
  return [
    ...charter(tutor, about, lang, tone),
    "You teach one child, one to one, speaking aloud, while floating next to a board. Below is a lesson written and checked by teachers: numbered teaching steps (SAY) and the questions the child will answer afterwards (ASK). Each SAY step has a picture on the board, described in brackets, with its touchable items numbered.",
    "Your job: for each SAY step, write exactly what you say aloud to TEACH that step like a good tutor, never like someone reading a book, and which items on the board you touch while saying it.",
    "Rules for every SAY step:",
    "- 2 to 4 short sentences. Start from something the child knows, then explain the idea in your own words.",
    "- When you name a thing that is on the board, touch it (see below), so the child understands even if a word is new.",
    "- Keep every fact, every number and every key word from the written step (for example 'equal groups'), so the questions afterwards make sense. Add no new facts, no facts from later steps, and nothing that is not true.",
    "- End with a tiny check or a bridge, such as \"Can you see that?\" or \"Now let us look at...\". Never ask a question that needs a real answer: the ASK steps do that.",
    "- Never give away the answers to the ASK questions.",
    "- Do not greet the child or use a name: the app greets by name before you start. A step marked (example) is a worked example: walk through it slowly.",
    "Touching the board: for each step give \"touch\", the board items you float to and touch, in the order you say them, so your movement matches your words exactly. Each touch is {\"item\": number, \"at\": \"the exact word or two from your sentence at the moment you touch it\"}. Count things by touching them one by one, each at its own number word (3 groups: item 1 at \"one\", item 2 at \"two\", item 3 at \"three\"; a triangle's corners: its three corners while counting). Name things by touching each at its name. Give 0 to 8 touches per step; an empty list is fine when nothing on the board is named.",
    variant > 0
      ? `This is explanation number ${variant + 1} of this lesson for a child who may have heard another one before: use different everyday examples, different openings and different wording from a plain first explanation, while keeping every fact.`
      : "",
    `Reply with JSON only, exactly this shape: {"steps": [{"say": "what you say for SAY 1", "touch": [{"item": 1, "at": "one"}, {"item": 2, "at": "two"}]}, {"say": "what you say for SAY 2", "touch": []}, ...]} with exactly ${sayCount} items, one per SAY step, in order.`,
  ].filter(Boolean).join("\n");
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

type Taught = { say: string; touch: number[]; at?: string[] };

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
    const touch: number[] = [];
    const at: string[] = [];
    for (const x of Array.isArray(o.touch) ? (o.touch as unknown[]) : []) {
      const item = typeof x === "object" && x ? Number((x as Record<string, unknown>).item) : Number(x);
      if (!Number.isInteger(item) || item < 1 || item > 60 || touch.length >= 8) continue;
      touch.push(item);
      at.push(typeof x === "object" && x ? clip((x as Record<string, unknown>).at, 40) : "");
    }
    return { say: clip(t, 700).replace(/[*_#`]/g, ""), touch, at };
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
  const answer = clip(raw.replace(/<think>[\s\S]*?<\/think>/g, ""), 900).replace(/[*_#`]/g, "");
  if (!answer) throw new Error("empty answer");
  return answer;
}

/** The pre-warm workflow fills the caches for every child; it is not held to a phone's daily limits. */
let prewarm = false;

async function withinLimits(device: string, kind = ""): Promise<Response | null> {
  if (prewarm) return null;
  // Voices are counted apart from questions: one lesson needs many lines.
  const [deviceLimit, dailyLimit] = kind === "tts"
    ? [Number(env("BRAIN_TTS_DEVICE_LIMIT", "400")), Number(env("BRAIN_TTS_DAILY_LIMIT", "8000"))]
    : kind === "live"
    ? [30, 600] // live talks per phone and for everyone, per day
    : [Number(env("BRAIN_DEVICE_LIMIT", "40")), Number(env("BRAIN_DAILY_LIMIT", "1000"))];
  try {
    const [mine, all] = await countHit(kind ? `${kind}:${device}` : device);
    if (mine > deviceLimit) return reply({ error: "device_limit" }, 429);
    if (all > dailyLimit) return reply({ error: "daily_limit" }, 429);
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
  const variant = Math.max(0, Math.min(2, Math.floor(Number(body.variant) || 0)));
  const key = await sha256([PROMPT_VERSION, lang, tutor, tone, `v${variant}`, lessonText].join("\n"));

  const cached = await cachedTeaching(key);
  if (cached && cached.length === sayCount) return reply({ steps: cached, by: "cache" });

  const limited = await withinLimits(device);
  if (limited) return limited;

  const messages = [
    { role: "system", content: teachPrompt(tutor, about, lang, tone, sayCount, variant) },
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

  prewarm = !!env("PREWARM_TOKEN") && req.headers.get("x-scol-prewarm") === env("PREWARM_TOKEN");
  if (body.mode === "speak") return speak(body, device, lang);
  if (body.mode === "live") return liveToken(body, device, lang);
  if (body.mode === "teach") return teach(body, device, lang);
  if (body.mode === "report") return report(body, device, lang);

  const question = clip(body.question, 500);
  if (question.length < 2) return reply({ error: "bad_request" }, 400);
  const limited = await withinLimits(device);
  if (limited) return limited;

  // The last few turns of this conversation, oldest first: [question, answer] pairs.
  const history = Array.isArray(body.history)
    ? (body.history as unknown[]).slice(-6).flatMap((h) => {
        const pair = Array.isArray(h) ? h : [];
        const q = clip(pair[0], 400);
        const a = clip(pair[1], 600);
        return q && a ? [{ role: "user", content: q }, { role: "assistant", content: a }] : [];
      })
    : [];
  const messages = [
    {
      role: "system",
      content: systemPrompt(clip(body.tutor, 30) || "Mio", clip(body.about, 200), lang, clip(body.lesson, 120), clip(body.notes, 2500),
        clip(body.tone, 10), clip(body.child, 30), clip(body.progress, 1200)),
    },
    ...history,
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

/** The child's progress, told aloud the way the tutor would tell it. The name arrives as {name}. */
async function report(body: Record<string, unknown>, device: string, lang: string): Promise<Response> {
  const facts = clip(body.report, 2500);
  if (facts.length < 10) return reply({ error: "bad_request" }, 400);
  const tutor = clip(body.tutor, 30) || "Mio";
  const about = clip(body.about, 200);
  const tone = TONES[clip(body.tone, 10)] ? clip(body.tone, 10) : "normal";
  const listener = body.listener === "child" ? "child" : "parent";
  const key = await sha256(["report-v1", lang, tutor, tone, listener, facts].join("\n"));
  const cached = await cachedTeaching(key);
  if (cached && cached.length === 1) return reply({ answer: cached[0].say, by: "cache" });
  const limited = await withinLimits(device);
  if (limited) return limited;
  const messages = [
    {
      role: "system",
      content: [
        ...charter(tutor, about, lang, tone),
        listener === "child"
          ? "You are telling the child, warmly and honestly, how their learning is going: what they are good at now, what you will practise together, and one small encouraging next step. Four to six short sentences. Use {name} where you would say the child's name (the app fills it in); use it once or twice."
          : "You are telling the child's parent, in a friendly spoken way, how their child's learning is going this week: time and levels, what is understood, what needs practice and why, what helps this child learn, and one practical thing to try at home. Five to eight short sentences, no lists. Use {name} for the child's name (the app fills it in).",
        "Use only the facts below; do not invent numbers or topics. Keep every number as it is.",
      ].join("\n"),
    },
    { role: "user", content: facts },
  ];
  for (const p of providers) {
    try {
      const said = answerText(await ask(p, messages, 900));
      if (lang === "ml" && !MALAYALAM.test(said)) throw new Error("not Malayalam");
      await rememberTeaching(key, [{ say: said, touch: [] }], p.name);
      return reply({ answer: said, by: p.name });
    } catch (e) {
      console.error("report provider", p.name, String(e).slice(0, 300));
    }
  }
  return reply({ error: "all_busy" }, 503);
}


// ---------------- Voices ----------------

/** Gemini's prebuilt voices a character may use. */
const VOICES = new Set([
  "Zephyr", "Puck", "Charon", "Kore", "Fenrir", "Leda", "Orus", "Aoede", "Callirrhoe", "Autonoe", "Enceladus", "Iapetus",
  "Umbriel", "Algieba", "Despina", "Erinome", "Algenib", "Rasalgethi", "Laomedeia", "Achernar", "Alnilam", "Schedar",
  "Gacrux", "Pulcherrima", "Achird", "Zubenelgenubi", "Vindemiatrix", "Sadachbia", "Sadaltager", "Sulafat",
]);
const TTS_MODELS = (env("BRAIN_TTS_MODELS") ||
  "gemini-3.8-flash-tts,gemini-3.8-flash-lite-tts,gemini-3.1-flash-tts-preview,gemini-2.5-flash-preview-tts,gemini-2.5-pro-preview-tts")
  .split(",").map((m) => m.trim()).filter(Boolean);
let ttsModel = 0; // moves on when a model name is not offered any more

/** 16-bit mono PCM to a WAV file. */
function wav(pcm: Uint8Array, rate: number): Uint8Array {
  const out = new Uint8Array(44 + pcm.length);
  const v = new DataView(out.buffer);
  const text = (o: number, t: string) => [...t].forEach((c, i) => v.setUint8(o + i, c.charCodeAt(0)));
  text(0, "RIFF"); v.setUint32(4, 36 + pcm.length, true); text(8, "WAVE");
  text(12, "fmt "); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
  v.setUint32(24, rate, true); v.setUint32(28, rate * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true);
  text(36, "data"); v.setUint32(40, pcm.length, true);
  out.set(pcm, 44);
  return out;
}

/**
 * Cleans a spoken line before it is kept: cuts a short burst of noise that speech models sometimes add after the
 * last word (a sound of under 0.35 s that comes after at least 0.3 s of silence at the very end), trims the
 * silence at both ends, and fades in and out so the line never starts or stops on a click.
 */
function cleanSpeech(pcm: Uint8Array, rate: number): Uint8Array {
  const n = pcm.length >> 1;
  if (n === 0) return pcm;
  const v = new DataView(pcm.buffer, pcm.byteOffset, pcm.byteLength);
  const win = Math.max(1, Math.floor(rate / 50)); // 20 ms
  const loud: boolean[] = [];
  for (let i = 0; i < n; i += win) {
    let sum = 0;
    const end = Math.min(n, i + win);
    for (let j = i; j < end; j++) {
      const x = v.getInt16(j * 2, true);
      sum += x * x;
    }
    loud.push(Math.sqrt(sum / (end - i)) > 450);
  }
  let last = loud.lastIndexOf(true);
  if (last < 0) return new Uint8Array(0);
  // the final sound run, and the silence before it
  let runStart = last;
  while (runStart > 0 && loud[runStart - 1]) runStart--;
  let gapStart = runStart;
  while (gapStart > 0 && !loud[gapStart - 1]) gapStart--;
  const runMs = (last - runStart + 1) * 20;
  const gapMs = (runStart - gapStart) * 20;
  if (gapStart > 0 && runMs < 350 && gapMs >= 300) last = gapStart - 1; // drop the stray burst
  const first = loud.indexOf(true);
  const from = Math.max(0, first * win - Math.floor(rate * 0.03));
  const to = Math.min(n, (last + 1) * win + Math.floor(rate * 0.08));
  const out = new Uint8Array((to - from) * 2);
  const o = new DataView(out.buffer);
  const fadeIn = Math.floor(rate * 0.01);
  const fadeOut = Math.floor(rate * 0.06);
  const len = to - from;
  for (let i = 0; i < len; i++) {
    let x = v.getInt16((from + i) * 2, true);
    if (i < fadeIn) x = Math.round((x * i) / fadeIn);
    if (i > len - fadeOut) x = Math.round((x * (len - i)) / fadeOut);
    o.setInt16(i * 2, x, true);
  }
  return out;
}

function fromBase64(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function geminiSpeech(text: string, voice: string, style: string): Promise<Uint8Array> {
  const key = env("BRAIN_GEMINI_KEY");
  if (!key) throw new Error("no Gemini key on the server");
  let lastError = "";
  for (let attempt = 0; attempt < TTS_MODELS.length; attempt++) {
    const model = TTS_MODELS[(ttsModel + attempt) % TTS_MODELS.length];
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: "POST",
      headers: { "x-goog-api-key": key, "content-type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: style ? `Say this as ${style}: ${text}` : text }] }],
        generationConfig: {
          responseModalities: ["AUDIO"],
          speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: voice } } },
        },
      }),
    });
    if (res.status === 404 || res.status === 400 || res.status === 429 || res.status === 503) {
      lastError = `${model}: ${res.status} ${(await res.text()).slice(0, 160)}`;
      continue; // not offered, out of quota or busy: each model has its own quota, so try the next one
    }
    if (!res.ok) throw new Error(`${model}: ${res.status} ${(await res.text()).slice(0, 200)}`);
    const data = await res.json();
    const part = (data?.candidates?.[0]?.content?.parts ?? []).find((p: Record<string, unknown>) => p.inlineData);
    const b64 = part?.inlineData?.data;
    if (!b64) throw new Error(`${model}: no audio`);
    ttsModel = (ttsModel + attempt) % TTS_MODELS.length;
    const rate = Number(/rate=(\d+)/.exec(String(part.inlineData.mimeType ?? ""))?.[1] ?? 24000);
    return wav(cleanSpeech(fromBase64(b64), rate), rate);
  }
  throw new Error(lastError || "no speech model answered");
}

const voiceUrl = (path: string) => `${env("SUPABASE_URL")}/storage/v1/object/public/voices/${path}`;

async function speak(body: Record<string, unknown>, device: string, lang: string): Promise<Response> {
  const text = clip(body.text, 700);
  const voice = clip(body.voice, 30);
  const style = clip(body.style, 160);
  if (text.length < 1 || !VOICES.has(voice)) return reply({ error: "bad_request" }, 400);
  const path = `g2/${voice}/${await sha256([voice, style, lang, text].join("|"))}.wav`;
  // Already made for someone: hand out the same file.
  try {
    const head = await fetch(voiceUrl(path), { method: "HEAD" });
    if (head.ok) return reply({ url: voiceUrl(path), by: "cache" });
  } catch { /* storage not reachable: make it */ }
  const limited = await withinLimits(device, "tts");
  if (limited) return limited;
  try {
    const audio = await geminiSpeech(text, voice, style);
    const up = await fetch(`${env("SUPABASE_URL")}/storage/v1/object/voices/${path}`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${env("SUPABASE_SERVICE_ROLE_KEY")}`,
        apikey: env("SUPABASE_SERVICE_ROLE_KEY"),
        "content-type": "audio/wav",
        "x-upsert": "true",
        "cache-control": "31536000",
      },
      body: audio,
    });
    if (!up.ok) console.error("voice upload", up.status, (await up.text()).slice(0, 200));
    return reply({ url: voiceUrl(path), by: "gemini" });
  } catch (e) {
    console.error("speak", String(e).slice(0, 300));
    return reply({ error: "voice_unavailable" }, 503);
  }
}


// ---------------- Gemini Live ----------------

const LIVE_MODEL = () => env("BRAIN_LIVE_MODEL") || "models/gemini-2.5-flash-native-audio-preview-12-2025";

/**
 * A one-use pass for a Gemini Live session (an "ephemeral token"): the phone talks to Gemini Live directly, with
 * this pass instead of the key. It must be used within two minutes and the session ends within half an hour.
 */
async function liveToken(body: Record<string, unknown>, device: string, lang: string): Promise<Response> {
  const key = env("BRAIN_GEMINI_KEY");
  if (!key) return reply({ error: "not_configured" }, 503);
  const limited = await withinLimits(device, "live");
  if (limited) return limited;
  const now = Date.now();
  try {
    const res = await fetch("https://generativelanguage.googleapis.com/v1alpha/auth_tokens", {
      method: "POST",
      headers: { "x-goog-api-key": key, "content-type": "application/json" },
      body: JSON.stringify({
        uses: 1,
        expireTime: new Date(now + 30 * 60 * 1000).toISOString(),
        newSessionExpireTime: new Date(now + 2 * 60 * 1000).toISOString(),
      }),
    });
    if (!res.ok) {
      console.error("live token", res.status, (await res.text()).slice(0, 300));
      return reply({ error: "live_unavailable" }, 503);
    }
    const data = await res.json();
    const token = String(data?.name ?? "");
    if (!token) return reply({ error: "live_unavailable" }, 503);
    const tone = TONES[clip(body.tone, 10)] ? clip(body.tone, 10) : "normal";
    return reply({
      token,
      model: LIVE_MODEL(),
      // the tutor's charter, the same rules as every other mode; the phone adds the lesson and the child's name
      rules: [
        ...charter(clip(body.tutor, 30) || "Mio", clip(body.about, 200), lang, tone),
        "This is a live spoken conversation. Keep every turn to one to three short sentences, then let the child talk.",
        "If the child is quiet, gently ask one simple question about the lesson. If the child goes off the lesson, answer kindly in one sentence and bring them back.",
      ].join("\n"),
      url: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContentConstrained",
    });
  } catch (e) {
    console.error("live token", String(e).slice(0, 300));
    return reply({ error: "live_unavailable" }, 503);
  }
}
