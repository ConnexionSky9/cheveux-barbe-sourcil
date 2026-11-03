'use strict';
/* =========================================================
   LASERGAME — appli du LaserGame ElyzeaFA (thème néon du jeu)
   · Profil : points, rang, position, statistiques PVP / Zombie
   · Classement : PVP et Zombie (les mêmes que la borne)
   · Matchs : demandes de match PVP Arena, écrire à l'auteur, rejoindre
   · Annonces : « 21:30 · carte Zombie » avec bouton Rejoindre
   · Messages : discussions entre joueurs de l'appli
   « Rejoindre » ne téléporte JAMAIS : seul un point GPS est posé
   sur le PNJ LaserGame le plus proche. elyzea_lasergame vérifie tout.
   ========================================================= */
const LG = { tab: 'me', home: null, board: { mode: 'pvp', kind: 'pvp_points', page: 1 }, thread: null, sending: false };
const LG_ASSETS = IS_BROWSER ? '../../elyzea_lasergame/html/' : 'nui://elyzea_lasergame/html/';
const lgCall = (action, data = {}) => api('lgCall', { action, data });

const LG_TABS = [
  ['me', 'Profil', '<circle cx="12" cy="8" r="3.6"/><path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/>'],
  ['board', 'Classement', '<path d="M8 21V11H3v10zM15 21V4h-5v17zM21 21v-7h-5v7z"/>'],
  ['match', 'Matchs', '<path d="M4 20 14 10M14 10l3-3 3 1-1 3-3 3M7 14l3 3M17 20l-3-3M20 4 10 14M10 14l-3 3-3-1 1-3 3-3"/>'],
  ['event', 'Annonces', '<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4M12 13.5v3l2 1.2"/>'],
  ['msg', 'Messages', '<path d="M21 11.5a8.5 8 0 0 1-12.3 7.1L4 20l1.3-4A8.5 8 0 1 1 21 11.5z"/>'],
];
const LG_BOARDS = {
  pvp: [['pvp_points', 'Points'], ['pvp_ratio', 'Ratio'], ['pvp_wins', 'Victoires'], ['pvp_streak', 'Séries']],
  zombie: [['zb_round', 'Manche'], ['zb_kills', 'Éliminations'], ['zb_solo', 'Solo'], ['zb_teams', 'Équipes']],
};
const LG_RES = { win: ['V', 'Victoire', 'win'], loss: ['D', 'Défaite', 'loss'], draw: ['N', 'Nul', 'draw'], left: ['A', 'Abandon', 'loss'] };
const lgSvg = (p, cls = 'lgi') => `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${p}</svg>`;
const LGI = {
  gps: '<path d="M12 21.5s-7-6.6-7-12.2a7 7 0 0 1 14 0c0 5.6-7 12.2-7 12.2z"/><circle cx="12" cy="9.3" r="2.6"/>',
  plus: '<path d="M12 5v14M5 12h14"/>', send: '<path d="m4 12 16-8-6 16-2.5-6.5z"/>', msg: '<path d="M21 11.5a8.5 8 0 0 1-12.3 7.1L4 20l1.3-4A8.5 8 0 1 1 21 11.5z"/>',
  back: '<path d="m15 5-7 7 7 7"/>', reload: '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 5v6h-6"/>', trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
  users: '<circle cx="9" cy="8" r="3.4"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4.6a3.4 3.4 0 0 1 0 6.8M18 14a6.5 6.5 0 0 1 3.5 6"/>',
  clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>', map: '<path d="M9 4 3.5 6v14L9 18l6 2 5.5-2V4L15 6zM9 4v14M15 6v14"/>',
  coin: '<circle cx="12" cy="12" r="8.5"/><path d="M14.5 9.5c-.5-1-1.4-1.5-2.5-1.5-1.5 0-2.5.8-2.5 2s1 1.7 2.5 2 2.5.8 2.5 2-1 2-2.5 2c-1.2 0-2.1-.6-2.6-1.6M12 6.5V8M12 16v1.5"/>',
  skull: '<path d="M12 3a7.5 7.5 0 0 0-4.5 13.5V20h9v-3.5A7.5 7.5 0 0 0 12 3z"/><circle cx="9.3" cy="11" r="1.5"/><circle cx="14.7" cy="11" r="1.5"/><path d="M10.5 20v-2M13.5 20v-2"/>',
};
const lgNum = (n) => Math.round(Number(n) || 0).toLocaleString(locale());
const lgHM = (ts) => { const d = new Date(ts * 1000); return `${pad(d.getHours())}:${pad(d.getMinutes())}`; };
function lgIn(ts) {
  const s = ts - Date.now() / 1000;
  if (s <= 0) return t('C\'est l\'heure');
  if (s < 3600) return t('dans {m} min', { m: Math.max(1, Math.ceil(s / 60)) });
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
  return h < 24 ? t('dans {h} h {m}', { h, m: pad(m) }) : t('dans {d} j', { d: Math.floor(h / 24) });
}
const lgRank = (id) => (LG.home?.ranks || []).find(r => r.id === id) || { id, label: id, color: '#B57BFF' };
const lgRankImg = (id, cls = '') => `<img class="${cls}" src="${LG_ASSETS}ranks/${esc(id)}.png" alt="" onerror="this.style.visibility='hidden'">`;
const lgToast = (r, ok) => notify({ app: 'lasergame', title: 'LaserGame', text: (r && (r.message || r.error)) || ok || t('Réessayez dans un instant.') });

