'use strict';
/* =========================================================
   ELYPICK (ex-InstaPick) : réseau social photo
   Accueil (stories + fil), Recherche (comptes + explorer), Créer (publication / story),
   Messages, Profil ; activité, stories à la une, musique sur les publications.
   Toutes les données viennent du serveur (server/elypick.lua).
   ========================================================= */
const EP = {
  acc: null, ready: false, badges: { notifs: 0, dms: 0 }, limits: { caption: 280, bio: 150, message: 500, storyHours: 24, links: true },
  tok: 0, cache: {}, playing: null, chat: null, viewer: null, draft: null,
};
const epApi = (name, args = {}) => IS_BROWSER ? Promise.resolve(EPMock.call(name, args)) : api(name, args);
const epGallery = async () => {
  const r = IS_BROWSER ? EPMock.call('getGallery') : await api('getGallery');
  return (r.photos || []).filter(p => (p.type || 'photo') === 'photo');
};

/* ---------- Icônes ---------- */
const EPI = {
  home: '<path d="M3.5 10.5 12 3.5l8.5 7V20a1 1 0 0 1-1 1H15v-6.5H9V21H4.5a1 1 0 0 1-1-1z"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20.5 20.5-4-4"/>',
  create: '<rect x="3.5" y="3.5" width="17" height="17" rx="5"/><path d="M12 8.5v7M8.5 12h7"/>',
  send: '<path d="M21.5 2.5 10.5 13.5"/><path d="M21.5 2.5 14.8 21.5l-4.3-8-8-4.3z"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4.5 21a7.5 7.5 0 0 1 15 0"/>',
  heart: '<path d="M12 20.5s-7.6-4.6-9.4-9.3C1.3 7.8 3.6 4.5 7 4.5c2 0 3.6 1.1 5 3 1.4-1.9 3-3 5-3 3.4 0 5.7 3.3 4.4 6.7-1.8 4.7-9.4 9.3-9.4 9.3z"/>',
  comment: '<path d="M20.5 11.5a8.5 8 0 0 1-12.6 7L3.5 20l1.4-4.1A8.5 8 0 1 1 20.5 11.5z"/>',
  music: '<path d="M9 18V5.5l11-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16.5" r="3"/>',
  more: '<circle cx="5" cy="12" r="1.4" fill="currentColor"/><circle cx="12" cy="12" r="1.4" fill="currentColor"/><circle cx="19" cy="12" r="1.4" fill="currentColor"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  back: '<path d="m15 5-7 7 7 7"/>',
  grid: '<rect x="3.5" y="3.5" width="17" height="17" rx="2"/><path d="M9.2 3.5v17M14.8 3.5v17M3.5 9.2h17M3.5 14.8h17"/>',
  camera: '<path d="M4 7.5h3.2L9 5h6l1.8 2.5H20a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V8.5a1 1 0 0 1 1-1z"/><circle cx="12" cy="13.5" r="3.6"/>',
  link: '<path d="M10 14a4.5 4.5 0 0 0 6.4 0l3-3a4.5 4.5 0 0 0-6.4-6.4l-1.2 1.2"/><path d="M14 10a4.5 4.5 0 0 0-6.4 0l-3 3a4.5 4.5 0 0 0 6.4 6.4l1.2-1.2"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
  trash: '<path d="M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13"/>',
  refresh: '<path d="M20 11a8 8 0 0 0-14.6-4.5L4 8.5"/><path d="M4 4v4.5h4.5"/><path d="M4 13a8 8 0 0 0 14.6 4.5L20 15.5"/><path d="M20 20v-4.5h-4.5"/>',
  play: '<path d="M8 5.5v13l11-6.5z" fill="currentColor"/>',
  pause: '<path d="M8 5v14M16 5v14"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  star: '<path d="m12 3.5 2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.8-5.2 2.8 1-5.8-4.3-4.1 5.9-.9z"/>',
  image: '<rect x="3.5" y="4.5" width="17" height="15" rx="3"/><circle cx="9" cy="10" r="1.8"/><path d="m4 17.5 5-5 4 4 2.5-2.5 4.5 4.5"/>',
  plus: '<path d="M12 6.5v11M6.5 12h11"/>',
  story: '<circle cx="12" cy="12" r="8.5" stroke-dasharray="3 2.6"/><path d="M12 8.5v7M8.5 12h7"/>',
};
const epIco = (n, cls = '') => `<svg class="epi ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${EPI[n] || ''}</svg>`;
const epWord = () => `<span class="ep-word">Ely<b>Pick</b></span>`;

function epAv(u, size = 36, ring = '') {
  const name = u?.name || u?.display_name || u?.username || '?';
  const inner = u?.avatar
    ? `<img src="${esc(u.avatar)}" alt="" loading="lazy" onerror="this.replaceWith(Object.assign(document.createElement('i'),{textContent:'${esc(initials(name)).replace(/'/g, '')}'}))">`
    : `<i>${esc(initials(name))}</i>`;
  return `<span class="ep-av ${ring ? 'ep-av--' + ring : ''}" style="--s:${size}px;--av:${avColor(u?.username || name)}">${inner}</span>`;
}
const epCount = (n) => {
  n = Number(n) || 0;
  if (n >= 1e6) return (n / 1e6).toFixed(1).replace('.0', '') + ' M';
  if (n >= 1e4) return Math.floor(n / 1e3) + ' k';
  return n.toLocaleString(locale());
};
function epAgo(ts) {
  if (!ts) return '';
  const d = (Date.now() / 1000) - ts;
  if (d < 60) return t('à l\'instant');
  if (d < 3600) return t('il y a {n} min', { n: Math.floor(d / 60) });
  if (d < 86400) return t('il y a {n} h', { n: Math.floor(d / 3600) });
  if (d < 7 * 86400) return t('il y a {n} j', { n: Math.floor(d / 86400) });
  return new Date(ts * 1000).toLocaleDateString(locale(), { day: 'numeric', month: 'long' });
}
const epRich = (s) => esc(s).replace(/@([a-z0-9_.]{3,20})/gi, '<button class="ep-mention" data-user="$1">@$1</button>').replace(/\n/g, '<br>');
const epErr = (r) => t(r?.error || 'Action impossible pour le moment.');
function epToast(text) { notify({ app: 'instapick', title: 'ElyPick', text }); }

/* ---------- Navigation ---------- */
const ROOTS = ['home', 'search', 'new', 'inbox', 'me'];
function epGo(page, params = {}) { epStopMusic(); openApp('instapick', Object.assign({ page }, params)); }
function epTab(page) {
  epStopMusic(); closeSheet(true);
  const first = S.stack.findIndex(e => e.id === 'instapick');
  if (first >= 0) { S.stack.length = first + 1; S.stack[first].params = { page }; }
  epRender({ page });
}
function epLeave() { epStopMusic(); epCloseViewer(); EP.chat = null; }

Views.instapick = (params = {}) => {
  S.onLeave = epLeave;
  epRender(params);
};

async function epRender(params = {}) {
  const tok = ++EP.tok;
  const page = params.page || 'home';
  if (!EP.ready) {
    epShell(page, '', loading(), true);
    const r = await epApi('epInit');
    if (tok !== EP.tok) return;
    if (!r.ok) { epShell(page, '', empty(t('ElyPick indisponible'), epErr(r)), true); return; }
    EP.acc = r.account || null; EP.badges = r.badges || EP.badges; Object.assign(EP.limits, r.limits || {}); EP.ready = true;
    epSyncBadge();
  }
  if (!EP.acc) return epOnboard();
  const fn = EP_PAGES[page] || EP_PAGES.home;
  return fn(params, tok);
}

// Gabarit : barre du haut, contenu, barre de navigation en bas
function epShell(page, head, body, bare = false) {
  const root = ROOTS.includes(page) ? page : null;
  const navItem = (id, ic, label) => {
    const act = root === id;
    const badge = id === 'inbox' && EP.badges.dms > 0 ? `<span class="ep-dot">${EP.badges.dms > 9 ? '9+' : EP.badges.dms}</span>` : '';
    const inner = id === 'me' && EP.acc ? epAv(EP.acc, 26, act ? 'me' : '') : epIco(ic, act ? 'on' : '');
    return `<button class="ep-nav__b ${act ? 'active' : ''}" data-tab="${id}" aria-label="${t(label)}">${inner}${badge}</button>`;
  };
  appView.innerHTML = `<div class="ep ${bare ? 'ep--bare' : ''}" data-page="${page}">
    ${head ? `<header class="ep-top">${head}</header>` : ''}
    <main class="ep-main" id="ep-main"><div class="ep-page">${body}</div></main>
    ${bare || page === 'chat' ? '' : `<nav class="ep-nav">${navItem('home', 'home', 'Accueil')}${navItem('search', 'search', 'Recherche')}${navItem('new', 'create', 'Créer')}${navItem('inbox', 'send', 'Messages')}${navItem('me', 'user', 'Profil')}</nav>`}
  </div>`;
  $$('[data-tab]', appView).forEach(b => b.onclick = () => {
    if (b.dataset.tab === root && b.dataset.tab !== 'new') { $('#ep-main').scrollTo({ top: 0, behavior: 'smooth' }); if (root === 'home') epRender({ page: 'home', fresh: true }); return; }
    epTab(b.dataset.tab);
  });
  return $('#ep-main');
}
const epBackBtn = () => `<button class="ep-ib" data-back aria-label="${t('Retour')}">${epIco('back')}</button>`;
const epHead = (title, right = '') => `${epBackBtn()}<h1 class="ep-title">${title}</h1><div class="ep-top__r">${right}</div>`;

function epSyncBadge() {
  S.epBadge = (EP.badges.notifs || 0) + (EP.badges.dms || 0);
  const b = $('.ep-nav [data-tab="inbox"]');
  if (b) { b.querySelector('.ep-dot')?.remove(); if (EP.badges.dms > 0) b.insertAdjacentHTML('beforeend', `<span class="ep-dot">${EP.badges.dms > 9 ? '9+' : EP.badges.dms}</span>`); }
  const h = $('[data-activity]');
  if (h) h.classList.toggle('has', EP.badges.notifs > 0);
}

/* ---------- Création du compte ---------- */
function epOnboard() {
  epShell('home', '', `<div class="ep-onboard">
    <div class="ep-onboard__logo">${solidTile('instapick', 84)}</div>
    ${epWord()}
    <p class="ep-onboard__txt">${t('Partagez vos photos, suivez la ville et échangez en privé.')}</p>
    <div class="ep-form">
      <label class="ep-lbl">${t('Nom affiché')}</label>
      <input class="field" id="ep-display" maxlength="40" value="${esc(S.profile?.name || '')}">
      <label class="ep-lbl">${t('Nom d\'utilisateur')}</label>
      <div class="handle-field"><span>@</span><input class="field" id="ep-user" maxlength="20" autocomplete="off" placeholder="${t('ex. lena.duval')}"></div>
      <p class="error-text" id="ep-err"></p>
      <button class="btn btn--block ep-grad" id="ep-go">${t('Créer mon compte')}</button>
    </div></div>`, true);
  $('#ep-user').oninput = (e) => { e.target.value = e.target.value.toLowerCase().replace(/[^a-z0-9_.]/g, ''); };
  $('#ep-go').onclick = async () => {
    const r = await epApi('epCreateAccount', { username: $('#ep-user').value, display: $('#ep-display').value });
    if (!r.ok) { $('#ep-err').textContent = epErr(r); return; }
    EP.acc = r.account; epRender({ page: 'home' });
  };
}

/* ---------- Musique des publications ---------- */
function epPlay(m, key) {
  if (EP.playing === key) { epStopMusic(); return; }
  epStopMusic();
  if (typeof Music !== 'undefined' && Music.playing) Music.pause();
  EP.playing = key;
  epMarkMusic();
  if (IS_BROWSER) return;
  AudioEngine.play('ep', { url: m.url, volume: .7,
    onEnd: () => { if (EP.playing === key) epStopMusic(); },
    onError: (code) => { if (EP.playing === key) { epStopMusic(); epToast(t(YT_ERRORS[code] || 'Lecture impossible.')); } } });
}
function epStopMusic() {
  if (!EP.playing) return;
  EP.playing = null;
  if (!IS_BROWSER) AudioEngine.stop('ep');
  epMarkMusic();
}
function epMarkMusic() {
  $$('[data-music]', appView).forEach(b => {
    const on = b.dataset.music === EP.playing;
    b.classList.toggle('playing', on);
    const ic = b.querySelector('.ep-mu__ic'); if (ic) ic.innerHTML = epIco(on ? 'pause' : 'play');
  });
}
const epMusicChip = (m, key) => `<button class="ep-mu" data-music="${esc(key)}" aria-label="${t('Écouter la musique')}">
  <span class="ep-mu__ic">${epIco(EP.playing === key ? 'pause' : 'play')}</span><span class="ep-mu__eq"><i></i><i></i><i></i></span>
  <span class="ep-mu__t">${esc(m.title)}${m.artist ? ` · ${esc(m.artist)}` : ''}</span></button>`;

