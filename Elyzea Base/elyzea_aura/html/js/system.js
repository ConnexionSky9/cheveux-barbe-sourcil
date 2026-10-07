'use strict';
/* =========================================================
   SYSTÈME — accueil, navigation, sécurité, intro, AuraDrop
   ========================================================= */
const APPS = {
  phone:     { label: 'Téléphone' },
  messages:  { label: 'Messages' },
  store:     { label: 'Appli' },
  camera:    { label: 'Photo' },
  contacts:  { label: 'Contacts' },
  bank:      { label: 'Banque' },
  gallery:   { label: 'Galerie' },
  notes:     { label: 'Notes' },
  ads:       { label: 'Annonces' },
  maps:      { label: 'Plans' },
  alert:     { label: 'Urgences' },
  calc:      { label: 'Calcul' },
  settings:  { label: 'Réglages' },
  birdy:     { label: 'Birdy', store: true },
  instapick: { label: 'InstaPick', store: true },
  itoune:    { label: 'Itoune', store: true },
  etincelle: { label: 'Étincelle', store: true },
  livrezy:   { label: 'Livrézy', store: true },
  helpmecano:{ label: 'HelpMécano', store: true },
  garage:    { label: 'Garage', store: true },
  carplay:   { label: 'CarPlay', store: true },
};
const DOCK = ['phone', 'messages', 'store', 'camera'];
const GRID = ['contacts', 'bank', 'gallery', 'notes', 'ads', 'maps', 'alert', 'calc', 'settings'];
const Views = {};
const homeEl = $('#home');

const installed = () => Array.isArray(S.settings.installed) ? S.settings.installed : [];
const isInstalled = (id) => installed().includes(id);
const bankOn = () => S.profile?.bankEnabled && S.profile?.bank != null;

// ---------------------------------------------------------
//  Accueil
// ---------------------------------------------------------
// Nombre d'applications par page : la page d'accueil garde l'horloge et les widgets
const FIRST_PAGE_APPS = 8;
const PAGE_APPS = 20;

function renderHome() {
  const s = S.settings;
  const cs = ['stack', 'line', 'minimal'].includes(s.clockStyle) ? s.clockStyle : 'stack';
  const digits = cs === 'stack' ? '<span id="clock-h">00</span><span id="clock-m">00</span>' : '<span id="clock-hm">00:00</span>';
  const tile = (id) => {
    const badge = id === 'messages' && S.unread > 0 ? `<span class="badge">${S.unread}</span>`
      : id === 'bank' && S.bankPending > 0 ? `<span class="badge">${S.bankPending}</span>` : '';
    return `<button class="app-icon ${S.freshApp === id ? 'fresh' : ''}" data-open="${id}" aria-label="${t(APPS[id].label)}">${appTile(id, badge)}<span>${t(APPS[id].label)}</span></button>`;
  };
  const apps = GRID.filter(id => id !== 'bank' || bankOn()).concat(Object.keys(STORE).filter(isInstalled));
  // Découpage en pages : accueil (horloge + widgets + 8 apps), puis 20 apps par page
  const pages = [apps.slice(0, FIRST_PAGE_APPS)];
  for (let i = FIRST_PAGE_APPS; i < apps.length; i += PAGE_APPS) pages.push(apps.slice(i, i + PAGE_APPS));
  // Une app qui vient d'être installée : on ouvre directement sa page
  if (S.freshApp) { const p = pages.findIndex(pg => pg.includes(S.freshApp)); if (p >= 0) S.homePage = p; }
  S.homePage = Math.min(S.homePage || 0, pages.length - 1);
  const showBank = bankOn() && s.showBankWidget !== false;
  homeEl.innerHTML = `
    <div class="pager" id="pager"><div class="pager__track" id="pager-track">
      <section class="page page--main" aria-label="${t('Accueil')}">
        <div class="clock clock--${cs}">
          <div class="clock__digits">${digits}</div>
          <div class="clock__meta"><p class="clock__date" id="clock-date"></p><p class="clock__greet" id="greeting"></p></div>
        </div>
        <div class="widgets ${showBank ? '' : 'single'}">
          ${showBank ? `<button class="widget" data-open="bank"><span class="widget__label">${t('Compte courant')}</span>
            <span class="widget__value" id="widget-balance">${money(S.profile.bank)}</span><span class="widget__sub">Elyzea Banque</span></button>` : ''}
          <button class="widget widget--num" id="widget-number"><span class="widget__label">${t('Mon numéro')}</span>
            <span class="widget__value">${esc(S.profile?.number || '')}</span>
            ${S.profile?.auraDrop ? `<span class="drop-mini">${icon('drop')}AuraDrop</span>` : ''}</button>
        </div>
        <div class="app-grid">${pages[0].map(tile).join('')}</div>
      </section>
      ${pages.slice(1).map((pg, i) => `<section class="page" aria-label="${t('Page {n}', { n: i + 2 })}"><div class="app-grid app-grid--full">${pg.map(tile).join('')}</div></section>`).join('')}
    </div></div>
    ${pages.length > 1 ? `<div class="pager__dots" role="tablist">${pages.map((_, i) => `<button data-page-dot="${i}" class="${i === S.homePage ? 'active' : ''}" aria-label="${t('Page {n}', { n: i + 1 })}"></button>`).join('')}</div>` : ''}
    <nav class="dock">${DOCK.map(tile).join('')}</nav>`;
  S.freshApp = null;
  $('#widget-number').onclick = () => { if (S.dragged) return; S.profile?.auraDrop ? openAuraDrop() : (copyText(S.profile.number), notify({ app: 'contacts', title: t('Numéro copié'), text: S.profile.number })); };
  setupPager(pages.length);
  updateClock();
}

