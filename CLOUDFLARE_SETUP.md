# Configuración de Variables de Entorno en Cloudflare Pages

## Variables Requeridas

Para que la funcionalidad de dictado por voz funcione correctamente, necesitas configurar la siguiente variable de entorno en Cloudflare Pages:

### `OPENAI_API_KEY`

Esta es tu API key de OpenAI, necesaria para la transcripción en tiempo real.

## Cómo Configurar en Cloudflare Pages

1. Ve a tu dashboard de Cloudflare Pages: https://dash.cloudflare.com/
2. Selecciona tu proyecto `narra`
3. Ve a **Settings** > **Environment variables**
4. Haz clic en **Add variable**
5. Agrega las siguientes variables:

   **Para Production:**
   - Variable name: `OPENAI_API_KEY`
   - Value: tu API key de OpenAI (empieza con `sk-proj-...`)
   - Environment: `Production`

   **Para Preview (opcional pero recomendado):**
   - Repite el proceso pero selecciona `Preview` en Environment

6. Haz clic en **Save**
7. Re-deploya tu aplicación o espera al siguiente commit para que tome efecto

## Desarrollo Local

Para desarrollo local con Cloudflare Pages Functions:

1. Copia el archivo `.dev.vars.example` a `.dev.vars`
2. Completa con tu API key real
3. Ejecuta: `npx wrangler pages dev build/web`

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

