# Actualización necesaria del workflow de GitHub Actions

## El problema: Refresh en /app/* redirecciona a la página principal

Cuando actualizas en cualquier ruta de Flutter (ej: /app/stories), estás siendo redirigido
a la página principal de React.

## La solución: Cloudflare Pages Middleware + _redirects

El archivo `_redirects` solo no es suficiente. Ahora usamos un **middleware de Cloudflare Pages**
(`functions/_middleware.js`) que intercepta TODAS las peticiones HTTP y las dirige correctamente
ANTES de que Cloudflare intente servir los archivos.

### ¿Cómo funciona el middleware?

El middleware intercepta cada petición y:
- Si la URL es `/app`, `/app/` o `/app/*` → Sirve `/app/index.html` (Flutter)
- Si la URL es `/blog/*` → Sirve `/index.html` (React)
- Todo lo demás → Pasa al siguiente handler

Esto **garantiza** que el routing funcione correctamente incluso cuando se refresca la página.

## Archivos que se crearon/modificaron:

### 1. `functions/_middleware.js` (NUEVO)
Este archivo ya existe en el repositorio y contiene la lógica de routing.

### 2. `web/_redirects` (MODIFICADO)
Las reglas de routing de respaldo por si el middleware falla.

### 3. `NEW_WORKFLOW_FILE.yml` (MODIFICADO)
El workflow ahora copia el middleware al build final.

## ¿Cómo aplicar estos cambios?

### IMPORTANTE: Debes actualizar el workflow en GitHub

El contenido completo del workflow actualizado está en `NEW_WORKFLOW_FILE.yml`.

**Pasos:**
1. Ve a tu repositorio en GitHub
2. Navega a `.github/workflows/cf-pages.yml`
3. Haz clic en el icono de lápiz para editar
4. **Borra TODO el contenido actual**
5. Abre `NEW_WORKFLOW_FILE.yml` (en la misma rama)
6. **Copia TODO su contenido y pégalo** en `cf-pages.yml`
7. Haz commit con el mensaje:
   ```
   Add Cloudflare Pages middleware for /app routing
   ```
8. El workflow se ejecutará automáticamente

## Estructura final después del deploy

```
build/web/
├── index.html                (React - landing page)
├── assets/                   (React assets)
├── _redirects                (Respaldo de routing)
├── functions/
│   └── _middleware.js        (Routing principal)
└── app/
    ├── index.html            (Flutter app)
    ├── flutter.js
    ├── flutter_bootstrap.js
    └── assets/               (Flutter assets)
```

## ¿Por qué ahora sí va a funcionar?

El middleware de Cloudflare Pages tiene **máxima prioridad** sobre archivos estáticos y `_redirects`.
Se ejecuta ANTES de que Cloudflare intente servir cualquier archivo, garantizando que:

✅ `/app/stories` → Sirve Flutter, NO React
✅ `/app/editor` → Sirve Flutter, NO React
✅ `/app/*` (cualquier ruta) → SIEMPRE sirve Flutter
✅ Refresh en Flutter → Te quedas en Flutter
✅ `/blog/*` → Sirve React
✅ `/` → Sirve React landing

## Verificación después del deploy

Una vez que el workflow termine de ejecutarse:

1. Ve a https://narra-8m1.pages.dev/app/
2. Navega a cualquier parte de la app de Flutter
3. **Presiona F5 o Ctrl+R para refrescar**
4. Deberías quedarte en Flutter, NO ir a la página principal de React

Si aún no funciona, avísame y revisamos juntos.
