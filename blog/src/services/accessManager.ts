import { StoryAccessRecord } from '../types';

const STORAGE_KEY = 'narra_subscriber_access';
const COOKIE_NAME = 'narra_subscriber_access';

export const accessManager = {
  grantAccess(record: StoryAccessRecord): void {
    const data = JSON.stringify(record);

    // Store in localStorage
    try {
      localStorage.setItem(STORAGE_KEY, data);
    } catch (e) {
      // Silently fail
    }

    // Store in cookie (for cross-tab persistence)
    try {
      const maxAge = 90 * 24 * 60 * 60; // 90 days
      document.cookie = `${COOKIE_NAME}=${encodeURIComponent(data)}; path=/; max-age=${maxAge}; SameSite=Lax`;
    } catch (e) {
      // Silently fail
    }
  },

  getAccess(): StoryAccessRecord | null {
    // Try localStorage first
    try {
      const data = localStorage.getItem(STORAGE_KEY);
      if (data) {
        return JSON.parse(data) as StoryAccessRecord;
      }
    } catch (e) {
      // Silently fail
    }

    // Fallback to cookie
    try {
      const cookies = document.cookie.split(';');
      for (const cookie of cookies) {
        const [name, value] = cookie.trim().split('=');
        if (name === COOKIE_NAME) {
          return JSON.parse(decodeURIComponent(value)) as StoryAccessRecord;
        }
      }
    } catch (e) {
      // Silently fail
    }

    return null;
  },

  revokeAccess(): void {
    // Remove from localStorage
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch (e) {
      // Silently fail
    }

    // Remove cookie
    try {
      document.cookie = `${COOKIE_NAME}=; path=/; max-age=0`;
    } catch (e) {
      // Silently fail
    }
  },

  hasAccess(authorId: string): boolean {
    const record = this.getAccess();
    return record !== null && record.authorId === authorId && record.status === 'active';
  },
};
