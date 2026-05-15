'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"coi-serviceworker.js": "f4e6e0859e3bb0a3c96a7604fc2f2df1",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/assets/fonts/DINPro-Bold.otf": "eeb004fd1098fdcc486235434e13e95a",
"assets/assets/images/nadya_toma_game.jpg": "63490dc302bd3a1c497ac89ad680878b",
"assets/assets/images/fest/lidia_leonteva.jpg": "977dbadedab317772943d4c020e9019e",
"assets/assets/images/fest/oleg_baranets.jpg": "3fc381a85703448982d7ec7d28cbdf6a",
"assets/assets/images/fest/natalia_baranets.jpg": "e7c56473e41223365eb906a5a5d2101e",
"assets/assets/images/fest/olga_volkova.jpg": "9ca1c32da917e8388ba419908d2708e8",
"assets/assets/images/fest/olga_ra.jpg": "a4307fcdb03a59a0fd0bb17317be1a14",
"assets/assets/images/fest/four_energies.jpg": "b7f25b894d92cf8b4525478f1c3aaae1",
"assets/assets/images/fest/tatiana_mashtakova.jpg": "fd4da0fc0cea74dbf6485e931fc21933",
"assets/assets/images/fest/yuliana_kell.jpg": "8b8d463d6c88876af54379615a82a0ee",
"assets/assets/images/fest/andrey_konstantinov.jpg": "d25df7e5cb617d2705ccf9d27fa8a8bc",
"assets/assets/images/fest/irina_prunchak.jpg": "855757a88e97c47c01c37e2571adf1af",
"assets/assets/images/fest/irina_boikova.jpg": "084d3120dbd110e11df238bff9fc3d2c",
"assets/assets/images/fest/ekaterina_kurchavina.jpg": "185794afa08017d84e3eca196bbd4804",
"assets/assets/images/fest/yuliana_eira.jpg": "02b7c579518303055d77a153a8797100",
"assets/assets/images/fest/olga_doroshkevich.jpg": "754ccce4d99948b091aeb0718795940e",
"assets/assets/images/Anya_Torpan.jpg": "82e8b70d970b3619bf63f936021889aa",
"assets/assets/images/ekaterina_volkova.jpg": "5dc723d1b6473589605bf21eedba2b29",
"assets/assets/images/fon.png": "110ea1f3197c7bbcb43e38ae56541296",
"assets/assets/images/svetlana_gurina.jpg": "b461df9b70e54b20cb6015f7077c3fa4",
"assets/assets/images/vladimir_papushin.jpg": "c8ab0083f31da6186b1df50f7a1415a2",
"assets/assets/images/cards/role_22.png": "82ddc763f30715d1bf30d93f821552c8",
"assets/assets/images/cards/role_5.png": "ca55406642e94f3efaf0b670ee7a585c",
"assets/assets/images/cards/role_9.png": "01c2cc30f9d2934c3b63a0f44f06bf28",
"assets/assets/images/cards/role_18.png": "dff95def7c7a363878bd84387d948e0c",
"assets/assets/images/cards/role_14.png": "15698ed192665a2947447e2d65c7b92b",
"assets/assets/images/cards/role_16.png": "3a0081740682ea0c3d230c4b74f4d10e",
"assets/assets/images/cards/role_17.png": "055111bdf3490ae960bcf24f97a8fddf",
"assets/assets/images/cards/role_15.png": "5ab57f6992e3ec29642782837c23d07b",
"assets/assets/images/cards/role_12.png": "e06c6837e4e1782361f68efdd2f32ea1",
"assets/assets/images/cards/role_1.png": "11a49c3cc2af72a99683de6c650c269d",
"assets/assets/images/cards/role_7.png": "76589134a5e7779ee50e6477d2bfeb51",
"assets/assets/images/cards/role_3.png": "31c2c1753bd0468d48c1c4e87a481bbe",
"assets/assets/images/cards/role_10.png": "1f086e0e3ff0fda3beaf23336da43d10",
"assets/assets/images/cards/role_11.png": "89c0a02949f6c071754081d23722c65a",
"assets/assets/images/cards/role_13.png": "c7565f58af22b39b7095f3c29df4a191",
"assets/assets/images/cards/role_4.png": "5c920dc75f633693348fcf845fc05a81",
"assets/assets/images/cards/role_6.png": "1f6b2807234bd03ddc393638b0a081a7",
"assets/assets/images/cards/role_20.png": "599dfa3b0eb9678ffaa0ab436c35adec",
"assets/assets/images/cards/role_19.png": "f1390f4dd3b0b582397ad76f2fdd61d7",
"assets/assets/images/cards/role_8.png": "f8e17fe2d7f065d68d99b20fb51c95b6",
"assets/assets/images/cards/role_2.png": "e2e06bfa5106aab62e7f904c6c7f1098",
"assets/assets/images/cards/role_21.png": "85c59bac5ae38ab739252de3ae9235e5",
"assets/assets/images/olga.jpg": "754ccce4d99948b091aeb0718795940e",
"assets/assets/images/photo_2102/DSC05075%2520(1).jpg": "1412b7f24e0f08f1b71b2f51f0a6bf9d",
"assets/assets/images/photo_2102/DSC05021%2520(1).jpg": "59cc8d7af4aac9dc195723d1774b242c",
"assets/assets/images/photo_2102/DSC05033%2520(1).jpg": "091974ca80f2deff923db445fbacd9cf",
"assets/assets/images/photo_2102/DSC05042%2520(1).jpg": "4be00a1ccfa16c5e31547941caa937c0",
"assets/assets/images/photo_2102/DSC05192%2520(1).jpg": "a638f0e4c8736f5776241f1304aa5bde",
"assets/assets/images/photo_2102/DSC05162%2520(1).jpg": "a1c08eedd7e1ff8b5db54a3782ec4aa1",
"assets/assets/images/photo_2102/DSC05070%2520(1).jpg": "7e83fbf8dc6c89ce2ba3be5e2b635018",
"assets/assets/images/photo_2102/DSC05212%2520(1).jpg": "73f63ced04fdcff0b35167629ee111d3",
"assets/assets/images/photo_2102/DSC05085%2520(1).jpg": "c8d73bc8a2f17759fb587d3c10195b90",
"assets/assets/images/photo_2102/DSC05106%2520(1).jpg": "25f8ddab8071fed06e30d457908df52c",
"assets/assets/images/photo_2102/DSC05067%2520(1).jpg": "231c7398530e1f29890306ade3400479",
"assets/assets/images/photo_2102/DSC05032%2520(1).jpg": "24643cfa9fb7422494220ed0ec5cef85",
"assets/assets/images/%25D0%259E%25D0%25BB%25D0%25B5%25D0%25B3%2520%25D0%2591%25D0%25B0%25D1%2580%25D0%25B0%25D0%25BD%25D0%25B5%25D1%2586.jpg": "3fc381a85703448982d7ec7d28cbdf6a",
"assets/assets/images/logo.png": "63d29c271f01955040712efb1300b70f",
"assets/assets/images/nataliabaranets.jpg": "11a5e8dcdb9137383c9f85f28ec58556",
"assets/assets/images/ksenia_varakina.jpg": "74d950d3785e5119a4a393b7624ac4aa",
"assets/assets/images/irina_viznyuk.jpg": "6ce336b175450599cf22e09a20113886",
"assets/assets/images/vera.jpg": "08eb9dc0cb871191ad18bdc2fafad0e3",
"assets/assets/images/nadezhda_lanskaya.jpg": "442a90e635cc1b336ad1a74304e28a39",
"assets/assets/images/irina_abramova.jpg": "a44f34d965952cd266d84e5bcf82dc44",
"assets/assets/images/logo.jpg": "2bdf65eea9b0556f5739d23f8f7a9f3b",
"assets/assets/images/Territory_Situations.png": "7bc8cd89fdf0b753b8d8469f9c66439d",
"assets/assets/images/varvara_ardel.jpg": "390af0db4fbab25ca05661a8ed5c0156",
"assets/assets/images/toma.jpg": "99eb7ee82005cceb868404f2fb1c1430",
"assets/assets/images/ekaterina_kurchavina.jpg": "185794afa08017d84e3eca196bbd4804",
"assets/assets/images/olegbaranets.jpg": "3fc381a85703448982d7ec7d28cbdf6a",
"assets/assets/images/IDPGMD092025.png": "2196e238c9c276cd54b2885ec7dc8dae",
"assets/fonts/MaterialIcons-Regular.otf": "06bd55d5006117362be5ccec7fa342c8",
"assets/AssetManifest.bin": "d5eca4177a3fd7668a489a85f2e81d75",
"assets/video/role_17.mp4": "15029105c11077cf52a2192752a0c11f",
"assets/video/role_8.mp4": "4059ad263d487ce9c7bc0622c8c9362f",
"assets/video/role_12.mp4": "302d9cdaa8aac8625afaafb44c947e44",
"assets/video/role_7.mp4": "1aa4eeccf840325801411c2a34a1ad1c",
"assets/video/role_6.mp4": "e845b77b4210eb4d54b47773a5ec68d5",
"assets/video/role_22.mp4": "5dce76bad4bb86b8b474dd96ee66ac4c",
"assets/video/role_14.mp4": "96351105d088360c72f4fc45116843e1",
"assets/video/role_11.mp4": "5eddb8943257d395300bff56a516af10",
"assets/video/role_21.mp4": "b88ac5fc7d81d0263d0a920956e81c7e",
"assets/video/role_5.mp4": "25aa8fc337fc47cb670150a1ad0466a8",
"assets/video/role_2.mp4": "ad14cc38f07b5d585daf64537930a240",
"assets/video/role_13.mp4": "f99915b1a4d6cf1197c056c9518b5c1f",
"assets/video/role_19.mp4": "a5a3b79ccc807368bceb271c62d3a167",
"assets/video/role_16.mp4": "ee4feb0f4a6b19a4a6aff0e233e2ebb8",
"assets/video/role_9.mp4": "f66f623e9d2897807bebad4b1a7b10a8",
"assets/video/role_4.mp4": "263b1731642eaddd975a45d87046da77",
"assets/video/role_10.mp4": "72a587470616537b98fc702d80385139",
"assets/video/role_18.mp4": "478a919a4ab16c8494c15c7caef0b0ae",
"assets/video/role_3.mp4": "2beefbbeacd8437b0f5cf08db13c4bd0",
"assets/video/role_1.mp4": "f3bcdc0a1c267ecda71b8fff35351172",
"assets/video/role_20.mp4": "ef6a47201adec255f9e3823aadc255b6",
"assets/video/role_15.mp4": "8dd3484df82730edc5c5b4147a1a3893",
"assets/FontManifest.json": "825f5a236a0d9f4ed076bf5cff0608ec",
"assets/AssetManifest.bin.json": "2a7d9893d44e8e76d9774ae735240279",
"assets/NOTICES": "2a3d74cdd4cf547d3f1f3f11f69d65b5",
"assets/packages/record_web/assets/js/record.fixwebmduration.js": "1f0108ea80c8951ba702ced40cf8cdce",
"assets/packages/record_web/assets/js/record.worklet.js": "6d247986689d283b7e45ccdf7214c2ff",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "d7d83bd9ee909f8a9b348f56ca7b68c6",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"version.json": "fd358a39902e0543e4a80a2379fe36b6",
"index.html": "22650415b87ce71e9ea3cca6161c29c6",
"/": "22650415b87ce71e9ea3cca6161c29c6",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"zoom_service.js": "83cd4f7525191805e7be310949466791",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"flutter_bootstrap.js": "cdb562129b50ec6f2968bc5d9deac3cd",
"manifest.json": "a667cf404403961ebaea48905ccce3ad",
"404.html": "aceaba07b123eb8b4d6029540feb9907",
"main.dart.js": "52acac8658294a0d2619cdefe9fdcb0d"};
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