/* ---------- Carte de publication ---------- */
const EPPOSTS = {};
function epCard(p, opts = {}) {
  EPPOSTS[p.id] = p;
  const key = 'p' + p.id;
  return `<article class="ep-post" data-post="${p.id}">
    <header class="ep-post__h">
      <button class="ep-post__who" data-user="${esc(p.username)}">${epAv(p, 34)}<span><b>${esc(p.username)}</b>${p.music ? `<small>${epIco('music')}${esc(p.music.title)}</small>` : ''}</span></button>
      ${p.canFollow && opts.follow ? `<button class="ep-pill" data-follow="${esc(p.username)}">${t('S\'abonner')}</button>` : ''}
      ${p.mine ? `<button class="ep-ib ep-ib--sm" data-pmenu="${p.id}" aria-label="${t('Options')}">${epIco('more')}</button>` : ''}
    </header>
    <div class="ep-post__img" data-dbl="${p.id}"><img src="${esc(p.image)}" alt="" loading="lazy" onerror="this.classList.add('bad')"><span class="ep-burst">${epIco('heart')}</span>
      ${p.music ? epMusicChip(p.music, key) : ''}</div>
    <div class="ep-post__a">
      <button class="ep-act ${p.liked ? 'liked' : ''}" data-like="${p.id}" aria-pressed="${p.liked}" aria-label="${t('J\'aime')}">${epIco('heart')}</button>
      <button class="ep-act" data-comments="${p.id}" aria-label="${t('Commenter')}">${epIco('comment')}</button>
      <button class="ep-act" data-share="${p.id}" aria-label="${t('Envoyer')}">${epIco('send')}</button>
    </div>
    <div class="ep-post__b">
      <p class="ep-likes" data-likes="${p.id}">${t('{n} J\'aime', { n: epCount(p.likes) })}</p>
      ${p.content ? `<p class="ep-cap"><button data-user="${esc(p.username)}"><b>${esc(p.username)}</b></button> ${epRich(p.content)}</p>` : ''}
      ${p.comments ? `<button class="ep-more" data-comments="${p.id}">${p.comments > 1 ? t('Voir les {n} commentaires', { n: p.comments }) : t('Voir le commentaire')}</button>` : ''}
      <p class="ep-time">${epAgo(p.ts)}</p>
    </div></article>`;
}
async function epToggleLike(id, root, force) {
  const p = EPPOSTS[id];
  if (force && p?.liked) return;
  const r = await epApi('epLike', { id, like: force ? true : undefined });
  if (!r.ok) { if (r.error) epToast(epErr(r)); return; }
  if (p) { p.liked = r.liked; p.likes = r.likes; }
  $$(`[data-like="${id}"]`, root).forEach(b => { b.classList.toggle('liked', r.liked); b.setAttribute('aria-pressed', r.liked); if (r.liked) { b.classList.remove('pop'); void b.offsetWidth; b.classList.add('pop'); } });
  $$(`[data-likes="${id}"]`, root).forEach(x => x.textContent = t('{n} J\'aime', { n: epCount(r.likes) }));
}
function epWire(root) {
  $$('[data-like]', root).forEach(b => b.onclick = () => epToggleLike(+b.dataset.like, root));
  $$('[data-dbl]', root).forEach(el => el.ondblclick = (e) => {
    if (e.target.closest('[data-music]')) return;
    const burst = el.querySelector('.ep-burst'); burst.classList.remove('pop'); void burst.offsetWidth; burst.classList.add('pop');
    epToggleLike(+el.dataset.dbl, root, true);
  });
  $$('[data-music]', root).forEach(b => b.onclick = (e) => { e.stopPropagation(); const p = EPPOSTS[+b.dataset.music.slice(1)]; if (p?.music) epPlay(p.music, b.dataset.music); });
  $$('[data-user]', root).forEach(b => b.onclick = () => epGo('profile', { user: b.dataset.user }));
  $$('[data-comments]', root).forEach(b => b.onclick = () => epComments(+b.dataset.comments, root));
  $$('[data-share]', root).forEach(b => b.onclick = () => epShare(+b.dataset.share));
  $$('[data-follow]', root).forEach(b => b.onclick = async () => {
    const r = await epApi('epFollow', { username: b.dataset.follow, follow: true });
    if (!r.ok) return epToast(epErr(r));
    $$(`[data-follow="${b.dataset.follow}"]`, root).forEach(x => { x.textContent = t('Abonné(e)'); x.classList.add('ep-pill--on'); x.disabled = true; });
    EP.cache.home = null;
  });
  $$('[data-pmenu]', root).forEach(b => b.onclick = () => openSheet('', `<div class="form">
      <button class="btn btn--danger btn--block" data-del>${epIco('trash')}${t('Supprimer la publication')}</button>
      <button class="btn btn--ghost btn--block" data-no>${t('Annuler')}</button></div>`, (sh) => {
    $('[data-no]', sh).onclick = () => closeSheet();
    $('[data-del]', sh).onclick = () => confirmSheet(t('Supprimer cette publication ?'), t('Elle disparaîtra de votre profil et du fil, avec ses j\'aime et commentaires.'), t('Supprimer'), async () => {
      const r = await epApi('epDeletePost', { id: +b.dataset.pmenu });
      if (!r.ok) return epToast(epErr(r));
      EP.cache = {};
      const card = $(`[data-post="${b.dataset.pmenu}"]`, root);
      if (S.stack[S.stack.length - 1]?.params?.page === 'post') back(); else card?.remove();
    });
  }));
}

/* ---------- Commentaires ---------- */
function epComments(postId, root) {
  openSheet(t('Commentaires'), `<div class="ep-cmts" id="ep-cm">${loading()}</div>
    <div class="composer" style="margin-top:12px"><input class="field" id="ep-cm-in" maxlength="200" placeholder="${t('Ajouter un commentaire…')}">
    <button class="icon-btn icon-btn--accent" id="ep-cm-go" aria-label="${t('Publier')}">${icon('send')}</button></div>`, (sh) => {
    const load = async () => {
      const r = await epApi('epComments', { id: postId });
      const list = r.comments || [];
      $('#ep-cm', sh).innerHTML = list.length ? list.map(c => `<div class="ep-cmt">${epAv(c, 32)}
        <div class="ep-cmt__b"><p><b>${esc(c.username)}</b> ${epRich(c.content)}</p><small>${epAgo(c.ts)}</small></div>
        ${c.canDelete ? `<button class="ep-ib ep-ib--sm" data-cdel="${c.id}" aria-label="${t('Supprimer')}">${epIco('trash')}</button>` : ''}</div>`).join('')
        : `<p class="ep-muted" style="text-align:center;padding:26px 0">${t('Aucun commentaire. Lancez la conversation !')}</p>`;
      $$('[data-cdel]', sh).forEach(b => b.onclick = async () => { await epApi('epDeleteComment', { id: +b.dataset.cdel }); load(); bump(-1); });
    };
    const bump = (d) => {
      const p = EPPOSTS[postId]; if (!p) return;
      p.comments = Math.max(0, (p.comments || 0) + d);
      const card = root && $(`[data-post="${postId}"]`, root);
      const more = card && $('.ep-more', card);
      const label = p.comments > 1 ? t('Voir les {n} commentaires', { n: p.comments }) : p.comments ? t('Voir le commentaire') : '';
      if (more) { if (label) more.textContent = label; else more.remove(); }
      else if (card && label) { $('.ep-time', card).insertAdjacentHTML('beforebegin', `<button class="ep-more" data-comments="${postId}">${label}</button>`); $('.ep-more', card).onclick = () => epComments(postId, root); }
    };
    const send = async () => {
      const i = $('#ep-cm-in', sh); if (!i.value.trim()) return;
      const r = await epApi('epComment', { id: postId, content: i.value });
      if (!r.ok) return epToast(epErr(r));
      i.value = ''; load(); bump(1);
    };
    $('#ep-cm-go', sh).onclick = send;
    $('#ep-cm-in', sh).onkeydown = (e) => { if (e.key === 'Enter') send(); };
    load();
  });
}

/* ---------- Partager en message privé ---------- */
function epShare(postId) {
  openSheet(t('Envoyer à'), `<input class="search" id="ep-sh-q" placeholder="${t('Rechercher un compte')}" autocomplete="off">
    <div class="ep-users" id="ep-sh-list">${loading()}</div>`, async (sh) => {
    const pick = async (username) => {
      const r = await epApi('epSend', { username, post: postId });
      if (!r.ok) return epToast(epErr(r));
      closeSheet(); epToast(t('Publication envoyée à @{u}', { u: username }));
    };
    const show = (users) => {
      $('#ep-sh-list', sh).innerHTML = users.length ? users.map(u => `<button class="ep-urow" data-pick="${esc(u.username)}">${epAv(u, 40)}<span><b>${esc(u.username)}</b><small>${esc(u.name)}</small></span><span class="ep-pill">${t('Envoyer')}</span></button>`).join('')
        : `<p class="ep-muted" style="text-align:center;padding:20px">${t('Aucun compte')}</p>`;
      $$('[data-pick]', sh).forEach(b => b.onclick = () => pick(b.dataset.pick));
    };
    const conv = await epApi('epConversations');
    const recent = (conv.conversations || []).map(c => ({ username: c.username, name: c.name, avatar: c.avatar }));
    show(recent);
    let tm;
    $('#ep-sh-q', sh).oninput = (e) => {
      clearTimeout(tm);
      const q = e.target.value.trim();
      if (!q) return show(recent);
      tm = setTimeout(async () => { const r = await epApi('epSearch', { q }); show((r.users || []).filter(u => !u.me)); }, 250);
    };
  });
}

/* ---------- Accueil : stories + fil ---------- */
async function epHome(params, tok) {
  const head = `${epWord()}<div class="ep-top__r">
    <button class="ep-ib ${EP.badges.notifs > 0 ? 'has' : ''}" data-activity aria-label="${t('Activité')}">${epIco('heart')}<span class="ep-pip"></span></button>
    <button class="ep-ib" data-tab2="inbox" aria-label="${t('Messages')}">${epIco('send')}${EP.badges.dms > 0 ? `<span class="ep-dot">${EP.badges.dms}</span>` : ''}</button></div>`;
  const main = epShell('home', head, `<div class="ep-tray" id="ep-tray"><div class="ep-tray__sk"></div></div><div id="ep-feed">${loading()}</div>`);
  $('[data-activity]', appView).onclick = () => epGo('activity');
  $('[data-tab2]', appView).onclick = () => epTab('inbox');
  const [tray, feed] = await Promise.all([epApi('epStoriesTray'), epApi('epFeed')]);
  if (tok !== EP.tok) return;
  epRenderTray(tray.users || []);
  const st = { posts: feed.posts || [], more: !!feed.more, loading: false };
  const box = $('#ep-feed');
  box.innerHTML = st.posts.length ? st.posts.map(p => epCard(p)).join('') : epFeedEmpty();
  epWire(box);
  $('[data-go-search]', box)?.addEventListener('click', () => epTab('search'));
  $('[data-go-new]', box)?.addEventListener('click', () => epTab('new'));
  if (st.more) box.insertAdjacentHTML('beforeend', '<div class="ep-loadmore" id="ep-feed-more"></div>');
  main.onscroll = async () => {
    if (!st.more || st.loading || main.scrollTop + main.clientHeight < main.scrollHeight - 500) return;
    st.loading = true;
    const r = await epApi('epFeed', { before: st.posts[st.posts.length - 1].id });
    st.loading = false;
    if (tok !== EP.tok || !r.ok) return;
    st.more = !!r.more; st.posts.push(...(r.posts || []));
    const tmp = document.createElement('div'); tmp.innerHTML = (r.posts || []).map(p => epCard(p)).join('');
    epWire(tmp);
    const mark = $('#ep-feed-more'); [...tmp.children].forEach(c => box.insertBefore(c, mark));
    if (!st.more) mark?.remove();
  };
}
const epFeedEmpty = () => `<div class="ep-empty">
  <div class="ep-empty__ic">${epIco('image')}</div><strong>${t('Bienvenue sur ElyPick')}</strong>
  <p>${t('Abonnez-vous à des comptes pour voir leurs photos ici, ou publiez la vôtre.')}</p>
  <div class="ep-empty__btns"><button class="btn ep-grad" data-go-search>${epIco('search')}${t('Trouver des comptes')}</button>
  <button class="btn btn--ghost" data-go-new>${epIco('create')}${t('Publier')}</button></div></div>`;

