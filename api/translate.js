// Vercel serverless function: server-side translation proxy.
//
// Keeps the API key OFF the client. The Flutter web app posts
// { text, target, source, provider } here and receives { translation }.
//
// Configure the key in Vercel → Project → Settings → Environment Variables:
//   ANTHROPIC_API_KEY   (for Claude — this is the "Claude key only" setup)
//   OPENAI_API_KEY      (optional, only if you also want the OpenAI translator)

const LANG_NAMES = {
  gu: 'Gujarati', hi: 'Hindi', en: 'English', ar: 'Arabic',
  fr: 'French', es: 'Spanish', ko: 'Korean', ja: 'Japanese',
};

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

async function translateWithClaude({ text, source, target }) {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error('ANTHROPIC_API_KEY is not set on the server.');
  const model = process.env.ANTHROPIC_MODEL || 'claude-3-5-sonnet-latest';

  const res = await fetch('https://api.anthropic.com/v1/messages', {
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
  const key = process.env.OPENAI_API_KEY;
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
    const useOpenAI = provider === 'openai' && process.env.OPENAI_API_KEY;
    const translation = useOpenAI
      ? await translateWithOpenAI({ text, source, target })
      : await translateWithClaude({ text, source, target });
    res.status(200).json({ translation });
  } catch (err) {
    res.status(500).json({ error: String(err && err.message ? err.message : err) });
  }
};
