interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

export const onRequestGet: PagesFunction<Env> = async ({ request, env }) => {
  return handleRevert(request, env);
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  return handleRevert(request, env);
};

async function handleRevert(request: Request, env: Env): Promise<Response> {
  try {
    // Validar configuración
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[email-change-revert] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    // Obtener el token desde query params o body
    const url = new URL(request.url);
    let token = url.searchParams.get('token');

    if (!token && request.method === 'POST') {
      const payload = await request.json().catch(() => null);
      if (payload && typeof payload === 'object') {
        token = typeof (payload as any).token === 'string'
          ? (payload as any).token.trim()
          : null;
      }
    }

    if (!token) {
      return json({ error: 'Token es requerido' }, 400);
    }

    console.log('[email-change-revert] Processing revert for token');

    // Buscar la solicitud de cambio de email
    const requestResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/email_change_requests?revert_token=eq.${token}&select=*`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!requestResponse.ok) {
      console.error('[email-change-revert] Failed to fetch request');
      return json({ error: 'Error al buscar solicitud' }, 500);
    }

    const requests = await requestResponse.json();

    if (!Array.isArray(requests) || requests.length === 0) {
      console.log('[email-change-revert] Request not found');
      return json({ error: 'Solicitud no encontrada o inválida' }, 404);
    }

    const changeRequest = requests[0];

    // Verificar que no haya sido revertida ya
    if (changeRequest.status === 'reverted') {
      console.log('[email-change-revert] Request already reverted');
      return json({
        error: 'Esta solicitud ya fue revertida anteriormente.'
      }, 400);
    }

    const userId = changeRequest.user_id;
    const oldEmail = changeRequest.old_email;
    const status = changeRequest.status;

    // Si el cambio ya fue confirmado, revertir el email en auth.users
    if (status === 'confirmed') {
      console.log('[email-change-revert] Change was confirmed, reverting email in auth.users...');

      const updateResponse = await fetch(
        `${env.SUPABASE_URL}/auth/v1/admin/users/${userId}`,
        {
          method: 'PUT',
          headers: {
            'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
            'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            email: oldEmail,
            email_confirm: true,
          }),
        }
      );

      if (!updateResponse.ok) {
        const errorText = await updateResponse.text();
        console.error('[email-change-revert] Failed to revert user email:', errorText);
        return json({ error: 'Error al revertir el email' }, 500);
      }

      console.log('[email-change-revert] Email reverted successfully in auth.users');
    }

    // Marcar la solicitud como revertida
    console.log('[email-change-revert] Marking request as reverted...');
    const revertResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/email_change_requests?id=eq.${changeRequest.id}`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({
          status: 'reverted',
          reverted_at: new Date().toISOString(),
        }),
      }
    );

    if (!revertResponse.ok) {
      console.error('[email-change-revert] Failed to update request status');
    }

    console.log('[email-change-revert] Email change reverted successfully');

    const message = status === 'confirmed'
      ? `El cambio de email ha sido revertido exitosamente. Tu email es ahora ${oldEmail}.`
      : `La solicitud de cambio de email ha sido cancelada. Tu email sigue siendo ${oldEmail}.`;

    return json({
      success: true,
      message: message,
      oldEmail: oldEmail,
      wasConfirmed: status === 'confirmed',
    });

  } catch (error) {
    console.error('[email-change-revert] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
}
