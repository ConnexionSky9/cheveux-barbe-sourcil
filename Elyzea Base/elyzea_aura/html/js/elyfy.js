'use strict';
/* =========================================================
   ELYFY : streaming musical (aux couleurs d'Elyzea) + studio IA
   Accueil (récents, tendances, créations de la ville, mixes), Rechercher (genres, titres, lien collé),
   Bibliothèque (titres likés, téléchargements, playlists), Studio IA (paroles + instru → chanson),
   lecteur plein écran et mini-lecteur. La lecture passe par le lecteur du téléphone (Music) :
   haut-parleur, île dynamique et commandes communes avec Itoune.
   Toutes les données viennent du serveur (server/elyfy.lua).
   ========================================================= */
const EF = {
  ready: false, tok: 0, init: null, states: {}, np: false, from: '', rehosting: {}, studio: null,
};
const efApi = (name, args = {}) => IS_BROWSER ? EFMock.call(name, args) : api(name, args);

/* ---------- Icônes ---------- */
const EFI = {
  home: '<path d="M3.5 10.5 12 3.5l8.5 7V20a1 1 0 0 1-1 1H15v-6H9v6H4.5a1 1 0 0 1-1-1z"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20.5 20.5-4-4"/>',
  library: '<path d="M4.5 3.5v17M9 3.5v17M13.5 4.2l5.8 15.8"/>',
  studio: '<path d="M12 3.5v4M12 16.5v4M3.5 12h4M16.5 12h4M6 6l2.5 2.5M15.5 15.5 18 18M6 18l2.5-2.5M15.5 8.5 18 6"/>',
  heart: '<path d="M12 20.5s-7.6-4.6-9.4-9.3C1.3 7.8 3.6 4.5 7 4.5c2 0 3.6 1.1 5 3 1.4-1.9 3-3 5-3 3.4 0 5.7 3.3 4.4 6.7-1.8 4.7-9.4 9.3-9.4 9.3z"/>',
  play: '<path d="M7 4.8v14.4L19.5 12z" fill="currentColor"/>',
  pause: '<rect x="6" y="4.5" width="4" height="15" rx="1.2" fill="currentColor" stroke="none"/><rect x="14" y="4.5" width="4" height="15" rx="1.2" fill="currentColor" stroke="none"/>',
  next: '<path d="M5 5v14l10-7z" fill="currentColor"/><path d="M18.5 5v14"/>',
  prev: '<path d="M19 5v14L9 12z" fill="currentColor"/><path d="M5.5 5v14"/>',
  shuffle: '<path d="M3 7h3.5c2 0 3.3 1 4.3 2.7l2.4 4.6c1 1.7 2.3 2.7 4.3 2.7H21"/><path d="M3 17h3.5c1.6 0 2.7-.6 3.6-1.7M14 8.7c.9-1.1 2-1.7 3.5-1.7H21"/><path d="m18 4 3 3-3 3M18 14l3 3-3 3"/>',
  repeat: '<path d="M4 11V9a3 3 0 0 1 3-3h13"/><path d="m17 3 3 3-3 3"/><path d="M20 13v2a3 3 0 0 1-3 3H4"/><path d="m7 21-3-3 3-3"/>',
  down: '<path d="M12 3.5v12M7 11l5 5 5-5M5 20.5h14"/>',
  downOk: '<circle cx="12" cy="12" r="9" fill="currentColor" stroke="none"/><path d="M12 7.5v8M8.5 12.5 12 16l3.5-3.5" stroke="#0B0716" stroke-width="2.2"/>',
  more: '<circle cx="5" cy="12" r="1.5" fill="currentColor"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/><circle cx="19" cy="12" r="1.5" fill="currentColor"/>',
  chevron: '<path d="m6 9 6 6 6-6"/>',
  back: '<path d="m15 5-7 7 7 7"/>',
  plus: '<path d="M12 5.5v13M5.5 12h13"/>',
  queue: '<path d="M4 6h12M4 11h12M4 16h7"/><path d="M16 14v6l4-3z" fill="currentColor"/>',
  speaker: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11"/>',
  lyrics: '<path d="M4 6h16M4 11h16M4 16h10"/>',
  trash: '<path d="M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
  link: '<path d="M10 14a4.5 4.5 0 0 0 6.4 0l3-3a4.5 4.5 0 0 0-6.4-6.4l-1.2 1.2"/><path d="M14 10a4.5 4.5 0 0 0-6.4 0l-3 3a4.5 4.5 0 0 0 6.4 6.4l1.2-1.2"/>',
  spark: '<path d="M12 2.5 13.8 9 20.5 11 13.8 13 12 19.5 10.2 13 3.5 11 10.2 9z" fill="currentColor"/><path d="M19 3v4M17 5h4" />',
  globe: '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.4 2.4 3.5 5.2 3.5 8.5s-1.1 6.1-3.5 8.5c-2.4-2.4-3.5-5.2-3.5-8.5S9.6 5.9 12 3.5z"/>',
  mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5v3.5"/>',
  upload: '<path d="M12 16V4.5M7 9.5l5-5 5 5M5 20.5h14"/>',
};
const efIco = (n, cls = '') => `<svg class="efi ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${EFI[n] || ''}</svg>`;
const efWord = () => `<span class="ef-word">Ely<b>Fy</b></span>`;
const efErr = (r) => t(r?.error || 'Action impossible pour le moment.');
const efN = (n) => (Number(n) || 0) <= 1 ? t('{n} titre', { n: Number(n) || 0 }) : t('{n} titres', { n: Number(n) });
function efToast(text) { notify({ app: 'elyfy', title: 'ElyFy', text }); }
const SRC = { audius: 'Audius', youtube: 'YouTube', ai: 'IA', city: 'Ville', catalog: 'Elyzea', link: 'Lien', spotify: 'Spotify' };

// Pochette : image du titre, sinon dégradé généré à partir du titre (même rendu partout)
function efArt(tr, size = 48, cls = '') {
  const c1 = avColor((tr?.title || '') + 'a'), c2 = avColor((tr?.artist || '') + (tr?.title || '') + 'z');
  const img = tr?.thumb ? `<img src="${esc(tr.thumb)}" alt="" loading="lazy" onerror="this.remove()">` : '';
  const icon = tr?.ai ? efIco('spark') : efIco('heart', 'ef-art__h');
  return `<span class="ef-art ${cls}" style="--s:${size}px;--c1:${c1};--c2:${c2}"><i>${tr?.ai ? efIco('spark') : `<b>${esc(initials(tr?.title || '♪'))}</b>`}</i>${img}</span>`;
}
const isCur = (tr) => Music.owner === 'elyfy' && Music.track && tr && Music.track.key === tr.key;

/* ---------- Lecture (lecteur du téléphone) ---------- */
function efPlay(list, i, from = '') {
  if (!list || !list.length) return;
  Music.owner = 'elyfy';
  Music.queue = list.map(x => Object.assign({}, x));
  EF.from = from;
  if (typeof Music.play === 'function') Music.play(i || 0);
  efSync();
}
function efShuffle(list, from) {
  if (!list.length) return;
  Music.shuffle = true;
  efPlay(list, Math.floor(Math.random() * list.length), from);
}
function efOnPlay(tr) { if (tr?.key) efApi('efPlayed', { key: tr.key }); }
function efToggleLike(tr, after) {
  if (!tr?.key) return;
  const on = !(EF.states[tr.key]?.liked);
  efApi('efLike', { key: tr.key, like: on }).then(r => {
    if (!r.ok) return efToast(efErr(r));
    EF.states[tr.key] = Object.assign({}, EF.states[tr.key], { liked: r.liked });
    efToast(r.liked ? t('Ajouté aux titres likés') : t('Retiré des titres likés'));
    efSync(); after?.();
  });
}
async function efDownload(tr, after) {
  const dl = EF.init?.downloads || {};
  if (!dl.allowed) return efToast(t('Téléchargement disponible à partir de l\'ElyAura {n}', { n: dl.minTier || 4 }));
  const on = !!EF.states[tr.key]?.downloaded;
  const r = await efApi('efDownload', { key: tr.key, remove: on || undefined });
  if (!r.ok) return efToast(efErr(r));
  EF.states[tr.key] = Object.assign({}, EF.states[tr.key], { downloaded: r.downloaded });
  if (r.downloads) EF.init.downloads = r.downloads;
  efToast(r.downloaded ? t('Téléchargé sur votre téléphone') : t('Supprimé du téléphone'));
  efSync(); after?.();
}
async function efLoadStates() { const r = await efApi('efStates'); if (r.ok) EF.states = r.states || {}; }

