/**
 * UNDO offline — data Godot hry natrvalo v prohlížeči (undogames/docs/OFFLINE_GAMES.md, kapitola Godot hry;
 * dohoda her stickwoundgodot/docs/OFFLINE_STATUS.md). Kopíruje se do hry beze změny, stránka hry ho vloží
 * do hlavičky. Používají ho DRIVAH, Stickwound a Cursed Camp.
 *
 * Verze 2 (16. 11. 2026): bez servisního workeru. Do 16. 11. ráno ukládal data worker sady, jenže Chrome workeru
 * ukončí každou akci delší než 5 minut: na pomalejším připojení se 300 MB Cursed Campu utrhlo uprostřed
 * a Godot hlásil „Couldn't load project data“. Teď ukládá stránka sama: engine (.wasm) a hlavní balík (.pck)
 * stahuje přes `fetch` stránky a cestou kopii zapíše do Cache Storage `undo-offline-v1`. Příště je podá z ní,
 * nestahuje nic. Worker se při spuštění odregistruje (jednou se stránka obnoví, aby ho už nepoužívala) a nasazení
 * ho na stejné adrese nahradí prázdným (`undo-offline-sw-retire.js`).
 *
 * Nasazení dá engine pod `/assets/` se jménem s otiskem (`assets/index.<otisk>.*`, `GODOT_CONFIG.executable`).
 * Testovací build (engine mimo `/assets/`) nedrží nic.
 *
 * Verze 4 (16. 11. 2026, Richard: „pořádný stahování herních dat pro mobilní hru, šetřit data z webhostingu“):
 * aktualizace stáhne jen to, co se změnilo. Engine (.wasm, mění se jen s verzí Godotu) a hlavní balík (.pck, kód hry)
 * mají každý vlastní otisk: hlavní balík je `GODOT_CONFIG.mainPack` (`assets/index.<otisk>.pck`), bez něj
 * `<executable>.pck` jako dřív. Do 16. 11. měly jeden společný otisk a každé nasazení přejmenovalo i 40 MB enginu.
 * Soubory, které stránka dá enginu před startem (`boot(url)`, třeba datový balík hry), patří k enginu: ukládají se
 * stejně, počítají se do „uloženo“ a starší verze (`/assets/index.*` mimo aktuální) se uklidí. Hra s částmi (v3)
 * uložená data nikdy nemaže kvůli odpovědi `keep: false` (dřívější „ne“ v dotazu katalogu by jinak při každém
 * spuštění smazalo všechno a hra by se stahovala pořád dokola); maže jen správce (plán `remove`, `?undo_offline=remove`).
 * Jakmile se ukládá, stránka požádá prohlížeč o trvalé úložiště (`navigator.storage.persist`), ať data při nedostatku
 * místa nezahodí. Hláška a animace stahování počítají jen bajty, které opravdu jdou ze sítě.
 *
 * Verze 4.1 (17. 11. 2026, Richard: „stahování se seklo na 30 MB a furt to tam glitchuje ten panel“): jeden stahovač
 * (`download`) pro engine, soubory před startem, části i balíky hry (`window.__undoOffline.download`). Spojení, které
 * 15 s nepošle data, zahodí a stahuje znovu (s Range od místa, kde skončil, jinak od začátku), nejvýš 5 pokusů;
 * selhání se ukáže jako chyba se Zkusit znovu, nikdy nekonečné čekání. Průběh posílá katalogu sám a jednou za sekundu
 * i během zaseknutí (panel drží, nebliká); stránka čte `net()` pro svůj pruh. Soubor je Blob z kousků: do paměti
 * prohlížeče i hře bez kopií navíc (dřív `tee()` a `TransformStream`).
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
 *                                                   předem do mezipaměti prohlížeče); `installed` přijde až po něm,
 *   parts: () => Promise<[část]>                   — verze 3, viz níž,
 *   quality: 'perf' | 'hd'                         — verze 4.1: hra má jen tuhle kvalitu (katalog nekreslí volbu).
 *
 * Dotaz katalogu (Richard 16. 11.: „při prvním načítání se zeptej, jestli uložit data natrvalo“): stránka
 * pošle `undo:offline-hello {version, bytes}`, katalog hned odpoví `undo:offline-keep {keep: true | false | null}`
 * (null = ještě se neptal, ukáže dotaz a odpoví znovu, až hráč vybere). Do odpovědi se stahuje a ukládá;
 * „ne“ uložené smaže a dál se neukládá. Hra si stav přečte přes `keep()` (vlastní balíky ukládá jen, když
 * není false). Katalog dál slyší `undo:offline-status` (po spuštění, po změně a na `undo:offline-status-request`).
 * Pokyny katalogu ve skrytém rámečku (`?undo_offline=install|remove|parts`): všechno stáhnout předem (průběh
 * po bajtech), smazat, nebo jen ohlásit části (`undo:data-parts`, pak `undo:offline-parts`). Engine se pak nespouští.
 *
 * Verze 3 (16. 11. 2026, undogames docs/GODOT_DATA.md): data po částech a kvalita Výkon / HD; výběr, animaci
 * a správce kreslí katalog. Část = {id, name: {cs, en}, base, files: {perf: [{url, bytes}], hd: [...]}} (základ
 * = část s `base`, engine a hlavní balík k ní sada přidá sama). Sada pošle `undo:data-parts {version, quality,
 * parts: [{id, name, base, size: {perf, hd}, stored: {perf, hd}}]}`, průběh `undo:data-progress {part, quality,
 * loaded, total, state: download | done | error, blocking}` (u částí i `have: {perf, hd}` = uložené bajty) (blocking = hra čeká: katalog ukáže velkou animaci)
 * a slyší `undo:data-plan {quality, parts, remove}`: chybějící části plánu stahuje po spuštění hry na pozadí po
 * jedné (pozastaví se, když hra stahuje něco naléhavého), `remove` a soubory druhé kvality smaže. Hra čte
 * `quality()`, naléhavé stahování hlásí `fileProgress(url, loaded, total)`, změnu kvality v nastavení hry
 * `setQuality(q)` (katalog dostane `undo:data-quality`), stahování, na které hráč nečeká, `busy()`, soubor, který
 * stránka dá enginu před startem, `boot(url)` (ukládá se jako engine). Části jdou katalogu ještě před `hello` (při prvním spuštění
 * nabídne jejich výběr místo dotazu na uložení), katalog na `hello` vždy odpoví plánem (bez volby `quality: null`)
 * a pak `keep`; na pozadí se stahuje, až hráč ukládání potvrdí. `overlay()` = katalog právě kreslí animaci stahování
 * přes hru (stránka a obrazovky načítání hry schovají svůj ukazatel, ať nejsou dva na stejném místě), `catalog()` = katalog části spravuje. Bez katalogu platí poslední plán uložený ve hře, jinak
 * všechny části a automatická kvalita (telefon a slabší počítač Výkon). Stažení předem bere plán z adresy:
 * `?undo_offline=install&undo_quality=perf|hd&undo_parts=a,b` (uložené mimo plán pak smaže).
 */
