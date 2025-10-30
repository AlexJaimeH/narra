import {
  resolveSupabaseConfig,
  type SupabaseEnv,
  type SupabaseCredentials,
} from "./_supabase";

interface Env extends SupabaseEnv {}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    const body = await request.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return json({ error: "invalid_body" }, 400);
    }

    const action = normalizeAction((body as any).action);
    if (!action) {
      return json({ error: "action_required" }, 400);
    }

    const authorId = normalizeId(
      (body as any).authorId ?? (body as any).author_id,
    );
    const subscriberId = normalizeId(
      (body as any).subscriberId ?? (body as any).subscriber_id,
    );
    const storyId = normalizeId(
      (body as any).storyId ?? (body as any).story_id,
    );
    const token =
      typeof (body as any).token === "string" ? (body as any).token.trim() : "";
    const source = normalizeOptional((body as any).source, 120);
    const parentCommentId = normalizeId(
      (body as any).parentCommentId ?? (body as any).parent_comment_id,
    );

    if (!authorId || !subscriberId || !storyId || !token) {
      return json(
        {
          error: "missing_parameters",
          detail: "authorId, subscriberId, storyId y token son requeridos",
        },
        400,
      );
    }

    const { credentials, diagnostics } = resolveSupabaseConfig(env);
    if (!credentials) {
      console.error(
        "[story-feedback] Missing Supabase credentials",
        diagnostics,
      );
      return json(
        { error: "supabase_not_configured", detail: diagnostics },
        500,
      );
    }

    const subscriber = await fetchSubscriber(
      credentials,
      authorId,
      subscriberId,
    );
    if (!subscriber) {
      return json({ error: "subscriber_not_found" }, 404);
    }

    // Token validation
    const storedToken =
      typeof subscriber.access_token === "string"
        ? subscriber.access_token.trim()
        : "";

    // For authors accessing their own content, token should be authorId
    const isAuthor = subscriber.is_author === true || subscriberId === authorId;
    const isValidToken = isAuthor
      ? (token.trim() === authorId.trim())
      : (storedToken && storedToken === token);

    if (!isValidToken) {
      return json({ error: "invalid_token" }, 403);
    }

    const status =
      typeof subscriber.status === "string"
        ? subscriber.status.toLowerCase()
        : "pending";
    if (status === "unsubscribed") {
      return json({ error: "subscriber_inactive" }, 403);
    }

    const ip =
      request.headers.get("cf-connecting-ip") ??
      request.headers.get("x-forwarded-for") ??
      null;
    const userAgent = request.headers.get("user-agent");

    switch (action) {
      case "fetch": {
        const comments = await fetchComments(credentials, authorId, storyId);
        const reaction = await fetchReaction(
          credentials,
          authorId,
          storyId,
          subscriberId,
        );
        const reactionCount = await fetchReactionCount(
          credentials,
          authorId,
          storyId,
        );

        // Transform comments to have the correct field names for frontend
        const transformedComments = comments.map(row => {
          // Check if comment is from author (subscriber_id is null or equals authorId)
          const isAuthorComment = !row.subscriber_id || row.subscriber_id === authorId;

          return {
            id: row.id,
            subscriberId: row.subscriber_id,
            subscriberName: isAuthorComment
              ? `${row.author_name || 'Suscriptor'} - Autor`
              : (row.author_name || 'Suscriptor'),
            content: row.content || "",
            createdAt: row.created_at,
            parentCommentId: row.parent_id,
            source: row.source,
          };
        });

        return json({
          comments: transformedComments,
          reaction: {
            ...reaction,
            count: reactionCount,
          },
          commentCount: comments.length,
        });
      }
      case "comment": {
        const content = normalizeContent((body as any).content);
        if (!content) {
          return json({ error: "content_required" }, 400);
        }

        if (parentCommentId) {
          const parentExists = await ensureCommentBelongsToStory(
            credentials,
            authorId,
            storyId,
            parentCommentId,
          );
          if (!parentExists) {
            return json({ error: "parent_not_found" }, 400);
          }
        }

        const inserted = await insertComment(credentials, {
          authorId,
          storyId,
          subscriberId,
          parentCommentId,
          source,
          ip,
          userAgent,
          content,
          subscriber,
          token,
        });

        if (!inserted) {
          return json({ error: "insert_failed" }, 502);
        }

        return json({ comment: inserted });
      }
      case "reaction": {
        const active = toBoolean(
          (body as any).active ??
            (body as any).enabled ??
            (body as any).state ??
            true,
        );
        const reactionType =
          normalizeReactionType(
            (body as any).reactionType ?? (body as any).reaction_type,
          ) ?? "heart";

        const updated = await toggleReaction(credentials, {
          authorId,
          storyId,
          subscriberId,
          reactionType,
          isActive: active,
          source,
          ip,
          userAgent,
          token,
        });

        if (!updated) {
          return json({ error: "reaction_failed" }, 502);
        }

        return json({
          reaction: {
            reactionType,
            active: updated,
          },
        });
      }
      default:
        return json({ error: "unsupported_action" }, 400);
    }
  } catch (error) {
    console.error("[story-feedback] Unexpected failure", error);
    return json({ error: "unexpected_error", detail: String(error) }, 500);
  }
};