/* ---------- Navigation ---------- */
const EF_ROOTS = ['home', 'search', 'library', 'studio'];
function efGo(page, params = {}) { openApp('elyfy', Object.assign({ page }, params)); }
function efTab(page) {
  closeSheet(true); efCloseNow();
  const first = S.stack.findIndex(e => e.id === 'elyfy');
  if (first >= 0) { S.stack.length = first + 1; S.stack[first].params = { page }; }
  efRender({ page });
}
Views.elyfy = (params = {}) => { S.onLeave = () => { efCloseNow(); clearInterval(EF.poll); }; efRender(params); };

async function efRender(params = {}) {
  const tok = ++EF.tok;
  const page = params.page || 'home';
  if (!EF.ready) {
    efShell(page, loading());
    const [r] = await Promise.all([efApi('efInit'), efLoadStates()]);
    if (tok !== EF.tok) return;
    if (!r.ok) { efShell(page, empty(t('ElyFy indisponible'), efErr(r))); return; }
    EF.init = r; EF.ready = true;
  }
  const fn = EF_PAGES[page] || EF_PAGES.home;
  return fn(params, tok);
}

function efShell(page, body) {
  const root = EF_ROOTS.includes(page) ? page : null;
  const nav = (id, ic, label) => `<button class="ef-nav__b ${root === id ? 'active' : ''}" data-tab="${id}" aria-label="${t(label)}">${efIco(ic)}<small>${t(label)}</small></button>`;
  appView.innerHTML = `<div class="ef" data-page="${page}">
    <main class="ef-main" id="ef-main">${body}</main>
    <div id="ef-mini"></div>
    <nav class="ef-nav">${nav('home', 'home', 'Accueil')}${nav('search', 'search', 'Rechercher')}${nav('library', 'library', 'Bibliothèque')}${nav('studio', 'studio', 'Studio IA')}</nav>
  </div>`;
  $$('[data-tab]', appView).forEach(b => b.onclick = () => efTab(b.dataset.tab));
  efMini();
  clearInterval(EF.poll);
  EF.poll = setInterval(efProgress, 500);
  return $('#ef-main');
}
const efTop = (title, right = '') => `<header class="ef-top"><button class="ef-ib" data-back aria-label="${t('Retour')}">${efIco('back')}</button><h1 class="ef-title">${title}</h1><div class="ef-top__r">${right}</div></header>`;

/* ---------- Lignes et cartes ---------- */
const EFL = {};   // listes affichées (pour lire « à partir de » une ligne)
function efRow(tr, list, i, opts = {}) {
  const st = EF.states[tr.key] || {};
  return `<div class="ef-row ${isCur(tr) ? 'cur' : ''}" data-row="${list}:${i}">
    ${efArt(tr, 46)}
    <span class="ef-row__t"><b>${esc(tr.title)}</b><small>${st.downloaded ? `<em class="ef-dl">${efIco('downOk')}</em>` : ''}${tr.ai ? '<em class="ef-tag ef-tag--ai">IA</em>' : ''}${esc(tr.artist)}${opts.src && tr.source ? ` · ${SRC[tr.source] || ''}` : ''}</small></span>
    <button class="ef-ib ef-ib--sm" data-menu="${list}:${i}" aria-label="${t('Options')}">${efIco('more')}</button></div>`;
}
function efRows(list, key, opts) {
  EFL[key] = list;
  return list.length ? list.map((tr, i) => efRow(tr, key, i, opts)).join('') : (opts?.empty || `<p class="ef-muted ef-empty">${t('Aucun titre')}</p>`);
}
function efCards(list, key) {
  EFL[key] = list;
  return `<div class="ef-carousel">${list.map((tr, i) => `<button class="ef-card" data-row="${key}:${i}">${efArt(tr, 132, 'ef-art--card')}<b>${esc(tr.title)}</b><small>${esc(tr.artist)}</small></button>`).join('')}</div>`;
}
function efWire(root) {
  $$('[data-row]', root).forEach(el => el.onclick = (e) => {
    if (e.target.closest('[data-menu]')) return;
    const [k, i] = el.dataset.row.split(':'); efPlay(EFL[k], +i, k);
  });
  $$('[data-menu]', root).forEach(b => b.onclick = (e) => { e.stopPropagation(); const [k, i] = b.dataset.menu.split(':'); efMenu(EFL[k][+i], { list: k }); });
}

/* ---------- Menu d'un titre ---------- */
function efMenu(tr, ctx = {}) {
  const st = EF.states[tr.key] || {};
  const dl = EF.init?.downloads || {};
  openSheet('', `<div class="ef-mh">${efArt(tr, 54)}<span><b>${esc(tr.title)}</b><small>${esc(tr.artist)} · ${SRC[tr.source] || ''}</small></span></div>
    <div class="ef-menu">
      <button data-a="like">${efIco('heart', st.liked ? 'on' : '')}${st.liked ? t('Retirer des titres likés') : t('Ajouter aux titres likés')}</button>
      <button data-a="pl">${efIco('plus')}${t('Ajouter à une playlist')}</button>
      <button data-a="queue">${efIco('queue')}${t('Ajouter à la file d\'attente')}</button>
      <button data-a="dl" class="${dl.allowed ? '' : 'locked'}">${efIco(st.downloaded ? 'downOk' : 'down')}${st.downloaded ? t('Supprimer du téléphone') : t('Télécharger')}${dl.allowed ? '' : `<small>${efIco('lock')}ElyAura ${dl.minTier || 4}+</small>`}</button>
      ${tr.lyrics ? `<button data-a="lyrics">${efIco('lyrics')}${t('Voir les paroles')}</button>` : ''}
      ${ctx.playlist ? `<button data-a="rm" class="danger">${efIco('trash')}${t('Retirer de cette playlist')}</button>` : ''}
    </div>`, (sh) => {
    sh.classList.add('ef-sheet');
    $$('[data-a]', sh).forEach(b => b.onclick = async () => {
      const a = b.dataset.a;
      if (a === 'like') { closeSheet(); efToggleLike(tr, () => ctx.refresh?.()); }
      if (a === 'pl') efPickPlaylist(tr);
      if (a === 'queue') {
        closeSheet();
        if (Music.owner !== 'elyfy' || !Music.queue.length) efPlay([tr], 0);
        else { Music.queue.splice(Music.index + 1, 0, Object.assign({}, tr)); efToast(t('Ajouté à la file d\'attente')); }
      }
      if (a === 'dl') { closeSheet(); efDownload(tr, () => ctx.refresh?.()); }
      if (a === 'lyrics') efLyrics(tr);
      if (a === 'rm') { closeSheet(); await efApi('efPlaylistRemove', { id: ctx.playlist, key: tr.key }); ctx.refresh?.(); }
    });
  });
}
function efLyrics(tr) {
  openSheet(esc(tr.title), `<div class="ef-lyrics">${esc(tr.lyrics || '').replace(/\[([^\]]+)\]/g, '<em>$1</em>').replace(/\n/g, '<br>')}</div>`, (sh) => sh.classList.add('ef-sheet'));
}
async function efPickPlaylist(tr) {
  const r = await efApi('efPlaylists');
  openSheet(t('Ajouter à une playlist'), `<button class="ef-newpl" data-new>${efIco('plus')}${t('Nouvelle playlist')}</button>
    ${(r.playlists || []).map(p => `<button class="ef-lrow" data-pl="${p.id}">${efArt({ title: p.name, artist: '', thumb: p.thumb }, 44)}<span><b>${esc(p.name)}</b><small>${efN(p.n)}</small></span></button>`).join('')}`, (sh) => {
    sh.classList.add('ef-sheet');
    const add = async (id) => {
      const x = await efApi('efPlaylistAdd', { id, key: tr.key });
      closeSheet();
      efToast(!x.ok ? efErr(x) : x.added ? t('Ajouté à « {n} »', { n: x.name }) : t('Déjà dans « {n} »', { n: x.name }));
    };
    $$('[data-pl]', sh).forEach(b => b.onclick = () => add(+b.dataset.pl));
    $('[data-new]', sh).onclick = () => efNewPlaylist((id) => add(id));
  });
}
function efNewPlaylist(onDone) {
  openSheet(t('Nouvelle playlist'), `<input class="field" id="ef-pln" maxlength="50" placeholder="${t('Ma playlist n°1')}"><button class="btn btn--block ef-grad" id="ef-plgo" style="margin-top:12px">${t('Créer')}</button>`, (sh) => {
    sh.classList.add('ef-sheet');
    const go = async () => {
      const r = await efApi('efPlaylistCreate', { name: $('#ef-pln', sh).value });
      if (!r.ok) return efToast(efErr(r));
      closeSheet(true);
      if (onDone) onDone(r.id); else efGo('playlist', { id: r.id });
    };
    $('#ef-plgo', sh).onclick = go;
    $('#ef-pln', sh).onkeydown = (e) => { if (e.key === 'Enter') go(); };
  });
}

