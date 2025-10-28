import { StoryAccessRecord } from '../types';

const API_BASE = '/api';

export interface RegisterAccessParams {
  authorId: string;
  subscriberId: string;
  token: string;
  storyId?: string;
  source?: string;
  eventType?: 'access_granted' | 'invite_opened';
}

export interface RegisterAccessResponse {
  authorId: string;
  subscriberId: string;
  subscriberName?: string;
  accessToken: string;
  status: 'active' | 'revoked';
  supabaseUrl?: string;
  supabaseAnonKey?: string;
}

export const publicAccessService = {
  async registerAccess(params: RegisterAccessParams): Promise<StoryAccessRecord | null> {
    try {
      const response = await fetch(`${API_BASE}/story-access`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(params),
      });

      if (!response.ok) {
        console.error('Failed to register access:', response.status, response.statusText);
        return null;
      }

      const data: RegisterAccessResponse = await response.json();

      return {
        authorId: data.authorId,
        subscriberId: data.subscriberId,
        subscriberName: data.subscriberName,
        accessToken: data.accessToken,
        source: params.source,
        grantedAt: new Date().toISOString(),
        status: data.status,
        supabaseUrl: data.supabaseUrl,
        supabaseAnonKey: data.supabaseAnonKey,
      };
    } catch (error) {
      console.error('Error registering access:', error);
      return null;
    }
  },

  parseSharePayloadFromUrl(): {
    authorId?: string;
    subscriberId?: string;
    token?: string;
    subscriberName?: string;
    source?: string;
  } {
    const params = new URLSearchParams(window.location.search);
    return {
      authorId: params.get('author') || undefined,
      subscriberId: params.get('subscriber') || undefined,
      token: params.get('token') || undefined,
      subscriberName: params.get('name') || undefined,
      source: params.get('source') || undefined,
    };
  },
};