function normalizeId(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function normalizeOptional(
  value: unknown,
  maxLength: number,
): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  if (!trimmed) return undefined;
  return trimmed.substring(0, maxLength);
}

function normalizeContent(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  if (!trimmed) return undefined;
  return trimmed.length > 4000 ? trimmed.substring(0, 4000) : trimmed;
}

function normalizeAction(
  value: unknown,
): "fetch" | "comment" | "reaction" | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim().toLowerCase();
  if (
    normalized === "fetch" ||
    normalized === "comment" ||
    normalized === "reaction"
  ) {
    return normalized;
  }
  return undefined;
}

function normalizeReactionType(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim().toLowerCase();
  if (!normalized) return undefined;
  switch (normalized) {
    case "heart":
      return "heart";
    default:
      return undefined;
  }
}

function toBoolean(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "true" || normalized === "1" || normalized === "yes") {
      return true;
    }
    if (normalized === "false" || normalized === "0" || normalized === "no") {
      return false;
    }
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  return Boolean(value);
}

async function fetchSubscriber(
  config: SupabaseCredentials,
  authorId: string,
  subscriberId: string,
) {
  // First, try to fetch from subscribers table
  const url = new URL("/rest/v1/subscribers", config.url);
  url.searchParams.set("id", `eq.${subscriberId}`);
  url.searchParams.set("user_id", `eq.${authorId}`);
  url.searchParams.set(
    "select",
    "id,name,email,status,access_token,last_access_source",
  );
  url.searchParams.set("limit", "1");

  const response = await supabaseFetch(config, url.toString());
  if (!response.ok) {
    console.error("[story-feedback] Failed to fetch subscriber", {
      status: response.status,
      body: await response.text(),
      authorId,
      subscriberId,
    });
    throw new Error("failed_to_fetch_subscriber");
  }

  const data = await response.json();
  if (Array.isArray(data) && data.length > 0) {
    return data[0];
  }

  // If not found in subscribers and subscriberId equals authorId, check if it's the author
  if (subscriberId === authorId) {
    // First get user_settings for the author name
    const settingsUrl = new URL("/rest/v1/user_settings", config.url);
    settingsUrl.searchParams.set("user_id", `eq.${authorId}`);
    settingsUrl.searchParams.set("select", "public_author_name");
    settingsUrl.searchParams.set("limit", "1");

    const settingsResponse = await supabaseFetch(config, settingsUrl.toString());
    let authorName = 'Autor';

    if (settingsResponse.ok) {
      const settingsData = await settingsResponse.json();
      if (Array.isArray(settingsData) && settingsData.length > 0) {
        authorName = settingsData[0].public_author_name || 'Autor';
      }
    }

    // Then get auth user for email
    const userUrl = new URL("/auth/v1/admin/users/" + authorId, config.url);
    const userResponse = await supabaseFetch(config, userUrl.toString());

    if (userResponse.ok) {
      const userData = await userResponse.json();
      // Return a subscriber-like object for the author
      return {
        id: userData.id,
        name: authorName,
        email: userData.email,
        status: 'author', // Special status for authors
        access_token: authorId, // For authors, token is their ID
        last_access_source: 'author_preview',
        is_author: true,
      };
    }
  }

  return null;
}

async function fetchComments(
  config: SupabaseCredentials,
  authorId: string,
  storyId: string,
) {
  const url = new URL("/rest/v1/story_comments", config.url);
  url.searchParams.set("user_id", `eq.${authorId}`);
  url.searchParams.set("story_id", `eq.${storyId}`);
  url.searchParams.set("status", "eq.visible");
  url.searchParams.set(
    "select",
    "id,author_name,author_email,content,source,parent_id,subscriber_id,created_at",
  );
  url.searchParams.set("order", "created_at.asc");

  const response = await supabaseFetch(config, url.toString());
  if (!response.ok) {
    console.error("[story-feedback] Failed to fetch comments", {
      status: response.status,
      body: await response.text(),
      authorId,
      storyId,
    });
    throw new Error("failed_to_fetch_comments");
  }

  const data = await response.json();
  return Array.isArray(data) ? data : [];
}

