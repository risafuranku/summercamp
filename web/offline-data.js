// The game's data kept in the browser for good, as UNDO.games' Godot games agreed (undogames
// docs/OFFLINE_GAMES.md, stickwoundgodot docs/OFFLINE_STATUS.md). The offline kit's worker
// (/undo-offline-sw.js, a copy of undogames/docs/offline-kit) keeps what the page downloads, and
// what lies under /assets/ (the engine and the game's data, printed names: tools/web/deploy.mjs)
// it never fetches again: a player downloads the 300 MB once per version, not at every start.
// - registered before the engine downloads, so the first visit already keeps it;
// - the catalogue hears what the game keeps (`undo:offline-status`, its downloads manager, and on
//   `undo:offline-status-request`); an older version's files go once the new one is kept;
// - the catalogue's own commands in a hidden frame (`?undo_offline=install|remove`, the protocol
//   of the kit's undo-offline.js): download everything ahead, or delete it. The engine does not
//   start then.
// Only the deployed build (its engine under /assets/): the test build keeps nothing.
(function () {
  var CACHE = 'undo-offline-v1';
  var WORKER = '/undo-offline-sw.js';
  var mode = (new URLSearchParams(location.search).get('undo_offline') || '');
  var config = null;
  var polls = 0;

  function post(message) {
    if (window.parent === window) return;
    try { window.parent.postMessage(Object.assign({ v: 1 }, message), '*'); } catch (e) { /* parent gone */ }
  }
  function kept(cfg) { return /^assets\//.test(cfg.executable) && 'serviceWorker' in navigator && 'caches' in window; }
  function engineFiles(cfg) {
    var base = cfg.executable;
    return [base + '.js', base + '.wasm', base + '.pck', base + '.audio.worklet.js', base + '.audio.position.worklet.js'];
  }
  function path(file) { return new URL(file, location.href).pathname; }

  // The kit's worker in charge of the page (it claims it as it starts); at most a few seconds.
  function worker() {
    if (navigator.serviceWorker.controller) return Promise.resolve(true);
    return navigator.serviceWorker.register(WORKER, { scope: '/' }).then(function () {
      return Promise.race([
        new Promise(function (resolve) { navigator.serviceWorker.addEventListener('controllerchange', function () { resolve(true); }, { once: true }); }),
        new Promise(function (resolve) { setTimeout(function () { resolve(Boolean(navigator.serviceWorker.controller)); }, 4000); }),
      ]);
    }).catch(function () { return false; });
  }

  // What the game keeps: the engine's files of this version, their sizes from the engine's own
  // config; once all are kept, the files of older versions go.
  function report() {
    if (!config) return Promise.resolve(false);
    return caches.open(CACHE).then(function (cache) {
      var files = engineFiles(config);
      return Promise.all(files.map(function (file) { return cache.match(new URL(file, location.href).href, { ignoreVary: true }); })).then(function (hits) {
        var installed = hits.every(Boolean);
        var bytes = 0;
        hits.forEach(function (hit, i) { if (hit) bytes += config.fileSizes[files[i]] || 0; });
        var tidy = installed ? cache.keys().then(function (keys) {
          var current = {};
          files.forEach(function (file) { current[path(file)] = true; });
          return Promise.all(keys.filter(function (request) {
            var p = new URL(request.url).pathname;
            return p.indexOf('/assets/') === 0 && !current[p];
          }).map(function (request) { return cache.delete(request); }));
        }) : Promise.resolve();
        return tidy.then(function () {
          post({ type: 'undo:offline-status', installed: installed, version: config.executable.split('.').pop(), bytes: bytes, packs: [] });
          return installed;
        });
      });
    }).catch(function () { return false; });
  }
  // The worker keeps a file after the page has it: looked again until the whole engine is kept.
  function watch() {
    report().then(function (installed) {
      if (!installed && polls++ < 120) setTimeout(watch, 5000);
    });
  }

  // `?undo_offline=install`: every file of this version kept ahead, the progress told.
  function install() {
    post({ type: 'undo:offline-start' });
    var files = engineFiles(config).concat(['/', 'splash.webm', 'splash.mp4', 'card_logo.png']);
    worker().then(function () {
      var active = navigator.serviceWorker.controller;
      if (!active) { post({ type: 'undo:offline-failed', error: 'worker' }); return; }
      var channel = new MessageChannel();
      channel.port1.onmessage = function (event) {
        var data = event.data || {};
        if (data.type === 'progress') post({ type: 'undo:offline-progress', done: data.done, total: data.total });
        if (data.type === 'done') {
          if (data.failed && data.failed.length) post({ type: 'undo:offline-failed', error: 'files' });
          else report().then(function () { post({ type: 'undo:offline-installed', bytes: data.bytes, files: data.files, version: config.executable.split('.').pop() }); });
        }
      };
      active.postMessage({ type: 'cache', urls: files.map(function (file) { return new URL(file, location.href).href; }), version: config.executable }, [channel.port2]);
    });
  }
  // `?undo_offline=remove`: everything the game keeps deleted, the worker let go.
  function remove() {
    post({ type: 'undo:offline-start' });
    caches.delete(CACHE).then(function () {
      return navigator.serviceWorker.getRegistrations().then(function (list) { return Promise.all(list.map(function (r) { return r.unregister(); })); });
    }).then(function () { post({ type: 'undo:offline-removed' }); }, function () { post({ type: 'undo:offline-failed', error: 'remove' }); });
  }

  addEventListener('message', function (event) {
    if (event.source === window.parent && event.data && event.data.type === 'undo:offline-status-request') report();
  });

  window.__ccOffline = {
    // True when the page is the catalogue's command, not a game to start.
    command: mode === 'install' || mode === 'remove',
    // Before the engine downloads: the worker in charge, or the catalogue's command carried out.
    ready: function (cfg) {
      config = cfg;
      if (!kept(cfg)) {
        if (mode === 'install' || mode === 'remove') post({ type: 'undo:offline-failed', error: 'unsupported' });
        return Promise.resolve();
      }
      if (mode === 'install') { install(); return new Promise(function () {}); }
      if (mode === 'remove') { remove(); return new Promise(function () {}); }
      // (The engine's script came before the worker took the page: fetched again through it,
      // from the browser's cache, so it is kept too.)
      return worker().then(function (inCharge) {
        if (inCharge) fetch(engineFiles(cfg)[0]).catch(function () {});
      });
    },
    // After the engine started: what is kept, told to the catalogue.
    started: function () { if (config && kept(config)) watch(); },
  };
})();
