import {
  resolveSupabaseConfig,
  type SupabaseEnv,
} from "./_supabase";

interface Env extends SupabaseEnv {}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
}

function normalizeString(value: unknown, maxLength = 500): string {
  if (typeof value === "string") {
    return value.trim().slice(0, maxLength);
  }
  return "";
}

function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

export const onRequestOptions: PagesFunction<Env> = async () => {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
};

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  try {
    // Parse request body
    const body = await request.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return json({ error: "invalid_body" }, 400);
    }

    // Extract and validate fields
    const name = normalizeString((body as any).name, 200);
    const email = normalizeString((body as any).email, 200);
    const message = normalizeString((body as any).message, 5000);
    const isCurrentClient = Boolean((body as any).is_current_client);

    // Validation
    if (!name) {
      return json({ error: "name_required" }, 400);
    }

    if (!email) {
      return json({ error: "email_required" }, 400);
    }

    if (!isValidEmail(email)) {
      return json({ error: "invalid_email" }, 400);
    }

    if (!message || message.length < 10) {
      return json({ error: "message_too_short" }, 400);
    }

    // Resolve Supabase credentials
    const { credentials } = resolveSupabaseConfig(env);
    if (!credentials) {
      console.error("Supabase credentials not found");
      return json({ error: "configuration_error" }, 500);
    }

    // Insert into contact_messages table using Supabase REST API
    const insertUrl = `${credentials.url}/rest/v1/contact_messages`;
    const insertResponse = await fetch(insertUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": credentials.serviceKey,
        "Authorization": `Bearer ${credentials.serviceKey}`,
        "Prefer": "return=minimal",
      },
      body: JSON.stringify({
        name,
        email,
        message,
        is_current_client: isCurrentClient,
      }),
    });

    if (!insertResponse.ok) {
      const errorText = await insertResponse.text().catch(() => "unknown");
      console.error("Failed to insert contact message:", insertResponse.status, errorText);
      return json({ error: "database_error" }, 500);
    }

    return json({ success: true }, 200);

  } catch (error) {
    console.error("Unexpected error in contact API:", error);
    return json({ error: "internal_error" }, 500);
  }
};
