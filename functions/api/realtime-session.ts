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
    const payload = contentType.includes('application/json')
      ? await request.json().catch(() => null)
      : null;

    const offerSdp =
      payload && typeof payload === 'object' && typeof (payload as any).sdp === 'string'
        ? ((payload as any).sdp as string)
        : undefined;

    if (offerSdp) {
      const response = await fetch(
        'https://api.openai.com/v1/realtime?model=gpt-4o-mini-transcribe-realtime',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'OpenAI-Beta': 'realtime=v1',
            'Content-Type': 'application/sdp',
            Accept: 'application/sdp',
          },
          body: offerSdp,
        },
      );

      const answerBody = await response.text();

      if (response.status >= 200 && response.status < 300) {
        return new Response(JSON.stringify({ answer: answerBody }), {
          status: 200,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        });
      }

      return new Response(
        JSON.stringify({
          error: 'Realtime handshake failed',
          status: response.status,
          details: answerBody,
        }),
        {
          status: response.status,
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
    );

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
