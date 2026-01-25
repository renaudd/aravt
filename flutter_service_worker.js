'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "4b2350e14c6650ba82871f60906437ea",
"icons/Icon-512.png": "908b75a517b7ec686f7652da87aad367",
"icons/Icon-maskable-512.png": "908b75a517b7ec686f7652da87aad367",
"icons/Icon-192.png": "908b75a517b7ec686f7652da87aad367",
"icons/Icon-maskable-192.png": "908b75a517b7ec686f7652da87aad367",
"manifest.json": "d2c18fb05f3ff7ee65ecfe85ffa933b7",
"index.html": "2527ae418c051e35f191c7f01c973c7f",
"/": "2527ae418c051e35f191c7f01c973c7f",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin.json": "5d29d49e178c3882949fb8169260934b",
"assets/assets/images/horse_icon.png": "19bb8c8b82aea364d281b1f80a927ae5",
"assets/assets/images/assassination_poison.png": "1a6c46bb2f016811552427b938fc02a2",
"assets/assets/images/background.png": "5221ba4c2ff265eb46f1138502e39caa",
"assets/assets/images/stockade.png": "93351b82ac8f3a7501707a073697e8b6",
"assets/assets/images/horse_archer_icon.xcf": "4eb52ed8c87b5ae42d58cf906e5885b7",
"assets/assets/images/destitute_yurt.png": "aa1bff186f9accbb658ed15c277be16e",
"assets/assets/images/opulent_yurt.png": "ceb8cdcbd69ce20381166bf72309f1dd",
"assets/assets/images/button_background.png": "57786cba7535102e289326c4f7c83785",
"assets/assets/images/opening_1.png": "e792f4afee22f3f1e2eebc52f743b0fb",
"assets/assets/images/title.png": "231a709bfb608990ba449355598ed27c",
"assets/assets/images/hard_difficulty.png": "bb6f93928306955e5f7095ef097cef01",
"assets/assets/images/sprites/green_horse_archer_spritesheet_right.png": "e4ef4f43b33569a1b19b39660157eee7",
"assets/assets/images/sprites/teal_horse_archer_spritesheet_right.png": "ae06849dd79a62738e876d91339046f3",
"assets/assets/images/sprites/red_horse_archer_spritesheet.png": "d612e30b2b9f33a9b760a120e345e187",
"assets/assets/images/sprites/red_spearman_spritesheet.png": "f28023715b16126065362694fd3e1641",
"assets/assets/images/sprites/teal_spearman_spritesheet_right.png": "63b815286f521836c37e7079683a13dc",
"assets/assets/images/sprites/yellow_horse_archer_spritesheet.png": "82b30f4d6f6074491e22c3e83a91239b",
"assets/assets/images/sprites/red_spearman_spritesheet_right.png": "542cc12dd8f727cdfb04a6f7ed03cc7a",
"assets/assets/images/sprites/blue_spearman_spritesheet.png": "90d28db27996e15843205e7058e730a3",
"assets/assets/images/sprites/pink_horse_archer_spritesheet.png": "11c248f06904ce4b8b983590cc06e419",
"assets/assets/images/sprites/teal_spearman_spritesheet.png": "780d811a699ba99c94924ce86c6a00b7",
"assets/assets/images/sprites/green_horse_archer_spritesheet.png": "79749bbc0cc1ad32d74788f0b1559bc7",
"assets/assets/images/sprites/kellygreen_horse_archer_spritesheet.png": "7446bf3e7510c23f34ba92e1f9cf9bd4",
"assets/assets/images/sprites/red_horse_archer_spritesheet_right.png": "5cdda4d09f008edb54284515cfde40b4",
"assets/assets/images/sprites/blue_horse_archer_spritesheet_right.png": "75940ee3c5d323c9dc68e490c42613ea",
"assets/assets/images/sprites/purple_spearman_spritesheet.png": "61d4aa177aeabc2ba634d0953393b8f4",
"assets/assets/images/sprites/pink_horse_archer_spritesheet_right.png": "c0185611e9b5a7782eb28461373fa400",
"assets/assets/images/sprites/purple_horse_archer_spritesheet_right.png": "f4899876add1ca6e915b533b84844caa",
"assets/assets/images/sprites/yellow_horse_archer_spritesheet_right.png": "7b7fe81ce2352dc1fb9de348720a6790",
"assets/assets/images/sprites/purple_spearman_spritesheet_right.png": "1677e3f509aaa88be8c0d2227f0b95e9",
"assets/assets/images/sprites/teal_horse_archer_spritesheet.png": "415fa5ebf443d37af5334ae6a8261d08",
"assets/assets/images/sprites/blue_horse_archer_spritesheet.png": "f641cb45c3a32749b7c55a29e9c9777e",
"assets/assets/images/sprites/blue_spearman_spritesheet_right.png": "54fd4be39f2cfeae09ba4031532f472b",
"assets/assets/images/sprites/kellygreen_horse_archer_spritesheet_right.png": "472f7470e448eee05186eab97e9b42b6",
"assets/assets/images/sprites/purple_horse_archer_spritesheet.png": "1418c70c5b301a4fbbc7cafd9ebc7415",
"assets/assets/images/sword_icon.png": "02fd1bad5e46f25fe8d9c1ca7e2955ab",
"assets/assets/images/normal_yurt.png": "f0a4148b31b0d175172b4ea890a9ac37",
"assets/assets/images/soldier_portraits.png": "16d6d13a41778740c832947b7aae1ab2",
"assets/assets/images/exit.png": "ecaea7815ef93b0a7ebe155eef405bb0",
"assets/assets/images/ger.png": "91643f90746956a9221234f745b8dd5f",
"assets/assets/images/easy_difficulty.png": "2fcb90ffc467845d4c48766c8e64a9d8",
"assets/assets/images/single%2520leader.png": "67a9fefb1e690870c655de15528a27a8",
"assets/assets/images/steppe_background.jpg": "cc033d08f8920610d279a919f56a707f",
"assets/assets/images/newsoldierspritesheet.xcf": "a5aaf6c558013b582eae35b90fe4d5ce",
"assets/assets/images/terrain/terrain_rocks.png": "7e413c1489f836012c2e971e963ae078",
"assets/assets/images/terrain/terrain_hills.png": "f274c62ab78a3a9ee72bf47d707472a1",
"assets/assets/images/terrain/terrain_trees.png": "976916c45b6d8db0b2a6d25c8d234c38",
"assets/assets/images/medium_difficulty.png": "bd3a6b9bd1d83f67ee2d0f438a99cd0b",
"assets/assets/images/soldier_walk_spritesheet.png": "aedfdaea86f06f24fcc009529063bc39",
"assets/assets/images/steppe_area_background.png": "0a88c1abaddc88c451e0210aab86f484",
"assets/assets/images/horses.png": "f377407fcb58bd3769166c7096ec1f1a",
"assets/assets/images/bow_icon.png": "c3deeaa90fbbe43866221b417bdf4817",
"assets/assets/images/opening_2.png": "b1d05e063c9f4e6258460decc41b3df7",
"assets/assets/images/assassination_strangle.png": "d8566eff0a27ad2e5f06cd93d69999c0",
"assets/assets/images/happy_captain.png": "a839bf1e463ce21510f4522cbb87980c",
"assets/assets/images/foreground.png": "b94f85bcd61d7cc19d29975a95e1998e",
"assets/assets/images/mongol_silhouette.png": "b54a293a34ae2b988e65dbdbe370ebb4",
"assets/assets/images/soldier_spritesheet.png": "7084bc4b547b9672bc204b63c33e5b2c",
"assets/assets/images/new_horses_bowless_spritesheet_right.png": "e1df28077614b034bba9a9dac365e7ea",
"assets/assets/images/horse_archer_icon.png": "c530f2854225e93ac5bf11e5d7014c15",
"assets/assets/images/assassination_confront.png": "aab0665bb773ab0333511c0f8c54f58e",
"assets/assets/images/single%2520spearman.png": "94f7c79c44a22e376d7fd8a9f9b84ed7",
"assets/assets/images/new_game.png": "8d2c21b3fbe0f28fc0942c88a4af8046",
"assets/assets/images/spear_icon.png": "3a36df42e33f83e990ccd94fdc899df7",
"assets/assets/images/battlefield_background.png": "a799a6773c05620b8f405b96e7feb315",
"assets/assets/images/single%2520red%2520horse%2520archer.png": "e574957f0e9a6731de465abe5f4117fe",
"assets/assets/images/load_game.png": "59dcc4e900e55cff851d639dbc8d64b0",
"assets/assets/images/equipped_soldier_silhouette.png": "71bee058ae3218720453713709e9b37b",
"assets/assets/images/short_battlefield_background.png": "e4e08cd56f6a6953c15a316816ba3d37",
"assets/assets/images/camp_background.png": "7823afa4dad629e0713d15de3f129765",
"assets/assets/images/soldier_walk_spritesheet_hollow_complete.xcf": "c63bf8757fa6bb422afdd377c51c1f9f",
"assets/assets/images/angry_captain.png": "e3aac13d80b64a1195977e323cd2cc86",
"assets/assets/images/soldier_portrait.png": "8098f3f71fdbd8f9a6ab622437150073",
"assets/assets/images/mongol_walk_sheet.png": "decdc4f351ce48a6045d13369a761d87",
"assets/assets/images/infirmary.png": "021501e7776767ad3a987bd2535cd020",
"assets/assets/images/Aravt.ico": "fc5b19c3c906285c135f1b55dc5f2a52",
"assets/assets/images/assassination_accident.png": "67eac96b3f95a77dd8559c67f386b83c",
"assets/assets/images/new_horses_bowless_spritesheet.png": "240918612f4e25b33e3917c62d08e279",
"assets/assets/images/soldier_walk_spritesheet_hollow.xcf": "04b02d81a4f621608ea05fea3bd1906a",
"assets/assets/images/just_sword_equipped_soldier_silhouette.png": "a9f1dfc1f80ace21a3832e55d7ddda56",
"assets/assets/images/nice_yurt.png": "024127e7b378dd327a0cdc30e03c8821",
"assets/assets/images/steppe_background.png": "12004ee4f102118cfe97c524f04216db",
"assets/assets/images/items/shields_items.png": "f49acf37fdcb8e91d6d6a4dc541d00dc",
"assets/assets/images/items/swords_items.png": "3c716ca629536706f79851e8d1a1ed82",
"assets/assets/images/items/rings_items.png": "4fbfcf7ca84adb576ddda5087d005fb5",
"assets/assets/images/items/armor_items.png": "8320802335f45c51175ccee11b9c891f",
"assets/assets/images/items/gauntlets_items.png": "a40068bec3b401ee5dede401b5d8f1f5",
"assets/assets/images/items/throwing_spears_items.png": "608816b591d2079e4567b803f43078bd",
"assets/assets/images/items/lance_spears_items.png": "ec35904f45f43300ad8ff27cf22a0495",
"assets/assets/images/items/helmets_items.png": "9c3c425eeb4356a0a15780bb1547055d",
"assets/assets/images/items/arrows_items.png": "c5e9d4b281481f4b81bfbb5b36a48963",
"assets/assets/images/items/boots_items.png": "81cf2dfd01dccc826dd269802b0b290d",
"assets/assets/images/items/necklaces_items.png": "c5938565f8889c6f6bee61748e3b6393",
"assets/assets/images/items/bows_items.png": "b85bde285c4656456eed15fbf174c655",
"assets/assets/images/items/undergarments_items.png": "98bcd0caf53e521f203052d38e0c9580",
"assets/assets/images/soldier_render.png": "c6a2c267f4f0f92149c53bd191830f50",
"assets/assets/images/horse_icon.xcf": "aaf6cc670d3c5a1971217997aeb1bc50",
"assets/assets/images/soldier_walk_spritesheet.xcf": "5c02009b63f63dfce64818a55bd71c91",
"assets/assets/images/settings.png": "66e40d3d99acddd66cc1ea677068540e",
"assets/assets/tiles/fog_tile.png": "e72fa7a7640657cef00257e275f5fffa",
"assets/assets/tiles/forest_tile.png": "673aa50e32788f9c2b2ec1b2c4719ad5",
"assets/assets/tiles/mountain_tile.png": "d12915b331b97842058022017afd1ad1",
"assets/assets/tiles/river_tile.png": "f5c7edcaf18dde55b7d4aa800e48bdcb",
"assets/assets/tiles/grassland_with_settlement_tile.png": "0a2dfdf215f11ef2c5fc4ea2ebef8edb",
"assets/assets/tiles/lake_tile.png": "b4c810b8c7b75b7a02fe00d06f4b3fad",
"assets/assets/tiles/grassland_tile.png": "2c9646dde06f8ab0fe1e09f5738f91cd",
"assets/assets/tiles/hills_tile.png": "4ef2197ad98acfa6e0d3880906ebfc78",
"assets/assets/backgrounds/default_bg.jpg": "e260ec8747c6b8a5f3e69473b653439a",
"assets/assets/backgrounds/forest_bg.jpg": "66b1de2ff47667003017f08f38e109d6",
"assets/assets/backgrounds/npc_camp_bg.jpg": "96d672b2fbc49e9c84a773c029702592",
"assets/assets/backgrounds/swamp_bg.jpg": "a08106ff0b42fc8db30ef3c13f884ac0",
"assets/assets/backgrounds/plains_bg.jpg": "da53254193c26cbf0ed6df21cc80fa02",
"assets/assets/backgrounds/steppe_bg.jpg": "e26b716f161356354e906e4dfc8bf073",
"assets/assets/backgrounds/river_bg.jpg": "4a8c08bde51f7a4a0859faa441c5295e",
"assets/assets/backgrounds/tundra_bg.jpg": "89b65c48f0c1a35333b3ef08faa60b70",
"assets/assets/backgrounds/mountain_bg.jpg": "4e11892df2eaa53b836ec2335ab3f335",
"assets/assets/backgrounds/settlement_bg.jpg": "96d672b2fbc49e9c84a773c029702592",
"assets/assets/backgrounds/desert_bg.jpg": "dd007146f4c489aab4d4cf66c86cee29",
"assets/assets/backgrounds/lake_bg.jpg": "d78119986e33001252bb02a4c0396c10",
"assets/assets/backgrounds/player_camp_bg.jpg": "96d672b2fbc49e9c84a773c029702592",
"assets/fonts/MaterialIcons-Regular.otf": "e7069dfd19b331be16bed984668fe080",
"assets/NOTICES": "f985129d978a0c915f2dd570880a79dd",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "b93248a553f9e8bc17f1065929d5934b",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin": "8e6720834c65a742fd38c86c459498cc",
"assets/AssetManifest.json": "b67d082dc277accb6f971ce276ebf33b",
"canvaskit/chromium/canvaskit.wasm": "ea5ab288728f7200f398f60089048b48",
"canvaskit/chromium/canvaskit.js": "b7ba6d908089f706772b2007c37e6da4",
"canvaskit/chromium/canvaskit.js.symbols": "e115ddcfad5f5b98a90e389433606502",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c",
"canvaskit/skwasm.js": "ac0f73826b925320a1e9b0d3fd7da61c",
"canvaskit/canvaskit.wasm": "e7602c687313cfac5f495c5eac2fb324",
"canvaskit/canvaskit.js": "26eef3024dbc64886b7f48e1b6fb05cf",
"canvaskit/skwasm.wasm": "828c26a0b1cc8eb1adacbdd0c5e8bcfa",
"canvaskit/canvaskit.js.symbols": "efc2cd87d1ff6c586b7d4c7083063a40",
"canvaskit/skwasm.js.symbols": "96263e00e3c9bd9cd878ead867c04f3c",
"favicon.png": "908b75a517b7ec686f7652da87aad367",
"flutter_bootstrap.js": "3f1464a164adc2777aff254a4c02b5b4",
"version.json": "98e36b4d73ed457670d60f988ea8d434",
"main.dart.js": "bef124b95f822578812131d2fa3b76e4"};
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
