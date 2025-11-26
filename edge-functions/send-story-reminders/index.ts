// ============================================================
// Edge Function: send-story-reminders
// ============================================================
// Esta funcion se ejecuta como cron job cada dia a las 8:08 PM de Mexico
// (02:08 UTC) para enviar emails motivacionales a usuarios que no han
// tenido actividad en las ultimas 2 semanas.
//
// Para crear esta edge function en Supabase:
// 1. Ve a Edge Functions en el dashboard de Supabase
// 2. Crea una nueva funcion llamada "send-story-reminders"
// 3. Copia y pega este codigo
// 4. Configura el cron job en Database > Extensions > pg_cron
//
// Cron expression para 8:08 PM Mexico (UTC-6):
// 8 2 * * *  (02:08 UTC = 20:08 Mexico)
//
// SQL para configurar el cron:
// select cron.schedule(
//   'send-story-reminders',
//   '8 2 * * *',
//   $$
//   select net.http_post(
//     url:='https://TU_PROJECT_REF.supabase.co/functions/v1/send-story-reminders',
//     headers:='{"Authorization": "Bearer TU_SERVICE_ROLE_KEY", "Content-Type": "application/json"}'::jsonb,
//     body:='{}'::jsonb
//   );
//   $$
// );
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ============================================================
// 10 TEMPLATES MOTIVACIONALES
// ============================================================

interface MotivationalTemplate {
  id: number;
  badge: string;
  title: string;
  greeting: (name: string) => string;
  messageNoDrafts: (name: string) => string;
  messageWithDrafts: (name: string, draftTitle: string) => string;
  messageFirstStory: (name: string) => string;
  ctaText: string;
  footerMessage: string;
}

