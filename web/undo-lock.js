/**
 * UNDO game lock — hra se smí spustit jen uvnitř katalogu na undogames.cz.
 *
 * Kopíruje se do všech her beze změny a načítá se jako první skript stránky,
 * aby zamkl dřív, než se rozjede engine. Nastaví `window.__undoLocked`, schová
 * obsah stránky a přes celou obrazovku natáhne jedno plátno.
 *
 * Scéna: starý televizor naskočí, v mlze rostou věže z kostek jako při
 * startu konzole, modrý disk se roztočí — a čtení selže. Obraz se trhá,
 * zamrzá a barví do ruda, pak tma, jedno podprahové probliknutí a chybová
 * obrazovka s cestou do katalogu. Pak už jen tiše hnije: občas se obraz
 * zadrhne, disk se zkusí roztočit a něco probleskne.
 *
 * Výkon: celá 3D scéna se kreslí do malého plátna (dlouhá strana ~800 px,
 * jako tehdejší konzole) a teprve to se roztáhne na obrazovku. Glitche čtou
 * z toho malého plátna nebo z kopie minulého snímku — nikdy z plátna, na
 * které se zrovna kreslí; čtení plátna do sebe sama dusí GPU. Rastry, šum
 * a vinětace se kreslí jednou a pak se jen pokládají.
 */
