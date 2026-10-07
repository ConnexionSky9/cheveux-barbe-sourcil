'use strict';
/* =========================================================
   ELYZEACARPLAY — tablette de bord + contrôle à distance
   ========================================================= */
const CP = { open: false, netId: null, name: '', plate: '', state: null, colors: [], tick: null, introTimer: null };
const DOOR_NAMES = ['Avant gauche', 'Avant droite', 'Arrière gauche', 'Arrière droite', 'Capot', 'Coffre'];
const WINDOW_NAMES = ['Avant gauche', 'Avant droite', 'Arrière gauche', 'Arrière droite'];
const rgb = (c) => c ? `rgb(${c[0]},${c[1]},${c[2]})` : '#6FE7F2';

/* ---------- Voiture vue de dessus (interactive) ---------- */
// Portes : 0 avant gauche, 1 avant droite, 2 arrière gauche, 3 arrière droite, 4 capot, 5 coffre
function carSvg(st, opts = {}) {
  const d = st?.doors || [], w = st?.windows || [], valid = st?.validDoors || [true, true, true, true, true, true];
  const neon = st?.neon ? rgb(st.neonColor) : null;
  const door = (i, x, y, h, hingeX, side) => valid[i] === false ? '' : `<g class="cp-door ${d[i] ? 'open' : ''}" data-door="${i}" role="button" aria-label="${t('Porte')} ${t(DOOR_NAMES[i])}"
      style="transform-origin:${hingeX}px ${y}px;transform:${d[i] ? `rotate(${side * 40}deg)` : 'none'}">
      <rect x="${x}" y="${y}" width="9" height="${h}" rx="4"/>${w[i] ? `<circle class="cp-win" cx="${x + 4.5}" cy="${y + h / 2}" r="3"/>` : ''}</g>`;
  return `<svg class="cp-car ${st?.locked ? 'locked' : ''} ${opts.small ? 'small' : ''}" viewBox="0 0 220 420" aria-label="${t('Votre véhicule vu de dessus')}">
    <defs><linearGradient id="cpBody" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2A3158"/><stop offset="1" stop-color="#151A33"/></linearGradient>
      <filter id="cpGlow"><feGaussianBlur stdDeviation="10"/></filter></defs>
    ${neon ? `<rect x="22" y="40" width="176" height="340" rx="70" fill="${neon}" filter="url(#cpGlow)" opacity=".75" class="cp-neon"/>` : ''}
    <path class="cp-body" d="M44 60 Q44 26 110 22 Q176 26 176 60 L182 330 Q182 396 110 400 Q38 396 38 330 Z"/>
    <path class="cp-glass" d="M60 116 Q110 100 160 116 L154 160 Q110 152 66 160 Z"/>
    <path class="cp-glass" d="M66 290 Q110 298 154 290 L160 326 Q110 340 60 326 Z"/>
    <rect class="cp-roof" x="64" y="166" width="92" height="118" rx="18"/>
    <g class="cp-hood ${d[4] ? 'open' : ''}" data-door="4" role="button" aria-label="${t('Capot')}"><path d="M56 38 Q110 14 164 38 L166 104 L54 104 Z"/></g>
    <g class="cp-trunk ${d[5] ? 'open' : ''}" data-door="5" role="button" aria-label="${t('Coffre')}"><path d="M50 340 L170 340 L166 386 Q110 408 54 386 Z"/></g>
    ${door(0, 30, 130, 70, 34, -1)}${door(1, 181, 130, 70, 186, 1)}${door(2, 30, 208, 66, 34, -1)}${door(3, 181, 208, 66, 186, 1)}
    <circle class="cp-light" cx="68" cy="30" r="5"/><circle class="cp-light" cx="152" cy="30" r="5"/>
    <circle class="cp-light rear" cx="64" cy="392" r="5"/><circle class="cp-light rear" cx="156" cy="392" r="5"/>
    ${st?.locked ? `<g class="cp-lockmark" transform="translate(94 210)"><rect x="0" y="12" width="32" height="24" rx="6"/><path d="M7 12 V6 a9 9 0 0 1 18 0 V12" fill="none" stroke-width="4"/></g>` : ''}
  </svg>`;
}

