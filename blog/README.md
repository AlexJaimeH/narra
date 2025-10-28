# Blog de Narra - React

Blog público donde los suscriptores pueden acceder a las historias publicadas por los autores mediante magic links.

## Características

- ✅ **Acceso sin contraseña**: Los suscriptores entran mediante enlaces mágicos (magic links)
- ✅ **Totalmente independiente**: No depende del sistema de autenticación principal de Narra
- ✅ **Colores de marca correctos**: Usa la paleta aqua/teal (#4DB3A8)
- ✅ **UI/UX moderna**: Diseño limpio y responsive con Tailwind CSS
- ✅ **Sin Flutter**: Implementado completamente en React/TypeScript
- ✅ **Comentarios y reacciones**: Los suscriptores pueden interactuar con las historias

## Estructura del Proyecto

```
blog/
├── src/
│   ├── components/     # Componentes reutilizables
│   │   ├── Header.tsx
│   │   ├── StoryCard.tsx
│   │   ├── Comments.tsx
│   │   ├── Loading.tsx
│   │   └── ErrorMessage.tsx
│   ├── pages/          # Páginas principales
│   │   ├── BlogHome.tsx    # Lista de historias
│   │   └── StoryPage.tsx   # Historia individual
│   ├── services/       # Servicios de API
│   │   ├── publicAccessService.ts
│   │   ├── accessManager.ts
│   │   ├── storyService.ts
│   │   └── feedbackService.ts
│   ├── types/          # Tipos TypeScript
│   │   └── index.ts
│   ├── styles/         # Estilos globales
│   │   └── index.css
│   ├── App.tsx         # Configuración de rutas
│   └── main.tsx        # Punto de entrada
├── index.html
├── package.json
├── vite.config.ts
└── tailwind.config.js
```

## Desarrollo Local

### Prerequisitos

- Node.js 18+
- npm o yarn

### Instalación

```bash
cd blog
npm install
```

### Servidor de Desarrollo

```bash
npm run dev
```

El blog estará disponible en `http://localhost:5173/blog/`

### Build de Producción

```bash
npm run build
```

El build se genera en `../build/web/blog/` para ser servido por Cloudflare Pages.

## Rutas

El blog usa las siguientes rutas:

- `/blog/subscriber/:subscriberId?author=...&token=...` - Página principal con lista de historias
- `/blog/story/:storyId?author=...&token=...` - Historia individual

## Parámetros de URL

Todas las rutas del blog requieren estos parámetros:

- `author`: ID del autor
- `subscriber`: ID del suscriptor
- `token`: Magic link token
- `name` (opcional): Nombre del suscriptor
- `source` (opcional): Fuente del acceso (email, invite, etc.)

## Tecnologías

- **React 18**: Librería UI
- **TypeScript**: Type safety
- **Vite**: Build tool rápido
- **Tailwind CSS**: Estilos utilitarios
- **React Router**: Enrutamiento
- **Supabase JS Client**: Base de datos

## Colores de Marca

```js
{
  primary: '#4DB3A8',        // Teal/Aqua principal
  'primary-solid': '#38827A',
  'primary-hover': '#2F6B64',
  accent: '#00EAD8',         // Cyan accent
}
```

## Integración con Narra

El blog se sirve desde `/blog/*` y es completamente independiente de la aplicación Flutter principal. Los redirects están configurados en `web/_redirects`:

```
/blog/*  /blog/index.html  200
```

## Build para Producción

El blog se construye automáticamente como parte del proceso de deploy:

1. `cd blog && npm install`
2. `npm run build` (genera archivos en `../build/web/blog/`)
3. Cloudflare Pages sirve desde `build/web/`

## Mejoras Implementadas

- ✅ Colores aqua correctos (no morados)
- ✅ Nombre real del autor (no "Autor/a de Narra")
- ✅ Sin botón "Volver a blog" en páginas de historia
- ✅ Contador de historias correcto
- ✅ Imágenes responsive sin placeholder cuando no hay imagen
- ✅ UI/UX moderna y limpia
- ✅ Separación completa del sistema de autenticación de Narra
