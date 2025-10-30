import { Story, PublicAuthorProfile } from '../types';
import { accessManager } from './accessManager';

// We'll use the Supabase credentials from the access record
let supabaseClient: any = null;

async function getSupabaseClient() {
  if (supabaseClient) return supabaseClient;

  const accessRecord = accessManager.getAccess();

  if (!accessRecord?.supabaseUrl || !accessRecord?.supabaseAnonKey) {
    throw new Error('No valid access credentials found');
  }

  // Import Supabase client
  const { createClient } = await import('@supabase/supabase-js');
  supabaseClient = createClient(accessRecord.supabaseUrl, accessRecord.supabaseAnonKey);

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
          tags:story_tags(tag_id, tags(id, name, color))
        `)
        .eq('id', storyId)
        .eq('status', 'published')
        .single();

      if (error) {
        return null;
      }

      return this.transformStory(data);
    } catch (error) {
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
          tags:story_tags(tag_id, tags(id, name, color))
        `)
        .eq('user_id', authorId)
        .eq('status', 'published')
        .order('published_at', { ascending: false })
        .limit(limit);

      if (error) {
        return [];
      }

      return (data || []).map(this.transformStory);
    } catch (error) {
      return [];
    }
  },

  async getAuthorProfile(authorId: string): Promise<PublicAuthorProfile | null> {
    try {
      const client = await getSupabaseClient();

      const { data, error } = await client
        .from('user_settings')
        .select('*')
        .eq('user_id', authorId)
        .single();

      if (error) {
        return null;
      }

      return {
        userId: data.user_id,
        displayName: data.public_author_name || 'Mi Blog',
        name: data.public_author_name || 'Mi Blog',
        avatarUrl: data.public_blog_avatar_url,
        tagline: data.public_author_tagline,
        summary: data.public_author_summary,
        coverImageUrl: data.public_blog_cover_url,
      };
    } catch (error) {
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
      storyDate: data.story_date,
      startDate: data.start_date || data.story_date,
      endDate: data.end_date,
      datesPrecision: data.dates_precision,
      photos: data.photos?.sort((a: any, b: any) => a.display_order - b.display_order).map((p: any) => ({
        id: p.id,
        storyId: p.story_id,
        photoUrl: p.photo_url,
        caption: p.caption,
        displayOrder: p.display_order,
        createdAt: p.created_at,
      })),
      tags: data.tags?.map((t: any) => {
        const tagData = t.tags || t;
        return {
          id: tagData.id || t.tag_id,
          storyId: data.id,
          tag: tagData.name || tagData.tag || '',
          name: tagData.name || tagData.tag || '',
          color: tagData.color,
          createdAt: t.created_at,
        };
      }),
    };
  },
};
