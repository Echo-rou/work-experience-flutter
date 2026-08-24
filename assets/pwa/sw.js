const CACHE = 'work-experience-pwa-v9';
const SHELL = ['/app-shell', '/pwa-icon.png'];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.pathname.startsWith('/api/')) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).then(async response => {
      if (!response.ok) return (await caches.match('/app-shell')) || response;
      if (url.pathname === '/' || url.pathname === '/index.html' || url.pathname === '/app-shell') {
        const cache = await caches.open(CACHE);
        await cache.put('/app-shell', response.clone());
      }
      return response;
    }).catch(() => caches.match('/app-shell')));
    return;
  }
  event.respondWith(fetch(event.request).catch(() => caches.match(event.request)));
});