function epRenderTray(users) {
  const tray = $('#ep-tray'); if (!tray) return;
  const meIn = users.find(u => u.mine);
  const others = users.filter(u => !u.mine);
  EP.trayOrder = (meIn ? [meIn] : []).concat(others).map(u => u.username);
  tray.innerHTML = `<button class="ep-st" data-mystory>${epAv(EP.acc, 62, meIn ? (meIn.seen ? 'seen' : 'new') : '')}${meIn ? '' : `<span class="ep-st__plus">${epIco('plus')}</span>`}<small>${t('Votre story')}</small></button>
    ${others.map(u => `<button class="ep-st" data-story="${esc(u.username)}">${epAv(u, 62, u.seen ? 'seen' : 'new')}<small>${esc(u.username)}</small></button>`).join('')}`;
  $('[data-mystory]', tray).onclick = () => meIn ? epOpenStories(EP.acc.username, EP.trayOrder) : epGo('new', { mode: 'story' });
  $$('[data-story]', tray).forEach(b => b.onclick = () => epOpenStories(b.dataset.story, EP.trayOrder));
}

/* ---------- Visionneuse de stories / à la une ---------- */
const STORY_MS = 5500;
function epCloseViewer() {
  const v = EP.viewer; if (!v) return;
  cancelAnimationFrame(v.raf); v.el?.remove(); EP.viewer = null;
}
async function epOpenStories(username, order = [username]) {
  const r = await epApi('epStories', { username });
  if (!r.ok) return epToast(epErr(r));
  if (!r.stories.length) { epToast(t('Plus de story pour le moment.')); return epRefreshTray(); }
  const first = Math.max(0, r.stories.findIndex(s => !s.seen));
  epViewer({ kind: 'story', user: r.user, mine: r.mine, items: r.stories, index: first, order, username });
}
async function epOpenHighlight(id) {
  const r = await epApi('epHighlight', { id });
  if (!r.ok) return epToast(epErr(r));
  if (!r.items.length) return epToast(t('Cette catégorie est vide.'));
  epViewer({ kind: 'hl', user: { username: r.highlight.username, name: r.highlight.name, avatar: r.highlight.avatar }, title: r.highlight.title, hl: r.highlight, mine: r.mine, items: r.items, index: 0 });
}
function epViewer(v) {
  epCloseViewer();
  EP.viewer = v;
  v.el = document.createElement('div');
  v.el.className = 'ep-viewer';
  appView.appendChild(v.el);
  requestAnimationFrame(() => v.el.classList.add('show'));
  epViewerShow();
}
function epViewerShow() {
  const v = EP.viewer; if (!v) return;
  const it = v.items[v.index];
  cancelAnimationFrame(v.raf);
  v.el.innerHTML = `<div class="ep-viewer__bg" style="background-image:url('${esc(it.image)}')"></div>
    <img class="ep-viewer__img" src="${esc(it.image)}" alt="">
    <div class="ep-viewer__bars">${v.items.map((_, i) => `<i><b style="width:${i < v.index ? 100 : 0}%"></b></i>`).join('')}</div>
    <div class="ep-viewer__head">${epAv(v.user, 32)}<span><b>${esc(v.kind === 'hl' ? v.title : v.user.username)}</b><small>${v.kind === 'hl' ? '@' + esc(v.user.username) + ' · ' : ''}${epAgo(it.ts)}</small></span>
      ${v.mine ? `<button class="ep-ib ep-ib--w" data-vmenu aria-label="${t('Options')}">${epIco('more')}</button>` : ''}
      <button class="ep-ib ep-ib--w" data-vclose aria-label="${t('Fermer')}">${epIco('close')}</button></div>
    <button class="ep-viewer__zone l" data-vprev aria-label="${t('Précédent')}"></button><button class="ep-viewer__zone r" data-vnext aria-label="${t('Suivant')}"></button>
    ${v.kind === 'story' && v.mine ? `<div class="ep-viewer__foot">${epIco('user')}${t('Vue par {n}', { n: it.views || 0 })}</div>` : ''}
    ${v.kind === 'story' && !v.mine ? `<div class="ep-viewer__foot ep-viewer__reply"><button data-vreply>${epIco('send')}${t('Répondre à @{u}', { u: esc(v.user.username) })}</button></div>` : ''}`;
  if (v.kind === 'story' && !it.seen && !v.mine) { it.seen = true; epApi('epStorySeen', { id: it.id }); }
  if (v.kind === 'story' && v.mine) epApi('epStorySeen', { id: it.id });
  $('[data-vclose]', v.el).onclick = () => { epCloseViewer(); epRefreshTray(); };
  $('[data-vprev]', v.el).onclick = () => epViewerStep(-1);
  $('[data-vnext]', v.el).onclick = () => epViewerStep(1);
  $('[data-vmenu]', v.el)?.addEventListener('click', () => { v.paused = true; epViewerMenu(); });
  $('[data-vreply]', v.el)?.addEventListener('click', () => { const u = v.user.username; epCloseViewer(); epGo('chat', { user: u }); });
  // Maintenir pour mettre en pause
  const zones = $$('.ep-viewer__zone', v.el);
  zones.forEach(z => { z.onpointerdown = () => { v.hold = Date.now(); v.paused = true; }; z.onpointerup = () => { v.paused = false; v.start = performance.now() - v.elapsed; }; });
  v.elapsed = 0; v.start = performance.now(); v.paused = false;
  const bar = $$('.ep-viewer__bars b', v.el)[v.index];
  const tick = (now) => {
    if (EP.viewer !== v) return;
    if (v.paused) { v.start = now - v.elapsed; } else { v.elapsed = now - v.start; }
    bar.style.width = Math.min(100, v.elapsed / STORY_MS * 100) + '%';
    if (v.elapsed >= STORY_MS) return epViewerStep(1);
    v.raf = requestAnimationFrame(tick);
  };
  v.raf = requestAnimationFrame(tick);
}
async function epViewerStep(d) {
  const v = EP.viewer; if (!v) return;
  if (v.hold && Date.now() - v.hold > 350) { v.hold = 0; return; }   // c'était une pause, pas un tap
  v.hold = 0;
  const i = v.index + d;
  if (i >= 0 && i < v.items.length) { v.index = i; return epViewerShow(); }
  // Story suivante / précédente d'un autre compte
  if (v.kind === 'story' && v.order) {
    const k = v.order.indexOf(v.username) + d;
    if (k >= 0 && k < v.order.length) {
      const r = await epApi('epStories', { username: v.order[k] });
      if (EP.viewer !== v) return;
      if (r.ok && r.stories.length) {
        Object.assign(v, { user: r.user, mine: r.mine, items: r.stories, username: v.order[k], index: d > 0 ? Math.max(0, r.stories.findIndex(s => !s.seen)) : r.stories.length - 1 });
        return epViewerShow();
      }
    }
  }
  if (d < 0) { v.index = 0; return epViewerShow(); }
  epCloseViewer(); epRefreshTray();
}
async function epRefreshTray() {
  if (!$('#ep-tray')) return;
  const r = await epApi('epStoriesTray');
  if (r.ok) epRenderTray(r.users || []);
}
function epViewerMenu() {
  const v = EP.viewer; const it = v.items[v.index];
  const resume = () => { if (EP.viewer === v) { v.paused = false; } };
  const sh = v.kind === 'story'
    ? openSheet('', `<div class="form">
        <button class="btn btn--block ep-grad" data-hl>${epIco('star')}${t('Ajouter à la une')}</button>
        <button class="btn btn--danger btn--block" data-sdel>${epIco('trash')}${t('Supprimer la story')}</button>
        <button class="btn btn--ghost btn--block" data-no>${t('Annuler')}</button></div>`, (s) => {
        $('[data-no]', s).onclick = () => { closeSheet(); resume(); };
        $('[data-hl]', s).onclick = () => { closeSheet(true); epPickHighlight([it.id], () => { resume(); }); };
        $('[data-sdel]', s).onclick = () => confirmSheet(t('Supprimer cette story ?'), t('Ses copies à la une sont conservées.'), t('Supprimer'), async () => {
          const r = await epApi('epDeleteStory', { id: it.id });
          if (!r.ok) return epToast(epErr(r));
          v.items.splice(v.index, 1);
          if (!v.items.length) { epCloseViewer(); epRefreshTray(); if (S.stack[S.stack.length - 1]?.params?.page === 'me') epTab('me'); return; }
          v.index = Math.min(v.index, v.items.length - 1); epViewerShow();
        });
      })
    : openSheet(v.title, `<div class="form">
        <button class="btn btn--ghost btn--block" data-cover>${epIco('image')}${t('Utiliser comme couverture')}</button>
        <button class="btn btn--ghost btn--block" data-rename>${epIco('edit')}${t('Renommer la catégorie')}</button>
        <button class="btn btn--ghost btn--block" data-rm>${epIco('close')}${t('Retirer cette story de la catégorie')}</button>
        <button class="btn btn--danger btn--block" data-hdel>${epIco('trash')}${t('Supprimer la catégorie')}</button>
        <button class="btn btn--ghost btn--block" data-no>${t('Annuler')}</button></div>`, (s) => {
        $('[data-no]', s).onclick = () => { closeSheet(); resume(); };
        $('[data-cover]', s).onclick = async () => { const r = await epApi('epHighlightUpdate', { id: v.hl.id, coverItem: it.id }); closeSheet(); resume(); epToast(r.ok ? t('Couverture mise à jour') : epErr(r)); epRefreshProfile(); };
        $('[data-rename]', s).onclick = () => { closeSheet(true); epPrompt(t('Renommer la catégorie'), v.title, 30, async (val) => {
          const r = await epApi('epHighlightUpdate', { id: v.hl.id, title: val });
          if (!r.ok) return epErr(r);
          v.title = val; resume(); epViewerShow(); epRefreshProfile();
        }, resume); };
        $('[data-rm]', s).onclick = async () => {
          closeSheet();
          const r = await epApi('epHighlightRemove', { item: it.id });
          if (!r.ok) return epToast(epErr(r));
          v.items.splice(v.index, 1); epRefreshProfile();
          if (!v.items.length) return epCloseViewer();
          v.index = Math.min(v.index, v.items.length - 1); epViewerShow();
        };
        $('[data-hdel]', s).onclick = () => confirmSheet(t('Supprimer « {n} » ?', { n: v.title }), t('Les stories de cette catégorie ne seront plus à la une.'), t('Supprimer'), async () => {
          await epApi('epHighlightDelete', { id: v.hl.id }); epCloseViewer(); epRefreshProfile();
        });
      });
  sh.addEventListener('sheetclose', () => setTimeout(() => { if (!$('.sheet', screenEl)) resume(); }, 350));
}
function epRefreshProfile() { const cur = S.stack[S.stack.length - 1]; if (cur?.id === 'instapick' && cur.params?.page === 'me') epRender({ page: 'me' }); }

function epPrompt(title, value, max, onOk, onCancel) {
  openSheet(title, `<div class="form"><input class="field" id="ep-pr" maxlength="${max}" value="${esc(value || '')}">
    <p class="error-text" id="ep-pr-err"></p><button class="btn btn--block ep-grad" id="ep-pr-ok">${t('Valider')}</button></div>`, (sh) => {
    let done = false;
    sh.addEventListener('sheetclose', () => { if (!done) onCancel?.(); });
    $('#ep-pr-ok', sh).onclick = async () => {
      const val = $('#ep-pr', sh).value.trim();
      if (!val) return;
      const err = await onOk(val);
      if (err) { $('#ep-pr-err', sh).textContent = err; return; }
      done = true; closeSheet();
    };
  });
}

