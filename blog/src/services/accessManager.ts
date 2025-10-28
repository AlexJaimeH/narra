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
      console.warn('Failed to store access in localStorage:', e);
    }

    // Store in cookie (for cross-tab persistence)
    try {
      const maxAge = 90 * 24 * 60 * 60; // 90 days
      document.cookie = `${COOKIE_NAME}=${encodeURIComponent(data)}; path=/; max-age=${maxAge}; SameSite=Lax`;
    } catch (e) {
      console.warn('Failed to store access in cookie:', e);
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
      console.warn('Failed to read access from localStorage:', e);
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
      console.warn('Failed to read access from cookie:', e);
    }

    return null;
  },

  revokeAccess(): void {
    // Remove from localStorage
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch (e) {
      console.warn('Failed to remove access from localStorage:', e);
    }

    // Remove cookie
    try {
      document.cookie = `${COOKIE_NAME}=; path=/; max-age=0`;
    } catch (e) {
      console.warn('Failed to remove access cookie:', e);
    }
  },

  hasAccess(authorId: string): boolean {
    const record = this.getAccess();
    return record !== null && record.authorId === authorId && record.status === 'active';
  },
};
