// Long tracks (the insects, the day's ambience, wind and rain, the camp's music) played by the browser, not by
// Godot's mixer: on the web the engine mixes on its one thread and every long frame was a gap in the sound
// (the user 16. 11.: "it stutters like hell"). Each track is an <audio> element (decoded and played off the main
// thread) through a low-pass and a gain into this page's AudioContext (undo-controller.js gives every context the
// hub's mute). godot/scripts/audio/long_player.gd drives it: play, stop, seek, pause, set(gain, low-pass, rate),
// ended. The tracks are not in the game's pack: window.__ccAudio maps their res:// paths to the page's files
// (tools/web/export.mjs); once UNDO.games has kept them (offline kit, Cache Storage undo-offline-v1) they play
// from the browser's storage, else they stream.
(function () {
  if (window.__ccStream) return;
  var CACHE = 'undo-offline-v1';
  var ctx = null;
  var players = {};

  function context() {
    if (ctx) return ctx;
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    // a page that may not play sound yet starts on the first gesture
    ['pointerdown', 'keydown', 'touchend'].forEach(function (type) {
      addEventListener(type, function () { if (ctx.state !== 'running') ctx.resume(); }, true);
    });
    return ctx;
  }
  function address(path) { return (window.__ccAudio || {})[path] || null; }
  // From the browser's storage as a blob when kept, else the page's file (streamed with ranges).
  function source(url) {
    if (!('caches' in window)) return Promise.resolve(url);
    var key = new URL(url, location.href);
    return caches.open(CACHE).then(function (cache) { return cache.match(key.origin + key.pathname, { ignoreVary: true }); })
      .then(function (hit) { return hit ? hit.blob().then(function (blob) { return URL.createObjectURL(blob); }) : url; })
      .catch(function () { return url; });
  }
  function make(id) {
    var c = context();
    var el = new Audio();
    el.preload = 'auto';
    el.preservesPitch = false;
    el.mozPreservesPitch = false;
    el.webkitPreservesPitch = false;
    var node = c.createMediaElementSource(el);
    var lowpass = c.createBiquadFilter();
    lowpass.type = 'lowpass';
    lowpass.frequency.value = 22050;
    var gain = c.createGain();
    gain.gain.value = 0;
    node.connect(lowpass).connect(gain).connect(c.destination);
    return (players[id] = { el: el, lowpass: lowpass, gain: gain, path: '', blob: '', want: false, ended: false, token: 0 });
  }
  function start(p) {
    if (!p.want) return;
    var go = p.el.play();
    if (go && go.catch) go.catch(function () { /* before a gesture: the next one resumes the context */ });
  }

  window.__ccStream = {
    has: function (path) { return !!address(path); },
    // The tracks in a folder (res://…/), sorted: the radio's songs on the web.
    list: function (dir) {
      return JSON.stringify(Object.keys(window.__ccAudio || {}).filter(function (p) { return p.indexOf(dir) === 0 && p.slice(dir.length).indexOf('/') < 0; }).sort());
    },
    play: function (id, path, at, loop) {
      var p = players[id] || make(id);
      p.want = true;
      p.ended = false;
      p.el.loop = !!loop;
      if (ctx.state !== 'running') ctx.resume();
      if (p.path === path && p.el.src) {
        try { p.el.currentTime = at || 0; } catch (e) { /* not loaded yet */ }
        start(p);
        return;
      }
      p.path = path;
      var token = ++p.token;
      var url = address(path);
      if (!url) return;
      source(url).then(function (src) {
        if (token !== p.token) return;
        if (p.blob) URL.revokeObjectURL(p.blob);
        p.blob = src.indexOf('blob:') === 0 ? src : '';
        p.el.src = src;
        p.el.onended = function () { p.ended = true; };
        var seek = function () { try { p.el.currentTime = (at || 0) % (p.el.duration || Infinity); } catch (e) { /* ignore */ } };
        if (p.el.readyState >= 1) seek(); else p.el.addEventListener('loadedmetadata', seek, { once: true });
        start(p);
      });
    },
    seek: function (id, at) {
      var p = players[id];
      if (p) try { p.el.currentTime = (at || 0) % (p.el.duration || Infinity); } catch (e) { /* ignore */ }
    },
    stop: function (id) {
      var p = players[id];
      if (!p) return;
      p.want = false;
      p.el.pause();
    },
    pause: function (id, paused) {
      var p = players[id];
      if (!p) return;
      if (paused) p.el.pause(); else start(p);
    },
    set: function (id, gain, cutoff, rate) {
      var p = players[id];
      if (!p) return;
      var t = ctx.currentTime;
      p.gain.gain.setTargetAtTime(gain, t, 0.03);
      p.lowpass.frequency.setTargetAtTime(Math.max(40, Math.min(22050, cutoff)), t, 0.05);
      if (rate > 0.05 && Math.abs(p.el.playbackRate - rate) > 0.001) p.el.playbackRate = rate;
    },
    ended: function (id) { var p = players[id]; return !!(p && p.ended); },
    // QA (tools/web/qa.mjs --probe): what plays, where, how loud.
    debug: function () {
      return JSON.stringify(Object.keys(players).map(function (id) {
        var p = players[id];
        return { id: id, path: p.path, playing: !p.el.paused, t: Math.round(p.el.currentTime * 10) / 10, gain: Math.round(p.gain.gain.value * 1000) / 1000, cutoff: Math.round(p.lowpass.frequency.value), rate: p.el.playbackRate, context: ctx && ctx.state };
      }));
    },
  };
})();