// Choisir / créer une catégorie « à la une » pour des stories
async function epPickHighlight(storyIds, after) {
  const r = await epApi('epMyStories');
  const hls = r.highlights || [];
  openSheet(t('Ajouter à la une'), `<div class="ep-hlpick">
      <button class="ep-hl" data-hnew><span class="ep-hl__c ep-hl__c--new">${epIco('create')}</span><small>${t('Nouvelle')}</small></button>
      ${hls.map(h => `<button class="ep-hl" data-hid="${h.id}"><span class="ep-hl__c">${h.cover ? `<img src="${esc(h.cover)}" alt="">` : ''}</span><small>${esc(h.title)}</small></button>`).join('')}</div>
    <p class="error-text" id="ep-hl-err"></p>`, (sh) => {
    let done = false;
    sh.addEventListener('sheetclose', () => { if (!done) after?.(); });
    const add = async (payload) => {
      const res = await epApi('epHighlightAdd', Object.assign({ stories: storyIds }, payload));
      if (!res.ok) { $('#ep-hl-err', sh).textContent = epErr(res); return false; }
      done = true; closeSheet(); epToast(t('Ajouté à la une')); after?.(); epRefreshProfile(); return true;
    };
    $$('[data-hid]', sh).forEach(b => b.onclick = () => add({ id: +b.dataset.hid }));
    $('[data-hnew]', sh).onclick = () => { done = true; closeSheet(true); epPrompt(t('Nom de la catégorie'), '', 30, async (title) => {
      const res = await epApi('epHighlightAdd', { stories: storyIds, title });
      if (!res.ok) return epErr(res);
      epToast(t('Catégorie « {n} » créée', { n: title })); after?.(); epRefreshProfile();
    }, after); };
  });
}

/* ---------- Recherche + Explorer ---------- */
async function epSearch(params, tok) {
  const head = `<div class="ep-searchbar">${epIco('search')}<input id="ep-q" placeholder="${t('Rechercher un compte')}" autocomplete="off" value="${esc(params.q || '')}">
    <button class="ep-ib ep-ib--sm hidden" id="ep-q-x" aria-label="${t('Effacer')}">${epIco('close')}</button></div>`;
  const main = epShell('search', head, `<div id="ep-res" class="hidden"></div><div id="ep-explore"><div class="ep-grid ep-grid--sk">${'<i></i>'.repeat(12)}</div></div>`);
  const q = $('#ep-q'), x = $('#ep-q-x'), res = $('#ep-res'), ex = $('#ep-explore');
  let tm, qtok = 0;
  const runSearch = async () => {
    const v = q.value.trim(); x.classList.toggle('hidden', !v);
    setParams({ page: 'search', q: v });
    if (!v) { res.classList.add('hidden'); ex.classList.remove('hidden'); return; }
    res.classList.remove('hidden'); ex.classList.add('hidden');
    const my = ++qtok;
    const r = await epApi('epSearch', { q: v });
    if (my !== qtok || tok !== EP.tok) return;
    epUserList(res, r.users || [], t('Aucun compte ne correspond à « {q} ».', { q: esc(v) }));
  };
  q.oninput = () => { clearTimeout(tm); tm = setTimeout(runSearch, 250); };
  x.onclick = () => { q.value = ''; runSearch(); q.focus(); };
  if (params.q) runSearch();
  // Explorer : toutes les photos du serveur, chargées par pages
  const st = { posts: [], more: true, loading: false };
  const load = async () => {
    if (!st.more || st.loading) return;
    st.loading = true;
    const r = await epApi('epExplore', { before: st.posts.length ? st.posts[st.posts.length - 1].id : undefined });
    st.loading = false;
    if (tok !== EP.tok || !r.ok) return;
    const first = !st.posts.length;
    st.posts.push(...(r.posts || [])); st.more = !!r.more;
    if (first) ex.innerHTML = st.posts.length ? '<div class="ep-grid" id="ep-ex-grid"></div>' : `<div class="ep-empty"><div class="ep-empty__ic">${epIco('image')}</div><strong>${t('Rien à explorer pour l\'instant')}</strong><p>${t('Les photos publiées en ville apparaîtront ici.')}</p></div>`;
    const grid = $('#ep-ex-grid'); if (!grid) return;
    grid.insertAdjacentHTML('beforeend', (r.posts || []).map(epTile).join(''));
    epWireGrid(grid);
  };
  main.onscroll = () => { if (!ex.classList.contains('hidden') && main.scrollTop + main.clientHeight > main.scrollHeight - 400) load(); };
  await load();
}
const epTile = (p) => `<button class="ep-tile" data-open-post="${p.id}" aria-label="${t('Publication')}"><img src="${esc(p.image)}" alt="" loading="lazy" onerror="this.classList.add('bad')">${p.music ? `<span class="ep-tile__mu">${epIco('music')}</span>` : ''}${p.likes ? `<span class="ep-tile__lk">${epIco('heart')}${epCount(p.likes)}</span>` : ''}</button>`;
function epWireGrid(grid) { $$('[data-open-post]:not([data-w])', grid).forEach(b => { b.dataset.w = 1; b.onclick = () => epGo('post', { id: +b.dataset.openPost }); }); }

function epUserList(box, users, emptyText) {
  box.innerHTML = users.length ? `<div class="ep-users">${users.map(u => `<div class="ep-urow" data-user-row="${esc(u.username)}">${epAv(u, 46)}
      <span><b>${esc(u.username)}</b><small>${esc(u.name)}${u.followers !== undefined ? ` · ${t('{n} abonnés', { n: epCount(u.followers) })}` : ''}</small></span>
      ${u.me ? '' : `<button class="ep-pill ${u.iFollow ? 'ep-pill--on' : ''}" data-fol="${esc(u.username)}" data-on="${u.iFollow ? 1 : 0}">${u.iFollow ? t('Abonné(e)') : t('S\'abonner')}</button>`}</div>`).join('')}</div>`
    : `<p class="ep-muted" style="text-align:center;padding:30px 10px">${emptyText}</p>`;
  $$('[data-user-row]', box).forEach(r => r.onclick = (e) => { if (!e.target.closest('[data-fol]')) epGo('profile', { user: r.dataset.userRow }); });
  $$('[data-fol]', box).forEach(b => b.onclick = async () => {
    const on = b.dataset.on === '1';
    const r = await epApi('epFollow', { username: b.dataset.fol, follow: !on });
    if (!r.ok) return epToast(epErr(r));
    b.dataset.on = r.following ? 1 : 0; b.classList.toggle('ep-pill--on', r.following);
    b.textContent = r.following ? t('Abonné(e)') : t('S\'abonner');
    EP.cache.home = null;
  });
}

/* ---------- Publication seule ---------- */
async function epPostPage(params, tok) {
  epShell('post', epHead(t('Publication')), loading());
  const r = await epApi('epPost', { id: params.id });
  if (tok !== EP.tok) return;
  const page = $('.ep-page');
  if (!r.ok) { page.innerHTML = empty(t('Publication indisponible'), epErr(r)); return; }
  page.innerHTML = epCard(r.post, { follow: true });
  epWire(page);
}

/* ---------- Profil ---------- */
async function epProfile(params, tok) {
  const mine = !params.user || params.user === EP.acc.username;
  const pageId = mine && !params.user ? 'me' : 'profile';
  const right = mine ? `<button class="ep-ib" data-edit aria-label="${t('Modifier le profil')}">${epIco('edit')}</button>` : '';
  epShell(pageId, mine && pageId === 'me' ? `<h1 class="ep-title ep-title--u">${esc(EP.acc.username)}</h1><div class="ep-top__r">${right}</div>` : epHead(esc(params.user), right), loading());
  $('[data-edit]', appView)?.addEventListener('click', () => epGo('edit'));
  const r = await epApi('epProfile', { username: mine ? undefined : params.user });
  if (tok !== EP.tok) return;
  const page = $('.ep-page');
  if (!r.ok) { page.innerHTML = empty(t('Compte introuvable'), epErr(r)); return; }
  const p = r.profile;
  if (p.mine) { EP.acc = Object.assign(EP.acc, { username: p.username, name: p.name, avatar: p.avatar, bio: p.bio }); }
  const ring = p.story ? (p.story === 'seen' ? 'seen' : 'new') : '';
  page.innerHTML = `<section class="ep-prof">
    <div class="ep-prof__top">
      <button class="ep-prof__av" ${p.story ? 'data-pstory' : ''} aria-label="${t('Photo de profil')}">${epAv(p, 84, ring)}</button>
      <div class="ep-prof__stats">
        <div><b>${epCount(p.posts)}</b><small>${t('publications')}</small></div>
        <button data-flist="followers"><b data-fcount>${epCount(p.followers)}</b><small>${t('abonnés')}</small></button>
        <button data-flist="following"><b>${epCount(p.following)}</b><small>${t('abonnements')}</small></button></div></div>
    <p class="ep-prof__name">${esc(p.name)}${p.followsMe ? `<span class="ep-tag">${t('Vous suit')}</span>` : ''}</p>
    ${p.bio ? `<p class="ep-prof__bio">${epRich(p.bio)}</p>` : (p.mine ? `<button class="ep-prof__addbio" data-edit2>${t('+ Ajouter une biographie')}</button>` : '')}
    <div class="ep-prof__btns">${p.mine
      ? `<button class="btn btn--ghost" data-edit2>${t('Modifier le profil')}</button><button class="btn btn--ghost" data-newstory>${epIco('story')}${t('Story')}</button>`
      : `<button class="btn ${p.iFollow ? 'btn--ghost' : 'ep-grad'}" data-pfollow>${p.iFollow ? t('Abonné(e)') : (p.followsMe ? t('S\'abonner en retour') : t('S\'abonner'))}</button><button class="btn btn--ghost" data-pmsg>${t('Message')}</button>`}</div>
    <div class="ep-hls">${p.mine ? `<button class="ep-hl" data-hnew2><span class="ep-hl__c ep-hl__c--new">${epIco('create')}</span><small>${t('Nouveau')}</small></button>` : ''}
      ${p.highlights.map(h => `<button class="ep-hl" data-hl="${h.id}"><span class="ep-hl__c">${h.cover ? `<img src="${esc(h.cover)}" alt="" loading="lazy">` : ''}</span><small>${esc(h.title)}</small></button>`).join('')}</div>
    </section>
    <div class="ep-gridtab">${epIco('grid')}</div>
    ${r.grid.length ? `<div class="ep-grid" id="ep-pgrid">${r.grid.map(epTile).join('')}</div>`
      : `<div class="ep-empty"><div class="ep-empty__ic">${epIco('camera')}</div><strong>${p.mine ? t('Partagez votre première photo') : t('Aucune publication')}</strong>
         ${p.mine ? `<p>${t('Elle apparaîtra sur votre profil et dans le fil de vos abonnés.')}</p><div class="ep-empty__btns"><button class="btn ep-grad" data-go-new>${t('Publier une photo')}</button></div>` : ''}</div>`}`;
  const grid = $('#ep-pgrid');
  if (grid) epWireGrid(grid);
  $$('[data-edit2]', page).forEach(b => b.onclick = () => epGo('edit'));
  $('[data-go-new]', page)?.addEventListener('click', () => epTab('new'));
  $('[data-newstory]', page)?.addEventListener('click', () => epGo('new', { mode: 'story' }));
  $('[data-pstory]', page)?.addEventListener('click', () => epOpenStories(p.username));
  $$('[data-flist]', page).forEach(b => b.onclick = () => epGo('follows', { user: p.username, kind: b.dataset.flist }));
  $('[data-pmsg]', page)?.addEventListener('click', () => epGo('chat', { user: p.username }));
  $$('[data-hl]', page).forEach(b => b.onclick = () => epOpenHighlight(+b.dataset.hl));
  $('[data-hnew2]', page)?.addEventListener('click', () => epNewHighlight());
  const fb = $('[data-pfollow]', page);
  if (fb) fb.onclick = async () => {
    const r2 = await epApi('epFollow', { username: p.username, follow: !p.iFollow });
    if (!r2.ok) return epToast(epErr(r2));
    p.iFollow = r2.following; EP.cache.home = null;
    fb.className = `btn ${p.iFollow ? 'btn--ghost' : 'ep-grad'}`;
    fb.textContent = p.iFollow ? t('Abonné(e)') : (p.followsMe ? t('S\'abonner en retour') : t('S\'abonner'));
    $('[data-fcount]', page).textContent = epCount(r2.followers);
  };
  // Grille : chargement progressif
  let more = r.more, busy = false;
  const main = $('#ep-main');
  main.onscroll = async () => {
    if (!more || busy || !grid || main.scrollTop + main.clientHeight < main.scrollHeight - 400) return;
    busy = true;
    const last = $$('[data-open-post]', grid).pop();
    const g = await epApi('epUserPosts', { username: p.username, before: +last.dataset.openPost });
    busy = false;
    if (tok !== EP.tok || !g.ok) return;
    more = g.more; grid.insertAdjacentHTML('beforeend', g.grid.map(epTile).join('')); epWireGrid(grid);
  };
}
async function epNewHighlight() {
  const r = await epApi('epMyStories');
  const list = r.stories || [];
  if (!list.length) {
    return openSheet(t('Nouvelle catégorie à la une'), `<p class="sheet__text">${t('Les stories à la une se créent à partir de vos stories. Publiez une story, puis ajoutez-la ici.')}</p>
      <div class="form"><button class="btn btn--block ep-grad" data-ns>${epIco('story')}${t('Publier une story')}</button></div>`, (sh) => { $('[data-ns]', sh).onclick = () => { closeSheet(true); epGo('new', { mode: 'story' }); }; });
  }
  openSheet(t('Choisir des stories'), `<div class="ep-pickgrid ep-pickgrid--story">${list.map(s => `<button data-sid="${s.id}"><img src="${esc(s.image)}" alt=""><i>${epIco('check')}</i></button>`).join('')}</div>
    <div class="form" style="margin-top:12px"><button class="btn btn--block ep-grad" id="ep-ns-next" disabled>${t('Suivant')}</button></div>`, (sh) => {
    const sel = new Set();
    $$('[data-sid]', sh).forEach(b => b.onclick = () => { const id = +b.dataset.sid; sel.has(id) ? sel.delete(id) : sel.add(id); b.classList.toggle('picked', sel.has(id)); $('#ep-ns-next', sh).disabled = !sel.size; });
    $('#ep-ns-next', sh).onclick = () => { closeSheet(true); epPickHighlight([...sel]); };
  });
}

