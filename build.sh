#!/bin/bash
set -e

echo "=== Building Narra ==="
echo ""

# Step 1: Build Flutter app
echo "Step 1: Building Flutter app..."
flutter build web --release
echo "Flutter build complete."
echo ""

# Step 2: Move Flutter files to /app subdirectory
echo "Step 2: Moving Flutter files to /app subdirectory..."
mkdir -p build/web/app
# Move all Flutter build files to /app, keeping _redirects at root
cd build/web
for item in *; do
  if [ "$item" != "app" ] && [ "$item" != "_redirects" ]; then
    mv "$item" app/
  fi
done
cd ../..
echo "Flutter files moved to build/web/app/"
echo ""

# Step 3: Build React app (landing + blog)
echo "Step 3: Building React app (landing + blog)..."
cd blog
npm run build
cd ..
echo "React build complete."
echo ""

# Step 4: Ensure _redirects file is in place
echo "Step 4: Ensuring _redirects file is in place..."
cp web/_redirects build/web/_redirects
echo "_redirects file copied."
echo ""

echo "=== Build Complete ==="
echo "Output structure:"
echo "  build/web/                 - React app (landing + blog)"
echo "  build/web/app/             - Flutter app"
echo "  build/web/_redirects       - Cloudflare routing config"
echo ""
echo "Verifying structure:"
ls -la build/web/ | head -15
