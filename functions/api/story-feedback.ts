import {
  resolvePublicSupabase,
  resolveSupabaseConfig,
  type SupabaseEnv,
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
    const token = typeof (body as any).token === "string"
      ? (body as any).token.trim()
      : "";
    const sourceRaw = typeof (body as any).source === "string"
      ? (body as any).source.trim()
      : undefined;
    const source = sourceRaw ? sourceRaw.substring(0, 120) : undefined;

    if (!authorId || !subscriberId || !storyId || !token) {
      return json(
        { error: "authorId, subscriberId, storyId and token are required" },
        400,
      );
    }

    let content: string | undefined;
    if (action === "comment") {
      const rawContent = typeof (body as any).content === "string"
        ? (body as any).content.trim()
        : "";
      if (!rawContent) {
        return json({ error: "content is required" }, 400);
      }
      content = rawContent.substring(0, 4000);
    }

    let reactionType: string | undefined;
    let reactionActive: boolean | undefined;
    if (action === "reaction") {
      reactionType = normalizeReactionType(
        (body as any).reactionType ?? (body as any).reaction_type,
      ) ?? "heart";
      reactionActive = toBoolean(
        (body as any).active
          ?? (body as any).enabled
          ?? (body as any).state
          ?? true,
      );
    }

    const { credentials, diagnostics } = resolveSupabaseConfig(env);
    const publicSupabase = resolvePublicSupabase(env, credentials?.url);
    const rpcUrl = credentials?.url ?? publicSupabase?.url;
    const apiKey = credentials?.serviceKey ?? publicSupabase?.anonKey;

    if (!rpcUrl || !apiKey) {
      console.error("[story-feedback] Missing Supabase credentials", {
        diagnostics,
        hasPublicSupabase: Boolean(publicSupabase),
      });
      return json({ error: "Supabase credentials not configured" }, 500);
    }

    const ip = request.headers.get("cf-connecting-ip")
      ?? request.headers.get("x-forwarded-for")
      ?? null;
    const userAgent = request.headers.get("user-agent");
    const normalizedUserAgent = userAgent ? userAgent.substring(0, 512) : null;

    const payload: Record<string, unknown> = {
      p_action: action,
      p_author_id: authorId,
      p_story_id: storyId,
      p_subscriber_id: subscriberId,
      p_token: token,
      p_source: source ?? null,
      p_request_ip: ip,
      p_user_agent: normalizedUserAgent,
    };

    if (content != null) {
      payload.p_content = content;
    }
    if (reactionType != null) {
      payload.p_reaction_type = reactionType;
      payload.p_active = reactionActive ?? true;
    }

    const rpcResponse = await fetch(
      `${rpcUrl}/rest/v1/rpc/process_story_feedback`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: apiKey,
          Authorization: `Bearer ${apiKey}`,
          Prefer: "return=representation",
        },
        body: JSON.stringify(payload),
      },
    );

    const rpcPayload = await parseJson(rpcResponse);
    if (!rpcPayload || typeof rpcPayload !== "object") {
      throw new Error(
        `Unexpected response from Supabase RPC (${rpcResponse.status})`,
      );
    }

    const errorCodeRaw = (rpcPayload as any).error;
    if (errorCodeRaw) {
      const errorCode = String(errorCodeRaw);
      const status = mapErrorStatus(errorCode);
      return json({
        error: mapErrorMessage(errorCode),
        code: errorCode,
      }, status);
    }

    console.log(`[story-feedback] ${action} processed via RPC`, {
      authorId,
      subscriberId,
      storyId,
      source,
      usedServiceKey: Boolean(credentials?.serviceKey),
    });

    return json(rpcPayload);
  } catch (error) {
    console.error("[story-feedback] Feedback processing failed", error);
    return json({
      error: "Feedback processing failed",
      detail: String(error),
    }, 500);
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
  if (normalized === "fetch" || normalized === "comment" || normalized === "reaction") {
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

function mapErrorStatus(code: string): number {
  switch (code) {
    case "subscriber_not_found":
      return 404;
    case "invalid_token":
    case "subscriber_inactive":
      return 403;
    case "content_required":
    case "unsupported_action":
      return 400;
    default:
      return 400;
  }
}

function mapErrorMessage(code: string): string {
  switch (code) {
    case "subscriber_not_found":
      return "No encontramos este suscriptor.";
    case "invalid_token":
      return "El enlace ya no es válido.";
    case "subscriber_inactive":
      return "Este suscriptor canceló su acceso.";
    case "content_required":
      return "El comentario necesita contenido.";
    case "unsupported_action":
      return "No podemos procesar esta acción.";
    default:
      return "No se pudo procesar esta solicitud.";
  }
}

async function parseJson(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch (_) {
    return null;
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}
