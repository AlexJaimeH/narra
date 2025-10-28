# Actualización necesaria del workflow de GitHub Actions

El archivo `.github/workflows/cf-pages.yml` necesita actualizarse para construir correctamente
tanto Flutter como React. No puedo modificar este archivo automáticamente por restricciones
de permisos de GitHub.

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
          echo "Final structure:"
          ls -la build/web/ | head -15
```

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

### Opción 1: Editar directamente en GitHub
1. Ve a tu repositorio en GitHub
2. Navega a `.github/workflows/cf-pages.yml`
3. Haz clic en el icono de lápiz para editar
4. Aplica los cambios descritos arriba
5. Haz commit directamente a la rama `claude/fix-emoji-cloudflare-deploy-011CUZv1bTfeviQ6oMzPyB6a`

### Opción 2: Editar localmente
1. Abre `.github/workflows/cf-pages.yml` en tu editor
2. Aplica los cambios descritos arriba
3. Commit y push:
   ```bash
   git add .github/workflows/cf-pages.yml
   git commit -m "Update workflow to build React landing and move Flutter to /app"
   git push
   ```

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
