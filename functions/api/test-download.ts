import {
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
  const log: string[] = [];

  try {
    log.push('1. Starting test endpoint');

    // Get authorization header
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      log.push('ERROR: No authorization header');
      return json({ error: 'No autorizado', log }, 401);
    }
    log.push('2. Auth header found');

    const token = authHeader.substring(7);
    log.push('3. Token extracted');

    const { credentials, diagnostics } = resolveSupabaseConfig(env);
    log.push(`4. Credentials resolved: hasUrl=${diagnostics.hasUrl}, hasServiceKey=${diagnostics.hasServiceKey}`);
    log.push(`   URL source: ${diagnostics.urlSource}`);
    log.push(`   Service key source: ${diagnostics.serviceKeySource}`);
    log.push(`   Available keys: ${diagnostics.availableKeys.join(', ')}`);

    const supabaseUrl = credentials?.url;
    const serviceKey = credentials?.serviceKey;

    if (!supabaseUrl || !serviceKey) {
      log.push('ERROR: Missing credentials');
      return json({ error: 'Configuración de servidor incorrecta', log, diagnostics }, 500);
    }

    log.push(`5. Supabase URL: ${supabaseUrl.substring(0, 30)}...`);
    log.push(`6. Service key length: ${serviceKey.length}`);

    // Verify token and get user
    log.push('7. Verifying token...');
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': serviceKey,
      },
    });

    log.push(`8. User response status: ${userResponse.status}`);

    if (!userResponse.ok) {
      const errorText = await userResponse.text();
      log.push(`ERROR: User verification failed: ${errorText.substring(0, 100)}`);
      return json({ error: 'Token inválido o expirado', log }, 401);
    }

    const user = await userResponse.json() as any;
    const userId = user.id;
    log.push(`9. User ID: ${userId}`);

    if (!userId) {
      log.push('ERROR: No user ID');
      return json({ error: 'Usuario no encontrado', log }, 404);
    }

    // Test simple query
    log.push('10. Testing simple user query...');
    const userProfileUrl = `${supabaseUrl}/rest/v1/users?id=eq.${userId}`;
    const userProfileRes = await fetch(userProfileUrl, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
      },
    });

    log.push(`11. User profile response status: ${userProfileRes.status}`);

    if (!userProfileRes.ok) {
      const errorText = await userProfileRes.text();
      log.push(`ERROR: User profile query failed: ${errorText.substring(0, 200)}`);
    } else {
      const profiles = await userProfileRes.json();
      log.push(`12. User profiles found: ${profiles.length}`);
      if (profiles.length > 0) {
        log.push(`    User name: ${profiles[0].name}`);
      }
    }

    // Test stories query
    log.push('13. Testing stories query...');
    const storiesUrl = `${supabaseUrl}/rest/v1/stories?user_id=eq.${userId}&order=created_at.desc&limit=1`;
    const storiesRes = await fetch(storiesUrl, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
      },
    });

    log.push(`14. Stories response status: ${storiesRes.status}`);

    if (!storiesRes.ok) {
      const errorText = await storiesRes.text();
      log.push(`ERROR: Stories query failed: ${errorText.substring(0, 200)}`);
    } else {
      const stories = await storiesRes.json();
      log.push(`15. Stories found: ${stories.length}`);
      if (stories.length > 0) {
        log.push(`    First story title: ${stories[0].title}`);
      }
    }

    log.push('16. All tests completed successfully!');

    return json({
      success: true,
      userId,
      log,
      diagnostics
    }, 200);

  } catch (error: any) {
    log.push(`EXCEPTION: ${error.message}`);
    log.push(`Stack: ${error.stack?.substring(0, 500)}`);
    return json({
      error: 'Error en test',
      detail: error?.message || String(error),
      log,
    }, 500);
  }
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
