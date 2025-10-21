interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

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
    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
      return json({ error: "Supabase credentials not configured" }, 500);
    }

    const body = await request.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return json({ error: "Invalid request body" }, 400);
    }

    const action = normalizeAction((body as any).action);
    if (!action) {
      return json({ error: "action is required" }, 400);
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
    const source =
      typeof (body as any).source === "string"
        ? (body as any).source.trim().slice(0, 120)
        : undefined;

    if (!authorId || !subscriberId || !storyId || !token) {
      return json(
        { error: "authorId, subscriberId, storyId and token are required" },
        400,
      );
    }

    const subscriber = await fetchSubscriber(env, authorId, subscriberId);
    if (!subscriber) {
      return json({ error: "Subscriber not found" }, 404);
    }

    const storedToken =
      typeof subscriber.access_token === "string"
        ? (subscriber.access_token as string).trim()
        : "";
    if (!storedToken || storedToken !== token) {
      return json({ error: "Invalid or expired token" }, 403);
    }

    const status =
      typeof subscriber.status === "string"
        ? (subscriber.status as string).toLowerCase()
        : "pending";
    if (status === "unsubscribed") {
      return json({ error: "Subscriber is not active" }, 403);
    }

    const ip =
      request.headers.get("cf-connecting-ip") ??
      request.headers.get("x-forwarded-for") ??
      undefined;
    const userAgent = request.headers.get("user-agent") ?? undefined;

    switch (action) {
      case "fetch": {
        const [comments, reaction] = await Promise.all([
          fetchComments(env, authorId, storyId),
          fetchReaction(env, authorId, storyId, subscriberId),
        ]);

        return json({
          comments: comments.map(formatCommentResponse),
          reaction,
        });
      }
      case "comment": {
        const rawContent =
          typeof (body as any).content === "string"
            ? (body as any).content.trim()
            : "";
        if (!rawContent) {
          return json({ error: "content is required" }, 400);
        }
        const content = rawContent.slice(0, 4000);
        const subscriberName =
          typeof subscriber.name === "string"
            ? (subscriber.name as string).trim()
            : "";
        const subscriberEmail =
          typeof subscriber.email === "string"
            ? (subscriber.email as string).trim()
            : undefined;

        const comment = await insertComment(env, {
          user_id: authorId,
          story_id: storyId,
          subscriber_id: subscriberId,
          author_name: subscriberName,
          author_email: subscriberEmail ?? null,
          content,
          source,
          metadata: {
            ip: ip ?? null,
            userAgent: userAgent ?? null,
            tokenHash: hashedToken(storedToken),
          },
        });
        return json({ comment: formatCommentResponse(comment) });
      }
      case "reaction": {
        const reactionType = normalizeReactionType(
          (body as any).reactionType ?? (body as any).reaction_type,
        );
        const active = toBoolean(
          (body as any).active ?? (body as any).enabled ?? (body as any).state,
        );
        if (!reactionType) {
          return json({ error: "reactionType is required" }, 400);
        }

        if (active) {
          await upsertReaction(env, {
            user_id: authorId,
            story_id: storyId,
            subscriber_id: subscriberId,
            reaction_type: reactionType,
            source,
            metadata: {
              ip: ip ?? null,
              userAgent: userAgent ?? null,
              tokenHash: hashedToken(storedToken),
            },
          });
        } else {
          await deleteReaction(
            env,
            authorId,
            storyId,
            subscriberId,
            reactionType,
          );
        }

        return json({
          reaction: {
            reactionType,
            active,
          },
        });
      }
      default:
        return json({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (error) {
    return json(
      { error: "Feedback processing failed", detail: String(error) },
      500,
    );
  }
};

function normalizeId(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
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
  if (normalized === "heart" || normalized === "❤️") {
    return "heart";
  }
  return normalized;
}

function toBoolean(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "") return false;
    if (["true", "1", "yes", "on"].includes(normalized)) return true;
    if (["false", "0", "no", "off"].includes(normalized)) return false;
    return true;
  }
  if (value == null) return false;
  return Boolean(value);
}

function hashedToken(token: string): string {
  const encoder = new TextEncoder();
  const data = encoder.encode(token);
  let hash = 0;
  for (let i = 0; i < data.length; i++) {
    hash = (hash * 31 + data[i]) >>> 0;
  }
  return hash.toString(16);
}

async function fetchSubscriber(
  env: Env,
  authorId: string,
  subscriberId: string,
) {
  const url = new URL("/rest/v1/subscribers", env.SUPABASE_URL);
  url.searchParams.set("id", `eq.${subscriberId}`);
  url.searchParams.set("user_id", `eq.${authorId}`);
  url.searchParams.set("select", "id,name,email,status,access_token");
  url.searchParams.set("limit", "1");

  const response = await fetch(url.toString(), {
    headers: supabaseHeaders(env),
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch subscriber (${response.status})`);
  }

  const data = await response.json();
  return Array.isArray(data) && data.length > 0 ? data[0] : null;
}

async function fetchComments(env: Env, authorId: string, storyId: string) {
  const url = new URL("/rest/v1/story_comments", env.SUPABASE_URL);
  url.searchParams.set("user_id", `eq.${authorId}`);
  url.searchParams.set("story_id", `eq.${storyId}`);
  url.searchParams.set(
    "select",
    "id,story_id,subscriber_id,author_name,author_email,content,source,created_at,metadata,subscribers(id,name)",
  );
  url.searchParams.set("order", "created_at.desc");
  url.searchParams.set("limit", "50");

  const response = await fetch(url.toString(), {
    headers: supabaseHeaders(env),
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch comments (${response.status})`);
  }

  return await response.json();
}

async function fetchReaction(
  env: Env,
  authorId: string,
  storyId: string,
  subscriberId: string,
) {
  const url = new URL("/rest/v1/story_reactions", env.SUPABASE_URL);
  url.searchParams.set("user_id", `eq.${authorId}`);
  url.searchParams.set("story_id", `eq.${storyId}`);
  url.searchParams.set("subscriber_id", `eq.${subscriberId}`);
  url.searchParams.set("reaction_type", "eq.heart");
  url.searchParams.set("select", "id,reaction_type,created_at");
  url.searchParams.set("limit", "1");

  const response = await fetch(url.toString(), {
    headers: supabaseHeaders(env),
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch reaction (${response.status})`);
  }

  const data = await response.json();
  if (Array.isArray(data) && data.length > 0) {
    return { reactionType: data[0].reaction_type ?? "heart", active: true };
  }
  return { reactionType: "heart", active: false };
}

async function insertComment(env: Env, payload: Record<string, unknown>) {
  const url = new URL("/rest/v1/story_comments", env.SUPABASE_URL);
  const response = await fetch(url.toString(), {
    method: "POST",
    headers: {
      ...supabaseHeaders(env),
      Prefer: "return=representation",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    throw new Error(`Failed to insert comment (${response.status})`);
  }

  const data = await response.json();
  if (Array.isArray(data) && data.length > 0) {
    return data[0];
  }
  return data;
}

async function upsertReaction(env: Env, payload: Record<string, unknown>) {
  const url = new URL("/rest/v1/story_reactions", env.SUPABASE_URL);
  url.searchParams.set("on_conflict", "story_id,subscriber_id,reaction_type");

  const response = await fetch(url.toString(), {
    method: "POST",
    headers: {
      ...supabaseHeaders(env),
      Prefer: "return=representation,resolution=merge-duplicates",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    throw new Error(`Failed to upsert reaction (${response.status})`);
  }
}

async function deleteReaction(
  env: Env,
  authorId: string,
  storyId: string,
  subscriberId: string,
  reactionType: string,
) {
  const url = new URL("/rest/v1/story_reactions", env.SUPABASE_URL);
  url.searchParams.set("user_id", `eq.${authorId}`);
  url.searchParams.set("story_id", `eq.${storyId}`);
  url.searchParams.set("subscriber_id", `eq.${subscriberId}`);
  url.searchParams.set("reaction_type", `eq.${reactionType}`);

  const response = await fetch(url.toString(), {
    method: "DELETE",
    headers: {
      ...supabaseHeaders(env),
      Prefer: "return=minimal",
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to delete reaction (${response.status})`);
  }
}

function formatCommentResponse(comment: any) {
  if (!comment || typeof comment !== "object") return comment;
  const subscriber = comment.subscribers as Record<string, unknown> | undefined;
  return {
    id: comment.id,
    storyId: comment.story_id,
    subscriberId: comment.subscriber_id ?? subscriber?.id ?? null,
    authorName:
      (comment.author_name as string | undefined)?.trim() ||
      (typeof subscriber?.name === "string" ? subscriber!.name : "Suscriptor"),
    authorEmail: comment.author_email ?? null,
    content: comment.content,
    source: comment.source ?? null,
    createdAt: comment.created_at,
  };
}

function supabaseHeaders(env: Env): Record<string, string> {
  return {
    "Content-Type": "application/json",
    apikey: env.SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}
