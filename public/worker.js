const currentCacheName = "v1";

const putInCache = async (request, response) => {
    const cache = await caches.open(currentCacheName);
    await cache.put(request, response);
};

addEventListener("install", (event) => {
    event.waitUntil(
        caches.open(currentCacheName).then((cache) => cache.addAll([
            "/",
            "/main.css",
            "/main.rb",
            "/dicey.pack.rb",
            "/vector_number.pack.rb",
            "/D12.svg",
            "/dicey.webmanifest",
            "https://cdn.jsdelivr.net/npm/@ruby/3.4-wasm-wasi@2.7.2/dist/browser.script.iife.js",
        ])
    ));
    skipWaiting();
});
addEventListener("activate", (event) => {
    event.waitUntil(clients.claim());
});

// Fetch caching strategies
const cacheFirst = async ({ request, event }) => {
    const responseFromCache = await caches.match(request);
    if (responseFromCache) {
        return responseFromCache;
    }
    try {
        const networkResponse = await fetch(request);
        if (networkResponse.ok) {
            event.waitUntil(putInCache(request, networkResponse.clone()));
        }
        return networkResponse;
    } catch (error) {
        return Response.error();
    }
};
const cacheFirstWithRefresh = async ({request, event}) => {
    const fetchResponsePromise = fetch(request).then(async (networkResponse) => {
        if (networkResponse.ok) {
            event.waitUntil(putInCache(request, networkResponse.clone()));
        }
        return networkResponse;
    });
    try {
        return (await caches.match(request)) || (await fetchResponsePromise);
    } catch (error) {
        return Response.error();
    }
};
const networkFirst = async ({request, event}) => {
    try {
        const networkResponse = await fetch(request);
        if (networkResponse.ok) {
            event.waitUntil(putInCache(request, networkResponse.clone()));
        }
        return networkResponse;
    } catch (error) {
        const cachedResponse = await caches.match(request);
        return cachedResponse || Response.error();
    }
};

// Cache CDN's artifacts aggressively, but refresh our own assets when possible.
addEventListener("fetch", (event) => {
    const url = new URL(event.request.url);
    let strategy = networkFirst;
    if (url.host === "cdn.jsdelivr.net") {
        strategy = cacheFirst;
    }
    event.respondWith(
        strategy({
            request: event.request,
            event,
        }),
    );
});