/* =========================================================
   MINI-LECTEUR ET LECTEUR PLEIN ÉCRAN
   ========================================================= */
function efMini() {
  const box = $('#ef-mini'); if (!box) return;
  const tr = Music.owner === 'elyfy' ? Music.track : null;
  if (!tr) { box.innerHTML = ''; return; }
  const liked = EF.states[tr.key]?.liked;
  box.innerHTML = `<div class="ef-mini" style="--c1:${avColor(tr.title + 'a')}">
    <button class="ef-mini__open" data-np>${efArt(tr, 40)}<span><b>${esc(tr.title)}</b><small>${esc(tr.artist)}</small></span></button>
    <button class="ef-ib ef-ib--sm ${liked ? 'on' : ''}" data-mlike aria-label="${t('J\'aime')}">${efIco('heart')}</button>
    <button class="ef-ib" data-mplay aria-label="${Music.playing ? t('Pause') : t('Lecture')}">${efIco(Music.playing ? 'pause' : 'play')}</button>
    <i class="ef-mini__bar"><b id="ef-mbar"></b></i></div>`;
  $('[data-np]', box).onclick = () => efOpenNow();
  $('[data-mplay]', box).onclick = () => Music.toggle();
  $('[data-mlike]', box).onclick = () => efToggleLike(tr);
  efProgress();
}
function efProgress() {
  const p = Music.dur > 0 ? Math.min(100, (Music.time / Music.dur) * 100) : 0;
  const mb = $('#ef-mbar'); if (mb) mb.style.width = `${p}%`;
  const bar = $('#ef-np-bar');
  if (bar && document.activeElement !== bar && Music.dur > 0) bar.value = Math.round(p * 10);
  const c = $('#ef-np-cur'), d = $('#ef-np-dur');
  if (c) c.textContent = duration(Math.floor(Music.time || 0));
  if (d) d.textContent = Music.dur ? duration(Math.floor(Music.dur)) : '--:--';
}
// Appelé par le lecteur du téléphone à chaque changement (lecture, pause, titre suivant…)
function efSync() {
  if (S.currentApp !== 'elyfy') return;
  efMini();
  if (EF.np) efRenderNow();
  $$('.ef-row').forEach(r => { const [k, i] = (r.dataset.row || ':').split(':'); r.classList.toggle('cur', isCur(EFL[k]?.[+i])); });
}
function efOpenNow() {
  if (!Music.track) return;
  EF.np = true;
  let el = $('#ef-np');
  if (!el) { el = document.createElement('div'); el.id = 'ef-np'; el.className = 'ef-np'; $('.ef')?.appendChild(el); }
  efRenderNow();
  requestAnimationFrame(() => el.classList.add('show'));
}
function efCloseNow() {
  EF.np = false;
  const el = $('#ef-np'); if (!el) return;
  el.classList.remove('show'); setTimeout(() => el.remove(), 260);
}
function efRenderNow() {
  const el = $('#ef-np'), tr = Music.track; if (!el || !tr) return;
  const st = EF.states[tr.key] || {};
  const dl = EF.init?.downloads || {};
  el.style.setProperty('--c1', avColor(tr.title + 'a'));
  el.style.setProperty('--c2', avColor((tr.artist || '') + tr.title + 'z'));
  el.innerHTML = `<header class="ef-np__h"><button class="ef-ib" data-close aria-label="${t('Fermer')}">${efIco('chevron')}</button>
      <span><small>${t('Lecture depuis')}</small><b>${esc(EF_FROM[EF.from] || t('ElyFy'))}</b></span>
      <button class="ef-ib" data-more aria-label="${t('Options')}">${efIco('more')}</button></header>
    <div class="ef-np__art ${Music.playing ? 'live' : ''}">${efArt(tr, 260, 'ef-art--np')}</div>
    <div class="ef-np__info"><span><b>${esc(tr.title)}</b><small>${tr.ai ? '<em class="ef-tag ef-tag--ai">IA</em>' : ''}${esc(tr.artist)}</small></span>
      <button class="ef-ib ${st.liked ? 'on' : ''}" data-like aria-label="${t('J\'aime')}">${efIco('heart')}</button></div>
    <input type="range" class="ef-np__bar" id="ef-np-bar" min="0" max="1000" value="0" aria-label="${t('Position')}">
    <div class="ef-np__times"><span id="ef-np-cur">0:00</span><span id="ef-np-dur">--:--</span></div>
    <div class="ef-np__ctl">
      <button class="ef-ib ${Music.shuffle ? 'on' : ''}" data-shuffle aria-label="${t('Aléatoire')}">${efIco('shuffle')}</button>
      <button class="ef-ib ef-ib--lg" data-prev aria-label="${t('Précédent')}">${efIco('prev')}</button>
      <button class="ef-play" data-toggle aria-label="${Music.playing ? t('Pause') : t('Lecture')}">${efIco(Music.playing ? 'pause' : 'play')}</button>
      <button class="ef-ib ef-ib--lg" data-next aria-label="${t('Suivant')}">${efIco('next')}</button>
      <button class="ef-ib ${Music.repeat !== 'off' ? 'on' : ''} ${Music.repeat === 'one' ? 'one' : ''}" data-repeat aria-label="${t('Répéter')}">${efIco('repeat')}</button>
    </div>
    <div class="ef-np__foot">
      <button class="ef-pill ${Music.speaker ? 'on' : ''}" data-speaker>${efIco('speaker')}${Music.speaker ? t('Haut-parleur') : t('Pour moi')}</button>
      <button class="ef-ib ${st.downloaded ? 'on' : ''} ${dl.allowed ? '' : 'dim'}" data-dl aria-label="${t('Télécharger')}">${efIco(st.downloaded ? 'downOk' : 'down')}</button>
      <button class="ef-ib" data-queue aria-label="${t('File d\'attente')}">${efIco('queue')}</button>
    </div>
    ${tr.lyrics ? `<section class="ef-np__lyr"><h3>${t('Paroles')}</h3><div>${esc(tr.lyrics).replace(/\[([^\]]+)\]/g, '<em>$1</em>').replace(/\n/g, '<br>')}</div></section>` : ''}`;
  $('[data-close]', el).onclick = () => efCloseNow();
  $('[data-more]', el).onclick = () => efMenu(tr);
  $('[data-like]', el).onclick = () => efToggleLike(tr);
  $('[data-toggle]', el).onclick = () => Music.toggle();
  $('[data-next]', el).onclick = () => Music.next();
  $('[data-prev]', el).onclick = () => Music.prev();
  $('[data-shuffle]', el).onclick = () => { Music.shuffle = !Music.shuffle; efRenderNow(); };
  $('[data-repeat]', el).onclick = () => { Music.repeat = Music.repeat === 'all' ? 'one' : Music.repeat === 'one' ? 'off' : 'all'; efRenderNow(); efToast({ all: t('Répéter la file'), one: t('Répéter ce titre'), off: t('Répétition désactivée') }[Music.repeat]); };
  $('[data-speaker]', el).onclick = () => Music.setSpeaker(!Music.speaker);
  $('[data-dl]', el).onclick = () => efDownload(tr);
  $('[data-queue]', el).onclick = () => efQueue();
  $('#ef-np-bar', el).onchange = (e) => { if (Music.dur) Music.seek(e.target.value / 1000 * Music.dur); };
  efProgress();
}
const EF_FROM = { trend: 'Tendances', city: 'Créations de la ville', fresh: 'Nouveautés de la ville', recent: 'Écoutés récemment', liked: 'Titres likés',
  dl: 'Téléchargements', search: 'Recherche', yt: 'Recherche', cityS: 'Recherche', genre: 'Genre', pl: 'Playlist', mine: 'Mes créations', cat: 'Sélection Elyzea', link: 'Lien' };
