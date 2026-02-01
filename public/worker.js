const logFetches = location.protocol !== "https:";

const currentCacheVersion = "v1";
const currentCaches = {
    refreshed: `refreshed-${currentCacheVersion}`,
    static: `static-${currentCacheVersion}`,
};

addEventListener("install", (event) => {
    event.waitUntil(
        caches.open(currentCaches.refreshed).then((cache) => cache.addAll([
            "/",
            "/D12.svg",
            "/dicey.webmanifest",
            "/main.css",
            "/main.rb",
            "/dicey.pack.rb",
            "/vector_number.pack.rb",
        ])
    ));
    event.waitUntil(
        caches.open(currentCaches.static).then((cache) => cache.addAll([
            "https://cdn.jsdelivr.net/npm/@ruby/3.4-wasm-wasi@2.7.2/dist/browser.script.iife.js",
            "https://cdn.jsdelivr.net/npm/@ruby/3.4-wasm-wasi@2.7.2/dist/ruby+stdlib.wasm",
            "https://fonts.gstatic.com/s/vendsans/v1/E21l_d7ijufNwCJPEUscVA9V.woff2",
            "https://fonts.gstatic.com/s/zain/v4/sykz-y9lm7soOG7ohS23-w.woff2",
        ])
    ));
    skipWaiting();
});
addEventListener("activate", (event) => {
    const expectedCacheNamesSet = new Set(Object.values(currentCaches));
    event.waitUntil(
        caches.keys().then((cacheNames) =>
            Promise.all(
                cacheNames.map((cacheName) => {
                    if (!expectedCacheNamesSet.has(cacheName)) {
                        console.log("Deleting out of date cache:", cacheName);
                        return caches.delete(cacheName);
                    }
                    return undefined;
                }),
            ),
        ),
    );
    event.waitUntil(clients.claim());
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
const putInCache = async (request, response, cacheName) => {
    const cache = await caches.open(cacheName);
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
        if (logFetches) console.log(`Fetching ${request.url}`);
        const networkResponse = await fetch(request);
        if (networkResponse.ok) {
            event.waitUntil(putInCache(request, networkResponse.clone(), currentCaches.static));
        }
        return networkResponse;
    } catch (error) {
        return Response.error();
    }
};
const cacheFirstWithRefresh = async ({request, event}) => {
    const fetchResponsePromise = fetch(request).then(async (networkResponse) => {
        if (logFetches) console.log(`Fetching ${request.url}`);
        if (networkResponse.ok) {
            putInCache(request, networkResponse.clone(), currentCaches.refreshed);
        }
        return networkResponse;
    }).catch(() => Response.error());
    try {
        return (await caches.match(request)) || (await fetchResponsePromise);
    } catch (error) {
        return Response.error();
    }
};
const networkFirst = async ({request, event}) => {
    try {
        if (logFetches) console.log(`Fetching ${request.url}`);
        const networkResponse = await fetch(request);
        if (networkResponse.ok) {
            event.waitUntil(putInCache(request, networkResponse.clone(), currentCaches.refreshed));
        }
        return networkResponse;
    } catch (error) {
        const cachedResponse = await caches.match(request);
        return cachedResponse || Response.error();
    }
};
const noCache = async ({ request, event }) => fetch(request);

addEventListener("fetch", (event) => {
    let request = event.request;
    const url = new URL(event.request.url);

    // Cache CDN's artifacts aggressively, but refresh our own assets when possible.
    let strategy = networkFirst;
    if (url.protocol !== "https:" && url.protocol !== "http:") {
        strategy = noCache;
    }
    else if (url.origin !== location.origin) {
        strategy = cacheFirst;
    }
    else if (url.pathname.match(/\.png$/)) {
        // Only happens when installing webapp.
        strategy = noCache;
    }
    else if (url.pathname.match(/\.svg$/)) {
        strategy = cacheFirstWithRefresh;
    }
    else if (url.origin === location.origin && url.pathname === "/") {
        // Protect against any search params and "?" being treated as a separate page.
        request = new Request(new URL("/", location));
    }

    if (logFetches) console.log(`Using ${strategy.name} for ${url}`);
    event.respondWith(strategy({request, event}));
    broadcastCacheSize();
});
