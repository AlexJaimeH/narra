export function fallbackAuthorNameFromEmail(
  email?: string | null,
  defaultLabel = 'Tu autor/a en Narra',
): string {
  if (typeof email === 'string') {
    const [localPart] = email.split('@');
    const normalized = localPart?.trim();
    if (normalized && normalized.length > 0) {
      return normalized;
    }
  }
  return defaultLabel;
}

export async function fetchAuthorDisplayName(
  supabaseUrl: string | undefined,
  serviceRoleKey: string | undefined,
  authorUserId: string,
  fallbackEmail?: string | null,
): Promise<string> {
  if (!supabaseUrl || !serviceRoleKey || !authorUserId) {
    return fallbackAuthorNameFromEmail(fallbackEmail);
  }

  try {
    const url = new URL('/rest/v1/user_settings', supabaseUrl);
    url.searchParams.set('user_id', `eq.${authorUserId}`);
    url.searchParams.set('select', 'public_author_name');
    url.searchParams.set('limit', '1');

    const response = await fetch(url.toString(), {
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
    });

    if (response.ok) {
      const data = await response.json().catch(() => null);
      if (Array.isArray(data) && data.length > 0) {
        const entry = data[0] as Record<string, unknown>;
        const publicName = entry?.public_author_name;
        if (typeof publicName === 'string') {
          const normalized = publicName.trim();
          if (normalized.length > 0) {
            return normalized;
          }
        }
      }
    } else {
      console.warn('[author-name] Failed to fetch author settings', {
        status: response.status,
      });
    }
  } catch (error) {
    console.warn('[author-name] Error while fetching display name', error);
  }

  return fallbackAuthorNameFromEmail(fallbackEmail);
}