// GPS : point posé sur la carte, jamais de téléportation
function lgGps(g) {
  if (!g || g.x == null) return;
  post('setWaypoint', { x: +g.x, y: +g.y });
}

/* ---------------------------------------------------------
   Coque de l'appli
   --------------------------------------------------------- */
function lgShell(inner, { sub = '' } = {}) {
  const unread = LG.home?.unread || 0;
  appView.innerHTML = `<div class="app lgp" data-tab="${LG.tab}">
    <div class="lgp-bg" aria-hidden="true"><i class="l1"></i><i class="l2"></i><i class="grid"></i></div>
    <header class="lgp-top">
      <button class="lgp-ib" data-back aria-label="${t('Retour')}">${lgSvg(LGI.back)}</button>
      <div class="lgp-word"><span>LASER</span><b>GAME</b>${sub ? `<em>${esc(sub)}</em>` : ''}</div>
      <button class="lgp-ib" data-lg-gps aria-label="${t('GPS vers le LaserGame')}" title="${t('GPS vers le LaserGame')}">${lgSvg(LGI.gps)}</button>
    </header>
    <main class="lgp-main">${inner}</main>
    <nav class="lgp-nav">${LG_TABS.map(([k, l, p]) => `<button class="${LG.tab === k ? 'on' : ''}" data-lg-tab="${k}">
      <span class="ic">${lgSvg(p)}${k === 'msg' && unread > 0 ? `<i class="dot">${unread > 99 ? '99+' : unread}</i>` : ''}</span><span>${t(l)}</span></button>`).join('')}</nav>
  </div>`;
  $$('[data-lg-tab]', appView).forEach(b => b.onclick = () => { LG.thread = null; lgOpen(b.dataset.lgTab); });
  $('[data-lg-gps]', appView).onclick = async () => { const r = await lgCall('gps'); if (r && r.ok) lgGps(r.gps); lgToast(r); };
  return $('.lgp-main', appView);
}
const lgLoading = () => `<div class="lgp-load"><i></i><i></i><i></i></div>`;
const lgEmpty = (title, text = '', btn = '') => `<div class="lgp-empty"><div class="ring"></div><strong>${title}</strong><p>${text}</p>${btn}</div>`;

function lgOpen(tab, params = {}) {
  LG.tab = tab;
  setParams(Object.assign({ tab }, params));
  ({ me: lgMe, board: lgBoard, match: () => lgPosts('match'), event: () => lgPosts('event'), msg: lgMessages })[tab]?.(params);
}

Views.lasergame = async ({ tab, token, name } = {}) => {
  LG.tab = tab || LG.tab || 'me';
  const main = lgShell(lgLoading());
  const r = await lgCall('home');
  if (S.currentApp !== 'lasergame') return;
  if (!r || !r.ok) { main.innerHTML = lgEmpty(t('LaserGame indisponible'), esc(t((r && r.error) || 'Réessayez dans un instant.'))); return; }
  LG.home = r;
  S.lgBadge = r.unread || 0;
  if (token) { LG.tab = 'msg'; LG.thread = { token, name }; }
  lgOpen(LG.tab, token ? { token, name } : {});
};

/* ---------------------------------------------------------
   Profil : points, rang, statistiques
   --------------------------------------------------------- */
