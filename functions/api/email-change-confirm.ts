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
  return handleConfirm(request, env);
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  return handleConfirm(request, env);
};

async function handleConfirm(request: Request, env: Env): Promise<Response> {
  try {
    // Validar configuración
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[email-change-confirm] Missing Supabase configuration');
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

    console.log('[email-change-confirm] Processing confirmation for token');

    // Buscar la solicitud de cambio de email
    const requestResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/email_change_requests?confirmation_token=eq.${token}&select=*`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!requestResponse.ok) {
      console.error('[email-change-confirm] Failed to fetch request');
      return json({ error: 'Error al buscar solicitud' }, 500);
    }

    const requests = await requestResponse.json();

    if (!Array.isArray(requests) || requests.length === 0) {
      console.log('[email-change-confirm] Request not found');
      return json({ error: 'Solicitud no encontrada o inválida' }, 404);
    }

    const changeRequest = requests[0];

    // Verificar que la solicitud esté pendiente
    if (changeRequest.status !== 'pending') {
      console.log('[email-change-confirm] Request already processed:', changeRequest.status);
      return json({
        error: `Esta solicitud ya fue ${changeRequest.status === 'confirmed' ? 'confirmada' : 'cancelada'}.`
      }, 400);
    }

    const userId = changeRequest.user_id;
    const newEmail = changeRequest.new_email;

    // Verificar nuevamente que el nuevo email no esté en uso
    console.log('[email-change-confirm] Checking if new email is still available...');
    const usersResponse = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/users`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!usersResponse.ok) {
      console.error('[email-change-confirm] Failed to check users');
      return json({ error: 'Error al verificar disponibilidad del email' }, 500);
    }

    const usersData = await usersResponse.json();
    const users = usersData.users || [];
    const emailExists = users.some((user: any) =>
      user.email?.toLowerCase() === newEmail.toLowerCase() && user.id !== userId
    );

    if (emailExists) {
      console.log('[email-change-confirm] Email is now in use');
      // Marcar como cancelada
      await fetch(
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
            status: 'cancelled',
            cancelled_at: new Date().toISOString(),
          }),
        }
      );

      return json({
        error: 'Este email ya está registrado con otra cuenta. La solicitud ha sido cancelada.'
      }, 400);
    }

    // Actualizar el email en auth.users usando Supabase Admin API
    console.log('[email-change-confirm] Updating user email in auth.users...');
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
          email: newEmail,
          email_confirm: true,
        }),
      }
    );

    if (!updateResponse.ok) {
      const errorText = await updateResponse.text();
      console.error('[email-change-confirm] Failed to update user email:', errorText);
      return json({ error: 'Error al actualizar el email' }, 500);
    }

    // Marcar la solicitud como confirmada
    console.log('[email-change-confirm] Marking request as confirmed...');
    const confirmResponse = await fetch(
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
          status: 'confirmed',
          confirmed_at: new Date().toISOString(),
        }),
      }
    );

    if (!confirmResponse.ok) {
      console.error('[email-change-confirm] Failed to update request status');
    }

    console.log('[email-change-confirm] Email change confirmed successfully');

    return json({
      success: true,
      message: 'Email cambiado exitosamente. Ahora puedes iniciar sesión con tu nuevo email.',
      newEmail: newEmail,
    });

  } catch (error) {
    console.error('[email-change-confirm] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
}
