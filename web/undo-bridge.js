// The game and UNDO.games (protocol v1, as every UNDO game speaks it). The hub talks to the game
// with messages into its frame; this script takes them (only from the allowed origins and only
// from the parent), queues them, and the game collects them (scripts/web/undo_hub.gd). The page's
// own events go into the same queue: the page hidden or shown again (the game pauses on hidden,
// not on a lost focus: a click on the hub's bar must not stop the game or its sound).
(function () {
  var ALLOWED = ['undogames.cz', 'games.undogames.cz', 'games.undocollective.cz', 'undocollective.cz'];
  var ALLOWED_SUFFIX = ['.undogames.cz', '.undocollective.cz', '.vercel.app'];
  var inbox = [];
  var parentOrigin = null;
  function allowed(origin) {
    try {
      var url = new URL(origin);
      var host = url.hostname.toLowerCase();
      var local = host === 'localhost' || host === '127.0.0.1' || host.endsWith('.ts.net');
      return (url.protocol === 'https:' || local) && (ALLOWED.indexOf(host) >= 0 || ALLOWED_SUFFIX.some(function (s) { return host.endsWith(s); }) || local);
    } catch (e) { return false; }
  }
  window.addEventListener('message', function (event) {
    if (event.source !== window.parent || !allowed(event.origin)) return;
    var message = event.data;
    if (!message || message.v !== 1 || typeof message.type !== 'string' || message.type.indexOf('undo:') !== 0) return;
    parentOrigin = parentOrigin || event.origin;
    try { inbox.push(JSON.stringify(message)); } catch (e) { /* unreadable */ }
  });
  document.addEventListener('visibilitychange', function () {
    inbox.push(JSON.stringify({ type: document.hidden ? 'page:hidden' : 'page:visible' }));
  });
  window.__ccUndo = {
    embedded: window.parent !== window,
    drain: function () { if (!inbox.length) return ''; var out = '[' + inbox.join(',') + ']'; inbox.length = 0; return out; },
    post: function (json) {
      if (window.parent === window) return;
      try { window.parent.postMessage(Object.assign({ v: 1 }, JSON.parse(json)), parentOrigin || '*'); } catch (e) { /* parent gone */ }
    },
    hubOrigin: function () { return parentOrigin || ''; },
    returnUrl: function () { return new URLSearchParams(location.search).get('undo_return') || ''; },
  };
})();
