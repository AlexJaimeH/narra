const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

interface Env {
  OPENAI_API_KEY: string;
}

const DEFAULT_MODEL = 'gpt-4o-mini-transcribe-realtime';
const DEFAULT_MODALITIES = ['text'];
const DEFAULT_INSTRUCTIONS =
  'Eres un transcriptor en español. Devuelve exclusivamente el discurso del usuario como texto claro y sin instrucciones adicionales.';

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    const apiKey = env.OPENAI_API_KEY;
    if (!apiKey) {
      return new Response('OpenAI API key not configured.', {
        status: 500,
        headers: CORS_HEADERS,
      });
    }

    const contentType = request.headers.get('Content-Type') ?? '';
    let jsonPayload: any = null;
    if (contentType.includes('application/json')) {
      jsonPayload = await request.json().catch(() => null);
    }

    if (jsonPayload && typeof jsonPayload === 'object' && 'sdp' in jsonPayload) {
      return new Response(
        JSON.stringify({
          error:
            'SDP exchange must be performed directly contra OpenAI usando el client_secret efímero (consulta la documentación Realtime).',
        }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        },
      );
    }

    const normalizedPayload = jsonPayload && typeof jsonPayload === 'object' ? jsonPayload : {};

    const model = typeof normalizedPayload.model === 'string' && normalizedPayload.model.trim().length > 0
      ? (normalizedPayload.model as string)
      : DEFAULT_MODEL;

    const modalities = Array.isArray(normalizedPayload.modalities)
      ? (normalizedPayload.modalities as string[])
      : DEFAULT_MODALITIES;

    const instructions = typeof normalizedPayload.instructions === 'string'
      ? (normalizedPayload.instructions as string)
      : DEFAULT_INSTRUCTIONS;

    const sessionRequest: Record<string, unknown> = {
      model,
      modalities,
      instructions,
    };

    if (normalizedPayload.voice && typeof normalizedPayload.voice === 'string') {
      sessionRequest.voice = normalizedPayload.voice;
    }

    if (normalizedPayload.temperature != null) {
      sessionRequest.temperature = normalizedPayload.temperature;
    }

    const sessionResponse = await fetch('https://api.openai.com/v1/realtime/sessions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'OpenAI-Beta': 'realtime=v1',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(sessionRequest),
    });

    const rawBody = await sessionResponse.text();
    if (sessionResponse.status < 200 || sessionResponse.status >= 300) {
      return new Response(
        JSON.stringify({
          error: 'Realtime session failed',
          status: sessionResponse.status,
          details: rawBody,
        }),
        {
          status: sessionResponse.status,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        },
      );
    }

    let sessionJson: Record<string, any> = {};
    try {
      sessionJson = JSON.parse(rawBody);
    } catch (parseError) {
      return new Response(
        JSON.stringify({
          error: 'Realtime session malformed payload',
          details: rawBody,
        }),
        {
          status: 502,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        },
      );
    }

    const clientSecretRaw = sessionJson.client_secret;
    const clientSecret =
      typeof clientSecretRaw === 'string'
        ? clientSecretRaw
        : typeof clientSecretRaw === 'object' && clientSecretRaw && 'value' in clientSecretRaw
          ? (clientSecretRaw.value as string | undefined)
          : undefined;

    if (!clientSecret || clientSecret.length === 0) {
      return new Response(
        JSON.stringify({
          error: 'Realtime session missing client_secret',
          details: sessionJson,
        }),
        {
          status: 502,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        },
      );
    }

    const payload = {
      sessionId: sessionJson.id ?? null,
      expiresAt: sessionJson.expires_at ?? sessionJson.expiration_time ?? null,
      clientSecret,
      iceServers: Array.isArray(sessionJson.ice_servers) ? sessionJson.ice_servers : [],
      model: sessionJson.model ?? model,
    };

    return new Response(JSON.stringify(payload), {
      status: 200,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  } catch (error: unknown) {
    return new Response(`Error: ${error instanceof Error ? error.message : String(error)}`, {
      status: 500,
      headers: CORS_HEADERS,
    });
  }
};