function lgMe() {
  const h = LG.home, p = h.profile || {}, rk = lgRank(p.rank);
  const pct = Math.round((p.progress || 0) * 100);
  const res = (x) => LG_RES[x] || ['–', x, 'draw'];
  const main = lgShell(`
    ${h.excluded ? `<div class="lgp-alert">${t('Tu es exclu du LaserGame.')}</div>` : ''}
    <section class="lgp-hero" style="--rk:${rk.color}">
      <div class="lgp-hero__scan"></div>
      <div class="lgp-hero__rank">${lgRankImg(p.rank, 'rk')}<div class="lgp-halo"></div></div>
      <div class="lgp-hero__info">
        <p class="nm">${esc(h.me.name)}</p>
        <p class="rl">${esc(p.rankLabel || rk.label)}</p>
        <p class="pts"><b>${lgNum(p.points)}</b><span>${t('points')}</span></p>
      </div>
      <div class="lgp-pos">${p.position ? `<small>${t('Rang')}</small><b>#${lgNum(p.position)}</b>` : `<small>${t('Non classé')}</small><b>–</b>`}</div>
      <div class="lgp-prog"><div class="bar"><i style="width:${pct}%"></i></div>
        <p>${p.next ? t('{n} pts avant {r}', { n: lgNum(p.next.min - p.points), r: esc(p.next.label) }) : t('Rang maximum atteint')}<span>${t('Record : {n}', { n: lgNum(p.peak) })}</span></p></div>
    </section>
    <h3 class="lgp-h"><span>PVP ARENA</span></h3>
    <div class="lgp-stats">
      <div><b>${lgNum(p.matches)}</b><span>${t('Matchs')}</span></div>
      <div class="g"><b>${lgNum(p.wins)}</b><span>${t('Victoires')}</span></div>
      <div class="r"><b>${lgNum(p.losses)}</b><span>${t('Défaites')}</span></div>
      <div><b>${p.ratio ?? 0}</b><span>${t('Ratio K/D')}</span></div>
      <div><b>${lgNum(p.kills)}</b><span>${t('Éliminations')}</span></div>
      <div class="y"><b>${lgNum(p.bestStreak)}</b><span>${t('Meilleure série')}</span></div>
    </div>
    <h3 class="lgp-h z"><span>ZOMBIE</span></h3>
    <div class="lgp-stats z">
      <div><b>${lgNum(p.zbBestRound)}</b><span>${t('Meilleure manche')}</span></div>
      <div><b>${lgNum(p.zbBestSolo)}</b><span>${t('Record solo')}</span></div>
      <div><b>${lgNum(p.zbKills)}</b><span>${t('Zombies tués')}</span></div>
    </div>
    <h3 class="lgp-h"><span>${t('DERNIÈRES PARTIES')}</span></h3>
    ${(h.history || []).length ? `<div class="lgp-hist">${h.history.map(x => {
      const zb = x.mode === 'zombie', rr = res(x.result);
      return `<div class="row ${zb ? 'zb' : rr[2]}">
        <span class="tag">${zb ? lgSvg(LGI.skull) : rr[0]}</span>
        <div class="tx"><b>${zb ? t('Zombie · manche {n}', { n: x.round || 0 }) : `${esc(x.format || 'PVP')} · ${esc(rr[1])}`}</b>
          <small>${esc(x.mapLabel || '')}${!zb && x.score_a != null ? ` · ${x.score_a}-${x.score_b}` : ''} · ${timeAgo(x.created_at)}</small></div>
        <span class="val">${zb ? `${lgNum(x.kills)} ${lgSvg(LGI.skull, 'lgi s')}` : `<em class="${(x.points_delta || 0) >= 0 ? 'up' : 'down'}">${(x.points_delta || 0) >= 0 ? '+' : ''}${x.points_delta || 0}</em>`}</span>
      </div>`; }).join('')}</div>` : lgEmpty(t('Aucune partie'), t('Ton historique apparaîtra ici après ta première partie.'))}
    <button class="lgp-btn ghost block" data-lg-go>${lgSvg(LGI.gps)}${t('Aller au LaserGame (GPS)')}</button>
  `);
  $('[data-lg-go]', main).onclick = () => $('[data-lg-gps]', appView).click();
}

/* ---------------------------------------------------------
   Classement
   --------------------------------------------------------- */
async function lgBoard() {
  const b = LG.board;
  const main = lgShell(`
    <div class="lgp-seg">${['pvp', 'zombie'].map(m => `<button class="${b.mode === m ? 'on' : ''} ${m}" data-lg-mode="${m}">${m === 'pvp' ? 'PVP ARENA' : 'ZOMBIE'}</button>`).join('')}</div>
    <div class="lgp-chips">${LG_BOARDS[b.mode].map(([k, l]) => `<button class="${b.kind === k ? 'on' : ''}" data-lg-kind="${k}">${t(l)}</button>`).join('')}</div>
    <div class="lgp-board">${lgLoading()}</div>`);
  $$('[data-lg-mode]', main).forEach(x => x.onclick = () => { b.mode = x.dataset.lgMode; b.kind = LG_BOARDS[b.mode][0][0]; b.page = 1; lgBoard(); });
  $$('[data-lg-kind]', main).forEach(x => x.onclick = () => { b.kind = x.dataset.lgKind; b.page = 1; lgBoard(); });
  const r = await lgCall('board', { kind: b.kind, page: b.page });
  if (S.currentApp !== 'lasergame' || LG.tab !== 'board') return;
  const box = $('.lgp-board', main);
  if (!r || !r.ok) { box.innerHTML = lgEmpty(t('Classement indisponible'), esc((r && r.error) || '')); return; }
  if (!r.rows.length) { box.innerHTML = lgEmpty(t('Personne pour l\'instant'), t('Joue une partie pour entrer dans ce classement.')); return; }
  const me = LG.home.me.name;
  const unit = { pvp_points: 'pts', pvp_ratio: 'K/D', pvp_wins: t('vict.'), pvp_streak: t('série'), zb_round: t('manche'), zb_kills: t('tués'), zb_solo: t('manche'), zb_teams: t('manche') }[b.kind];
  const team = b.kind === 'zb_teams';
  box.innerHTML = `${r.rows.map(x => {
    const nm = team ? (x.names || '') : `${x.firstname || ''} ${x.lastname || ''}`.trim();
    const pos = x.pos;
    const sub = team ? t('{n} joueurs · {k} tués', { n: x.players, k: lgNum(x.kills) })
      : b.mode === 'pvp' ? t('{w} V · {l} D · {p} pts', { w: lgNum(x.wins), l: lgNum(x.losses ?? 0), p: lgNum(x.points ?? x.v) })
      : t('{k} tués · {g} parties', { k: lgNum(x.zb_kills ?? x.v), g: lgNum(x.zb_games ?? 0) });
    return `<div class="lgp-lb ${pos <= 3 ? 'p' + pos : ''} ${nm === me ? 'me' : ''}">
      <span class="pos">${pos <= 3 ? `<i>${pos}</i>` : pos}</span>
      ${b.mode === 'pvp' && x.rank ? lgRankImg(x.rank, 'rk') : `<span class="zb">${lgSvg(team ? LGI.users : LGI.skull)}</span>`}
      <div class="tx"><b>${esc(nm || '?')}</b><small>${sub}</small></div>
      <span class="v">${typeof x.v === 'number' ? (b.kind === 'pvp_ratio' ? x.v.toFixed(2) : lgNum(x.v)) : esc(x.v)}<small>${unit}</small></span>
    </div>`; }).join('')}
    ${r.pages > 1 ? `<div class="lgp-pager"><button ${r.page <= 1 ? 'disabled' : ''} data-lg-page="-1">‹</button><span>${r.page} / ${r.pages}</span><button ${r.page >= r.pages ? 'disabled' : ''} data-lg-page="1">›</button></div>` : ''}`;
  $$('[data-lg-page]', box).forEach(x => x.onclick = () => { b.page = Math.max(1, b.page + +x.dataset.lgPage); lgBoard(); });
}

/* ---------------------------------------------------------
   Demandes de match (PVP) et annonces programmées
   --------------------------------------------------------- */
async function lgPosts(kind) {
  const ev = kind === 'event';
  const main = lgShell(`
    <div class="lgp-intro ${ev ? 'ev' : ''}">
      <div><b>${ev ? t('Annonces') : t('Demandes de match')}</b>
      <p>${ev ? t('Une heure, une carte : rejoins et un point GPS t\'emmène au LaserGame.') : t('Trouve des adversaires pour la PVP Arena. Écris à l\'auteur ou rejoins.')}</p></div>
      <button class="lgp-btn" data-lg-new>${lgSvg(LGI.plus)}${ev ? t('Annoncer') : t('Demander')}</button>
    </div>
    <div class="lgp-list">${lgLoading()}</div>`);
  $('[data-lg-new]', main).onclick = () => lgForm(kind);
  const r = await lgCall('posts', { kind });
  if (S.currentApp !== 'lasergame' || LG.tab !== kind) return;
  const box = $('.lgp-list', main);
  if (!r || !r.ok) { box.innerHTML = lgEmpty(t('Indisponible'), esc((r && r.error) || '')); return; }
  if (!r.posts.length) {
    box.innerHTML = lgEmpty(ev ? t('Aucune annonce') : t('Aucune demande'), ev ? t('Programme la prochaine soirée Zombie ou PVP.') : t('Lance la première demande de match.'),
      `<button class="lgp-btn" data-lg-new2>${lgSvg(LGI.plus)}${ev ? t('Créer une annonce') : t('Demander un match')}</button>`);
    $('[data-lg-new2]', box).onclick = () => lgForm(kind);
    return;
  }
  box.innerHTML = r.posts.map(lgCard).join('');
  wirePosts(box, r.posts, kind);
}

function lgCard(p) {
  const zb = p.mode === 'zombie', ev = p.kind === 'event';
  const slots = p.slots > 0 ? `${p.count}/${p.slots}` : `${p.count}`;
  const time = p.startsAt > 0;
  return `<article class="lgp-card ${zb ? 'zb' : 'pvp'} ${p.joined ? 'joined' : ''} ${p.mine ? 'mine' : ''}" data-id="${p.id}">
    <div class="lgp-card__map" style="background-image:url('${LG_ASSETS}images/maps/${esc(p.map || (zb ? 'zombie_map' : 'pvp_medium'))}.png')"><i></i>
      <span class="mode">${zb ? `${lgSvg(LGI.skull)}ZOMBIE` : `PVP ${esc(p.formatLabel || p.format || '')}`}</span>
      ${time ? `<span class="hour"><b>${lgHM(p.startsAt)}</b><small>${esc(lgIn(p.startsAt))}</small></span>` : `<span class="hour now"><b>${t('MAINTENANT')}</b><small>${t('dès que possible')}</small></span>`}
    </div>
    <div class="lgp-card__body">
      <div class="by">${avatar(p.author, p.authorToken, 'lgp-av')}<div><b>${esc(p.author)}${p.mine ? ` <em>${t('toi')}</em>` : ''}</b><small>${esc(p.when)} · ${timeAgo(p.created)}</small></div></div>
      <div class="meta">
        <span>${lgSvg(LGI.map)}${esc(p.mapLabel)}</span>
        <span>${lgSvg(LGI.users)}${slots} ${t('inscrit(s)')}${p.full ? ` · <b>${t('complet')}</b>` : ''}</span>
        ${p.stake > 0 ? `<span class="gold">${lgSvg(LGI.coin)}${t('Mise {m}', { m: money(p.stake) })}</span>` : ''}
      </div>
      ${p.message ? `<p class="txt">${esc(p.message)}</p>` : ''}
      ${p.players.length ? `<p class="who">${p.players.slice(0, 6).map(n => `<span>${esc(n)}</span>`).join('')}${p.players.length > 6 ? `<span>+${p.players.length - 6}</span>` : ''}</p>` : ''}
      <div class="act">
        ${p.mine ? `<button class="lgp-btn ghost" data-lg-gpsp>${lgSvg(LGI.gps)}${t('GPS')}</button>`
          : p.joined ? `<button class="lgp-btn ok" data-lg-join>${lgSvg(LGI.gps)}${t('GPS')}</button><button class="lgp-btn ghost" data-lg-leave>${t('Je ne viens plus')}</button>`
          : `<button class="lgp-btn" data-lg-join ${p.full ? 'disabled' : ''}>${lgSvg(LGI.gps)}${t('Rejoindre')}</button>`}
        ${!p.mine ? `<button class="lgp-btn ghost" data-lg-write>${lgSvg(LGI.msg)}${t('Message')}</button>` : ''}
        ${p.canCancel ? `<button class="lgp-btn danger" data-lg-cancel aria-label="${t('Retirer')}">${lgSvg(LGI.trash)}</button>` : ''}
      </div>
    </div>
  </article>`;
}

function wirePosts(box, posts, kind) {
  const byId = (el) => posts.find(p => p.id === +el.closest('[data-id]').dataset.id);
  $$('[data-lg-join], [data-lg-gpsp]', box).forEach(b => b.onclick = async () => {
    b.disabled = true;
    const r = await lgCall('join', { id: byId(b).id });
    if (r && r.gps) lgGps(r.gps);
    lgToast(r);
    if (S.currentApp === 'lasergame' && LG.tab === kind) lgPosts(kind);
  });
  $$('[data-lg-leave]', box).forEach(b => b.onclick = async () => { const r = await lgCall('leave', { id: byId(b).id }); lgToast(r); lgPosts(kind); });
  $$('[data-lg-write]', box).forEach(b => b.onclick = () => { const p = byId(b); lgCompose(p); });
  $$('[data-lg-cancel]', box).forEach(b => b.onclick = () => {
    const p = byId(b);
    openSheet(t('Retirer cette annonce ?'), `<p class="lgp-sheet-p">${t('Les joueurs inscrits seront prévenus.')}</p>
      <div class="lgp-sheet-act"><button class="lgp-btn ghost" data-no>${t('Annuler')}</button><button class="lgp-btn danger" data-yes>${t('Retirer')}</button></div>`, (sh) => {
      sh.classList.add('lgp-sheet');
      $('[data-no]', sh).onclick = () => closeSheet();
      $('[data-yes]', sh).onclick = async () => { closeSheet(); const r = await lgCall('cancel', { id: p.id }); lgToast(r); lgPosts(kind); };
    });
  });
}

// Écrire à l'auteur d'une annonce (message rattaché à l'annonce)
function lgCompose(p) {
  const max = LG.home.limits?.message || 300;
  openSheet(t('Message à {n}', { n: esc(p.author) }), `
    <p class="lgp-sheet-p">${p.mode === 'zombie' ? 'Zombie' : 'PVP ' + esc(p.format)} · ${esc(p.mapLabel)} · ${esc(p.when)}</p>
    <textarea class="lgp-in" rows="3" maxlength="${max}" placeholder="${t('Ex. : Partant, on se rejoint au LaserGame ?')}"></textarea>
    <div class="lgp-sheet-act"><button class="lgp-btn ghost" data-no>${t('Annuler')}</button><button class="lgp-btn" data-yes>${lgSvg(LGI.send)}${t('Envoyer')}</button></div>`, (sh) => {
    sh.classList.add('lgp-sheet');
    const ta = $('textarea', sh);
    ta.value = p.mode === 'zombie' ? t('Je suis partant pour la Zombie, on se rejoint au LaserGame ?') : t('Partant pour ton match, on se rejoint au LaserGame ?');
    $('[data-no]', sh).onclick = () => closeSheet();
    $('[data-yes]', sh).onclick = async () => {
      const r = await lgCall('send', { token: p.authorToken, post: p.id, body: ta.value });
      if (!r || !r.ok) return lgToast(r);
      closeSheet();
      LG.thread = { token: r.token, name: r.name };
      lgOpen('msg', LG.thread);
    };
  });
}

// Formulaire : demande de match (PVP) ou annonce programmée (Zombie / PVP)
function lgForm(kind) {
  const h = LG.home, ev = kind === 'event';
  const st = { mode: ev ? 'zombie' : 'pvp', format: (h.formats[1] || h.formats[0] || {}).id, map: '', when: ev ? 'at' : 'now', day: 0, time: '', slots: 4, stake: 0, message: '' };
  const d = new Date(Date.now() + 30 * 60000); d.setMinutes(Math.ceil(d.getMinutes() / 15) * 15);
  st.time = `${pad(d.getHours() % 24)}:${pad(d.getMinutes() % 60)}`;
  const render = (sh) => {
    const maps = h.maps.filter(m => m.mode === st.mode);
    sh.innerHTML = `<h2 class="sheet__title">${ev ? t('Nouvelle annonce') : t('Demande de match PVP')}</h2>
      ${ev ? `<label class="lgp-lab">${t('Mode')}</label><div class="lgp-chips big">
        ${h.zombie ? `<button class="${st.mode === 'zombie' ? 'on' : ''}" data-f-mode="zombie">${lgSvg(LGI.skull)}Zombie</button>` : ''}
        ${h.pvp ? `<button class="${st.mode === 'pvp' ? 'on' : ''}" data-f-mode="pvp">PVP Arena</button>` : ''}</div>` : ''}
      ${st.mode === 'pvp' ? `<label class="lgp-lab">${t('Format')}</label><div class="lgp-chips">${h.formats.map(f => `<button class="${st.format === f.id ? 'on' : ''}" data-f-format="${f.id}">${esc(f.label)}</button>`).join('')}</div>`
        : `<label class="lgp-lab">${t('Joueurs (toi compris)')}</label><div class="lgp-chips">${[1, 2, 3, 4].map(n => `<button class="${st.slots === n ? 'on' : ''}" data-f-slots="${n}">${n}</button>`).join('')}</div>`}
      <label class="lgp-lab">${t('Carte')}</label>
      <div class="lgp-maps">${(st.mode === 'pvp' ? [{ id: '', label: t('Au choix') }] : []).concat(maps).map(m => `<button class="${st.map === m.id ? 'on' : ''}" data-f-map="${esc(m.id)}"
        style="background-image:url('${LG_ASSETS}images/maps/${esc(m.id || 'pvp_medium')}.png')"><span>${esc(m.label)}</span></button>`).join('')}</div>
      <label class="lgp-lab">${t('Quand')}</label>
      ${ev ? '' : `<div class="lgp-chips"><button class="${st.when === 'now' ? 'on' : ''}" data-f-when="now">${t('Dès que possible')}</button><button class="${st.when === 'at' ? 'on' : ''}" data-f-when="at">${t('À une heure')}</button></div>`}
      ${st.when === 'at' ? `<div class="lgp-when"><div class="lgp-chips">${[[0, t('Aujourd\'hui')], [1, t('Demain')], [2, t('Après-demain')]].map(([k, l]) => `<button class="${st.day === k ? 'on' : ''}" data-f-day="${k}">${l}</button>`).join('')}</div>
        <input class="lgp-in time" type="time" value="${st.time}" data-f-time></div>` : ''}
      ${st.mode === 'pvp' && h.stake?.enabled ? `<label class="lgp-lab">${t('Mise proposée (facultatif)')}</label>
        <input class="lgp-in" type="number" min="0" max="${h.stake.max}" step="${h.stake.step || 100}" value="${st.stake || ''}" placeholder="0" data-f-stake>` : ''}
      <label class="lgp-lab">${t('Message')}</label>
      <textarea class="lgp-in" rows="2" maxlength="${h.limits?.text || 160}" placeholder="${ev ? t('Ex. : Soirée survie, on vise la manche 20 !') : t('Ex. : Équipe de 2 cherche adversaires')}" data-f-msg>${esc(st.message)}</textarea>
      <p class="lgp-note">${lgSvg(LGI.gps)}${t('Rejoindre pose un point GPS vers le LaserGame : personne n\'est téléporté.')}</p>
      <div class="lgp-sheet-act"><button class="lgp-btn ghost" data-no>${t('Annuler')}</button><button class="lgp-btn" data-yes>${ev ? t('Publier l\'annonce') : t('Publier la demande')}</button></div>`;
    const keep = () => {
      const ti = $('[data-f-time]', sh); if (ti) st.time = ti.value;
      const sk = $('[data-f-stake]', sh); if (sk) st.stake = +sk.value || 0;
      st.message = $('[data-f-msg]', sh).value;
    };
    const set = (k, v) => { keep(); st[k] = v; if (k === 'mode') st.map = ''; render(sh); };
    $$('[data-f-mode]', sh).forEach(b => b.onclick = () => set('mode', b.dataset.fMode));
    $$('[data-f-format]', sh).forEach(b => b.onclick = () => set('format', b.dataset.fFormat));
    $$('[data-f-slots]', sh).forEach(b => b.onclick = () => set('slots', +b.dataset.fSlots));
    $$('[data-f-map]', sh).forEach(b => b.onclick = () => set('map', b.dataset.fMap));
    $$('[data-f-when]', sh).forEach(b => b.onclick = () => set('when', b.dataset.fWhen));
    $$('[data-f-day]', sh).forEach(b => b.onclick = () => set('day', +b.dataset.fDay));
    $('[data-no]', sh).onclick = () => closeSheet();
    $('[data-yes]', sh).onclick = async () => {
      keep();
      let startsAt = 0;
      if (st.when === 'at') {
        const [hh, mm] = (st.time || '').split(':').map(Number);
        if (isNaN(hh) || isNaN(mm)) return lgToast({ error: t('Choisis une heure.') });
        const x = new Date(); x.setDate(x.getDate() + st.day); x.setHours(hh, mm, 0, 0);
        startsAt = Math.floor(x.getTime() / 1000);
        if (startsAt < Date.now() / 1000 - 60) return lgToast({ error: t('Cette heure est déjà passée : choisis « Demain ».') });
      }
      const btn = $('[data-yes]', sh); btn.disabled = true;
      const r = await lgCall('create', { kind, mode: st.mode, format: st.format, map: st.map, slots: st.slots, stake: st.stake, startsAt, message: st.message });
      btn.disabled = false;
      lgToast(r);
      if (r && r.ok) { closeSheet(); lgPosts(kind); }
    };
  };
  openSheet('', '', (sh) => { sh.classList.add('lgp-sheet', 'lgp-form'); render(sh); });
}

/* ---------------------------------------------------------
   Messages
   --------------------------------------------------------- */
async function lgMessages(params = {}) {
  if (params.token) LG.thread = { token: params.token, name: params.name };
  if (LG.thread) return lgThread();
  const main = lgShell(`<div class="lgp-threads">${lgLoading()}</div>`);
  const r = await lgCall('threads');
  if (S.currentApp !== 'lasergame' || LG.tab !== 'msg' || LG.thread) return;
  const box = $('.lgp-threads', main);
  if (!r || !r.ok) { box.innerHTML = lgEmpty(t('Messages indisponibles'), esc((r && r.error) || '')); return; }
  LG.home.unread = r.unread || 0; S.lgBadge = LG.home.unread;
  if (!r.threads.length) { box.innerHTML = lgEmpty(t('Aucun message'), t('Écris à un joueur depuis une demande de match ou une annonce pour vous retrouver au LaserGame.')); return; }
  box.innerHTML = r.threads.map(th => `<button class="lgp-th ${th.unread ? 'new' : ''}" data-tok="${esc(th.token)}" data-nm="${esc(th.name)}">
    ${avatar(th.name, th.token, 'lgp-av')}<div class="tx"><b>${esc(th.name)}</b><small>${th.mine ? t('Toi : ') : ''}${esc(th.last)}</small></div>
    <div class="rt"><small>${timeAgo(th.at)}</small>${th.unread ? `<i>${th.unread}</i>` : ''}</div></button>`).join('');
  $$('[data-tok]', box).forEach(b => b.onclick = () => { LG.thread = { token: b.dataset.tok, name: b.dataset.nm }; setParams({ tab: 'msg', token: b.dataset.tok, name: b.dataset.nm }); lgThread(); });
}

async function lgThread() {
  const th = LG.thread, max = LG.home.limits?.message || 300;
  const main = lgShell(`<div class="lgp-chat">
      <div class="lgp-chat__head"><button class="lgp-ib sm" data-lg-out>${lgSvg(LGI.back)}</button>${avatar(th.name || '?', th.token, 'lgp-av')}<b>${esc(th.name || '')}</b></div>
      <div class="lgp-chat__list">${lgLoading()}</div>
      <form class="lgp-chat__in"><input class="lgp-in" maxlength="${max}" placeholder="${t('Message…')}" autocomplete="off"><button class="lgp-send" aria-label="${t('Envoyer')}">${lgSvg(LGI.send)}</button></form>
    </div>`, { sub: '' });
  $('[data-lg-out]', main).onclick = () => { LG.thread = null; setParams({ tab: 'msg' }); lgMessages(); };
  const list = $('.lgp-chat__list', main);
  const load = async () => {
    const r = await lgCall('thread', { token: th.token });
    if (S.currentApp !== 'lasergame' || LG.thread !== th) return;
    if (!r || !r.ok) { list.innerHTML = lgEmpty(t('Conversation indisponible'), esc((r && r.error) || '')); return; }
    th.name = r.name; $('.lgp-chat__head b', main).textContent = r.name;
    LG.home.unread = r.unread || 0; S.lgBadge = LG.home.unread;
    const dot = $('[data-lg-tab="msg"] .dot', appView); if (dot && !LG.home.unread) dot.remove();
    list.innerHTML = r.messages.length ? r.messages.map(m => `<div class="lgp-bub ${m.mine ? 'me' : ''}">${m.post ? `<small class="ref">${t('À propos d\'une annonce')}</small>` : ''}${esc(m.body)}<time>${timeAgo(m.at)}</time></div>`).join('')
      : `<p class="lgp-chat__hint">${t('Proposez-vous un rendez-vous au LaserGame : le bouton GPS en haut vous y guide.')}</p>`;
    list.scrollTop = list.scrollHeight;
  };
  LG.reloadThread = load;
  await load();
  const form = $('.lgp-chat__in', main), inp = $('input', form);
  form.onsubmit = async (e) => {
    e.preventDefault();
    const body = inp.value.trim();
    if (!body || LG.sending) return;
    LG.sending = true;
    const r = await lgCall('send', { token: th.token, body });
    LG.sending = false;
    if (!r || !r.ok) return lgToast(r);
    inp.value = '';
    load();
  };
}

// Message reçu pendant que l'appli est ouverte : la conversation ou la liste se met à jour
function lgOnNotify(d) {
  if (d.app !== 'lasergame') return;
  const isMsg = /·/.test(d.title || '');
  if (isMsg) S.lgBadge = (S.lgBadge || 0) + 1;
  if (S.currentApp !== 'lasergame' || !LG.home) return;
  if (isMsg) {
    LG.home.unread = (LG.home.unread || 0) + 1;
    if (LG.tab === 'msg' && LG.thread && LG.reloadThread) LG.reloadThread();
    else if (LG.tab === 'msg') lgMessages();
  }
}