async function fetchReaction(
  config: SupabaseCredentials,
  authorId: string,
  storyId: string,
  subscriberId: string,
) {
  const url = new URL("/rest/v1/story_reactions", config.url);
  url.searchParams.set("user_id", `eq.${authorId}`);
  url.searchParams.set("story_id", `eq.${storyId}`);
  url.searchParams.set("subscriber_id", `eq.${subscriberId}`);
  url.searchParams.set("reaction_type", "eq.heart");
  url.searchParams.set("select", "id,reaction_type,created_at");
  url.searchParams.set("limit", "1");

  const response = await supabaseFetch(config, url.toString());
  if (!response.ok) {
    console.error("[story-feedback] Failed to fetch reaction", {
      status: response.status,
      body: await response.text(),
    });
    throw new Error("failed_to_fetch_reaction");
  }

  const data = await response.json();
  if (Array.isArray(data) && data.length > 0) {
    return { reactionType: data[0].reaction_type ?? "heart", active: true };
  }
  return { reactionType: "heart", active: false };
}

async function fetchReactionCount(
  config: SupabaseCredentials,
  authorId: string,
  storyId: string,
) {
  const url = new URL("/rest/v1/story_reactions", config.url);
  url.searchParams.set("user_id", `eq.${authorId}`);
  url.searchParams.set("story_id", `eq.${storyId}`);
  url.searchParams.set("reaction_type", "eq.heart");
  url.searchParams.set("select", "id");

  const response = await supabaseFetch(config, url.toString());
  if (!response.ok) {
    console.error("[story-feedback] Failed to fetch reaction count", {
      status: response.status,
      body: await response.text(),
    });
    return 0;
  }

  const data = await response.json();
  return Array.isArray(data) ? data.length : 0;
}

async function ensureCommentBelongsToStory(
  config: SupabaseCredentials,
  authorId: string,
  storyId: string,
  commentId: string,
) {
  const url = new URL("/rest/v1/story_comments", config.url);
  url.searchParams.set("id", `eq.${commentId}`);
  url.searchParams.set("user_id", `eq.${authorId}`);
  url.searchParams.set("story_id", `eq.${storyId}`);
  url.searchParams.set("limit", "1");

  const response = await supabaseFetch(config, url.toString());
  if (!response.ok) {
    console.error("[story-feedback] Failed to validate parent comment", {
      status: response.status,
      body: await response.text(),
    });
    throw new Error("failed_to_validate_parent");
  }

  const data = await response.json();
  return Array.isArray(data) && data.length > 0;
}

async function insertComment(
  config: SupabaseCredentials,
  options: {
    authorId: string;
    storyId: string;
    subscriberId: string;
    parentCommentId?: string;
    source?: string;
    ip: string | null;
    userAgent: string | null;
    content: string;
    subscriber: any;
    token: string;
  },
) {
  // If subscriber is the author, set subscriber_id to null to avoid FK constraint issues
  const isAuthor = options.subscriberId === options.authorId || options.subscriber?.is_author === true;

  const payload = {
    user_id: options.authorId,
    story_id: options.storyId,
    subscriber_id: isAuthor ? null : options.subscriberId,
    parent_id: options.parentCommentId ?? null,
    author_name: normalizeDisplayName(options.subscriber?.name),
    author_email: normalizeOptional(options.subscriber?.email, 320) ?? null,
    content: options.content,
    source: options.source ?? null,
    metadata: {
      source: options.source ?? null,
      ip: options.ip,
      userAgent: options.userAgent?.substring(0, 512) ?? null,
      tokenHash: hashToken(options.token),
      is_author: isAuthor,
    },
  };

  const response = await supabaseFetch(
    config,
    new URL("/rest/v1/story_comments", config.url).toString(),
    {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify(payload),
    },
  );

  const raw = await response.text();
  if (!response.ok) {
    console.error("[story-feedback] Failed to insert comment", {
      status: response.status,
      body: raw,
      payload,
    });
    return null;
  }

  let data: any = null;
  try {
    data = raw ? JSON.parse(raw) : null;
  } catch (error) {
    console.error("[story-feedback] Cannot parse comment response", error, raw);
  }

  const record = Array.isArray(data) && data.length > 0 ? data[0] : data;
  if (!record || typeof record !== "object") {
    return null;
  }

  return {
    id: record.id,
    authorName:
      record.author_name ?? normalizeDisplayName(options.subscriber?.name),
    content: record.content ?? options.content,
    createdAt: record.created_at ?? new Date().toISOString(),
    subscriberId: record.subscriber_id ?? options.subscriberId,
    source: record.source ?? options.source ?? null,
    parentId: record.parent_id ?? options.parentCommentId ?? null,
  };
}

