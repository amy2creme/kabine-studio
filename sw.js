// Service worker minimal : rend l'appli installable. Pas de cache : les données restent toujours à jour.
self.addEventListener("install", e => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));
self.addEventListener("fetch", () => {});