/* ---------- Tablette ---------- */
function cpAct(action, value) {
  return post('carplayAction', { action, value }).then(r => {
    if (r && r.ok && r.state) { CP.state = Object.assign({}, CP.state, r.state); renderCarPlay(true); }
    else if (r && r.error) toast({ app: 'carplay', title: 'ElyzeaCarPlay', text: t(r.error) });
    return r;
  });
}

function cpOpen(d) {
  CP.open = true; CP.netId = d.netId; CP.name = d.name; CP.plate = d.plate; CP.state = d.state; CP.colors = d.colors || [];
  const root = $('#carplay');
  root.classList.remove('hidden', 'closing');
  root.innerHTML = `${d.intro ? `<div class="cp-intro" id="cp-intro">
      <i class="cp-bar top"></i><i class="cp-bar bottom"></i>
      <div class="cp-intro__text">
        <p class="cp-intro__kicker">ElyzeaCarPlay</p>
        <h1 class="cp-intro__title">${t('Bienvenue sur')} <b>ElyzeaCarPlay</b></h1>
        <p class="cp-intro__car">${esc(d.name)}<span>${esc(d.plate)}</span></p>
        <i class="cp-intro__scan"></i>
      </div>
      <button class="cp-intro__skip" id="cp-skip">${t('Passer')}</button></div>` : ''}
    <div class="cp-tablet ${d.intro ? 'waiting' : ''}" id="cp-tablet" role="dialog" aria-label="ElyzeaCarPlay"></div>`;
  renderCarPlay();
  if (d.intro) {
    $('#cp-skip').onclick = () => { post('carplaySkip'); cpIntroEnd(); };
    if (IS_BROWSER) CP.introTimer = setTimeout(cpIntroEnd, 3600);
  }
  clearInterval(CP.tick);
  CP.tick = setInterval(updateCpProgress, 500);
}
function cpIntroEnd() {
  clearTimeout(CP.introTimer);
  const intro = $('#cp-intro');
  if (intro) { intro.classList.add('done'); setTimeout(() => intro.remove(), 700); }
  $('#cp-tablet')?.classList.remove('waiting');
}
function cpClose() {
  CP.open = false;
  clearInterval(CP.tick);
  const root = $('#carplay');
  root.classList.add('closing');
  setTimeout(() => { if (!CP.open) { root.classList.add('hidden'); root.innerHTML = ''; } }, 350);
}

