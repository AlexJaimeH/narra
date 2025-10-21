interface SupabaseEnv {
  SUPABASE_URL?: string;
  SUPABASE_REST_URL?: string;
  SUPABASE_URL_PUBLIC?: string;
  SUPABASE_PROJECT_URL?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_SERVICE_ROLE?: string;
  SUPABASE_SERVICE_KEY?: string;
  SUPABASE_ADMIN_KEY?: string;
  SUPABASE_SECRET_KEY?: string;
}

interface SupabaseCredentials {
  url: string;
  serviceKey: string;
}

interface SupabaseDiagnostics {
  hasUrl: boolean;
  hasServiceKey: boolean;
  resolvedUrl?: string;
  serviceKeySource?: string;
  availableKeys: string[];
}

const SUPABASE_URL_CANDIDATES = [
  "SUPABASE_URL",
  "SUPABASE_REST_URL",
  "SUPABASE_URL_PUBLIC",
  "SUPABASE_PROJECT_URL",
];

const SUPABASE_SERVICE_KEY_CANDIDATES = [
  "SUPABASE_SERVICE_ROLE_KEY",
  "SUPABASE_SERVICE_ROLE",
  "SUPABASE_SERVICE_KEY",
  "SUPABASE_ADMIN_KEY",
  "SUPABASE_SECRET_KEY",
];

export function resolveSupabaseConfig(
  env: SupabaseEnv,
): { credentials?: SupabaseCredentials; diagnostics: SupabaseDiagnostics } {
  let resolvedUrl: string | undefined;
  for (const key of SUPABASE_URL_CANDIDATES) {
    const value = env[key as keyof SupabaseEnv];
    if (typeof value === "string") {
      const trimmed = value.trim();
      if (trimmed.length > 0) {
        resolvedUrl = trimmed;
        break;
      }
    }
  }

  let serviceKey: string | undefined;
  let serviceKeySource: string | undefined;
  for (const key of SUPABASE_SERVICE_KEY_CANDIDATES) {
    const value = env[key as keyof SupabaseEnv];
    if (typeof value === "string") {
      const trimmed = value.trim();
      if (trimmed.length > 0) {
        serviceKey = trimmed;
        serviceKeySource = key;
        break;
      }
    }
  }

  const diagnostics: SupabaseDiagnostics = {
    hasUrl: Boolean(resolvedUrl),
    hasServiceKey: Boolean(serviceKey),
    resolvedUrl,
    serviceKeySource,
    availableKeys: Object.keys(env ?? {}),
  };

  if (resolvedUrl && serviceKey) {
    return {
      credentials: { url: resolvedUrl, serviceKey },
      diagnostics,
    };
  }

  return { diagnostics };
}

export function supabaseHeaders(serviceKey: string): Record<string, string> {
  return {
    "Content-Type": "application/json",
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
  };
}

export type { SupabaseEnv, SupabaseCredentials, SupabaseDiagnostics };
