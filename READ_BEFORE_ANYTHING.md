# 📚 Guía de Inicio para Desarrolladores de Narra

Bienvenido al equipo de Narra! Este documento contiene todo lo que necesitas saber para empezar a trabajar en el proyecto.

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
- **URL en producción**: `https://narra-8m1.pages.dev/`

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
- **URL en producción**: `https://narra-8m1.pages.dev/app/`
- **Autenticación**: Supabase Auth (email/password, Google, etc.)

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
- **URL en producción**: `https://narra-8m1.pages.dev/blog/`
- **Autenticación**: Magic links (enlaces únicos por email, sin contraseña)

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
narra-8m1.pages.dev/
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

## 📂 Estructura de Carpetas

```
narra/
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
- Production: https://narra-8m1.pages.dev/
- Preview de ramas: https://{branch-name}.narra-8m1.pages.dev/

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

## 🎉 ¡Listo para Empezar!

Ahora tienes todo lo necesario para trabajar en Narra. Si tienes dudas:
1. Lee este documento completo
2. Revisa el código existente para entender patrones
3. Pregunta al equipo si algo no está claro

**¡Bienvenido al equipo y happy coding!** 🚀
