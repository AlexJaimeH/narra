# AGENTS.md — Narra

## Objetivo
Agente: continúa el desarrollo de esta app Flutter Web. Mantén el deploy automático a Cloudflare Pages (workflow ya creado).

## Setup
- Usa Flutter **stable**.
- Instala deps: `flutter pub get`

## QA antes de cada commit/PR
- Linter: `flutter analyze`
- Tests (si existen): `flutter test`

## Build
- Web release: `flutter build web --release`

## Política de cambios
- Crea rama: `feat/<breve-descripcion>` o `fix/<breve-descripcion>`
- Abre **PR** contra `main`. No pushes directos a `main`.
- No toques `.github/workflows/cf-pages.yml` salvo que se pida.
- Mantén `.gitignore` respetado.

## Deploy
- Al hacer **merge** a `main`, Actions construye y publica a **producción** en Cloudflare Pages (`narra`).
- En **pull_request**, Actions construye **preview**.

## Estilo
- Código idiomático Flutter/Dart.
- Commits convencionales: `feat: ...`, `fix: ...`, `chore: ...`, `refactor: ...`

## Notas
- Si agregas rutas SPA, el archivo `web/_redirects` ya está configurado.
- Evita dependencias nativas móviles; foco en **Web**.