// Défilement des pages : glisser à la souris, molette, ou points de navigation
function setupPager(count) {
  const pager = $('#pager'), track = $('#pager-track');
  if (!pager || !track) return;
  const go = (i, animate = true) => {
    S.homePage = Math.max(0, Math.min(count - 1, i));
    track.style.transition = animate ? '' : 'none';
    track.style.transform = `translateX(${-S.homePage * 100}%)`;
    $$('[data-page-dot]', homeEl).forEach((d, k) => d.classList.toggle('active', k === S.homePage));
  };
  go(S.homePage, false);
  $$('[data-page-dot]', homeEl).forEach(d => d.onclick = () => go(+d.dataset.pageDot));
  if (count < 2) return;

  let startX = 0, startY = 0, dx = 0, dragging = false, pointerId = null;
  pager.onpointerdown = (e) => {
    if (e.button !== 0) return;
    startX = e.clientX; startY = e.clientY; dx = 0; dragging = true; pointerId = e.pointerId; S.dragged = false;
  };
  pager.onpointermove = (e) => {
    if (!dragging || e.pointerId !== pointerId) return;
    dx = e.clientX - startX;
    if (!S.dragged && Math.abs(dx) > 8 && Math.abs(dx) > Math.abs(e.clientY - startY)) {
      S.dragged = true;
      pager.setPointerCapture(pointerId);
    }
    if (!S.dragged) return;
    const w = pager.clientWidth;
    // résistance aux extrémités
    const edge = (S.homePage === 0 && dx > 0) || (S.homePage === count - 1 && dx < 0);
    track.style.transition = 'none';
    track.style.transform = `translateX(calc(${-S.homePage * 100}% + ${edge ? dx / 3 : dx}px))`;
    void w;
  };
  const end = () => {
    if (!dragging) return;
    dragging = false;
    if (S.dragged) {
      const w = pager.clientWidth;
      if (dx < -w * 0.18) go(S.homePage + 1); else if (dx > w * 0.18) go(S.homePage - 1); else go(S.homePage);
      setTimeout(() => { S.dragged = false; }, 60); // empêche d'ouvrir l'app sur laquelle on a relâché
    }
  };
  pager.onpointerup = end;
  pager.onpointercancel = end;
  let wheelLock = 0;
  pager.onwheel = (e) => {
    const d = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY;
    if (Math.abs(d) < 20 || Date.now() < wheelLock) return;
    wheelLock = Date.now() + 450;
    go(S.homePage + (d > 0 ? 1 : -1));
  };
}

function updateClock() {
  const now = new Date();
  const h = S.gameTime ? S.gameTime.h : now.getHours();
  const m = S.gameTime ? S.gameTime.m : now.getMinutes();
  const set = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
  set('clock-h', pad(h)); set('clock-m', pad(m)); set('clock-hm', `${pad(h)}:${pad(m)}`);
  set('sb-time', `${pad(h)}:${pad(m)}`); set('lock-time', `${pad(h)}:${pad(m)}`);
  const date = now.toLocaleDateString(locale(), { weekday: 'long', day: 'numeric', month: 'long' });
  set('clock-date', date); set('lock-date', date);
  const first = (S.profile?.name || '').split(' ')[0];
  const g = h < 5 ? t('Bonne nuit') : h < 12 ? t('Bonjour') : h < 18 ? t('Bon après-midi') : t('Bonsoir');
  set('greeting', first ? `${g}, ${first}` : g);
  if (S.settings.theme === 'auto' && screenEl.dataset.theme !== resolvedTheme()) applySettings();
}
setInterval(() => { if (!S.gameTime) updateClock(); }, 2000); // heure réelle : mise à jour régulière

// ---------------------------------------------------------
//  Navigation
// ---------------------------------------------------------
function leaveApp() {
  if (S.onLeave) { const f = S.onLeave; S.onLeave = null; f(); }
}
function openApp(id, params = {}, push = true) {
  if (S.locked) return;
  if (APPS[id]?.store && !isInstalled(id)) { params = { detail: id }; id = 'store'; }
  if (!Views[id]) return;
  leaveApp();
  if (push) S.stack.push({ id, params });
  S.currentApp = id;
  screenEl.classList.add('in-app');
  appView.classList.add('active');
  appView.setAttribute('aria-hidden', 'false');
  closeSheet(true);
  Views[id](params);
}
function back() {
  if (closeSheet()) return;
  leaveApp();
  S.stack.pop();
  const prev = S.stack[S.stack.length - 1];
  if (prev) openApp(prev.id, prev.params, false); else goHome();
}
function goHome() {
  closeSheet();
  if (S.locked || screenEl.classList.contains('in-setup')) return;
  if (S.call && callView.classList.contains('active')) { minimizeCall(); return; }
  leaveApp();
  S.stack = []; S.currentApp = null; S.thread = null;
  screenEl.classList.remove('in-app');
  appView.classList.remove('active');
  appView.setAttribute('aria-hidden', 'true');
  renderHome();
}
function refreshCurrent() {
  const cur = S.stack[S.stack.length - 1];
  if (cur) openApp(cur.id, cur.params, false);
}
function setParams(params) { const cur = S.stack[S.stack.length - 1]; if (cur) cur.params = params; }

