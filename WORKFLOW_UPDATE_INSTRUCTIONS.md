# Actualización necesaria del workflow de GitHub Actions

## El problema: Refresh en /app/* redirecciona a la página principal

Cuando actualizas en cualquier ruta de Flutter (ej: /app/stories), estás siendo redirigido
a la página principal de React. Esto significa que el archivo `_redirects` no se está
aplicando correctamente en Cloudflare Pages.

El archivo `.github/workflows/cf-pages.yml` necesita actualizarse con mejores verificaciones
para diagnosticar y solucionar este problema.

## Cambios necesarios:

### 1. Actualizar el paso "Build Web (release)"

**Busca esta línea (aproximadamente línea 46-50):**
```yaml
      - name: Build Web (release)
        run: >
          flutter build web --release
          --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }}
          --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
```

**Cámbiala por:**
```yaml
      - name: Build Web (release)
        run: >
          flutter build web --release
          --base-href=/app/
          --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }}
          --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
```

**⚠️ Nota:** Se agregó `--base-href=/app/` para que Flutter se sirva desde `/app/*`

### 2. Agregar pasos después del build de Flutter

**Después del paso "Build Web (release)", agrega estos nuevos pasos:**

```yaml
      - name: Move Flutter to /app subdirectory
        run: |
          echo "Moving Flutter files to build/web/app/"
          mkdir -p build/web/app
          cd build/web
          for item in *; do
            if [ "$item" != "app" ] && [ "$item" != "_redirects" ]; then
              mv "$item" app/ || true
            fi
          done
          cd ../..
          echo "Flutter files moved successfully"

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: blog/package-lock.json

      - name: Install React dependencies
        run: |
          cd blog
          npm ci
          cd ..

      - name: Build React app (landing + blog)
        run: |
          cd blog
          npm run build
          cd ..
          echo "React build complete"

      - name: Copy _redirects file
        run: |
          cp web/_redirects build/web/_redirects
          echo "=== _redirects file copied ==="
          echo "Content of _redirects:"
          cat build/web/_redirects
          echo ""
          echo "=== Final build/web/ structure ==="
          ls -la build/web/
          echo ""
          echo "=== Contents of build/web/app/ ==="
          ls -la build/web/app/ | head -10
          echo ""
          echo "=== Verifying key files exist ==="
          test -f build/web/_redirects && echo "✓ _redirects exists" || echo "✗ _redirects missing"
          test -f build/web/index.html && echo "✓ React index.html exists" || echo "✗ React index.html missing"
          test -f build/web/app/index.html && echo "✓ Flutter index.html exists" || echo "✗ Flutter index.html missing"
```

**⚠️ IMPORTANTE:** Este paso ahora incluye verificaciones detalladas para asegurar que:
- El archivo `_redirects` se copió correctamente
- El contenido del archivo es el correcto
- Todos los archivos necesarios existen en sus ubicaciones correctas


### 3. Resultado final

Después de estos cambios, el proceso de build será:

1. ✅ Construir Flutter con `--base-href=/app/`
2. ✅ Mover todos los archivos de Flutter a `build/web/app/`
3. ✅ Construir React (landing + blog) en `build/web/` (raíz)
4. ✅ Copiar el archivo `_redirects`

Estructura final de `build/web/`:
```
build/web/
├── index.html          (React - landing page)
├── assets/             (React assets)
├── _redirects          (Cloudflare routing)
└── app/
    ├── index.html      (Flutter app)
    ├── flutter.js
    ├── flutter_bootstrap.js
    └── ... (todos los archivos de Flutter)
```

## ¿Cómo aplicar estos cambios?

### OPCIÓN RECOMENDADA: Copiar el archivo completo

El contenido completo del workflow actualizado está en el archivo `NEW_WORKFLOW_FILE.yml`
en la raíz del proyecto.

**Pasos:**
1. Ve a tu repositorio en GitHub
2. Navega a `.github/workflows/cf-pages.yml`
3. Haz clic en el icono de lápiz para editar
4. Borra TODO el contenido actual
5. Abre `NEW_WORKFLOW_FILE.yml` (en la raíz del repo)
6. Copia TODO su contenido y pégalo en `cf-pages.yml`
7. Haz commit con el mensaje: "Add debug output to workflow for _redirects verification"
8. El workflow se ejecutará automáticamente

### Verificación después del deploy

Una vez que el workflow termine, revisa los logs del paso "Copy _redirects file":
- Debe mostrar el contenido completo del archivo `_redirects`
- Debe mostrar checkmarks (✓) para todos los archivos
- Si algún archivo falta, el problema está en el build, no en los redirects

## ¿Por qué es necesario esto?

El problema actual es que Flutter se construye en la raíz y se sirve en `/`, causando:
- Loop infinito de redirecciones
- Flutter cargando cuando debería ser React
- "Cargando historias..." cuando debería ser el landing

Con estos cambios:
- `/` → React landing page (NO Flutter)
- `/blog/*` → React blog
- `/app/*` → Flutter app

Esto elimina el loop infinito y asegura que cada ruta sirva el código correcto.
