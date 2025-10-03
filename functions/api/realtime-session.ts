const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

interface Env {
  OPENAI_API_KEY: string;
}

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

    const offerSdp =
      typeof jsonPayload?.sdp === 'string' ? (jsonPayload.sdp as string) : undefined;

    if (offerSdp) {
      const sessionResponse = await fetch('https://api.openai.com/v1/realtime/sessions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'OpenAI-Beta': 'realtime=v1',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini-transcribe-realtime',
          modalities: ['text'],
          instructions:
            'Eres un transcriptor en español. Devuelve exclusivamente el discurso del usuario como texto claro y sin instrucciones adicionales.',
        }),
      });

      const sessionBody = await sessionResponse.text();
      if (sessionResponse.status < 200 || sessionResponse.status >= 300) {
        return new Response(
          JSON.stringify({
            error: 'Realtime session failed',
            status: sessionResponse.status,
            details: sessionBody,
          }),
          {
            status: sessionResponse.status,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
          },
        );
      }

      const sessionJson = JSON.parse(sessionBody) as Record<string, unknown>;
      const sessionSecretRaw = sessionJson['client_secret'];
      let clientSecret = '';
      if (typeof sessionSecretRaw === 'string') {
        clientSecret = sessionSecretRaw;
      } else if (
        sessionSecretRaw != null &&
        typeof sessionSecretRaw === 'object' &&
        'value' in sessionSecretRaw &&
        typeof (sessionSecretRaw as any).value === 'string'
      ) {
        clientSecret = (sessionSecretRaw as any).value as string;
      }

      if (!clientSecret) {
        return new Response(
          JSON.stringify({
            error: 'Realtime session missing client_secret',
            details: sessionBody,
          }),
          {
            status: 500,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
          },
        );
      }

      const answerResponse = await fetch(
        'https://api.openai.com/v1/realtime?model=gpt-4o-mini-transcribe-realtime',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${clientSecret}`,
            'OpenAI-Beta': 'realtime=v1',
            'Content-Type': 'application/sdp',
            Accept: 'application/sdp',
          },
          body: offerSdp,
        },
      );

      const answerBody = await answerResponse.text();

      if (answerResponse.status >= 200 && answerResponse.status < 300) {
        return new Response(
          JSON.stringify({ answer: answerBody }),
          {
            status: 200,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
          },
        );
      }

      return new Response(
        JSON.stringify({
          error: 'Realtime handshake failed',
          status: answerResponse.status,
          details: answerBody,
        }),
        {
          status: answerResponse.status,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        },
      );
    }

    const sessionResponse = await fetch('https://api.openai.com/v1/realtime/sessions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'OpenAI-Beta': 'realtime=v1',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini-transcribe-realtime',
        modalities: ['text'],
        instructions:
          'Eres un transcriptor en español. Devuelve exclusivamente el discurso del usuario como texto claro y sin instrucciones adicionales.',
      }),
    });

    const body = await sessionResponse.text();
    return new Response(body, {
      status: sessionResponse.status,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  } catch (error: unknown) {
    return new Response(`Error: ${error instanceof Error ? error.message : String(error)}`, {
      status: 500,
      headers: CORS_HEADERS,
    });
  }
};
