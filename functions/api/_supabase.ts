interface SupabaseEnv {
  SUPABASE_URL?: string;
  SUPABASE_REST_URL?: string;
  SUPABASE_URL_PUBLIC?: string;
  SUPABASE_PROJECT_URL?: string;
  PUBLIC_SUPABASE_URL?: string;
  PUBLIC_SUPABASE_REST_URL?: string;
  PUBLIC_SUPABASE_PROJECT_URL?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_SERVICE_ROLE?: string;
  SUPABASE_SERVICE_KEY?: string;
  SUPABASE_ADMIN_KEY?: string;
  SUPABASE_SECRET_KEY?: string;
  SUPABASE_SERVICE_ROLE_TOKEN?: string;
  PUBLIC_SUPABASE_SERVICE_ROLE_KEY?: string;
  PUBLIC_SUPABASE_SERVICE_ROLE?: string;
  SUPABASE?: string | Record<string, unknown>;
  SUPABASE_CONFIG?: string | Record<string, unknown>;
  SUPABASE_CREDENTIALS?: string | Record<string, unknown>;
  PUBLIC_SUPABASE?: string | Record<string, unknown>;
}

interface SupabaseCredentials {
  url: string;
  serviceKey: string;
}

interface SupabaseDiagnostics {
  hasUrl: boolean;
  hasServiceKey: boolean;
  resolvedUrl?: string;
  urlSource?: string;
  serviceKeySource?: string;
  availableKeys: string[];
}

const SUPABASE_URL_CANDIDATES = [
  "SUPABASE_URL",
  "SUPABASE_REST_URL",
  "SUPABASE_URL_PUBLIC",
  "SUPABASE_PROJECT_URL",
  "PUBLIC_SUPABASE_URL",
  "PUBLIC_SUPABASE_REST_URL",
  "PUBLIC_SUPABASE_PROJECT_URL",
];

const SUPABASE_SERVICE_KEY_CANDIDATES = [
  "SUPABASE_SERVICE_ROLE_KEY",
  "SUPABASE_SERVICE_ROLE",
  "SUPABASE_SERVICE_KEY",
  "SUPABASE_ADMIN_KEY",
  "SUPABASE_SECRET_KEY",
  "SUPABASE_SERVICE_ROLE_TOKEN",
  "PUBLIC_SUPABASE_SERVICE_ROLE_KEY",
  "PUBLIC_SUPABASE_SERVICE_ROLE",
];

const SUPABASE_COMPOSITE_CANDIDATES = [
  "SUPABASE",
  "SUPABASE_CONFIG",
  "SUPABASE_CREDENTIALS",
  "PUBLIC_SUPABASE",
];

const COMPOSITE_URL_KEYS = [
  "url",
  "restUrl",
  "rest_url",
  "rest",
  "projectUrl",
  "project_url",
];

const COMPOSITE_SERVICE_KEY_KEYS = [
  "serviceKey",
  "service_key",
  "serviceRoleKey",
  "service_role_key",
  "serviceRole",
  "service_role",
  "serviceToken",
  "service_token",
];

export function resolveSupabaseConfig(
  env: SupabaseEnv,
): { credentials?: SupabaseCredentials; diagnostics: SupabaseDiagnostics } {
  const recordEnv = (env ?? {}) as Record<string, unknown>;

  const readString = (key: string): string | undefined => {
    const value = recordEnv[key];
    if (typeof value === "string") {
      const trimmed = value.trim();
      if (trimmed.length > 0) {
        return trimmed;
      }
    }
    return undefined;
  };

  let resolvedUrl: string | undefined;
  let urlSource: string | undefined;
  for (const key of SUPABASE_URL_CANDIDATES) {
    const value = readString(key);
    if (value) {
      resolvedUrl = value;
      urlSource = key;
      break;
    }
  }

  let serviceKey: string | undefined;
  let serviceKeySource: string | undefined;
  for (const key of SUPABASE_SERVICE_KEY_CANDIDATES) {
    const value = readString(key);
    if (value) {
      serviceKey = value;
      serviceKeySource = key;
      break;
    }
  }

  const parsedCompositeSources: string[] = [];

  const parseComposite = (
    raw: unknown,
  ): Record<string, unknown> | undefined => {
    if (typeof raw === "string") {
      const trimmed = raw.trim();
      if (trimmed.length === 0) return undefined;
      try {
        const parsed = JSON.parse(trimmed);
        if (parsed && typeof parsed === "object") {
          return parsed as Record<string, unknown>;
        }
      } catch (_) {
        return undefined;
      }
      return undefined;
    }
    if (raw && typeof raw === "object") {
      return raw as Record<string, unknown>;
    }
    return undefined;
  };

  const extractCompositeString = (
    source: Record<string, unknown>,
    keys: string[],
  ): { value?: string; keyName?: string } => {
    for (const key of keys) {
      const candidate = source[key];
      if (typeof candidate === "string") {
        const trimmed = candidate.trim();
        if (trimmed.length > 0) {
          return { value: trimmed, keyName: key };
        }
      }
    }
    return {};
  };

  if (!resolvedUrl || !serviceKey) {
    for (const candidate of SUPABASE_COMPOSITE_CANDIDATES) {
      const composite = parseComposite(recordEnv[candidate]);
      if (!composite) continue;
      parsedCompositeSources.push(candidate);

      if (!resolvedUrl) {
        const { value, keyName } = extractCompositeString(
          composite,
          COMPOSITE_URL_KEYS,
        );
        if (value) {
          resolvedUrl = value;
          urlSource = `${candidate}.${keyName ?? "url"}`;
        }
      }

      if (!serviceKey) {
        const { value, keyName } = extractCompositeString(
          composite,
          COMPOSITE_SERVICE_KEY_KEYS,
        );
        if (value) {
          serviceKey = value;
          serviceKeySource = `${candidate}.${keyName ?? "serviceKey"}`;
        }
      }

      if (resolvedUrl && serviceKey) {
        break;
      }
    }
  }

  let availableKeys: string[] = [];
  try {
    availableKeys = Object.keys(recordEnv);
  } catch (_) {
    availableKeys = [
      ...SUPABASE_URL_CANDIDATES,
      ...SUPABASE_SERVICE_KEY_CANDIDATES,
      ...SUPABASE_COMPOSITE_CANDIDATES,
    ].filter((key) => recordEnv[key] !== undefined);
  }

  if (parsedCompositeSources.length > 0) {
    availableKeys = Array.from(
      new Set([...availableKeys, ...parsedCompositeSources]),
    );
  }

  const diagnostics: SupabaseDiagnostics = {
    hasUrl: Boolean(resolvedUrl),
    hasServiceKey: Boolean(serviceKey),
    resolvedUrl,
    urlSource,
    serviceKeySource,
    availableKeys,
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