/* ---------- Abonnés / abonnements ---------- */
async function epFollows(params, tok) {
  const kind = params.kind === 'following' ? 'following' : 'followers';
  epShell('follows', epHead(esc(params.user)), `<div class="ep-seg"><button data-k="followers" class="${kind === 'followers' ? 'on' : ''}">${t('Abonnés')}</button><button data-k="following" class="${kind === 'following' ? 'on' : ''}">${t('Abonnements')}</button></div><div id="ep-fl">${loading()}</div>`);
  $$('[data-k]', appView).forEach(b => b.onclick = () => { setParams({ page: 'follows', user: params.user, kind: b.dataset.k }); epRender({ page: 'follows', user: params.user, kind: b.dataset.k }); });
  const users = [];
  const load = async () => {
    const r = await epApi('epFollowList', { username: params.user, kind, offset: users.length });
    if (tok !== EP.tok) return;
    if (!r.ok) { $('#ep-fl').innerHTML = empty(t('Liste indisponible'), epErr(r)); return; }
    users.push(...r.users);
    epUserList($('#ep-fl'), users, kind === 'followers' ? t('Aucun abonné pour l\'instant.') : t('Aucun abonnement pour l\'instant.'));
    if (r.more) { $('#ep-fl').insertAdjacentHTML('beforeend', `<button class="btn btn--ghost btn--block" style="margin-top:12px" id="ep-fl-more">${t('Afficher plus')}</button>`); $('#ep-fl-more').onclick = load; }
  };
  load();
}

/* ---------- Modifier le profil ---------- */
async function epEdit(params, tok) {
  const a = EP.acc;
  let avatar = a.avatar || '';
  epShell('edit', epHead(t('Modifier le profil')), `<div class="ep-edit">
    <button class="ep-edit__av" id="ep-av-btn">${epAv({ username: a.username, name: a.name, avatar }, 92)}<span>${t('Changer la photo')}</span></button>
    <div class="ep-form">
      <label class="ep-lbl">${t('Nom affiché')}</label><input class="field" id="ep-e-name" maxlength="40" value="${esc(a.name)}">
      <label class="ep-lbl">${t('Nom d\'utilisateur')}</label><div class="handle-field"><span>@</span><input class="field" id="ep-e-user" maxlength="20" value="${esc(a.username)}"></div>
      <label class="ep-lbl">${t('Biographie')}</label><textarea class="field" id="ep-e-bio" rows="3" maxlength="${EP.limits.bio}">${esc(a.bio || '')}</textarea>
      <p class="counter" id="ep-e-cnt"></p>
      <p class="error-text" id="ep-e-err"></p>
      <button class="btn btn--block ep-grad" id="ep-e-save">${t('Enregistrer')}</button></div></div>`);
  const cnt = () => { $('#ep-e-cnt').textContent = `${$('#ep-e-bio').value.length} / ${EP.limits.bio}`; };
  $('#ep-e-bio').oninput = cnt; cnt();
  $('#ep-e-user').oninput = (e) => { e.target.value = e.target.value.toLowerCase().replace(/[^a-z0-9_.]/g, ''); };
  $('#ep-av-btn').onclick = () => epImagePicker(t('Photo de profil'), (url) => {
    avatar = url; $('#ep-av-btn .ep-av').outerHTML = epAv({ username: a.username, name: a.name, avatar }, 92);
  }, avatar ? () => { avatar = ''; $('#ep-av-btn .ep-av').outerHTML = epAv({ username: a.username, name: a.name }, 92); } : null);
  $('#ep-e-save').onclick = async () => {
    const r = await epApi('epUpdateProfile', { display: $('#ep-e-name').value, username: $('#ep-e-user').value, bio: $('#ep-e-bio').value, avatar: avatar || false });
    if (!r.ok) { $('#ep-e-err').textContent = epErr(r); return; }
    EP.acc = r.account; EP.cache = {}; epToast(t('Profil mis à jour')); back();
  };
}

