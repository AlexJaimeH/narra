export interface OpenAIHeaderConfig {
  /** Primary API key used to authenticate against OpenAI */
  apiKey: string | null | undefined;
  /** Optional project id to scope requests (e.g. proj_...) */
  projectId?: string | null | undefined;
  /** Optional organization id */
  organizationId?: string | null | undefined;
}

const PROJECT_KEY_PREFIX = 'sk-proj-';

export const deriveProjectIdFromKey = (key?: string | null): string | null => {
  if (!key) return null;
  if (!key.startsWith(PROJECT_KEY_PREFIX)) return null;
  const remainder = key.slice(PROJECT_KEY_PREFIX.length);
  const dashIndex = remainder.indexOf('-');
  if (dashIndex <= 0) {
    return remainder.startsWith('proj_') ? remainder : null;
  }

  const candidate = remainder.slice(0, dashIndex);
  return candidate.startsWith('proj_') ? candidate : null;
};

export const buildOpenAIHeaders = (
  config: OpenAIHeaderConfig,
): Record<string, string> => {
  if (!config.apiKey) {
    throw new Error('Missing OpenAI API key');
  }

  const headers: Record<string, string> = {
    Authorization: `Bearer ${config.apiKey}`,
  };

  const resolvedProjectId =
    config.projectId ?? deriveProjectIdFromKey(config.apiKey);
  if (resolvedProjectId) {
    headers['OpenAI-Project'] = resolvedProjectId;
  }

  if (config.organizationId) {
    headers['OpenAI-Organization'] = config.organizationId;
  }

  return headers;
};