const MOTIVATIONAL_TEMPLATES: MotivationalTemplate[] = [
  {
    id: 1,
    badge: "Tus recuerdos te esperan",
    title: "Tu historia merece ser contada",
    greeting: (name) => `Hola ${name},`,
    messageNoDrafts: () => `Han pasado algunas semanas desde la ultima vez que escribiste. Tus recuerdos son tesoros unicos que solo tu puedes compartir. Cada historia que cuentas es un regalo para quienes te quieren.`,
    messageWithDrafts: (_, draftTitle) => `Tienes una historia esperando ser terminada: "${draftTitle}". Ese recuerdo ya esta ahi, solo necesita unos minutos mas de tu tiempo para cobrar vida y llegar a quienes amas.`,
    messageFirstStory: () => `Aun no has escrito tu primera historia, y eso esta bien. El primer paso siempre es el mas importante. Tus recuerdos son unicos y valiosos, comienza con uno pequeno.`,
    ctaText: "Escribir ahora",
    footerMessage: "Cada historia que escribes se convierte en un legado para tu familia.",
  },
  {
    id: 2,
    badge: "Un momento para ti",
    title: "Tus memorias importan",
    greeting: (name) => `Querido/a ${name},`,
    messageNoDrafts: () => `A veces la vida nos mantiene ocupados, pero tus historias son demasiado importantes para quedarse en el olvido. Tomate unos minutos hoy para revivir un recuerdo especial.`,
    messageWithDrafts: (_, draftTitle) => `Tu historia "${draftTitle}" esta casi lista. A veces solo necesitamos un pequeno empujon para terminar lo que empezamos. Hoy puede ser ese dia.`,
    messageFirstStory: () => `Sabemos que empezar puede parecer dificil, pero tu primera historia no tiene que ser perfecta. Solo tiene que ser tuya. Comienza con un recuerdo feliz.`,
    ctaText: "Continuar mi historia",
    footerMessage: "Los mejores regalos son los que vienen del corazon.",
  },
  {
    id: 3,
    badge: "Te extranamos",
    title: "Tu familia quiere saber mas",
    greeting: (name) => `Hola ${name},`,
    messageNoDrafts: () => `Tus suscriptores esperan con ilusion tu proxima historia. Cada vez que compartes un recuerdo, les das la oportunidad de conocerte mejor y de atesorar tu historia.`,
    messageWithDrafts: (_, draftTitle) => `"${draftTitle}" esta esperandote. Tus lectores estaran encantados de leer lo que tienes que contar. Solo faltan unos toques finales.`,
    messageFirstStory: () => `Tu circulo de lectores esta listo para conocer tus historias. No hay mejor momento que ahora para empezar a compartir esos momentos que te han hecho quien eres.`,
    ctaText: "Compartir mi historia",
    footerMessage: "Cada historia compartida fortalece los lazos familiares.",
  },
  {
    id: 4,
    badge: "Inspiracion del dia",
    title: "Que recuerdo te hace sonreir?",
    greeting: (name) => `Buenos dias ${name},`,
    messageNoDrafts: () => `Piensa en ese momento que siempre te saca una sonrisa. Esa anecdota que cuentas en las reuniones familiares. Esa historia merece ser escrita para que perdure para siempre.`,
    messageWithDrafts: (_, draftTitle) => `"${draftTitle}" ya tiene el potencial de hacer sonreir a alguien. Unos minutos mas y estara lista para compartir esa alegria con tu familia.`,
    messageFirstStory: () => `Todos tenemos ese recuerdo especial que nos hace sonreir. Ese es el perfecto para empezar. No tiene que ser largo, solo tiene que ser real.`,
    ctaText: "Escribir ese recuerdo",
    footerMessage: "Las sonrisas que provocan tus historias son invaluables.",
  },
  {
    id: 5,
    badge: "Un legado de amor",
    title: "Escribe para quienes amas",
    greeting: (name) => `Estimado/a ${name},`,
    messageNoDrafts: () => `Cada historia que escribes es un acto de amor. Es una manera de decir "esto es importante, esto soy yo, esto quiero que recuerden". Tu legado se construye una historia a la vez.`,
    messageWithDrafts: (_, draftTitle) => `"${draftTitle}" es mas que palabras en una pantalla. Es un pedacito de ti que permanecera por siempre. Terminala y regalala a quienes amas.`,
    messageFirstStory: () => `El mejor regalo que puedes dejar a tu familia es tu historia. Comienza hoy a construir ese legado de amor, una anecdota a la vez.`,
    ctaText: "Crear mi legado",
    footerMessage: "Tu historia es el regalo mas valioso que puedes dar.",
  },
  {
    id: 6,
    badge: "Pequenos momentos",
    title: "Los detalles hacen la diferencia",
    greeting: (name) => `Hola ${name},`,
    messageNoDrafts: () => `No necesitas grandes aventuras para tener grandes historias. A veces los momentos mas simples son los que mas atesoramos. Que tal esa tarde de domingo? O esa receta de la abuela?`,
    messageWithDrafts: (_, draftTitle) => `"${draftTitle}" ya tiene lo mas importante: tu voz y tu perspectiva. Los pequenos detalles que agregues haran que sea inolvidable.`,
    messageFirstStory: () => `Tu primera historia puede ser sobre algo simple: tu comida favorita de la infancia, un juego que jugabas, una persona que admirabas. Lo simple es poderoso.`,
    ctaText: "Capturar un momento",
    footerMessage: "Son los pequenos momentos los que forman los grandes recuerdos.",
  },
  {
    id: 7,
    badge: "Tu voz unica",
    title: "Solo tu puedes contar esta historia",
    greeting: (name) => `Querido/a ${name},`,
    messageNoDrafts: () => `Hay historias que solo tu conoces, momentos que solo tu viviste, perspectivas que solo tu tienes. El mundo necesita escuchar tu version de los hechos.`,
    messageWithDrafts: (_, draftTitle) => `Nadie mas puede terminar "${draftTitle}" como tu. Esa historia lleva tu esencia, tu humor, tu manera de ver el mundo. Completala.`,
    messageFirstStory: () => `Tu voz es unica e irremplazable. La primera historia que escribas sera especial simplemente porque viene de ti. Atrevete a compartir tu perspectiva.`,
    ctaText: "Usar mi voz",
    footerMessage: "Tu perspectiva es invaluable y merece ser escuchada.",
  },
  {
    id: 8,
    badge: "Conecta generaciones",
    title: "Puente entre pasado y futuro",
    greeting: (name) => `Hola ${name},`,
    messageNoDrafts: () => `Tus historias son el puente que conecta a las generaciones. Lo que escribas hoy podra ser leido por tus nietos, y los nietos de tus nietos. Ese es el poder de preservar tus memorias.`,
    messageWithDrafts: (_, draftTitle) => `"${draftTitle}" podria ser la historia que una generacion futura lea para entender de donde viene. Terminala y crea ese puente hacia el futuro.`,
    messageFirstStory: () => `Imagina a alguien en el futuro leyendo tu primera historia y sintiendo que te conoce. Ese es el regalo que puedes dar hoy. Empieza a construir ese puente.`,
    ctaText: "Conectar generaciones",
    footerMessage: "Tus palabras trascenderan el tiempo.",
  },
  {
    id: 9,
    badge: "Momento de reflexion",
    title: "Que historia contarias hoy?",
    greeting: (name) => `Hola ${name},`,
    messageNoDrafts: () => `Si pudieras contarle una historia a alguien que amas, cual seria? Ese recuerdo que te vino a la mente, ese es el que deberias escribir. No lo dejes escapar.`,
    messageWithDrafts: (_, draftTitle) => `"${draftTitle}" fue importante cuando empezaste a escribirla. Todavia lo es. Tomate un momento para recordar por que la empezaste y terminala con ese mismo sentimiento.`,
    messageFirstStory: () => `Cierra los ojos y piensa en un momento de tu vida que te gustaria que otros conocieran. Ahora abrelos y escribelo. Es asi de simple.`,
    ctaText: "Escribir mi historia",
    footerMessage: "Cada historia que escribes es un acto de generosidad.",
  },
  {
    id: 10,
    badge: "Nunca es tarde",
    title: "Hoy es un buen dia para escribir",
    greeting: (name) => `Hola ${name},`,
    messageNoDrafts: () => `No importa cuanto tiempo haya pasado, hoy es un excelente dia para retomar la escritura. Tus historias siguen ahi, esperando ser contadas. El momento perfecto es ahora.`,
    messageWithDrafts: (_, draftTitle) => `"${draftTitle}" ha estado esperando pacientemente. No importa cuanto tiempo haya pasado, hoy es el dia perfecto para darle el final que merece.`,
    messageFirstStory: () => `Nunca es tarde para empezar. Tu primera historia puede ser escrita hoy, ahora mismo. No necesitas el momento perfecto, solo necesitas empezar.`,
    ctaText: "Empezar ahora",
    footerMessage: "El mejor momento para empezar fue ayer. El segundo mejor momento es ahora.",
  },
];