// Choisir une image : galerie du téléphone, appareil photo ou lien
async function epImagePicker(title, onPick, onRemove) {
  const photos = await epGallery();
  openSheet(title, `${photos.length ? `<div class="ep-pickgrid">${photos.slice(0, 30).map(p => `<button data-url="${esc(p.url)}"><img src="${esc(p.url)}" alt="" loading="lazy"></button>`).join('')}</div>`
      : `<p class="sheet__text">${t('Votre galerie est vide. Prenez une photo avec l\'appareil photo.')}</p>`}
    <div class="form" style="margin-top:12px">
      ${EP.limits.links ? `<div class="composer"><input class="field" id="ep-ip-link" placeholder="${t('Ou collez le lien d\'une image')}"><button class="icon-btn icon-btn--accent" id="ep-ip-go" aria-label="${t('Valider')}">${icon('check')}</button></div>` : ''}
      ${S.profile?.cameraEnabled ? `<button class="btn btn--ghost btn--block" data-cam>${epIco('camera')}${t('Appareil photo')}</button>` : ''}
      ${onRemove ? `<button class="btn btn--ghost btn--block" data-rm>${t('Retirer la photo')}</button>` : ''}</div>`, (sh) => {
    $$('[data-url]', sh).forEach(b => b.onclick = () => { closeSheet(); onPick(b.dataset.url); });
    $('#ep-ip-go', sh)?.addEventListener('click', () => { const v = $('#ep-ip-link', sh).value.trim(); if (/^https:\/\//.test(v)) { closeSheet(); onPick(v); } });
    $('[data-cam]', sh)?.addEventListener('click', () => { closeSheet(true); openApp('camera'); });
    $('[data-rm]', sh)?.addEventListener('click', () => { closeSheet(); onRemove(); });
  });
}

/* ---------- Créer : publication ou story ---------- */
async function epNew(params, tok) {
  const mode = params.mode === 'story' ? 'story' : 'post';
  const d = EP.draft && EP.draft.mode === mode ? EP.draft : (EP.draft = { mode, image: params.image || '', caption: '', music: null, hl: null });
  if (params.image) d.image = params.image;
  epShell('new', `<h1 class="ep-title">${t('Créer')}</h1>`, `<div class="ep-seg"><button data-m="post" class="${mode === 'post' ? 'on' : ''}">${t('Publication')}</button><button data-m="story" class="${mode === 'story' ? 'on' : ''}">${t('Story')}</button></div><div id="ep-new">${loading()}</div>`);
  $$('[data-m]', appView).forEach(b => b.onclick = () => { EP.draft = null; setParams({ page: 'new', mode: b.dataset.m }); epRender({ page: 'new', mode: b.dataset.m }); });
  const box = $('#ep-new');
  if (!d.image) {
    const photos = await epGallery();
    if (tok !== EP.tok) return;
    box.innerHTML = `<p class="ep-step">${t('1. Choisissez une photo')}</p>
      <div class="ep-pickgrid ep-pickgrid--lg">
        ${S.profile?.cameraEnabled ? `<button class="ep-pick-cam" data-cam>${epIco('camera')}<small>${t('Appareil')}</small></button>` : ''}
        ${photos.map(p => `<button data-url="${esc(p.url)}"><img src="${esc(p.url)}" alt="" loading="lazy"></button>`).join('')}</div>
      ${photos.length ? '' : `<p class="ep-muted" style="margin:14px 4px">${t('Votre galerie est vide : prenez une photo avec l\'appareil photo.')}</p>`}
      ${EP.limits.links ? `<div class="composer" style="margin-top:14px"><input class="field" id="ep-n-link" placeholder="${t('Ou collez le lien d\'une image (https://…)')}"><button class="icon-btn icon-btn--accent" id="ep-n-link-go" aria-label="${t('Valider')}">${icon('check')}</button></div>` : ''}`;
    $$('[data-url]', box).forEach(b => b.onclick = () => { d.image = b.dataset.url; epRender({ page: 'new', mode }); });
    $('[data-cam]', box)?.addEventListener('click', () => openApp('camera'));
    $('#ep-n-link-go')?.addEventListener('click', () => { const v = $('#ep-n-link').value.trim(); if (/^https:\/\//.test(v)) { d.image = v; epRender({ page: 'new', mode }); } else epToast(t('Le lien doit commencer par https://')); });
    return;
  }
  if (mode === 'story') {
    box.innerHTML = `<div class="ep-preview ep-preview--story"><img src="${esc(d.image)}" alt=""><div class="ep-preview__head">${epAv(EP.acc, 28)}<b>${esc(EP.acc.username)}</b><small>${t('maintenant')}</small></div></div>
      <button class="ep-linkbtn" data-change>${epIco('image')}${t('Changer de photo')}</button>
      <button class="ep-row" data-hlrow>${epIco('star')}<span><b>${t('Ajouter à la une')}</b><small id="ep-hl-lbl">${d.hl ? esc(d.hl.title) : t('Garder cette story sur votre profil après 24 h')}</small></span>${d.hl ? `<i class="ep-x" data-hlx>${epIco('close')}</i>` : epIco('back', 'flip')}</button>
      <p class="ep-muted ep-note">${t('Visible par vos abonnés pendant {h} h.', { h: EP.limits.storyHours })}</p>
      <p class="error-text" id="ep-n-err"></p>
      <button class="btn btn--block ep-grad" id="ep-n-go">${epIco('story')}${t('Partager en story')}</button>`;
    $('[data-hlrow]', box).onclick = async (e) => {
      if (e.target.closest('[data-hlx]')) { d.hl = null; return epRender({ page: 'new', mode }); }
      const r = await epApi('epMyStories');
      openSheet(t('Ajouter à la une'), `<div class="ep-hlpick">
        <button class="ep-hl" data-hnew><span class="ep-hl__c ep-hl__c--new">${epIco('create')}</span><small>${t('Nouvelle')}</small></button>
        ${(r.highlights || []).map(h => `<button class="ep-hl" data-hid="${h.id}" data-ht="${esc(h.title)}"><span class="ep-hl__c">${h.cover ? `<img src="${esc(h.cover)}" alt="">` : ''}</span><small>${esc(h.title)}</small></button>`).join('')}</div>`, (sh) => {
        $$('[data-hid]', sh).forEach(b => b.onclick = () => { d.hl = { id: +b.dataset.hid, title: b.dataset.ht }; closeSheet(); epRender({ page: 'new', mode }); });
        $('[data-hnew]', sh).onclick = () => { closeSheet(true); epPrompt(t('Nom de la catégorie'), '', 30, (title) => { d.hl = { title }; epRender({ page: 'new', mode }); }); };
      });
    };
  } else {
    box.innerHTML = `<div class="ep-preview"><img src="${esc(d.image)}" alt=""></div>
      <button class="ep-linkbtn" data-change>${epIco('image')}${t('Changer de photo')}</button>
      <div class="ep-capbox">${epAv(EP.acc, 32)}<textarea class="field" id="ep-n-cap" rows="3" maxlength="${EP.limits.caption}" placeholder="${t('Écrivez une description…')}">${esc(d.caption)}</textarea></div>
      <p class="counter" id="ep-n-cnt">${d.caption.length} / ${EP.limits.caption}</p>
      <button class="ep-row" data-murow>${epIco('music')}<span><b>${d.music ? esc(d.music.title) : t('Ajouter une musique')}</b><small>${d.music ? esc(d.music.artist || '') : t('Facultatif')}</small></span>${d.music ? `<i class="ep-x" data-mux>${epIco('close')}</i>` : epIco('back', 'flip')}</button>
      <p class="error-text" id="ep-n-err"></p>
      <div class="grid-2"><button class="btn btn--ghost" id="ep-n-prev">${t('Aperçu')}</button><button class="btn ep-grad" id="ep-n-go">${t('Partager')}</button></div>`;
    const cap = $('#ep-n-cap');
    cap.oninput = () => { d.caption = cap.value; $('#ep-n-cnt').textContent = `${cap.value.length} / ${EP.limits.caption}`; };
    $('[data-murow]', box).onclick = (e) => {
      if (e.target.closest('[data-mux]')) { d.music = null; return epRender({ page: 'new', mode }); }
      epMusicPicker((m) => { d.music = m; epRender({ page: 'new', mode }); });
    };
    $('#ep-n-prev').onclick = () => {
      const fake = { id: 0, username: EP.acc.username, name: EP.acc.name, avatar: EP.acc.avatar, image: d.image, content: cap.value.trim(), music: d.music, likes: 0, liked: false, comments: 0, ts: Date.now() / 1000 };
      openSheet(t('Aperçu'), `<div class="ep-prevcard">${epCard(fake)}</div><button class="btn btn--ghost btn--block" data-close style="margin-top:12px">${t('Fermer l\'aperçu')}</button>`, (sh) => {
        $('[data-close]', sh).onclick = () => closeSheet();
        $$('[data-music]', sh).forEach(b => b.onclick = () => epPlay(d.music, 'prev'));
        $$('.ep-post__a button, [data-user], [data-comments]', sh).forEach(b => { b.disabled = true; });
        sh.addEventListener('sheetclose', epStopMusic);
      });
    };
  }
  $('[data-change]', box).onclick = () => { d.image = ''; epRender({ page: 'new', mode }); };
  $('#ep-n-go').onclick = async (e) => {
    const btn = e.currentTarget; btn.disabled = true;
    const r = mode === 'story'
      ? await epApi('epCreateStory', { image: d.image, highlight: d.hl || undefined })
      : await epApi('epCreatePost', { image: d.image, caption: d.caption, music: d.music?.ref });
    btn.disabled = false;
    if (!r.ok) { $('#ep-n-err').textContent = epErr(r); return; }
    EP.draft = null; EP.cache = {}; epStopMusic();
    epToast(mode === 'story' ? t('Story publiée') : t('Publication partagée'));
    epTab(mode === 'story' ? 'home' : 'me');
  };
}
async function epMusicPicker(onPick) {
  const r = await epApi('epMusic');
  const row = (m) => `<div class="ep-murow" data-ref="${esc(m.ref)}">
      <button class="ep-murow__play" data-prev="${esc(m.ref)}" aria-label="${t('Écouter')}">${m.thumb ? `<img src="${esc(m.thumb)}" alt="">` : ''}<span>${epIco('play')}</span></button>
      <span class="ep-murow__t"><b>${esc(m.title)}</b><small>${esc(m.artist || '')}</small></span>
      <button class="ep-pill" data-use="${esc(m.ref)}">${t('Choisir')}</button></div>`;
  const all = (r.catalog || []).concat(r.library || []);
  openSheet(t('Ajouter une musique'), all.length ? `
      ${(r.catalog || []).length ? `<p class="section-label">${t('Musiques Elyzea')}</p>${r.catalog.map(row).join('')}` : ''}
      ${(r.library || []).length ? `<p class="section-label">${t('Ma bibliothèque Itoune')}</p>${r.library.map(row).join('')}` : ''}`
    : `<p class="sheet__text">${t('Aucune musique disponible. Ajoutez des morceaux dans l\'application Itoune : ils apparaîtront ici.')}</p>`, (sh) => {
    const find = (ref) => all.find(m => m.ref === ref);
    $$('[data-prev]', sh).forEach(b => b.onclick = () => { epPlay(find(b.dataset.prev), 'pick:' + b.dataset.prev); $$('[data-prev]', sh).forEach(x => x.classList.toggle('playing', EP.playing === 'pick:' + x.dataset.prev)); });
    $$('[data-use]', sh).forEach(b => b.onclick = () => { epStopMusic(); closeSheet(); onPick(find(b.dataset.use)); });
    sh.addEventListener('sheetclose', epStopMusic);
  });
}

/* ---------- Messages ---------- */
async function epInbox(params, tok) {
  epShell('inbox', `<h1 class="ep-title ep-title--u">${esc(EP.acc.username)}</h1><div class="ep-top__r">
    <button class="ep-ib" data-refresh aria-label="${t('Actualiser')}">${epIco('refresh')}</button>
    <button class="ep-ib" data-newmsg aria-label="${t('Nouveau message')}">${epIco('edit')}</button></div>`, `<p class="ep-h2">${t('Messages')}</p><div id="ep-convs">${loading()}</div>`);
  $('[data-refresh]', appView).onclick = (e) => { e.currentTarget.classList.add('spin'); epRender({ page: 'inbox' }); };
  $('[data-newmsg]', appView).onclick = () => epNewMessage();
  const r = await epApi('epConversations');
  if (tok !== EP.tok) return;
  if (r.badges) { EP.badges = r.badges; epSyncBadge(); }
  const list = r.conversations || [];
  const box = $('#ep-convs');
  box.innerHTML = list.length ? `<div class="ep-users">${list.map(c => `<button class="ep-conv ${c.unread ? 'unread' : ''}" data-conv="${c.id}">${epAv(c, 52)}
      <span class="ep-conv__m"><b>${esc(c.name)}</b><small>${c.lastMine ? t('Vous : ') : ''}${esc(c.last)} · ${epAgo(c.ts)}</small></span>${c.unread ? '<i class="ep-conv__dot"></i>' : ''}</button>`).join('')}</div>`
    : `<div class="ep-empty"><div class="ep-empty__ic">${epIco('send')}</div><strong>${t('Vos messages')}</strong><p>${t('Envoyez des photos et des messages privés à vos amis.')}</p><div class="ep-empty__btns"><button class="btn ep-grad" data-newmsg2>${t('Envoyer un message')}</button></div></div>`;
  $$('[data-conv]', box).forEach(b => b.onclick = () => epGo('chat', { id: +b.dataset.conv }));
  $('[data-newmsg2]', box)?.addEventListener('click', () => epNewMessage());
}
function epNewMessage() {
  openSheet(t('Nouveau message'), `<input class="search" id="ep-nm-q" placeholder="${t('Rechercher un compte')}" autocomplete="off"><div class="ep-users" id="ep-nm-list"><p class="ep-muted" style="text-align:center;padding:18px">${t('Tapez un nom pour trouver un compte.')}</p></div>`, (sh) => {
    let tm;
    $('#ep-nm-q', sh).oninput = (e) => {
      clearTimeout(tm); const q = e.target.value.trim(); if (!q) return;
      tm = setTimeout(async () => {
        const r = await epApi('epSearch', { q });
        const users = (r.users || []).filter(u => !u.me);
        $('#ep-nm-list', sh).innerHTML = users.length ? users.map(u => `<button class="ep-urow" data-to="${esc(u.username)}">${epAv(u, 40)}<span><b>${esc(u.username)}</b><small>${esc(u.name)}</small></span></button>`).join('') : `<p class="ep-muted" style="text-align:center;padding:18px">${t('Aucun compte')}</p>`;
        $$('[data-to]', sh).forEach(b => b.onclick = () => { closeSheet(true); epGo('chat', { user: b.dataset.to }); });
      }, 250);
    };
  });
}
const EP_SHARED = {};
function epBubble(m) {
  const sp = m.post ? EP_SHARED[m.post] : null;
  const shared = m.post ? (sp ? `<button class="ep-sharedpost" data-open-post="${m.post}"><span class="ep-sharedpost__h">${epAv(sp, 22)}<b>${esc(sp.username)}</b></span><img src="${esc(sp.image)}" alt="" loading="lazy">${sp.content ? `<small>${esc(sp.content)}</small>` : ''}</button>` : `<span class="ep-sharedpost ep-sharedpost--gone">${t('Publication indisponible')}</span>`) : '';
  return `<div class="ep-msg ${m.mine ? 'mine' : ''}" data-mid="${m.id}">${shared}${m.body ? `<p>${esc(m.body).replace(/\n/g, '<br>')}</p>` : ''}<small>${epAgo(m.ts)}</small></div>`;
}
async function epChat(params, tok) {
  epShell('chat', `${epBackBtn()}<button class="ep-chathead" data-chu>${loading().replace('spinner', 'spinner ep-sp-sm')}</button>`, `<div id="ep-msgs"></div>`);
  const foot = document.createElement('div'); foot.className = 'ep-chatfoot';
  foot.innerHTML = `<div class="composer"><textarea class="field" id="ep-c-in" rows="1" maxlength="${EP.limits.message}" placeholder="${t('Votre message…')}"></textarea><button class="icon-btn icon-btn--accent" id="ep-c-go" aria-label="${t('Envoyer')}">${icon('send')}</button></div>`;
  $('.ep').appendChild(foot);
  const r = await epApi('epConversation', params.id ? { id: params.id } : { username: params.user });
  if (tok !== EP.tok) return;
  if (!r.ok) { $('.ep-page').innerHTML = empty(t('Conversation indisponible'), epErr(r)); foot.remove(); return; }
  const c = r.conversation;
  EP.chat = { id: c.id, user: c.user, tok };
  Object.assign(EP_SHARED, r.posts || {});
  $('[data-chu]', appView).innerHTML = `${epAv(c.user, 32)}<span><b>${esc(c.user.name)}</b><small>@${esc(c.user.username)}</small></span>`;
  $('[data-chu]', appView).onclick = () => epGo('profile', { user: c.user.username });
  const box = $('#ep-msgs'), main = $('#ep-main');
  const wire = () => { $$('[data-open-post]:not([data-w])', box).forEach(b => { b.dataset.w = 1; b.onclick = () => epGo('post', { id: +b.dataset.openPost }); }); };
  const msgs = r.messages || [];
  box.innerHTML = (r.more ? `<button class="ep-older" id="ep-older">${t('Messages précédents')}</button>` : '')
    + (msgs.length ? msgs.map(epBubble).join('') : `<div class="ep-chatintro">${epAv(c.user, 76)}<b>${esc(c.user.name)}</b><small>@${esc(c.user.username)} · ElyPick</small></div>`);
  wire();
  main.scrollTop = main.scrollHeight;
  if (r.posts) setTimeout(() => { main.scrollTop = main.scrollHeight; }, 250);
  if (c.id) { const b = await epApi('epMarkRead', { id: c.id }); if (b.badges) { EP.badges = b.badges; epSyncBadge(); } }
  const older = () => $('#ep-older')?.addEventListener('click', async () => {
    const first = $('[data-mid]', box);
    const o = await epApi('epConversation', { id: EP.chat.id, before: +first.dataset.mid });
    if (!o.ok) return;
    Object.assign(EP_SHARED, o.posts || {});
    const h = main.scrollHeight;
    $('#ep-older').remove();
    box.insertAdjacentHTML('afterbegin', (o.more ? `<button class="ep-older" id="ep-older">${t('Messages précédents')}</button>` : '') + o.messages.map(epBubble).join(''));
    main.scrollTop = main.scrollHeight - h; wire(); older();
  });
  older();
  const input = $('#ep-c-in');
  input.oninput = () => { input.style.height = 'auto'; input.style.height = Math.min(110, input.scrollHeight) + 'px'; };
  const send = async () => {
    const body = input.value.trim(); if (!body) return;
    input.value = ''; input.style.height = '';
    const s = await epApi('epSend', EP.chat.id ? { id: EP.chat.id, body } : { username: c.user.username, body });
    if (!s.ok) { input.value = body; return epToast(epErr(s)); }
    if (!EP.chat.id) { EP.chat.id = s.conv; setParams({ page: 'chat', id: s.conv }); $('.ep-chatintro', box)?.remove(); }
    box.insertAdjacentHTML('beforeend', epBubble(s.message));
    main.scrollTop = main.scrollHeight;
  };
  $('#ep-c-go').onclick = send;
  input.onkeydown = (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } };
}

/* ---------- Activité ---------- */
async function epActivity(params, tok) {
  epShell('activity', epHead(t('Activité')), loading());
  const r = await epApi('epActivity');
  if (tok !== EP.tok) return;
  if (r.badges) { EP.badges = r.badges; epSyncBadge(); }
  const items = r.items || [];
  const txt = { follow: 'a commencé à vous suivre.', like: 'a aimé votre publication.', story: 'a publié une nouvelle story.' };
  const page = $('.ep-page');
  page.innerHTML = items.length ? `<div class="ep-users">${items.map(n => `<div class="ep-act-row ${n.isRead ? '' : 'new'}" data-n-type="${n.type}" data-n-user="${esc(n.username)}" data-n-post="${n.post || ''}">
      ${epAv(n, 44)}<p><b>${esc(n.username)}</b> ${t(txt[n.type] || '')} <small>${epAgo(n.ts)}</small></p>
      ${n.type === 'like' && n.postImage ? `<img class="ep-act-row__img" src="${esc(n.postImage)}" alt="">` : ''}
      ${n.type === 'follow' ? `<button class="ep-pill ${n.iFollow ? 'ep-pill--on' : ''}" data-fol="${esc(n.username)}" data-on="${n.iFollow ? 1 : 0}">${n.iFollow ? t('Abonné(e)') : t('S\'abonner')}</button>` : ''}</div>`).join('')}</div>`
    : `<div class="ep-empty"><div class="ep-empty__ic">${epIco('heart')}</div><strong>${t('Aucune activité')}</strong><p>${t('Les j\'aime, nouveaux abonnés et stories de vos comptes apparaîtront ici.')}</p></div>`;
  $$('[data-n-type]', page).forEach(row => row.onclick = (e) => {
    if (e.target.closest('[data-fol]')) return;
    const ty = row.dataset.nType;
    if (ty === 'like' && row.dataset.nPost) epGo('post', { id: +row.dataset.nPost });
    else if (ty === 'story') epOpenStories(row.dataset.nUser);
    else epGo('profile', { user: row.dataset.nUser });
  });
  $$('[data-fol]', page).forEach(b => b.onclick = async () => {
    const on = b.dataset.on === '1';
    const x = await epApi('epFollow', { username: b.dataset.fol, follow: !on });
    if (!x.ok) return epToast(epErr(x));
    b.dataset.on = x.following ? 1 : 0; b.classList.toggle('ep-pill--on', x.following); b.textContent = x.following ? t('Abonné(e)') : t('S\'abonner');
  });
}

const EP_PAGES = { home: epHome, search: epSearch, new: epNew, inbox: epInbox, me: epProfile, profile: epProfile, post: epPostPage, follows: epFollows, edit: epEdit, chat: epChat, activity: epActivity };

/* ---------- Événements en direct (serveur → téléphone) ---------- */
function epPush(d) {
  if (d.badges) { EP.badges = d.badges; epSyncBadge(); if (typeof renderHome === 'function' && !S.currentApp && S.open && !S.locked) renderHome(); }
  const cur = S.stack[S.stack.length - 1];
  const here = S.open && S.currentApp === 'instapick' && cur?.id === 'instapick';
  if (d.type === 'dm') {
    if (here && EP.chat && EP.chat.id === d.conv && cur.params?.page === 'chat') {
      Object.assign(EP_SHARED, d.posts || {});
      const box = $('#ep-msgs'), main = $('#ep-main');
      if (box && !$(`[data-mid="${d.message.id}"]`, box)) {
        box.insertAdjacentHTML('beforeend', epBubble(d.message));
        $$('[data-open-post]:not([data-w])', box).forEach(b => { b.dataset.w = 1; b.onclick = () => epGo('post', { id: +b.dataset.openPost }); });
        main.scrollTop = main.scrollHeight;
        epApi('epMarkRead', { id: d.conv }).then(b => { if (b.badges) { EP.badges = b.badges; epSyncBadge(); } });
      }
    } else if (here && cur.params?.page === 'inbox') epRender({ page: 'inbox' });
  }
  if (d.type === 'stories' && here && (cur.params?.page || 'home') === 'home' && !EP.viewer) epRefreshTray();
}
// Ancien point d'entrée (galerie → « Publier sur ElyPick »)
function instaComposer(prefill = '') {
  EP.draft = { mode: 'post', image: prefill || '', caption: '', music: null };
  openApp('instapick', { page: 'new', mode: 'post', image: prefill || '' });
}

/* ---------- Aperçu navigateur (hors FiveM) : données de démonstration en mémoire ---------- */
const EPMock = (() => {
  const img = (h, txt = '') => 'data:image/svg+xml;utf8,' + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="hsl(${h},70%,60%)"/><stop offset="1" stop-color="hsl(${(h + 60) % 360},70%,30%)"/></linearGradient></defs><rect width="600" height="600" fill="url(#g)"/><circle cx="430" cy="170" r="70" fill="rgba(255,255,255,.35)"/><path d="M0 470 L120 360 L230 430 L360 300 L600 480 V600 H0Z" fill="rgba(0,0,0,.35)"/><text x="30" y="560" font-family="sans-serif" font-size="34" fill="#fff">${txt}</text></svg>`);
  const now = () => Math.floor(Date.now() / 1000);
  const U = {
    me: { username: 'lena.duval', name: 'Léna Duval', avatar: img(280, 'L'), bio: 'Photographe à Vinewood 📸' },
    malik: { username: 'malik', name: 'Malik Benali', avatar: img(20, 'M'), bio: 'Cuisinier le jour, DJ la nuit.' },
    ines: { username: 'ines.m', name: 'Inès Morel', avatar: null, bio: '' },
  };
  let acc = null, id = 100;
  const follows = new Set(['me>malik', 'malik>me']);
  const posts = [
    { id: 3, by: 'malik', image: img(30, 'Del Perro'), content: 'Coucher de soleil sur la jetée 🌅 @lena.duval', music: { title: 'Nuit sur Vinewood', artist: 'Los Santos Lofi', url: 'x' }, likes: new Set(['ines']), ts: now() - 3600 },
    { id: 2, by: 'ines', image: img(200, 'Mirror Park'), content: 'Balade au parc', likes: new Set(), ts: now() - 7200 },
    { id: 1, by: 'me', image: img(300, 'Vinewood'), content: 'Première photo sur ElyPick !', likes: new Set(['malik']), ts: now() - 86400 },
  ];
  const comments = { 3: [{ id: 1, by: 'ines', content: 'Magnifique !', ts: now() - 1800 }] };
  const stories = [{ id: 1, by: 'malik', image: img(10, 'Story 1'), ts: now() - 600, seen: false }, { id: 2, by: 'malik', image: img(50, 'Story 2'), ts: now() - 300, seen: false }];
  const hls = [{ id: 1, by: 'me', title: 'Vinewood', cover: null, items: [{ id: 1, image: img(260, 'Souvenir'), ts: now() - 200000 }] }];
  const convs = [{ id: 1, with: 'malik', msgs: [{ id: 1, from: 'malik', body: 'Salut ! Tu viens ce soir ?', ts: now() - 900 }, { id: 2, from: 'malik', body: '', post: 1, ts: now() - 800 }], read: 0 }];
  const acts = [{ id: 1, type: 'follow', by: 'malik', ts: now() - 5000, read: false }, { id: 2, type: 'like', by: 'malik', post: 1, ts: now() - 4000, read: false }];
  const pub = (k) => ({ username: U[k].username, name: U[k].name, avatar: U[k].avatar, bio: U[k].bio });
  const key = (u) => Object.keys(U).find(k => U[k].username === u);
  const P = (p) => ({ id: p.id, image: p.image, content: p.content, ts: p.ts, username: U[p.by].username, name: U[p.by].name, avatar: U[p.by].avatar, music: p.music, likes: p.likes.size, liked: p.likes.has('me'), comments: (comments[p.id] || []).length, mine: p.by === 'me', canFollow: p.by !== 'me' && !follows.has('me>' + p.by) });
  const gallery = [img(120, 'Galerie 1'), img(160, 'Galerie 2'), img(330, 'Galerie 3'), img(60, 'Galerie 4')].map((u, i) => ({ id: i + 1, url: u, type: 'photo' }));
  const unreadDm = () => convs.filter(c => c.msgs.length && c.msgs[c.msgs.length - 1].from !== 'me' && c.msgs[c.msgs.length - 1].id > c.read).length;
  const badges = () => ({ notifs: acts.filter(a => !a.read).length, dms: unreadDm() });
  return {
    U, posts, stories, convs, follows,
    call(n, a = {}) {
      if (n === 'getGallery') return { ok: true, photos: gallery };
      if (n === 'epInit') return { ok: true, account: acc, badges: badges(), limits: { caption: 280, bio: 150, message: 500, storyHours: 24, links: true } };
      if (n === 'epCreateAccount') { if (!/^[a-z0-9_.]{3,20}$/.test(a.username || '')) return { ok: false, error: 'Nom d\'utilisateur : 3 à 20 caractères, lettres, chiffres, _ ou .' }; U.me.username = a.username; U.me.name = a.display || U.me.name; acc = pub('me'); return { ok: true, account: acc }; }
      if (n === 'epUpdateProfile') { U.me.username = a.username || U.me.username; U.me.name = a.display || U.me.name; U.me.bio = a.bio || ''; U.me.avatar = a.avatar || null; acc = pub('me'); return { ok: true, account: acc }; }
      if (n === 'epFeed') { const l = posts.filter(p => p.by === 'me' || follows.has('me>' + p.by)).sort((x, y) => y.id - x.id).map(P); return { ok: true, posts: l, more: false }; }
      if (n === 'epExplore') return { ok: true, posts: posts.slice().sort((x, y) => y.id - x.id).map(p => ({ id: p.id, image: p.image, music: !!p.music, likes: p.likes.size })), more: false };
      if (n === 'epPost') { const p = posts.find(x => x.id === +a.id); return p ? { ok: true, post: P(p) } : { ok: false, error: 'Publication introuvable ou supprimée' }; }
      if (n === 'epLike') { const p = posts.find(x => x.id === +a.id); const on = a.like === undefined ? !p.likes.has('me') : a.like; on ? p.likes.add('me') : p.likes.delete('me'); return { ok: true, liked: on, likes: p.likes.size }; }
      if (n === 'epComments') return { ok: true, comments: (comments[a.id] || []).map(c => ({ id: c.id, content: c.content, ts: c.ts, username: U[c.by].username, name: U[c.by].name, avatar: U[c.by].avatar, canDelete: c.by === 'me' })) };
      if (n === 'epComment') { (comments[a.id] ||= []).push({ id: ++id, by: 'me', content: a.content, ts: now() }); return { ok: true }; }
      if (n === 'epDeleteComment') { Object.values(comments).forEach(l => { const i = l.findIndex(c => c.id === a.id); if (i >= 0) l.splice(i, 1); }); return { ok: true }; }
      if (n === 'epDeletePost') { const i = posts.findIndex(p => p.id === a.id && p.by === 'me'); if (i < 0) return { ok: false }; posts.splice(i, 1); return { ok: true }; }
      if (n === 'epCreatePost') { if (!a.image) return { ok: false, error: 'Choisis une photo' }; const m = a.music ? this.call('epMusic').library.concat(this.call('epMusic').catalog).find(x => x.ref === a.music) : null; posts.unshift({ id: ++id, by: 'me', image: a.image, content: a.caption || '', music: m, likes: new Set(), ts: now() }); return { ok: true, id }; }
      if (n === 'epMusic') return { ok: true, catalog: [{ ref: 'cat:1', title: 'Nuit sur Vinewood', artist: 'Los Santos Lofi', url: 'x' }], library: [{ ref: 'lib:4', title: 'Sunset Drive', artist: 'Elyzea FM', url: 'x' }] };
      if (n === 'epSearch') { const q = String(a.q).toLowerCase().replace(/^@/, ''); return { ok: true, users: Object.keys(U).filter(k => U[k].username.includes(q) || U[k].name.toLowerCase().includes(q)).map(k => Object.assign(pub(k), { me: k === 'me', iFollow: follows.has('me>' + k), followers: [...follows].filter(f => f.endsWith('>' + k)).length })) }; }
      if (n === 'epFollow') { const k = key(a.username); const on = a.follow === undefined ? !follows.has('me>' + k) : a.follow; on ? follows.add('me>' + k) : follows.delete('me>' + k); return { ok: true, following: on, followers: [...follows].filter(f => f.endsWith('>' + k)).length }; }
      if (n === 'epFollowList') { const k = key(a.username); const l = [...follows].filter(f => a.kind === 'following' ? f.startsWith(k + '>') : f.endsWith('>' + k)).map(f => a.kind === 'following' ? f.split('>')[1] : f.split('>')[0]); return { ok: true, users: l.map(x => Object.assign(pub(x), { me: x === 'me', iFollow: follows.has('me>' + x) })), more: false }; }
      if (n === 'epProfile') {
        const k = a.username ? key(a.username) : 'me'; if (!k) return { ok: false, error: 'Compte introuvable' };
        const mine = posts.filter(p => p.by === k);
        const st = stories.filter(s => s.by === k);
        return { ok: true, profile: Object.assign(pub(k), { mine: k === 'me', posts: mine.length, followers: [...follows].filter(f => f.endsWith('>' + k)).length, following: [...follows].filter(f => f.startsWith(k + '>')).length, iFollow: follows.has('me>' + k), followsMe: follows.has(k + '>me'), story: st.length ? (st.every(s => s.seen) ? 'seen' : 'new') : null, highlights: hls.filter(h => h.by === k).map(h => ({ id: h.id, title: h.title, cover: h.cover || h.items[0]?.image, count: h.items.length })) }), grid: mine.map(p => ({ id: p.id, image: p.image, music: !!p.music, likes: p.likes.size })), more: false };
      }
      if (n === 'epUserPosts') return { ok: true, grid: [], more: false };
      if (n === 'epStoriesTray') { const by = [...new Set(stories.map(s => s.by))]; return { ok: true, users: by.map(k => Object.assign(pub(k), { mine: k === 'me', seen: stories.filter(s => s.by === k).every(s => s.seen), ts: now() })) }; }
      if (n === 'epStories') { const k = a.username ? key(a.username) : 'me'; return { ok: true, user: pub(k), mine: k === 'me', stories: stories.filter(s => s.by === k).map(s => ({ id: s.id, image: s.image, ts: s.ts, seen: s.seen, views: k === 'me' ? 2 : null })) }; }
      if (n === 'epStorySeen') { const s = stories.find(x => x.id === a.id); if (s) s.seen = true; return { ok: true }; }
      if (n === 'epCreateStory') { stories.push({ id: ++id, by: 'me', image: a.image, ts: now(), seen: false }); if (a.highlight) this.call('epHighlightAdd', { id: a.highlight.id, title: a.highlight.title, stories: [id] }); return { ok: true, id }; }
      if (n === 'epDeleteStory') { const i = stories.findIndex(s => s.id === a.id && s.by === 'me'); if (i >= 0) stories.splice(i, 1); return { ok: true }; }
      if (n === 'epMyStories') return { ok: true, stories: stories.filter(s => s.by === 'me').map(s => ({ id: s.id, image: s.image, ts: s.ts })), highlights: hls.filter(h => h.by === 'me').map(h => ({ id: h.id, title: h.title, cover: h.cover || h.items[0]?.image })) };
      if (n === 'epHighlight') { const h = hls.find(x => x.id === a.id); return h ? { ok: true, highlight: Object.assign({ id: h.id, title: h.title }, pub(h.by)), items: h.items, mine: h.by === 'me' } : { ok: false, error: 'Catégorie introuvable' }; }
      if (n === 'epHighlightAdd') { let h = a.id ? hls.find(x => x.id === a.id) : null; if (!h) { if (!a.title) return { ok: false, error: 'Donne un nom à la catégorie' }; h = { id: ++id, by: 'me', title: a.title, items: [] }; hls.unshift(h); } (a.stories || []).forEach(sid => { const s = stories.find(x => x.id === sid); if (s && !h.items.some(i => i.story === sid)) h.items.push({ id: ++id, story: sid, image: s.image, ts: s.ts }); }); return { ok: true, id: h.id }; }
      if (n === 'epHighlightUpdate') { const h = hls.find(x => x.id === a.id); if (a.title) h.title = a.title; if (a.coverItem) h.cover = h.items.find(i => i.id === a.coverItem)?.image; return { ok: true }; }
      if (n === 'epHighlightRemove') { hls.forEach(h => { const i = h.items.findIndex(x => x.id === a.item); if (i >= 0) h.items.splice(i, 1); }); return { ok: true }; }
      if (n === 'epHighlightDelete') { const i = hls.findIndex(h => h.id === a.id); if (i >= 0) hls.splice(i, 1); return { ok: true }; }
      if (n === 'epConversations') return { ok: true, badges: badges(), conversations: convs.filter(c => c.msgs.length).map(c => { const l = c.msgs[c.msgs.length - 1]; return Object.assign(pub(c.with), { id: c.id, last: l.body || 'a partagé une publication', lastMine: l.from === 'me', ts: l.ts, unread: l.from !== 'me' && l.id > c.read }); }) };
      if (n === 'epConversation') {
        let c = a.id ? convs.find(x => x.id === a.id) : convs.find(x => U[x.with].username === a.username);
        if (!c) { const k = key(a.username); return k ? { ok: true, conversation: { id: null, user: pub(k) }, messages: [], more: false } : { ok: false, error: 'Compte introuvable' }; }
        c.read = c.msgs.length ? c.msgs[c.msgs.length - 1].id : 0;
        const ps = {}; c.msgs.filter(m => m.post).forEach(m => { const p = posts.find(x => x.id === m.post); if (p) ps[p.id] = { id: p.id, image: p.image, content: p.content, username: U[p.by].username, avatar: U[p.by].avatar }; });
        return { ok: true, conversation: { id: c.id, user: pub(c.with) }, messages: c.msgs.map(m => ({ id: m.id, mine: m.from === 'me', body: m.body, post: m.post, ts: m.ts })), posts: ps, more: false };
      }
      if (n === 'epMarkRead') return { ok: true, badges: badges() };
      if (n === 'epSend') {
        let c = a.id ? convs.find(x => x.id === a.id) : convs.find(x => U[x.with].username === a.username);
        if (!c) { const k = key(a.username); if (!k) return { ok: false, error: 'Compte introuvable' }; c = { id: ++id, with: k, msgs: [], read: 0 }; convs.unshift(c); }
        const m = { id: ++id, from: 'me', body: a.body || '', post: a.post, ts: now() }; c.msgs.push(m); c.read = m.id;
        return { ok: true, conv: c.id, message: { id: m.id, mine: true, body: m.body, post: m.post, ts: m.ts }, posts: {} };
      }
      if (n === 'epActivity') { const items = acts.map(x => ({ id: x.id, type: x.type, post: x.post, isRead: x.read, ts: x.ts, username: U[x.by].username, name: U[x.by].name, avatar: U[x.by].avatar, postImage: x.post ? posts.find(p => p.id === x.post)?.image : null, iFollow: follows.has('me>' + x.by) })); acts.forEach(x => { x.read = true; }); return { ok: true, items, badges: badges() }; }
      return { ok: false, error: 'mock: ' + n };
    },
  };
})();

/* ---------- Traductions (anglais, espagnol) des principaux textes ElyPick ---------- */
(() => {
  const T = {
    'Accueil': ['Home', 'Inicio'], 'Recherche': ['Search', 'Buscar'], 'Créer': ['Create', 'Crear'], 'Messages': ['Messages', 'Mensajes'], 'Profil': ['Profile', 'Perfil'],
    'Activité': ['Activity', 'Actividad'], 'Votre story': ['Your story', 'Tu historia'], 'Publication': ['Post', 'Publicación'], 'Story': ['Story', 'Historia'],
    'S\'abonner': ['Follow', 'Seguir'], 'Abonné(e)': ['Following', 'Siguiendo'], 'S\'abonner en retour': ['Follow back', 'Seguir también'], 'Vous suit': ['Follows you', 'Te sigue'],
    'publications': ['posts', 'publicaciones'], 'abonnés': ['followers', 'seguidores'], 'abonnements': ['following', 'seguidos'], 'Abonnés': ['Followers', 'Seguidores'], 'Abonnements': ['Following', 'Seguidos'],
    'Modifier le profil': ['Edit profile', 'Editar perfil'], 'Message': ['Message', 'Mensaje'], 'Nouveau': ['New', 'Nuevo'], 'Nouvelle': ['New', 'Nueva'],
    '{n} J\'aime': ['{n} likes', '{n} me gusta'], 'Voir les {n} commentaires': ['View all {n} comments', 'Ver los {n} comentarios'], 'Voir le commentaire': ['View comment', 'Ver comentario'],
    'Commentaires': ['Comments', 'Comentarios'], 'Ajouter un commentaire…': ['Add a comment…', 'Añade un comentario…'], 'Envoyer à': ['Send to', 'Enviar a'], 'Envoyer': ['Send', 'Enviar'],
    'Rechercher un compte': ['Search accounts', 'Buscar cuentas'], 'Partager': ['Share', 'Compartir'], 'Aperçu': ['Preview', 'Vista previa'], 'Fermer l\'aperçu': ['Close preview', 'Cerrar vista previa'],
    'Écrivez une description…': ['Write a caption…', 'Escribe una descripción…'], 'Ajouter une musique': ['Add music', 'Añadir música'], 'Facultatif': ['Optional', 'Opcional'],
    'Changer de photo': ['Change photo', 'Cambiar foto'], '1. Choisissez une photo': ['1. Choose a photo', '1. Elige una foto'], 'Appareil': ['Camera', 'Cámara'],
    'Partager en story': ['Share to story', 'Compartir en historia'], 'Ajouter à la une': ['Add to highlights', 'Añadir a destacadas'], 'Story publiée': ['Story shared', 'Historia publicada'],
    'Publication partagée': ['Post shared', 'Publicación compartida'], 'Nouveau message': ['New message', 'Nuevo mensaje'], 'Votre message…': ['Message…', 'Mensaje…'],
    'Messages précédents': ['Earlier messages', 'Mensajes anteriores'], 'Vous : ': ['You: ', 'Tú: '], 'Actualiser': ['Refresh', 'Actualizar'],
    'a commencé à vous suivre.': ['started following you.', 'empezó a seguirte.'], 'a aimé votre publication.': ['liked your post.', 'le gustó tu publicación.'], 'a publié une nouvelle story.': ['shared a new story.', 'publicó una nueva historia.'],
    'Créer mon compte': ['Create my account', 'Crear mi cuenta'], 'Nom affiché': ['Display name', 'Nombre visible'], 'Nom d\'utilisateur': ['Username', 'Nombre de usuario'], 'Biographie': ['Bio', 'Biografía'],
    'Enregistrer': ['Save', 'Guardar'], 'Changer la photo': ['Change photo', 'Cambiar foto'], 'Profil mis à jour': ['Profile updated', 'Perfil actualizado'],
    'Supprimer la publication': ['Delete post', 'Eliminar publicación'], 'Supprimer la story': ['Delete story', 'Eliminar historia'], 'Répondre à @{u}': ['Reply to @{u}', 'Responder a @{u}'], 'Vue par {n}': ['Seen by {n}', 'Visto por {n}'],
    'à l\'instant': ['just now', 'ahora'], 'il y a {n} min': ['{n} min ago', 'hace {n} min'], 'il y a {n} h': ['{n} h ago', 'hace {n} h'], 'il y a {n} j': ['{n} d ago', 'hace {n} d'],
    '{name} s\'est abonné(e) à vous.': ['{name} started following you.', '{name} empezó a seguirte.'], '{name} a aimé votre publication.': ['{name} liked your post.', 'A {name} le gustó tu publicación.'],
    '{name} a publié une nouvelle story.': ['{name} shared a new story.', '{name} publicó una nueva historia.'], 'vous a envoyé une publication': ['sent you a post', 'te envió una publicación'],
  };
  for (const [fr, [en, es]] of Object.entries(T)) { if (I18N.en && !I18N.en[fr]) I18N.en[fr] = en; if (I18N.es && !I18N.es[fr]) I18N.es[fr] = es; }
})();
