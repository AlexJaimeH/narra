# ✅ Checklist: Migración de Dominio a narra.mx

Este documento contiene todos los pasos que debes realizar manualmente después de cambiar el dominio de `https://narra-8m1.pages.dev/` a `https://narra.mx`.

---

## 🔧 Cambios en el Código (YA REALIZADOS ✅)

Estos cambios ya están en el código y se aplicarán automáticamente en el próximo deploy:

- ✅ `functions/api/author-magic-link.ts` - Fallback de magic links actualizado a narra.mx
- ✅ `lib/services/story_share_link_builder.dart` - Fallback de links compartidos actualizado a narra.mx
- ✅ Documentación actualizada en `READ_BEFORE_ANYTHING.md`
- ✅ Documentación actualizada en `WORKFLOW_UPDATE_INSTRUCTIONS.md`

---

## 🚨 ACCIONES REQUERIDAS - Debes hacer estos cambios manualmente:

### 1. 📧 Supabase Authentication URLs

**Ve a Supabase Dashboard:**
1. Abre https://app.supabase.com/
2. Selecciona tu proyecto
3. Ve a **Authentication** → **URL Configuration**

**Actualiza estos valores:**

#### Site URL:
```
https://narra.mx
```

#### Redirect URLs:
Agrega las siguientes URLs (MANTÉN las antiguas de .pages.dev para preview branches):

```
✅ Nuevas URLs (Producción - narra.mx):
https://narra.mx/app
https://narra.mx/app/*
https://narra.mx/app/**

✅ Mantener URLs antiguas (Preview branches - .pages.dev):
https://narra-8m1.pages.dev/app
https://narra-8m1.pages.dev/app/*
https://narra-8m1.pages.dev/app/**
```

**¿Por qué mantener las .pages.dev?**
Las preview branches de Cloudflare Pages (ej: `feature-xyz.narra-8m1.pages.dev`) siguen usando ese dominio y necesitan autenticación para desarrollo/testing.

---

### 2. 🔐 Variables de Entorno en Cloudflare Pages

**Ve a Cloudflare Dashboard:**
1. Abre https://dash.cloudflare.com/
2. Ve a **Workers & Pages** → Selecciona tu proyecto **narra**
3. Ve a **Settings** → **Environment variables**

**Actualiza la variable:**

| Variable | Valor Anterior | Valor Nuevo |
|----------|---------------|-------------|
| `APP_URL` | `https://narra-8m1.pages.dev` | `https://narra.mx` |

**Entornos donde aplicar:**
- ✅ Production
- ⚠️ Preview (opcional - las previews pueden usar su propio dominio)

**Nota:** Si la variable `APP_URL` no existe, el código usa `https://narra.mx` como fallback automáticamente.

---

### 3. 📮 Resend (Email Service) - Opcional

**Ve a Resend Dashboard:**
1. Abre https://resend.com/
2. Ve a **Settings** → **Domains**

**Verifica:**
- Si configuraste un dominio personalizado para emails (ej: `narra.mx`), asegúrate de que los DNS estén correctos
- Si usas `noreply@narra.mx`, verifica que el dominio esté verificado

**Emails que se envían:**
- Magic links para autores
- Notificaciones a suscriptores
- Magic links para suscriptores

---

### 4. 🌐 Cloudflare DNS - YA DEBERÍA ESTAR CONFIGURADO

Si ya cambiaste el dominio, esto debería estar listo. Verifica que tienes:

```
Tipo    Nombre    Contenido
CNAME   @         narra-8m1.pages.dev
CNAME   www       narra-8m1.pages.dev
```

O si usas custom domain de Cloudflare Pages, debería aparecer en:
**Pages** → **narra** → **Custom domains**

---

### 5. 🔍 Testing después de los cambios

Una vez que hayas hecho todos los cambios anteriores:

#### Test 1: Magic Link de Autor
1. Ve a https://narra.mx/app/
2. Ingresa tu email
3. Haz clic en "Enviar enlace"
4. Abre el email que recibes
5. **Verifica:** El link debe ser `https://narra.mx/app?token=...`
6. Haz clic en el link
7. **Verifica:** Debes quedar autenticado en https://narra.mx/app/

#### Test 2: Link compartido de historia
1. Desde el dashboard, abre una historia publicada
2. Copia el link para compartir
3. **Verifica:** El link debe ser `https://narra.mx/blog/story/...`
4. Ábrelo en una ventana de incógnito
5. **Verifica:** Debe cargar la historia correctamente

#### Test 3: Magic Link de Suscriptor
1. Envía una historia a un suscriptor
2. Abre el email que recibe
3. **Verifica:** El link debe ser `https://narra.mx/blog/story/...?token=...`
4. Haz clic en el link
5. **Verifica:** Debe autenticarse y ver la historia

---

## 📝 Resumen de Cambios

| Componente | Acción | Estado |
|------------|--------|--------|
| Código Flutter | Actualizar fallback en `story_share_link_builder.dart` | ✅ Hecho |
| Código API | Actualizar fallback en `author-magic-link.ts` | ✅ Hecho |
| Documentación | Actualizar URLs en READMEs | ✅ Hecho |
| Supabase Auth URLs | Agregar narra.mx a redirect URLs | ⚠️ **DEBES HACERLO** |
| Cloudflare Env Vars | Actualizar APP_URL a narra.mx | ⚠️ **DEBES HACERLO** |
| Testing | Probar magic links y links compartidos | ⚠️ **DEBES HACERLO** |

---

## 🆘 Problemas Comunes

### "El magic link no funciona"
**Causa:** Supabase Redirect URLs no incluye narra.mx
**Solución:** Verifica que agregaste `https://narra.mx/app/*` en Supabase → Authentication → URL Configuration

### "Los links compartidos siguen siendo narra-8m1.pages.dev"
**Causa:** La app de Flutter en cache
**Solución:** Haz un hard refresh (Ctrl+Shift+R) o borra cache del navegador

### "Error 404 en preview branches"
**Causa:** Las preview branches no tienen las redirect URLs
**Solución:** Asegúrate de mantener las URLs `.pages.dev` en Supabase

---

## 📅 Fecha de Migración

**Migración realizada:** 2025-11-04
**Dominio anterior:** https://narra-8m1.pages.dev/
**Dominio nuevo:** https://narra.mx/

---

**Una vez completados todos los pasos marcados con ⚠️, puedes eliminar este archivo.**