// ============================================================
// GENERADOR DE HTML DE EMAIL
// ============================================================

function generateEmailHtml(params: {
  template: MotivationalTemplate;
  userName: string;
  reminderType: "no_activity" | "has_drafts" | "first_story" | "general_motivation";
  draftTitle?: string;
  dashboardUrl: string;
  unsubscribeUrl: string;
}): string {
  const { template, userName, reminderType, draftTitle, dashboardUrl, unsubscribeUrl } = params;

  let message: string;
  switch (reminderType) {
    case "has_drafts":
      message = template.messageWithDrafts(userName, draftTitle || "tu borrador");
      break;
    case "first_story":
      message = template.messageFirstStory(userName);
      break;
    default:
      message = template.messageNoDrafts(userName);
  }

  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="color-scheme" content="light only" />
    <meta name="supported-color-schemes" content="light only" />
    <title>Narra - ${template.title}</title>
    <style>
      :root { color-scheme: light only; }
      @media (prefers-color-scheme: dark) {
        body { background: linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%) !important; }
        .email-card { background: #ffffff !important; }
        * { color: inherit !important; }
      }
    </style>
  </head>
  <body style="margin:0;padding:0;background:linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;-webkit-font-smoothing:antialiased;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr>
        <td>
          <!-- Logo -->
          <div style="text-align:center;margin-bottom:32px;">
            <img src="https://ptlzlaacaiftusslzwhc.supabase.co/storage/v1/object/public/general/Logo%20horizontal.png" alt="Narra" style="height:36px;width:auto;" />
          </div>

          <!-- Main Card -->
          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" class="email-card" style="background:#ffffff;border-radius:24px;box-shadow:0 20px 60px rgba(77,179,168,0.12),0 8px 20px rgba(0,0,0,0.06);overflow:hidden;">
            <tr>
              <td style="padding:0;">
                <!-- Header con gradiente verde -->
                <div style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:40px 36px;text-align:center;">
                  <div style="display:inline-block;background:rgba(255,255,255,0.25);backdrop-filter:blur(10px);border-radius:16px;padding:12px 24px;margin-bottom:20px;">
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">${template.badge}</p>
                  </div>
                  <h1 style="font-size:28px;line-height:1.3;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">${template.title}</h1>
                </div>

                <!-- Content -->
                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">${template.greeting(userName)}</p>

                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">${message}</p>

                  <!-- Motivational Box -->
                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0;font-size:16px;line-height:1.6;color:#374151;font-style:italic;">"${template.footerMessage}"</p>
                  </div>

                  <!-- CTA Button -->
                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="${dashboardUrl}" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">${template.ctaText}</a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <!-- Link alternativo -->
                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Si el boton no funciona, usa este enlace:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="${dashboardUrl}" style="color:#38827A;text-decoration:none;">${dashboardUrl}</a></p>
                  </div>
                </div>

                <!-- Footer -->
                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0 0 16px 0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">
                    Recibiste este correo porque tienes una cuenta en Narra.<br/>
                    Si ya no deseas recibir estos recordatorios, puedes <a href="${unsubscribeUrl}" style="color:#38827A;text-decoration:underline;">desactivarlos aqui</a>.
                  </p>
                  <p style="margin:0;font-size:12px;color:#a8a29e;line-height:1.6;text-align:center;">
                    Con carino, el equipo de Narra<br/>
                    Creando legados familiares, una historia a la vez.
                  </p>
                </div>
              </td>
            </tr>
          </table>

          <!-- Spacer -->
          <div style="height:40px;"></div>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function generatePlainText(params: {
  template: MotivationalTemplate;
  userName: string;
  reminderType: "no_activity" | "has_drafts" | "first_story" | "general_motivation";
  draftTitle?: string;
  dashboardUrl: string;
  unsubscribeUrl: string;
}): string {
  const { template, userName, reminderType, draftTitle, dashboardUrl, unsubscribeUrl } = params;

  let message: string;
  switch (reminderType) {
    case "has_drafts":
      message = template.messageWithDrafts(userName, draftTitle || "tu borrador");
      break;
    case "first_story":
      message = template.messageFirstStory(userName);
      break;
    default:
      message = template.messageNoDrafts(userName);
  }

  return `${template.title}

${template.greeting(userName)}

${message}

"${template.footerMessage}"

${template.ctaText}: ${dashboardUrl}

---

Recibiste este correo porque tienes una cuenta en Narra.
Si ya no deseas recibir estos recordatorios: ${unsubscribeUrl}

Con carino, el equipo de Narra
Creando legados familiares, una historia a la vez.`;
}

// ============================================================
// FUNCION PRINCIPAL
// ============================================================

interface UserNeedingReminder {
  user_id: string;
  user_email: string;
  user_name: string;
  last_activity_at: string | null;
  draft_count: number;
  published_count: number;
  oldest_draft_id: string | null;
  oldest_draft_title: string | null;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Verificar autorizacion (debe ser llamado con SERVICE_ROLE_KEY)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Inicializar cliente de Supabase
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const resendApiKey = Deno.env.get("RESEND_API_KEY")!;
    const fromEmail = Deno.env.get("RESEND_FROM_EMAIL") || "Narra <hola@narra.mx>";
    const appUrl = Deno.env.get("APP_URL") || "https://narra.mx";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Obtener usuarios que necesitan recordatorio
    const { data: users, error: usersError } = await supabase
      .rpc("get_users_needing_reminder") as { data: UserNeedingReminder[] | null; error: Error | null };

    if (usersError) {
      console.error("Error fetching users:", usersError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch users", detail: usersError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!users || users.length === 0) {
      return new Response(
        JSON.stringify({ message: "No users need reminders", sent: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const results: { userId: string; email: string; success: boolean; error?: string }[] = [];

    for (const user of users) {
      try {
        // Determinar tipo de recordatorio
        let reminderType: "no_activity" | "has_drafts" | "first_story" | "general_motivation";
        if (user.published_count === 0 && user.draft_count === 0) {
          reminderType = "first_story";
        } else if (user.draft_count > 0) {
          reminderType = "has_drafts";
        } else {
          reminderType = "no_activity";
        }

        // Seleccionar template aleatorio
        const templateId = Math.floor(Math.random() * 10) + 1;
        const template = MOTIVATIONAL_TEMPLATES[templateId - 1];

        // Generar URLs
        const dashboardUrl = `${appUrl}/app`;
        const unsubscribeUrl = `${appUrl}/app/settings`;

        // Generar email
        const htmlContent = generateEmailHtml({
          template,
          userName: user.user_name || "Autor",
          reminderType,
          draftTitle: user.oldest_draft_title || undefined,
          dashboardUrl,
          unsubscribeUrl,
        });

        const textContent = generatePlainText({
          template,
          userName: user.user_name || "Autor",
          reminderType,
          draftTitle: user.oldest_draft_title || undefined,
          dashboardUrl,
          unsubscribeUrl,
        });

        // Enviar email via Resend
        const resendResponse = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${resendApiKey}`,
          },
          body: JSON.stringify({
            from: fromEmail,
            to: [user.user_email],
            subject: `${template.title} - Narra`,
            html: htmlContent,
            text: textContent,
            tags: [{ name: "category", value: "story-reminder" }],
          }),
        });

        if (!resendResponse.ok) {
          const errorData = await resendResponse.json();
          throw new Error(errorData?.error?.message || "Failed to send email");
        }

        // Registrar el recordatorio enviado
        const { error: insertError } = await supabase
          .from("email_reminders")
          .insert({
            user_id: user.user_id,
            reminder_type: reminderType,
            template_id: templateId,
            draft_story_id: user.oldest_draft_id,
            metadata: {
              user_name: user.user_name,
              draft_count: user.draft_count,
              published_count: user.published_count,
            },
          });

        if (insertError) {
          console.error("Error inserting reminder record:", insertError);
        }

        // Actualizar last_reminder_sent_at en user_settings
        const { error: updateError } = await supabase
          .from("user_settings")
          .upsert({
            user_id: user.user_id,
            last_reminder_sent_at: new Date().toISOString(),
          }, { onConflict: "user_id" });

        if (updateError) {
          console.error("Error updating user_settings:", updateError);
        }

        results.push({ userId: user.user_id, email: user.user_email, success: true });
      } catch (error) {
        console.error(`Error sending reminder to ${user.user_email}:`, error);
        results.push({
          userId: user.user_id,
          email: user.user_email,
          success: false,
          error: error instanceof Error ? error.message : "Unknown error",
        });
      }
    }

    const successCount = results.filter((r) => r.success).length;
    const failureCount = results.filter((r) => !r.success).length;

    return new Response(
      JSON.stringify({
        message: `Sent ${successCount} reminders, ${failureCount} failures`,
        sent: successCount,
        failed: failureCount,
        results,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", detail: error instanceof Error ? error.message : "Unknown" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
