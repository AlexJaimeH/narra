export interface Env {
  OPENAI_API_KEY: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, {
    status: 204,
    headers: CORS_HEADERS,
  });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    const openaiApiKey = env.OPENAI_API_KEY;
    if (!openaiApiKey) {
      return new Response('OpenAI API key not configured.', { status: 500 });
    }

    const url = new URL(request.url);
    const allowedModels = new Set([
      'gpt-4o-transcribe-latest',
      'gpt-4o-transcribe',
      'gpt-4o-mini-transcribe',
      'whisper-1',
    ]);
    const defaultModel = 'gpt-4o-transcribe-latest';
    const requestedModel = url.searchParams.get('model');
    const model =
      requestedModel != null && allowedModels.has(requestedModel)
        ? requestedModel
        : defaultModel;
    const fallbackQuery = url.searchParams.get('fallback');
    const languageParam = url.searchParams.get('language');
    const language =
      languageParam != null && languageParam.trim().length > 0
        ? languageParam
        : null;
    const prompt = url.searchParams.get('prompt');

    const contentType = request.headers.get('content-type') || '';
    let formData: FormData;

    if (contentType.includes('multipart/form-data')) {
      formData = await request.formData();
      if (!formData.get('model')) formData.append('model', model);
      if (language != null && !formData.get('language')) {
        formData.append('language', language);
      }
      if (prompt && !formData.get('prompt')) formData.append('prompt', prompt);
      if (!formData.get('response_format')) {
        formData.append('response_format', 'verbose_json');
      }
    } else {
      const arrayBuffer = await request.arrayBuffer();
      const type = request.headers.get('Content-Type') || 'audio/webm';
      const extension = (() => {
        const mime = type.split(';')[0]?.trim() || 'audio/webm';
        switch (mime) {
          case 'audio/mp4':
            return 'mp4';
          case 'audio/mpeg':
            return 'mp3';
          case 'audio/ogg':
            return 'ogg';
          case 'audio/webm':
            return 'webm';
          case 'audio/aac':
            return 'aac';
          default:
            return 'webm';
        }
      })();
      const file = new File([arrayBuffer], `audio.${extension}`, { type });
      formData = new FormData();
      formData.append('file', file);
      formData.append('model', model);
      if (language != null) {
        formData.append('language', language);
      }
      if (prompt) formData.append('prompt', prompt);
      formData.append('response_format', 'verbose_json');
    }

    const attemptOrder: string[] = [];
    const pushModel = (candidate: string | null | undefined) => {
      if (!candidate) return;
      const trimmed = candidate.trim();
      if (!allowedModels.has(trimmed)) return;
      if (!attemptOrder.includes(trimmed)) {
        attemptOrder.push(trimmed);
      }
    };

    pushModel(model);

    if (fallbackQuery) {
      for (const part of fallbackQuery.split(',')) {
        pushModel(part);
      }
    }

    pushModel('gpt-4o-transcribe');
    pushModel('gpt-4o-mini-transcribe');
    pushModel('whisper-1');

    if (attemptOrder.length === 0) {
      attemptOrder.push(defaultModel);
    }

    const attempt = async (m: string) => {
      const fd = new FormData();
      for (const [k, v] of (formData as any).entries()) {
        fd.append(k, v);
      }
      fd.set('model', m);
      if (!fd.get('response_format')) {
        fd.set('response_format', 'verbose_json');
      }
      const res = await fetch('https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${openaiApiKey}` },
        body: fd,
      });
      return res;
    };

    let openaiRes: Response | null = null;
    for (const candidate of attemptOrder) {
      openaiRes = await attempt(candidate);
      if (openaiRes.status < 400) {
        break;
      }
    }

    if (!openaiRes) {
      return new Response('Transcription attempt failed: no model attempted', {
        status: 502,
      });
    }

    if (openaiRes.status >= 400) {
      const failureBody = await openaiRes.text();
      return new Response(
        `OpenAI transcription failed (${openaiRes.status}): ${failureBody}`,
        {
          status: openaiRes.status,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        },
      );
    }

    const body = await openaiRes.text();
    return new Response(body, {
      status: openaiRes.status,
      headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
    });
  } catch (error: any) {
    return new Response(`Error: ${error.message || String(error)}`, { status: 500 });
  }
};
