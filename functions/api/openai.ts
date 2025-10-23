export interface Env {
  OPENAI_API_KEY: string;
  OPENAI_PROJECT_ID?: string;
  OPENAI_ORGANIZATION?: string;
}

const buildOpenAIHeaders = (env: Env): Record<string, string> => {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${env.OPENAI_API_KEY}`,
  };

  if (env.OPENAI_PROJECT_ID) {
    headers['OpenAI-Project'] = env.OPENAI_PROJECT_ID;
  }

  if (env.OPENAI_ORGANIZATION) {
    headers['OpenAI-Organization'] = env.OPENAI_ORGANIZATION;
  }

  return headers;
};

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    if (!env.OPENAI_API_KEY) {
      return json({ error: 'OPENAI_API_KEY not configured' }, 500);
    }

    const req = await request.json().catch(() => null);
    if (!req || !Array.isArray(req.messages)) {
      return json({ error: 'Invalid request: messages[] required' }, 400);
    }

    const payload: Record<string, unknown> = {
      model: typeof req.model === 'string' ? req.model : 'gpt-4.1',
      messages: req.messages,
    };

    const temperature =
      typeof req.temperature === 'number' ? req.temperature : 0.7;
    if (typeof temperature === 'number' && !Number.isNaN(temperature)) {
      payload.temperature = temperature;
    }

    if (req.response_format && typeof req.response_format === 'object') {
      payload.response_format = req.response_format;
    }

    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: buildOpenAIHeaders(env),
      body: JSON.stringify(payload),
    });

    const text = await res.text();
    let data: unknown;
    try {
      data = JSON.parse(text);
    } catch {
      data = { raw: text };
    }
    return json(data, res.status);
  } catch (err: unknown) {
    return json(
      { error: 'OpenAI proxy failed', detail: String(err) },
      500,
    );
  }
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