(function () {
  if (window.__undoOffline) return;
  var CACHE = 'undo-offline-v1';
  var RETIRED = 'undo-offline-sw-retired';
  var PLAN = 'undo-data-plan';
  var params = new URLSearchParams(location.search);
  var mode = params.get('undo_offline') || '';
  var config = null;
  var options = {};
  var keep = null;
  var hits = {};
  var polls = 0;
  var warmed = false;
  var waiting = [];
  // v3: části, plán a stahování na pozadí
  var parts = null;
  var plan = null;
  var filling = false;
  var refill = false;
  var urgentAt = 0;
  var running = false;
  var hub = false;
  var bgAbort = null;
  var overlay = false;
  var overlayAt = 0;

  // Průběh stahování nejvýš 10× za sekundu na část (konec a chyba hned): po každém kousku dat to byly stovky zpráv
  // za sekundu a hra i katalog se zpomalily (16. 11.: závod se se stahováním na pozadí načítal 3× déle).
  var told = {};
  function post(message) {
    if (window.parent === window) return;
    if (message.type === 'undo:data-progress' && message.state === 'download') {
      var k = message.part + (message.blocking ? '!' : '');
      var now = Date.now();
      if (now - (told[k] || 0) < 100) return;
      told[k] = now;
    }
    try { window.parent.postMessage(Object.assign({ v: 1 }, message), '*'); } catch (e) { /* rodič zmizel */ }
  }
  function kept(cfg) { return /^assets\//.test(cfg.executable) && 'caches' in window; }
  function engineFiles(cfg) { return [cfg.executable + '.wasm', cfg.mainPack || cfg.executable + '.pck']; }
  // engine, hlavní balík a soubory, které stránka dá enginu před startem (boot)
  var boots = [];
  function coreFiles() { return engineFiles(config).concat(boots.filter(function (file) { return engineFiles(config).indexOf(file) < 0; })); }
  function key(file) { var url = new URL(file, location.href); return url.origin + url.pathname; }
  // verze hry = otisk hlavního balíku (engine se mezi verzemi nemění)
  function version() { return (config.mainPack || config.executable).replace(/\.pck$/, '').split('.').pop(); }
  function engineBytes() { return coreFiles().reduce(function (sum, file) { return sum + (config.fileSizes[file] || 0); }, 0); }
  // Trvalé úložiště: bez něj prohlížeč při nedostatku místa data zahodí (Chrome nejdřív u stránek v rámečku).
  var persisted = false;
  function persist() {
    if (persisted || !navigator.storage || !navigator.storage.persist) return;
    persisted = true;
    navigator.storage.persisted().then(function (yes) { return yes || navigator.storage.persist(); }).catch(function () { /* nejde */ });
  }
  function list(option) { return option ? Promise.resolve().then(typeof option === 'function' ? option : function () { return option; }).catch(function () { return []; }) : Promise.resolve([]); }
  function cs() { return /^(cs|sk)/i.test(navigator.language || ''); }
  function mb(bytes) { return Math.round(bytes / 1048576); }
  function bytesOf(files) { return files.reduce(function (sum, f) { return sum + (f.bytes || 0); }, 0); }

  // ---------------------------------------------------------------- v3: kvalita a plán

  // Automatická kvalita: telefon a slabší počítač Výkon (malé textury, nízké rozlišení), jinak HD.
  function autoQuality() {
    var coarse = !!(window.matchMedia && matchMedia('(pointer: coarse)').matches);
    var memory = navigator.deviceMemory || 8;
    var cores = navigator.hardwareConcurrency || 8;
    return coarse || memory <= 4 || cores <= 4 ? 'perf' : 'hd';
  }
  function loadPlan() {
    try { var saved = JSON.parse(localStorage.getItem(PLAN) || 'null'); if (saved && (saved.quality === 'perf' || saved.quality === 'hd')) return saved; } catch (e) { /* bez úložiště */ }
    return null;
  }
  function savePlan() { try { localStorage.setItem(PLAN, JSON.stringify(plan)); } catch (e) { /* bez úložiště */ } }
  // v4.1: hra s jednou kvalitou (volba `quality: 'perf' | 'hd'`, DRIVAH lite na webu) jinou nebere
  function fixedQuality() { return options && (options.quality === 'perf' || options.quality === 'hd') ? options.quality : null; }
  function quality() { return fixedQuality() || (plan && plan.quality) || autoQuality(); }
  function wanted(part) { return part.base || !(plan && Array.isArray(plan.parts)) || plan.parts.indexOf(part.id) >= 0; }

  // Části hry, základ s enginem a hlavním balíkem; jednou za běh.
  function getParts() {
    if (parts) return Promise.resolve(parts);
    return list(options.parts).then(function (got) {
      var engine = engineFiles(config).map(function (file) { return { url: file, bytes: config.fileSizes[file] || 0 }; });
      var engineKeys = engineFiles(config).map(key);
      var notEngine = function (f) { return engineKeys.indexOf(key(f.url)) < 0; };
      if (!got.some(function (part) { return part.base; })) got.unshift({ id: 'base', name: { cs: 'Základ', en: 'Base' }, base: true, files: { perf: [], hd: [] } });
      got.forEach(function (part) {
        part.files = part.files || {};
        if (part.base) {
          part.files.perf = engine.concat((part.files.perf || []).filter(notEngine));
          part.files.hd = engine.concat((part.files.hd || []).filter(notEngine));
        }
      });
      parts = got;
      return parts;
    });
  }
  function partOf(url) {
    var k = key(url);
    var q = quality();
    for (var i = 0; parts && i < parts.length; i++) {
      var files = parts[i].files[q] || [];
      for (var j = 0; j < files.length; j++) if (key(files[j].url) === k) return parts[i];
    }
    return null;
  }
  // Katalogu: velikost částí a jestli jsou uložené v obou kvalitách.
  function reportParts() {
    if (!config || !kept(config) || !options.parts) return Promise.resolve();
    return getParts().then(function (all) {
      return caches.open(CACHE).then(function (cache) {
        // [celá uložená, uložené bajty]
        var stored = function (files) {
          return Promise.all(files.map(function (f) { return cache.match(key(f.url), { ignoreVary: true }); })).then(function (found) {
            var have = 0;
            found.forEach(function (hit, i) { if (hit) have += files[i].bytes || 0; });
            return [files.length > 0 && found.every(Boolean), have];
          });
        };
        return Promise.all(all.map(function (part) {
          return Promise.all([stored(part.files.perf || []), stored(part.files.hd || [])]).then(function (got) {
            return { id: part.id, name: part.name, base: !!part.base, size: { perf: bytesOf(part.files.perf || []), hd: bytesOf(part.files.hd || []) }, stored: { perf: got[0][0], hd: got[1][0] }, have: { perf: got[0][1], hd: got[1][1] } };
          });
        }));
      }).then(function (report) {
        post({ type: 'undo:data-parts', version: version(), quality: quality(), fixed: fixedQuality(), parts: report });
      });
    }).catch(function () { /* bez úložiště */ });
  }
  // Chybějící části plánu na pozadí po jedné; čeká, dokud hra stahuje něco naléhavého (fileProgress).
  function fill() {
    if (!running || keep !== true || !options.parts || !config || !kept(config)) return;
    if (filling) { refill = true; return; }
    filling = true;
    refill = false;
    var q = quality();
    getParts().then(function (all) {
      return caches.open(CACHE).then(function (cache) {
        return all.filter(wanted).reduce(function (chain, part) {
          return chain.then(function () {
            if (q !== quality()) return;
            var files = part.files[q] || [];
            var total = bytesOf(files);
            var have = 0;
            var fetched = false;
            return files.reduce(function (inner, f) {
              return inner.then(function () {
                if (!wanted(part) || q !== quality()) throw new Error('plan');
                return cache.match(key(f.url), { ignoreVary: true }).then(function (hit) {
                  if (hit) { have += f.bytes || 0; return; }
                  fetched = true;
                  // hra mohla soubor mezitím stáhnout sama (balík před závodem): znovu se podívat
                  return idle().then(function () { return cache.match(key(f.url), { ignoreVary: true }); }).then(function (now) {
                    if (now) { have += f.bytes || 0; return; }
                    return store(cache, f.url, function (loaded) {
                      post({ type: 'undo:data-progress', part: part.id, quality: q, loaded: Math.min(total, have + loaded), total: total, state: 'download', blocking: false });
                    }, true).then(function () { have += f.bytes || 0; });
                  });
                });
              });
            }, Promise.resolve()).then(function () {
              if (fetched) post({ type: 'undo:data-progress', part: part.id, quality: q, loaded: total, total: total, state: 'done', blocking: false });
            }, function () {
              // zrušená část (nebo jiná kvalita) není chyba
              if (wanted(part) && q === quality()) post({ type: 'undo:data-progress', part: part.id, quality: q, loaded: have, total: total, state: 'error', blocking: false });
            });
          });
        }, Promise.resolve());
      });
    }).then(reportParts, function () {}).then(function () {
      filling = false;
      if (refill) fill();
    });
  }
  function idle() {
    return new Promise(function (resolve) {
      (function check() { if (Date.now() - urgentAt > 1500) resolve(); else setTimeout(check, 500); })();
    });
  }
  // Odebrané části a soubory druhé kvality pryč (soubor, který patří i jiné části, zůstává).
  function prune(removeIds, keepQuality) {
    return getParts().then(function (all) {
      var stay = {};
      all.forEach(function (part) {
        if (!part.base && removeIds.indexOf(part.id) >= 0) return;
        (part.files[keepQuality] || []).forEach(function (f) { stay[key(f.url)] = true; });
      });
      var drop = {};
      all.forEach(function (part) {
        ['perf', 'hd'].forEach(function (q) { (part.files[q] || []).forEach(function (f) { if (!stay[key(f.url)]) drop[key(f.url)] = true; }); });
      });
      return caches.open(CACHE).then(function (cache) { return Promise.all(Object.keys(drop).map(function (url) { return cache.delete(url); })); });
    }).then(reportParts, function () {});
  }

  // ---------------------------------------------------------------- v2

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

  // ---------------------------------------------------------------- stahovač (v4.1)
  // Jeden stahovač pro engine, datový balík, balíky hry a části (Richard 17. 11.: „stahování se seklo na 30 MB a furt
  // to tam glitchuje ten panel“). Mobilní připojení umí spojení nechat viset bez chyby a prohlížeč pak čeká navždy:
  // když 15 s nepřijdou data, pokus se zahodí a stahuje se znovu (od místa, kde skončil, když server posílá soubor
  // beze změny a umí Range, jinak od začátku), nejvýš 5 pokusů. Hotový soubor je Blob z kousků (bez skládání do
  // jednoho bufferu a bez kopií navíc: na iPhonu jde o paměť).
  //   download(url, {total, onBytes(have, total), gate: () => Promise | null, signal}) → Promise<{blob, headers}>
  // `onBytes` přijde po každém kousku a jednou za sekundu i bez dat (panel stahování v katalogu nezhasne a nebliká),
  // `gate` pozdrží čtení (stahování na pozadí čeká na hru), zaseknutí se během čekání nepočítá.
  var STALL = 15000;
  var TRIES = 5;
  var netFetch = null;
  function download(url, opts) {
    opts = opts || {};
    var chunks = [], have = 0, total = opts.total || 0, tries = 0, headers = null, resumable = false;
    var outer = opts.signal || null;
    var beat = opts.onBytes ? setInterval(function () { opts.onBytes(have, total); }, 1000) : null;
    function attempt() {
      tries += 1;
      var ctrl = new AbortController();
      var stop = function () { ctrl.abort(); };
      if (outer) {
        if (outer.aborted) return Promise.reject(new Error('aborted'));
        outer.addEventListener('abort', stop);
      }
      var timer = null;
      var arm = function () { clearTimeout(timer); timer = setTimeout(stop, STALL); };
      var settle = function () { clearTimeout(timer); if (outer) outer.removeEventListener('abort', stop); };
      var init = { signal: ctrl.signal };
      if (tries > 1) init.cache = 'no-store';
      if (have > 0 && resumable) init.headers = { Range: 'bytes=' + have + '-' };
      else { chunks = []; have = 0; }
      arm();
      return (netFetch || window.fetch).call(window, url, init).then(function (response) {
        if (!response.ok || !response.body) throw new Error('HTTP ' + response.status);
        if (have > 0 && response.status !== 206) { chunks = []; have = 0; }
        headers = headers || response.headers;
        var encoded = !!response.headers.get('content-encoding');
        resumable = !encoded && response.headers.get('accept-ranges') === 'bytes';
        if (!total && !encoded) total = have + (Number(response.headers.get('content-length')) || 0);
        var reader = response.body.getReader();
        var pump = function () {
          var wait = opts.gate ? opts.gate() : null;
          if (wait) clearTimeout(timer);
          var read = function () { arm(); return reader.read(); };
          return (wait ? wait.then(read) : read()).then(function (part) {
            if (part.done) return;
            chunks.push(part.value);
            have += part.value.length;
            if (opts.onBytes) opts.onBytes(have, total);
            return pump();
          });
        };
        return pump();
      }).then(function () {
        settle();
        if (total && have < total) throw new Error('short ' + have + '/' + total);
      }).catch(function (error) {
        settle();
        if ((outer && outer.aborted) || tries >= TRIES) throw error;
        return new Promise(function (resolve) { setTimeout(resolve, Math.min(6000, 700 * tries)); }).then(attempt);
      });
    }
    return attempt().then(function () {
      clearInterval(beat);
      var blob = new Blob(chunks);
      chunks = [];
      return { blob: blob, headers: headers };
    }, function (error) {
      clearInterval(beat);
      throw error;
    });
  }
  // Odpověď ze staženého souboru (pro hru i pro paměť prohlížeče): bez komprese, se skutečnou délkou.
  function blobResponse(got) {
    var headers = new Headers(got.headers);
    headers.delete('content-encoding');
    headers.set('content-length', String(got.blob.size));
    return new Response(got.blob, { status: 200, headers: headers });
  }

  // Engine, hlavní balík a soubory před startem: z paměti, jinak stahovačem ze sítě a do paměti (pokud hráč ukládání
  // neodmítl). Co jde při startu ze sítě, hlásí sada katalogu sama (velká animace) a stránka z toho plní pruh.
  var fetched = {};
  var net = { loaded: 0, total: 0, files: [], told: false };
  function netActive() { return net.files.some(function (f) { return !f.done; }); }
  function netTell() {
    if (!net.files.length) return;
    var active = netActive();
    urgentAt = overlayAt = Date.now();
    overlay = hub && active;
    if (active) post({ type: 'undo:data-progress', part: 'base', quality: quality(), loaded: Math.min(net.loaded, net.total), total: net.total, state: 'download', blocking: true });
    else if (!net.told) {
      net.told = true;
      post({ type: 'undo:data-progress', part: 'base', quality: quality(), loaded: net.total, total: net.total, state: 'done', blocking: true });
    }
  }
  function wrapFetch() {
    var original = netFetch = window.fetch;
    var files = fetched;
    engineFiles(config).forEach(function (file) { files[key(file)] = file; });
    window.fetch = function (input, init) {
      var self = this, args = arguments, url;
      try { url = key(typeof input === 'string' ? input : input.url); } catch (e) { return original.apply(self, args); }
      var file = files[url];
      if (!file) return original.apply(self, args);
      return caches.open(CACHE).then(function (cache) {
        return cache.match(url, { ignoreVary: true }).catch(function () { return null; }).then(function (hit) {
          if (hit) { hits[file] = true; return hit; }
          var size = config.fileSizes[file] || 0;
          var mine = { loaded: 0, done: false };
          net.files.push(mine);
          net.total += size;
          netTell();
          return download(url, { total: size, onBytes: function (have) { net.loaded += have - mine.loaded; mine.loaded = have; netTell(); } }).then(function (got) {
            mine.done = true;
            netTell();
            if (keep !== false) {
              persist();
              cache.put(url, blobResponse(got))
                .then(function () { if (keep === false) return cache.delete(url); })
                .then(report, function () { /* plná paměť: příště se stáhne znovu */ });
            }
            return blobResponse(got);
          }, function (error) {
            mine.done = true;
            netTell();
            throw error;
          });
        });
      }, function () { return original.apply(self, args); });
    };
  }

  // Co hra drží: engine této verze a uložené balíky; jakmile je celý engine uložený, starší verze zmizí.
  function report() {
    if (!config || !kept(config)) return Promise.resolve(false);
    return caches.open(CACHE).then(function (cache) {
      var files = coreFiles();
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

  // Soubor celý do paměti s průběhem po bajtech (stažení předem, hudba po kouscích, části na pozadí). Na pozadí
  // (`background`) se čtení zastaví, dokud hra stahuje něco naléhavého: prohlížeč pak přestane brát data a linka
  // patří hře.
  function store(cache, url, onBytes, background) {
    // stahovač jde mimo obal fetch: engine by se jinak ukládal dvakrát
    var abort = background && window.AbortController ? new AbortController() : null;
    if (abort) bgAbort = abort;
    return download(url, {
      signal: abort ? abort.signal : null,
      onBytes: onBytes ? function (have) { onBytes(have); } : null,
      gate: background ? function () { return Date.now() - urgentAt <= 1500 ? idle() : null; } : null,
    }).then(function (got) {
      return cache.put(key(url), blobResponse(got)).then(function () { return got.blob.size; });
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

  // `?undo_offline=install`: engine, balíky z voleb (v3: základ a části plánu v jeho kvalitě) a hudba předem.
  function install() {
    post({ type: 'undo:offline-start' });
    keep = true;
    persist();
    if (params.get('undo_quality')) {
      plan = { quality: params.get('undo_quality') === 'hd' ? 'hd' : 'perf', parts: params.get('undo_parts') !== null ? (params.get('undo_parts') || '').split(',').filter(Boolean) : null };
      savePlan();
    }
    var prepared = typeof options.prepare === 'function' ? Promise.resolve().then(options.prepare).catch(function () {}) : Promise.resolve();
    var planned = options.parts ? getParts().then(function (all) {
      var q = quality();
      return all.filter(wanted).reduce(function (out, part) { return out.concat(part.files[q] || []); }, []);
    }) : Promise.resolve(null);
    Promise.all([list(options.files), list(options.keep), list(options.packs), planned]).then(function (got) {
      var sizes = {};
      coreFiles().forEach(function (file) { sizes[key(file)] = config.fileSizes[file] || 0; });
      got[2].forEach(function (pack) { sizes[key(pack.url)] = pack.bytes || 0; });
      var extra = got[0];
      if (got[3]) {
        got[3].forEach(function (f) { sizes[key(f.url)] = f.bytes || 0; });
        extra = got[3].map(function (f) { return f.url; });
      }
      var files = coreFiles().concat(extra, got[1]).map(key).filter(function (url, i, all) { return all.indexOf(url) === i; });
      var total = files.reduce(function (sum, url) { return sum + (sizes[url] || 1048576); }, 0);
      var done = 0, bytes = 0, failed = 0;
      return caches.open(CACHE).then(function (cache) {
        return files.reduce(function (chain, url) {
          return chain.then(function () {
            return cache.match(url, { ignoreVary: true }).catch(function () { return null; }).then(function (hit) {
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
        // v3: uložené mimo plán (odebrané části, druhá kvalita) pryč, ať paměť odpovídá výběru ve správci
        if (got[3]) return getParts().then(function (all) { return prune(all.filter(function (part) { return !wanted(part); }).map(function (part) { return part.id; }), quality()); }).then(function () { return 'ok'; });
        return 'ok';
      }).then(function (state) {
        if (state !== 'ok') return;
        report().then(reportParts).then(function () { post({ type: 'undo:offline-installed', bytes: bytes, files: files.length, version: version() }); });
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
      post({ type: 'undo:offline-hello', version: version(), bytes: engineBytes(), parts: !!options.parts });
    });
  }
  addEventListener('message', function (event) {
    if (event.source !== window.parent || !event.data) return;
    var data = event.data;
    if (data.type === 'undo:offline-status-request') { report(); reportParts(); }
    if (data.type === 'undo:offline-keep') {
      var before = keep;
      keep = data.keep === true ? true : data.keep === false ? false : null;
      // v4: hra s částmi data drží vždy; „ne“ z dřívějšího dotazu (katalog si ho pamatuje) nic nemaže
      if (keep === false && options.parts) keep = true;
      waiting.splice(0).forEach(function (resolve) { resolve(); });
      // „Ne“: co se do té doby uložilo, pryč (i balíky hry), dál se neukládá.
      if (keep === false && before !== false && config && kept(config)) caches.delete(CACHE).then(report, function () {}).then(reportParts);
      if (keep === true && before !== true && config && kept(config)) { persist(); report(); polls = 0; watch(); fill(); }
    }
    if (data.type === 'undo:data-plan') {
      hub = true;
      // bez volby kvality zůstává automatická; části platí vždy (katalog: na začátku jen základ)
      var was = quality();
      plan = { quality: data.quality === 'hd' || data.quality === 'perf' ? data.quality : was, parts: Array.isArray(data.parts) ? data.parts.slice() : null };
      savePlan();
      // rozstahovaný soubor části, kterou hráč zrušil (nebo jiné kvality), se utne; pozadí pak jede podle nového plánu
      if (bgAbort) bgAbort.abort();
      var removed = Array.isArray(data.remove) ? data.remove : [];
      (removed.length || was !== quality() ? prune(removed, quality()) : Promise.resolve()).then(fill);
    }
  });

  plan = loadPlan();

  window.__undoOffline = {
    // Stránka je pokyn katalogu, ne hra ke spuštění.
    command: mode === 'install' || mode === 'remove' || mode === 'parts',
    // Před stažením enginu: pryč se starým workerem, pokyn katalogu, nebo ukládání a dotaz katalogu.
    ready: function (cfg, opts) {
      config = cfg;
      options = opts || {};
      if (!kept(cfg)) {
        if (mode === 'install' || mode === 'remove' || mode === 'parts') post({ type: 'undo:offline-failed', error: 'unsupported' });
        return Promise.resolve();
      }
      return retireWorker().then(function (reloading) {
        if (reloading) return new Promise(function () {});
        if (mode === 'install') { install(); return new Promise(function () {}); }
        // v3: katalog chce znát části (správce v detailu hry, hra tu ještě neběžela)
        if (mode === 'parts') { post({ type: 'undo:offline-start' }); reportParts().then(function () { post({ type: 'undo:offline-parts' }); }); return new Promise(function () {}); }
        if (mode === 'remove') { remove(); return new Promise(function () {}); }
        wrapFetch();
        // v3: části katalogu ještě před dotazem, ať při prvním spuštění může nabídnout jejich výběr
        return reportParts().then(ask);
      });
    },
    // Po startu enginu: co je uložené, katalogu; pak hudba po kouscích a části plánu na pozadí.
    started: function () {
      running = true;
      if (!config || !kept(config)) return;
      watch();
      reportParts().then(function () { setTimeout(fill, 3000); });
    },
    report: report,
    // Smí hra ukládat vlastní balíky? (false = hráč ukládání odmítl.)
    keep: function () { return keep; },
    // v3: kvalita, ve které hra hraje ('perf' = Výkon, 'hd' = HD).
    quality: quality,
    // v3: hráč přepnul kvalitu v nastavení hry; katalog upraví plán a správce.
    setQuality: function (q) {
      if (fixedQuality()) return;
      if ((q !== 'perf' && q !== 'hd') || q === quality()) return;
      plan = { quality: q, parts: plan && Array.isArray(plan.parts) ? plan.parts : null };
      savePlan();
      post({ type: 'undo:data-quality', quality: q });
      if (config && kept(config)) prune([], q).then(fill);
    },
    // v3: hra naléhavě stahuje soubor (balík trati před závodem): katalog ukáže velkou animaci, pozadí počká.
    fileProgress: function (url, loaded, total) {
      urgentAt = overlayAt = Date.now();
      overlay = hub && loaded < total;
      var part = partOf(url);
      post({ type: 'undo:data-progress', part: part ? part.id : 'base', quality: quality(), loaded: Math.min(loaded, total), total: total, state: loaded >= total ? 'done' : 'download', blocking: true });
      if (loaded >= total) setTimeout(reportParts, 300);
    },
    // v3: katalog teď kreslí animaci stahování přes hru (stránka schová vlastní ukazatel, ať nejsou dva).
    overlay: function () { return overlay && Date.now() - overlayAt < 2000; },
    // v3: katalog části kreslí a spravuje (hra pak vlastní správce stahování neukazuje).
    catalog: function () { return hub; },
    // v3: soubor, který stránka dá enginu před startem (`engine.preloadFile`, Stickwound: textury podle kvality):
    // jde stejnou cestou jako engine (z paměti, jinak ze sítě a cestou do paměti).
    boot: function (url) { fetched[key(url)] = url; if (boots.indexOf(url) < 0) boots.push(url); },
    // v3: hra stahuje něco, na co hráč nečeká (fotky aut do menu), nebo něco načítá (obrazovka načítání: stahování
    // a ukládání na pozadí by jí bralo hlavní vlákno): pozadí počká, katalog nic neukazuje.
    busy: function () { urgentAt = Date.now(); },
    // Stavová hláška pod ukazatelem načítání (`current`/`total` = průběh enginu z onProgress). v4: stahování = jen
    // soubory, které v paměti nebyly (aktualizace kódu: pár MB, ne celý engine); start z paměti katalog neukazuje.
    // v4.1: průběh stahování hlásí katalogu stahovač sám (i během zaseknutí, panel nebliká), tady jen text.
    status: function (current, total) {
      var czech = cs();
      if (netActive()) return (czech ? 'Stahuji data · ' : 'Downloading · ') + mb(net.loaded) + ' / ' + mb(net.total) + ' MB';
      if (total > 0 && current < total) return czech ? 'Načítám z paměti zařízení' : 'Loading from this device';
      return czech ? 'Spouštím hru…' : 'Starting the game…';
    },
    // v4.1: stahování při startu pro pruh stránky: {loaded, total, active} (Godot vidí soubor až celý)
    net: function () { return { loaded: net.loaded, total: net.total, active: netActive() }; },
    // v4.1: stahovač sady pro balíky hry (web_packs.js, map-packs.js): zaseknutí → nový pokus, Blob bez kopií
    download: download,
  };
})();
