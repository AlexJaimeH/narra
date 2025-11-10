# 📚 Guía de Inicio para Desarrolladores de Narra

Bienvenido al equipo de Narra! Este documento contiene todo lo que necesitas saber para empezar a trabajar en el proyecto.

**IMPORTANTE PARA FUTUROS DESARROLLADORES:** Si realizas cambios significativos en la arquitectura, funcionalidades principales o mejoras importantes, documéntalos en este archivo para que otros desarrolladores estén al tanto. Esto incluye nuevas features, cambios en la BD, modificaciones al flujo de autenticación, etc.

---

## 🎯 ¿Qué es Narra?

**Narra** es una plataforma para crear, gestionar y compartir historias personales con suscriptores de manera privada y controlada.

### Características principales:
- **Editor de historias** con soporte para fotos, grabaciones de voz y texto enriquecido
- **Gestión de suscriptores** con magic links (enlaces únicos para acceso sin contraseña)
- **Blog privado** donde los suscriptores pueden leer, reaccionar y comentar historias
- **Sistema de etiquetas** para organizar historias
- **Fechas flexibles** para historias (año, mes o día específico)
- **Notificaciones por email** cuando se publican nuevas historias

---

## 🏗️ Arquitectura del Proyecto

Narra está compuesto por **3 aplicaciones separadas** que conviven en el mismo dominio:

### 1. **Landing Page** (React) → `/`
- **Ubicación**: `blog/src/pages/` (componentes de landing)
- **Tecnología**: React + TypeScript + Vite
- **Propósito**: Página principal de marketing para usuarios no autenticados
- **URL en producción**: `https://narra.mx/`

### 2. **App de Autor** (Flutter) → `/app/*`
- **Ubicación**: `lib/` (código Dart/Flutter)
- **Tecnología**: Flutter Web
- **Propósito**: Aplicación completa para autores
- **Funcionalidades**:
  - Crear y editar historias
  - Subir fotos y grabaciones de voz
  - Gestionar suscriptores
  - Enviar notificaciones por email
  - Ver estadísticas y engagement
  - Administrar etiquetas
  - Ajustes de perfil
- **URL en producción**: `https://narra.mx/app/`
- **Autenticación**: Supabase Auth con Magic Links (sin contraseña)

### 3. **Blog de Suscriptor** (React) → `/blog/*`
- **Ubicación**: `blog/src/` (componentes de blog)
- **Tecnología**: React + TypeScript + Vite
- **Propósito**: Vista pública/privada para suscriptores
- **Funcionalidades**:
  - Ver todas las historias del autor
  - Leer historias individuales
  - Reaccionar con "❤️" (corazones)
  - Comentar en historias
  - Ver historias relacionadas
- **URL en producción**: `https://narra.mx/blog/`
- **Autenticación**: Magic links (enlaces únicos por email, sin contraseña)

---

## 🔐 Sistema de Autenticación

Narra tiene **dos sistemas de autenticación separados** para diferentes tipos de usuarios:

### 1. **Autores** → Supabase Auth con Magic Links

**Ubicación**: `/app/login`

**Características**:
- ✅ Sin contraseña (passwordless)
- ✅ Diseñado para personas mayores (60-90 años)
- ✅ Interfaz simple y clara con instrucciones paso a paso
- ✅ Usa Supabase Admin API para generar magic links
- ✅ **Solo usuarios existentes** pueden iniciar sesión (no auto-registro)
- ✅ Enlaces válidos por 15 minutos
- ✅ Email personalizado via Resend API