function renderCarPlay(partial) {
  const tab = $('#cp-tablet'); if (!tab) return;
  const st = CP.state || {};
  const m = st.music;
  const now = new Date();
  const doorsOpen = (st.doors || []).some(Boolean), winOpen = (st.windows || []).some(Boolean);
  const speedPct = Math.min(1, (st.speed || 0) / 260);
  const arc = (pct, r) => { const c = 2 * Math.PI * r; return `stroke-dasharray:${c * 0.75} ${c};stroke-dashoffset:${c * 0.75 * (1 - pct)}`; };
  const html = `
    <header class="cp-head">
      <div class="cp-brand"><span class="cp-logo">${icon('carplay')}</span><div><b>ElyzeaCarPlay</b><span>${esc(CP.name)}, ${esc(CP.plate)}</span></div></div>
      <p class="cp-clock" id="cp-clock">${pad(now.getHours())}:${pad(now.getMinutes())}</p>
      <button class="cp-close" data-cp="close" aria-label="${t('Fermer')}">${icon('close')}</button>
    </header>
    <div class="cp-grid">
      <section class="cp-panel cp-vehicle">
        <p class="cp-label">${t('Véhicule')}</p>
        <div class="cp-car-wrap">${carSvg(st)}</div>
        <p class="cp-hint">${t('Touchez une porte, le capot ou le coffre pour l\'ouvrir')}</p>
        <div class="cp-row2">
          <button class="cp-btn ${doorsOpen ? 'on' : ''}" data-cp="doorsAll">${icon('car')}${doorsOpen ? t('Fermer les portes') : t('Ouvrir les portes')}</button>
          <button class="cp-btn ${winOpen ? 'on' : ''}" data-cp="windowsAll">${icon('size')}${winOpen ? t('Monter les vitres') : t('Baisser les vitres')}</button></div>
        <div class="cp-windows">${WINDOW_NAMES.map((n, i) => `<button class="cp-chip ${st.windows?.[i] ? 'on' : ''}" data-win="${i}" title="${t('Vitre')} ${t(n)}">${['AVG', 'AVD', 'ARG', 'ARD'][i]}</button>`).join('')}</div>
      </section>

      <section class="cp-panel cp-media">
        <p class="cp-label">${t('Musique')}</p>
        <div class="cp-now ${m ? '' : 'empty'}" ${m?.thumb ? `style="--art:url('${esc(m.thumb)}')"` : ''}>
          <div class="cp-now__art">${m?.thumb ? '' : icon('music')}</div>
          <div class="cp-now__text"><p class="cp-now__title">${m ? esc(m.title || t('Lecture en cours')) : t('Aucune musique')}</p>
            <p class="cp-now__artist">${m ? esc(m.artist || '') : t('Collez un lien YouTube ci-dessous')}</p></div>
        </div>
        <div class="cp-progress"><input type="range" class="range" id="cp-seek" min="0" max="1000" value="0" ${m ? '' : 'disabled'} aria-label="${t('Position dans le morceau')}">
          <div class="np__times"><span id="cp-cur">0:00</span><span id="cp-dur">--:--</span></div></div>
        <div class="cp-controls">
          <button class="cp-round" data-cp="musicStop" ${m ? '' : 'disabled'} aria-label="${t('Arrêter')}">${icon('close')}</button>
          <button class="cp-play" data-cp="${m && !m.paused ? 'musicPause' : 'musicResume'}" ${m ? '' : 'disabled'} aria-label="${m && !m.paused ? t('Pause') : t('Lecture')}">${icon(m && !m.paused ? 'pause' : 'play')}</button>
          <div class="cp-vol">${icon('speaker')}<input type="range" class="range" id="cp-vol" min="0" max="100" value="${Math.round((m?.volume ?? 0.6) * 100)}" ${m ? '' : 'disabled'} aria-label="${t('Volume')}"></div>
        </div>
        <div class="cp-link"><input class="field" id="cp-link" placeholder="${t('Collez un lien YouTube ou audio')}"><button class="cp-go" id="cp-go" aria-label="${t('Lancer')}">${icon('play')}</button></div>
        <p class="error-text" id="cp-err"></p>
        <p class="cp-hint">${t('Les passagers et les personnes autour de la voiture entendent la musique.')}</p>
      </section>

      <section class="cp-panel cp-side">
        <div class="cp-gauge">
          <svg viewBox="0 0 120 120"><circle class="cp-gauge__bg" cx="60" cy="60" r="48" style="${arc(1, 48)}"/>
            <circle class="cp-gauge__fg" id="cp-speed-arc" cx="60" cy="60" r="48" style="${arc(speedPct, 48)}"/></svg>
          <div class="cp-gauge__val"><b id="cp-speed">${st.speed || 0}</b><span>km/h</span></div>
        </div>
        <div class="cp-stats"><span>${icon('drop')}<b id="cp-fuel">${st.fuel ?? '--'}%</b></span><span>${icon('wrench')}<b id="cp-engine">${st.engine ?? '--'}%</b></span></div>
        <button class="cp-lock ${st.locked ? 'on' : ''}" data-cp="lock">${icon('lock')}<span>${st.locked ? t('Verrouillé') : t('Déverrouillé')}</span></button>
        <button class="cp-btn cp-neon-btn ${st.neon ? 'on' : ''}" data-cp="neon" style="--neon:${rgb(st.neonColor)}">${icon('sparkle')}${st.neon ? t('LED allumées') : t('LED éteintes')}</button>
        <div class="cp-colors">${CP.colors.map((c, i) => `<button class="cp-dot ${st.neon && st.neonColor && st.neonColor[0] === c[0] && st.neonColor[1] === c[1] && st.neonColor[2] === c[2] ? 'active' : ''}" data-color="${i}" style="background:${rgb(c)}" aria-label="${t('Couleur')} ${i + 1}"></button>`).join('')}</div>
      </section>
    </div>`;
  const keepLink = partial ? $('#cp-link')?.value : '';
  tab.innerHTML = html;
  if (keepLink) $('#cp-link').value = keepLink;
  wireCarPlay(tab);
  updateCpProgress();
}

