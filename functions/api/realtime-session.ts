const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

interface Env {
  OPENAI_API_KEY: string;
  OPENAI_PROJECT_ID?: string;
  OPENAI_ORGANIZATION?: string;
}

const buildRealtimeHeaders = (env: Env): Record<string, string> => {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'OpenAI-Beta': 'realtime=v1',
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

const DEFAULT_MODEL = 'gpt-4o-mini-transcribe';
const ALLOWED_TRANSCRIPTION_MODELS = new Set([
  'gpt-4o-mini-transcribe',
  'gpt-4o-transcribe-latest',
  'gpt-4o-transcribe',
  'whisper-1',
]);
const DEFAULT_MODALITIES = ['text'];

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

    const resolveModel = (value: unknown) => {
      if (typeof value !== 'string' || value.trim().length === 0) {
        return DEFAULT_MODEL;
      }
      const trimmed = value.trim();
      if (!ALLOWED_TRANSCRIPTION_MODELS.has(trimmed)) {
        return DEFAULT_MODEL;
      }
      // Whisper-1 no soporta sesiones Realtime; hacemos fallback al modelo primario.
      return trimmed === 'whisper-1' ? DEFAULT_MODEL : trimmed;
    };

    const model = resolveModel(normalizedPayload.model);

    const modalities = Array.isArray(normalizedPayload.modalities)
      ? (normalizedPayload.modalities as string[])
      : DEFAULT_MODALITIES;

    const instructionsRaw =
      typeof normalizedPayload.instructions === 'string'
        ? normalizedPayload.instructions.trim()
        : '';

    const sessionRequest: Record<string, unknown> = {
      model,
      modalities,
      input_audio_format: 'pcm16',
      output_audio_format: 'pcm16',
      turn_detection: {
        type: 'server_vad',
        threshold: 0.5,
        prefix_padding_ms: 300,
        silence_duration_ms: 500,
      },
    };

    if (instructionsRaw.length > 0) {
      sessionRequest.instructions = instructionsRaw;
    }

    if (normalizedPayload.voice && typeof normalizedPayload.voice === 'string') {
      sessionRequest.voice = normalizedPayload.voice;
    } else {
      sessionRequest.voice = 'alloy';
    }

    if (normalizedPayload.temperature != null) {
      sessionRequest.temperature = normalizedPayload.temperature;
    } else {
      sessionRequest.temperature = 0;
    }

    const sessionResponse = await fetch('https://api.openai.com/v1/realtime/sessions', {
      method: 'POST',
      headers: buildRealtimeHeaders(env),
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

    const sessionIdRaw = sessionJson.id ?? sessionJson.session_id ?? null;
    const expiresRaw =
      sessionJson.expires_at ?? sessionJson.expiration_time ?? sessionJson.expire_time ?? null;

    const payload = {
      sessionId:
        sessionIdRaw == null || sessionIdRaw === ''
          ? null
          : typeof sessionIdRaw === 'string'
            ? sessionIdRaw
            : String(sessionIdRaw),
      expiresAt:
        expiresRaw == null || expiresRaw === ''
          ? null
          : typeof expiresRaw === 'string'
            ? expiresRaw
            : String(expiresRaw),
      clientSecret,
      iceServers: Array.isArray(sessionJson.ice_servers) ? sessionJson.ice_servers : [],
      model: typeof sessionJson.model === 'string' && sessionJson.model.length > 0 ? sessionJson.model : model,
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
