/*! coi-serviceworker v0.1.7 - Guido Zuidhof, licensed under MIT */
let coepCredentialless = false;
if (typeof window === 'undefined') {
    self.addEventListener("install", () => self.skipWaiting());
    self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

    self.addEventListener("message", (ev) => {
        if (!ev.data) {
            return;
        } else if (ev.data.type === "deregister") {
            self.registration.unregister().then(() => {
                return self.clients.matchAll();
            }).then(clients => {
                clients.forEach(client => client.navigate(client.url));
            });
        }
    });

    self.addEventListener("fetch", function (event) {
        const r = event.request;
        if (r.cache === "only-if-cached" && r.mode !== "same-origin") {
            return;
        }

        const coep = coepCredentialless ? "credentialless" : "require-corp";
        const headers = new Headers(r.headers);
        headers.set("Cross-Origin-Embedder-Policy", coep);
        headers.set("Cross-Origin-Opener-Policy", "same-origin");

        event.respondWith(
            fetch(r, {
                cache: r.cache,
                credentials: r.credentials,
                headers: headers,
                integrity: r.integrity,
                keepalive: r.keepalive,
                method: r.method,
                mode: r.mode,
                redirect: r.redirect,
                referrer: r.referrer,
                referrerPolicy: r.referrerPolicy,
                signal: r.signal,
            }).then((response) => {
                if (response.status === 0) {
                    return response;
                }

                const newHeaders = new Headers(response.headers);
                newHeaders.set("Cross-Origin-Embedder-Policy", coep);
                newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");

                return new Response(response.body, {
                    status: response.status,
                    statusText: response.statusText,
                    headers: newHeaders,
                });
            })
        );
    });

} else {
    (() => {
        // You can customize the behavior of this script through a global `coi` variable.
        const coi = {
            shouldRegister: () => true,
            shouldDeregister: () => false,
            coepCredentialless: () => false,
            doReload: () => window.location.hostname !== 'localhost', // Reload unless local dev
            quiet: false,
            ...window.coi
        };

        const n = navigator;
        if (coi.shouldDeregister() && n.serviceWorker && n.serviceWorker.controller) {
            n.serviceWorker.controller.postMessage({ type: "deregister" });
        }

        // If we're already coi: do nothing. Perhaps it's due to this script doing its job, or COOP/COEP are
        // already set from the origin server.
        if (window.crossOriginIsolated !== false || !coi.shouldRegister()) return;

        if (!n.serviceWorker) {
            return;
        }

        n.serviceWorker.register(window.document.currentScript.src).then(
            (registration) => {
                if (coi.quiet === false) console.log("COI: Registered, reloading...");

                registration.addEventListener("updatefound", () => {
                    if (coi.quiet === false) console.log("COI: Reloading due to update...");
                    if (coi.doReload()) window.location.reload();
                });

                if (coi.doReload()) {
                    window.location.reload();
                }
            },
            (err) => {
                if (coi.quiet === false) console.error("COI: ", err);
            }
        );
    })();
}
