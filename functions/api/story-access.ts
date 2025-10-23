import {
  resolvePublicSupabase,
  resolveSupabaseConfig,
  type SupabaseEnv,
} from "./_supabase";

interface Env extends SupabaseEnv {}

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
    const body = await request.json().catch(() => null);
    if (!body || typeof body !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const authorId = normalizeId((body as any).authorId ?? (body as any).author_id);
    const subscriberId = normalizeId(
      (body as any).subscriberId ?? (body as any).subscriber_id,
    );
    const tokenRaw = typeof (body as any).token === 'string'
      ? (body as any).token.trim()
      : '';
    const storyId = normalizeId((body as any).storyId ?? (body as any).story_id);
    const sourceRaw = typeof (body as any).source === 'string'
      ? (body as any).source.trim()
      : undefined;
    const source = sourceRaw ? sourceRaw.substring(0, 120) : undefined;
    const eventTypeRaw = typeof (body as any).eventType === 'string'
      ? (body as any).eventType.trim()
      : 'access_granted';
    const eventType = eventTypeRaw.length > 0 ? eventTypeRaw : 'access_granted';

    if (!authorId || !subscriberId || !tokenRaw) {
      return json({ error: 'authorId, subscriberId and token are required' }, 400);
    }

    const { credentials, diagnostics } = resolveSupabaseConfig(env);
    const publicSupabase = resolvePublicSupabase(env, credentials?.url);
    const rpcUrl = credentials?.url ?? publicSupabase?.url;
    const apiKey = credentials?.serviceKey ?? publicSupabase?.anonKey;

    if (!rpcUrl || !apiKey) {
      console.error('[story-access] Missing Supabase credentials', {
        diagnostics,
        hasPublicSupabase: Boolean(publicSupabase),
      });
      return json({ error: 'Supabase credentials not configured' }, 500);
    }

    const ip = request.headers.get('cf-connecting-ip')
      ?? request.headers.get('x-forwarded-for')
      ?? null;
    const userAgent = request.headers.get('user-agent');
    const normalizedUserAgent = userAgent ? userAgent.substring(0, 512) : null;

    const rpcResponse = await fetch(
      `${rpcUrl}/rest/v1/rpc/register_subscriber_access`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          apikey: apiKey,
          Authorization: `Bearer ${apiKey}`,
          Prefer: 'return=representation',
        },
        body: JSON.stringify({
          author_id: authorId,
          subscriber_id: subscriberId,
          token: tokenRaw,
          story_id: storyId ?? null,
          source: source ?? null,
          event_type: eventType,
          request_ip: ip,
          user_agent: normalizedUserAgent,
        }),
      },
    );

    const payload = await parseJson(rpcResponse);

    if (!payload || typeof payload !== 'object') {
      throw new Error(
        `Unexpected response from Supabase RPC (${rpcResponse.status})`,
      );
    }

    const status = typeof (payload as any).status === 'string'
      ? ((payload as any).status as string).toLowerCase()
      : undefined;

    if (status === 'ok') {
      const data = ((payload as any).data ?? {}) as Record<string, unknown>;
      const subscriber = (data.subscriber ?? {}) as Record<string, unknown>;
      const resolvedSource = (() => {
        if (typeof data.source === 'string') {
          const trimmed = (data.source as string).trim();
          if (trimmed.length > 0) {
            return trimmed;
          }
        }
        return source ?? 'link';
      })();
      const subscriberStatusRaw = typeof subscriber.status === 'string'
        ? (subscriber.status as string).toLowerCase()
        : undefined;
      const responseBody: Record<string, unknown> = {
        grantedAt: data.grantedAt ?? new Date().toISOString(),
        token: data.token ?? tokenRaw,
        source: resolvedSource,
        subscriber,
        unsubscribed: subscriberStatusRaw === 'unsubscribed',
      };
      if (publicSupabase) {
        responseBody.supabase = publicSupabase;
      }

      console.log('[story-access] Access granted via RPC', {
        authorId,
        subscriberId,
        storyId,
        eventType,
        source: resolvedSource,
        unsubscribed: responseBody.unsubscribed,
        rpcUsedServiceKey: Boolean(credentials?.serviceKey),
      });

      return json(responseBody);
    }

    if (status === 'not_found') {
      return json({ error: 'Subscriber not found' }, 404);
    }

    if (status === 'forbidden') {
      return json({
        error: typeof (payload as any).message === 'string'
            ? (payload as any).message
            : 'Invalid or expired token',
      }, 403);
    }

    return json({
      error: 'Access validation failed',
      detail: payload,
    }, 400);
  } catch (error) {
    console.error('[story-access] Access validation failed', error);
    return json({ error: 'Access validation failed', detail: String(error) }, 500);
  }
};

function normalizeId(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

async function parseJson(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch (_) {
    return null;
  }
}