function efQueue() {
  const q = Music.queue, i = Music.index;
  openSheet(t('File d\'attente'), `<p class="ef-lbl">${t('En cours')}</p>${q[i] ? efRow(q[i], 'q', i) : ''}
    <p class="ef-lbl">${t('À suivre')}</p>${q.slice(i + 1).map((tr, k) => efRow(tr, 'q', i + 1 + k)).join('') || `<p class="ef-muted ef-empty">${t('Fin de la file')}</p>`}`, (sh) => {
    sh.classList.add('ef-sheet');
    EFL.q = q;
    $$('[data-row]', sh).forEach(el => el.onclick = (e) => { if (e.target.closest('[data-menu]')) return; closeSheet(); Music.play(+el.dataset.row.split(':')[1]); });
    $$('[data-menu]', sh).forEach(b => b.onclick = () => efMenu(q[+b.dataset.menu.split(':')[1]]));
  });
}

/* =========================================================
   ACCUEIL
   ========================================================= */
function efHello() { const h = new Date().getHours(); return h < 5 ? t('Bonne nuit') : h < 18 ? t('Bonjour') : t('Bonsoir'); }
async function efHome(params, tok) {
  const main = efShell('home', `<header class="ef-home__h">${efWord()}<span class="ef-home__hi">${efHello()}</span></header><div class="ef-pad">${loading()}</div>`);
  const r = await efApi('efHome');
  if (tok !== EF.tok) return;
  const quick = [
    { id: 'liked', label: t('Titres likés'), cls: 'liked', icon: 'heart', go: () => efGo('liked') },
    { id: 'dl', label: t('Téléchargements'), cls: 'dl', icon: 'down', go: () => efGo('downloads') },
    { id: 'studio', label: t('Mes créations IA'), cls: 'ai', icon: 'spark', go: () => efTab('studio') },
    ...(r.playlists || []).slice(0, 3).map(p => ({ id: 'p' + p.id, label: p.name, cls: '', icon: 'library', go: () => efGo('playlist', { id: p.id }) })),
  ].slice(0, 6);
  const sec = (title, list, key, more = '') => list && list.length ? `<h2 class="ef-h2">${title}${more}</h2>${efCards(list, key)}` : '';
  $('.ef-pad', main).innerHTML = `<div class="ef-quick">${quick.map((q, i) => `<button class="ef-quick__b ${q.cls}" data-q="${i}"><span class="ef-quick__i">${efIco(q.icon)}</span><b>${esc(q.label)}</b></button>`).join('')}</div>
    ${sec(t('Écoutés récemment'), r.recent, 'recent')}
    ${sec(t('Créations de la ville'), r.city, 'city', ` <button class="ef-more" data-genre="ville">${t('Tout voir')}</button>`)}
    ${sec(t('Sélection Elyzea'), r.catalog, 'cat')}
    ${sec(t('Tendances de la semaine'), r.trending, 'trend')}
    ${sec(t('Nouveautés de la ville'), r.fresh, 'fresh')}
    <h2 class="ef-h2">${t('Vos mixes')}</h2>
    <div class="ef-carousel">${(r.mixes || []).map(m => `<button class="ef-mix" data-genre="${m.id}" style="--g:${m.color}"><span>${esc(m.label)}</span><small>${t('Mix')}</small></button>`).join('')}</div>
    ${!(r.trending || []).length && !(r.city || []).length ? `<p class="ef-muted ef-empty">${t('Le catalogue se charge… Cherchez un titre ou créez le vôtre avec le studio IA.')}</p>` : ''}`;
  $$('[data-q]', main).forEach(b => b.onclick = () => quick[+b.dataset.q].go());
  $$('[data-genre]', main).forEach(b => b.onclick = () => efGo('genre', { id: b.dataset.genre }));
  efWire(main);
}

/* =========================================================
   RECHERCHER
   ========================================================= */
async function efSearch(params, tok) {
  const main = efShell('search', `<header class="ef-top ef-top--big"><h1 class="ef-title">${t('Rechercher')}</h1></header>
    <div class="ef-sbar">${efIco('search')}<input id="ef-q" placeholder="${t('Que souhaitez-vous écouter ?')}" autocomplete="off" value="${esc(params.q || '')}"></div>
    <div class="ef-pad" id="ef-sbody"></div>`);
  const body = $('#ef-sbody');
  const browse = () => {
    body.innerHTML = `<h2 class="ef-h2">${t('Parcourir tout')}</h2><div class="ef-genres">${(EF.init.genres || []).map(g => `<button class="ef-genre" data-genre="${g.id}" style="--g:${g.color}"><b>${esc(t(g.label))}</b><i>${efIco(g.id === 'ville' ? 'spark' : 'library')}</i></button>`).join('')}</div>
      <p class="ef-hint">${efIco('link')}${t('Astuce : collez un lien YouTube, Spotify ou audio dans la recherche pour l\'écouter.')}</p>`;
    $$('[data-genre]', body).forEach(b => b.onclick = () => efGo('genre', { id: b.dataset.genre }));
  };
  const run = async (q) => {
    if (/^https:\/\//i.test(q)) {
      body.innerHTML = loading();
      const r = await efApi('efLink', { link: q });
      if ($('#ef-q')?.value.trim() !== q) return;
      body.innerHTML = r.ok ? `<h2 class="ef-h2">${t('Lien')}</h2>${efRows([r.track], 'link', { src: true })}` : `<p class="ef-muted ef-empty">${efErr(r)}</p>`;
      efWire(body); return;
    }
    body.innerHTML = loading();
    const r = await efApi('efSearch', { q });
    if ($('#ef-q')?.value.trim() !== q) return;
    const html = [
      (r.city || []).length ? `<h2 class="ef-h2">${t('De la ville')}</h2>${efRows(r.city, 'cityS', { src: true })}` : '',
      (r.tracks || []).length ? `<h2 class="ef-h2">${t('Titres')}</h2>${efRows(r.tracks, 'search', { src: true })}` : '',
      (r.youtube || []).length ? `<h2 class="ef-h2">${t('Sur YouTube')}</h2>${efRows(r.youtube, 'yt', { src: true })}` : '',
    ].join('');
    body.innerHTML = html || `<p class="ef-muted ef-empty">${t('Aucun résultat pour « {q} »', { q: esc(q) })}</p>`;
    efWire(body);
  };
  let tm;
  $('#ef-q').oninput = (e) => {
    clearTimeout(tm);
    const q = e.target.value.trim();
    const cur = S.stack[S.stack.length - 1]; if (cur?.id === 'elyfy') cur.params = Object.assign({}, cur.params, { q });
    tm = setTimeout(() => q.length >= 2 ? run(q) : browse(), 350);
  };
  if ((params.q || '').length >= 2) run(params.q); else browse();
}

