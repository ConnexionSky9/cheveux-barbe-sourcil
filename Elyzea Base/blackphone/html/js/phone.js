/* =====================================================================
   BLACKPHONE - cœur de l'interface
   Démarrage, écran verrouillé, accueil, navigation, barre d'état, batterie visuelle, sons.
   Les applications s'enregistrent avec BPPhone.registerApp({ id, name, icon, order, render(el, api) })
   dans html/js/apps/*.js (un fichier par application, ajouté dans index.html et fxmanifest).
   ===================================================================== */
(() => {
  const B = window.BPBrand;
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'blackphone';
  const $ = (s) => document.querySelector(s);
  const post = (name, body = {}) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).catch(() => {});

  const PREF_KEY = 'blackphone.prefs';
  const defaults = { wallpaper: 'noir', sounds: true, volume: 35, brightness: 100, battery: 100, battAt: Date.now() };
  let prefs = { ...defaults };
  try { prefs = { ...defaults, ...JSON.parse(localStorage.getItem(PREF_KEY) || '{}') }; } catch (e) { /* stockage indisponible */ }
  const save = () => { try { localStorage.setItem(PREF_KEY, JSON.stringify(prefs)); } catch (e) { /* ignoré */ } };

  const S = { open: false, booted: false, screen: 'lock', app: null, time: { h: 0, m: 0 }, serial: '', serverSounds: true };
  const apps = [];

  // ---------------- Sons discrets (synthétisés, aucun fichier) ----------------
  let ctx = null;
  function tick(freq = 1800, dur = 0.035) {
    if (!prefs.sounds || !S.serverSounds || prefs.volume <= 0) return;
    try {
      ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
      const o = ctx.createOscillator(); const g = ctx.createGain();
      o.type = 'sine'; o.frequency.value = freq;
      g.gain.setValueAtTime((prefs.volume / 100) * 0.08, ctx.currentTime);
      g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + dur);
      o.connect(g); g.connect(ctx.destination); o.start(); o.stop(ctx.currentTime + dur);
    } catch (e) { /* audio indisponible */ }
  }

  // ---------------- Barre d'état ----------------
  const pad = (n) => String(n).padStart(2, '0');
  const timeStr = () => `${pad(S.time.h)}:${pad(S.time.m)}`;
  const dateStr = () => new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
  function battery() {
    // batterie visuelle : -1 % toutes les 2 min allumé, +1 % par minute éteint
    const now = Date.now(); const mins = (now - prefs.battAt) / 60000;
    prefs.battery = Math.max(1, Math.min(100, prefs.battery + (S.open ? -mins / 2 : mins)));
    prefs.battAt = now; save();
    const v = Math.round(prefs.battery);
    $('#battFill').style.width = `${v}%`;
    $('#battPct').textContent = v;
    document.querySelector('.batt').classList.toggle('low', v <= 15);
  }
  function status() {
    $('#stTime').textContent = timeStr();
    $('#stSignal').innerHTML = `<svg width="16" height="11" viewBox="0 0 16 11" fill="#e8e8ec"><rect x="0" y="8" width="3" height="3" rx=".5"/><rect x="4.3" y="5.5" width="3" height="5.5" rx=".5"/><rect x="8.6" y="3" width="3" height="8" rx=".5"/><rect x="12.9" y="0" width="3" height="11" rx=".5" opacity=".35"/></svg>`;
    battery();
    const ck = document.querySelector('[data-clock]'); if (ck) ck.textContent = timeStr();
  }
  function applyPrefs() { $('#dim').style.opacity = String((100 - prefs.brightness) / 140); }

  const wallpaper = () => `<div class="wp wp-${prefs.wallpaper}"><svg class="ghost" viewBox="-4 -4 76 112">${B.mark({ color: '#fff', accent: '#fff' })}</svg></div>`;

  // ---------------- Écrans ----------------
  function boot(done) {
    const l = B.word('BLACKPHONE', { color: '#ececee' });
    $('#view').innerHTML = `<div class="boot"><svg class="mk" viewBox="-4 -4 76 112">${B.mark({ color: '#ececee', accent: '#b3161b' })}</svg>
      <svg class="wm" viewBox="-2 -2 ${l.width + 4} 18">${l.svg}</svg><div class="bar"><i></i></div></div>`;
    tick(900, 0.12);
    setTimeout(done, 2300);
  }
  function lock() {
    S.screen = 'lock'; S.app = null;
    $('#view').innerHTML = `${wallpaper()}<div class="lock" id="lock"><div class="clk" data-clock>${timeStr()}</div><div class="date">${dateStr()}</div>
      <div class="lk">${B.icon('lock', 20)}<span>TOUCHER POUR DÉVERROUILLER</span></div></div>`;
    $('#lock').onclick = () => { tick(); $('#lock').classList.add('out'); setTimeout(home, 260); };
  }
  function home() {
    S.screen = 'home'; S.app = null;
    const list = apps.slice().sort((a, b) => (a.order || 99) - (b.order || 99));
    $('#view').innerHTML = `${wallpaper()}<div class="home"><div class="widget"><div class="t" data-clock>${timeStr()}</div><div class="d">${dateStr()}</div>
        <div class="net"><i></i>BLACKPHONE · ${S.serial ? S.serial.slice(-6) : '------'}</div></div>
      <div class="grid">${list.map((a) => `<div class="app" data-app="${a.id}"><div class="ic">${a.icon}</div><span>${a.name}</span></div>`).join('')}</div>
      <p class="empty-note">De nouvelles applications arriveront<br>avec les prochaines mises à jour.</p></div>`;
    document.querySelectorAll('[data-app]').forEach((n) => { n.onclick = () => openApp(n.dataset.app); });
  }
  function openApp(id) {
    const a = apps.find((x) => x.id === id);
    if (!a) return;
    tick(); S.screen = 'app'; S.app = id;
    $('#view').innerHTML = `<div class="appv"><div class="apph"><button data-back>${B.icon('back', 22)}</button><h1>${a.name}</h1></div><div class="appb" id="appb"></div></div>`;
    $('[data-back]').onclick = () => { tick(1400); home(); };
    a.render($('#appb'), api);
  }

  // API donnée aux applications
  const api = { prefs, save: () => { save(); applyPrefs(); }, tick, icon: B.icon, brand: B, serial: () => S.serial, home, post, wallpaperClass: () => prefs.wallpaper };

  // ---------------- Ouverture / fermeture ----------------
  function open(m) {
    S.open = true; S.serial = m.serial || S.serial; S.time = m.time || S.time; S.serverSounds = m.sounds !== false;
    $('#phone').classList.remove('hidden');
    requestAnimationFrame(() => $('#phone').classList.add('shown'));
    applyPrefs(); status();
    if (!S.booted) { S.booted = true; boot(lock); } else lock();
  }
  function close(notify) {
    if (!S.open) return;
    S.open = false; battery();
    $('#phone').classList.remove('shown');
    setTimeout(() => { if (!S.open) $('#phone').classList.add('hidden'); }, 380);
    if (notify) post('close');
  }

  $('#homebar').onclick = () => { if (S.screen !== 'lock') { tick(1400); home(); } };
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && S.open) close(true); });

  window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    if (m.action === 'open') open(m);
    else if (m.action === 'close') close(false);
    else if (m.action === 'time') { S.time = m.time || S.time; if (S.open) status(); }
  });

  window.BPPhone = { registerApp: (def) => { if (def && def.id && !apps.find((a) => a.id === def.id)) apps.push(def); }, openApp, home, api };
})();