function wireCarPlay(root) {
  const st = CP.state || {};
  $$('[data-door]', root).forEach(el => el.addEventListener('click', () => { const i = +el.dataset.door; cpAct('door', { index: i, open: !st.doors?.[i] }); }));
  $$('[data-win]', root).forEach(el => el.onclick = () => { const i = +el.dataset.win; cpAct('window', { index: i, down: !st.windows?.[i] }); });
  $$('[data-color]', root).forEach(el => el.onclick = () => cpAct('neonColor', CP.colors[+el.dataset.color]));
  $$('[data-cp]', root).forEach(el => el.onclick = () => {
    const a = el.dataset.cp;
    if (a === 'close') return post('carplayClose').then(() => IS_BROWSER && cpClose());
    if (a === 'lock') return cpAct('lock', !st.locked);
    if (a === 'neon') return cpAct('neon', !st.neon);
    if (a === 'doorsAll') return cpAct('doorsAll', !(st.doors || []).some(Boolean));
    if (a === 'windowsAll') return cpAct('windowsAll', !(st.windows || []).some(Boolean));
    cpAct(a);
  });
  const go = async () => {
    const link = $('#cp-link').value.trim(); if (!link) return;
    $('#cp-err').textContent = t('Recherche du morceau…');
    const r = await cpAct('music', link);
    $('#cp-err').textContent = r && r.ok ? '' : t(r?.error || 'Lecture impossible');
    if (r && r.ok) $('#cp-link').value = '';
  };
  $('#cp-go').onclick = go;
  $('#cp-link').onkeydown = (e) => { if (e.key === 'Enter') go(); };
  let volTimer;
  $('#cp-vol').oninput = (e) => { clearTimeout(volTimer); const v = e.target.value / 100; volTimer = setTimeout(() => cpAct('musicVolume', v), 250); };
  $('#cp-seek').onchange = (e) => { const dur = AudioEngine.duration('car' + CP.netId); if (dur) cpAct('musicSeek', Math.floor(e.target.value / 1000 * dur)); };
}

function updateCpProgress() {
  const now = new Date();
  const ck = $('#cp-clock'); if (ck) ck.textContent = `${pad(now.getHours())}:${pad(now.getMinutes())}`;
  const key = 'car' + CP.netId;
  const tm = AudioEngine.time(key), dur = AudioEngine.duration(key);
  const seek = $('#cp-seek');
  if (seek && dur && document.activeElement !== seek) seek.value = Math.min(1000, tm / dur * 1000);
  const c = $('#cp-cur'), d = $('#cp-dur');
  if (c) c.textContent = duration(Math.floor(tm));
  if (d) d.textContent = dur ? duration(Math.floor(dur)) : '--:--';
}

// Données en direct (vitesse, carburant...) envoyées par le jeu pendant que la tablette est ouverte
function cpLive(s) {
  if (!CP.open) return;
  const prev = CP.state || {};
  CP.state = Object.assign({}, prev, s);
  const changed = JSON.stringify([prev.doors, prev.windows, prev.locked, prev.neon, prev.neonColor, prev.music]) !==
    JSON.stringify([s.doors, s.windows, s.locked, s.neon, s.neonColor, s.music]);
  if (changed && document.activeElement?.id !== 'cp-link' && document.activeElement?.id !== 'cp-vol') { renderCarPlay(true); return; }
  const sp = $('#cp-speed'); if (sp) sp.textContent = s.speed;
  const arc = $('#cp-speed-arc');
  if (arc) { const c = 2 * Math.PI * 48; arc.style.strokeDashoffset = c * 0.75 * (1 - Math.min(1, s.speed / 260)); }
  const f = $('#cp-fuel'); if (f) f.textContent = `${s.fuel}%`;
  const e = $('#cp-engine'); if (e) e.textContent = `${s.engine}%`;
}

/* ---------- Musique des voitures (jouée pour chaque joueur selon sa position) ---------- */
const CarAudio = {
  handle(d) {
    const key = 'car' + d.id;
    if (d.action === 'play') AudioEngine.play(key, { url: d.url, time: d.time || 0, volume: 0 });
    else if (d.action === 'pause') AudioEngine.pause(key);
    else if (d.action === 'resume') { AudioEngine.seek(key, d.time || 0); AudioEngine.resume(key); }
    else if (d.action === 'volume') AudioEngine.setVolume(key, d.volume);
    else if (d.action === 'stop') AudioEngine.stop(key);
  },
};