/* ---------- Listes : genre, titres likés, téléchargements, playlist ---------- */
function efListPage(page, { title, sub, cover, list, key, menuCtx, right = '', emptyMsg, coverIcon = 'library', color }) {
  const main = efShell(page, `${efTop('', right)}<section class="ef-lhead" style="--g:${color || avColor(title)}">
      <div class="ef-lhead__cover">${cover || `<span class="ef-cover">${efIco(coverIcon)}</span>`}</div>
      <h1>${esc(title)}</h1><p>${sub}</p>
      <div class="ef-lhead__btns">
        <button class="ef-ib" data-shuf aria-label="${t('Lecture aléatoire')}">${efIco('shuffle')}</button>
        <button class="ef-play" data-playall aria-label="${t('Lecture')}">${efIco('play')}</button></div></section>
    <div class="ef-pad">${efRows(list, key, { empty: `<p class="ef-muted ef-empty">${emptyMsg}</p>`, src: true })}</div>`);
  $('[data-playall]', main).onclick = () => { Music.shuffle = false; efPlay(list, 0, key); };
  $('[data-shuf]', main).onclick = () => efShuffle(list, key);
  efWire(main);
  if (menuCtx) $$('[data-menu]', main).forEach(b => b.onclick = (e) => { e.stopPropagation(); efMenu(list[+b.dataset.menu.split(':')[1]], menuCtx); });
  return main;
}
async function efGenre(params, tok) {
  efShell('genre', `${efTop('')}${loading()}`);
  const r = await efApi('efGenre', { id: params.id });
  if (tok !== EF.tok) return;
  if (!r.ok) { efShell('genre', `${efTop('')}${empty(t('Genre indisponible'), efErr(r))}`); return; }
  efListPage('genre', { title: t(r.genre.label), sub: efN(r.tracks.length), list: r.tracks, key: 'genre', color: r.genre.color, coverIcon: r.genre.id === 'ville' ? 'spark' : 'library',
    emptyMsg: r.genre.id === 'ville' ? t('Aucune création publiée pour l\'instant. Lancez-vous avec le studio IA !') : t('Catalogue indisponible pour le moment.') });
}
async function efLiked(params, tok) {
  efShell('liked', loading());
  const r = await efApi('efLiked');
  if (tok !== EF.tok) return;
  efListPage('liked', { title: t('Titres likés'), sub: efN((r.tracks || []).length), list: r.tracks || [], key: 'liked', color: '#7B2FF7', coverIcon: 'heart',
    menuCtx: { refresh: () => efLiked(params, EF.tok) }, emptyMsg: t('Appuyez sur le cœur d\'un titre pour le retrouver ici.') });
}
async function efDownloads(params, tok) {
  efShell('downloads', loading());
  const r = await efApi('efDownloads');
  if (tok !== EF.tok) return;
  const d = r.downloads || EF.init.downloads || {};
  if (r.downloads) EF.init.downloads = r.downloads;
  const sub = d.allowed ? t('{n} / {m} titres sur ce téléphone', { n: d.count, m: d.max }) : t('Disponible à partir de l\'ElyAura {n}', { n: d.minTier || 4 });
  const main = efListPage('downloads', { title: t('Téléchargements'), sub, list: r.tracks || [], key: 'dl', color: '#3EE6B0', coverIcon: 'down',
    menuCtx: { refresh: () => efDownloads(params, EF.tok) },
    emptyMsg: d.allowed ? t('Téléchargez vos titres préférés : ils restent sur votre téléphone.') : t('Votre téléphone ne permet pas de télécharger de la musique. Passez à l\'ElyAura {n} ou plus.', { n: d.minTier || 4 }) });
  if (d.allowed) $('.ef-lhead', main).insertAdjacentHTML('beforeend', `<div class="ef-storage"><i style="width:${Math.min(100, (d.count / Math.max(1, d.max)) * 100)}%"></i></div>`);
}
async function efPlaylistPage(params, tok) {
  efShell('playlist', loading());
  const r = await efApi('efPlaylist', { id: params.id });
  if (tok !== EF.tok) return;
  if (!r.ok) { efShell('playlist', `${efTop('')}${empty(t('Playlist introuvable'), efErr(r))}`); return; }
  const p = r.playlist;
  const first = p.tracks.find(x => x.thumb);
  const main = efListPage('playlist', { title: p.name, sub: efN(p.tracks.length), list: p.tracks, key: 'pl', cover: first ? efArt(first, 150) : null,
    right: `<button class="ef-ib" data-plmenu aria-label="${t('Options')}">${efIco('more')}</button>`,
    menuCtx: { playlist: p.id, refresh: () => efPlaylistPage(params, EF.tok) }, emptyMsg: t('Ajoutez des titres avec le menu « … » d\'un titre.') });
  $('[data-plmenu]', main).onclick = () => openSheet('', `<div class="ef-menu">
      <button data-ren>${efIco('edit')}${t('Renommer')}</button><button data-del class="danger">${efIco('trash')}${t('Supprimer la playlist')}</button></div>`, (sh) => {
    sh.classList.add('ef-sheet');
    $('[data-ren]', sh).onclick = () => openSheet(t('Renommer'), `<input class="field" id="ef-rn" maxlength="50" value="${esc(p.name)}"><button class="btn btn--block ef-grad" id="ef-rngo" style="margin-top:12px">${t('Enregistrer')}</button>`, (s2) => {
      s2.classList.add('ef-sheet');
      $('#ef-rngo', s2).onclick = async () => { const x = await efApi('efPlaylistRename', { id: p.id, name: $('#ef-rn', s2).value }); if (!x.ok) return efToast(efErr(x)); closeSheet(); efPlaylistPage(params, EF.tok); };
    });
    $('[data-del]', sh).onclick = () => confirmSheet(t('Supprimer « {n} » ?', { n: p.name }), t('Les titres restent disponibles dans ElyFy.'), t('Supprimer'), async () => { await efApi('efPlaylistDelete', { id: p.id }); back(); });
  });
}

/* =========================================================
   BIBLIOTHÈQUE
   ========================================================= */
async function efLibrary(params, tok) {
  const main = efShell('library', `<header class="ef-top ef-top--big"><h1 class="ef-title">${t('Bibliothèque')}</h1><div class="ef-top__r"><button class="ef-ib" data-newpl aria-label="${t('Nouvelle playlist')}">${efIco('plus')}</button></div></header><div class="ef-pad">${loading()}</div>`);
  $('[data-newpl]', main).onclick = () => efNewPlaylist();
  const r = await efApi('efPlaylists');
  if (tok !== EF.tok) return;
  const d = r.downloads || {};
  if (r.downloads) EF.init.downloads = r.downloads;
  $('.ef-pad', main).innerHTML = `
    <button class="ef-lrow" data-go="liked"><span class="ef-cover ef-cover--liked">${efIco('heart')}</span><span><b>${t('Titres likés')}</b><small>${`${t('Playlist')} · ${efN(r.liked || 0)}`}</small></span></button>
    <button class="ef-lrow" data-go="downloads"><span class="ef-cover ef-cover--dl">${efIco('down')}</span><span><b>${t('Téléchargements')}</b>
      <small>${d.allowed ? t('{n} / {m} sur ce téléphone', { n: d.count, m: d.max }) : `${efIco('lock')} ${t('ElyAura {n} et plus', { n: d.minTier || 4 })}`}</small></span></button>
    <button class="ef-lrow" data-go="studio"><span class="ef-cover ef-cover--ai">${efIco('spark')}</span><span><b>${t('Mes créations IA')}</b><small>${t('Studio IA')}</small></span></button>
    ${(r.playlists || []).map(p => `<button class="ef-lrow" data-pl="${p.id}">${efArt({ title: p.name, artist: '', thumb: p.thumb }, 56)}<span><b>${esc(p.name)}</b><small>${`${t('Playlist')} · ${efN(p.n)}`}</small></span></button>`).join('')}
    ${!(r.playlists || []).length ? `<button class="ef-newpl" data-newpl2>${efIco('plus')}${t('Créer une playlist')}</button>` : ''}`;
  $$('[data-go]', main).forEach(b => b.onclick = () => b.dataset.go === 'studio' ? efTab('studio') : efGo(b.dataset.go));
  $$('[data-pl]', main).forEach(b => b.onclick = () => efGo('playlist', { id: +b.dataset.pl }));
  $('[data-newpl2]', main)?.addEventListener('click', () => efNewPlaylist());
}

