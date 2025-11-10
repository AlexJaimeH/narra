interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
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

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString('es-MX', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
}

export const onRequestGet: PagesFunction<Env> = async ({ request, env }) => {
  try {
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      console.error('[gift-management-download-data] Missing Supabase configuration');
      return json({ error: 'Server configuration error' }, 500);
    }

    const url = new URL(request.url);
    const token = url.searchParams.get('token');

    if (!token) {
      return json({ error: 'Token es requerido' }, 400);
    }

    console.log('[gift-management-download-data] Validating token...');

    // Validate token
    const tokenResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/gift_management_tokens?management_token=eq.${token}&select=*`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!tokenResponse.ok) {
      return json({ error: 'Error al validar token' }, 500);
    }

    const tokens = await tokenResponse.json();

    if (!Array.isArray(tokens) || tokens.length === 0) {
      return json({ error: 'Token inválido' }, 401);
    }

    const tokenData = tokens[0];
    const authorUserId = tokenData.author_user_id;

    // Get author email
    const userResponse = await fetch(
      `${env.SUPABASE_URL}/auth/v1/admin/users/${authorUserId}`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    const userData = await userResponse.json();
    const authorEmail = userData.email || 'autor';

    // Get published stories
    console.log('[gift-management-download-data] Getting published stories...');
    const storiesResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/stories?user_id=eq.${authorUserId}&status=eq.published&select=id,title,content,excerpt,created_at,published_at&order=published_at.desc`,
      {
        headers: {
          'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': env.SUPABASE_SERVICE_ROLE_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!storiesResponse.ok) {
      return json({ error: 'Error al obtener historias' }, 500);
    }

    const stories = await storiesResponse.json();

    if (!Array.isArray(stories) || stories.length === 0) {
      return json({ error: 'No hay historias publicadas para descargar' }, 404);
    }

    // Generate text content
    console.log('[gift-management-download-data] Generating download file...');

    let textContent = `========================================
HISTORIAS DE ${authorEmail.toUpperCase()}
Descargado: ${formatDate(new Date().toISOString())}
Total de historias: ${stories.length}
========================================

NOTA: Esta descarga incluye solo el texto de las historias publicadas.
No incluye fotos, grabaciones de voz, borradores ni historial de versiones.
Para una descarga completa, el autor debe hacerlo desde su cuenta en /app/settings.

========================================

`;

    stories.forEach((story: any, index: number) => {
      textContent += `
${'='.repeat(80)}
HISTORIA ${index + 1} DE ${stories.length}
${'='.repeat(80)}

Título: ${story.title || 'Sin título'}
Fecha de publicación: ${story.published_at ? formatDate(story.published_at) : 'Sin fecha'}
Fecha de creación: ${formatDate(story.created_at)}

${story.excerpt ? `Extracto:\n${story.excerpt}\n\n` : ''}
${'─'.repeat(80)}

${story.content || 'Sin contenido'}

${'='.repeat(80)}

`;
    });

    textContent += `
========================================
FIN DEL DOCUMENTO
========================================
`;

    console.log('[gift-management-download-data] Download file generated successfully');

    // Return as downloadable file
    return new Response(textContent, {
      status: 200,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Content-Disposition': `attachment; filename="narra-historias-${new Date().toISOString().split('T')[0]}.txt"`,
        ...CORS_HEADERS,
      },
    });

  } catch (error) {
    console.error('[gift-management-download-data] Unexpected error:', error);
    return json({ error: 'Internal server error' }, 500);
  }
};
