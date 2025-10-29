// Cloudflare Pages middleware for handling Flutter and React routing
export async function onRequest(context) {
  const { request, next, env } = context;
  const url = new URL(request.url);
  const pathname = url.pathname;

  // Handle Flutter app routes - HIGHEST PRIORITY
  // Any request to /app, /app/, or /app/* should serve Flutter
  if (pathname === '/app' || pathname === '/app/' || pathname.startsWith('/app/')) {
    // Only rewrite if it's not already requesting a static file
    if (!pathname.includes('.') || pathname.endsWith('.html')) {
      const flutterUrl = new URL('/app/index.html', request.url);
      return env.ASSETS.fetch(flutterUrl);
    }
  }

  // Handle blog routes - serve React SPA
  if (pathname.startsWith('/blog/')) {
    if (!pathname.includes('.') || pathname.endsWith('.html')) {
      const reactUrl = new URL('/index.html', request.url);
      return env.ASSETS.fetch(reactUrl);
    }
  }

  // Pass through everything else (API routes, static assets, root)
  return await next();
}
