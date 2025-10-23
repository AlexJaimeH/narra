# Configuración de Variables de Entorno en Cloudflare Pages

## Variables Requeridas

### `OPENAI_API_KEY`

Necesaria para la transcripción en tiempo real.

### `RESEND_API_KEY`

Clave privada de Resend para enviar correos. La obtienes en [https://resend.com/api-keys](https://resend.com/api-keys).

### `RESEND_FROM_EMAIL`

Dirección verificada en Resend desde la que se enviarán los correos (por ejemplo `Narra <historias@narra.app>`).

### `RESEND_REPLY_TO` *(opcional)*

Dirección que recibirá las respuestas de los suscriptores. Si no se define se usa la misma que `RESEND_FROM_EMAIL`.

### `SUPABASE_URL`

URL del proyecto de Supabase. La misma que usas en la app web.

### `SUPABASE_SERVICE_ROLE_KEY`

Service Role Key de Supabase (⚠️ **trátala como secreto**). Se usa únicamente en las Cloudflare Functions para validar los enlaces mágicos de los suscriptores.

## Cómo Configurar en Cloudflare Pages

1. Ve a tu dashboard de Cloudflare Pages: https://dash.cloudflare.com/
2. Selecciona tu proyecto `narra`
3. Ve a **Settings** > **Environment variables**
4. Haz clic en **Add variable**
5. Agrega las variables necesarias:

   **Production**

   | Variable | Valor |
   | --- | --- |
   | `OPENAI_API_KEY` | Tu key principal de OpenAI |
   | `OPENAI_PROJECT_ID` *(opcional)* | ID del proyecto si tu key es del nuevo panel de Projects |
   | `OPENAI_ORGANIZATION` *(opcional)* | ID de tu organización si OpenAI lo requiere |
   | `OPENAI_TRANSCRIBE_API_KEY` *(opcional)* | Key dedicada solo para transcripción (por defecto usa `OPENAI_API_KEY`) |
   | `OPENAI_TRANSCRIBE_PROJECT_ID` *(opcional)* | Project ID exclusivo para transcripción |
   | `OPENAI_TRANSCRIBE_ORGANIZATION` *(opcional)* | Organization ID exclusivo para transcripción |
   | `OPENAI_CHAT_API_KEY` *(opcional)* | Key para ghostwriter/sugerencias (usa `OPENAI_API_KEY` si no se define) |
   | `OPENAI_CHAT_PROJECT_ID` *(opcional)* | Project ID para ghostwriter/sugerencias |
   | `OPENAI_CHAT_ORGANIZATION` *(opcional)* | Organization ID para ghostwriter/sugerencias |
   | `OPENAI_REALTIME_API_KEY` *(opcional)* | Key para sesiones Realtime (voz) |
   | `OPENAI_REALTIME_PROJECT_ID` *(opcional)* | Project ID para Realtime |
   | `OPENAI_REALTIME_ORGANIZATION` *(opcional)* | Organization ID para Realtime |
   | `RESEND_API_KEY` | Tu key privada de Resend |
   | `RESEND_FROM_EMAIL` | Dirección verificada en Resend |
   | `RESEND_REPLY_TO` *(opcional)* | Dirección para respuestas |
   | `SUPABASE_URL` | URL de tu proyecto |
   | `SUPABASE_SERVICE_ROLE_KEY` | Service role key de Supabase |

   **Preview (opcional pero recomendado)**

   Repite la tabla anterior seleccionando el entorno `Preview`.

   > **Nota:** Si tus keys empiezan con `sk-proj-` (keys de Projects), la app intenta detectar el `projectId` automáticamente. Si OpenAI te exige un ID distinto, define explícitamente la variable correspondiente (`*_PROJECT_ID`).

6. Haz clic en **Save**
7. Re-deploya tu aplicación o espera al siguiente commit para que tome efecto

## Desarrollo Local

Para desarrollo local con Cloudflare Pages Functions:

1. Copia el archivo `.dev.vars.example` a `.dev.vars`
2. Completa con tu API key real
3. Ejecuta: `npx wrangler pages dev build/web`

Para desarrollo local añade estas claves al archivo `.dev.vars` con los mismos nombres (`RESEND_API_KEY`, `RESEND_FROM_EMAIL`, etc.).

**IMPORTANTE:** El archivo `.dev.vars` ya está en `.gitignore` para evitar que subas tu API key al repositorio.

## Verificación

Después de configurar, puedes verificar que todo funciona:

1. Abre tu aplicación desplegada
2. Ve a crear/editar una historia
3. Haz clic en el botón de micrófono
4. Si la transcripción comienza, ¡todo está funcionando correctamente!

Si ves errores 400 o 500, verifica que:
- La API key esté configurada correctamente
- La API key sea válida y tenga créditos disponibles
- Hayas re-desplegado después de configurar las variables

## Obtener una API Key de OpenAI

Si no tienes una API key:

1. Ve a https://platform.openai.com/api-keys
2. Crea una cuenta o inicia sesión
3. Haz clic en **Create new secret key**
4. Copia la key (¡solo se muestra una vez!)
5. Asegúrate de tener créditos en tu cuenta de OpenAI

## Costos

La API Realtime de OpenAI tiene costos asociados. Verifica los precios actuales en:
https://openai.com/api/pricing/

La app usa el modelo `gpt-4o-mini-transcribe` (con fallback automático a `whisper-1`) para transcribir audio del usuario.
