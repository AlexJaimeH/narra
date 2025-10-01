export const onRequestOptions: PagesFunction = async () => {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    },
  });
};

export const onRequestPost: PagesFunction = async ({ request, env }) => {
  try {
    const openaiApiKey = env.OPENAI_API_KEY;
    if (!openaiApiKey) {
      return new Response('OpenAI API key not configured.', { status: 500 });
    }

    const url = new URL(request.url);
    const model = url.searchParams.get('model') || 'gpt-4o-mini-transcribe';
    const language = url.searchParams.get('language') || 'es';

    const contentType = request.headers.get('content-type') || '';
    let formData: FormData;

    if (contentType.includes('multipart/form-data')) {
      formData = await request.formData();
      if (!formData.get('model')) formData.append('model', model);
      if (!formData.get('language')) formData.append('language', language);
      if (!formData.get('response_format')) formData.append('response_format', 'json');
    } else {
      const arrayBuffer = await request.arrayBuffer();
      const type = request.headers.get('Content-Type') || 'audio/webm';
      const file = new File([arrayBuffer], 'audio.webm', { type });
      formData = new FormData();
      formData.append('file', file);
      formData.append('model', model);
      formData.append('language', language);
      formData.append('response_format', 'json');
    }

    const attempt = async (m: string) => {
      const fd = new FormData();
      for (const [k, v] of (formData as any).entries()) {
        fd.append(k, v);
      }
      fd.set('model', m);
      if (!fd.get('response_format')) fd.set('response_format', 'json');
      const res = await fetch('https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${openaiApiKey}` },
        body: fd,
      });
      return res;
    };

    let openaiRes = await attempt(model);
    if (openaiRes.status >= 400) {
      // Fallbacks for compatibility
      openaiRes = await attempt('gpt-4o-mini-transcribe');
      if (openaiRes.status >= 400) {
        openaiRes = await attempt('whisper-1');
      }
    }

    const body = await openaiRes.text();
    return new Response(body, {
      status: openaiRes.status,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      },
    });
  } catch (error: any) {
    return new Response(`Error: ${error.message || String(error)}`, { status: 500 });
  }
};


