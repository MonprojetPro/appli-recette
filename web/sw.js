'use strict';

const CACHE_NAME = 'menufacile-v2';

// Installation — mise en cache des ressources critiques
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll([
        '/',
        '/index.html',
        '/manifest.json',
        '/flutter_bootstrap.js',
        '/flutter.js',
      ]).catch(() => {
        // Ignorer les erreurs de précache au premier install
      });
    })
  );
});

// Activation — nettoyer les anciens caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    ).then(() => self.clients.claim())
  );
});

// Fetch — network-first, fallback sur cache pour navigation
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);

  // 1. Ignorer tout ce qui n'est pas http(s) — chrome-extension, data:, etc.
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return;

  // 2. Ne JAMAIS intercepter les requêtes cross-origin (Supabase, APIs externes).
  //    Le SW interceptait avant les calls auth Supabase et les cassait.
  if (url.origin !== self.location.origin) return;

  // 3. Navigation (HTML) — network-first puis fallback /index.html, sinon offline.
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(async () => {
        const cached = await caches.match('/index.html');
        return cached || new Response(
          '<h1>Hors ligne</h1><p>Reconnecte-toi à internet.</p>',
          { status: 503, headers: { 'Content-Type': 'text/html; charset=utf-8' } }
        );
      })
    );
    return;
  }

  // 4. Ressources statiques same-origin — network-first avec cache fallback.
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Ne cacher que les réponses 200 same-origin "basic" (pas opaque/cross).
        if (response && response.status === 200 && response.type === 'basic') {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, clone).catch(() => {
              // Silencieux — un échec de cache ne doit pas casser le fetch.
            });
          });
        }
        return response;
      })
      .catch(async () => {
        const cached = await caches.match(event.request);
        return cached || Response.error();
      })
  );
});
