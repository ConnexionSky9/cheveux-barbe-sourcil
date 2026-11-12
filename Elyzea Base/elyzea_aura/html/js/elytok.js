'use strict';
/* =========================================================
   ELYTOK : réseau social vidéo (à partir de l'ElyAura 3)
   Fil vertical plein écran « Pour toi » / « Abonnements » (lecture auto, double-tap = j'aime),
   barre d'actions (profil + abonnement, j'aime, commentaires, favoris, partage, son),
   Découvrir (hashtags tendance, populaires, recherche), Créer (vidéo de la galerie + légende + son),
   Boîte de réception (activité + messages), Profils (vidéos, favoris, j'aime).
   Toutes les données viennent du serveur (server/elytok.lua).
   ========================================================= */
const ET = {
  acc: null, ready: false, badges: { notifs: 0, dms: 0 }, limits: { caption: 220, bio: 120, comment: 150, message: 400, maxSeconds: 60 },
  tok: 0, tab: 'foryou', feeds: {}, lists: {}, player: null, draft: null, chat: null,
};
const etApi = (name, args = {}) => IS_BROWSER ? ETMock.call(name, args) : api(name, args);
const etGallery = async () => {
  const r = IS_BROWSER ? await ETMock.call('getGallery') : await api('getGallery');
  return r.photos || [];
};

/* ---------- Icônes ---------- */
const ETI = {
  home: '<path d="M3.5 10.5 12 3.5l8.5 7V20a1 1 0 0 1-1 1H15v-6H9v6H4.5a1 1 0 0 1-1-1z"/>',
  discover: '<circle cx="11" cy="11" r="7"/><path d="m20.5 20.5-4-4"/>',
  inbox: '<path d="M4 5.5h16v10H15l-3 3-3-3H4z"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4.5 21a7.5 7.5 0 0 1 15 0"/>',
  heart: '<path d="M12 20.5s-7.6-4.6-9.4-9.3C1.3 7.8 3.6 4.5 7 4.5c2 0 3.6 1.1 5 3 1.4-1.9 3-3 5-3 3.4 0 5.7 3.3 4.4 6.7-1.8 4.7-9.4 9.3-9.4 9.3z"/>',
  comment: '<path d="M20.5 11.5c0 4.4-3.8 7.5-8.5 7.5-1.2 0-2.3-.2-3.3-.5L4 20l1.3-3.7A7.2 7.2 0 0 1 3.5 11.5C3.5 7.1 7.3 4 12 4s8.5 3.1 8.5 7.5z"/>',
  save: '<path d="M6.5 3.5h11v17L12 16.5l-5.5 4z"/>',
  share: '<path d="M13.5 4.5 21 11l-7.5 6.5v-4C8.5 13.5 5 15 3 19c.5-5.5 3.5-9.5 10.5-10.5z"/>',
  music: '<path d="M9 18V5.5l11-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16.5" r="3"/>',
  plus: '<path d="M12 5.5v13M5.5 12h13"/>',
  play: '<path d="M8 5.5v13l11-6.5z" fill="currentColor"/>',
  back: '<path d="m15 5-7 7 7 7"/>',
  more: '<circle cx="5" cy="12" r="1.5" fill="currentColor"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/><circle cx="19" cy="12" r="1.5" fill="currentColor"/>',
  grid: '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M9.3 4v16M14.7 4v16M4 9.3h16M4 14.7h16"/>',
  eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="2.8"/>',
  send: '<path d="M21.5 2.5 10.5 13.5"/><path d="M21.5 2.5 14.8 21.5l-4.3-8-8-4.3z"/>',
  trash: '<path d="M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  hash: '<path d="M9.5 3.5 7.5 20.5M16.5 3.5l-2 17M4 9h17M3 15h17"/>',
  camera: '<path d="M4 7.5h3.2L9 5h6l1.8 2.5H20a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V8.5a1 1 0 0 1 1-1z"/><circle cx="12" cy="13.5" r="3.6"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
};
const etIco = (n, cls = '') => `<svg class="eti ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ETI[n] || ''}</svg>`;
const etWord = () => `<span class="et-word">Ely<b>Tok</b></span>`;