/* =========================================================
   STUDIO IA : paroles + instru → chanson
   ========================================================= */
const EF_STATUS = { queued: 'En file d\'attente', processing: 'Composition en cours…', ready_temp: 'Finalisation…', ready: 'Prête', failed: 'Échec' };
async function efStudio(params, tok) {
  const ai = EF.init.ai || {};
  const main = efShell('studio', `<section class="ef-hero"><div class="ef-hero__wave"><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
      <h1>${t('Studio IA')}</h1><p>${t('Écrivez vos paroles, choisissez une instru : l\'IA compose et chante votre chanson.')}</p>
      <button class="btn ef-grad" data-new ${ai.enabled ? '' : 'disabled'}>${efIco('spark')}${t('Nouvelle chanson')}</button>
      ${ai.enabled ? `<small>${t('{p} $ par chanson · {d} par jour · remboursé en cas d\'échec', { p: (ai.price || 0).toLocaleString(locale()), d: ai.daily })}</small>` : `<small>${t('Le studio IA n\'est pas encore activé sur ce serveur.')}</small>`}
    </section>
    <div class="ef-pad">
      <div class="ef-artist"><span>${efIco('mic')}<b>${t('Nom d\'artiste')}</b></span><button data-artist>${esc(EF.init.artist || '')} ${efIco('edit')}</button></div>
      <h2 class="ef-h2">${t('Mes créations')}</h2><div id="ef-cr">${loading()}</div>
      <button class="ef-newpl" data-upload>${efIco('upload')}${t('Publier un titre (lien audio)')}</button></div>`);
  $('[data-new]', main).onclick = () => efGo('compose');
  $('[data-artist]', main).onclick = () => openSheet(t('Nom d\'artiste'), `<input class="field" id="ef-an" maxlength="40" value="${esc(EF.init.artist || '')}"><button class="btn btn--block ef-grad" id="ef-ango" style="margin-top:12px">${t('Enregistrer')}</button>`, (sh) => {
    sh.classList.add('ef-sheet');
    $('#ef-ango', sh).onclick = async () => { const r = await efApi('efArtist', { name: $('#ef-an', sh).value }); if (!r.ok) return efToast(efErr(r)); EF.init.artist = r.artist; closeSheet(); efStudio(params, EF.tok); };
  });
  $('[data-upload]', main).onclick = () => efUploadSheet();
  efLoadCreations(tok);
}
async function efLoadCreations(tok) {
  const r = await efApi('efCreations');
  const box = $('#ef-cr'); if (!box || (tok && tok !== EF.tok)) return;
  const list = r.creations || [];
  const ready = list.filter(c => c.status === 'ready').map(c => ({ key: c.key, title: c.title, artist: c.artist, url: c.url, source: c.kind === 'ai' ? 'ai' : 'city', ai: c.kind === 'ai', lyrics: c.lyrics }));
  EFL.mine = ready;
  box.innerHTML = list.length ? list.map(c => {
    const tr = { key: c.key, title: c.title, artist: c.artist, ai: c.kind === 'ai' };
    const idx = ready.findIndex(x => x.key === c.key);
    const style = (EF.init.styles || []).find(s => s.id === c.style);
    return `<div class="ef-cr ef-cr--${c.status}" data-cid="${c.id}">
      ${efArt(tr, 54)}
      <span class="ef-cr__t"><b>${esc(c.title)}</b><small>${style ? esc(style.label) + ' · ' : ''}${c.kind === 'ai' ? t(EF_STATUS[c.status] || '') : t('Titre publié')}${c.status === 'ready' ? ` · ${t('{n} écoutes', { n: c.plays || 0 })}` : ''}</small>
        ${c.status === 'failed' ? `<small class="ef-cr__err">${esc(c.error || '')}${c.kind === 'ai' ? ' · ' + t('remboursé') : ''}</small>` : ''}
        ${c.status === 'processing' || c.status === 'queued' || c.status === 'ready_temp' ? '<span class="ef-eq"><i></i><i></i><i></i><i></i></span>' : ''}</span>
      ${c.status === 'ready' ? `<button class="ef-pill ${c.public ? 'on' : ''}" data-pub="${c.id}" data-on="${c.public ? 1 : 0}">${efIco('globe')}${c.public ? t('Publiée') : t('Publier')}</button>
        <button class="ef-ib ef-ib--sm" data-crplay="${idx}" aria-label="${t('Lecture')}">${efIco('play')}</button>` : ''}
      ${c.status === 'ready' || c.status === 'failed' ? `<button class="ef-ib ef-ib--sm" data-crdel="${c.id}" aria-label="${t('Supprimer')}">${efIco('trash')}</button>` : ''}</div>`;
  }).join('') : `<p class="ef-muted ef-empty">${t('Vos chansons apparaîtront ici. Elles restent privées tant que vous ne les publiez pas.')}</p>`;
  $$('[data-crplay]', box).forEach(b => b.onclick = () => efPlay(ready, +b.dataset.crplay, 'mine'));
  $$('[data-pub]', box).forEach(b => b.onclick = async () => {
    const on = b.dataset.on === '1';
    const x = await efApi('efPublish', { id: +b.dataset.pub, public: !on });
    if (!x.ok) return efToast(efErr(x));
    efToast(x.public ? t('Publiée dans « Créations de la ville »') : t('Chanson redevenue privée'));
    efLoadCreations();
  });
  $$('[data-crdel]', box).forEach(b => b.onclick = () => confirmSheet(t('Supprimer cette chanson ?'), t('Elle disparaîtra d\'ElyFy pour tout le monde.'), t('Supprimer'), async () => { await efApi('efDeleteCreation', { id: +b.dataset.crdel }); efLoadCreations(); }));
  // Chansons prêtes chez le fournisseur : le téléphone les copie sur l'hébergeur du serveur
  list.filter(c => c.status === 'ready_temp' && c.temp_url).forEach(c => efRehost(c));
  if (list.some(c => c.status === 'queued' || c.status === 'processing')) { clearTimeout(EF.crTimer); EF.crTimer = setTimeout(() => { if (S.currentApp === 'elyfy' && $('#ef-cr')) efLoadCreations(); }, 8000); }
}
async function efRehost(c) {
  if (EF.rehosting[c.id]) return;
  EF.rehosting[c.id] = true;
  try {
    let url;
    if (IS_BROWSER) url = 'https://r2.fivemanage.com/demo/' + c.id + '.mp3';
    else {
      const blob = await (await fetch(c.temp_url)).blob();
      const link = await api('efUploadUrl');
      if (!link.ok) throw new Error('lien');
      const fd = new FormData(); fd.append('file', blob, `elyfy_${c.id}.mp3`);
      const res = await fetch(link.url, { method: 'POST', body: fd });
      let b = {}; try { b = await res.json(); } catch (e) { /* vide */ }
      url = b.url || b.data?.url;
    }
    if (!url) throw new Error('hébergeur');
    const r = await efApi('efAiSaved', { id: c.id, url });
    if (r.ok) { efToast(t('« {t} » est prête !', { t: c.title })); if ($('#ef-cr')) efLoadCreations(); }
  } catch (e) { EF.rehosting[c.id] = false; }
}