/* =========================================================
   APP TÉLÉPHONE : contrôle à distance
   ========================================================= */
const CPR = { list: [], state: null, colors: [], summonDistance: 350 };
const fmtDist = (d) => d >= 1000 ? `${(d / 1000).toFixed(1)} km` : `${d} m`;

async function loadFleet() {
  const r = IS_BROWSER ? Mock.fleet() : await api('carplayFleet');
  CPR.list = r.vehicles || [];
  CPR.summonDistance = r.summonDistance || 350;
  if (!IS_BROWSER && CPR.list.length) {
    const lr = await post('vehicleLabels', { models: CPR.list.map(v => v.model) });
    (lr.labels || []).forEach((l, i) => { if (CPR.list[i]) CPR.list[i].name = l; });
  }
  return CPR.list;
}

// Écran « flotte » : toutes mes voitures sorties
Views.carplay = async ({ netId } = {}) => {
  if (netId) return renderRemote(netId);
  frame({ title: 'CarPlay', action: `<button class="icon-btn" data-refresh aria-label="${t('Actualiser')}">${icon('reset')}</button>`, body: loading() });
  $('[data-refresh]', appView).onclick = () => Views.carplay();
  await loadFleet();
  if (S.currentApp !== 'carplay') return;
  const list = CPR.list;
  const allLocked = list.length && list.every(v => v.locked);
  $('.app__body', appView).innerHTML = `
    <div class="cpr-hero"><span class="cp-logo">${icon('carplay')}</span><div><b>${t('Ma flotte')}</b>
      <p>${list.length ? t('{n} véhicule(s) sorti(s), contrôlables à distance.', { n: list.length }) : t('Aucun véhicule sorti pour le moment.')}</p></div></div>
    ${list.length ? `<button class="btn btn--block cpr-lockall ${allLocked ? 'btn--ghost' : ''}" data-lockall="${allLocked ? 0 : 1}">${icon('lock')}${allLocked ? t('Tout déverrouiller') : t('Tout verrouiller')}</button>
    <div class="cpr-fleet">${list.map(v => `<article class="cpr-veh" data-car="${v.netId}" role="button" tabindex="0">
      <div class="cpr-veh__top"><span class="cpr-veh__ic ${v.engine ? 'live' : ''}">${icon('car')}</span>
        <div class="row__main"><div class="row__title">${esc(v.name || v.model)}</div><div class="row__sub"><span class="gar-plate">${esc(v.plate)}</span> ${t('à {d}', { d: fmtDist(v.distance) })}</div></div>
        <button class="cpr-quick ${v.locked ? 'on' : ''}" data-qlock="${v.netId}" aria-label="${v.locked ? t('Déverrouiller') : t('Verrouiller')}">${icon('lock')}</button></div>
      <div class="cpr-badges">
        <span class="${v.locked ? 'on' : ''}">${v.locked ? t('Verrouillé') : t('Ouvert')}</span>
        <span class="${v.engine ? 'on' : ''}">${v.engine ? t('Moteur allumé') : t('Moteur coupé')}</span>
        ${v.neon ? `<span class="on">${t('LED')}</span>` : ''}${v.lights ? `<span class="on">${t('Phares')}</span>` : ''}
        ${v.doorsOpen ? `<span class="warn">${t('{n} porte(s) ouverte(s)', { n: v.doorsOpen })}</span>` : ''}
        ${v.music ? `<span class="on">${icon('music')}${esc(v.music)}</span>` : ''}
        ${v.occupied ? `<span class="warn">${t('Quelqu\'un est au volant')}</span>` : ''}</div>
    </article>`).join('')}</div>`
      : empty(t('Aucun véhicule sorti'), t('Sortez un véhicule du garage pour le contrôler à distance.'), `<button class="btn" data-open="garage">${t('Ouvrir le Garage')}</button>`)}`;
  $('[data-lockall]', appView)?.addEventListener('click', async (e) => {
    const lock = e.currentTarget.dataset.lockall === '1';
    const r = IS_BROWSER ? { ok: true, count: list.length } : await api('carplayLockAll', { lock });
    if (r.ok) notify({ app: 'carplay', title: lock ? t('Flotte verrouillée') : t('Flotte déverrouillée'), text: t('{n} véhicule(s)', { n: r.count }) });
    Views.carplay();
  });
  $$('[data-qlock]', appView).forEach(b => b.onclick = async (e) => {
    e.stopPropagation();
    const v = list.find(x => x.netId === +b.dataset.qlock);
    const r = await remoteAct(v.netId, 'lock', !v.locked, true);
    if (r.ok) { v.locked = !v.locked; b.classList.toggle('on', v.locked); Views.carplay(); }
  });
  $$('[data-car]', appView).forEach(el => el.onclick = () => openApp('carplay', { netId: +el.dataset.car }));
};

