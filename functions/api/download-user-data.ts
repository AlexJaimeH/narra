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
  // ULTRA SIMPLIFIED VERSION FOR DEBUGGING
  try {
    // Get authorization header
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'No autorizado' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS }
      });
    }

    const token = authHeader.substring(7);

    const { credentials } = resolveSupabaseConfig(env);
    const supabaseUrl = credentials?.url;
    const serviceKey = credentials?.serviceKey;

    if (!supabaseUrl || !serviceKey) {
      return new Response(JSON.stringify({ error: 'Configuración incorrecta' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS }
      });
    }

    // Verify token and get user
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': serviceKey,
      },
    });

    if (!userResponse.ok) {
      return new Response(JSON.stringify({ error: 'Token inválido' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS }
      });
    }

    const user = await userResponse.json() as any;
    const userId = user.id;

    if (!userId) {
      return new Response(JSON.stringify({ error: 'Usuario no encontrado' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS }
      });
    }

    // TEST: Just return simple text file
    const testContent = `Descarga de Datos - narra.mx
===========================================

Usuario ID: ${userId}
Email: ${user.email || 'N/A'}
Fecha de descarga: ${new Date().toISOString()}

Esta es una versión simplificada de prueba.
La versión completa con ZIP se habilitará una vez
resuelto el problema actual.
`;

    return new Response(testContent, {
      status: 200,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Content-Disposition': `attachment; filename="narra-datos-test-${Date.now()}.txt"`,
        ...CORS_HEADERS,
      },
    });

  } catch (error) {
    // Even if this fails, return 500 with details
    const errorMsg = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({
      error: 'Error en el servidor',
      detail: errorMsg
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...CORS_HEADERS }
    });
  }
};
