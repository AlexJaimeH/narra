import { Story, PublicAuthorProfile } from '../types';
import { accessManager } from './accessManager';

// We'll use the Supabase credentials from the access record
let supabaseClient: any = null;

async function getSupabaseClient() {
  if (supabaseClient) return supabaseClient;

  const accessRecord = accessManager.getAccess();
  console.log('[storyService] Access record:', {
    hasUrl: !!accessRecord?.supabaseUrl,
    hasKey: !!accessRecord?.supabaseAnonKey,
    url: accessRecord?.supabaseUrl,
  });

  if (!accessRecord?.supabaseUrl || !accessRecord?.supabaseAnonKey) {
    console.error('[storyService] Missing Supabase credentials:', accessRecord);
    throw new Error('No valid access credentials found');
  }

  // Import Supabase client
  const { createClient } = await import('@supabase/supabase-js');
  supabaseClient = createClient(accessRecord.supabaseUrl, accessRecord.supabaseAnonKey);
  console.log('[storyService] Supabase client created');

  return supabaseClient;
}

export const storyService = {
  async getStory(storyId: string): Promise<Story | null> {
    try {
      const client = await getSupabaseClient();

      const { data, error } = await client
        .from('stories')
        .select(`
          *,
          photos:story_photos(*),
          tags:story_tags(*)
        `)
        .eq('id', storyId)
        .eq('status', 'published')
        .single();

      if (error) {
        console.error('Error fetching story:', error);
        return null;
      }

      return this.transformStory(data);
    } catch (error) {
      console.error('Error in getStory:', error);
      return null;
    }
  },

  async getLatestStories(authorId: string, limit: number = 10): Promise<Story[]> {
    try {
      const client = await getSupabaseClient();

      const { data, error } = await client
        .from('stories')
        .select(`
          *,
          photos:story_photos(*),
          tags:story_tags(*)
        `)
        .eq('user_id', authorId)
        .eq('status', 'published')
        .order('published_at', { ascending: false })
        .limit(limit);

      if (error) {
        console.error('Error fetching stories:', error);
        return [];
      }

      return (data || []).map(this.transformStory);
    } catch (error) {
      console.error('Error in getLatestStories:', error);
      return [];
    }
  },

  async getAuthorProfile(authorId: string): Promise<PublicAuthorProfile | null> {
    try {
      const client = await getSupabaseClient();

      const { data, error } = await client
        .from('user_profiles')
        .select('*')
        .eq('user_id', authorId)
        .single();

      if (error) {
        console.error('Error fetching author profile:', error);
        return null;
      }

      return {
        userId: data.user_id,
        displayName: data.display_name || data.name || 'Autor',
        name: data.name || data.display_name || 'Autor',
        avatarUrl: data.avatar_url,
        tagline: data.tagline,
        summary: data.summary,
        coverImageUrl: data.cover_image_url,
      };
    } catch (error) {
      console.error('Error in getAuthorProfile:', error);
      return null;
    }
  },

  transformStory(data: any): Story {
    return {
      id: data.id,
      userId: data.user_id,
      title: data.title,
      content: data.content,
      status: data.status,
      publishedAt: data.published_at,
      createdAt: data.created_at,
      updatedAt: data.updated_at,
      authorName: data.author_name,
      authorDisplayName: data.author_display_name,
      authorAvatarUrl: data.author_avatar_url,
      photos: data.photos?.sort((a: any, b: any) => a.display_order - b.display_order).map((p: any) => ({
        id: p.id,
        storyId: p.story_id,
        photoUrl: p.photo_url,
        caption: p.caption,
        displayOrder: p.display_order,
        createdAt: p.created_at,
      })),
      tags: data.tags?.map((t: any) => ({
        id: t.id,
        storyId: t.story_id,
        tag: t.tag,
        createdAt: t.created_at,
      })),
    };
  },
};