(function () {
  "use strict";

  var CATALOG_URL = "https://undogames.cz";
  var SANS = "ui-sans-serif, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif";
  var MONO = "ui-monospace, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace";

  /** Vývoj na vlastním stroji zamykat nebudeme. */
  function isLocal() {
    var host = location.hostname;
    if (host === "localhost" || host === "127.0.0.1" || host === "" || host.slice(-6) === ".local") return true;
    // Testování z telefonu přes Tailscale (MagicDNS jméno, *.ts.net nebo 100.64.0.0/10).
    if (host.slice(-7) === ".ts.net" || host.indexOf(".") < 0) return true;
    var m = /^100\.(\d+)\.\d+\.\d+$/.exec(host);
    if (m && +m[1] >= 64 && +m[1] <= 127) return true;
    // Domácí síť (PC pod svou adresou v LAN): 192.168.x.x, 10.x.x.x, 172.16–31.x.x.
    var lan = /^(192\.168|10)\.\d+\.\d+(\.\d+)?$|^172\.(1[6-9]|2\d|3[01])\.\d+\.\d+$/;
    return lan.test(host);
  }

  /**
   * Hra běží legitimně jen uvnitř katalogu. Cizí web si ji do iframe nevloží,
   * to blokuje frame-ancestors v hlavičkách; tady tedy stačí odchytit přímé
   * otevření adresy na Vercelu.
   */
  function isEmbedded() {
    try {
      return window.parent !== window.self;
    } catch (error) {
      // Výjimka znamená cross-origin rodiče, tedy iframe.
      return true;
    }
  }

  // `__undoLockPreview` slouží jen k prohlédnutí obrazovky při vývoji;
  // zámek zapíná, nikdy nevypíná, takže se přes něj nedá nic obejít.
  if (!window.__undoLockPreview && (isLocal() || isEmbedded())) return;

  // Hra se podle tohohle příznaku ani nerozjede (zvuk, síť, animace).
  window.__undoLocked = true;

  var reduced = false;
  try {
    reduced = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  } catch (error) {
    // Starší prohlížeč dotaz neumí; jedeme s plnou animací.
  }

  /* ------------------------------ Pomocníci ------------------------------ */

  function rand(a, b) { return a + Math.random() * (b - a); }
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function lerp(a, b, k) { return a + (b - a) * k; }
  function smooth(k) { k = clamp(k, 0, 1); return k * k * (3 - 2 * k); }
  function outBack(k) { k = clamp(k, 0, 1); var c = 1.7; return 1 + (c + 1) * Math.pow(k - 1, 3) + c * Math.pow(k - 1, 2); }
  /** Deterministický šum z celých čísel — věže mají stálé výšky, ať se nemihotají. */
  function hash(a, b) {
    var h = (a * 374761393 + b * 668265263) | 0;
    h = (h ^ (h >>> 13)) * 1274126177;
    h = h ^ (h >>> 16);
    return ((h >>> 0) % 10000) / 10000;
  }
  function layer(w, h) {
    var c = document.createElement("canvas");
    c.width = Math.max(1, Math.round(w));
    c.height = Math.max(1, Math.round(h));
    return c;
  }

  var GARBLE = "▓▒░█#%&@$ΔΞ¥§¤╳╬";
  var WHISPERS = [
    "NEMĚL BYS TU BÝT",
    "VRAŤ SE",
    "KDO TĚ SEM POSLAL?",
    "TADY NIC NENÍ",
    "VIDÍM TĚ",
    "DISK JE PRÁZDNÝ",
  ];
  var MEMORY_LINES = [
    "Paměťová karta (8 MB) ve slotu 1 je poškozená.",
    "Paměťová karta (8 MB) ve slotu 1 se právě používá.",
    "Neodpojuj ovladač.",
    "Ovladač 2 není připojený. Přesto se hýbe.",
    "Ukládání… 0 %",
  ];

  function start() {
    /* --------------------------- Schovat hru --------------------------- */

    var veil = document.createElement("style");
    veil.textContent =
      "html.undo-locked body>*:not([data-undo-lock]){display:none!important}" +
      "html.undo-locked,html.undo-locked body{background:#000!important;overflow:hidden!important;margin:0!important}";
    (document.head || document.documentElement).appendChild(veil);
    document.documentElement.classList.add("undo-locked");
    document.title = "DISC READ ERROR";

    var cv = document.createElement("canvas");
    cv.setAttribute("data-undo-lock", "");
    cv.style.cssText =
      "position:fixed;inset:0;width:100vw;height:100vh;height:100dvh;z-index:2147483647;display:block;" +
      "background:#000;margin:0;padding:0;border:0;outline:none;touch-action:manipulation;-webkit-tap-highlight-color:transparent";
    cv.setAttribute("role", "img");
    cv.setAttribute("aria-label", "Hra je zamčená — hraje se jen na undogames.cz. Game locked, play at undogames.cz.");
    (document.body || document.documentElement).appendChild(cv);
    var ctx = cv.getContext("2d");

    /* ----------------------------- Rozměry ----------------------------- */

    var W = 0, H = 0, dpr = 1;
    // Scéna v nízkém rozlišení, kopie minulého snímku a vrstvy pro RGB rozklad.
    var sc, s, prev, pctx, tint = [], sw = 0, sh = 0;
    var scan, noise = [], vignette, discTex, discSheen, crack;
    var R = 100; // poloměr disku v pixelech scény

    function resize() {
      W = window.innerWidth; H = window.innerHeight;
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);

      var k = Math.min(1, 800 / Math.max(W, H, 1));
      sw = Math.max(160, Math.round(W * k)); sh = Math.max(160, Math.round(H * k));
      sc = layer(sw, sh); s = sc.getContext("2d");
      prev = layer(sw, sh); pctx = prev.getContext("2d");
      tint = ["#ff0000", "#00ff00", "#0000ff"].map(function (color) {
        var c = layer(sw, sh);
        return { c: c, x: c.getContext("2d"), color: color };
      });

      R = Math.round(Math.min(sw, sh) * 0.2);
      bakeDisc();
      bakeOverlays();
    }

    /** Disk: spodní strana PS2 CD je modrá. Stopy a škrábance se točí, odlesk stojí. */
    function bakeDisc() {
      var size = R * 2 + 4;
      discTex = layer(size, size);
      var d = discTex.getContext("2d");
      var c = size / 2;
      var base = d.createRadialGradient(c, c, R * 0.18, c, c, R);
      base.addColorStop(0, "#1b2c63");
      base.addColorStop(0.55, "#0e1a44");
      base.addColorStop(1, "#060c24");
      d.fillStyle = base;
      d.beginPath(); d.arc(c, c, R, 0, Math.PI * 2); d.fill();
      // Stopy — jemné soustředné kruhy, každý trochu jinak světlý.
      for (var r = R * 0.36; r < R * 0.97; r += 1.6) {
        d.strokeStyle = "rgba(140,170,255," + (0.03 + Math.random() * 0.06).toFixed(3) + ")";
        d.lineWidth = 0.7;
        d.beginPath(); d.arc(c, c, r, 0, Math.PI * 2); d.stroke();
      }
      // Škrábance a jeden tmavý flek — díky nim je vidět, že se disk točí.
      for (var i = 0; i < 16; i++) {
        var a = rand(0, Math.PI * 2), r1 = rand(R * 0.4, R * 0.92), len = rand(0.08, 0.5);
        d.strokeStyle = "rgba(220,230,255," + rand(0.08, 0.28).toFixed(3) + ")";
        d.lineWidth = rand(0.4, 1.1);
        d.beginPath(); d.arc(c, c, r1, a, a + len); d.stroke();
      }
      d.fillStyle = "rgba(0,0,0,0.35)";
      d.beginPath(); d.ellipse(c + R * 0.55, c - R * 0.2, R * 0.12, R * 0.05, 0.6, 0, Math.PI * 2); d.fill();
      // Průhledný náboj a díra.
      d.globalCompositeOperation = "destination-out";
      d.beginPath(); d.arc(c, c, R * 0.3, 0, Math.PI * 2); d.fill();
      d.globalCompositeOperation = "source-over";
      d.strokeStyle = "rgba(200,215,255,0.35)"; d.lineWidth = 1.2;
      d.beginPath(); d.arc(c, c, R * 0.3, 0, Math.PI * 2); d.stroke();
      d.fillStyle = "rgba(190,205,240,0.12)";
      d.beginPath(); d.arc(c, c, R * 0.3, 0, Math.PI * 2); d.arc(c, c, R * 0.14, 0, Math.PI * 2, true); d.fill();
      d.globalCompositeOperation = "destination-out";
      d.beginPath(); d.arc(c, c, R * 0.075, 0, Math.PI * 2); d.fill();
      d.globalCompositeOperation = "source-over";
      d.strokeStyle = "rgba(170,190,255,0.5)"; d.lineWidth = 1;
      d.beginPath(); d.arc(c, c, R - 0.5, 0, Math.PI * 2); d.stroke();

      // Duhový odlesk: dva protilehlé klíny, jako když se na CD dívá proti lampě.
      discSheen = layer(size, size);
      var h = discSheen.getContext("2d");
      h.save();
      h.beginPath(); h.arc(c, c, R, 0, Math.PI * 2); h.arc(c, c, R * 0.3, 0, Math.PI * 2, true); h.clip();
      if (h.createConicGradient) {
        var g = h.createConicGradient(-0.4, c, c);
        var stops = [
          [0, "rgba(255,80,160,0)"], [0.05, "rgba(255,90,170,0.55)"], [0.09, "rgba(255,230,90,0.55)"],
          [0.13, "rgba(90,255,190,0.5)"], [0.17, "rgba(80,160,255,0.45)"], [0.22, "rgba(80,160,255,0)"],
          [0.5, "rgba(255,80,160,0)"], [0.55, "rgba(255,90,170,0.45)"], [0.59, "rgba(255,230,90,0.45)"],
          [0.63, "rgba(90,255,190,0.4)"], [0.67, "rgba(80,160,255,0.38)"], [0.72, "rgba(80,160,255,0)"], [1, "rgba(0,0,0,0)"],
        ];
        for (var q = 0; q < stops.length; q++) g.addColorStop(stops[q][0], stops[q][1]);
        h.fillStyle = g;
      } else {
        var lg = h.createLinearGradient(0, 0, size, size);
        lg.addColorStop(0.3, "rgba(255,90,170,0)"); lg.addColorStop(0.45, "rgba(255,230,90,0.4)");
        lg.addColorStop(0.55, "rgba(90,200,255,0.4)"); lg.addColorStop(0.7, "rgba(90,200,255,0)");
        h.fillStyle = lg;
      }
      h.fillRect(0, 0, size, size);
      h.restore();

      // Praskliny — ukážou se, až čtení selže.
      crack = [];
      for (var n = 0; n < 5; n++) {
        var ang = rand(0, Math.PI * 2), rr = R * 0.32, pts = [];
        while (rr < R * 0.99) {
          pts.push([Math.cos(ang) * rr, Math.sin(ang) * rr]);
          ang += rand(-0.22, 0.22); rr += rand(R * 0.06, R * 0.16);
        }
        pts.push([Math.cos(ang) * R, Math.sin(ang) * R]);
        crack.push(pts);
      }
    }

    function bakeOverlays() {
      // Řádkování: jeden vzorek, jedno vyplnění za snímek.
      var tile = layer(1, 3 * dpr);
      var tc = tile.getContext("2d");
      tc.fillStyle = "rgba(0,0,0,0.2)";
      tc.fillRect(0, 0, 1, Math.max(1, Math.round(dpr)));
      scan = ctx.createPattern(tile, "repeat");

      noise = [];
      for (var i = 0; i < 3; i++) {
        var nz = layer(160, 160), nc = nz.getContext("2d"), img = nc.createImageData(160, 160);
        for (var p = 0; p < img.data.length; p += 4) {
          var v = Math.random() * 255;
          img.data[p] = img.data[p + 1] = img.data[p + 2] = v;
          img.data[p + 3] = 255;
        }
        nc.putImageData(img, 0, 0);
        noise.push(ctx.createPattern(nz, "repeat"));
      }

      vignette = layer(cv.width, cv.height);
      var vc = vignette.getContext("2d");
      var g = vc.createRadialGradient(cv.width / 2, cv.height / 2, Math.min(cv.width, cv.height) * 0.25, cv.width / 2, cv.height / 2, Math.hypot(cv.width, cv.height) * 0.55);
      g.addColorStop(0, "rgba(0,0,0,0)");
      g.addColorStop(0.75, "rgba(0,0,0,0.35)");
      g.addColorStop(1, "rgba(0,0,0,0.85)");
      vc.fillStyle = g; vc.fillRect(0, 0, cv.width, cv.height);
    }

    resize();
    window.addEventListener("resize", resize);

    /* ------------------------------ Časová osa ------------------------------ */

    var T_ON = 0.55;     // televizor naskočí
    var T_DISC = 1.15;   // disk se objeví
    var T_FAIL = 3.35;   // čtení začne selhávat
    var T_DARK = 4.6;    // tma
    var T_ERR = 4.9;     // chybová obrazovka

    var T0 = performance.now(), last = T0, t = 0;
    var running = true;
    var gl = 0;              // síla glitche 0–1, sama odeznívá
    var frozenUntil = 0;     // „zamrzlý“ obraz scény — záměrné zadrhnutí, ne sekání
    var nextBurst = T_ERR + rand(2.5, 5);
    var nextTwitch = T_ERR + rand(4, 7);
    var nextWhisper = T_ERR + rand(12, 20);
    var whisper = null;      // { text, until }
    var memoryIndex = 0, memoryAt = T_ERR + 1.8;
    var spin = 0, omega = 0; // natočení a rychlost disku
    var camZ = 0;
    var ctaBox = null, ctaHover = false;
    var motes = [];
    for (var i = 0; i < 42; i++) motes.push({ x: Math.random(), y: Math.random(), z: rand(0.3, 1), ph: rand(0, 6.28) });

    if (reduced) T0 = performance.now() - (T_ERR + 3) * 1000;

    /* ------------------------------- Scéna -------------------------------- */

    /** Věže z kostek v mlze. `rot` = kolik zčervenaly, `lum` = jas celé scény. */
    function drawTowers(time, rot, lum) {
      // Na telefonu na výšku se ohnisko zkrátí, jinak věže utečou za okraj.
      var f = Math.min(sw * 1.15, sh * 0.95), horizon = sh * 0.47, camY = 3.1;
      var spacing = sw < sh ? 4.2 : 6;
      var camX = Math.sin(time * 0.13) * 1.2;

      // Nebe a podlaha.
      var sky = s.createLinearGradient(0, 0, 0, sh);
      var hue = lerp(222, 352, rot);
      sky.addColorStop(0, "hsl(" + hue + ",60%," + (3 * lum).toFixed(1) + "%)");
      sky.addColorStop(0.47, "hsl(" + hue + ",70%," + (16 * lum).toFixed(1) + "%)");
      sky.addColorStop(0.5, "hsl(" + hue + ",60%," + (9 * lum).toFixed(1) + "%)");
      sky.addColorStop(1, "hsl(" + hue + ",60%," + (2 * lum).toFixed(1) + "%)");
      s.fillStyle = sky; s.fillRect(0, 0, sw, sh);

      var glow = s.createRadialGradient(sw / 2, horizon, 0, sw / 2, horizon, Math.max(sw, sh) * 0.6);
      glow.addColorStop(0, "hsla(" + hue + ",90%,70%," + (0.22 * lum).toFixed(3) + ")");
      glow.addColorStop(1, "hsla(" + hue + ",90%,50%,0)");
      s.fillStyle = glow; s.fillRect(0, 0, sw, sh);

      var rowBase = Math.floor(camZ / 6);
      s.lineWidth = 1;
      for (var n = 15; n >= 0; n--) {
        var row = rowBase + n;
        var z = row * 6 - camZ + 3;
        // Nejbližší řady by zakryly půl obrazovky — mlha je lepší kulisa.
        if (z < 7) continue;
        var fog = clamp(1 - z / 92, 0, 1);
        var scale = f / z;
        for (var col = -9; col <= 9; col++) {
          if (col === 0 || (sw >= sh && (col === -1 || col === 1))) continue; // ulička pro disk
          var hv = hash(col + 40, row);
          if (hv < 0.28) continue;
          var stack = 1 + Math.floor(hash(col, row + 99) * 7);
          var x = col * spacing + (hash(col + 7, row) - 0.5) * 2;
          var size = 2.4;
          var sx = sw / 2 + (x - camX) * scale;
          var w = size * scale;
          if (sx + w < 0 || sx - w > sw) continue;
          for (var k = 0; k < stack; k++) {
            var yb = k * (size + 0.28);
            var top = horizon - (yb + size - camY) * scale;
            var lit = hash(col * 3 + k, row) > 0.94;
            var jitter = rot > 0.3 && hash(col + k, row + Math.floor(time * 8)) > 0.97 ? rand(-1, 1) * w * rot : 0;
            var a = fog * lum * (lit ? 0.75 + Math.sin(time * 3 + col + row) * 0.2 : 0.38);
            var cubeHue = lerp(218, 356, rot) + (lit ? -12 : 0);
            s.fillStyle = "hsla(" + cubeHue.toFixed(0) + ",85%," + (lit ? 70 : 58) + "%," + a.toFixed(3) + ")";
            s.fillRect(sx - w / 2 + jitter, top, w, size * scale);
            // Boční stěna ke středu obrazu — z plochých obdélníků udělá kostky.
            var side = Math.min(w * 0.45, Math.abs(sx - sw / 2) * 0.08);
            s.fillStyle = "hsla(" + cubeHue.toFixed(0) + ",80%,30%," + (a * 0.9).toFixed(3) + ")";
            s.fillRect(sx > sw / 2 ? sx - w / 2 - side + jitter : sx + w / 2 + jitter, top + side * 0.3, side, size * scale - side * 0.3);
            s.fillStyle = "hsla(" + cubeHue.toFixed(0) + ",100%,85%," + (a * 1.5).toFixed(3) + ")";
            s.fillRect(sx - w / 2 + jitter, top, w, Math.max(1, scale * 0.12));
          }
        }
      }

      // Poletující světýlka.
      for (var m = 0; m < motes.length; m++) {
        var M = motes[m];
        var my = (M.y - time * 0.012 * M.z) % 1; if (my < 0) my += 1;
        var mx = M.x + Math.sin(time * 0.4 + M.ph) * 0.01;
        var ma = (0.25 + Math.sin(time * 1.3 + M.ph) * 0.2) * lum * M.z;
        s.fillStyle = "hsla(" + lerp(210, 0, rot).toFixed(0) + ",100%,80%," + clamp(ma, 0, 1).toFixed(3) + ")";
        var ms = 1 + M.z * 1.6;
        s.fillRect(mx * sw, my * sh, ms, ms);
      }
    }

    /** Disk se stopou laseru. `wob` = kolik se kymácí, `cracked` = praskliny 0–1. */
    function drawDisc(cx, cy, scale, alpha, wob, cracked, time) {
      if (alpha <= 0.01) return;
      var tex = discTex, half = tex.width / 2;
      s.save();
      s.globalAlpha = alpha;
      s.translate(cx, cy);
      // Stín pod diskem.
      s.fillStyle = "rgba(0,0,0,0.45)";
      s.beginPath(); s.ellipse(0, R * scale * 1.12, R * scale * 0.85, R * scale * 0.12, 0, 0, Math.PI * 2); s.fill();
      s.scale(scale, scale * (1 - wob * 0.25 * (0.5 + 0.5 * Math.sin(time * 23))));
      // Rychle točený disk rozmazat pár průhlednými kopiemi.
      var blur = clamp(Math.abs(omega) / 30, 0, 1);
      var copies = blur > 0.2 ? 3 : 1;
      for (var c = 0; c < copies; c++) {
        s.save();
        s.rotate(spin - c * 0.05 * Math.sign(omega));
        s.globalAlpha = alpha * (c === 0 ? 1 : 0.35);
        s.drawImage(tex, -half, -half);
        s.restore();
      }
      s.globalCompositeOperation = "screen";
      s.globalAlpha = alpha * (0.65 + Math.sin(time * 0.7) * 0.15);
      s.drawImage(discSheen, -half, -half);
      s.globalCompositeOperation = "source-over";
      if (cracked > 0) {
        s.rotate(spin);
        s.strokeStyle = "rgba(255,255,255," + (0.55 * cracked).toFixed(3) + ")";
        s.lineWidth = 1.1;
        for (var i = 0; i < crack.length; i++) {
          var pts = crack[i];
          s.beginPath(); s.moveTo(pts[0][0], pts[0][1]);
          for (var j = 1; j < pts.length; j++) s.lineTo(pts[j][0], pts[j][1]);
          s.stroke();
        }
      }
      s.restore();
    }

    /** Rudá tečka laseru, která hledá stopu. */
    function drawLaser(cx, cy, scale, time, lost) {
      var r = R * scale * (0.45 + 0.45 * (0.5 + 0.5 * Math.sin(time * (lost ? 17 : 2.2))));
      if (lost) r += rand(-1, 1) * R * scale * 0.2;
      var x = cx + r * 0.7, y = cy - r * 0.7;
      var g = s.createRadialGradient(x, y, 0, x, y, 9);
      g.addColorStop(0, "rgba(255,70,70,0.95)"); g.addColorStop(1, "rgba(255,0,0,0)");
      s.fillStyle = g; s.fillRect(x - 9, y - 9, 18, 18);
    }

    /* ------------------------------- Glitch ------------------------------- */

    /** Zkopíruje scénu na obrazovku — při glitchi rozloženou, roztrhanou a rozmazanou. */
    function present(g) {
      var sx = W / sw, sy = H / sh;
      ctx.imageSmoothingEnabled = true;
      if (g < 0.04) {
        ctx.drawImage(sc, 0, 0, W, H);
        return;
      }
      // RGB rozklad — tři obarvené kopie sečtené přes sebe.
      ctx.fillStyle = "#000"; ctx.fillRect(0, 0, W, H);
      ctx.globalCompositeOperation = "lighter";
      var spread = g * 7;
      for (var i = 0; i < 3; i++) {
        var T = tint[i];
        T.x.globalCompositeOperation = "copy"; T.x.drawImage(sc, 0, 0);
        T.x.globalCompositeOperation = "multiply"; T.x.fillStyle = T.color; T.x.fillRect(0, 0, sw, sh);
        var off = (i - 1) * spread;
        ctx.drawImage(T.c, off * sx, (i === 1 ? 0 : off * 0.3) * sy, W, H);
      }
      ctx.globalCompositeOperation = "source-over";

      // Vodorovné trhliny.
      var slices = Math.round(2 + g * 9);
      for (var k = 0; k < slices; k++) {
        var y = Math.random() * sh, h = rand(2, 4 + g * 26), dx = rand(-1, 1) * g * sw * 0.12;
        ctx.drawImage(sc, 0, y, sw, h, dx * sx, y * sy, W, h * sy);
      }
      // Rozmazané bloky z minulého snímku — datamosh.
      var blocks = Math.round(g * 10);
      for (var b = 0; b < blocks; b++) {
        var bw = rand(12, 70), bh = rand(8, 40), bx = Math.random() * (sw - bw), by = Math.random() * (sh - bh);
        ctx.drawImage(prev, bx, by, bw, bh, (bx + rand(-14, 14)) * sx, (by + rand(-6, 6)) * sy, bw * sx, bh * sy);
      }
    }

    /* ------------------------------- Písmo -------------------------------- */

    function font(weight, size, family) { return weight + " " + Math.round(size) + "px " + family; }

    /** Nastaví písmo tak, aby se text vešel do šířky. Vrací použitou velikost. */
    function fit(text, weight, size, family, maxW) {
      ctx.font = font(weight, size, family);
      var w = ctx.measureText(text).width;
      if (w > maxW) { size = Math.max(8, size * maxW / w); ctx.font = font(weight, size, family); }
      return size;
    }

    /** Text s barevným rozkladem. `g` = jak moc se rozjede. */
    function splitText(text, x, y, g, color) {
      var o = 1.2 + g * 7;
      ctx.globalCompositeOperation = "lighter";
      ctx.fillStyle = "rgba(255,30,60,0.8)"; ctx.fillText(text, x - o + rand(-1, 1) * g * 4, y);
      ctx.fillStyle = "rgba(30,220,255,0.75)"; ctx.fillText(text, x + o + rand(-1, 1) * g * 4, y + g * 1.5);
      ctx.globalCompositeOperation = "source-over";
      ctx.fillStyle = color; ctx.fillText(text, x, y);
    }

    /** Písmena se „dekódují“ zleva: zatím nerozluštěná jsou šum. */
    function decode(text, since, perChar) {
      var out = "";
      for (var i = 0; i < text.length; i++) {
        var ch = text[i];
        if (ch === " " || since > i * perChar + 0.12) out += ch;
        else if (since > i * perChar - 0.2) out += GARBLE[(Math.random() * GARBLE.length) | 0];
        else out += " ";
      }
      return out;
    }

    function roundRect(x, y, w, h, r) {
      ctx.beginPath();
      ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y); ctx.quadraticCurveTo(x + w, y, x + w, y + r);
      ctx.lineTo(x + w, y + h - r); ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
      ctx.lineTo(x + r, y + h); ctx.quadraticCurveTo(x, y + h, x, y + h - r);
      ctx.lineTo(x, y + r); ctx.quadraticCurveTo(x, y, x + r, y); ctx.closePath();
    }

    /* ------------------------------ Obrazovky ----------------------------- */

    function drawBootText(time) {
      var u = Math.min(W, H);
      var fade = smooth((time - 1.5) / 0.4);
      if (fade <= 0) return;
      var failing = time > T_FAIL;
      ctx.textAlign = "center"; ctx.textBaseline = "middle";
      ctx.font = font(500, clamp(u * 0.032, 11, 16), MONO);
      var dots = ".".repeat(1 + (Math.floor(time * 3) % 3));
      var line = "NAČÍTÁNÍ DISKU" + dots;
      if (failing) {
        var arr = line.split("");
        for (var i = 0; i < arr.length; i++) if (Math.random() < (time - T_FAIL) * 0.35) arr[i] = GARBLE[(Math.random() * GARBLE.length) | 0];
        line = arr.join("");
      }
      ctx.globalAlpha = fade * (failing ? 0.6 + Math.random() * 0.4 : 0.8);
      ctx.fillStyle = failing ? "#ff9aa8" : "#cfd9ff";
      ctx.fillText(line, W / 2 + (failing ? rand(-3, 3) : 0), H * 0.84);
      ctx.globalAlpha = 1;

      ctx.textAlign = "left";
      ctx.font = font(500, clamp(u * 0.024, 9, 12), MONO);
      ctx.globalAlpha = fade * 0.45;
      ctx.fillStyle = "#9fb3ff";
      ctx.fillText("UNDO SYSTEM  v2.26  ·  DVD-ROM", Math.max(16, W * 0.04), Math.max(22, H * 0.05));
      ctx.globalAlpha = 1;
    }

    function drawError(time, since) {
      var u = Math.min(W, H);
      var narrow = W < 560;
      var cx = W / 2;
      var y0 = H * (narrow ? 0.54 : 0.6);
      ctx.textAlign = "center"; ctx.textBaseline = "alphabetic";

      // Ztmavený pruh pod textem, ať se čte i přes rudé věže.
      var band = ctx.createLinearGradient(0, y0 - H * 0.2, 0, y0 + H * 0.32);
      band.addColorStop(0, "rgba(0,0,0,0)");
      band.addColorStop(0.3, "rgba(4,0,4,0.55)");
      band.addColorStop(0.75, "rgba(4,0,4,0.55)");
      band.addColorStop(1, "rgba(0,0,0,0)");
      ctx.globalAlpha = smooth(since / 0.4);
      ctx.fillStyle = band; ctx.fillRect(0, y0 - H * 0.2, W, H * 0.52);

      // Štítek s kódem chyby.
      var a1 = smooth(since / 0.25);
      ctx.globalAlpha = a1;
      ctx.font = font(600, clamp(u * 0.028, 10, 14), MONO);
      ctx.fillStyle = "#ff4d63";
      ctx.fillText("ERR 0x5B · E-101 · SEKTOR 0000", cx, y0 - clamp(u * 0.1, 44, 78));

      // Nadpis.
      var maxW = W - 40;
      var headSize = fit("DISK NELZE PŘEČÍST", 900, clamp(Math.min(W * (narrow ? 0.098 : 0.064), H * 0.075), 24, 68), SANS, maxW);
      var head = since < 1.2 ? decode("DISK NELZE PŘEČÍST", since - 0.15, 0.04) : "DISK NELZE PŘEČÍST";
      ctx.globalAlpha = smooth((since - 0.1) / 0.2);
      var jitterX = gl > 0.05 ? rand(-1, 1) * gl * 10 : 0;
      splitText(head, cx + jitterX, y0, clamp(gl + (since < 1 ? 0.4 : 0), 0, 1), "#f4f6ff");

      // Podtitul česky a anglicky.
      var a2 = smooth((since - 0.7) / 0.4);
      ctx.globalAlpha = a2;
      fit("Tahle hra běží jen na UNDO Games.", 500, clamp(u * 0.04, 14, 19), SANS, maxW);
      ctx.fillStyle = "#c9cfe6";
      ctx.fillText("Tahle hra běží jen na UNDO Games.", cx, y0 + headSize * 0.78);
      ctx.globalAlpha = a2 * 0.55;
      var en = narrow ? "DISC READ ERROR — play on UNDO Games" : "DISC READ ERROR — this game only runs on UNDO Games";
      fit(en, 500, clamp(u * 0.03, 11, 14), MONO, maxW);
      ctx.fillStyle = "#8f98bb";
      ctx.fillText(en, cx, y0 + headSize * 0.78 + clamp(u * 0.055, 20, 28));

      // Tlačítko do katalogu.
      var a3 = smooth((since - 1.0) / 0.45);
      if (a3 > 0) {
        var bs = clamp(u * 0.04, 14, 18);
        ctx.font = font(800, bs, SANS);
        var label = "▶  HRÁT NA UNDOGAMES.CZ";
        var tw = ctx.measureText(label).width;
        var bw = tw + bs * 2.6, bh = bs * 3.2;
        var by = y0 + headSize * 0.78 + clamp(u * 0.13, 52, 84);
        var bx = cx - bw / 2;
        var pulse = 0.5 + 0.5 * Math.sin(time * 2.4);
        ctx.globalAlpha = a3;
        ctx.shadowColor = "rgba(255,60,90," + (0.35 + pulse * 0.35 + (ctaHover ? 0.3 : 0)).toFixed(3) + ")";
        ctx.shadowBlur = 18 + pulse * 14;
        roundRect(bx, by, bw, bh, bh / 2);
        ctx.fillStyle = ctaHover ? "rgba(255,55,85,0.95)" : "rgba(20,6,14,0.72)";
        ctx.fill();
        ctx.shadowBlur = 0; ctx.shadowColor = "transparent";
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = "rgba(255,90,115," + (0.7 + pulse * 0.3).toFixed(3) + ")";
        ctx.stroke();
        ctx.fillStyle = ctaHover ? "#fff" : "#ffd9df";
        ctx.textBaseline = "middle";
        ctx.fillText(label, cx, by + bh / 2 + 1);
        ctx.textBaseline = "alphabetic";
        ctaBox = { x: bx, y: by, w: bw, h: bh };
      }

      // Hláška paměťové karty, psaná po znacích.
      if (time > memoryAt) {
        var text = MEMORY_LINES[memoryIndex % MEMORY_LINES.length];
        var shown = Math.floor((time - memoryAt) * 28);
        if (shown > text.length + 110) { memoryIndex += 1; memoryAt = time + rand(0.6, 1.4); }
        var cut = text.slice(0, Math.min(shown, text.length));
        var cursor = Math.floor(time * 2) % 2 === 0 ? "▌" : " ";
        ctx.globalAlpha = 0.5 * clamp((text.length + 110 - shown) / 20, 0, 1);
        fit(text + "▌", 500, clamp(u * 0.026, 10, 13), MONO, maxW);
        ctx.fillStyle = "#8d93b3";
        ctx.fillText(cut + cursor, cx, H - Math.max(26, H * 0.05));
      }
      ctx.globalAlpha = 1;
    }

    /** Podprahová zpráva — jen pár snímků, tlumená ruda, žádný bílý stroboskop. */
    function drawWhisper(text) {
      ctx.fillStyle = "#2a0006";
      ctx.fillRect(0, 0, W, H);
      ctx.textAlign = "center"; ctx.textBaseline = "middle";
      fit(text, 900, clamp(Math.min(W * 0.11, H * 0.1), 28, 110), SANS, W - 24);
      ctx.fillStyle = "#ff2a44";
      ctx.save();
      ctx.translate(W / 2, H / 2);
      ctx.scale(1, -1); // vzhůru nohama, ať to mozek přečte až potom
      ctx.fillText(text, 0, 0);
      ctx.restore();
      ctx.textBaseline = "alphabetic";
    }

    /* ------------------------------- Zvuk -------------------------------- */

    // Prohlížeč pustí zvuk až po doteku. Pak bzučí televizor a každý glitch
    // zachrastí — všechno syntetizované, žádné soubory.
    var audio = null;
    function wakeAudio() {
      if (audio || reduced) return;
      try {
        var AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) return;
        var ac = new AC();
        var out = ac.createGain(); out.gain.value = 0.5; out.connect(ac.destination);
        var hum = ac.createOscillator(), hum2 = ac.createOscillator(), hg = ac.createGain();
        hum.type = "sawtooth"; hum.frequency.value = 50; hum2.type = "sine"; hum2.frequency.value = 15734;
        var lp = ac.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 180;
        hg.gain.value = 0.018;
        hum.connect(lp); lp.connect(hg); hg.connect(out);
        // Pisklavý řádkový kmitočet starých televizí — skoro neslyšitelný.
        var whine = ac.createGain(); whine.gain.value = 0.0025;
        hum2.connect(whine); whine.connect(out);
        hum.start(); hum2.start();
        var len = ac.sampleRate * 0.4, buf = ac.createBuffer(1, len, ac.sampleRate), ch = buf.getChannelData(0);
        for (var i = 0; i < len; i++) ch[i] = Math.random() * 2 - 1;
        audio = { ac: ac, out: out, noise: buf };
      } catch (error) {
        audio = null;
      }
    }

    function crackle(strength) {
      if (!audio) return;
      var ac = audio.ac, now = ac.currentTime;
      var src = ac.createBufferSource(); src.buffer = audio.noise;
      var bp = ac.createBiquadFilter(); bp.type = "bandpass"; bp.frequency.value = rand(900, 3200); bp.Q.value = 0.8;
      var g = ac.createGain();
      var dur = 0.06 + strength * 0.22;
      g.gain.setValueAtTime(0.0001, now);
      g.gain.exponentialRampToValueAtTime(0.12 * strength + 0.02, now + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
      src.connect(bp); bp.connect(g); g.connect(audio.out);
      src.start(now, rand(0, 0.2), dur + 0.02);
      // Laser hledá stopu: krátké kliknutí s tupým dozvukem.
      var o = ac.createOscillator(), og = ac.createGain();
      o.frequency.setValueAtTime(rand(70, 140), now);
      o.frequency.exponentialRampToValueAtTime(40, now + 0.12);
      og.gain.setValueAtTime(0.08 * strength, now);
      og.gain.exponentialRampToValueAtTime(0.0001, now + 0.14);
      o.connect(og); og.connect(audio.out);
      o.start(now); o.stop(now + 0.16);
    }

    function burst(strength) {
      gl = Math.max(gl, strength);
      crackle(strength);
    }

    /* ------------------------------- Snímek ------------------------------- */

    function frame(now) {
      if (!running) return;
      var dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      t = (now - T0) / 1000;

      // Stav scény podle časové osy.
      var rot = 0, lum = 1, discAlpha = 0, discScale = 1, wob = 0, cracked = 0;
      var discX = sw / 2, discY = sh * 0.47;
      if (t < T_FAIL) {
        lum = smooth((t - T_ON) / 0.9);
        discAlpha = smooth((t - T_DISC) / 0.5);
        discScale = lerp(0.6, 1, outBack((t - T_DISC) / 0.8));
        // Roztočení.
        var target = t > T_DISC + 0.3 ? 34 : 0;
        omega += (target - omega) * Math.min(1, dt * 1.6);
        camZ += dt * 2.2;
      } else if (t < T_DARK) {
        var p = (t - T_FAIL) / (T_DARK - T_FAIL);
        rot = smooth(p * 1.3);
        lum = 1 - p * 0.35;
        discAlpha = 1; wob = p;
        cracked = smooth((p - 0.55) / 0.4);
        // Otáčky se lámou: cukne, zpomalí, zkusí to znovu.
        if (Math.random() < dt * 9) omega *= rand(0.15, 0.7);
        omega += (Math.random() < dt * 5 ? rand(10, 40) : 0);
        omega *= Math.pow(0.4, dt);
        discX += rand(-1, 1) * p * 3;
        camZ += dt * 2.2 * (1 - p);
        if (Math.random() < dt * (3 + p * 10)) burst(rand(0.35, 0.9));
        if (Math.random() < dt * 2.2 && now > frozenUntil) frozenUntil = now + rand(60, 240);
      } else {
        var e = t - T_ERR;
        rot = 1; lum = t < T_ERR ? 0 : 0.42 + 0.06 * Math.sin(t * 0.8);
        cracked = 1; discAlpha = t < T_ERR ? 0 : smooth(e / 0.6);
        var up = outBack(e / 0.9);
        discY = lerp(sh * 0.47, sh * (W < 560 ? 0.3 : 0.29), up);
        discScale = lerp(1, W < 560 ? 0.9 : 0.72, up);
        omega *= Math.pow(0.25, dt);
        camZ += dt * 0.35;
        if (!reduced) {
          if (t > nextBurst) { burst(rand(0.25, 0.8)); nextBurst = t + rand(3.5, 8); if (Math.random() < 0.4) frozenUntil = now + rand(80, 200); }
          if (t > nextTwitch) { omega = rand(14, 30) * (Math.random() < 0.2 ? -1 : 1); nextTwitch = t + rand(5, 9); crackle(0.3); }
          if (t > nextWhisper) {
            whisper = { text: WHISPERS[(Math.random() * WHISPERS.length) | 0], until: t + 0.075 };
            burst(0.9);
            nextWhisper = t + rand(16, 28);
          }
        }
      }
      spin += omega * dt;
      gl *= Math.pow(0.02, dt);

      // Scéna: v zamrzlém okamžiku se nepřekresluje — obraz se zadrhne.
      if (now >= frozenUntil) {
        pctx.globalCompositeOperation = "copy";
        pctx.drawImage(sc, 0, 0);
        drawTowers(t, rot, lum);
        drawDisc(discX, discY, discScale, discAlpha, wob, cracked, t);
        if (discAlpha > 0.5 && t > T_DISC + 0.5 && t < T_DARK) drawLaser(discX, discY, discScale, t, t > T_FAIL);
      }

      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "source-over";

      if (t >= T_DARK && t < T_ERR) {
        // Tma. Uprostřed jedno podprahové probliknutí.
        ctx.fillStyle = "#000"; ctx.fillRect(0, 0, W, H);
        if (!reduced && t > T_DARK + 0.12 && t < T_DARK + 0.19) drawWhisper("NEMĚL BYS TU BÝT");
      } else if (whisper && t < whisper.until) {
        drawWhisper(whisper.text);
      } else {
        present(gl);

        if (t < T_ON) {
          // Televizor naskakuje: bod → čára → obraz.
          var k = t / T_ON;
          var lineW = W * smooth(k * 2);
          var lineH = k < 0.5 ? 2 : lerp(2, H, smooth((k - 0.5) * 2));
          ctx.fillStyle = "#000";
          ctx.fillRect(0, 0, W, (H - lineH) / 2);
          ctx.fillRect(0, (H + lineH) / 2, W, H);
          ctx.fillRect(0, 0, (W - lineW) / 2, H);
          ctx.fillRect((W + lineW) / 2, 0, W, H);
          ctx.globalAlpha = 1 - smooth((k - 0.4) / 0.6);
          ctx.fillStyle = "#e6edff";
          ctx.fillRect((W - lineW) / 2, (H - lineH) / 2, lineW, lineH);
          ctx.globalAlpha = 1;
        }

        if (t < T_DARK) drawBootText(t);
        else drawError(t, t - T_ERR);
      }

      // Rastr, šum a vinětace přes všechno.
      ctx.fillStyle = scan;
      ctx.save(); ctx.translate(0, (t * 18) % 3); ctx.fillRect(0, -3, W, H + 6); ctx.restore();
      ctx.save();
      ctx.globalAlpha = 0.05 + gl * 0.18;
      ctx.globalCompositeOperation = "overlay";
      ctx.fillStyle = noise[(Math.random() * noise.length) | 0];
      ctx.translate(rand(-80, 0), rand(-80, 0));
      ctx.fillRect(0, 0, W + 80, H + 80);
      ctx.restore();
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.drawImage(vignette, 0, 0);

      if (!reduced) requestAnimationFrame(frame);
    }

    /* ------------------------------ Ovládání ------------------------------ */

    function inCta(x, y) {
      if (!ctaBox) return false;
      var pad = 8;
      return x >= ctaBox.x - pad && x <= ctaBox.x + ctaBox.w + pad && y >= ctaBox.y - pad && y <= ctaBox.y + ctaBox.h + pad;
    }
    function go() { location.href = CATALOG_URL; }
    cv.addEventListener("pointermove", function (event) {
      var hover = inCta(event.clientX, event.clientY);
      if (hover !== ctaHover) { ctaHover = hover; if (reduced) frame(performance.now()); }
      cv.style.cursor = hover ? "pointer" : "default";
    });
    cv.addEventListener("pointerdown", function (event) {
      wakeAudio();
      if (inCta(event.clientX, event.clientY)) return;
      // Ťuknutí do obrazu ho rozhodí — a chvíli nechce poslouchat.
      if (!reduced && t > T_ERR) { burst(rand(0.6, 1)); frozenUntil = performance.now() + rand(60, 160); }
    });
    cv.addEventListener("click", function (event) {
      if (inCta(event.clientX, event.clientY)) go();
    });
    // Klávesnice a odečítače obrazovky se ke katalogu dostanou taky.
    cv.tabIndex = 0;
    cv.addEventListener("keydown", function (event) {
      if (event.key === "Enter" || event.key === " ") { event.preventDefault(); go(); }
    });
    // Skrytá karta nemá důvod kreslit ani bzučet.
    document.addEventListener("visibilitychange", function () {
      if (document.hidden) {
        running = false;
        if (audio) audio.ac.suspend();
      } else if (!running) {
        running = true;
        if (audio) audio.ac.resume();
        last = performance.now();
        requestAnimationFrame(frame);
      }
    });
    window.addEventListener("resize", function () {
      if (reduced) requestAnimationFrame(frame);
    });

    requestAnimationFrame(frame);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
