// Vercel serverless function: server-side Kimchi companion chat.
//
// Keeps the API key OFF the client. The Flutter web app posts
// { messages: [{role, content}], language } here and receives { reply }.
//
// Configure the key in Vercel → Project → Settings → Environment Variables:
//   ANTHROPIC_API_KEY   (for Claude — the "Claude key only" setup)
//   OPENAI_API_KEY      (optional alternative)

// Env values sometimes get pasted with surrounding whitespace or accidentally
// duplicated across lines. Take the first whitespace-delimited token so a stray
// newline / double-paste can never produce an invalid header value.
function cleanKey(value) {
  return (value || '').trim().split(/\s+/)[0] || '';
}

// Never leak a key in an error message.
function redact(text) {
  return String(text).replace(/sk-[A-Za-z0-9._-]+/g, 'sk-***');
}

function kimchiSystem(language) {
  const lang = language || 'the same language the user used';
  return (
    'You are Kimchi (also spelled Kimachi), a warm, playful, upbeat AI ' +
    'companion — part personal pet, part best friend, part translator and ' +
    'search guide. You chat naturally, remember the conversation, and love ' +
    'helping. Keep replies short and natural — they are spoken out loud, so ' +
    'talk like a friendly companion, not an essay. Use at most a couple of ' +
    'sentences unless asked for more. Be encouraging and a little cute, but ' +
    'genuinely helpful. Always reply in ' + lang + '.'
  );
}

// Discover a valid Claude model for THIS account (model aliases like
// "claude-3-5-sonnet-latest" 404 on some accounts). Prefer newest sonnet,
// then haiku, then whatever is available. Cached across warm invocations.
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

async function callClaude(key, model, language, messages) {
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
      system: kimchiSystem(language),
      messages: messages.map((m) => ({ role: m.role, content: m.content })),
    }),
  });
}

// Always query the account's real model list (ignores any env override), used
// to self-heal when the configured/default model 404s.
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

async function chatWithClaude({ messages, language }) {
  const key = cleanKey(process.env.ANTHROPIC_API_KEY);
  if (!key) throw new Error('ANTHROPIC_API_KEY is not set on the server.');

  let model = await resolveClaudeModel(key);
  let res = await callClaude(key, model, language, messages);

  // If the chosen model isn't available (even a wrong env override), discover a
  // real one from the account and retry once.
  if (res.status === 404) {
    cachedClaudeModel = null;
    const discovered = await forceDiscoverClaudeModel(key);
    if (discovered && discovered !== model) {
      cachedClaudeModel = discovered;
      model = discovered;
      res = await callClaude(key, model, language, messages);
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

async function chatWithOpenAI({ messages, language }) {
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
      temperature: 0.7,
      messages: [
        { role: 'system', content: kimchiSystem(language) },
        ...messages.map((m) => ({ role: m.role, content: m.content })),
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
    const { messages, language } = body;
    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ error: 'Missing "messages".' });
      return;
    }
    const preferOpenAI = !process.env.ANTHROPIC_API_KEY && process.env.OPENAI_API_KEY;
    const reply = preferOpenAI
      ? await chatWithOpenAI({ messages, language })
      : await chatWithClaude({ messages, language });
    res.status(200).json({ reply });
  } catch (err) {
    res.status(500).json({ error: redact(err && err.message ? err.message : err) });
  }
};