function etAv(u, size = 36) {
  const name = u?.name || u?.username || '?';
  const inner = u?.avatar
    ? `<img src="${esc(u.avatar)}" alt="" loading="lazy" onerror="this.remove()">`
    : '';
  return `<span class="et-av" style="--s:${size}px;--av:${avColor(u?.username || name)}"><i>${esc(initials(name))}</i>${inner}</span>`;
}
const etCount = (n) => {
  n = Number(n) || 0;
  if (n >= 1e6) return (n / 1e6).toFixed(1).replace('.0', '') + ' M';
  if (n >= 1e4) return (n / 1e3).toFixed(1).replace('.0', '') + ' k';
  return n.toLocaleString(locale());
};
function etAgo(ts) {
  if (!ts) return '';
  const d = (Date.now() / 1000) - ts;
  if (d < 60) return t('à l\'instant');
  if (d < 3600) return t('il y a {n} min', { n: Math.floor(d / 60) });
  if (d < 86400) return t('il y a {n} h', { n: Math.floor(d / 3600) });
  if (d < 7 * 86400) return t('il y a {n} j', { n: Math.floor(d / 86400) });
  return new Date(ts * 1000).toLocaleDateString(locale(), { day: 'numeric', month: 'short' });
}
const etRich = (s) => esc(s)
  .replace(/#([^\s#@.,!?;:()"']{1,30})/g, '<button class="et-tag" data-tag="$1">#$1</button>')
  .replace(/@([a-z0-9_.]{3,20})/gi, '<button class="et-at" data-user="$1">@$1</button>')
  .replace(/\n/g, '<br>');
const etErr = (r) => t(r?.error || 'Action impossible pour le moment.');
function etToast(text) { notify({ app: 'elytok', title: 'ElyTok', text }); }
const etVideoTag = (url, cls = '') => `<video class="${cls}" src="${esc(url)}#t=0.1" muted playsinline preload="metadata"></video>`;

/* ---------- Navigation ---------- */
const ET_ROOTS = ['home', 'discover', 'create', 'inbox', 'me'];
function etGo(page, params = {}) { etStopAll(); openApp('elytok', Object.assign({ page }, params)); }
function etTab(page) {
  etStopAll(); closeSheet(true);
  const first = S.stack.findIndex(e => e.id === 'elytok');
  if (first >= 0) { S.stack.length = first + 1; S.stack[first].params = { page }; }
  etRender({ page });
}
function etLeave() { etStopAll(); ET.chat = null; }

Views.elytok = (params = {}) => {
  S.onLeave = etLeave;
  etRender(params);
};

async function etRender(params = {}) {
  const tok = ++ET.tok;
  const page = params.page || 'home';
  if (!ET.ready) {
    etShell(page, loading(), { bare: true });
    const r = await etApi('etInit');
    if (tok !== ET.tok) return;
    if (!r.ok) { etShell(page, empty(t('ElyTok indisponible'), etErr(r)), { bare: true }); return; }
    ET.acc = r.account || null; ET.badges = r.badges || ET.badges; Object.assign(ET.limits, r.limits || {}); ET.ready = true;
    etSyncBadge();
  }
  if (!ET.acc) return etOnboard();
  const fn = ET_PAGES[page] || ET_PAGES.home;
  return fn(params, tok);
}

// Gabarit : contenu + barre de navigation en bas (noire sur le fil, comme l'appli d'origine)
function etShell(page, body, opts = {}) {
  const root = ET_ROOTS.includes(page) ? page : null;
  const dark = opts.dark || page === 'home' || page === 'watch';
  const navItem = (id, ic, label) => {
    const act = root === id;
    const badge = id === 'inbox' && (ET.badges.notifs + ET.badges.dms) > 0 ? `<span class="et-dot">${Math.min(99, ET.badges.notifs + ET.badges.dms)}</span>` : '';
    if (id === 'create') return `<button class="et-nav__plus" data-tab="create" aria-label="${t(label)}"><span>${etIco('plus')}</span></button>`;
    return `<button class="et-nav__b ${act ? 'active' : ''}" data-tab="${id}" aria-label="${t(label)}">${etIco(ic)}<small>${t(label)}</small>${badge}</button>`;
  };
  appView.innerHTML = `<div class="et ${dark ? 'et--dark' : ''} ${opts.bare ? 'et--bare' : ''}" data-page="${page}">
    <main class="et-main" id="et-main">${body}</main>
    ${opts.bare || opts.noNav ? '' : `<nav class="et-nav">${navItem('home', 'home', 'Accueil')}${navItem('discover', 'discover', 'Découvrir')}${navItem('create', 'plus', 'Créer')}${navItem('inbox', 'inbox', 'Boîte')}${navItem('me', 'user', 'Profil')}</nav>`}
  </div>`;
  $$('[data-tab]', appView).forEach(b => b.onclick = () => {
    if (b.dataset.tab === root && root === 'home') { ET.feeds = {}; etRender({ page: 'home' }); return; }
    etTab(b.dataset.tab);
  });
  return $('#et-main');
}
const etTop = (title, right = '') => `<header class="et-top"><button class="et-ib" data-back aria-label="${t('Retour')}">${etIco('back')}</button>
  <h1 class="et-title">${title}</h1><div class="et-top__r">${right}</div></header>`;

function etSyncBadge() {
  S.etBadge = (ET.badges.notifs || 0) + (ET.badges.dms || 0);
  const b = $('.et-nav [data-tab="inbox"]');
  if (b) { b.querySelector('.et-dot')?.remove(); if (S.etBadge > 0) b.insertAdjacentHTML('beforeend', `<span class="et-dot">${Math.min(99, S.etBadge)}</span>`); }
}

/* ---------- Création du compte ---------- */
function etOnboard() {
  etShell('home', `<div class="et-onboard">
    <div class="et-onboard__logo">${solidTile('elytok', 86)}</div>
    ${etWord()}
    <p class="et-onboard__txt">${t('Filmez, publiez et découvrez les vidéos de toute la ville.')}</p>
    <div class="et-form">
      <label class="et-lbl">${t('Nom affiché')}</label>
      <input class="field" id="et-display" maxlength="40" value="${esc(S.profile?.name || '')}">
      <label class="et-lbl">${t('Nom d\'utilisateur')}</label>
      <div class="handle-field"><span>@</span><input class="field" id="et-user" maxlength="20" autocomplete="off" placeholder="${t('ex. lena.duval')}"></div>
      <p class="error-text" id="et-err"></p>
      <button class="btn btn--block et-grad" id="et-go">${t('Créer mon compte')}</button>
    </div></div>`, { bare: true });
  $('#et-user').oninput = (e) => { e.target.value = e.target.value.toLowerCase().replace(/[^a-z0-9_.]/g, ''); };
  $('#et-go').onclick = async () => {
    const r = await etApi('etCreateAccount', { username: $('#et-user').value, display: $('#et-display').value });
    if (!r.ok) { $('#et-err').textContent = etErr(r); return; }
    ET.acc = r.account; etRender({ page: 'home' });
  };
}

/* =========================================================
   LECTEUR VERTICAL (fil, vidéo ouverte depuis un profil, un hashtag, un message)
   ========================================================= */
const ETV = {};   // vidéos connues par id (mises à jour en direct : likes, favoris…)
function etSlide(v, i) {
  ETV[v.id] = v;
  const hue = (v.id * 47) % 360;
  return `<section class="et-slide" data-i="${i}" data-vid="${v.id}" style="--hue:${hue}">
    <video class="et-v" src="${esc(v.url)}" loop playsinline muted preload="${i < 2 ? 'auto' : 'none'}"></video>
    <div class="et-tapzone" data-tap="${v.id}"></div>
    <span class="et-paused">${etIco('play')}</span>
    <span class="et-burst">${etIco('heart')}</span>
    <aside class="et-rail">
      <div class="et-rail__who">
        <button class="et-rail__av" data-user="${esc(v.username)}" aria-label="@${esc(v.username)}">${etAv(v, 46)}</button>
        ${v.canFollow ? `<button class="et-rail__follow" data-follow="${esc(v.username)}" aria-label="${t('S\'abonner')}">${etIco('plus')}</button>` : ''}
      </div>
      <button class="et-act ${v.liked ? 'on' : ''}" data-like="${v.id}" aria-label="${t('J\'aime')}">${etIco('heart')}<b data-likes="${v.id}">${etCount(v.likes)}</b></button>
      <button class="et-act" data-comments="${v.id}" aria-label="${t('Commentaires')}">${etIco('comment')}<b data-ccount="${v.id}">${etCount(v.comments)}</b></button>
      <button class="et-act ${v.saved ? 'on on--save' : ''}" data-save="${v.id}" aria-label="${t('Favoris')}">${etIco('save')}<b data-saves="${v.id}">${etCount(v.saves)}</b></button>
      <button class="et-act" data-share="${v.id}" aria-label="${t('Partager')}">${etIco('share')}<b data-shares="${v.id}">${etCount(v.shares)}</b></button>
      <button class="et-disc ${v.music ? '' : 'et-disc--none'}" data-sound="${v.id}" aria-label="${t('Son')}">${etAv(v, 30)}</button>
    </aside>
    <div class="et-info">
      <p class="et-info__who"><button data-user="${esc(v.username)}"><b>@${esc(v.username)}</b></button> · <span>${etAgo(v.ts)}</span>
        ${v.mine ? `<button class="et-info__more" data-vmenu="${v.id}" aria-label="${t('Options')}">${etIco('more')}</button>` : ''}</p>
      ${v.caption ? `<p class="et-info__cap">${etRich(v.caption)}</p>` : ''}
      <p class="et-info__music">${etIco('music')}<span class="et-marquee"><span>${v.music ? `${esc(v.music.title)}${v.music.artist ? ' · ' + esc(v.music.artist) : ''}` : t('Son original · @{u}', { u: esc(v.username) })}</span></span></p>
    </div>
    <div class="et-prog"><i></i></div>
  </section>`;
}

// Lecteur : une seule vidéo joue (celle à l'écran) ; son de la vidéo avec AudioEngine ; vue comptée après 2 s
function etPlayer(box, videos, opts = {}) {
  etStopAll();
  const P = { box, videos: videos.slice(), more: !!opts.more, loadMore: opts.loadMore, cur: -1, paused: false, viewTimer: 0, loading: false, key: 'et' + Date.now() };
  ET.player = P;
  box.innerHTML = videos.length ? videos.map((v, i) => etSlide(v, i)).join('') : (opts.empty || '');
  etWireSlides(box);
  const io = new IntersectionObserver((entries) => {
    entries.forEach(en => { if (en.isIntersecting && en.intersectionRatio > .6) etActivate(P, +en.target.dataset.i); });
  }, { root: box, threshold: [.6] });
  P.io = io;
  $$('.et-slide', box).forEach(s => io.observe(s));
  if (opts.start) requestAnimationFrame(() => { const s = $(`.et-slide[data-i="${opts.start}"]`, box); if (s) box.scrollTop = s.offsetTop; });
  return P;
}
function etAppend(P, list) {
  const start = P.videos.length;
  P.videos.push(...list);
  P.box.insertAdjacentHTML('beforeend', list.map((v, i) => etSlide(v, start + i)).join(''));
  const fresh = $$('.et-slide', P.box).slice(start);
  etWireSlides(P.box, fresh);
  fresh.forEach(s => P.io.observe(s));
}
function etActivate(P, i) {
  if (P.cur === i || ET.player !== P) return;
  P.cur = i; P.paused = false;
  const slides = $$('.et-slide', P.box);
  slides.forEach((s, k) => {
    const v = $('.et-v', s);
    s.classList.toggle('active', k === i);
    s.classList.remove('is-paused');
    if (Math.abs(k - i) <= 1 && v.preload !== 'auto') v.preload = 'auto';
    if (k === i) { v.currentTime = 0; v.play()?.catch(() => {}); } else v.pause();
  });
  const vid = P.videos[i];
  etSound(P, vid);
  clearTimeout(P.viewTimer);
  P.viewTimer = setTimeout(() => { if (ET.player === P && P.cur === i) etApi('etView', { id: vid.id }); }, 2000);
  if (P.more && P.loadMore && !P.loading && i >= P.videos.length - 2) {
    P.loading = true;
    P.loadMore(P).then(r => { P.loading = false; if (r && r.length) etAppend(P, r); });
  }
}
function etSound(P, v) {
  if (IS_BROWSER) return;
  AudioEngine.stop('et');
  if (v?.music?.url && !P.paused) AudioEngine.play('et', { url: v.music.url, volume: .7, onError: () => {} });
}
function etTogglePause(P, slide) {
  const v = $('.et-v', slide);
  P.paused = !v.paused ? true : false;
  if (P.paused) { v.pause(); if (!IS_BROWSER) AudioEngine.stop('et'); } else { v.play()?.catch(() => {}); etSound(P, P.videos[+slide.dataset.i]); }
  slide.classList.toggle('is-paused', P.paused);
}
function etStopAll() {
  const P = ET.player;
  if (P) { clearTimeout(P.viewTimer); P.io?.disconnect(); $$('.et-v', P.box).forEach(v => v.pause()); ET.player = null; }
  if (!IS_BROWSER) AudioEngine.stop('et');
}
// Mise à jour d'une vidéo partout où elle est affichée
function etPatch(id, fields) {
  const v = ETV[id]; if (v) Object.assign(v, fields);
  if ('likes' in fields || 'liked' in fields) $$(`[data-like="${id}"]`).forEach(b => { b.classList.toggle('on', !!v?.liked); }), $$(`[data-likes="${id}"]`).forEach(x => x.textContent = etCount(v?.likes));
  if ('saves' in fields || 'saved' in fields) $$(`[data-save="${id}"]`).forEach(b => { b.classList.toggle('on', !!v?.saved); b.classList.toggle('on--save', !!v?.saved); }), $$(`[data-saves="${id}"]`).forEach(x => x.textContent = etCount(v?.saves));
  if ('comments' in fields) $$(`[data-ccount="${id}"]`).forEach(x => x.textContent = etCount(v?.comments));
  if ('shares' in fields) $$(`[data-shares="${id}"]`).forEach(x => x.textContent = etCount(v?.shares));
}
async function etLike(id, force) {
  const v = ETV[id];
  if (force && v?.liked) return;
  const r = await etApi('etLike', { id, like: force ? true : undefined });
  if (!r.ok) { if (r.error) etToast(etErr(r)); return; }
  etPatch(id, { liked: r.liked, likes: r.likes });
  if (r.liked) $$(`[data-like="${id}"]`).forEach(b => { b.classList.remove('pop'); void b.offsetWidth; b.classList.add('pop'); });
}
function etWireSlides(box, list) {
  const slides = list || $$('.et-slide', box);
  slides.forEach(s => {
    const id = +s.dataset.vid;
    const v = $('.et-v', s), bar = $('.et-prog i', s);
    v.ontimeupdate = () => { if (v.duration) bar.style.width = `${(v.currentTime / v.duration) * 100}%`; };
    // Un appui : pause / lecture. Deux appuis rapides : j'aime (cœur à l'endroit touché)
    let tm = 0, last = 0;
    $('[data-tap]', s).onclick = (e) => {
      const now = Date.now();
      if (now - last < 300) {
        clearTimeout(tm); last = 0;
        const burst = $('.et-burst', s), r = s.getBoundingClientRect();
        burst.style.left = `${e.clientX - r.left}px`; burst.style.top = `${e.clientY - r.top}px`;
        burst.classList.remove('pop'); void burst.offsetWidth; burst.classList.add('pop');
        etLike(id, true);
        return;
      }
      last = now;
      tm = setTimeout(() => { if (ET.player) etTogglePause(ET.player, s); }, 280);
    };
    $$('[data-like]', s).forEach(b => b.onclick = () => etLike(id));
    $$('[data-comments]', s).forEach(b => b.onclick = () => etComments(id));
    $$('[data-save]', s).forEach(b => b.onclick = async () => {
      const r = await etApi('etSave', { id });
      if (!r.ok) return r.error && etToast(etErr(r));
      etPatch(id, { saved: r.saved, saves: r.saves });
      etToast(r.saved ? t('Ajouté aux favoris') : t('Retiré des favoris'));
    });
    $$('[data-share]', s).forEach(b => b.onclick = () => etShare(id));
    $$('[data-sound]', s).forEach(b => b.onclick = () => etSoundSheet(id));
    $$('[data-user]', s).forEach(b => b.onclick = () => etGo('profile', { user: b.dataset.user }));
    $$('[data-tag]', s).forEach(b => b.onclick = () => etGo('tag', { tag: b.dataset.tag }));
    $$('[data-follow]', s).forEach(b => b.onclick = async () => {
      const r = await etApi('etFollow', { username: b.dataset.follow, follow: true });
      if (!r.ok) return etToast(etErr(r));
      Object.values(ETV).forEach(x => { if (x.username === b.dataset.follow) { x.following = true; x.canFollow = false; } });
      $$(`[data-follow="${b.dataset.follow}"]`).forEach(x => { x.classList.add('done'); x.innerHTML = etIco('check'); setTimeout(() => x.remove(), 700); });
      ET.feeds.following = null;
    });
    $$('[data-vmenu]', s).forEach(b => b.onclick = () => openSheet('', `<div class="form">
        <button class="btn btn--danger btn--block" data-del>${etIco('trash')}${t('Supprimer la vidéo')}</button>
        <button class="btn btn--ghost btn--block" data-no>${t('Annuler')}</button></div>`, (sh) => {
      $('[data-no]', sh).onclick = () => closeSheet();
      $('[data-del]', sh).onclick = () => confirmSheet(t('Supprimer cette vidéo ?'), t('Elle disparaîtra de votre profil et des fils, avec ses j\'aime et commentaires.'), t('Supprimer'), async () => {
        const r = await etApi('etDelete', { id });
        if (!r.ok) return etToast(etErr(r));
        ET.feeds = {}; ET.lists = {};
        etToast(t('Vidéo supprimée'));
        if (S.stack[S.stack.length - 1]?.params?.page === 'watch') back(); else etRender({ page: 'home' });
      });
    }));
  });
}

/* ---------- Commentaires ---------- */
function etComments(id) {
  const v = ETV[id];
  openSheet('', `<div class="et-cm">
    <header class="et-cm__h"><b>${t('{n} commentaires', { n: etCount(v?.comments || 0) })}</b><button class="et-ib et-ib--sm" data-close aria-label="${t('Fermer')}">${etIco('close')}</button></header>
    <div class="et-cm__list" id="et-cm">${loading()}</div>
    <div class="composer et-cm__in"><input class="field" id="et-cm-in" maxlength="${ET.limits.comment}" placeholder="${t('Ajouter un commentaire…')}">
    <button class="icon-btn icon-btn--accent" id="et-cm-go" aria-label="${t('Publier')}">${icon('send')}</button></div></div>`, (sh) => {
    sh.classList.add('et-sheet');
    $('[data-close]', sh).onclick = () => closeSheet();
    const load = async () => {
      const r = await etApi('etComments', { id });
      const list = r.comments || [];
      $('.et-cm__h b', sh).textContent = t('{n} commentaires', { n: etCount(list.length) });
      if (r.allowed === false && !v?.mine) { $('.et-cm__in', sh).innerHTML = `<p class="et-muted et-cm__off">${etIco('lock')}${t('Les commentaires sont désactivés')}</p>`; }
      $('#et-cm', sh).innerHTML = list.length ? list.map(c => `<div class="et-cmt">${etAv(c, 34)}
        <div class="et-cmt__b"><p class="et-cmt__u">${esc(c.name)}${c.byAuthor ? `<span class="et-badge">${t('Auteur')}</span>` : ''}</p>
          <p class="et-cmt__t">${etRich(c.content)}</p>
          <small>${etAgo(c.ts)}${c.canDelete ? ` · <button data-cdel="${c.id}">${t('Supprimer')}</button>` : ''}</small></div>
        <button class="et-cmt__like ${c.liked ? 'on' : ''}" data-clike="${c.id}">${etIco('heart')}<small>${c.likes ? etCount(c.likes) : ''}</small></button></div>`).join('')
        : `<p class="et-muted et-cm__empty">${t('Aucun commentaire pour l\'instant. Soyez le premier !')}</p>`;
      $$('[data-cdel]', sh).forEach(b => b.onclick = async () => { await etApi('etDeleteComment', { id: +b.dataset.cdel }); etPatch(id, { comments: Math.max(0, (ETV[id]?.comments || 1) - 1) }); load(); });
      $$('[data-clike]', sh).forEach(b => b.onclick = async () => {
        const x = await etApi('etCommentLike', { id: +b.dataset.clike });
        if (!x.ok) return;
        b.classList.toggle('on', x.liked); $('small', b).textContent = x.likes ? etCount(x.likes) : '';
      });
      $$('[data-user]', sh).forEach(b => b.onclick = () => { closeSheet(true); etGo('profile', { user: b.dataset.user }); });
      $$('[data-tag]', sh).forEach(b => b.onclick = () => { closeSheet(true); etGo('tag', { tag: b.dataset.tag }); });
    };
    const send = async () => {
      const i = $('#et-cm-in', sh); if (!i || !i.value.trim()) return;
      const r = await etApi('etComment', { id, content: i.value });
      if (!r.ok) return etToast(etErr(r));
      i.value = ''; etPatch(id, { comments: r.comments }); load();
    };
    $('#et-cm-go', sh)?.addEventListener('click', send);
    $('#et-cm-in', sh)?.addEventListener('keydown', (e) => { if (e.key === 'Enter') send(); });
    load();
  });
}

/* ---------- Partager : envoyer à un compte ---------- */
function etShare(id) {
  openSheet(t('Partager'), `<input class="search" id="et-sh-q" placeholder="${t('Rechercher un compte')}" autocomplete="off">
    <div class="et-share" id="et-sh-list">${loading()}</div>`, async (sh) => {
    sh.classList.add('et-sheet');
    const show = (users) => {
      $('#et-sh-list', sh).innerHTML = users.length ? users.map(u => `<button class="et-share__u" data-pick="${esc(u.username)}">${etAv(u, 52)}<small>${esc(u.name || u.username)}</small></button>`).join('')
        : `<p class="et-muted" style="grid-column:1/-1;text-align:center;padding:16px">${t('Aucun compte')}</p>`;
      $$('[data-pick]', sh).forEach(b => b.onclick = async () => {
        const r = await etApi('etShare', { id, username: b.dataset.pick });
        if (!r.ok) return etToast(etErr(r));
        etPatch(id, { shares: r.shares });
        closeSheet(); etToast(t('Vidéo envoyée à @{u}', { u: b.dataset.pick }));
      });
    };
    const [c, ib] = await Promise.all([etApi('etContacts'), etApi('etInbox')]);
    const seen = new Set(), recent = [];
    [...(ib.conversations || []), ...(c.users || [])].forEach(u => { if (!seen.has(u.username)) { seen.add(u.username); recent.push(u); } });
    show(recent);
    let tm;
    $('#et-sh-q', sh).oninput = (e) => {
      clearTimeout(tm);
      const q = e.target.value.trim();
      if (!q) return show(recent);
      tm = setTimeout(async () => { const r = await etApi('etSearch', { q }); show((r.users || []).filter(u => !u.me)); }, 250);
    };
  });
}

/* ---------- Son : écouter, utiliser ce son ---------- */
function etSoundSheet(id) {
  const v = ETV[id]; if (!v) return;
  const title = v.music ? v.music.title : t('Son original');
  openSheet('', `<div class="et-sound">
    <div class="et-sound__disc">${etAv(v, 64)}</div>
    <div><b>${esc(title)}</b><small>${v.music?.artist ? esc(v.music.artist) : '@' + esc(v.username)}</small></div></div>
    ${v.music ? `<button class="btn btn--block et-grad" data-use>${etIco('camera')}${t('Utiliser ce son')}</button>` : `<p class="et-muted" style="text-align:center">${t('Cette vidéo n\'a pas de son ajouté.')}</p>`}`, (sh) => {
    sh.classList.add('et-sheet');
    $('[data-use]', sh)?.addEventListener('click', () => {
      closeSheet(true);
      ET.draft = { music: { ref: 'video:' + id, title: v.music.title, artist: v.music.artist } };
      etGo('create');
    });
  });
}

/* =========================================================
   ACCUEIL : Pour toi / Abonnements
   ========================================================= */
async function etHome(params, tok) {
  const tab = params.tab || ET.tab || 'foryou';
  ET.tab = tab;
  const main = etShell('home', `<div class="et-feedtop">
      <button class="et-feedtop__tab ${tab === 'following' ? 'on' : ''}" data-ftab="following">${t('Abonnements')}</button><i></i>
      <button class="et-feedtop__tab ${tab === 'foryou' ? 'on' : ''}" data-ftab="foryou">${t('Pour toi')}</button>
      <button class="et-feedtop__s" data-go-search aria-label="${t('Rechercher')}">${etIco('discover')}</button></div>
    <div class="et-reel" id="et-reel">${loading()}</div>`);
  $$('[data-ftab]', main).forEach(b => b.onclick = () => { if (b.dataset.ftab !== ET.tab) { etStopAll(); etHome({ tab: b.dataset.ftab }, ET.tok); } });
  $('[data-go-search]', main).onclick = () => etTab('discover');
  let f = ET.feeds[tab];
  if (!f || params.fresh) {
    const r = await etApi('etFeed', { tab });
    if (tok !== ET.tok || ET.tab !== tab) return;
    f = ET.feeds[tab] = { videos: r.videos || [], more: !!r.more };
  }
  const emptyHtml = tab === 'following'
    ? `<div class="et-reel__empty">${etIco('user')}<b>${t('Suivez des comptes')}</b><p>${t('Les vidéos des comptes que vous suivez apparaîtront ici.')}</p><button class="btn et-grad" data-ftab2="foryou">${t('Voir Pour toi')}</button></div>`
    : `<div class="et-reel__empty">${etIco('camera')}<b>${t('Aucune vidéo pour le moment')}</b><p>${t('Filmez avec l\'appareil photo puis publiez la première vidéo de la ville !')}</p><button class="btn et-grad" data-create>${t('Créer une vidéo')}</button></div>`;
  etPlayer($('#et-reel'), f.videos, {
    more: f.more, empty: emptyHtml,
    loadMore: async (P) => {
      const last = P.videos[P.videos.length - 1];
      const r = await etApi('etFeed', tab === 'following' ? { tab, before: last?.id } : { tab, seen: P.videos.map(v => v.id) });
      P.more = !!r.more; f.more = P.more;
      f.videos.push(...(r.videos || []));
      return r.videos || [];
    },
  });
  $('[data-ftab2]', main)?.addEventListener('click', () => etHome({ tab: 'foryou' }, ET.tok));
  $('[data-create]', main)?.addEventListener('click', () => etTab('create'));
}

// Vidéo(s) ouvertes depuis une grille, une conversation, une activité
async function etWatch(params, tok) {
  const main = etShell('watch', `<button class="et-watch__back" data-back aria-label="${t('Retour')}">${etIco('back')}</button><div class="et-reel" id="et-reel">${loading()}</div>`, { noNav: true, dark: true });
  let list = params.list ? ET.lists[params.list] : null;
  if (!list) {
    const r = await etApi('etVideo', { id: params.id });
    if (tok !== ET.tok) return;
    if (!r.ok) { $('#et-reel').innerHTML = `<div class="et-reel__empty">${etIco('close')}<b>${etErr(r)}</b></div>`; return; }
    list = [r.video];
  }
  etPlayer($('#et-reel'), list, { start: params.start || 0 });
}

/* =========================================================
   DÉCOUVRIR : recherche, hashtags tendance, vidéos populaires
   ========================================================= */
function etGrid(videos, listKey, opts = {}) {
  ET.lists[listKey] = videos;
  if (!videos.length) return opts.empty || `<p class="et-muted et-grid__empty">${t('Aucune vidéo')}</p>`;
  return `<div class="et-grid">${videos.map((v, i) => `<button class="et-cell" data-watch="${i}" data-list="${listKey}" style="--hue:${(v.id * 47) % 360}">
    ${etVideoTag(v.url)}<span class="et-cell__v">${etIco(opts.likes ? 'heart' : 'play')}${etCount(opts.likes ? v.likes : v.views)}</span></button>`).join('')}</div>`;
}
function etWireGrid(root) {
  $$('[data-watch]', root).forEach(b => b.onclick = () => etGo('watch', { list: b.dataset.list, start: +b.dataset.watch }));
}
async function etDiscover(params, tok) {
  const main = etShell('discover', `<div class="et-disc-top"><div class="et-search">${etIco('discover')}<input id="et-q" placeholder="${t('Rechercher')}" autocomplete="off" value="${esc(params.q || '')}"></div></div>
    <div id="et-dbody" class="et-pad">${loading()}</div>`);
  const body = $('#et-dbody');
  const showHome = async () => {
    const r = await etApi('etDiscover');
    if (tok !== ET.tok) return;
    body.innerHTML = `${(r.tags || []).length ? `<h2 class="et-h2">${t('Tendances')}</h2><div class="et-trends">${r.tags.map((x, i) => `<button class="et-trend" data-tag="${esc(x.tag)}">
        <span class="et-trend__n">${i + 1}</span><span class="et-trend__i">${etIco('hash')}</span><span class="et-trend__t"><b>#${esc(x.tag)}</b><small>${t('{n} vidéos', { n: etCount(x.videos) })} · ${t('{n} vues', { n: etCount(x.views) })}</small></span></button>`).join('')}</div>` : ''}
      <h2 class="et-h2">${t('Populaires')}</h2>${etGrid(r.videos || [], 'disc')}`;
    $$('[data-tag]', body).forEach(b => b.onclick = () => etGo('tag', { tag: b.dataset.tag }));
    etWireGrid(body);
  };
  let sTab = 'top';
  const showSearch = async (q) => {
    const r = await etApi('etSearch', { q });
    if (tok !== ET.tok || $('#et-q')?.value.trim() !== q) return;
    const users = r.users || [], vids = r.videos || [], tags = r.tags || [];
    const tabs = `<div class="et-stabs">${[['top', 'Top'], ['users', 'Comptes'], ['videos', 'Vidéos'], ['tags', 'Hashtags']].map(([k, l]) => `<button data-stab="${k}" class="${sTab === k ? 'on' : ''}">${t(l)}</button>`).join('')}</div>`;
    const userRows = (list) => list.map(u => `<button class="et-urow" data-user="${esc(u.username)}">${etAv(u, 48)}<span><b>${esc(u.username)}</b><small>${esc(u.name)} · ${t('{n} abonnés', { n: etCount(u.followers) })}</small></span></button>`).join('');
    const tagRows = tags.map(x => `<button class="et-trend" data-tag="${esc(x)}"><span class="et-trend__i">${etIco('hash')}</span><span class="et-trend__t"><b>#${esc(x)}</b></span></button>`).join('');
    let html = '';
    if (sTab === 'top') html = `${users.length ? userRows(users.slice(0, 3)) : ''}${tags.length ? `<div class="et-trends">${tagRows}</div>` : ''}${etGrid(vids, 'search')}`;
    if (sTab === 'users') html = users.length ? userRows(users) : `<p class="et-muted et-grid__empty">${t('Aucun compte')}</p>`;
    if (sTab === 'videos') html = etGrid(vids, 'search');
    if (sTab === 'tags') html = tagRows ? `<div class="et-trends">${tagRows}</div>` : `<p class="et-muted et-grid__empty">${t('Aucun hashtag')}</p>`;
    body.innerHTML = tabs + html;
    $$('[data-stab]', body).forEach(b => b.onclick = () => { sTab = b.dataset.stab; showSearch(q); });
    $$('[data-user]', body).forEach(b => b.onclick = () => etGo('profile', { user: b.dataset.user }));
    $$('[data-tag]', body).forEach(b => b.onclick = () => etGo('tag', { tag: b.dataset.tag }));
    etWireGrid(body);
  };
  let tm;
  $('#et-q').oninput = (e) => {
    clearTimeout(tm);
    const q = e.target.value.trim();
    const cur = S.stack[S.stack.length - 1]; if (cur?.id === 'elytok') cur.params = Object.assign({}, cur.params, { q });
    tm = setTimeout(() => q ? showSearch(q) : showHome(), 260);
  };
  if (params.q) showSearch(params.q); else showHome();
}

async function etTagPage(params, tok) {
  const tag = String(params.tag || '').replace(/^#/, '');
  const main = etShell('tag', `${etTop('#' + esc(tag))}<div class="et-pad">${loading()}</div>`);
  const r = await etApi('etHashtag', { tag });
  if (tok !== ET.tok) return;
  $('.et-pad', main).innerHTML = `<div class="et-taghead"><span class="et-taghead__i">${etIco('hash')}</span><div><b>#${esc(tag)}</b>
    <small>${t('{n} vues', { n: etCount(r.views || 0) })} · ${t('{n} vidéos', { n: etCount((r.videos || []).length) })}</small></div></div>${etGrid(r.videos || [], 'tag')}`;
  etWireGrid(main);
}

/* =========================================================
   CRÉER : vidéo de la galerie, légende, son, commentaires
   ========================================================= */
async function etCreate(params, tok) {
  const d = ET.draft = Object.assign({ url: '', caption: '', music: null, allowComments: true }, ET.draft || {});
  const main = etShell('create', `${etTop(t('Nouvelle vidéo'))}<div class="et-pad">${loading()}</div>`);
  const pad = $('.et-pad', main);
  const gal = (await etGallery()).filter(p => p.type === 'video');
  if (tok !== ET.tok) return;
  const max = ET.limits.maxSeconds || 0;
  if (!gal.length) {
    pad.innerHTML = `<div class="et-reel__empty et-reel__empty--light">${etIco('camera')}<b>${t('Aucune vidéo dans votre galerie')}</b>
      <p>${t('Ouvrez l\'appareil photo, passez en mode Vidéo et filmez. Vos vidéos arrivent ici.')}</p><button class="btn et-grad" data-cam>${t('Ouvrir l\'appareil photo')}</button></div>`;
    $('[data-cam]', pad).onclick = () => openApp('camera');
    return;
  }
  if (!d.url) {
    pad.innerHTML = `${d.music ? `<p class="et-chosen">${etIco('music')}<span>${t('Son : {t}', { t: esc(d.music.title) })}</span><button data-nomusic aria-label="${t('Retirer le son')}">${etIco('close')}</button></p>` : ''}
      <p class="et-lbl">${t('Choisissez une vidéo de votre galerie')}</p>
      <div class="et-grid">${gal.map((p, i) => `<button class="et-cell ${max && p.duration > max ? 'et-cell--off' : ''}" data-pick="${i}">${etVideoTag(p.url)}
        <span class="et-cell__v">${p.duration ? duration(p.duration) : ''}</span>${max && p.duration > max ? `<span class="et-cell__x">${t('Trop longue')}</span>` : ''}</button>`).join('')}</div>`;
    $('[data-nomusic]', pad)?.addEventListener('click', () => { d.music = null; etCreate(params, ET.tok); });
    $$('[data-pick]', pad).forEach(b => b.onclick = () => {
      const p = gal[+b.dataset.pick];
      if (max && p.duration > max) return etToast(t('Vidéo trop longue ({n} s maximum)', { n: max }));
      d.url = p.url; d.duration = p.duration; etCreate(params, ET.tok);
    });
    return;
  }
  const L = ET.limits.caption;
  pad.innerHTML = `<div class="et-compose">
      <div class="et-compose__prev"><video src="${esc(d.url)}" autoplay loop muted playsinline></video><button class="et-compose__change" data-change>${t('Changer')}</button></div>
      <div class="et-compose__txt">
        <textarea class="field" id="et-cap" maxlength="${L}" rows="5" placeholder="${t('Décrivez votre vidéo…')}">${esc(d.caption)}</textarea>
        <div class="et-compose__chips"><button data-ins="#"># ${t('Hashtags')}</button><button data-ins="@">@ ${t('Mentionner')}</button><span id="et-capn">${d.caption.length}/${L}</span></div>
      </div></div>
    <button class="et-row" data-music>${etIco('music')}<span><b>${t('Son')}</b><small>${d.music ? esc(d.music.title) + (d.music.artist ? ' · ' + esc(d.music.artist) : '') : t('Son original')}</small></span>${d.music ? `<i data-nomusic>${etIco('close')}</i>` : ''}</button>
    <label class="et-row"><span>${etIco('comment')}</span><span><b>${t('Autoriser les commentaires')}</b></span>
      <input type="checkbox" class="switch" id="et-allow" ${d.allowComments ? 'checked' : ''}></label>
    <p class="error-text" id="et-perr"></p>
    <button class="btn btn--block et-grad et-publish" id="et-pub">${t('Publier')}</button>`;
  const cap = $('#et-cap', pad);
  cap.oninput = () => { d.caption = cap.value; $('#et-capn').textContent = `${cap.value.length}/${L}`; };
  $$('[data-ins]', pad).forEach(b => b.onclick = () => { const s = cap.selectionStart ?? cap.value.length; cap.value = cap.value.slice(0, s) + (s && !/\s$/.test(cap.value.slice(0, s)) ? ' ' : '') + b.dataset.ins + cap.value.slice(s); cap.focus(); cap.oninput(); });
  $('[data-change]', pad).onclick = () => { d.url = ''; etCreate(params, ET.tok); };
  $('#et-allow', pad).onchange = (e) => { d.allowComments = e.target.checked; };
  $('[data-music]', pad).onclick = (e) => {
    if (e.target.closest('[data-nomusic]')) { d.music = null; etCreate(params, ET.tok); return; }
    etMusicPicker((m) => { d.music = m; etCreate(params, ET.tok); });
  };
  $('#et-pub', pad).onclick = async () => {
    const b = $('#et-pub', pad); b.disabled = true;
    const r = await etApi('etPost', { url: d.url, caption: cap.value, music: d.music?.ref, allowComments: d.allowComments });
    b.disabled = false;
    if (!r.ok) { $('#et-perr').textContent = etErr(r); return; }
    ET.draft = null; ET.feeds = {};
    etToast(t('Vidéo publiée !'));
    etTab('me');
  };
}
function etMusicPicker(onPick) {
  openSheet(t('Ajouter un son'), `<div id="et-mu">${loading()}</div>`, async (sh) => {
    sh.classList.add('et-sheet');
    const r = await etApi('etMusic');
    const row = (m) => `<button class="et-mrow" data-ref="${esc(m.ref)}">${etIco('music')}<span><b>${esc(m.title)}</b><small>${esc(m.artist || '')}</small></span></button>`;
    const cat = r.catalog || [], lib = r.library || [];
    $('#et-mu', sh).innerHTML = (cat.length ? `<p class="et-lbl">${t('Sons ElyTok')}</p>${cat.map(row).join('')}` : '')
      + (lib.length ? `<p class="et-lbl">${t('Ma bibliothèque Itoune')}</p>${lib.map(row).join('')}` : '')
      + (!cat.length && !lib.length ? `<p class="et-muted" style="text-align:center;padding:16px">${t('Ajoutez des morceaux dans Itoune, ou utilisez le son d\'une autre vidéo (icône disque).')}</p>` : '');
    $$('[data-ref]', sh).forEach(b => b.onclick = () => {
      const m = [...cat, ...lib].find(x => x.ref === b.dataset.ref);
      closeSheet(true); onPick({ ref: m.ref, title: m.title, artist: m.artist });
    });
  });
}

/* =========================================================
   BOÎTE DE RÉCEPTION : activité + messages
   ========================================================= */
const ET_ACT = { like: 'a aimé votre vidéo.', comment: 'a commenté :', follow: 's\'est abonné(e) à vous.', mention: 'vous a mentionné(e) :' };
// Texte d'une activité : phrase traduite + extrait (commentaire, légende) sécurisé
const etActText = (it) => `${t(ET_ACT[it.type] || '')}${it.text ? ' ' + etRich(it.text) : ''}`;
async function etInbox(params, tok) {
  const main = etShell('inbox', `<header class="et-top et-top--c"><h1 class="et-title">${t('Boîte de réception')}</h1>
    <div class="et-top__r"><button class="et-ib" data-new aria-label="${t('Nouveau message')}">${etIco('edit')}</button></div></header><div class="et-pad">${loading()}</div>`);
  $('[data-new]', main).onclick = () => etNewMessage();
  const r = await etApi('etInbox');
  if (tok !== ET.tok) return;
  ET.badges = r.badges || ET.badges; ET.badges.notifs = 0; etSyncBadge();
  const convs = r.conversations || [], items = r.items || [];
  $('.et-pad', main).innerHTML = `<h2 class="et-h2">${t('Messages')}</h2>
    ${convs.length ? convs.map(c => `<button class="et-urow" data-chat="${esc(c.username)}">${etAv(c, 50)}<span><b>${esc(c.name)}</b>
      <small>${c.fromMe ? t('Vous : ') : ''}${c.video_id ? t('a partagé une vidéo') : esc(c.content)} · ${etAgo(c.ts)}</small></span>${c.unread ? `<i class="et-unread">${c.unread}</i>` : ''}</button>`).join('')
      : `<p class="et-muted et-grid__empty">${t('Aucun message. Partagez une vidéo ou écrivez à un compte.')}</p>`}
    <h2 class="et-h2">${t('Activité')}</h2>
    ${items.length ? items.map(it => `<div class="et-arow ${it.unread ? 'unread' : ''}">
      <button data-user="${esc(it.username)}">${etAv(it, 46)}</button>
      <p><button data-user="${esc(it.username)}"><b>${esc(it.name)}</b></button> ${etActText(it)}<small>${etAgo(it.ts)}</small></p>
      ${it.video_url ? `<button class="et-arow__v" data-vid="${it.video_id}">${etVideoTag(it.video_url)}</button>`
        : it.type === 'follow' && !it.following ? `<button class="et-pill" data-fb="${esc(it.username)}">${t('Suivre en retour')}</button>` : ''}</div>`).join('')
      : `<p class="et-muted et-grid__empty">${t('Les j\'aime, commentaires, mentions et nouveaux abonnés apparaîtront ici.')}</p>`}`;
  $$('[data-chat]', main).forEach(b => b.onclick = () => etGo('chat', { user: b.dataset.chat }));
  $$('[data-user]', main).forEach(b => b.onclick = () => etGo('profile', { user: b.dataset.user }));
  $$('[data-vid]', main).forEach(b => b.onclick = () => etGo('watch', { id: +b.dataset.vid }));
  $$('[data-fb]', main).forEach(b => b.onclick = async () => { const x = await etApi('etFollow', { username: b.dataset.fb, follow: true }); if (x.ok) { b.textContent = t('Abonné(e)'); b.disabled = true; b.classList.add('on'); } });
}
function etNewMessage() {
  openSheet(t('Nouveau message'), `<input class="search" id="et-nm" placeholder="${t('Rechercher un compte')}" autocomplete="off"><div id="et-nml"></div>`, (sh) => {
    sh.classList.add('et-sheet');
    let tm;
    $('#et-nm', sh).oninput = (e) => {
      clearTimeout(tm);
      const q = e.target.value.trim();
      tm = setTimeout(async () => {
        const r = q ? await etApi('etSearch', { q }) : { users: [] };
        $('#et-nml', sh).innerHTML = (r.users || []).filter(u => !u.me).map(u => `<button class="et-urow" data-u="${esc(u.username)}">${etAv(u, 42)}<span><b>${esc(u.username)}</b><small>${esc(u.name)}</small></span></button>`).join('');
        $$('[data-u]', sh).forEach(b => b.onclick = () => { closeSheet(true); etGo('chat', { user: b.dataset.u }); });
      }, 250);
    };
  });
}
function etBubble(m) {
  const vid = m.video_id && m.video_url ? `<button class="et-bub__v" data-vid="${m.video_id}">${etVideoTag(m.video_url)}<span>${etIco('play')}</span><small>@${esc(m.video_user || '')}</small></button>` : '';
  return `<div class="et-bub ${m.mine ? 'mine' : ''}" data-mid="${m.id}">${vid}${m.content ? `<p>${etRich(m.content)}</p>` : ''}</div>`;
}
async function etChat(params, tok) {
  const main = etShell('chat', `${etTop(`<button class="et-chat__who" data-user="${esc(params.user)}">@${esc(params.user)}</button>`)}
    <div class="et-msgs" id="et-msgs">${loading()}</div>
    <div class="composer et-chat__in"><input class="field" id="et-msg" maxlength="${ET.limits.message}" placeholder="${t('Envoyer un message…')}">
    <button class="icon-btn icon-btn--accent" id="et-msg-go" aria-label="${t('Envoyer')}">${icon('send')}</button></div>`, { noNav: true });
  ET.chat = params.user;
  const load = async () => {
    const r = await etApi('etConversation', { username: params.user });
    if (tok !== ET.tok) return;
    if (!r.ok) { $('#et-msgs').innerHTML = empty(t('Conversation indisponible'), etErr(r)); return; }
    if (r.badges) { ET.badges = r.badges; etSyncBadge(); }
    const box = $('#et-msgs');
    box.innerHTML = (r.messages || []).length ? r.messages.map(etBubble).join('') : `<p class="et-muted et-grid__empty">${t('Dites bonjour à @{u} !', { u: esc(params.user) })}</p>`;
    $$('[data-vid]', box).forEach(b => b.onclick = () => etGo('watch', { id: +b.dataset.vid }));
    box.scrollTop = box.scrollHeight;
  };
  $('[data-user]', main).onclick = () => etGo('profile', { user: params.user });
  const send = async () => {
    const i = $('#et-msg'); if (!i.value.trim()) return;
    const r = await etApi('etSend', { username: params.user, content: i.value });
    if (!r.ok) return etToast(etErr(r));
    i.value = ''; load();
  };
  $('#et-msg-go').onclick = send;
  $('#et-msg').onkeydown = (e) => { if (e.key === 'Enter') send(); };
  load();
}

/* =========================================================
   PROFIL : moi ou un autre compte
   ========================================================= */
async function etProfile(params, tok) {
  const isMe = !params.user || params.user === ET.acc?.username;
  const page = isMe && !params.user ? 'me' : 'profile';
  const main = etShell(page, `<div class="et-pad">${loading()}</div>`);
  const r = await etApi('etProfile', isMe ? {} : { username: params.user });
  if (tok !== ET.tok) return;
  if (!r.ok) { $('.et-pad', main).innerHTML = empty(t('Compte introuvable'), etErr(r)); return; }
  const p = r.profile;
  if (p.me) ET.acc = Object.assign(ET.acc || {}, { username: p.username, name: p.name, avatar: p.avatar, bio: p.bio });
  const tab = params.tab || 'videos';
  main.innerHTML = `<header class="et-top et-top--c">${page === 'profile' ? `<button class="et-ib" data-back aria-label="${t('Retour')}">${etIco('back')}</button>` : '<span class="et-ib"></span>'}
      <h1 class="et-title">${esc(p.name)}</h1><div class="et-top__r">${p.me ? `<button class="et-ib" data-edit aria-label="${t('Modifier le profil')}">${etIco('edit')}</button>` : ''}</div></header>
    <section class="et-prof">
      <div class="et-prof__av">${etAv(p, 92)}</div>
      <p class="et-prof__u">@${esc(p.username)}</p>
      <div class="et-prof__n">
        <button data-follows="following"><b>${etCount(p.counts.following)}</b><small>${t('Abonnements')}</small></button>
        <button data-follows="followers"><b data-fcount>${etCount(p.counts.followers)}</b><small>${t('Abonnés')}</small></button>
        <span><b>${etCount(p.counts.likes)}</b><small>${t('J\'aime')}</small></span>
      </div>
      <div class="et-prof__btns">${p.me ? `<button class="btn et-btn2" data-edit>${t('Modifier le profil')}</button>`
        : `<button class="btn ${p.following ? 'et-btn2' : 'et-grad'}" data-fol>${p.following ? t('Abonné(e)') : p.followsMe ? t('Suivre en retour') : t('Suivre')}</button>
           <button class="btn et-btn2" data-msg>${t('Message')}</button>`}</div>
      ${p.bio ? `<p class="et-prof__bio">${etRich(p.bio)}</p>` : ''}
    </section>
    <div class="et-ptabs">
      <button data-ptab="videos" class="${tab === 'videos' ? 'on' : ''}" aria-label="${t('Vidéos')}">${etIco('grid')}</button>
      ${p.me ? `<button data-ptab="saved" class="${tab === 'saved' ? 'on' : ''}" aria-label="${t('Favoris')}">${etIco('save')}</button>
      <button data-ptab="liked" class="${tab === 'liked' ? 'on' : ''}" aria-label="${t('J\'aime')}">${etIco('heart')}</button>` : ''}
    </div>
    <div id="et-pgrid">${loading()}</div>`;
  $$('[data-edit]', main).forEach(b => b.onclick = () => etGo('edit'));
  $$('[data-follows]', main).forEach(b => b.onclick = () => etGo('follows', { user: p.username, kind: b.dataset.follows }));
  $('[data-msg]', main)?.addEventListener('click', () => etGo('chat', { user: p.username }));
  $('[data-fol]', main)?.addEventListener('click', async (e) => {
    const b = e.currentTarget;
    const x = await etApi('etFollow', { username: p.username, follow: !p.following });
    if (!x.ok) return etToast(etErr(x));
    p.following = x.following;
    b.textContent = p.following ? t('Abonné(e)') : t('Suivre');
    b.className = `btn ${p.following ? 'et-btn2' : 'et-grad'}`;
    $('[data-fcount]', main).textContent = etCount(x.counts.followers);
    ET.feeds.following = null;
  });
  $$('[data-ptab]', main).forEach(b => b.onclick = () => {
    const cur = S.stack[S.stack.length - 1]; if (cur?.id === 'elytok') cur.params = Object.assign({}, cur.params, { tab: b.dataset.ptab });
    etProfile(Object.assign({}, params, { tab: b.dataset.ptab }), ET.tok);
  });
  const g = await etApi('etUserVideos', { username: p.me ? undefined : p.username, tab });
  if (tok !== ET.tok && ET.tok !== tok + 0) return;
  const emptyMsg = tab === 'saved' ? t('Ajoutez des vidéos à vos favoris avec l\'icône signet.') : tab === 'liked' ? t('Les vidéos que vous aimez apparaîtront ici.')
    : p.me ? t('Publiez votre première vidéo avec le bouton +.') : t('Aucune vidéo publiée.');
  $('#et-pgrid', main).innerHTML = etGrid(g.videos || [], 'prof:' + p.username + ':' + tab, { empty: `<p class="et-muted et-grid__empty">${emptyMsg}</p>` });
  etWireGrid(main);
}

async function etEdit(params, tok) {
  const a = ET.acc || {};
  const d = { avatar: a.avatar || '' };
  const main = etShell('edit', `${etTop(t('Modifier le profil'))}<div class="et-pad et-form">
    <button class="et-edit__av" data-av>${etAv(a, 96)}<span>${t('Changer la photo')}</span></button>
    <label class="et-lbl">${t('Nom affiché')}</label><input class="field" id="et-e-name" maxlength="40" value="${esc(a.name || '')}">
    <label class="et-lbl">${t('Nom d\'utilisateur')}</label><div class="handle-field"><span>@</span><input class="field" id="et-e-user" maxlength="20" value="${esc(a.username || '')}"></div>
    <label class="et-lbl">${t('Bio')}</label><textarea class="field" id="et-e-bio" rows="3" maxlength="${ET.limits.bio}">${esc(a.bio || '')}</textarea>
    <p class="error-text" id="et-e-err"></p>
    <button class="btn btn--block et-grad" id="et-e-save">${t('Enregistrer')}</button></div>`, { noNav: true });
  $('#et-e-user').oninput = (e) => { e.target.value = e.target.value.toLowerCase().replace(/[^a-z0-9_.]/g, ''); };
  $('[data-av]', main).onclick = async () => {
    const photos = (await etGallery()).filter(p => (p.type || 'photo') === 'photo');
    openSheet(t('Photo de profil'), photos.length ? `<div class="et-grid et-grid--sq">${photos.map((p, i) => `<button class="et-cell" data-ph="${i}"><img src="${esc(p.url)}" alt=""></button>`).join('')}</div>
      <button class="btn btn--ghost btn--block" data-none style="margin-top:10px">${t('Retirer la photo')}</button>` : `<p class="et-muted" style="text-align:center;padding:16px">${t('Prenez une photo avec l\'appareil photo pour l\'utiliser ici.')}</p>`, (sh) => {
      $$('[data-ph]', sh).forEach(b => b.onclick = () => { d.avatar = photos[+b.dataset.ph].url; $('[data-av] .et-av', main).outerHTML = etAv(Object.assign({}, a, { avatar: d.avatar }), 96); closeSheet(); });
      $('[data-none]', sh)?.addEventListener('click', () => { d.avatar = ''; $('[data-av] .et-av', main).outerHTML = etAv(Object.assign({}, a, { avatar: '' }), 96); closeSheet(); });
    });
  };
  $('#et-e-save').onclick = async () => {
    const r = await etApi('etUpdateProfile', { display: $('#et-e-name').value, username: $('#et-e-user').value, bio: $('#et-e-bio').value, avatar: d.avatar });
    if (!r.ok) { $('#et-e-err').textContent = etErr(r); return; }
    ET.acc = r.account; etToast(t('Profil enregistré')); back();
  };
}

async function etFollows(params, tok) {
  const kind = params.kind === 'following' ? 'following' : 'followers';
  const main = etShell('follows', `${etTop('@' + esc(params.user))}
    <div class="et-stabs"><button data-k="following" class="${kind === 'following' ? 'on' : ''}">${t('Abonnements')}</button><button data-k="followers" class="${kind === 'followers' ? 'on' : ''}">${t('Abonnés')}</button></div>
    <div class="et-pad">${loading()}</div>`);
  $$('[data-k]', main).forEach(b => b.onclick = () => etFollows(Object.assign({}, params, { kind: b.dataset.k }), ET.tok));
  const r = await etApi('etFollowList', { username: params.user, kind });
  if (tok !== ET.tok && ET.tok !== tok) return;
  const list = r.users || [];
  $('.et-pad', main).innerHTML = list.length ? list.map(u => `<div class="et-urow"><button class="et-urow__l" data-user="${esc(u.username)}">${etAv(u, 46)}<span><b>${esc(u.username)}</b><small>${esc(u.name)}</small></span></button>
      ${u.me ? '' : `<button class="et-pill ${u.following ? 'on' : ''}" data-f="${esc(u.username)}" data-on="${u.following ? 1 : 0}">${u.following ? t('Abonné(e)') : t('Suivre')}</button>`}</div>`).join('')
    : `<p class="et-muted et-grid__empty">${kind === 'followers' ? t('Aucun abonné') : t('Aucun abonnement')}</p>`;
  $$('[data-user]', main).forEach(b => b.onclick = () => etGo('profile', { user: b.dataset.user }));
  $$('[data-f]', main).forEach(b => b.onclick = async () => {
    const on = b.dataset.on === '1';
    const x = await etApi('etFollow', { username: b.dataset.f, follow: !on });
    if (!x.ok) return etToast(etErr(x));
    b.dataset.on = on ? '0' : '1'; b.classList.toggle('on', !on); b.textContent = !on ? t('Abonné(e)') : t('Suivre');
  });
}

const ET_PAGES = { home: etHome, discover: etDiscover, create: etCreate, inbox: etInbox, me: etProfile, profile: etProfile, watch: etWatch, tag: etTagPage, chat: etChat, edit: etEdit, follows: etFollows };

/* ---------- Événements en direct (serveur → téléphone) ---------- */
function etPush(d) {
  if (d.badges) { ET.badges = d.badges; etSyncBadge(); if (typeof renderHome === 'function' && !S.currentApp && S.open && !S.locked) renderHome(); }
  const cur = S.stack[S.stack.length - 1];
  const here = S.open && S.currentApp === 'elytok' && cur?.id === 'elytok';
  if (d.type === 'message' && here) {
    if (cur.params?.page === 'chat' && ET.chat === d.from) etChat(cur.params, ET.tok);
    else if (cur.params?.page === 'inbox') etRender({ page: 'inbox' });
  }
}

/* ---------- Aperçu navigateur (hors FiveM) : données de démonstration en mémoire ---------- */
const ETMock = (() => {
  const now = () => Math.floor(Date.now() / 1000);
  // Petites vidéos de démonstration générées dans le navigateur (dégradé animé + texte)
  const clips = [];
  const makeClip = (hue, label) => new Promise((resolve) => {
    try {
      const c = document.createElement('canvas'); c.width = 270; c.height = 480;
      const g = c.getContext('2d');
      const rec = new MediaRecorder(c.captureStream(24), { mimeType: 'video/webm' });
      const parts = []; rec.ondataavailable = (e) => e.data.size && parts.push(e.data);
      rec.onstop = () => resolve(URL.createObjectURL(new Blob(parts, { type: 'video/webm' })));
      let f = 0; rec.start();
      const draw = () => {
        const k = f / 36;
        const gr = g.createLinearGradient(0, 0, 270, 480);
        gr.addColorStop(0, `hsl(${hue},75%,${45 + 10 * Math.sin(k * 6)}%)`); gr.addColorStop(1, `hsl(${(hue + 70) % 360},70%,18%)`);
        g.fillStyle = gr; g.fillRect(0, 0, 270, 480);
        g.fillStyle = 'rgba(255,255,255,.18)'; g.beginPath(); g.arc(135 + 70 * Math.cos(k * 6), 190 + 50 * Math.sin(k * 6), 60, 0, 7); g.fill();
        g.fillStyle = 'rgba(0,0,0,.3)'; g.beginPath(); g.moveTo(0, 360); g.lineTo(90, 300 + 20 * Math.sin(k * 5)); g.lineTo(180, 340); g.lineTo(270, 290); g.lineTo(270, 480); g.lineTo(0, 480); g.fill();
        g.fillStyle = '#fff'; g.font = 'bold 26px sans-serif'; g.fillText(label, 24, 440);
        if (++f < 36) requestAnimationFrame(draw); else rec.stop();
      };
      draw();
    } catch (e) { resolve(''); }
  });
  const ready = Promise.all([[280, 'Vinewood'], [20, 'Del Perro'], [200, 'Sandy Shores'], [320, 'Maze Bank'], [140, 'Paleto']].map(([h, l]) => makeClip(h, l))).then(list => clips.push(...list));
  const img = (h, txt = '') => 'data:image/svg+xml;utf8,' + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200"><rect width="200" height="200" fill="hsl(${h},60%,45%)"/><text x="100" y="125" font-family="sans-serif" font-size="80" text-anchor="middle" fill="#fff">${txt}</text></svg>`);
  const U = {
    me: { username: 'lena.duval', name: 'Léna Duval', avatar: img(280, 'L'), bio: 'Je filme Los Santos 🎥 #vinewood' },
    malik: { username: 'malik', name: 'Malik Benali', avatar: img(20, 'M'), bio: 'Cuisinier le jour, DJ la nuit.' },
    ines: { username: 'ines.m', name: 'Inès Morel', avatar: '', bio: '' },
  };
  let acc = null, vid = 0;
  const follows = new Set(['malik']);
  const V = [];
  const add = (u, clip, caption, music, stats, ago) => V.push(Object.assign({ id: ++vid, user: u, clip, caption, music, ts: now() - ago, liked: false, saved: false, allowComments: true }, stats));
  add('malik', 1, 'Coucher de soleil sur la jetée 🌅 #delperro #lofi avec @lena.duval', { title: 'Nuit sur Vinewood', artist: 'Los Santos Lofi', url: '' }, { views: 18200, likes: 4210, comments: 3, shares: 120, saves: 330 }, 3600);
  add('ines', 2, 'Road trip dans le désert #sandyshores #roadtrip', null, { views: 920, likes: 87, comments: 1, shares: 4, saves: 9 }, 7200);
  add('malik', 3, 'Vue du toit de la Maze Bank 😮 #lossantos', { title: 'Skyline', artist: 'DJ Malik', url: '' }, { views: 52300, likes: 12900, comments: 0, shares: 840, saves: 2100 }, 86400);
  add('me', 0, 'Balade à Vinewood #vinewood #lofi', null, { views: 340, likes: 52, comments: 0, shares: 2, saves: 5 }, 172800);
  add('ines', 4, 'Paleto au petit matin #paleto', null, { views: 150, likes: 12, comments: 0, shares: 0, saves: 1 }, 260000);
  const comments = { 1: [{ id: 1, user: 'ines', content: 'Magnifique 😍 #delperro', likes: 12, ts: now() - 1800 }, { id: 2, user: 'me', content: 'Merci @malik !', likes: 3, ts: now() - 900 }, { id: 3, user: 'malik', content: 'On y retourne ce soir ?', likes: 0, ts: now() - 300 }], 2: [{ id: 4, user: 'malik', content: 'Prends de l\'eau 😂', likes: 1, ts: now() - 3000 }] };
  let cid = 10;
  const pub = (v) => ({ id: v.id, url: clips[v.clip] || '', duration: 12, caption: v.caption, music: v.music, ts: v.ts, views: v.views, likes: v.likes, comments: (comments[v.id] || []).length, shares: v.shares, saves: v.saves,
    username: U[v.user].username, name: U[v.user].name, avatar: U[v.user].avatar, mine: v.user === 'me', liked: v.liked, saved: v.saved, following: follows.has(v.user), canFollow: v.user !== 'me' && !follows.has(v.user), allowComments: v.allowComments });
  const key = (username) => Object.keys(U).find(k => U[k].username === username);
  const inbox = [{ id: 1, type: 'like', username: 'malik', name: 'Malik Benali', avatar: U.malik.avatar, video_id: 4, ts: now() - 600, unread: true },
    { id: 2, type: 'follow', username: 'ines.m', name: 'Inès Morel', avatar: '', ts: now() - 5000, following: false },
    { id: 3, type: 'comment', username: 'malik', name: 'Malik Benali', avatar: U.malik.avatar, video_id: 4, text: 'Trop beau ce coin #vinewood', ts: now() - 9000 }];
  const msgs = { malik: [{ id: 1, mine: false, content: 'Regarde ça 👀', video_id: 3, ts: now() - 4000 }, { id: 2, mine: true, content: 'Incroyable !', ts: now() - 3500 }] };
  const handlers = {
    getGallery: () => ({ ok: true, photos: [{ id: 1, type: 'video', url: clips[0] || '', duration: 12 }, { id: 2, type: 'video', url: clips[2] || '', duration: 95 }, { id: 3, type: 'photo', url: img(280, 'L') }] }),
    etInit: () => ({ ok: true, account: acc, badges: { notifs: 2, dms: 1 }, limits: { caption: 220, bio: 120, comment: 150, message: 400, maxSeconds: 60 } }),
    etCreateAccount: (a) => { if (!/^[a-z0-9_.]{3,20}$/.test(a.username || '')) return { ok: false, error: 'Nom d\'utilisateur : 3 à 20 caractères, lettres, chiffres, _ ou .' }; acc = { username: a.username, name: a.display || 'Léna Duval', avatar: U.me.avatar, bio: U.me.bio }; U.me.username = a.username; return { ok: true, account: acc }; },
    etFeed: (a) => ({ ok: true, videos: V.filter(v => a.tab === 'following' ? follows.has(v.user) : true).filter(v => !(a.seen || []).includes(v.id)).map(pub), more: false }),
    etVideo: (a) => { const v = V.find(x => x.id === a.id); return v ? { ok: true, video: pub(v) } : { ok: false, error: 'Vidéo introuvable ou supprimée' }; },
    etView: () => ({ ok: true }),
    etLike: (a) => { const v = V.find(x => x.id === a.id); const want = a.like ?? !v.liked; if (want !== v.liked) { v.liked = want; v.likes += want ? 1 : -1; } return { ok: true, liked: v.liked, likes: v.likes }; },
    etSave: (a) => { const v = V.find(x => x.id === a.id); v.saved = !v.saved; v.saves += v.saved ? 1 : -1; return { ok: true, saved: v.saved, saves: v.saves }; },
    etShare: (a) => { const v = V.find(x => x.id === a.id); v.shares++; return { ok: true, shares: v.shares }; },
    etComments: (a) => ({ ok: true, allowed: true, comments: (comments[a.id] || []).map(c => ({ id: c.id, content: c.content, likes: c.likes, ts: c.ts, username: U[c.user].username, name: U[c.user].name, avatar: U[c.user].avatar, byAuthor: V.find(x => x.id === a.id).user === c.user, liked: !!c.liked, canDelete: c.user === 'me' })) }),
    etComment: (a) => { (comments[a.id] = comments[a.id] || []).push({ id: ++cid, user: 'me', content: a.content, likes: 0, ts: now() }); return { ok: true, comments: comments[a.id].length }; },
    etCommentLike: (a) => { for (const l of Object.values(comments)) for (const c of l) if (c.id === a.id) { c.liked = !c.liked; c.likes += c.liked ? 1 : -1; return { ok: true, liked: c.liked, likes: c.likes }; } return { ok: false }; },
    etDeleteComment: (a) => { for (const k in comments) comments[k] = comments[k].filter(c => c.id !== a.id); return { ok: true }; },
    etMusic: () => ({ ok: true, catalog: [{ ref: 'cat:1', title: 'Nuit sur Vinewood', artist: 'Los Santos Lofi' }], library: [{ ref: 'lib:4', title: 'Mon morceau', artist: 'Itoune' }] }),
    etPost: (a) => { if (!a.url) return { ok: false, error: 'Choisis une vidéo de ta galerie' }; add('me', 0, a.caption || '', a.music ? { title: 'Son', artist: '' } : null, { views: 0, likes: 0, comments: 0, shares: 0, saves: 0 }, 0); return { ok: true, id: vid }; },
    etDelete: (a) => { const i = V.findIndex(v => v.id === a.id && v.user === 'me'); if (i < 0) return { ok: false }; V.splice(i, 1); return { ok: true }; },
    etProfile: (a) => { const k = a.username ? key(a.username) : 'me'; if (!k) return { ok: false, error: 'Compte introuvable' }; const mine = V.filter(v => v.user === k);
      return { ok: true, profile: Object.assign({}, U[k], { me: k === 'me', following: follows.has(k), followsMe: k === 'ines', counts: { following: k === 'me' ? follows.size : 12, followers: k === 'me' ? 1240 : 8800 + (follows.has(k) ? 1 : 0), likes: mine.reduce((s, v) => s + v.likes, 0), videos: mine.length } }) }; },
    etUserVideos: (a) => { const k = a.username ? key(a.username) : 'me'; const list = a.tab === 'saved' ? V.filter(v => v.saved) : a.tab === 'liked' ? V.filter(v => v.liked) : V.filter(v => v.user === k); return { ok: true, videos: list.map(pub) }; },
    etUpdateProfile: (a) => { if (!/^[a-z0-9_.]{3,20}$/.test(a.username || '')) return { ok: false, error: 'Nom d\'utilisateur : 3 à 20 caractères, lettres, chiffres, _ ou .' };
      Object.assign(U.me, { username: a.username, name: a.display || U.me.name, bio: a.bio || '', avatar: a.avatar || '' }); acc = Object.assign({}, U.me); return { ok: true, account: acc }; },
    etFollow: (a) => { const k = key(a.username); if (a.follow === false) follows.delete(k); else follows.add(k); return { ok: true, following: a.follow !== false, counts: { followers: 8800 + (follows.has(k) ? 1 : 0) } }; },
    etFollowList: () => ({ ok: true, users: [{ username: 'malik', name: 'Malik Benali', avatar: U.malik.avatar, following: follows.has('malik') }, { username: 'ines.m', name: 'Inès Morel', following: follows.has('ines') }] }),
    etDiscover: () => ({ ok: true, tags: [{ tag: 'lofi', videos: 2, views: 18540 }, { tag: 'vinewood', videos: 1, views: 340 }, { tag: 'delperro', videos: 1, views: 18200 }, { tag: 'lossantos', videos: 1, views: 52300 }], videos: V.slice().sort((a, b) => b.likes - a.likes).map(pub) }),
    etSearch: (a) => { const q = (a.q || '').toLowerCase().replace(/^[#@]/, ''); return { ok: true, users: Object.entries(U).filter(([, u]) => u.username.includes(q) || u.name.toLowerCase().includes(q)).map(([k, u]) => Object.assign({}, u, { me: k === 'me', followers: 1200 })), videos: V.filter(v => v.caption.toLowerCase().includes(q)).map(pub), tags: ['lofi', 'lossantos'].filter(x => x.includes(q)) }; },
    etHashtag: (a) => ({ ok: true, tag: a.tag, videos: V.filter(v => v.caption.toLowerCase().includes('#' + a.tag.toLowerCase())).map(pub), views: 18540 }),
    etInbox: () => ({ ok: true, items: inbox.map(it => Object.assign({}, it, { video_url: it.video_id ? clips[V.find(v => v.id === it.video_id)?.clip ?? 0] : null })), conversations: [{ username: 'malik', name: 'Malik Benali', avatar: U.malik.avatar, content: 'Incroyable !', fromMe: true, ts: now() - 3500, unread: 1 }], badges: { notifs: 0, dms: 1 } }),
    etConversation: (a) => ({ ok: true, messages: (msgs[key(a.username)] || []).map(m => Object.assign({}, m, m.video_id ? { video_url: clips[V.find(v => v.id === m.video_id)?.clip ?? 0], video_user: 'malik' } : {})), badges: { notifs: 0, dms: 0 } }),
    etSend: (a) => { const k = key(a.username); (msgs[k] = msgs[k] || []).push({ id: Date.now(), mine: true, content: a.content, ts: now() }); return { ok: true }; },
    etContacts: () => ({ ok: true, users: [{ username: 'malik', name: 'Malik Benali', avatar: U.malik.avatar }, { username: 'ines.m', name: 'Inès Morel' }] }),
  };
  return { call: async (name, args) => { await ready; return (handlers[name] || (() => ({ ok: false, error: 'inconnu' })))(args || {}); } };
})();