**Flujo de autenticación**:
1. Usuario ingresa su email en `/app/login`
2. API verifica que el usuario existe en `auth.users`
3. Si existe, genera magic link usando Supabase Admin API
4. Envía email con enlace personalizado via Resend
5. Usuario hace clic en el enlace del correo
6. Supabase procesa los tokens del hash fragment (#access_token=...)
7. Flutter detecta la sesión y redirige al Dashboard
8. Sesión persiste en localStorage

**Archivos clave**:
- `lib/screens/auth/magic_link_login_page.dart` - UI de login
- `functions/api/author-magic-link.ts` - API que genera y envía magic links
- `lib/screens/app/app_navigation.dart` - Detecta sesión y maneja errores
- `lib/supabase/supabase_config.dart` - Configuración con implicit flow

**Mensajes de error amigables**:
- Link expirado → "El enlace ya expiró. Solicita uno nuevo. Los enlaces duran 15 minutos."
- Link inválido → "El enlace no es válido. Asegúrate de copiar el enlace completo."
- Usuario no existe → "Este correo no está registrado. Contacta al administrador."

**Variables de entorno requeridas**:
```bash
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...  # Para Admin API
SUPABASE_ANON_KEY=eyJ...          # Para cliente Flutter
RESEND_API_KEY=re_...
RESEND_FROM_EMAIL=Narra <hola@narra.mx>  # IMPORTANTE: Incluir nombre y email con este formato
APP_URL=https://narra.mx  # Opcional, usa default
```

**Configuración en Supabase Dashboard**:
```
Authentication → URL Configuration:
- Site URL: https://narra.mx
- Redirect URLs:
  * https://narra.mx/app
  * https://narra.mx/app/*
  * https://narra.mx/app/**
```

**IMPORTANTE:** También mantén las URLs antiguas de Cloudflare Pages para preview branches:
```
- Redirect URLs adicionales (para preview branches):
  * https://narra-8m1.pages.dev/app
  * https://narra-8m1.pages.dev/app/*
  * https://narra-8m1.pages.dev/app/**
```

### 2. **Suscriptores** → Magic Links Personalizados

**Ubicación**: `/blog/story/{id}` (cuando no está autenticado)

**Características**:
- ✅ Links únicos generados por el autor
- ✅ Tokens personalizados (no usa Supabase Auth)
- ✅ Acceso solo a historias específicas del autor
- ✅ Sin registro, sin contraseña
- ✅ Links pueden ser revocados por el autor

**Diferencias clave con autores**:
| Autores | Suscriptores |
|---------|--------------|
| Supabase Auth native | Tokens custom |
| Admin API (SERVICE_ROLE_KEY) | Tabla `subscribers` |
| Persiste en auth.users | No crea usuario en auth |
| Dashboard completo | Solo lectura de historias |
| Solo usuarios registrados | Auto-registro con magic link |

---

## 🗄️ Base de Datos (Supabase)

### Stack de datos:
- **PostgreSQL** (base de datos principal)
- **Supabase Storage** (archivos: fotos, audios)
- **Supabase Auth** (autenticación de autores)
- **Row Level Security (RLS)** para proteger datos

### Tablas principales:
- `users` - Datos de autores
- `user_settings` - Configuración de perfil de autores
- `stories` - Historias con contenido, fechas y estado (draft/published)
- `story_photos` - Fotos asociadas a historias
- `story_tags` - Relación entre historias y etiquetas
- `tags` - Etiquetas creadas por autores
- `voice_recordings` - Grabaciones de voz
- `subscribers` - Lista de suscriptores del autor
- `story_comments` - Comentarios de suscriptores en historias
- `story_reactions` - Reacciones (corazones) de suscriptores

### ⚠️ REGLA IMPORTANTE: Cambios en la base de datos

**TODOS los cambios de esquema SQL deben ir en**: `sqlToPasteSupabase.sql`

Este archivo contiene TODAS las migraciones en orden cronológico y debe ser:
- ✅ **Idempotente**: Se puede ejecutar múltiples veces sin errores
- ✅ **Completo**: Incluye toda la historia de cambios del proyecto
- ✅ **Documentado**: Cada sección tiene comentarios explicando qué hace

**Proceso para agregar cambios SQL:**
1. Abre `sqlToPasteSupabase.sql`
2. Ve al FINAL del archivo
3. Agrega tu nueva migración con comentarios:
   ```sql
   -- ============================================================
   -- Nombre descriptivo del cambio (Fecha: YYYY-MM-DD)
   -- ============================================================
   begin;

   -- Tu código SQL aquí

   commit;
   ```
4. Prueba el SQL en Supabase SQL Editor
5. Haz commit del cambio

---

## 🚀 Deployment (Cloudflare Pages)

El proyecto se despliega automáticamente en **Cloudflare Pages** mediante GitHub Actions.

### Workflow de deployment:
- **Archivo**: `.github/workflows/cf-pages.yml`
- **Trigger**: Push a cualquier rama
- **Proceso**:
  1. Build Flutter Web → `build/web/app/`
  2. Build React (landing + blog) → `build/web/`
  3. Copia routing (`_redirects` + `functions/_middleware.js`)
  4. Deploy a Cloudflare Pages

### ⚠️ REGLA IMPORTANTE: Cambios al workflow

**NO puedes editar `.github/workflows/cf-pages.yml` directamente en este repo** (restricciones de permisos).

**Si necesitas modificar el workflow:**
1. Edita el archivo `NEW_WORKFLOW_FILE.yml` (en la raíz)
2. Documenta los cambios
3. Actualiza `WORKFLOW_UPDATE_INSTRUCTIONS.md` con instrucciones
4. Avisa al administrador del repo para que aplique los cambios

---

## 🧭 Routing y Navegación

### ¿Cómo funciona el routing entre las 3 apps?

Narra usa un sistema híbrido de routing:

1. **Cloudflare Pages Middleware** (`functions/_middleware.js`)
   - Intercepta TODAS las peticiones HTTP
   - Dirige `/app/*` → Flutter
   - Dirige `/blog/*` → React
   - Se ejecuta ANTES de servir archivos estáticos

2. **Archivo `_redirects`** (`web/_redirects`)
   - Respaldo de reglas de routing
   - Se aplica si el middleware falla

### Estructura final en producción:
```
narra.mx/
├── /                    → React landing page
├── /app/                → Flutter app (autores)
│   ├── /app/stories     → Lista de historias
│   ├── /app/editor      → Editor de historias
│   ├── /app/subscribers → Gestión de suscriptores
│   └── /app/settings    → Ajustes
├── /blog/               → React blog (suscriptores)
│   ├── /blog/story/{id} → Ver historia
│   └── /blog/author/{id}→ Ver todas las historias del autor
└── /api/                → Cloudflare Functions (backend)
```

---

## 🛠️ Stack Tecnológico

### Frontend (Flutter)
- **Lenguaje**: Dart
- **Framework**: Flutter 3.x
- **Gestión de estado**: setState (local) + Callbacks
- **Routing**: go_router
- **HTTP**: http package
- **Storage**: flutter_secure_storage

### Frontend (React)
- **Lenguaje**: TypeScript
- **Framework**: React 18 + Vite
- **Routing**: react-router-dom
- **HTTP**: fetch nativo
- **Styling**: Tailwind CSS (configurado en blog)

### Backend
- **Database**: PostgreSQL (Supabase)
- **Auth**: Supabase Auth
- **Storage**: Supabase Storage
- **Serverless Functions**: Cloudflare Pages Functions (`functions/`)
- **Email**: Resend API (para notificaciones)

### Infrastructure
- **Hosting**: Cloudflare Pages
- **CI/CD**: GitHub Actions
- **Secrets Management**: GitHub Secrets + Cloudflare Environment Variables

---

## 🎨 Branding y Diseño

### Paleta de Colores de Narra

**Colores Principales:**
```css
/* Verde/Turquesa - Color primario de marca */
--brand-primary: #4DB3A8        /* Verde turquesa principal */
--brand-primary-solid: #38827A  /* Verde más oscuro para hover */
--brand-primary-light: #6BC5BC  /* Verde claro para backgrounds */
--brand-primary-pale: #E8F5F4   /* Verde muy claro para fondos sutiles */
--brand-accent: #38827A         /* Color de acento */

/* Beige/Crema - Colores de fondo */
--surface-white: #FDFBF7        /* Blanco cálido principal */
--surface-cream: #F0EBE3        /* Beige claro para gradientes */

/* Grises - Texto y elementos UI */
--text-primary: #1F2937         /* Gris oscuro para texto principal */
--text-secondary: #4B5563       /* Gris medio para texto secundario */
--text-light: #9CA3AF           /* Gris claro para texto terciario */

/* Estados y Feedback */
--success: #10B981              /* Verde para estados exitosos */
--error: #EF4444                /* Rojo para errores */
--warning: #F59E0B              /* Naranja para advertencias */
--info: #3B82F6                 /* Azul para información */
```

**Gradientes Comunes:**
```css
/* Fondo principal de la app */
background: linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%);

/* Logo y elementos de marca */
background: linear-gradient(135deg, #4DB3A8, #38827A);

/* Headers y elementos destacados */
background: linear-gradient(135deg, #4DB3A815 0%, #38827A10 100%);
```

### Logos y Assets

#### 📁 Ubicación de Logos Oficiales

Todos los logos están en la carpeta raíz:
```
/assets/
├── icon-50.png           (50×50px)   - Ícono cuadrado para favicons
├── logo-250.png          (250×250px) - Logo cuadrado para íconos medianos
├── logo-500.png          (500×500px) - Logo cuadrado para íconos grandes
└── logo-horizontal.png   (500×100px) - Logo horizontal (logo + texto "Narra")
```

**Características importantes:**
- ✅ Todos tienen **fondo transparente**
- ✅ Formato PNG con transparencia
- ✅ Alta calidad para retina displays
- ✅ Logo horizontal incluye el texto "Narra" incorporado

#### 🔄 Cómo Actualizar Logos

**Proceso:**
1. Crea tus nuevos logos con **fondo transparente** en formato PNG
2. Respeta los tamaños exactos:
   - Ícono: 50×50px
   - Logo cuadrado mediano: 250×250px
   - Logo cuadrado grande: 500×500px
   - Logo horizontal: 500×100px (o proporciones similares)
3. Guarda los archivos en `/assets/` con los nombres exactos
4. Haz commit y push a main
5. Los logos se actualizarán automáticamente en el siguiente deployment

**El sistema copiará automáticamente a:**
- ✅ Flutter web: `web/favicon.png`, `web/icons/`, `web/splash-logo.png`, `web/logo-horizontal.png`
- ✅ React: `blog/public/favicon.png`, `blog/public/icon.png`, `blog/public/logo.png`, `blog/public/logo-horizontal.png`

#### 📍 Dónde Se Usan Los Logos

**Flutter App (`/app`):**
- **Favicon:** `web/favicon.png` (ícono en pestaña del navegador)
- **Splash screen:** `web/splash-logo.png` (logo horizontal al cargar)
- **Menú superior:** Logo horizontal en barra de navegación
- **PWA icons:** `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-*.png`
- **Manifest:** `web/manifest.json` (para instalar como app)

**React Landing (`/`):**
- **Favicon:** `blog/public/favicon.png`
- **Header:** Logo horizontal en barra superior
- **Footer:** Logo horizontal con opacidad

**React Blog (`/blog`):**
- **Loading screen:** Logo cuadrado animado
- **Footers:** Ícono pequeño + texto "Creado con Narra"

#### ⚙️ Configuración Técnica

**Flutter - Menú Superior:**
```dart
// lib/screens/app/top_navigation_bar.dart
Image.network(
  '/app/logo-horizontal.png',
  height: 32,
  fit: BoxFit.contain,
)
```

**Flutter - Splash Screen:**
```html
<!-- web/index.html -->
<div id="splash-logo">
  <img src="splash-logo.png" alt="Narra">
</div>
<!-- Nota: NO incluir texto adicional, el logo horizontal ya lo tiene -->
```

**React - Header:**
```tsx
// blog/src/pages/LandingPage.tsx
<img
  src="/logo-horizontal.png"
  alt="Narra - Historias Familiares"
  className="h-10 w-auto object-contain"
/>
```

**PWA Manifest:**
```json
// web/manifest.json
{
  "name": "Narra - Historias Familiares",
  "short_name": "Narra",
  "theme_color": "#4DB3A8",
  "background_color": "#fdfbf7",
  "icons": [...]
}
```

### Estándares de Email

Todos los emails que envía Narra deben seguir el mismo formato y paleta de colores para consistencia de marca.

#### 📧 Emails Actuales

**1. Magic Link Login** (`functions/api/author-magic-link.ts`)
- **Cuándo:** Usuario solicita iniciar sesión
- **Propósito:** Enviar enlace seguro de acceso único
- **Badge:** "🔑 Acceso Seguro"

**2. Nueva Historia** (`lib/services/email/email_templates.dart` - `storyPublishedHtml`)
- **Cuándo:** Autor publica nueva historia
- **Propósito:** Notificar a suscriptores con enlace personalizado
- **Badge:** "✨ Nueva Historia"

**3. Invitación Suscriptor** (`lib/services/email/email_templates.dart` - `subscriberInviteHtml`)
- **Cuándo:** Autor invita nuevo suscriptor
- **Propósito:** Dar acceso privado al círculo
- **Badge:** "🔐 Invitación Privada"

#### 🎨 Estructura HTML Estándar

Todos los emails deben usar esta estructura:

```html
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>[Título del email]</title>
  </head>
  <body style="margin:0;padding:0;background:linear-gradient(135deg, #fdfbf7 0%, #f0ebe3 100%);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr>
        <td>
          <!-- Logo -->
          <div style="text-align:center;margin-bottom:32px;">
            <img src="https://ptlzlaacaiftusslzwhc.supabase.co/storage/v1/object/public/general/Logo%20horizontal.png" alt="Narra" style="height:36px;width:auto;" />
          </div>

          <!-- Main Card -->
          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background:#ffffff;border-radius:24px;box-shadow:0 20px 60px rgba(77,179,168,0.12),0 8px 20px rgba(0,0,0,0.06);overflow:hidden;">
            <tr>
              <td style="padding:0;">
                <!-- Header con gradiente verde -->
                <div style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:40px 36px;text-align:center;">
                  <div style="display:inline-block;background:rgba(255,255,255,0.25);backdrop-filter:blur(10px);border-radius:16px;padding:12px 24px;margin-bottom:20px;">
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">[Badge con emoji]</p>
                  </div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">[Título]</h1>
                </div>

                <!-- Content -->
                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">[Saludo],</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">[Mensaje principal]</p>

                  <!-- Info Box (usar color #E8F5F4 para fondo) -->
                  <div style="background:#E8F5F4;border-left:4px solid #4DB3A8;border-radius:16px;padding:24px;margin:32px 0;">
                    <p>[Información destacada]</p>
                  </div>

                  <!-- CTA Button -->
                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="[URL]" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">[Emoji] [Texto del botón]</a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <!-- Alternative Link -->
                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Si el botón no funciona, usa este enlace:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="[URL]" style="color:#38827A;text-decoration:none;">[URL]</a></p>
                  </div>
                </div>

                <!-- Footer -->
                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0 0 16px 0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">[Mensaje del footer]</p>
                  <p style="margin:0;font-size:12px;color:#a8a29e;line-height:1.6;text-align:center;">[Texto secundario]</p>
                </div>
              </td>
            </tr>
          </table>

          <div style="height:40px;"></div>
        </td>
      </tr>
    </table>
  </body>
</html>
```

#### ✅ Reglas de Email

**Obligatorio:**
- ✅ Usar logo horizontal en vez de texto
- ✅ Header con gradiente verde turquesa (#4DB3A8 a #38827A)
- ✅ Badge con fondo blanco translúcido
- ✅ Botón CTA con gradiente verde y sombra
- ✅ Info boxes con fondo #E8F5F4 (verde muy claro de Narra)
- ✅ Enlaces alternativos en gris con borde punteado
- ✅ Footer con fondo #fafaf9
- ✅ Texto principal en #1f2937, secundario en #4b5563

**Prohibido:**
- ❌ Usar texto "Narra" en lugar del logo
- ❌ Usar colores morados (#6d28d9) o fuera de paleta
- ❌ Fondos de info box en morado (#faf5ff, #f3e8ff)
- ❌ Botones sin el gradiente verde de marca
- ❌ Logos de tamaño inconsistente (siempre height:36px)

**Recomendaciones:**
- 💡 Usar emojis en badges y CTAs para personalidad
- 💡 Mantener máximo 660px de ancho
- 💡 Padding consistente: 40px en contenido, 32px en footer
- 💡 Border-radius: 24px para card principal, 16px para elementos internos
- 💡 Siempre incluir versión plain text del email

---

## 📂 Estructura de Carpetas

```
narra/
├── assets/                       # ⭐ Logos y assets oficiales
│   ├── icon-50.png               # Ícono 50×50px (favicon)
│   ├── logo-250.png              # Logo cuadrado 250×250px
│   ├── logo-500.png              # Logo cuadrado 500×500px
│   └── logo-horizontal.png       # Logo horizontal 500×100px
│
├── lib/                          # Código Flutter (app de autor)
│   ├── main.dart                 # Entry point de Flutter
│   ├── screens/                  # Pantallas de la app
│   │   ├── app/                  # Pantallas principales
│   │   │   ├── story_editor_page.dart     # Editor de historias
│   │   │   ├── stories_page.dart          # Lista de historias
│   │   │   ├── subscribers_page.dart      # Gestión de suscriptores
│   │   │   └── settings_page.dart         # Ajustes del usuario
│   │   └── auth/                 # Pantallas de autenticación
│   ├── services/                 # Servicios (API, storage)
│   ├── repositories/             # Acceso a datos
│   └── supabase/                 # Configuración de Supabase
│
├── blog/                         # Código React (landing + blog)
│   ├── src/
│   │   ├── pages/                # Páginas React
│   │   │   ├── BlogHome.tsx      # Página principal del blog
│   │   │   ├── StoryPage.tsx     # Vista de historia individual
│   │   │   └── LandingPage.tsx   # Landing page (/)
│   │   ├── components/           # Componentes reutilizables
│   │   ├── services/             # Servicios (API)
│   │   └── types/                # TypeScript types
│   ├── package.json
│   └── vite.config.ts
│
├── functions/                    # Cloudflare Pages Functions
│   ├── _middleware.js            # Middleware de routing
│   └── api/                      # Endpoints de API
│       ├── story-access.ts       # Validar acceso a historias
│       └── story-feedback.ts     # Comentarios y reacciones
│
├── web/
│   └── _redirects                # Reglas de routing de respaldo
│
├── .github/
│   └── workflows/
│       └── cf-pages.yml          # GitHub Actions workflow
│
├── sqlToPasteSupabase.sql        # ⭐ TODAS las migraciones SQL
├── NEW_WORKFLOW_FILE.yml         # ⭐ Template del workflow
├── WORKFLOW_UPDATE_INSTRUCTIONS.md
└── README.md
```

---

## 🔐 Variables de Entorno y Secrets

### Para desarrollo local:

**Flutter** necesita (en tiempo de build):
```bash
--dart-define=SUPABASE_URL=https://xxx.supabase.co
--dart-define=SUPABASE_ANON_KEY=eyJ...
```

**React** necesita (en `.env` o tiempo de build):
```bash
# No necesita credenciales de Supabase en build
# Se obtienen dinámicamente del API en runtime
```

### En GitHub Actions (Secrets):
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

### En Cloudflare Pages (Environment Variables):
- Se heredan automáticamente del deployment

---

## 🧪 Cómo Ejecutar el Proyecto Localmente

### 1. Flutter (App de Autor)

```bash
# Instalar dependencias
flutter pub get

# Ejecutar en modo web
flutter run -d chrome \
  --dart-define=SUPABASE_URL=tu_url \
  --dart-define=SUPABASE_ANON_KEY=tu_key

# Build para producción
flutter build web --release \
  --base-href=/app/ \
  --dart-define=SUPABASE_URL=tu_url \
  --dart-define=SUPABASE_ANON_KEY=tu_key
```

### 2. React (Landing + Blog)

```bash
cd blog

# Instalar dependencias
npm install

# Modo desarrollo
npm run dev

# Build para producción
npm run build
```

### 3. Testing local del build completo

Después de hacer builds de Flutter y React:
```bash
# Simular la estructura de producción
mkdir -p build/web/app
# Mover Flutter a /app
# Copiar React a raíz
# etc. (ver workflow)

# Servir con un servidor local
npx serve build/web
```

---

## 🎨 Convenciones de Código

### Flutter (Dart):
- **Nombres de clases**: PascalCase (`StoryEditorPage`)
- **Nombres de archivos**: snake_case (`story_editor_page.dart`)
- **Variables/funciones**: camelCase (`loadStories`, `currentUser`)
- **Privados**: Prefijo `_` (`_isLoading`)
- **Constantes**: camelCase con `const` (`const defaultPadding = 16.0`)

### React (TypeScript):
- **Componentes**: PascalCase (`StoryCard.tsx`)
- **Funciones/variables**: camelCase (`fetchStories`, `isLoading`)
- **Interfaces/types**: PascalCase (`Story`, `StoryFeedbackState`)
- **Archivos de utilidades**: camelCase (`storyService.ts`)
- **CSS classes**: kebab-case (`story-card`, `btn-primary`)

### SQL:
- **Tablas**: snake_case plural (`stories`, `story_tags`)
- **Columnas**: snake_case (`user_id`, `created_at`)
- **Funciones**: snake_case (`get_story_comments`)

---

## 🐛 Debugging Tips

### Flutter:
```bash
# Ver logs detallados
flutter run -d chrome --verbose

# Limpiar cache si hay problemas
flutter clean
flutter pub get

# Analizar código
dart analyze
```

### React:
```bash
# Ver errores de TypeScript
cd blog && npm run build

# Limpiar cache de Vite
rm -rf blog/node_modules/.vite
```

### Supabase:
- Usa la consola SQL de Supabase para probar queries
- Revisa los logs de RLS si hay errores de permisos
- Verifica que las políticas de RLS permitan la acción

---

## 📝 Workflow de Desarrollo

### Para agregar una nueva feature:

1. **Crea una rama** desde `main`:
   ```bash
   git checkout -b feature/nombre-descriptivo
   ```

2. **Desarrolla tu feature**:
   - Si necesitas cambios en DB → Edita `sqlToPasteSupabase.sql`
   - Si es en Flutter → Edita archivos en `lib/`
   - Si es en React → Edita archivos en `blog/src/`
   - Si necesitas API → Agrega en `functions/api/`

3. **Haz commit**:
   ```bash
   git add .
   git commit -m "Add: descripción clara del cambio"
   ```

4. **Push y crea PR**:
   ```bash
   git push -u origin feature/nombre-descriptivo
   ```
   - El workflow ejecutará build automáticamente
   - Revisa el preview deployment en Cloudflare

5. **Merge a main**:
   - Una vez aprobado, merge a `main`
   - Se desplegará automáticamente a producción

---

## 🔍 Recursos Útiles

### Documentación:
- [Flutter Docs](https://docs.flutter.dev/)
- [React Docs](https://react.dev/)
- [Supabase Docs](https://supabase.com/docs)
- [Cloudflare Pages Docs](https://developers.cloudflare.com/pages/)

### APIs y servicios:
- **Supabase Dashboard**: https://app.supabase.com/
- **Cloudflare Dashboard**: https://dash.cloudflare.com/
- **Resend (Email)**: https://resend.com/

### Testing:
- Production: https://narra.mx/
- Preview de ramas: https://{branch-name}.narra-8m1.pages.dev/ (Cloudflare Pages)

---

## 🤖 Ghost Writer (Asistente de IA)

El Ghost Writer es el editor de historias impulsado por IA que ayuda a los usuarios a mejorar la calidad de sus relatos para que sean dignos de publicación en un libro.

### Características principales:
- **Pulido profesional**: Mejora redacción, gramática y estilo
- **Respeta la voz del autor**: Mantiene emociones y estilo personal
- **Configurable**: Tono, perspectiva, estilo de edición y más
- **Tracking de uso**: Sistema para detectar primera vez y mostrar introducción

### Valores por defecto (Fecha: 2025-11-04):
```dart
// Optimizados para historias de calidad profesional/publicable
ai_no_bad_words: true       // Cambió de false a true
ai_person: 'first'          // Primera persona (natural para memorias)
ai_fidelity: 'balanced'     // Equilibrado (respeta original pero pule)
writing_tone: 'warm'        // Cálido (apropiado para historias familiares)
```

### Columnas de tracking en `user_settings`:
- `has_used_ghost_writer`: boolean - Indica si usó el ghost writer alguna vez
- `has_configured_ghost_writer`: boolean - Indica si configuró las preferencias
- `has_dismissed_ghost_writer_intro`: boolean - Indica si cerró la intro en dashboard

### Introducción del Ghost Writer:
La primera vez que un usuario ingresa al dashboard y **NO** ha usado, configurado o cerrado la introducción, se muestra una tarjeta de bienvenida emotiva que:
- Explica qué es el Ghost Writer de forma amena y emocional
- Presenta 3 beneficios clave con íconos
- Ofrece botones para "Configurar" o "Entendido"
- Se diseñó con colores violeta/morado (#7C3AED) para diferenciarlo visualmente

**Ubicación del código:**
- Widget: `_GhostWriterIntroCard` en `lib/screens/app/dashboard_page.dart`
- Lógica de tracking: `UserService` en `lib/services/user_service.dart`
- Configuración: `settings_page.dart` sección "Asistente de IA (Ghostwriter)"
- Uso: `story_editor_page.dart` método `_runGhostWriter()`

---

## 🤖 Ghost Writer (Asistente de IA)

El Ghost Writer es el editor de historias impulsado por IA que ayuda a los usuarios a mejorar la calidad de sus relatos para que sean dignos de publicación en un libro.

### Características principales:
- **Pulido profesional**: Mejora redacción, gramática y estilo
- **Respeta la voz del autor**: Mantiene emociones y estilo personal
- **Configurable**: Tono, perspectiva, estilo de edición y más
- **Tracking de uso**: Sistema para detectar primera vez y mostrar introducción

### Valores por defecto (Fecha: 2025-11-04):
```dart
// Optimizados para historias de calidad profesional/publicable
ai_no_bad_words: true       // Cambió de false a true
ai_person: 'first'          // Primera persona (natural para memorias)
ai_fidelity: 'balanced'     // Equilibrado (respeta original pero pule)
writing_tone: 'warm'        // Cálido (apropiado para historias familiares)
```

### Columnas de tracking en `user_settings`:
- `has_used_ghost_writer`: boolean - Indica si usó el ghost writer alguna vez
- `has_configured_ghost_writer`: boolean - Indica si configuró las preferencias
- `has_dismissed_ghost_writer_intro`: boolean - Indica si cerró la intro en dashboard

### Introducción del Ghost Writer:
La primera vez que un usuario ingresa al dashboard y **NO** ha usado, configurado o cerrado la introducción, se muestra una tarjeta de bienvenida emotiva que:
- Explica qué es el Ghost Writer de forma amena y emocional
- Presenta 3 beneficios clave con íconos
- Ofrece botones para "Configurar" o "Entendido"
- Se diseñó con colores violeta/morado (#7C3AED) para diferenciarlo visualmente

**Ubicación del código:**
- Widget: `_GhostWriterIntroCard` en `lib/screens/app/dashboard_page.dart`
- Lógica de tracking: `UserService` en `lib/services/user_service.dart`
- Configuración: `settings_page.dart` sección "Asistente de IA (Ghostwriter)"
- Uso: `story_editor_page.dart` método `_runGhostWriter()`

---

## ⚠️ Cosas que NO debes hacer

❌ **NO edites `.github/workflows/cf-pages.yml` directamente**
   → Usa `NEW_WORKFLOW_FILE.yml` y documenta en `WORKFLOW_UPDATE_INSTRUCTIONS.md`

❌ **NO pongas secrets o API keys en el código**
   → Usa GitHub Secrets y variables de entorno

❌ **NO subas archivos grandes a git**
   → Las fotos/audios van a Supabase Storage, no al repo

❌ **NO hagas push directo a `main` sin PR**
   → Siempre crea una rama y PR para revisión

❌ **NO uses `console.log()` en producción**
   → Los logs ya fueron removidos del blog y no deben agregarse

❌ **NO modifiques código generado automáticamente**
   → Ejemplo: archivos en `build/`, `node_modules/`, etc.

❌ **NO uses emojis en commits que van a deploy**
   → Cloudflare Pages falla con emojis en algunos casos

❌ **NO olvides agregar imports cuando uses servicios/clases en archivos nuevos**
   → SIEMPRE ejecuta `dart analyze` localmente antes de hacer push
   → Imports comunes que puedes necesitar:
   ```dart
   // Servicios principales
   import 'package:narra/services/user_service.dart';
   import 'package:narra/services/story_service_new.dart';
   import 'package:narra/services/subscriber_service.dart';

   // Repositories
   import 'package:narra/repositories/user_repository.dart';
   import 'package:narra/repositories/story_repository.dart';

   // API
   import 'package:narra/api/narra_api.dart';
   ```

---

## ✅ Checklist Antes de Hacer Push

Antes de hacer `git push`, SIEMPRE ejecuta estos comandos:

```bash
# 1. Analizar código Dart (detecta imports faltantes, errores de sintaxis)
dart analyze --no-fatal-warnings

# 2. Si hay errores, corrígelos antes de hacer push

# 3. Commit y push solo cuando dart analyze esté limpio
git add -A
git commit -m "Tu mensaje"
git push -u origin tu-rama
```

**Por qué es importante:**
- El workflow de GitHub Actions ejecuta `dart analyze` automáticamente
- Si hay errores, el deploy falla
- Es más rápido detectar errores localmente que esperar al CI/CD

---

## 🆘 ¿Necesitas Ayuda?

### Problemas comunes:

**"No puedo hacer login en Flutter"**
→ Verifica que `SUPABASE_URL` y `SUPABASE_ANON_KEY` sean correctos

**"El refresh en /app/* me lleva a /"**
→ Asegúrate que `functions/_middleware.js` esté en el build

**"Los cambios SQL no se aplican"**
→ Copia `sqlToPasteSupabase.sql` y ejecútalo en Supabase SQL Editor

**"El workflow falla en GitHub Actions"**
→ Revisa los logs en la pestaña "Actions" del repo

**"No veo mis historias en el blog"**
→ Verifica que estén en estado `published` y que el suscriptor tenga acceso válido

---

## 📧 Sistema de Cambio de Email (Fecha: 2025-11-05)

Narra incluye un sistema completo y seguro para que los usuarios cambien su email de registro en cualquier momento.

### Características principales:
- **Doble confirmación**: Emails a ambas direcciones (vieja y nueva)
- **Reversible**: El usuario puede revertir el cambio en cualquier momento
- **Sin expiración del revert**: El enlace de reversión nunca expira
- **Validación**: Verifica que el nuevo email no esté registrado
- **Seguro**: Usa tokens únicos y requiere confirmación explícita

### Flujo completo:

**1. Usuario solicita cambio**
- Va a Ajustes → "Cambiar email"
- Ingresa su nuevo email
- Confirma la acción en un diálogo

**2. Sistema envía 2 emails**
- **Email al correo viejo**:
  - Notifica del cambio solicitado
  - Incluye enlace para CANCELAR/REVERTIR (nunca expira)
  - Badge: "🔄 Cambio de Email"
- **Email al correo nuevo**:
  - Pide confirmación para completar el cambio
  - Incluye enlace para CONFIRMAR
  - Badge: "✅ Confirmación Requerida"

**3. Usuario confirma desde nuevo email**
- Hace clic en el enlace del email nuevo
- El sistema actualiza el email en `auth.users`
- Estado cambia a 'confirmed'

**4. Usuario puede revertir en cualquier momento**
- Hace clic en el enlace del email viejo (incluso después de confirmado)
- El sistema restaura el email anterior
- Estado cambia a 'reverted'

### Estructura técnica:

**Base de datos** (`sqlToPasteSupabase.sql`):
```sql
create table email_change_requests (
  id uuid primary key,
  user_id uuid references auth.users(id),
  old_email text not null,
  new_email text not null,
  confirmation_token text not null unique,
  revert_token text not null unique,
  status text check (status in ('pending', 'confirmed', 'reverted', 'cancelled')),
  created_at timestamptz,
  confirmed_at timestamptz,
  reverted_at timestamptz,
  cancelled_at timestamptz
);
```

**APIs** (`functions/api/`):
- `email-change-request.ts`: Solicita cambio, genera tokens, envía emails
- `email-change-confirm.ts`: Confirma cambio desde nuevo email
- `email-change-revert.ts`: Revierte cambio desde email viejo

**UI Flutter** (`lib/screens/app/`):
- `change_email_page.dart`: Formulario para solicitar cambio
- `email_change_confirm_page.dart`: Página de confirmación
- `email_change_revert_page.dart`: Página de reversión
- `settings_page.dart`: Botón "Cambiar email" en sección de perfil

**Rutas** (`lib/main.dart`):
- `/app/email-change-confirm?token=xxx` → Confirmar cambio
- `/app/email-change-revert?token=xxx` → Revertir cambio

**Templates de email**:
- Siguen el estándar de diseño de Narra
- Usan gradiente verde turquesa (#4DB3A8)
- Incluyen logo horizontal
- Dark mode compatible

### Validaciones de seguridad:
- ✅ Verifica que el nuevo email no esté registrado (al solicitar Y al confirmar)
- ✅ Solo permite un cambio pendiente por usuario a la vez
- ✅ Cancela automáticamente cambios pendientes anteriores
- ✅ Tokens únicos y aleatorios de 64 caracteres
- ✅ Requiere sesión activa para solicitar cambio
- ✅ No requiere sesión para confirmar/revertir (solo token)

### Variables de entorno requeridas:
```bash
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...  # Necesario para Admin API
RESEND_API_KEY=re_...
RESEND_FROM_EMAIL=Narra <hola@narra.mx>  # IMPORTANTE: Incluir nombre y email
APP_URL=https://narra.mx  # Opcional
```

### Notas importantes:
- El enlace de reversión **NUNCA expira** (diferente al magic link que dura 15 min)
- El usuario puede revertir incluso después de que el cambio fue confirmado
- Si el email nuevo ya está registrado, rechaza el cambio inmediatamente
- Los emails siguen el estándar de diseño de Narra (ver sección "Estándares de Email")

---

## 🎉 ¡Listo para Empezar!

Ahora tienes todo lo necesario para trabajar en Narra. Si tienes dudas:
1. Lee este documento completo
2. Revisa el código existente para entender patrones
3. Pregunta al equipo si algo no está claro

**¡Bienvenido al equipo y happy coding!** 🚀
