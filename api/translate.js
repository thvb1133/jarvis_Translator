// Vercel serverless function: server-side translation proxy.
//
// Keeps any API key OFF the client. The Flutter web app posts
// { text, target, source, provider } here and receives { translation }.
//
// Works with ZERO configuration: if no key is set (or the "free" provider is
// requested) it uses a free, key-free translation endpoint server-side.
//
// Optional keys (Vercel → Project → Settings → Environment Variables) unlock the
// higher-quality paid providers:
//   OPENAI_API_KEY      (for the OpenAI translator)
//   ANTHROPIC_API_KEY   (for the Claude translator)

const LANG_NAMES = {
  gu: 'Gujarati', hi: 'Hindi', en: 'English', ar: 'Arabic',
  fr: 'French', es: 'Spanish', ko: 'Korean', ja: 'Japanese',
};

// Take the first whitespace-delimited token so a stray newline / double-paste
// in an env var can never produce an invalid header value.
function cleanKey(value) {
  return (value || '').trim().split(/\s+/)[0] || '';
}

// Never leak a key in an error message.
function redact(text) {
  return String(text).replace(/sk-[A-Za-z0-9._-]+/g, 'sk-***');
}

function languageName(code) {
  if (!code || code === 'auto') return 'the detected language';
  return LANG_NAMES[code] || code;
}

function systemPrompt(source, target) {
  return (
    'You are a professional live interpreter. Translate the user message from ' +
    languageName(source) + ' into ' + languageName(target) + '. Preserve ' +
    'meaning, tone and names. Respond with ONLY the translation, no quotes, ' +
    'no notes.'
  );
}

// Free, key-free translation via a public Google endpoint. Runs server-side so
// there is no browser CORS issue and no API key or payment is required.
async function translateFree({ text, source, target }) {
  const sl = !source || source === 'auto' ? 'auto' : source;
  const url =
    'https://translate.googleapis.com/translate_a/single?client=gtx&sl=' +
    encodeURIComponent(sl) +
    '&tl=' +
    encodeURIComponent(target) +
    '&dt=t&q=' +
    encodeURIComponent(text);

  const res = await fetch(url);
  if (!res.ok) {
    throw new Error('Free translation error ' + res.status);
  }
  const data = await res.json();
  const segments = Array.isArray(data) && Array.isArray(data[0]) ? data[0] : [];
  return segments
    .map((s) => (Array.isArray(s) ? s[0] : ''))
    .join('')
    .trim();
}

// Discover a valid Claude model for THIS account (aliases 404 on some
// accounts). Cached across warm invocations.
let cachedClaudeModel = null;
async function resolveClaudeModel(key) {
  if (process.env.ANTHROPIC_MODEL) return process.env.ANTHROPIC_MODEL;
  if (cachedClaudeModel) return cachedClaudeModel;
  try {
    const r = await fetch('https://api.anthropic.com/v1/models?limit=100', {
      headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01' },
    });
    if (r.ok) {
      const d = await r.json();
      const ids = (d.data || []).map((m) => m.id);
      cachedClaudeModel =
        ids.find((i) => i.includes('sonnet')) ||
        ids.find((i) => i.includes('haiku')) ||
        ids[0] ||
        null;
    }
  } catch (_) {
    // fall through to default
  }
  return cachedClaudeModel || 'claude-3-5-sonnet-latest';
}

async function callClaude(key, model, source, target, text) {
  return fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model,
      max_tokens: 1024,
      system: systemPrompt(source, target),
      messages: [{ role: 'user', content: text }],
    }),
  });
}

async function forceDiscoverClaudeModel(key) {
  try {
    const r = await fetch('https://api.anthropic.com/v1/models?limit=100', {
      headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01' },
    });
    if (r.ok) {
      const d = await r.json();
      const ids = (d.data || []).map((m) => m.id);
      return (
        ids.find((i) => i.includes('sonnet')) ||
        ids.find((i) => i.includes('haiku')) ||
        ids[0] ||
        null
      );
    }
  } catch (_) {
    // ignore
  }
  return null;
}

async function translateWithClaude({ text, source, target }) {
  const key = cleanKey(process.env.ANTHROPIC_API_KEY);
  if (!key) throw new Error('ANTHROPIC_API_KEY is not set on the server.');

  let model = await resolveClaudeModel(key);
  let res = await callClaude(key, model, source, target, text);

  if (res.status === 404) {
    cachedClaudeModel = null;
    const discovered = await forceDiscoverClaudeModel(key);
    if (discovered && discovered !== model) {
      cachedClaudeModel = discovered;
      model = discovered;
      res = await callClaude(key, model, source, target, text);
    }
  }

  if (!res.ok) {
    throw new Error('Claude error ' + res.status + ': ' + (await res.text()));
  }
  const data = await res.json();
  return (data.content || [])
    .filter((b) => b.type === 'text')
    .map((b) => b.text)
    .join('')
    .trim();
}

async function translateWithOpenAI({ text, source, target }) {
  const key = cleanKey(process.env.OPENAI_API_KEY);
  if (!key) throw new Error('OPENAI_API_KEY is not set on the server.');
  const model = process.env.OPENAI_TRANSLATE_MODEL || 'gpt-4o-mini';

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      authorization: 'Bearer ' + key,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      messages: [
        { role: 'system', content: systemPrompt(source, target) },
        { role: 'user', content: text },
      ],
    }),
  });

  if (!res.ok) {
    throw new Error('OpenAI error ' + res.status + ': ' + (await res.text()));
  }
  const data = await res.json();
  return (data.choices?.[0]?.message?.content || '').trim();
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }
  try {
    const body =
      typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const { text, target, source, provider } = body;
    if (!text || !target) {
      res.status(400).json({ error: 'Missing "text" or "target".' });
      return;
    }
    // Route to the requested provider when its key is available; otherwise fall
    // back to the free engine so the deploy works with zero secrets.
    let translation;
    if (provider === 'openai' && process.env.OPENAI_API_KEY) {
      translation = await translateWithOpenAI({ text, source, target });
    } else if (provider === 'claude' && process.env.ANTHROPIC_API_KEY) {
      translation = await translateWithClaude({ text, source, target });
    } else {
      translation = await translateFree({ text, source, target });
    }
    res.status(200).json({ translation });
  } catch (err) {
    res.status(500).json({ error: redact(err && err.message ? err.message : err) });
  }
};
