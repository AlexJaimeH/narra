import {
  resolvePublicSupabase,
  resolveSupabaseConfig,
  type SupabaseEnv,
} from "./_supabase";
import { fetchAuthorDisplayName } from "./_author_display_name";

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
      const context = {
        diagnostics,
        hasPublicSupabase: Boolean(publicSupabase),
        rpcUrlResolved: Boolean(rpcUrl),
        hasServiceKey: Boolean(credentials?.serviceKey),
      };
      console.error('[story-access] Missing Supabase credentials', context);
      return json({
        error: 'Supabase credentials not configured',
        detail: context,
        hint:
          'Define SUPABASE_URL (o PUBLIC_SUPABASE_URL) y SUPABASE_SERVICE_ROLE_KEY '
          + 'en la configuración de Cloudflare Pages.',
      }, 500);
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
        isAuthor: data.isAuthor === true,
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

      // Send unsubscribe email notification if this was an unsubscribe event
      if (eventType === 'unsubscribe' && subscriberStatusRaw === 'unsubscribed') {
        const subscriberEmail = subscriber.email;
        const subscriberName = subscriber.name || 'Suscriptor';

        if (subscriberEmail && typeof subscriberEmail === 'string') {
          let authorEmail: string | undefined;
          if (credentials?.serviceKey) {
            try {
              const authorResponse = await fetch(
                `${rpcUrl}/auth/v1/admin/users/${authorId}`,
                {
                  headers: {
                    'Content-Type': 'application/json',
                    apikey: credentials.serviceKey,
                    Authorization: `Bearer ${credentials.serviceKey}`,
                  },
                },
              );
              if (authorResponse.ok) {
                const authorData = await parseJson(authorResponse);
                if (
                  authorData
                  && typeof (authorData as any).email === 'string'
                ) {
                  authorEmail = (authorData as any).email;
                }
              }
            } catch (err) {
              console.warn('[story-access] Failed to fetch author email for unsubscribe notice', err);
            }
          }

          const authorName = await fetchAuthorDisplayName(
            rpcUrl,
            credentials?.serviceKey,
            authorId,
            authorEmail,
          );

          // Send email notification
          const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #F0FAF9;">
  <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #F0FAF9;" cellpadding="0" cellspacing="0">
    <tr>
      <td style="padding: 40px 20px;" align="center">
        <table role="presentation" style="max-width: 600px; width: 100%; border-collapse: collapse; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);" cellpadding="0" cellspacing="0">
          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #4DB3A8 0%, #38827A 100%); padding: 40px 30px; text-align: center;">
              <h1 style="margin: 0; font-size: 32px; font-weight: bold; color: #FFFFFF;">Narra</h1>
              <p style="margin: 10px 0 0 0; font-size: 14px; color: #E0F5F3;">Historias que perduran para siempre</p>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="margin: 0 0 20px 0; font-size: 24px; font-weight: bold; color: #1F2937;">Te has desuscrito</h2>

              <p style="margin: 0 0 16px 0; font-size: 16px; line-height: 1.6; color: #6B7280;">
                Hola ${subscriberName},
              </p>

              <p style="margin: 0 0 16px 0; font-size: 16px; line-height: 1.6; color: #6B7280;">
                Confirmamos que te has desuscrito exitosamente y ya no recibirás más historias de ${authorName}.
              </p>

              <p style="margin: 0 0 16px 0; font-size: 16px; line-height: 1.6; color: #6B7280;">
                Tus enlaces mágicos han dejado de funcionar y ya no podrás acceder al contenido compartido.
              </p>

              <div style="background-color: #F0FAF9; border-left: 4px solid #4DB3A8; padding: 16px; margin: 24px 0; border-radius: 8px;">
                <p style="margin: 0; font-size: 14px; line-height: 1.6; color: #38827A;">
                  <strong>¿Cambias de opinión?</strong><br>
                  Si deseas volver a suscribirte en el futuro, por favor contacta directamente a ${authorName}.
                </p>
              </div>

              <p style="margin: 24px 0 0 0; font-size: 14px; line-height: 1.6; color: #9CA3AF;">
                Gracias por haber sido parte de esta comunidad de historias.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #F3F4F6; padding: 30px; text-align: center; border-top: 1px solid #E5E7EB;">
              <p style="margin: 0 0 8px 0; font-size: 14px; color: #6B7280;">
                Creado con <span style="color: #4DB3A8; font-weight: bold;">Narra</span>
              </p>
              <p style="margin: 0; font-size: 12px; color: #9CA3AF;">
                Historias que perduran para siempre
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
          `.trim();

          try {
            // Call the email API
            const emailApiUrl = new URL('/api/email', new URL(request.url).origin);
            const emailResponse = await fetch(emailApiUrl.toString(), {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                to: subscriberEmail,
                subject: `Te has desuscrito de las historias de ${authorName}`,
                html: emailHtml,
                tags: [
                  { name: 'type', value: 'unsubscribe' },
                  { name: 'author_id', value: authorId },
                  { name: 'subscriber_id', value: subscriberId },
                ],
              }),
            });

            if (emailResponse.ok) {
              console.log('[story-access] Unsubscribe email sent successfully', {
                subscriberEmail,
                authorId,
                subscriberId,
              });
            } else {
              console.error('[story-access] Failed to send unsubscribe email', {
                status: emailResponse.status,
                body: await emailResponse.text(),
              });
            }
          } catch (emailError) {
            console.error('[story-access] Error sending unsubscribe email', emailError);
          }
        }
      }

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
