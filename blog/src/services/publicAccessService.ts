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
  grantedAt: string;
  token: string;
  source: string;
  subscriber: {
    id: string;
    name?: string;
    email?: string;
    status?: string;
  };
  unsubscribed: boolean;
  supabase?: {
    url: string;
    anonKey: string;
  };
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
        return null;
      }

      const data: RegisterAccessResponse = await response.json();

      // If unsubscribed, return null
      if (data.unsubscribed) {
        return null;
      }

      const accessRecord: StoryAccessRecord = {
        authorId: params.authorId,
        subscriberId: params.subscriberId,
        subscriberName: data.subscriber?.name,
        accessToken: data.token,
        source: data.source || params.source,
        grantedAt: data.grantedAt,
        status: (data.subscriber?.status === 'unsubscribed' ? 'revoked' : 'active') as 'active' | 'revoked',
        supabaseUrl: data.supabase?.url,
        supabaseAnonKey: data.supabase?.anonKey,
      };

      return accessRecord;
    } catch (error) {
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
