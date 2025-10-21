interface Env {
  RESEND_API_KEY: string;
  RESEND_FROM_EMAIL: string;
  RESEND_REPLY_TO?: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    if (!env.RESEND_API_KEY) {
      return json({ error: 'RESEND_API_KEY not configured' }, 500);
    }

    if (!env.RESEND_FROM_EMAIL) {
      return json({ error: 'RESEND_FROM_EMAIL not configured' }, 500);
    }

    const payload = await request.json().catch(() => null);
    if (!payload || typeof payload !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const rawTo = (payload as any).to;
    const recipients: string[] = Array.isArray(rawTo)
      ? rawTo.filter((value) => typeof value === 'string')
      : typeof rawTo === 'string'
        ? [rawTo]
        : [];

    const normalizedTo = recipients
      .map((value) => value.trim())
      .filter((value) => value.length > 0);

    if (normalizedTo.length === 0) {
      return json({ error: 'At least one recipient is required' }, 400);
    }

    const subject = typeof (payload as any).subject === 'string'
      ? (payload as any).subject.trim()
      : '';
    const html = typeof (payload as any).html === 'string'
      ? (payload as any).html
      : '';

    if (!subject) {
      return json({ error: 'Email subject is required' }, 400);
    }

    if (!html) {
      return json({ error: 'Email html content is required' }, 400);
    }

    const fromOverride = typeof (payload as any).from === 'string'
      ? (payload as any).from.trim()
      : '';
    const replyToOverride = typeof (payload as any).replyTo === 'string'
      ? (payload as any).replyTo.trim()
      : '';

    const resendBody: Record<string, unknown> = {
      from: fromOverride || env.RESEND_FROM_EMAIL,
      to: normalizedTo,
      subject,
      html,
    };

    const text = typeof (payload as any).text === 'string'
      ? (payload as any).text
      : '';
    if (text.trim().length > 0) {
      resendBody.text = text;
    }

    if (replyToOverride || env.RESEND_REPLY_TO) {
      resendBody.reply_to = replyToOverride || env.RESEND_REPLY_TO;
    }

    const maybeList = (value: unknown): string[] | undefined => {
      if (!value) return undefined;
      if (Array.isArray(value)) {
        const items = value
          .filter((item) => typeof item === 'string')
          .map((item) => (item as string).trim())
          .filter((item) => item.length > 0);
        return items.length > 0 ? items : undefined;
      }
      return undefined;
    };

    const cc = maybeList((payload as any).cc);
    if (cc) resendBody.cc = cc;

    const bcc = maybeList((payload as any).bcc);
    if (bcc) resendBody.bcc = bcc;

    const tags = maybeList((payload as any).tags);
    if (tags) resendBody.tags = tags;

    const headers = (payload as any).headers;
    if (headers && typeof headers === 'object') {
      const headerEntries = Object.entries(headers as Record<string, unknown>)
        .filter(([key, value]) => typeof key === 'string' && typeof value === 'string');
      if (headerEntries.length > 0) {
        resendBody.headers = Object.fromEntries(headerEntries);
      }
    }

    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
      },
      body: JSON.stringify(resendBody),
    });

    const raw = await resendResponse.text();
    let parsed: any = null;
    try {
      parsed = raw ? JSON.parse(raw) : null;
    } catch (_) {
      parsed = raw ? { raw } : null;
    }

    if (resendResponse.status >= 200 && resendResponse.status < 300) {
      return json(parsed ?? { ok: true }, resendResponse.status);
    }

    return json(
      {
        error: parsed?.error ?? 'Resend API error',
        detail: parsed,
      },
      resendResponse.status,
    );
  } catch (error) {
    return json({ error: 'Email function failed', detail: String(error) }, 500);
  }
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
