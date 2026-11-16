/**
 * UNDO offline — data Godot hry natrvalo v prohlížeči (undogames/docs/OFFLINE_GAMES.md, kapitola Godot hry;
 * dohoda her stickwoundgodot/docs/OFFLINE_STATUS.md). Kopíruje se do hry beze změny, stránka hry ho vloží
 * do hlavičky. Používají ho DRIVAH, Stickwound a Cursed Camp.
 *
 * Verze 2 (17. 11. 2026): bez servisního workeru. Do 16. 11. ukládal data worker sady, jenže Chrome workeru
 * ukončí každou akci delší než 5 minut: na pomalejším připojení se 300 MB Cursed Campu utrhlo uprostřed
 * a Godot hlásil „Couldn't load project data“ (Richard 17. 11.). Teď ukládá stránka sama: engine (.wasm)
 * a hlavní balík (.pck) stahuje přes `fetch` stránky a cestou kopii zapíše do Cache Storage `undo-offline-v1`.
 * Příště je podá z ní, nestahuje nic. Worker z 16. 11. se při spuštění odregistruje (jednou se stránka
 * obnoví, aby ho už nepoužívala) a nasazení ho na stejné adrese nahradí prázdným (`undo-offline-sw-retire.js`).
 *
 * Nasazení dá engine pod `/assets/` se jménem s otiskem (`assets/index.<otisk>.*`, `GODOT_CONFIG.executable`).
 * Testovací build (engine mimo `/assets/`) nedrží nic.
 *
 * Stránka hry:
 *   if (window.__undoOffline.command) { …bez hry a opony…; window.__undoOffline.ready(GODOT_CONFIG, volby); return; }
 *   window.__undoOffline.ready(GODOT_CONFIG, volby).then(() => engine.startGame({ onProgress(c, t) { text = window.__undoOffline.status(c, t); } }))
 *     .then(() => window.__undoOffline.started());
 * Volby (nepovinné):
 *   files: [adresy] nebo () => Promise<[adresy]>  — co stáhnout navíc při `?undo_offline=install` (balíky dat),
 *   packs: () => Promise<[{id, url, bytes}]>      — balíky, které hra drží ve stejné paměti, do hlášení katalogu,
 *   keep: () => Promise<[adresy]>                  — soubory, které hra přehrává po kouscích (`<audio>`): po uložení
 *                                                   enginu je stránka jednou stáhne celé; jdou i do install,
 *   prepare: () => Promise                         — co ještě udělat při stažení předem (DRIVAH: grafické programy
 *                                                   předem do mezipaměti prohlížeče); `installed` přijde až po něm.
 *
 * Dotaz katalogu (Richard 17. 11.: „při prvním načítání se zeptej, jestli uložit data natrvalo“): stránka
 * pošle `undo:offline-hello {version, bytes}`, katalog hned odpoví `undo:offline-keep {keep: true | false | null}`
 * (null = ještě se neptal, ukáže dotaz a odpoví znovu, až hráč vybere). Do odpovědi se stahuje a ukládá;
 * „ne“ uložené smaže a dál se neukládá. Hra si stav přečte přes `keep()` (vlastní balíky ukládá jen, když
 * není false). Katalog dál slyší `undo:offline-status` (po spuštění, po změně a na `undo:offline-status-request`).
 * Pokyny katalogu ve skrytém rámečku (`?undo_offline=install|remove`): všechno stáhnout předem (průběh
 * po bajtech), nebo smazat. Engine se pak nespouští.
 */
