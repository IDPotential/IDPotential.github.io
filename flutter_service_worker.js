'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"manifest.json": "a667cf404403961ebaea48905ccce3ad",
"zoom_service.js": "83cd4f7525191805e7be310949466791",
"index.html": "8f90b3274f9b3ce6e17e4d8366350fd3",
"/": "8f90b3274f9b3ce6e17e4d8366350fd3",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin.json": "dec2fe03796ce72b0d331c37d61c3f8c",
"assets/assets/images/IDPGMD092025.png": "2196e238c9c276cd54b2885ec7dc8dae",
"assets/assets/images/logo.jpg": "2bdf65eea9b0556f5739d23f8f7a9f3b",
"assets/assets/images/fon.png": "110ea1f3197c7bbcb43e38ae56541296",
"assets/assets/images/cards/role_10.png": "1f086e0e3ff0fda3beaf23336da43d10",
"assets/assets/images/cards/role_16.png": "3a0081740682ea0c3d230c4b74f4d10e",
"assets/assets/images/cards/role_20.png": "599dfa3b0eb9678ffaa0ab436c35adec",
"assets/assets/images/cards/role_17.png": "055111bdf3490ae960bcf24f97a8fddf",
"assets/assets/images/cards/role_6.png": "1f6b2807234bd03ddc393638b0a081a7",
"assets/assets/images/cards/role_13.png": "c7565f58af22b39b7095f3c29df4a191",
"assets/assets/images/cards/role_7.png": "76589134a5e7779ee50e6477d2bfeb51",
"assets/assets/images/cards/role_12.png": "e06c6837e4e1782361f68efdd2f32ea1",
"assets/assets/images/cards/role_18.png": "dff95def7c7a363878bd84387d948e0c",
"assets/assets/images/cards/role_9.png": "01c2cc30f9d2934c3b63a0f44f06bf28",
"assets/assets/images/cards/role_14.png": "15698ed192665a2947447e2d65c7b92b",
"assets/assets/images/cards/role_1.png": "11a49c3cc2af72a99683de6c650c269d",
"assets/assets/images/cards/role_19.png": "f1390f4dd3b0b582397ad76f2fdd61d7",
"assets/assets/images/cards/role_3.png": "31c2c1753bd0468d48c1c4e87a481bbe",
"assets/assets/images/cards/role_21.png": "85c59bac5ae38ab739252de3ae9235e5",
"assets/assets/images/cards/role_2.png": "e2e06bfa5106aab62e7f904c6c7f1098",
"assets/assets/images/cards/role_8.png": "f8e17fe2d7f065d68d99b20fb51c95b6",
"assets/assets/images/cards/role_11.png": "89c0a02949f6c071754081d23722c65a",
"assets/assets/images/cards/role_4.png": "5c920dc75f633693348fcf845fc05a81",
"assets/assets/images/cards/role_5.png": "ca55406642e94f3efaf0b670ee7a585c",
"assets/assets/images/cards/role_22.png": "82ddc763f30715d1bf30d93f821552c8",
"assets/assets/images/cards/role_15.png": "5ab57f6992e3ec29642782837c23d07b",
"assets/assets/images/logo.png": "63d29c271f01955040712efb1300b70f",
"assets/assets/images/Territory_Situations.png": "7bc8cd89fdf0b753b8d8469f9c66439d",
"assets/assets/fonts/DINPro-Bold.otf": "eeb004fd1098fdcc486235434e13e95a",
"assets/fonts/MaterialIcons-Regular.otf": "125a7c62ce622aa207772cf9047c0eb1",
"assets/NOTICES": "25dea1181c05bc2de106b4410d9f8ced",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "d7d83bd9ee909f8a9b348f56ca7b68c6",
"assets/packages/record_web/assets/js/record.fixwebmduration.js": "1f0108ea80c8951ba702ced40cf8cdce",
"assets/packages/record_web/assets/js/record.worklet.js": "6d247986689d283b7e45ccdf7214c2ff",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"assets/FontManifest.json": "825f5a236a0d9f4ed076bf5cff0608ec",
"assets/AssetManifest.bin": "2c33d09a9ddd54a89807a9c429bc89fb",
"assets/video/role_9.mp4": "f66f623e9d2897807bebad4b1a7b10a8",
"assets/video/role_19.mp4": "a5a3b79ccc807368bceb271c62d3a167",
"assets/video/role_4.mp4": "263b1731642eaddd975a45d87046da77",
"assets/video/role_18.mp4": "478a919a4ab16c8494c15c7caef0b0ae",
"assets/video/role_17.mp4": "15029105c11077cf52a2192752a0c11f",
"assets/video/role_20.mp4": "ef6a47201adec255f9e3823aadc255b6",
"assets/video/role_8.mp4": "4059ad263d487ce9c7bc0622c8c9362f",
"assets/video/role_16.mp4": "ee4feb0f4a6b19a4a6aff0e233e2ebb8",
"assets/video/role_21.mp4": "b88ac5fc7d81d0263d0a920956e81c7e",
"assets/video/role_14.mp4": "96351105d088360c72f4fc45116843e1",
"assets/video/role_12.mp4": "302d9cdaa8aac8625afaafb44c947e44",
"assets/video/role_2.mp4": "ad14cc38f07b5d585daf64537930a240",
"assets/video/role_3.mp4": "2beefbbeacd8437b0f5cf08db13c4bd0",
"assets/video/role_7.mp4": "1aa4eeccf840325801411c2a34a1ad1c",
"assets/video/role_5.mp4": "25aa8fc337fc47cb670150a1ad0466a8",
"assets/video/role_22.mp4": "5dce76bad4bb86b8b474dd96ee66ac4c",
"assets/video/role_13.mp4": "f99915b1a4d6cf1197c056c9518b5c1f",
"assets/video/role_6.mp4": "e845b77b4210eb4d54b47773a5ec68d5",
"assets/video/role_15.mp4": "8dd3484df82730edc5c5b4147a1a3893",
"assets/video/role_1.mp4": "f3bcdc0a1c267ecda71b8fff35351172",
"assets/video/role_10.mp4": "72a587470616537b98fc702d80385139",
"assets/video/role_11.mp4": "5eddb8943257d395300bff56a516af10",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter_bootstrap.js": "4ffe4d866c8d2aa55478e3bbf1733e11",
"coi-serviceworker.js": "f4e6e0859e3bb0a3c96a7604fc2f2df1",
"version.json": "94a8ed8fe9501ca89d1fdb89fc6bd173",
"main.dart.js": "495c9fcc1bdf7065b67eb1617de828a0"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