async function toggleReaction(
  config: SupabaseCredentials,
  options: {
    authorId: string;
    storyId: string;
    subscriberId: string;
    reactionType: string;
    isActive: boolean;
    source?: string;
    ip: string | null;
    userAgent: string | null;
    token: string;
  },
) {
  if (options.isActive) {
    const payload = {
      user_id: options.authorId,
      story_id: options.storyId,
      subscriber_id: options.subscriberId,
      reaction_type: options.reactionType,
      source: options.source ?? null,
      metadata: {
        source: options.source ?? null,
        ip: options.ip,
        userAgent: options.userAgent?.substring(0, 512) ?? null,
        tokenHash: hashToken(options.token),
      },
    };

    const url = new URL("/rest/v1/story_reactions", config.url);
    url.searchParams.set("on_conflict", "story_id,subscriber_id,reaction_type");

    const response = await supabaseFetch(config, url.toString(), {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      console.error("[story-feedback] Failed to upsert reaction", {
        status: response.status,
        body: await response.text(),
        payload,
      });
      return false;
    }
    return true;
  }

  const url = new URL("/rest/v1/story_reactions", config.url);
  url.searchParams.set("user_id", `eq.${options.authorId}`);
  url.searchParams.set("story_id", `eq.${options.storyId}`);
  url.searchParams.set("subscriber_id", `eq.${options.subscriberId}`);
  url.searchParams.set("reaction_type", `eq.${options.reactionType}`);

  const response = await supabaseFetch(config, url.toString(), {
    method: "DELETE",
    headers: { Prefer: "return=minimal" },
  });

  if (!response.ok) {
    console.error("[story-feedback] Failed to delete reaction", {
      status: response.status,
      body: await response.text(),
    });
    return false;
  }

  return true;
}

function buildCommentTree(rows: any[], authorId: string) {
  const map = new Map<string, any>();
  const roots: any[] = [];

  for (const row of rows) {
    const isAuthorComment = row.subscriber_id === authorId;
    const authorName = row.author_name ?? "Suscriptor";
    const displayName = isAuthorComment ? `${authorName} - Autor` : authorName;

    const node = {
      id: row.id,
      subscriberName: displayName,
      content: row.content ?? "",
      createdAt: row.created_at,
      subscriberId: row.subscriber_id ?? null,
      source: row.source ?? null,
      parentCommentId: row.parent_id ?? null,
      replies: [] as any[],
    };
    map.set(node.id, node);
  }

  for (const node of map.values()) {
    if (node.parentCommentId && map.has(node.parentCommentId)) {
      map.get(node.parentCommentId).replies.push(node);
    } else {
      roots.push(node);
    }
  }

  const sortAscending = (a: any, b: any) =>
    new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime();
  const sortDescending = (a: any, b: any) =>
    new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();

  const sortTree = (nodes: any[]) => {
    nodes.sort(sortAscending);
    for (const child of nodes) {
      if (child.replies.length > 0) {
        sortTree(child.replies);
      }
    }
  };

  sortTree(roots);
  roots.sort(sortDescending);

  return { roots, count: rows.length };
}

function normalizeDisplayName(name: unknown): string {
  if (typeof name === "string" && name.trim()) {
    return name.trim();
  }
  return "Suscriptor";
}

function hashToken(token: string): string {
  try {
    const encoder = new TextEncoder();
    const data = encoder.encode(token);
    let hash = 0;
    for (let i = 0; i < data.length; i += 1) {
      hash = (hash << 5) - hash + data[i];
      hash |= 0;
    }
    return hash.toString(16);
  } catch (_) {
    return "";
  }
}

async function supabaseFetch(
  config: SupabaseCredentials,
  input: string,
  init?: RequestInit,
) {
  const headers: Record<string, string> = {
    apikey: config.serviceKey,
    Authorization: `Bearer ${config.serviceKey}`,
    "Content-Type": "application/json",
  };

  if (init?.headers) {
    const override = new Headers(init.headers);
    override.forEach((value, key) => {
      headers[key] = value;
    });
  }

  return fetch(input, {
    ...init,
    headers,
  });
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
