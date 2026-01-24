const currentCacheName = "v1";

addEventListener("install", (event) => {
    event.waitUntil(
        caches.open(currentCacheName).then((cache) => cache.addAll([
            "/",
            "/D12.svg",
            "/dicey.webmanifest",
            "/main.css",
            "/main.rb",
            "/dicey.pack.rb",
            "/vector_number.pack.rb",
            "https://cdn.jsdelivr.net/npm/@ruby/3.4-wasm-wasi@2.7.2/dist/browser.script.iife.js",
            "https://cdn.jsdelivr.net/npm/@ruby/3.4-wasm-wasi@2.7.2/dist/ruby+stdlib.wasm"
        ])
    ));
    skipWaiting();
});
addEventListener("activate", (event) => {
    event.waitUntil(clients.claim());
    broadcastCacheSize();
});

const broadcastCacheSize = async () => {
    const size = await ((navigator.storage && navigator.storage.estimate) ?
        navigator.storage.estimate().then((estimate) => estimate.usage).catch(() => "???")
        : Promise.resolve("???"));

    const clients = await self.clients.matchAll();
    clients.forEach(client => {
        client.postMessage({
            type: "CACHE_SIZE_UPDATE",
            size: size
        });
    });
}
const putInCache = async (request, response) => {
    const cache = await caches.open(currentCacheName);
    await cache.put(request, response);

    broadcastCacheSize();
};

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
const noCache = async ({ request, event }) => fetch(request);

// Cache CDN's artifacts aggressively, but refresh our own assets when possible.
addEventListener("fetch", (event) => {
    const url = new URL(event.request.url);
    let strategy = networkFirst;
    if (url.protocol !== "https:" && url.protocol !== "http:") {
        strategy = noCache;
    }
    else if (url.host === "cdn.jsdelivr.net") {
        strategy = cacheFirst;
    }
    else if (url.pathname.match(/\.png$/)) {
        strategy = noCache;
    }
    // console.log(`Using ${strategy.name} for ${url}`);
    event.respondWith(
        strategy({
            request: event.request,
            event,
        }),
    );
});