// ---------------------------------------------------------
//  Verrouillage, code et Face ID
// ---------------------------------------------------------
const FACE_SVG = `<svg viewBox="0 0 120 120" aria-hidden="true">
  <path class="corners" d="M14 38V24a10 10 0 0 1 10-10h14M82 14h14a10 10 0 0 1 10 10v14M106 82v14a10 10 0 0 1-10 10H82M38 106H24a10 10 0 0 1-10-10V82" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round"/>
  <g class="face" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><path d="M44 46v6M76 46v6M60 46v17h-5M46 76c8 6 20 6 28 0"/></g>
  <path class="check" d="M40 61l13 13 27-28" fill="none" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const faceEl = (state = '') => `<div class="faceid ${state}">${FACE_SVG}<span class="scan"></span></div>`;

function showLock() {
  S.locked = true;
  screenEl.classList.add('locked');
  lockView.classList.add('active'); lockView.setAttribute('aria-hidden', 'false');
  $('#sb-lock').classList.remove('hidden');
  closeSheet(true);
  renderLock();
}
function renderLock() {
  const face = S.settings.faceid;
  lockView.innerHTML = `<div class="lock">
    <p class="lock__date" id="lock-date"></p>
    <p class="lock__time" id="lock-time">00:00</p>
    <div class="lock__notifs">${S.lockNotifs.map(n => `<div class="lock__notif"><div class="island__icon">${solidTile(n.app, 34)}</div>
      <div class="island__text"><div class="island__title">${esc(n.title)}</div><div class="island__body">${esc(n.text)}</div></div></div>`).join('')}</div>
    <div class="lock__bottom">
      <button class="lock__face" id="lock-btn" aria-label="${face ? t('Déverrouiller avec Face ID') : t('Saisir le code')}">${icon(face ? 'face' : 'lock')}</button>
      <p class="lock__hint">${face ? t('Touchez pour utiliser Face ID') : t('Touchez pour saisir le code')}</p>
    </div></div>`;
  updateClock();
  $('#lock-btn').onclick = () => face ? runFaceUnlock() : askUnlockCode();
}
function runFaceUnlock() {
  const bottom = $('.lock__bottom', lockView);
  bottom.innerHTML = `${faceEl()}<p class="lock__hint">${t('Recherche du visage…')}</p>
    <button class="link-btn" id="use-code">${t('Utiliser le code')}</button>`;
  $('#use-code').onclick = askUnlockCode;
  setTimeout(() => {
    const f = $('.faceid', lockView); if (!f) return;
    f.classList.add('ok'); $('.lock__hint', lockView).textContent = t('Visage reconnu');
    setTimeout(unlockSuccess, 550);
  }, 1250);
}
function askUnlockCode() {
  passcodePad({
    title: t('Saisissez votre code'), length: S.profile.passcode.length || 4, root: lockView,
    allowFace: S.settings.faceid,
    onComplete: async (code) => {
      const r = await api('unlock', { code });
      if (r.ok) { unlockSuccess(); return true; }
      return { error: r.wait ? t('Trop d\'essais. Réessayez dans {s} s.', { s: r.wait }) : t('Code incorrect') };
    },
    onCancel: renderLock,
    onFace: () => { renderLock(); runFaceUnlock(); },
  });
}
function unlockSuccess() {
  S.locked = false; S.lockNotifs = [];
  Sound.unlock();
  $('#sb-lock').classList.add('hidden');
  lockView.classList.remove('active'); lockView.setAttribute('aria-hidden', 'true');
  screenEl.classList.remove('locked');
  setTimeout(() => { lockView.innerHTML = ''; }, 400);
  if (S.currentApp) refreshCurrent(); else renderHome();
  if (S.pendingDrops.length) setTimeout(() => showDropPrompt(S.pendingDrops[0]), 500);
}

// Clavier de code réutilisable (déverrouillage, création, modification)
function passcodePad({ title, sub = '', length = 4, root = screenEl, onComplete, onCancel, allowFace = false, onFace }) {
  $('.passcode', root)?.remove();
  const el = document.createElement('div');
  el.className = 'passcode';
  el.innerHTML = `<p class="passcode__title">${title}</p><p class="passcode__sub">${sub}</p>
    <div class="dots">${'<i></i>'.repeat(length)}</div>
    <div class="pad">${[1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => `<button data-n="${n}">${n}</button>`).join('')}
      ${allowFace ? `<button class="pad-ghost" data-face aria-label="Face ID">${icon('face')}</button>` : '<span></span>'}
      <button data-n="0">0</button>
      <button class="pad-ghost" data-del>${t('Effacer')}</button></div>
    <button class="link-btn" data-cancel style="margin-top:14px">${t('Annuler')}</button>`;
  root.appendChild(el);
  let code = '', busy = false;
  const dots = $$('.dots i', el);
  const draw = () => dots.forEach((d, i) => d.classList.toggle('on', i < code.length));
  const setSub = (txt) => { $('.passcode__sub', el).textContent = txt; };
  $$('[data-n]', el).forEach(b => b.onclick = async () => {
    if (busy || code.length >= length) return;
    code += b.dataset.n; draw(); Sound.tap(b.dataset.n);
    if (code.length === length) {
      busy = true;
      const res = await onComplete(code, { setSub, reset: () => { code = ''; draw(); } });
      if (res === true) { el.remove(); return; }
      if (res && res.error) {
        Sound.error();
        const d = $('.dots', el); d.classList.add('shake'); setSub(res.error);
        setTimeout(() => { d.classList.remove('shake'); code = ''; draw(); busy = false; }, 450);
      } else { code = ''; draw(); busy = false; }
    }
  });
  $('[data-del]', el).onclick = () => { code = code.slice(0, -1); draw(); };
  $('[data-cancel]', el).onclick = () => { el.remove(); onCancel?.(); };
  $('[data-face]', el)?.addEventListener('click', () => { el.remove(); onFace?.(); });
  return el;
}

// Création d'un code (saisie + confirmation)
function createPasscode(length, root, done, cancel, old) {
  passcodePad({
    title: t('Choisissez un code à {n} chiffres', { n: length }), length, root,
    onCancel: cancel,
    onComplete: (first) => {
      passcodePad({
        title: t('Confirmez votre code'), length, root, onCancel: cancel,
        onComplete: async (second) => {
          if (second !== first) return { error: t('Les codes ne correspondent pas') };
          const r = await api('setPasscode', { code: second, old });
          if (!r.ok) return { error: t(r.error || 'Code incorrect') };
          S.profile.passcode = { set: true, length };
          done(); return true;
        }
      });
      return true;
    }
  });
}

// ---------------------------------------------------------
//  Premier démarrage : intro + configuration
// ---------------------------------------------------------
const W = { step: 0, steps: [] };
const LANGS = [['fr', 'Français', 'FR'], ['en', 'English', 'EN'], ['es', 'Español', 'ES']];

function startSetup() {
  screenEl.classList.add('in-setup');
  setupView.classList.add('active'); setupView.setAttribute('aria-hidden', 'false');
  setupView.innerHTML = `<div class="boot" id="boot">
    <svg class="boot__mark" viewBox="0 0 128 128" aria-hidden="true">
      <circle class="r1" cx="64" cy="64" r="46"/><circle class="r2" cx="64" cy="64" r="34" transform="rotate(120 64 64)"/>
      <circle class="r3" cx="64" cy="64" r="22" transform="rotate(240 64 64)"/><circle class="core" cx="64" cy="64" r="6"/></svg>
    <p class="boot__word">Elyzea <b>Aura 5</b></p>
    <p class="boot__hello" id="boot-hello"></p></div>
    <div class="wizard" id="wizard"></div>`;
  Sound.boot();
  const hellos = ['Bonjour', 'Hello', 'Hola'];
  let i = 0;
  const hello = $('#boot-hello');
  const cycle = setInterval(() => {
    hello.classList.remove('show');
    setTimeout(() => { hello.textContent = hellos[i++ % hellos.length]; hello.classList.add('show'); }, 250);
  }, 1100);
  setTimeout(() => { hello.textContent = hellos[i++]; hello.classList.add('show'); }, 1900);
  setTimeout(() => { clearInterval(cycle); $('#boot').classList.add('done'); W.step = 0; renderWizard(); }, 5200);
}

function wizardSteps() {
  const steps = ['lang', 'theme', 'code'];
  if (hasSecurity()) steps.push('faceid');
  steps.push('style', 'done');
  return steps;
}
function renderWizard() {
  W.steps = wizardSteps();
  const step = W.steps[W.step];
  const wiz = $('#wizard');
  const progress = `<div class="wizard__progress" aria-hidden="true">${W.steps.map((_, i) => `<i class="${i <= W.step ? 'done' : ''}"></i>`).join('')}</div>`;
  const next = () => { W.step = Math.min(W.step + 1, W.steps.length - 1); renderWizard(); };
  const view = (title, text, body, foot) => {
    wiz.innerHTML = `${progress}<div class="wizard__step"><h2 class="wizard__title">${title}</h2><p class="wizard__text">${text}</p>
      <div class="wizard__body">${body}</div><div class="wizard__foot">${foot}</div></div>`;
  };
  const check = `<span class="choice__check">${icon('check')}</span>`;

  if (step === 'lang') {
    view(t('Choisissez votre langue'), t('Vous pourrez la changer à tout moment dans Réglages.'),
      LANGS.map(([k, l, f]) => `<button class="choice ${S.settings.lang === k ? 'active' : ''}" data-lang="${k}"><span class="choice__flag">${f}</span><span class="choice__label">${l}</span>${check}</button>`).join(''),
      `<button class="btn btn--block" data-next>${t('Continuer')}</button>`);
    $$('[data-lang]', wiz).forEach(b => b.onclick = () => { S.settings.lang = b.dataset.lang; applySettings(); renderWizard(); });
  }
  if (step === 'theme') {
    const card = (k, l, cls) => `<button class="theme-card ${S.settings.theme === k ? 'active' : ''}" data-theme-pick="${k}">
      <span class="theme-card__phone ${cls}"><i style="width:40%"></i><i style="width:65%"></i><b></b><span class="mini-grid">${'<span></span>'.repeat(8)}</span></span>${l}</button>`;
    view(t('Sombre ou clair ?'), t('Le mode Auto passe au clair le jour et au sombre la nuit, selon l\'heure en ville.'),
      `<div class="theme-cards">${card('dark', t('Sombre'), 'tc-dark')}${card('light', t('Clair'), 'tc-light')}${card('auto', t('Auto'), 'tc-auto')}</div>`,
      `<button class="btn btn--block" data-next>${t('Continuer')}</button>`);
    $$('[data-theme-pick]', wiz).forEach(b => b.onclick = () => { S.settings.theme = b.dataset.themePick; applySettings(); renderWizard(); });
  }
  if (step === 'code') {
    if (hasSecurity()) {
      view(t('Code créé'), t('Votre téléphone demandera ce code à chaque ouverture.'),
        `<div class="setup-illus">${faceEl('ok')}</div>`, `<button class="btn btn--block" data-next>${t('Continuer')}</button>`);
    } else {
      view(t('Protégez votre téléphone'), t('Un code empêche les autres de lire vos messages ou d\'utiliser votre banque.'),
        `<div class="setup-illus"><div class="radar__me" style="width:96px;height:96px">${icon('lock')}</div></div>
         <button class="choice" data-len="4"><span class="choice__flag">4</span><span class="choice__label">${t('Code à 4 chiffres')}</span></button>
         <button class="choice" data-len="6"><span class="choice__flag">6</span><span class="choice__label">${t('Code à 6 chiffres')}</span></button>`,
        `<button class="link-btn" data-skip>${t('Plus tard')}</button>`);
      $$('[data-len]', wiz).forEach(b => b.onclick = () => createPasscode(+b.dataset.len, setupView, () => renderWizard(), () => {}));
      $('[data-skip]', wiz).onclick = () => { W.step = W.steps.indexOf('style'); renderWizard(); };
    }
  }
  if (step === 'faceid') {
    view(t('Activer Face ID ?'), t('Déverrouillez votre téléphone d\'un regard. Le code reste disponible en secours.'),
      `<div class="setup-illus">${faceEl('idle')}</div><p class="wizard__text" id="face-status" style="text-align:center;margin:0 auto">&nbsp;</p>`,
      `<button class="btn btn--block" id="face-go">${t('Configurer Face ID')}</button><button class="link-btn" data-skip>${t('Plus tard')}</button>`);
    $('[data-skip]', wiz).onclick = () => { S.settings.faceid = false; next(); };
    $('#face-go').onclick = (e) => {
      e.currentTarget.disabled = true;
      const f = $('.faceid', wiz); f.classList.remove('idle');
      $('#face-status').textContent = t('Bougez lentement la tête en cercle');
      setTimeout(() => { $('#face-status').textContent = t('Encore un peu…'); }, 1100);
      setTimeout(() => {
        f.classList.add('ok'); $('#face-status').textContent = t('Face ID est configuré');
        S.settings.faceid = true; Sound.unlock();
        setTimeout(next, 900);
      }, 2300);
    };
  }
  if (step === 'style') {
    view(t('Votre style'), t('Choisissez un fond d\'écran et une couleur. Tout le reste se règle dans Réglages.'),
      `<div class="list" style="margin-bottom:10px"><div class="swatches">${WALLPAPERS.map(w => `<button class="swatch ${S.settings.wallpaper === w ? 'active' : ''}" data-wp="${w}" data-pick-wp="${w}" aria-label="${t(WP_NAMES[w])}"></button>`).join('')}</div></div>
       <div class="list"><div class="accents">${Object.entries(ACCENTS).map(([k, c]) => `<button class="accent-dot ${S.settings.accent === k ? 'active' : ''}" data-pick-accent="${k}" style="background:${c}" aria-label="${k}"></button>`).join('')}</div></div>`,
      `<button class="btn btn--block" data-next>${t('Continuer')}</button>`);
    $$('[data-pick-wp]', wiz).forEach(b => b.onclick = () => { S.settings.wallpaper = b.dataset.pickWp; applySettings(); renderWizard(); });
    $$('[data-pick-accent]', wiz).forEach(b => b.onclick = () => { S.settings.accent = b.dataset.pickAccent; applySettings(); renderWizard(); });
  }
  if (step === 'done') {
    view(t('Tout est prêt'), t('Votre numéro est le {number}. Partagez-le en un geste avec AuraDrop.', { number: esc(S.profile.number) }),
      `<div class="me-card" style="margin-top:6px">${avatar(S.profile.name, S.profile.number, 'avatar--lg')}
        <p class="me-card__name">${esc(S.profile.name)}</p><p class="me-card__number">${esc(S.profile.number)}</p></div>`,
      `<button class="btn btn--block" id="finish">${t('Commencer')}</button>`);
    $('#finish').onclick = finishSetup;
  }
  $('[data-next]', wiz)?.addEventListener('click', next);
}
async function finishSetup() {
  await saveSettings({ setup: true });
  screenEl.classList.remove('in-setup');
  setupView.classList.remove('active'); setupView.setAttribute('aria-hidden', 'true');
  setTimeout(() => { setupView.innerHTML = ''; }, 400);
  S.locked = false;
  renderHome();
}

// ---------------------------------------------------------
//  AuraDrop
// ---------------------------------------------------------
function openAuraDrop() {
  const myName = S.settings.cardName || S.profile.name;
  let timer;
  const sh = openSheet('AuraDrop', `<p class="sheet__text">${t('Approchez-vous d\'une personne pour lui envoyer votre fiche contact.')}</p>
    <div class="drop-card">${avatar(myName, S.profile.number)}<div class="row__main"><div class="row__title">${esc(myName)}</div><div class="row__sub">${esc(S.profile.number)}</div></div>
      <button class="icon-btn" id="drop-copy" aria-label="${t('Copier le numéro')}">${icon('copy')}</button></div>
    <div class="radar"><i></i><i></i><i></i><div class="radar__me">${icon('drop')}</div></div>
    <div id="drop-list"><p class="row__sub" style="text-align:center">${t('Recherche d\'appareils à proximité…')}</p></div>`, (el) => {
    $('#drop-copy', el).onclick = () => { copyText(S.profile.number); notify({ app: 'contacts', title: t('Numéro copié'), text: S.profile.number }); };
  });
  const sent = new Set();
  const scan = async () => {
    const r = await api('getNearby');
    const list = $('#drop-list', sh); if (!list) return clearInterval(timer);
    const devices = r.devices || [];
    list.innerHTML = devices.length ? `<div class="list">${devices.map(d => `<button class="row" data-dev="${d.id}">
      <span class="chip-ic" style="--c:${avColor(d.device)}">${icon('user')}</span>
      <div class="row__main"><div class="row__title">${esc(d.device)}</div><div class="row__sub">${t('à {d} m', { d: d.distance })}</div></div>
      <span class="chip ${sent.has(d.id) ? '' : 'chip--accent'}">${sent.has(d.id) ? t('Envoyé') : t('Envoyer')}</span></button>`).join('')}</div>`
      : `<p class="row__sub row__sub--wrap" style="text-align:center">${t('Aucun appareil à proximité. Rapprochez-vous à moins de quelques mètres.')}</p>`;
    $$('[data-dev]', list).forEach(b => b.onclick = async () => {
      if (sent.has(+b.dataset.dev)) return;
      const res = await api('auraDropSend', { id: +b.dataset.dev });
      if (!res.ok) { notify({ app: 'auradrop', title: 'AuraDrop', text: t(res.error || 'Appareil hors de portée') }); return; }
      sent.add(+b.dataset.dev); scan();
    });
  };
  scan(); timer = setInterval(scan, 3000);
  sh.addEventListener('sheetclose', () => clearInterval(timer));
}

function showDropPrompt(d) {
  if (!d || S.locked || !S.open) return;
  clearTimeout(islandTimeout);
  island.classList.remove('compact', 'music');
  island.classList.add('expanded', 'tall');
  island.onclick = null;
  $('.island__content', island).innerHTML = `<div class="island__icon">${solidTile('auradrop', 42)}</div>
    <div class="island__text"><div class="island__title">AuraDrop</div><div class="island__body">${esc(t('{device} partage la fiche de {name}', { device: d.device, name: d.name }))}</div></div>
    <div class="island__actions"><button data-drop="0">${t('Refuser')}</button><button class="primary" data-drop="1">${t('Enregistrer')}</button></div>`;
  $$('[data-drop]', island).forEach(b => b.onclick = async (e) => {
    e.stopPropagation();
    const accept = b.dataset.drop === '1';
    S.pendingDrops = S.pendingDrops.filter(x => x.id !== d.id);
    collapseIsland();
    const r = await api('auraDropAnswer', { id: d.id, accept });
    if (accept && r.ok) {
      await loadContacts();
      notify({ app: 'contacts', title: t('Contact enregistré'), text: `${d.name} (${d.number})` });
      if (S.currentApp === 'contacts' || S.currentApp === 'phone') refreshCurrent();
    } else if (!r.ok) notify({ app: 'auradrop', title: 'AuraDrop', text: t(r.error || 'Cette demande a expiré') });
    if (S.pendingDrops.length) setTimeout(() => showDropPrompt(S.pendingDrops[0]), 600);
  });
}

// ---------------------------------------------------------
//  RÉGLAGES
// ---------------------------------------------------------
Views.settings = ({ page = 'root' } = {}) => {
  const s = S.settings;
  const go = (p) => { S.stack.push({ id: 'settings', params: { page: p } }); Views.settings({ page: p }); };
  const toggleRow = (label, key, ic, color, extra = '') => `<button class="row" data-toggle="${key}">
    <span class="chip-ic" style="--c:${color}">${icon(ic)}</span><span class="row__main row__title row__title--light">${label}</span>
    ${extra}<span class="toggle ${s[key] ? 'on' : ''}" role="switch" aria-checked="${!!s[key]}"></span></button>`;
  const linkRow = (label, p, ic, color, aside = '') => `<button class="row" data-page="${p}">
    <span class="chip-ic" style="--c:${color}">${icon(ic)}</span><span class="row__main row__title row__title--light">${label}</span>
    <span class="row__aside">${aside}</span><span class="row__chev">${icon('chev')}</span></button>`;
  const wire = () => {
    $$('[data-page]', appView).forEach(b => b.onclick = () => go(b.dataset.page));
    $$('[data-toggle]', appView).forEach(b => b.onclick = () => {
      const k = b.dataset.toggle, v = !S.settings[k];
      b.querySelector('.toggle').classList.toggle('on', v);
      b.querySelector('.toggle').setAttribute('aria-checked', v);
      saveSettings({ [k]: v });
      if (k === 'moveWithPhone') post('setMove', { enabled: v });
    });
  };

  if (page === 'root') {
    const name = s.cardName || S.profile.name;
    const themeLabel = { dark: t('Sombre'), light: t('Clair'), auto: t('Auto') }[s.theme] || t('Sombre');
    frame({ title: t('Réglages'), body: `
      <div class="me-card">${avatar(name, S.profile.number, 'avatar--lg')}
        <p class="me-card__name">${esc(name)}</p><p class="me-card__number">${esc(S.profile.number)}</p>
        <div class="me-card__actions">
          <button data-me="copy">${icon('copy')}${t('Copier')}</button>
          <button data-me="drop" ${S.profile.auraDrop ? '' : 'disabled'}>${icon('drop')}AuraDrop</button>
          <button data-me="card">${icon('edit')}${t('Ma fiche')}</button></div></div>
      <div class="list" style="margin-top:14px">${toggleRow(t('Mode avion'), 'airplane', 'plane', '#F5A524')}</div>
      <p class="section-label">${t('Personnalisation')}</p>
      <div class="list">${linkRow(t('Apparence'), 'look', 'palette', '#7C6CFF', themeLabel)}${linkRow(t('Fond d\'écran'), 'wallpaper', 'wallpaper', '#2FC9D9')}${linkRow(t('Icônes et horloge'), 'icons', 'grid', '#FF6F9E')}</div>
      <p class="section-label">${t('Sécurité')}</p>
      <div class="list">${linkRow(t('Face ID et code'), 'security', 'face', '#3FBF8E', hasSecurity() ? t('Activé') : t('Désactivé'))}</div>
      <p class="section-label">${t('Général')}</p>
      <div class="list">${linkRow(t('Sons'), 'sounds', 'bell', '#FF6B7A')}${linkRow(t('Langue'), 'lang', 'globe', '#4C8DFF', LANGS.find(l => l[0] === s.lang)?.[1] || 'Français')}${linkRow(t('Général'), 'general', 'settings', '#8A90A8')}</div>
      <div class="about"><b>Elyzea Aura 5</b>${t('Version {v}', { v: '5.2' })}</div>` });
    $$('[data-me]', appView).forEach(b => b.onclick = () => {
      if (b.dataset.me === 'copy') { copyText(S.profile.number); notify({ app: 'contacts', title: t('Numéro copié'), text: S.profile.number }); }
      if (b.dataset.me === 'drop') openAuraDrop();
      if (b.dataset.me === 'card') editTextSetting(t('Ma fiche'), t('Le nom envoyé avec votre numéro par AuraDrop.'), 'cardName', S.profile.name, 40);
    });
    wire(); return;
  }

  if (page === 'look') {
    frame({ title: t('Apparence'), small: true, body: `
      <div class="list" style="padding:14px"><div class="theme-cards">
        ${[['dark', t('Sombre'), 'tc-dark'], ['light', t('Clair'), 'tc-light'], ['auto', t('Auto'), 'tc-auto']].map(([k, l, c]) => `<button class="theme-card ${s.theme === k ? 'active' : ''}" data-th="${k}">
          <span class="theme-card__phone ${c}"><i style="width:40%"></i><i style="width:65%"></i><b></b><span class="mini-grid">${'<span></span>'.repeat(8)}</span></span>${l}</button>`).join('')}</div></div>
      <p class="section-label">${t('Couleur d\'accent')}</p>
      <div class="list"><div class="accents">${Object.entries(ACCENTS).map(([k, c]) => `<button class="accent-dot ${s.accent === k ? 'active' : ''}" data-acc="${k}" style="background:${c}" aria-label="${k}"></button>`).join('')}
        <label class="accent-dot accent-dot--custom ${/^#/.test(s.accent) ? 'active' : ''}" aria-label="${t('Couleur personnalisée')}"><input type="color" id="acc-custom" value="${accentHex()}"></label></div></div>
      <p class="section-label">${t('Cadre du téléphone')}</p>
      <div class="list"><div class="frames">${Object.entries(FRAMES).map(([k, g]) => `<button class="frame-dot ${s.frame === k ? 'active' : ''}" data-frame="${k}" style="background:${g}" aria-label="${k}"></button>`).join('')}</div>
        ${toggleRow(t('Liseré lumineux'), 'edgeLight', 'sparkle', '#2FC9D9')}</div>` });
    $$('[data-th]', appView).forEach(b => b.onclick = () => { saveSettings({ theme: b.dataset.th }); $$('[data-th]', appView).forEach(x => x.classList.toggle('active', x === b)); });
    $$('[data-acc]', appView).forEach(b => b.onclick = () => { saveSettings({ accent: b.dataset.acc }); Views.settings({ page }); });
    $('#acc-custom').onchange = (e) => { saveSettings({ accent: e.target.value }); Views.settings({ page }); };
    $$('[data-frame]', appView).forEach(b => b.onclick = () => { saveSettings({ frame: b.dataset.frame }); $$('[data-frame]', appView).forEach(x => x.classList.toggle('active', x === b)); });
    wire(); return;
  }

  if (page === 'wallpaper') {
    const custom = /^https:\/\//.test(s.wallpaper || '');
    frame({ title: t('Fond d\'écran'), small: true, body: `
      <div class="list"><div class="swatches" style="flex-wrap:wrap">${WALLPAPERS.map(w => `<button class="swatch ${s.wallpaper === w ? 'active' : ''}" data-wp="${w}" data-set-wp="${w}" aria-label="${t(WP_NAMES[w])}" title="${t(WP_NAMES[w])}"></button>`).join('')}
        <button class="swatch swatch--add ${custom ? 'active' : ''}" id="wp-custom" aria-label="${t('Image personnalisée')}" ${custom ? `style="--wp:url('${esc(s.wallpaper)}')"` : ''}>${custom ? '' : icon('plus')}</button></div></div>
      <p class="row__sub row__sub--wrap" style="margin:12px 8px">${t('Le bouton + permet d\'utiliser n\'importe quelle image en ligne (lien https).')}</p>` });
    $$('[data-set-wp]', appView).forEach(b => b.onclick = () => { saveSettings({ wallpaper: b.dataset.setWp }); Views.settings({ page }); });
    $('#wp-custom').onclick = () => openSheet(t('Image personnalisée'), `<div class="form">
      <input class="field" id="wp-url" placeholder="https://…" value="${custom ? esc(s.wallpaper) : ''}">
      <p class="error-text" id="wp-err"></p><button class="btn btn--block" id="wp-save">${t('Appliquer')}</button></div>`, (sh) => {
      $('#wp-save', sh).onclick = () => {
        const v = $('#wp-url', sh).value.trim();
        if (!/^https:\/\//.test(v)) { $('#wp-err', sh).textContent = t('Le lien doit commencer par https://'); return; }
        closeSheet(); saveSettings({ wallpaper: v }); Views.settings({ page });
      };
    });
    return;
  }

  if (page === 'icons') {
    frame({ title: t('Icônes et horloge'), small: true, body: `
      <p class="section-label">${t('Style des icônes')}</p>
      <div class="list"><div class="icon-styles">${[['prisme', t('Prisme')], ['verre', t('Verre')], ['mono', t('Mono')]].map(([k, l]) => `<button class="icon-style ${s.iconStyle === k ? 'active' : ''}" data-ic="${k}">
        <span style="display:flex;gap:6px">${appTile('messages', '', 'is-' + k)}${appTile('bank', '', 'is-' + k)}</span>${l}</button>`).join('')}</div></div>
      <p class="section-label">${t('Horloge de l\'accueil')}</p>
      <div class="list"><div class="row row--stack"><div class="seg">${[['stack', t('Empilée')], ['line', t('Classique')], ['minimal', t('Discrète')]].map(([k, l]) => `<button class="${s.clockStyle === k ? 'active' : ''}" data-clock="${k}">${l}</button>`).join('')}</div></div></div>
      <p class="section-label">${t('Accueil')}</p>
      <div class="list">${bankOn() ? toggleRow(t('Widget du compte'), 'showBankWidget', 'card', '#2FC9D9') : ''}</div>` });
    $$('[data-ic]', appView).forEach(b => b.onclick = () => { saveSettings({ iconStyle: b.dataset.ic }); $$('[data-ic]', appView).forEach(x => x.classList.toggle('active', x === b)); });
    $$('[data-clock]', appView).forEach(b => b.onclick = () => { saveSettings({ clockStyle: b.dataset.clock }); $$('[data-clock]', appView).forEach(x => x.classList.toggle('active', x === b)); });
    wire(); return;
  }

  if (page === 'security') {
    const on = hasSecurity();
    frame({ title: t('Face ID et code'), small: true, body: `
      <div class="setup-illus" style="margin-top:0">${faceEl(on ? 'ok' : 'idle')}</div>
      ${on ? `<div class="list">${toggleRow(t('Face ID'), 'faceid', 'face', '#3FBF8E')}${toggleRow(t('Verrouiller à la fermeture'), 'lockOnClose', 'lock', '#7C6CFF')}</div>
        <div class="list" style="margin-top:12px">
          <button class="row" id="code-change"><span class="row__main row__title row__title--light">${t('Modifier le code')}</span><span class="row__chev">${icon('chev')}</span></button>
          <button class="row" id="code-off"><span class="row__main row__title row__title--light" style="color:var(--danger)">${t('Désactiver le code')}</span></button></div>
        <p class="row__sub row__sub--wrap" style="margin:12px 8px">${t('Code oublié ? Un administrateur peut le réinitialiser.')}</p>`
      : `<p class="sheet__text" style="text-align:center;margin:0 10px 18px">${t('Un code empêche les autres de lire vos messages ou d\'utiliser votre banque.')}</p>
        <div class="grid-2"><button class="btn" data-len="4">${t('Code à 4 chiffres')}</button><button class="btn btn--ghost" data-len="6">${t('Code à 6 chiffres')}</button></div>`}` });
    $$('[data-len]', appView).forEach(b => b.onclick = () => createPasscode(+b.dataset.len, screenEl, () => {
      notify({ app: 'settings', title: t('Code activé'), text: t('Il sera demandé à chaque ouverture.') }); Views.settings({ page });
    }, () => {}));
    $('#code-change')?.addEventListener('click', () => passcodePad({
      title: t('Saisissez votre code actuel'), length: S.profile.passcode.length,
      onComplete: async (old) => {
        const r = await api('unlock', { code: old });
        if (!r.ok) return { error: r.wait ? t('Trop d\'essais. Réessayez dans {s} s.', { s: r.wait }) : t('Code incorrect') };
        setTimeout(() => openSheet(t('Nouveau code'), `<div class="grid-2"><button class="btn" data-nl="4">${t('Code à 4 chiffres')}</button><button class="btn btn--ghost" data-nl="6">${t('Code à 6 chiffres')}</button></div>`, (sh) => {
          $$('[data-nl]', sh).forEach(b => b.onclick = () => { closeSheet(true); createPasscode(+b.dataset.nl, screenEl, () => { notify({ app: 'settings', title: t('Code modifié'), text: '' }); Views.settings({ page }); }, () => {}, old); });
        }), 50);
        return true;
      }
    }));
    $('#code-off')?.addEventListener('click', () => passcodePad({
      title: t('Saisissez votre code pour le désactiver'), length: S.profile.passcode.length,
      onComplete: async (code) => {
        const r = await api('removePasscode', { code });
        if (!r.ok) return { error: t(r.error || 'Code incorrect') };
        S.profile.passcode = { set: false }; S.settings.faceid = false;
        Views.settings({ page }); return true;
      }
    }));
    wire(); return;
  }

  if (page === 'sounds') {
    frame({ title: t('Sons'), small: true, body: `
      <div class="list">${toggleRow(t('Mode silencieux'), 'silent', 'bell', '#FF6B7A')}</div>
      <p class="section-label">${t('Sonnerie')}</p>
      <div class="list">${Object.entries(RINGTONES).map(([k, l]) => `<button class="row" data-ring="${k}"><span class="chip-ic" style="--c:#7C6CFF">${icon('music')}</span>
        <span class="row__main row__title row__title--light">${l}</span>${s.ringtone === k ? `<span style="width:20px;color:var(--accent)">${icon('check')}</span>` : ''}</button>`).join('')}</div>` });
    $$('[data-ring]', appView).forEach(b => b.onclick = () => { Sound.preview(b.dataset.ring); saveSettings({ ringtone: b.dataset.ring }); Views.settings({ page }); });
    wire(); return;
  }

  if (page === 'lang') {
    frame({ title: t('Langue'), small: true, body: LANGS.map(([k, l, f]) => `<button class="choice ${s.lang === k ? 'active' : ''}" data-lang="${k}"><span class="choice__flag">${f}</span><span class="choice__label">${l}</span><span class="choice__check">${icon('check')}</span></button>`).join('') });
    $$('[data-lang]', appView).forEach(b => b.onclick = () => { saveSettings({ lang: b.dataset.lang }); Views.settings({ page }); });
    return;
  }

  if (page === 'general') {
    frame({ title: t('Général'), small: true, body: `
      <div class="list">${toggleRow(t('Notifications'), 'notifications', 'bell', '#FF6B7A')}${toggleRow(t('Aperçu quand le téléphone est rangé'), 'notifPreview', 'frame', '#7C6CFF')}${toggleRow(t('Se déplacer avec le téléphone ouvert'), 'moveWithPhone', 'size', '#3FBF8E')}${S.profile.auraDrop ? toggleRow(t('Visible sur AuraDrop'), 'auraDrop', 'drop', '#2FC9D9') : ''}
        <button class="row" id="dev-name"><span class="chip-ic" style="--c:#4C8DFF">${icon('frame')}</span><span class="row__main row__title row__title--light">${t('Nom de l\'appareil')}</span>
        <span class="row__aside">${esc(s.deviceName || 'Aura ' + (S.profile.name || '').split(' ')[0])}</span><span class="row__chev">${icon('chev')}</span></button></div>
      <p class="section-label">${t('Taille du téléphone')}</p>
      <div class="list"><div class="row row--stack"><div class="seg">${[80, 90, 100, 110].map(z => `<button class="${+s.zoom === z ? 'active' : ''}" data-zoom="${z}">${z}%</button>`).join('')}</div></div></div>
      <p class="section-label">${t('Réinitialisation')}</p>
      <div class="list"><button class="row" id="rerun"><span class="chip-ic" style="--c:#8A90A8">${icon('reset')}</span><span class="row__main row__title row__title--light">${t('Relancer la configuration')}</span></button></div>
      <p class="row__sub row__sub--wrap" style="margin:10px 8px">${t('Vos messages, contacts et photos sont conservés.')}</p>` });
    $('#dev-name').onclick = () => editTextSetting(t('Nom de l\'appareil'), t('Le nom que voient les autres dans AuraDrop.'), 'deviceName', '', 30);
    $$('[data-zoom]', appView).forEach(b => b.onclick = () => { saveSettings({ zoom: +b.dataset.zoom }); $$('[data-zoom]', appView).forEach(x => x.classList.toggle('active', x === b)); });
    $('#rerun').onclick = () => confirmSheet(t('Relancer la configuration ?'), t('L\'intro et les étapes de configuration s\'afficheront à nouveau.'), t('Relancer'), async () => {
      await saveSettings({ setup: false }); goHome(); startSetup();
    });
    wire(); return;
  }
};

function editTextSetting(title, help, key, fallback, max) {
  openSheet(title, `<p class="sheet__text">${help}</p><div class="form">
    <input class="field" id="ts-val" maxlength="${max}" value="${esc(S.settings[key] || fallback)}">
    <button class="btn btn--block" id="ts-save">${t('Enregistrer')}</button></div>`, (sh) => {
    $('#ts-save', sh).onclick = () => { saveSettings({ [key]: $('#ts-val', sh).value.trim() }); closeSheet(); refreshCurrent(); };
  });
}