// Écriture : titre, paroles (structure), instru, ambiance, voix
async function efCompose(params, tok) {
  const ai = EF.init.ai || {};
  const d = EF.studio = EF.studio || { title: '', lyrics: '', style: '', mood: '', voice: 'm' };
  const max = ai.lyricsMax || 600;
  const main = efShell('compose', `${efTop(t('Nouvelle chanson'))}<div class="ef-pad ef-compose">
    <label class="ef-lbl">${t('Titre')}</label><input class="field" id="ef-ct" maxlength="80" placeholder="${t('ex. Nuits de Vinewood')}" value="${esc(d.title)}">
    <label class="ef-lbl">${t('Paroles')}</label>
    <div class="ef-tags">${['Intro', 'Couplet', 'Pré-refrain', 'Refrain', 'Pont', 'Outro'].map(x => `<button data-ins="[${x}]">${t(x)}</button>`).join('')}</div>
    <textarea class="field" id="ef-cl" rows="8" maxlength="${max}" placeholder="${t('[Couplet]\nJe roule la nuit sur Vinewood…\n[Refrain]\nLos Santos, ma ville…')}">${esc(d.lyrics)}</textarea>
    <p class="ef-count"><span id="ef-cln">${d.lyrics.length}</span> / ${max}</p>
    <label class="ef-lbl">${t('Instru')}</label>
    <div class="ef-styles">${(EF.init.styles || []).map(s => `<button class="ef-style ${d.style === s.id ? 'on' : ''}" data-style="${s.id}" style="--g:${s.color}"><span class="ef-eq"><i></i><i></i><i></i><i></i></span><b>${esc(t(s.label))}</b></button>`).join('')}</div>
    <label class="ef-lbl">${t('Ambiance')}</label>
    <div class="ef-chips">${(EF.init.moods || []).map(m => `<button class="${d.mood === m ? 'on' : ''}" data-mood="${esc(m)}">${esc(t(m))}</button>`).join('')}</div>
    <label class="ef-lbl">${t('Voix')}</label>
    <div class="ef-seg"><button data-voice="m" class="${d.voice === 'm' ? 'on' : ''}">${t('Masculine')}</button><button data-voice="f" class="${d.voice === 'f' ? 'on' : ''}">${t('Féminine')}</button></div>
    <p class="error-text" id="ef-cerr"></p>
    <button class="btn btn--block ef-grad ef-create" id="ef-cgo">${efIco('spark')}${t('Créer ma chanson · {p} $', { p: (ai.price || 0).toLocaleString(locale()) })}</button>
    <p class="ef-muted ef-small">${t('La création prend une à quelques minutes. Vous serez prévenu quand elle sera prête. En cas d\'échec, vous êtes remboursé.')}</p></div>`);
  const ly = $('#ef-cl'), ti = $('#ef-ct');
  ly.oninput = () => { d.lyrics = ly.value; $('#ef-cln').textContent = ly.value.length; };
  ti.oninput = () => { d.title = ti.value; };
  $$('[data-ins]', main).forEach(b => b.onclick = () => {
    const pos = ly.selectionStart ?? ly.value.length;
    const pre = ly.value.slice(0, pos);
    const ins = (pre && !pre.endsWith('\n') ? '\n' : '') + b.dataset.ins + '\n';
    ly.value = pre + ins + ly.value.slice(pos); ly.focus(); ly.selectionStart = ly.selectionEnd = pos + ins.length; ly.oninput();
  });
  $$('[data-style]', main).forEach(b => b.onclick = () => { d.style = b.dataset.style; $$('[data-style]', main).forEach(x => x.classList.toggle('on', x === b)); });
  $$('[data-mood]', main).forEach(b => b.onclick = () => { d.mood = d.mood === b.dataset.mood ? '' : b.dataset.mood; $$('[data-mood]', main).forEach(x => x.classList.toggle('on', x.dataset.mood === d.mood)); });
  $$('[data-voice]', main).forEach(b => b.onclick = () => { d.voice = b.dataset.voice; $$('[data-voice]', main).forEach(x => x.classList.toggle('on', x === b)); });
  $('#ef-cgo').onclick = async () => {
    if (!d.title.trim()) { $('#ef-cerr').textContent = t('Donnez un titre à votre chanson.'); return; }
    if (d.lyrics.trim().length < 20) { $('#ef-cerr').textContent = t('Écrivez au moins quelques lignes de paroles.'); return; }
    if (!d.style) { $('#ef-cerr').textContent = t('Choisissez une instru.'); return; }
    const b = $('#ef-cgo'); b.disabled = true;
    const r = await efApi('efAiCreate', { title: d.title, lyrics: d.lyrics, style: d.style, mood: d.mood || undefined, voice: d.voice });
    b.disabled = false;
    if (!r.ok) { $('#ef-cerr').textContent = efErr(r); return; }
    EF.studio = null;
    efToast(t('Chanson en cours de création…'));
    efTab('studio');
  };
}
function efUploadSheet() {
  openSheet(t('Publier un titre'), `<p class="ef-muted ef-small">${t('Artistes de la ville : collez le lien de votre fichier audio (Fivemanage…).')}</p>
    <label class="ef-lbl">${t('Titre')}</label><input class="field" id="ef-ut" maxlength="80">
    <label class="ef-lbl">${t('Lien audio')}</label><input class="field" id="ef-uu" placeholder="https://…">
    <label class="ef-lbl">${t('Paroles (facultatif)')}</label><textarea class="field" id="ef-ul" rows="3"></textarea>
    <p class="error-text" id="ef-uerr"></p><button class="btn btn--block ef-grad" id="ef-ugo">${t('Publier')}</button>`, (sh) => {
    sh.classList.add('ef-sheet');
    $('#ef-ugo', sh).onclick = async () => {
      const r = await efApi('efUpload', { title: $('#ef-ut', sh).value, url: $('#ef-uu', sh).value, lyrics: $('#ef-ul', sh).value });
      if (!r.ok) { $('#ef-uerr', sh).textContent = efErr(r); return; }
      closeSheet(); efToast(t('Titre publié dans « Créations de la ville »')); efLoadCreations();
    };
  });
}

const EF_PAGES = { home: efHome, search: efSearch, library: efLibrary, studio: efStudio, compose: efCompose, genre: efGenre, liked: efLiked, downloads: efDownloads, playlist: efPlaylistPage };

/* ---------- Événements en direct (serveur → téléphone) ---------- */
function efPush(d) {
  if (d.type === 'ai') {
    if (d.status === 'ready_temp') efApi('efCreations').then(r => (r.creations || []).filter(c => c.id === d.id && c.status === 'ready_temp').forEach(c => efRehost(c)));
    if (S.currentApp === 'elyfy' && $('#ef-cr')) efLoadCreations();
  }
}

