import {
  resolveSupabaseConfig,
  supabaseHeaders,
  type SupabaseCredentials,
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
    const { credentials, diagnostics } = resolveSupabaseConfig(env);
    if (!credentials) {
      console.error("[story-access] Missing Supabase credentials", diagnostics);
      return json({ error: 'Supabase credentials not configured' }, 500);
    }
    const supabase = credentials;
    const { url: supabaseUrl, serviceKey } = supabase;

    const body = await request.json().catch(() => null);
    if (!body || typeof body !== 'object') {
      return json({ error: 'Invalid request body' }, 400);
    }

    const authorId = normalizeId((body as any).authorId ?? (body as any).author_id);
    const subscriberId = normalizeId(
      (body as any).subscriberId ?? (body as any).subscriber_id,
    );
    const token = typeof (body as any).token === 'string'
      ? (body as any).token.trim()
      : '';
    const storyId = normalizeId((body as any).storyId ?? (body as any).story_id);
    const source = typeof (body as any).source === 'string'
      ? (body as any).source.trim()
      : undefined;
    const eventType = typeof (body as any).eventType === 'string'
      ? (body as any).eventType.trim()
      : 'access_granted';

    if (!authorId || !subscriberId || !token) {
      return json({ error: 'authorId, subscriberId and token are required' }, 400);
    }

    const subscriber = await fetchSubscriber(supabase, authorId, subscriberId);
    if (!subscriber) {
      return json({ error: 'Subscriber not found' }, 404);
    }

    const storedToken = typeof subscriber.access_token === 'string'
      ? (subscriber.access_token as string).trim()
      : '';
    if (!storedToken || storedToken !== token) {
      return json({ error: 'Invalid or expired token' }, 403);
    }

    const status = typeof subscriber.status === 'string'
      ? (subscriber.status as string).toLowerCase()
      : 'pending';
    if (status === 'unsubscribed') {
      return json({ error: 'Subscriber is not active' }, 403);
    }

    const nowIso = new Date().toISOString();
    const ip = request.headers.get('cf-connecting-ip')
      ?? request.headers.get('x-forwarded-for')
      ?? undefined;
    const userAgent = request.headers.get('user-agent') ?? undefined;

    const updates: Record<string, unknown> = {
      last_access_at: nowIso,
      last_access_ip: ip ?? subscriber.last_access_ip ?? null,
      last_access_user_agent: userAgent
        ? userAgent.substring(0, 512)
        : subscriber.last_access_user_agent ?? null,
      last_access_source: source ?? subscriber.last_access_source ?? 'link',
    };

    if (status !== 'confirmed') {
      updates.status = 'confirmed';
    }

    await updateSubscriber(supabase, authorId, subscriberId, updates);

    await insertAccessEvent(supabase, {
      user_id: authorId,
      subscriber_id: subscriberId,
      story_id: storyId ?? null,
      access_token: token,
      event_type: eventType,
      metadata: {
        source: source ?? null,
        ip: ip ?? null,
        userAgent: userAgent ?? null,
      },
    });

    console.log('[story-access] Access granted', {
      authorId,
      subscriberId,
      storyId,
      eventType,
      source: source ?? 'link',
      status: (updates.status as string | undefined) ?? status,
    });

    return json({
      grantedAt: nowIso,
      token: storedToken,
      source: source ?? subscriber.last_access_source ?? 'link',
      subscriber: {
        id: subscriber.id,
        name: subscriber.name,
        email: subscriber.email,
        status: 'confirmed',
      },
    });
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

async function fetchSubscriber(
  config: SupabaseCredentials,
  authorId: string,
  subscriberId: string,
) {
  const url = new URL('/rest/v1/subscribers', config.url);
  url.searchParams.set('id', `eq.${subscriberId}`);
  url.searchParams.set('user_id', `eq.${authorId}`);
  url.searchParams.set('select',
    'id,name,email,status,access_token,access_token_created_at,' +
      'access_token_last_sent_at,last_access_at,last_access_ip,' +
      'last_access_user_agent,last_access_source'
  );
  url.searchParams.set('limit', '1');

  const response = await fetch(url.toString(), {
    headers: supabaseHeaders(config.serviceKey),
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch subscriber (${response.status})`);
  }

  const data = await response.json();
  return Array.isArray(data) && data.length > 0 ? data[0] : null;
}

async function updateSubscriber(
  config: SupabaseCredentials,
  authorId: string,
  subscriberId: string,
  updates: Record<string, unknown>,
) {
  const url = new URL('/rest/v1/subscribers', config.url);
  url.searchParams.set('id', `eq.${subscriberId}`);
  url.searchParams.set('user_id', `eq.${authorId}`);

  const response = await fetch(url.toString(), {
    method: 'PATCH',
    headers: {
      ...supabaseHeaders(config.serviceKey),
      Prefer: 'return=minimal',
    },
    body: JSON.stringify(updates),
  });

  if (!response.ok) {
    throw new Error(`Failed to update subscriber (${response.status})`);
  }
}

async function insertAccessEvent(
  config: SupabaseCredentials,
  payload: Record<string, unknown>,
) {
  const url = new URL('/rest/v1/subscriber_access_events', config.url);
  const response = await fetch(url.toString(), {
    method: 'POST',
    headers: {
      ...supabaseHeaders(config.serviceKey),
      Prefer: 'return=minimal',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    throw new Error(`Failed to insert access event (${response.status})`);
  }
}


function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