(function () {
  if (window.__undoOffline) return;
  var CACHE = 'undo-offline-v1';
  var RETIRED = 'undo-offline-sw-retired';
  var mode = new URLSearchParams(location.search).get('undo_offline') || '';
  var config = null;
  var options = {};
  var keep = null;
  var hits = {};
  var polls = 0;
  var warmed = false;
  var waiting = [];

  function post(message) {
    if (window.parent === window) return;
    try { window.parent.postMessage(Object.assign({ v: 1 }, message), '*'); } catch (e) { /* rodič zmizel */ }
  }
  function kept(cfg) { return /^assets\//.test(cfg.executable) && 'caches' in window; }
  function engineFiles(cfg) { return [cfg.executable + '.wasm', cfg.executable + '.pck']; }
  function key(file) { var url = new URL(file, location.href); return url.origin + url.pathname; }
  function version() { return config.executable.split('.').pop(); }
  function engineBytes() { return engineFiles(config).reduce(function (sum, file) { return sum + (config.fileSizes[file] || 0); }, 0); }
  function list(option) { return option ? Promise.resolve().then(typeof option === 'function' ? option : function () { return option; }).catch(function () { return []; }) : Promise.resolve([]); }
  function cs() { return /^(cs|sk)/i.test(navigator.language || ''); }
  function mb(bytes) { return Math.round(bytes / 1048576); }

  // Worker sady z 16. 11. pryč (viz úvod). Stránku, kterou ještě řídí, jednou obnoví, ať jde rovnou na síť.
  function retireWorker() {
    if (!('serviceWorker' in navigator)) return Promise.resolve(false);
    var ours = function (worker) { return worker && /\/undo-offline-sw\.js/.test(worker.scriptURL); };
    return navigator.serviceWorker.getRegistrations().then(function (regs) {
      return Promise.all(regs.filter(function (reg) { return ours(reg.active || reg.waiting || reg.installing); }).map(function (reg) { return reg.unregister(); }));
    }).then(function () {
      if (!ours(navigator.serviceWorker.controller)) return false;
      var again = false;
      try { again = sessionStorage.getItem(RETIRED) === '1'; sessionStorage.setItem(RETIRED, '1'); } catch (e) { again = true; }
      if (again) return false;
      location.reload();
      return true;
    }).catch(function () { return false; });
  }

  // Engine a hlavní balík: z paměti, jinak ze sítě a cestou kopie do paměti (pokud hráč ukládání neodmítl).
  function wrapFetch() {
    var original = window.fetch;
    var files = {};
    engineFiles(config).forEach(function (file) { files[key(file)] = file; });
    window.fetch = function (input, init) {
      var self = this, args = arguments, url;
      try { url = key(typeof input === 'string' ? input : input.url); } catch (e) { return original.apply(self, args); }
      var file = files[url];
      if (!file) return original.apply(self, args);
      return caches.open(CACHE).then(function (cache) {
        return cache.match(url, { ignoreVary: true }).then(function (hit) {
          if (hit) { hits[file] = true; return hit; }
          return original.apply(self, args).then(function (response) {
            if (keep === false || !response.ok || !response.body) return response;
            var pair = response.body.tee();
            var headers = new Headers(response.headers);
            headers.delete('content-encoding');
            headers.delete('content-length');
            cache.put(url, new Response(pair[1], { status: 200, headers: headers }))
              .then(function () { if (keep === false) return cache.delete(url); })
              .then(report, function () { /* plná paměť: příště se stáhne znovu */ });
            return new Response(pair[0], { status: response.status, statusText: response.statusText, headers: response.headers });
          });
        });
      }).catch(function () { return original.apply(self, args); });
    };
  }

  // Co hra drží: engine této verze a uložené balíky; jakmile je celý engine uložený, starší verze zmizí.
  function report() {
    if (!config || !kept(config)) return Promise.resolve(false);
    return caches.open(CACHE).then(function (cache) {
      var files = engineFiles(config);
      var match = function (file) { return cache.match(key(file), { ignoreVary: true }); };
      return Promise.all([Promise.all(files.map(match)), list(options.packs)]).then(function (found) {
        var installed = found[0].every(Boolean);
        var bytes = 0;
        found[0].forEach(function (hit, i) { if (hit) bytes += config.fileSizes[files[i]] || 0; });
        return Promise.all(found[1].map(function (pack) { return match(pack.url).then(function (hit) { return hit ? pack : null; }); })).then(function (stored) {
          var packs = stored.filter(Boolean).map(function (pack) { bytes += pack.bytes || 0; return { id: pack.id, bytes: pack.bytes || 0 }; });
          return (installed ? tidy(cache, files) : Promise.resolve()).then(function () {
            post({ type: 'undo:offline-status', installed: installed, version: version(), bytes: bytes, packs: packs });
            return installed;
          });
        });
      });
    }).catch(function () { return false; });
  }
  // Engine starších verzí (`/assets/index.*` mimo tuhle), stránka a soubory s parametrem v adrese z doby workeru.
  function tidy(cache, files) {
    var current = {};
    files.forEach(function (file) { current[key(file)] = true; });
    return cache.keys().then(function (keys) {
      return Promise.all(keys.filter(function (request) {
        var url = new URL(request.url);
        if (url.pathname === '/' || (url.pathname.indexOf('/assets/') === 0 && url.search)) return true;
        return url.pathname.indexOf('/assets/index.') === 0 && !current[url.origin + url.pathname];
      }).map(function (request) { return cache.delete(request); }));
    });
  }

  // Soubor celý do paměti s průběhem po bajtech (stažení předem, hudba po kouscích).
  function store(cache, url, onBytes) {
    return fetch(url).then(function (response) {
      if (!response.ok || !response.body) throw new Error(String(response.status));
      var loaded = 0;
      var counted = response.body.pipeThrough(new TransformStream({ transform: function (chunk, controller) { loaded += chunk.length; if (onBytes) onBytes(loaded); controller.enqueue(chunk); } }));
      var headers = new Headers(response.headers);
      headers.delete('content-encoding');
      headers.delete('content-length');
      return cache.put(key(url), new Response(counted, { status: 200, headers: headers })).then(function () { return loaded; });
    });
  }
  function warm() {
    if (warmed || keep === false) return;
    warmed = true;
    list(options.keep).then(function (urls) {
      return caches.open(CACHE).then(function (cache) {
        return urls.reduce(function (chain, url) {
          return chain.then(function () {
            return cache.match(key(url), { ignoreVary: true }).then(function (hit) { return hit || store(cache, url); }).catch(function () { /* příště */ });
          });
        }, Promise.resolve());
      });
    });
  }
  // Cache.put dopíše až s koncem stahování: kontrola znovu, dokud není celý engine uložený.
  function watch() {
    report().then(function (installed) {
      if (installed) warm();
      else if (keep !== false && polls++ < 120) setTimeout(watch, 5000);
    });
  }

  // `?undo_offline=install`: engine, balíky z voleb a hudba předem, průběh po bajtech.
  function install() {
    post({ type: 'undo:offline-start' });
    keep = true;
    var prepared = typeof options.prepare === 'function' ? Promise.resolve().then(options.prepare).catch(function () {}) : Promise.resolve();
    Promise.all([list(options.files), list(options.keep), list(options.packs)]).then(function (got) {
      var sizes = {};
      engineFiles(config).forEach(function (file) { sizes[key(file)] = config.fileSizes[file] || 0; });
      got[2].forEach(function (pack) { sizes[key(pack.url)] = pack.bytes || 0; });
      var files = engineFiles(config).concat(got[0], got[1]).map(key).filter(function (url, i, all) { return all.indexOf(url) === i; });
      var total = files.reduce(function (sum, url) { return sum + (sizes[url] || 1048576); }, 0);
      var done = 0, bytes = 0, failed = 0;
      return caches.open(CACHE).then(function (cache) {
        return files.reduce(function (chain, url) {
          return chain.then(function () {
            return cache.match(url, { ignoreVary: true }).then(function (hit) {
              if (hit) return hit.blob().then(function (blob) { return blob.size; });
              return store(cache, url, function (loaded) {
                post({ type: 'undo:offline-progress', done: Math.min(total, done + loaded), total: total });
              });
            }).then(function (size) { bytes += size; }, function () { failed += 1; }).then(function () {
              done += sizes[url] || 1048576;
              post({ type: 'undo:offline-progress', done: Math.min(total, done), total: total });
            });
          });
        }, Promise.resolve());
      }).then(function () { return prepared; }).then(function () {
        if (failed) { post({ type: 'undo:offline-failed', error: 'files' }); return; }
        report().then(function () { post({ type: 'undo:offline-installed', bytes: bytes, files: files.length, version: version() }); });
      });
    }).catch(function () { post({ type: 'undo:offline-failed', error: 'install' }); });
  }
  // `?undo_offline=remove`: všechno, co hra drží, pryč.
  function remove() {
    post({ type: 'undo:offline-start' });
    caches.delete(CACHE).then(function () { post({ type: 'undo:offline-removed' }); }, function () { post({ type: 'undo:offline-failed', error: 'remove' }); });
  }

  // Katalog: jestli data ukládat (odpověď na hello, později volba hráče v dotazu).
  function ask() {
    if (window.parent === window) { keep = true; return Promise.resolve(); }
    return new Promise(function (resolve) {
      var timer = setTimeout(resolve, 600);
      waiting.push(function () { clearTimeout(timer); resolve(); });
      post({ type: 'undo:offline-hello', version: version(), bytes: engineBytes() });
    });
  }
  addEventListener('message', function (event) {
    if (event.source !== window.parent || !event.data) return;
    if (event.data.type === 'undo:offline-status-request') report();
    if (event.data.type === 'undo:offline-keep') {
      var before = keep;
      keep = event.data.keep === true ? true : event.data.keep === false ? false : null;
      waiting.splice(0).forEach(function (resolve) { resolve(); });
      // „Ne“: co se do té doby uložilo, pryč (i balíky hry), dál se neukládá.
      if (keep === false && before !== false && config && kept(config)) caches.delete(CACHE).then(report, function () {});
      if (keep === true && before !== true && config && kept(config)) { report(); polls = 0; watch(); }
    }
  });

  window.__undoOffline = {
    // Stránka je pokyn katalogu, ne hra ke spuštění.
    command: mode === 'install' || mode === 'remove',
    // Před stažením enginu: pryč se starým workerem, pokyn katalogu, nebo ukládání a dotaz katalogu.
    ready: function (cfg, opts) {
      config = cfg;
      options = opts || {};
      if (!kept(cfg)) {
        if (mode === 'install' || mode === 'remove') post({ type: 'undo:offline-failed', error: 'unsupported' });
        return Promise.resolve();
      }
      return retireWorker().then(function (reloading) {
        if (reloading) return new Promise(function () {});
        if (mode === 'install') { install(); return new Promise(function () {}); }
        if (mode === 'remove') { remove(); return new Promise(function () {}); }
        wrapFetch();
        return ask();
      });
    },
    // Po startu enginu: co je uložené, katalogu; pak hudba po kouscích.
    started: function () { if (config && kept(config)) watch(); },
    report: report,
    // Smí hra ukládat vlastní balíky? (false = hráč ukládání odmítl.)
    keep: function () { return keep; },
    // Stavová hláška pod ukazatelem načítání (průběh z onProgress enginu).
    status: function (current, total) {
      var czech = cs();
      if (!(total > 0 && current < total)) return czech ? 'Spouštím hru…' : 'Starting the game…';
      if (config && engineFiles(config).some(function (file) { return hits[file]; })) return czech ? 'Načítám z paměti zařízení' : 'Loading from this device';
      return (czech ? 'Stahuji data · ' : 'Downloading · ') + mb(current) + ' / ' + mb(total) + ' MB';
    },
  };
})();