/* ---------- Aperçu navigateur (hors FiveM) : données de démonstration ---------- */
const EFMock = (() => {
  // petits morceaux de démonstration générés dans le navigateur (WAV)
  const tone = (notes, bpm = 110) => {
    const rate = 8000, beat = 60 / bpm, len = Math.floor(rate * beat * notes.length);
    const buf = new ArrayBuffer(44 + len * 2), v = new DataView(buf);
    const w = (o, s) => [...s].forEach((c, i) => v.setUint8(o + i, c.charCodeAt(0)));
    w(0, 'RIFF'); v.setUint32(4, 36 + len * 2, true); w(8, 'WAVE'); w(12, 'fmt '); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
    v.setUint32(24, rate, true); v.setUint32(28, rate * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true); w(36, 'data'); v.setUint32(40, len * 2, true);
    for (let i = 0; i < len; i++) { const n = notes[Math.floor(i / (rate * beat))]; const f = 220 * Math.pow(2, n / 12); v.setInt16(44 + i * 2, Math.sin(2 * Math.PI * f * i / rate) * 6000 * (1 - (i % (rate * beat)) / (rate * beat)), true); }
    return URL.createObjectURL(new Blob([buf], { type: 'audio/wav' }));
  };
  const T = (key, title, artist, source, extra = {}) => Object.assign({ key, title, artist, source, url: tone([0, 4, 7, 12, 7, 4, 0, -5]) }, extra);
  const trend = [T('audius:1', 'Vinewood Nights', 'Lofi LS', 'audius'), T('audius:2', 'Grove Street Anthem', 'MC Grove', 'audius'), T('audius:3', 'Del Perro Sunset', 'Beach Club', 'audius'), T('audius:4', 'Maze Bank Rooftop', 'DJ Skyline', 'audius')];
  const city = [T('ef:1', 'Ma ville la nuit', 'MC Malik', 'ai', { ai: true, lyrics: '[Couplet]\nJe roule la nuit sur Vinewood\nLes lumières de la ville\n[Refrain]\nLos Santos, ma ville, mon histoire', plays: 342 }),
    T('ef:2', 'Los Santos Flow', 'Inès M', 'city', { plays: 120 })];
  const all = [...trend, ...city];
  const states = { 'audius:1': { liked: true, downloaded: true } };
  const pls = [{ id: 1, name: 'Route de nuit', items: ['audius:2', 'ef:1'] }];
  let crs = [{ id: 1, kind: 'ai', key: 'ef:1', title: 'Ma ville la nuit', artist: 'Léna D.', url: city[0].url, lyrics: city[0].lyrics, style: 'trap', status: 'ready', public: true, plays: 342 },
    { id: 2, kind: 'ai', key: 'ef:5', title: 'Pluie sur Paleto', artist: 'Léna D.', style: 'lofi', status: 'processing' },
    { id: 3, kind: 'ai', key: 'ef:6', title: 'Essai', artist: 'Léna D.', style: 'pop', status: 'failed', error: 'L\'IA n\'a pas pu créer la chanson' }];
  let artist = 'Léna D.', plid = 1, crid = 3;
  const dl = () => ({ allowed: true, tier: 4, minTier: 4, max: 100, count: Object.values(states).filter(s => s.downloaded).length });
  const find = (k) => all.find(x => x.key === k);
  const H = {
    efInit: () => ({ ok: true, artist, downloads: dl(), youtube: true, ai: { enabled: true, price: 2500, daily: 3, lyricsMax: 600 },
      genres: [['rap', 'Rap', '#9B5CFF'], ['pop', 'Pop', '#FF6FB5'], ['electro', 'Électro', '#2EE6F0'], ['rnb', 'R&B', '#C9A6FF'], ['lofi', 'Lo-fi', '#6FE7F2'], ['rock', 'Rock', '#E8590C'], ['afro', 'Afro', '#3EE6B0'], ['ville', 'Créations de la ville', '#FF2D7A']].map(([id, label, color]) => ({ id, label, color })),
      styles: [['trap', 'Trap', '#9B5CFF'], ['drill', 'Drill', '#FF2D55'], ['afro', 'Afro', '#3EE6B0'], ['pop', 'Pop', '#FF6FB5'], ['rnb', 'R&B', '#C9A6FF'], ['lofi', 'Lo-fi', '#6FE7F2']].map(([id, label, color]) => ({ id, label, color })),
      moods: ['Énergique', 'Mélancolique', 'Chill', 'Sombre', 'Joyeux', 'Romantique'] }),
    efStates: () => ({ ok: true, states }),
    efHome: () => ({ ok: true, recent: [trend[1], city[0]], trending: trend, city, fresh: city.slice().reverse(), catalog: [], playlists: pls.map(p => ({ id: p.id, name: p.name, n: p.items.length })), mixes: [['rap', 'Rap', '#9B5CFF'], ['pop', 'Pop', '#FF6FB5'], ['lofi', 'Lo-fi', '#6FE7F2']].map(([id, label, color]) => ({ id, label, color })) }),
    efGenre: (a) => ({ ok: true, genre: { id: a.id, label: a.id === 'ville' ? 'Créations de la ville' : 'Rap', color: '#9B5CFF' }, tracks: a.id === 'ville' ? city : trend }),
    efSearch: (a) => ({ ok: true, tracks: trend.filter(x => x.title.toLowerCase().includes(a.q.toLowerCase())), city: city.filter(x => (x.title + x.artist).toLowerCase().includes(a.q.toLowerCase())), youtube: [T('yt:abc', 'Clip officiel – ' + a.q, 'Artiste VEVO', 'youtube')] }),
    efLink: (a) => ({ ok: true, track: T('yt:lnk', 'Lien YouTube', 'Chaîne', 'youtube') }),
    efPlayed: () => ({ ok: true }),
    efLike: (a) => { states[a.key] = Object.assign({}, states[a.key], { liked: a.like }); return { ok: true, liked: a.like }; },
    efLiked: () => ({ ok: true, tracks: all.filter(x => states[x.key]?.liked) }),
    efDownload: (a) => { states[a.key] = Object.assign({}, states[a.key], { downloaded: !a.remove }); return { ok: true, downloaded: !a.remove, downloads: dl() }; },
    efDownloads: () => ({ ok: true, tracks: all.filter(x => states[x.key]?.downloaded), downloads: dl() }),
    efPlaylists: () => ({ ok: true, liked: all.filter(x => states[x.key]?.liked).length, downloads: dl(), playlists: pls.map(p => ({ id: p.id, name: p.name, n: p.items.length })) }),
    efPlaylistCreate: (a) => { pls.push({ id: ++plid, name: a.name || 'Ma playlist', items: [] }); return { ok: true, id: plid }; },
    efPlaylist: (a) => { const p = pls.find(x => x.id === a.id); return p ? { ok: true, playlist: { id: p.id, name: p.name, tracks: p.items.map(find).filter(Boolean) } } : { ok: false, error: 'Playlist introuvable' }; },
    efPlaylistAdd: (a) => { const p = pls.find(x => x.id === a.id); const added = !p.items.includes(a.key); if (added) p.items.push(a.key); return { ok: true, added, name: p.name }; },
    efPlaylistRemove: (a) => { const p = pls.find(x => x.id === a.id); p.items = p.items.filter(k => k !== a.key); return { ok: true }; },
    efPlaylistRename: (a) => { pls.find(x => x.id === a.id).name = a.name; return { ok: true }; },
    efPlaylistDelete: (a) => { pls.splice(pls.findIndex(x => x.id === a.id), 1); return { ok: true }; },
    efArtist: (a) => { artist = a.name; return { ok: true, artist }; },
    efCreations: () => ({ ok: true, creations: crs.map(c => Object.assign({}, c)) }),
    efAiCreate: (a) => { crs.unshift({ id: ++crid, kind: 'ai', key: 'ef:' + (crid + 10), title: a.title, artist, style: a.style, status: 'queued', lyrics: a.lyrics }); return { ok: true, id: crid }; },
    efPublish: (a) => { const c = crs.find(x => x.id === a.id); c.public = a.public !== false; return { ok: true, public: c.public }; },
    efDeleteCreation: (a) => { crs = crs.filter(x => x.id !== a.id); return { ok: true }; },
    efAiSaved: () => ({ ok: true }),
    efUpload: (a) => a.url.startsWith('https://') ? { ok: true, id: 99 } : { ok: false, error: 'Lien refusé' },
  };
  return { call: async (n, a) => (H[n] || (() => ({ ok: false, error: 'inconnu' })))(a || {}) };
})();