async function remoteAct(netId, action, value, silent) {
  const r = IS_BROWSER ? Mock.carAction(action, value) : await api('carplayAction', { netId, action, value, remote: true });
  if (r.ok && r.state) { CPR.state = r.state; if (!silent && $('#cpr-panel')) drawRemote(netId); }
  else if (!r.ok) notify({ app: 'carplay', title: 'CarPlay', text: t(r.error || 'Action impossible') });
  return r;
}

async function renderRemote(netId) {
  if (!CPR.list.length) await loadFleet();
  const v = CPR.list.find(x => x.netId === netId) || { name: t('Véhicule'), plate: '' };
  frame({ title: esc(v.name || v.model), small: true, body: loading() });
  const r = IS_BROWSER ? Mock.carState() : await api('carplayState', { netId, remote: true });
  if (S.currentApp !== 'carplay') return;
  if (!r.ok) { $('.app__body', appView).innerHTML = empty(t('Véhicule injoignable'), t(r.error || 'Ce véhicule n\'est plus disponible.')); return; }
  CPR.state = r.state; CPR.colors = r.colors || []; CPR.pos = { x: r.x, y: r.y }; CPR.distance = r.distance; CPR.current = v;
  drawRemote(netId);
}

function drawRemote(netId) {
  const st = CPR.state || {}, v = CPR.current || {};
  const m = st.music;
  const body = $('.app__body', appView); if (!body) return;
  const doorsOpen = (st.doors || []).some(Boolean), winOpen = (st.windows || []).some(Boolean);
  const canSummon = (CPR.distance ?? 0) <= CPR.summonDistance;
  body.innerHTML = `<div id="cpr-panel">
    <div class="cpr-car">${carSvg(st, { small: true })}
      <span class="cpr-status ${st.locked ? 'on' : ''}">${icon('lock')}${st.locked ? t('Verrouillé') : t('Déverrouillé')}</span>
      <span class="cpr-dist">${v.plate ? `<span class="gar-plate">${esc(v.plate)}</span>` : ''} ${t('à {d}', { d: fmtDist(CPR.distance || 0) })}</span></div>
    <button class="btn btn--block cpr-summon" data-r="summon" ${canSummon ? '' : 'disabled'}>${icon('car')}${canSummon ? t('Venir à moi') : t('Trop loin pour venir seule ({d})', { d: fmtDist(CPR.distance || 0) })}</button>
    <div class="cpr-grid">
      <button class="cpr-tile ${st.locked ? 'on' : ''}" data-r="lock">${icon('lock')}<span>${st.locked ? t('Déverrouiller') : t('Verrouiller')}</span></button>
      <button class="cpr-tile ${st.engine ? 'on' : ''}" data-r="engine">${icon('wrench')}<span>${st.engine ? t('Couper le moteur') : t('Démarrer le moteur')}</span></button>
      <button class="cpr-tile ${st.lights ? 'on' : ''}" data-r="lights">${icon('sparkle')}<span>${st.lights ? t('Éteindre les phares') : t('Allumer les phares')}</span></button>
      <button class="cpr-tile ${st.neon ? 'on' : ''}" data-r="neon" style="--neon:${rgb(st.neonColor)}">${icon('sparkle')}<span>${st.neon ? t('Éteindre les LED') : t('Allumer les LED')}</span></button>
      <button class="cpr-tile ${doorsOpen ? 'on' : ''}" data-r="doorsAll">${icon('car')}<span>${doorsOpen ? t('Fermer les portes') : t('Ouvrir les portes')}</span></button>
      <button class="cpr-tile ${winOpen ? 'on' : ''}" data-r="windowsAll">${icon('size')}<span>${winOpen ? t('Monter les vitres') : t('Baisser les vitres')}</span></button>
      <button class="cpr-tile" data-r="ping">${icon('pin')}<span>${t('Localiser')}</span></button>
      <button class="cpr-tile cpr-tile--alarm" data-r="alarm">${icon('alert')}<span>${t('Alarme')}</span></button>
      <button class="cpr-tile ${m ? 'on' : ''}" data-r="music">${icon('music')}<span>${m ? t('Couper la musique') : t('Musique')}</span></button>
    </div>
    <p class="section-label">${t('Couleur des LED')}</p>
    <div class="cp-colors" style="justify-content:flex-start;margin-top:0">${CPR.colors.map((c, i) => `<button class="cp-dot ${st.neon && st.neonColor && st.neonColor.join() === c.join() ? 'active' : ''}" data-color="${i}" style="background:${rgb(c)}" aria-label="${t('Couleur')} ${i + 1}"></button>`).join('')}</div>
    ${m ? `<div class="list" style="margin-top:12px"><div class="row">${m.thumb ? `<div class="art art--sm" style="background-image:url('${esc(m.thumb)}')"></div>` : `<span class="chip-ic">${icon('music')}</span>`}
      <div class="row__main"><div class="row__title">${esc(m.title || '')}</div><div class="row__sub">${t('Joue dans le véhicule')}</div></div>
      <button class="chip" data-r="musicToggle">${m.paused ? t('Lecture') : t('Pause')}</button></div></div>` : ''}
    <p class="row__sub row__sub--wrap" style="text-align:center;margin-top:12px">${t('Touchez une porte sur le schéma pour l\'ouvrir ou la fermer.')}</p></div>`;
  $$('[data-door]', body).forEach(el => el.addEventListener('click', () => { const i = +el.dataset.door; remoteAct(netId, 'door', { index: i, open: !st.doors?.[i] }); }));
  $$('[data-color]', body).forEach(el => el.onclick = () => remoteAct(netId, 'neonColor', CPR.colors[+el.dataset.color]));
  $$('[data-r]', body).forEach(el => el.onclick = async () => {
    const a = el.dataset.r;
    if (a === 'lock') remoteAct(netId, 'lock', !st.locked);
    else if (a === 'engine') remoteAct(netId, 'engine', !st.engine);
    else if (a === 'lights') remoteAct(netId, 'lights', !st.lights);
    else if (a === 'neon') remoteAct(netId, 'neon', !st.neon);
    else if (a === 'doorsAll') remoteAct(netId, 'doorsAll', !doorsOpen);
    else if (a === 'windowsAll') remoteAct(netId, 'windowsAll', !winOpen);
    else if (a === 'alarm') { remoteAct(netId, 'alarm'); notify({ app: 'carplay', title: t('Alarme déclenchée'), text: esc(v.name || '') }); }
    else if (a === 'musicToggle') remoteAct(netId, m.paused ? 'musicResume' : 'musicPause');
    else if (a === 'ping') { remoteAct(netId, 'ping'); if (CPR.pos?.x) post('waypointTo', CPR.pos); notify({ app: 'carplay', title: t('Véhicule localisé'), text: t('Il clignote et klaxonne. Itinéraire ajouté au GPS.') }); }
    else if (a === 'summon') {
      el.disabled = true;
      const r = IS_BROWSER ? { ok: true } : await post('carplaySummon', { netId });
      if (!r.ok) { notify({ app: 'carplay', title: 'CarPlay', text: t(r.error || 'Action impossible') }); el.disabled = false; }
      else { el.innerHTML = `${icon('car')}${t('En route vers vous…')}`; }
    }
    else if (a === 'music') {
      if (m) return remoteAct(netId, 'musicStop');
      openSheet(t('Musique dans le véhicule'), `<div class="form"><input class="field" id="rm-link" placeholder="${t('Collez un lien YouTube ou audio')}">
        <p class="error-text" id="rm-err"></p><button class="btn btn--block" id="rm-go">${icon('play')}${t('Lancer')}</button></div>`, (sh) => {
        $('#rm-go', sh).onclick = async () => {
          $('#rm-err', sh).textContent = t('Recherche du morceau…');
          const r = await remoteAct(netId, 'music', $('#rm-link', sh).value.trim());
          if (r.ok) closeSheet(); else $('#rm-err', sh).textContent = t(r.error || 'Lecture impossible');
        };
      });
    }
  });
}
