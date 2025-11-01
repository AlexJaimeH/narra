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
  try {
    // Get authorization header
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return json({ error: 'No autorizado' }, 401);
    }

    const token = authHeader.substring(7);

    const { credentials } = resolveSupabaseConfig(env);
    const supabaseUrl = credentials?.url;
    const serviceKey = credentials?.serviceKey;

    if (!supabaseUrl || !serviceKey) {
      console.error('[download-user-data] Missing Supabase credentials');
      return json({
        error: 'Configuración de servidor incorrecta',
      }, 500);
    }

    // Verify token and get user
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': serviceKey,
      },
    });

    if (!userResponse.ok) {
      return json({ error: 'Token inválido o expirado' }, 401);
    }

    const user = await userResponse.json() as any;
    const userId = user.id;

    if (!userId) {
      return json({ error: 'Usuario no encontrado' }, 404);
    }

    // Fetch user data
    const [userProfile, userSettings, stories, subscribers, tags] = await Promise.all([
      fetchFromSupabase(supabaseUrl, serviceKey, 'users', `id=eq.${userId}`),
      fetchFromSupabase(supabaseUrl, serviceKey, 'user_settings', `user_id=eq.${userId}`),
      fetchFromSupabase(supabaseUrl, serviceKey, 'stories', `author_id=eq.${userId}&order=created_at.desc`),
      fetchFromSupabase(supabaseUrl, serviceKey, 'subscribers', `author_id=eq.${userId}&order=created_at.desc`),
      fetchFromSupabase(supabaseUrl, serviceKey, 'tags', `author_id=eq.${userId}&order=name.asc`),
    ]);

    // Fetch related data for each story
    const storiesWithDetails = await Promise.all(
      stories.map(async (story: any) => {
        const [photos, recordings, comments, reactions, storyTags, versions] = await Promise.all([
          fetchFromSupabase(supabaseUrl, serviceKey, 'story_photos', `story_id=eq.${story.id}&order=position.asc`),
          fetchFromSupabase(supabaseUrl, serviceKey, 'voice_recordings', `story_id=eq.${story.id}&order=created_at.asc`),
          fetchFromSupabase(supabaseUrl, serviceKey, 'story_comments', `story_id=eq.${story.id}&order=created_at.asc`),
          fetchFromSupabase(supabaseUrl, serviceKey, 'story_reactions', `story_id=eq.${story.id}`),
          fetchFromSupabase(supabaseUrl, serviceKey, 'story_tags', `story_id=eq.${story.id}`),
          fetchFromSupabase(supabaseUrl, serviceKey, 'story_versions', `story_id=eq.${story.id}&order=version_number.asc`),
        ]);

        return {
          ...story,
          photos,
          recordings,
          comments,
          reactions,
          tags: storyTags,
          versions,
        };
      })
    );

    // Organize data by status
    const draftStories = storiesWithDetails.filter((s: any) => !s.is_published);
    const publishedStories = storiesWithDetails.filter((s: any) => s.is_published);

    // Create the complete data export
    const exportData = {
      metadata: {
        exportedAt: new Date().toISOString(),
        userId: userId,
        userEmail: user.email,
      },
      profile: userProfile[0] || {},
      settings: userSettings[0] || {},
      stories: {
        drafts: draftStories,
        published: publishedStories,
        total: storiesWithDetails.length,
      },
      subscribers: subscribers,
      tags: tags,
      instructions: {
        es: 'Este archivo contiene todos tus datos de Narra. Las URLs de fotos y grabaciones son enlaces públicos que puedes usar para descargar los archivos multimedia.',
        en: 'This file contains all your Narra data. Photo and recording URLs are public links you can use to download the media files.',
      },
    };

    // Return as JSON download
    const jsonString = JSON.stringify(exportData, null, 2);

    return new Response(jsonString, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Content-Disposition': `attachment; filename="narra-data-${userId}-${Date.now()}.json"`,
        ...CORS_HEADERS,
      },
    });

  } catch (error) {
    console.error('[download-user-data] Error:', error);
    return json({ error: 'Error al generar descarga de datos', detail: String(error) }, 500);
  }
};

async function fetchFromSupabase(
  supabaseUrl: string,
  serviceKey: string,
  table: string,
  query: string
): Promise<any[]> {
  try {
    const url = `${supabaseUrl}/rest/v1/${table}?${query}`;
    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceKey,
        'Authorization': `Bearer ${serviceKey}`,
      },
    });

    if (!response.ok) {
      console.error(`[download-user-data] Failed to fetch ${table}:`, response.status);
      return [];
    }

    return await response.json();
  } catch (error) {
    console.error(`[download-user-data] Error fetching ${table}:`, error);
    return [];
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}
