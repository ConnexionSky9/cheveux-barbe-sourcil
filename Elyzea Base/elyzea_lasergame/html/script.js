/* =====================================================================
   ELYZEA LASERGAME · INTERFACE (NUI)
   Menu (accueil, PVP, classements, profil, historique, paramètres, staff),
   lobbies, HUD de partie, chargement, résultats, invites, notifications, sons.
   Hors FiveM (navigateur), un mode démo avec des données fictives permet de tester l'interface :
   index.html?demo=home | pvp | create | lobby | ranks | profile | history | admin | arenas | hud-pvp | results | loading
   ===================================================================== */
'use strict';
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'elyzea_lasergame';
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
const money = (n) => `${fmt(n)} $`;
const dateFr = (ts) => ts ? new Date(ts * 1000).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—';

const S = { init: null, tab: 'home', sub: {}, lobby: null, list: [], settings: { volume: 0.7, effects: true, hudScale: 1 }, admin: null, adminTab: 'games',
  lb: { kind: 'pvp_points', page: 1, data: null }, create: {}, hud: null, timer: null, lbTimer: null };

/* ------------------------------------------------------------------ communication */
async function post(name, data) {
  if (!IN_GAME) return Demo.post(name, data);
  try {
    const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}) });
    return await r.json();
  } catch (e) { return null; }
}
async function rpc(name, ...args) {
  const r = await post('rpc', { name, args });
  if (!r) return { ok: false, err: 'Pas de réponse.' };
  if (!r.ok && r.err) toast(typeof r.err === 'string' ? r.err : 'Erreur.', 'error');
  return r;
}

/* ------------------------------------------------------------------ sons */
const Snd = {
  cache: {},
  play(name, vol) {
    try {
      const v = Math.max(0, Math.min(1, vol ?? S.settings.volume));
      if (v <= 0.01) return;
      let pool = this.cache[name];
      if (!pool) { pool = this.cache[name] = []; }
      let a = pool.find((x) => x.paused || x.ended);
      if (!a) { if (pool.length >= 6) a = pool[0]; else { a = new Audio(`sounds/${name}.ogg`); pool.push(a); } }
      a.volume = v; a.currentTime = 0; a.play().catch(() => {});
    } catch (e) { /* son indisponible */ }
  },
};
document.addEventListener('mouseover', (e) => { const b = e.target.closest('button, .mapcard, .weapon, .mode, .gamerow'); if (b && !b.dataset.hov) { b.dataset.hov = 1; Snd.play('hover', S.settings.volume * 0.35); setTimeout(() => delete b.dataset.hov, 120); } });
document.addEventListener('click', (e) => { if (e.target.closest('button, .mapcard, .weapon, .mode')) Snd.play('click', S.settings.volume * 0.6); });

/* ------------------------------------------------------------------ icônes */
const I = {
  home: '<path d="M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
  pvp: '<path d="M4 4l7 7-2 2-7-7V4zm16 0v2l-9 9-2-2 9-9h2zM6 14l4 4-2 2-1-1-2 2-2-2 2-2-1-1 2-2zm12 0l2 2-1 1 2 2-2 2-2-2-1 1-2-2 4-4z"/>',
  ranks: '<path d="M7 3h10v3a5 5 0 0 1-4 4.9V14h3v3H8v-3h3v-3.1A5 5 0 0 1 7 6zM3 4h3v3a3 3 0 0 1-3-3zm15 0h3a3 3 0 0 1-3 3zM6 19h12v2H6z"/>',
  profile: '<path d="M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10zm0 2c-5 0-9 2.5-9 5.5V22h18v-2.5c0-3-4-5.5-9-5.5z"/>',
  history: '<path d="M13 3a9 9 0 1 0 8.5 12h-2.1A7 7 0 1 1 13 5V2l4 4-4 4V7zm-1 4h2v5l4 2-1 1.7-5-3z"/>',
  settings: '<path d="M19.4 13a7.5 7.5 0 0 0 0-2l2.1-1.6-2-3.5-2.5 1a7 7 0 0 0-1.7-1L15 3h-4l-.4 2.9a7 7 0 0 0-1.7 1l-2.5-1-2 3.5L6.6 11a7.5 7.5 0 0 0 0 2l-2.1 1.6 2 3.5 2.5-1a7 7 0 0 0 1.7 1L11 21h4l.4-2.9a7 7 0 0 0 1.7-1l2.5 1 2-3.5zM13 15.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z"/>',
  arena: '<path d="M3 5l6-2 6 2 6-2v16l-6 2-6-2-6 2zm6 0v14m6-12v14" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>',
  staff: '<path d="M12 2l8 3v6c0 5-3.4 9.4-8 11-4.6-1.6-8-6-8-11V5zm-1 13l6-6-1.4-1.4L11 12.2 8.4 9.6 7 11z"/>',
  // atouts
};
const svg = (name, size = 18) => `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="currentColor">${I[name] || ''}</svg>`;
const rankImg = (id, cls = 'rk') => `<img class="${cls}" src="ranks/${esc(id || 'bronze')}.png" alt="">`;
const rankOf = (id) => (S.init?.ranks || []).find((r) => r.id === id) || { label: 'ELYZEA BRONZE', color: '#C98A55' };
const mapOf = (id) => (S.init?.maps || []).find((m) => m.id === id) || { label: id };
// Silhouette d'une arène (zone vue du dessus + apparitions des deux équipes), coordonnées 0..100
function shapeSvg(sh) {
  if (!sh || !sh.poly || sh.poly.length < 3) return '<svg viewBox="0 0 100 100"><text x="50" y="54" text-anchor="middle" fill="rgba(255,255,255,.5)" font-size="9" font-family="Manrope">zone à dessiner</text></svg>';
  const pts = sh.poly.map(([x, y]) => `${x},${y}`).join(' ');
  const dots = (list, c) => (list || []).map(([x, y]) => `<circle cx="${x}" cy="${y}" r="2.6" fill="${c}" stroke="#fff" stroke-width=".6"/>`).join('');
  return `<svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet"><polygon points="${pts}" fill="rgba(155,92,255,.22)" stroke="#B57BFF" stroke-width="1.6" stroke-linejoin="round"/>${dots(sh.A, '#FF2D46')}${dots(sh.B, '#288CFF')}</svg>`;
}
const catLabel = (id) => (S.init?.categories || []).find((c) => c.id === id)?.label || id;

/* ------------------------------------------------------------------ notifications */
function toast(text, kind = 'info') {
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.innerHTML = `<i></i><span>${esc(text)}</span>`;
  $('#toasts').appendChild(el);
  Snd.play(kind === 'error' ? 'deny' : 'toast', S.settings.volume * 0.6);
  setTimeout(() => el.remove(), 4800);
}

/* ------------------------------------------------------------------ menu principal */
const TABS = [
  ['home', 'ACCUEIL', 'Bienvenue au complexe'], ['pvp', 'PVP ARENA', 'Laser compétitif 1v1 → 6v6'],
  ['ranks', 'CLASSEMENTS', 'Les meilleurs d\'ElyzeaFA'], ['profile', 'MON PROFIL', 'Rang et statistiques'], ['history', 'HISTORIQUE', 'Tes dernières parties'],
  ['settings', 'PARAMÈTRES', 'Son, effets, HUD'],
];

function renderNav() {
  const tabs = TABS.map(([id, label]) => `<button data-tab="${id}" class="${S.tab === id ? 'active' : ''}">${svg(id)}${label}</button>`).join('');
  const staff = S.init?.isAdmin ? `<div class="sep"></div><button data-tab="admin" class="staff ${S.tab === 'admin' ? 'active' : ''}">${svg('staff')}STAFF</button>` : '';
  $('#nav').innerHTML = tabs + staff;
  const p = S.init?.profile || {};
  const r = rankOf(p.rank);
  $('#mecard').innerHTML = `${rankImg(p.rank, '')}<div><div class="n">${esc(S.init?.me?.name || '')}</div><div class="r" style="color:${r.color}">${esc(r.label)}</div><div class="p">${fmt(p.points)} pts</div></div>`;
}

function setTitle(id) {
  const t = TABS.find((x) => x[0] === id) || ['admin', 'ESPACE STAFF', 'Administration du LaserGame'];
  const el = $('#title');
  el.dataset.text = t[1];
  el.innerHTML = `<small>${esc(t[2])}</small>${esc(t[1])}`;
  el.classList.remove('go'); void el.offsetWidth; el.classList.add('go');
}

// glitch occasionnel sur le titre de la page (si les effets sont activés)
function glitchNow(el) { if (!el || !S.settings.effects) return; el.classList.remove('go'); void el.offsetWidth; el.classList.add('go'); Snd.play('glitch', S.settings.volume * 0.25); }
setInterval(() => { if (!$('#app').classList.contains('hidden')) glitchNow($('#title')); }, 9000);

function go(tab, sub) {
  S.tab = tab;
  if (sub) S.sub[tab] = sub;
  renderNav();
  setTitle(tab);
  render();
}

function render() {
  const p = $('#page');
  p.style.animation = 'none'; void p.offsetWidth; p.style.animation = '';
  clearInterval(S.lbTimer);
  const fn = { home: pageHome, pvp: pagePvp, ranks: pageRanks, profile: pageProfile, history: pageHistory, settings: pageSettings, admin: pageAdmin }[S.tab] || pageHome;
  fn(p);
}

/* ---------------- ACCUEIL */
function gameRow(g) {
  const run = g.phase !== 'lobby';
  const mode = `<span class="chip">${esc(g.format)}</span>`;
  const score = run ? `<span class="score"><span class="a">${g.score?.A ?? 0}</span> — <span class="b">${g.score?.B ?? 0}</span></span>` : '';
  const action = run
    ? (S.init?.spectator ? `<button class="btn sm ghost" data-spec="${g.uid}">Regarder</button>` : '')
    : `<button class="btn sm" data-join="${g.uid}" data-pw="${g.hasPassword ? 1 : 0}">Rejoindre</button>`;
  return `<div class="gamerow"><span class="dot ${run ? 'run' : ''}"></span>${mode}
    <div class="sp"><div class="nm">${esc(g.name)} ${g.hasPassword ? '🔒' : ''} ${g.ranked ? '<span class="chip warn">CLASSÉE</span>' : ''}</div>
    <div class="meta">${esc(g.mapLabel)} · ${g.players}/${g.max} joueurs${g.stake ? ' · mise ' + money(g.stake) : ''}${run ? ' · en cours' : ' · en attente'}${g.spectators ? ` · ${g.spectators} 👁` : ''}</div></div>
    ${score}${action}</div>`;
}

function pageHome(p) {
  const pr = S.init.profile;
  const r = rankOf(pr.rank);
  const running = S.list.filter((g) => g.phase !== 'lobby');
  const open = S.list.filter((g) => g.phase === 'lobby');
  p.innerHTML = `
  <div class="hero"><i class="laser-line r"></i><i class="laser-line b"></i>
    <div class="t2 muted" style="letter-spacing:.4em;font-weight:800;font-size:11px">COMPLEXE LASERGAME · ELYZEA FA</div>
    <h1>LASER<b>GAME</b><br>ELYZEA</h1>
    <p>Deux équipes, des lasers, aucune seconde chance. Affronte les meilleurs de la ville en PVP classé, de 1 VS 1 à 6 VS 6, dans les arènes du complexe.</p>
    <div class="row"><button class="btn red" data-tab="pvp">${svg('pvp')}PVP ARENA</button><button class="btn ghost" data-tab="pvp" data-sub="quick">MATCHMAKING RAPIDE</button></div>
  </div>
  <div class="grid g2" style="margin-top:16px">
    <div class="mode pvp" data-tab="pvp"><span class="chip">${S.init.pvp.enabled ? 'OUVERT' : 'FERMÉ'}</span><h2><span>PVP</span> <em>ARENA</em></h2><div class="muted">1v1 à 6v6 · mises · 8 rangs · parties en instance privée</div></div>
    <div class="mode arena" data-tab="pvp" data-sub="create"><span class="chip">${S.init.maps.length} ARÈNE${S.init.maps.length > 1 ? 'S' : ''}</span><h2>LES ARÈNES</h2><div class="muted">${S.init.maps.length ? S.init.maps.slice(0, 4).map((m) => esc(m.label)).join(' · ') : 'Aucune arène ouverte pour le moment'}</div></div>
  </div>
  <div class="grid g3" style="margin-top:16px;grid-template-columns:1.2fr 1fr 1fr">
    <div class="card holo"><h3>Matchs en direct</h3><div class="live">${running.length ? running.slice(0, 5).map(gameRow).join('') : '<div class="empty">Aucune partie en cours.</div>'}</div></div>
    <div class="card holo"><h3>Lobbies ouverts</h3><div class="live">${open.length ? open.slice(0, 5).map(gameRow).join('') : '<div class="empty">Aucun lobby : crée le tien !</div>'}</div></div>
    <div class="card holo" style="text-align:center">${rankImg(pr.rank, '')}<style>.card img{width:120px}</style>
      <div class="rankname" style="font-size:20px;color:${r.color}">${esc(r.label)}</div><div class="muted">${fmt(pr.points)} points${pr.position ? ' · #' + pr.position : ''}</div>
      <div class="bar" style="margin:12px 0 6px"><i style="width:${Math.round((pr.progress || 0) * 100)}%"></i></div>
      <div class="small muted">${pr.next ? `Prochain rang : ${esc(pr.next.label)} (${fmt(pr.next.min)})` : 'Rang maximum atteint'}</div>
      <div class="grid g3" style="margin-top:12px"><div class="stat"><div class="v">${pr.wins}</div><div class="l">Victoires</div></div><div class="stat"><div class="v">${pr.ratio}</div><div class="l">Ratio</div></div><div class="stat"><div class="v">${pr.matches}</div><div class="l">Matchs</div></div></div>
    </div>
  </div>`;
}

/* ---------------- PVP */
function pagePvp(p) {
  if (S.lobby && S.lobby.mode === 'pvp') return renderPvpLobby(p);
  const sub = S.sub.pvp || 'list';
  if (!S.init.pvp.enabled) { p.innerHTML = '<div class="empty">Le mode PVP est fermé par le staff.</div>'; return; }
  const tabs = `<div class="tabs">${[['list', 'Parties'], ['quick', 'Matchmaking'], ['create', 'Créer une partie']].map(([id, l]) => `<button data-sub="${id}" class="${sub === id ? 'on' : ''}">${l}</button>`).join('')}</div>`;
  if (sub === 'list') {
    const games = S.list.filter((g) => g.mode === 'pvp');
    p.innerHTML = tabs + `<div class="card holo"><h3>Parties PVP</h3><div class="live">${games.length ? games.map(gameRow).join('') : '<div class="empty">Aucune partie. Lance un matchmaking ou crée la tienne.</div>'}</div></div>`;
  } else if (sub === 'quick') {
    const q = S.sub.quickFormat || '2v2';
    p.innerHTML = tabs + `<div class="card holo"><h3>Matchmaking rapide</h3>
      <p class="muted">Rejoins automatiquement la partie publique la plus remplie de ce format, ou ouvre-en une nouvelle.</p>
      <div class="field"><label>Format</label><div class="seg" id="qf">${S.init.pvp.formats.map((f) => `<button data-qf="${f.id}" class="${q === f.id ? 'on' : ''}">${esc(f.label)}</button>`).join('')}</div></div>
      ${S.init.stake.enabled ? `<div class="field" style="margin-top:14px"><label>Mise par joueur</label><input class="input" id="qstake" type="number" min="0" step="${S.init.stake.step}" value="${S.sub.quickStake || 0}" style="max-width:220px"></div>` : ''}
      <div class="row" style="margin-top:18px"><button class="btn" data-act="quick">Lancer la recherche</button></div></div>`;
  } else {
    if (!S.init.maps.length) { p.innerHTML = tabs + '<div class="card holo"><div class="empty">Aucune arène ouverte pour le moment : le staff doit en créer une.</div></div>'; return; }
    const c = Object.assign({ format: '2v2', map: S.init.maps[0].id, rounds: S.init.pvp.defaultRounds, roundTime: S.init.pvp.defaultRoundTime,
      category: 'rifle', stake: 0, private: false, password: '', name: '' }, S.create);
    if (!S.init.maps.some((m) => m.id === c.map)) c.map = S.init.maps[0].id;
    S.create = c;
    p.innerHTML = tabs + `<div class="card holo"><h3>Nouvelle partie</h3>${createForm(c)}<div class="row" style="margin-top:18px"><button class="btn" data-act="create">Créer le lobby</button></div></div>`;
  }
}

function createForm(c) {
  const maps = S.init.maps;
  return `<div class="grid g2">
    <div class="field"><label>Nom du match</label><input class="input" data-c="name" maxlength="28" value="${esc(c.name)}" placeholder="Partie de ${esc(S.init.me.firstname)}"></div>
    <div class="field"><label>Format</label><div class="seg">${S.init.pvp.formats.map((f) => `<button data-cs="format" data-v="${f.id}" class="${c.format === f.id ? 'on' : ''}">${esc(f.label)}</button>`).join('')}</div></div>
  </div>
  <div class="field" style="margin-top:14px"><label>Arène</label><div class="mapcards">${maps.map((m) => `<div class="mapcard ${c.map === m.id ? 'on' : ''}" data-cs="map" data-v="${esc(m.id)}"><div class="pv">${shapeSvg(m.shape)}</div><div>${esc(m.label)} <span class="chip" style="float:right">${esc(m.size)}</span><small>jusqu'à ${m.maxPerTeam} VS ${m.maxPerTeam}${m.description ? ' · ' + esc(m.description) : ''}</small></div></div>`).join('')}</div></div>
  <div class="grid g3" style="margin-top:14px">
    <div class="field"><label>Manches</label><div class="seg">${S.init.pvp.rounds.map((r) => `<button data-cs="rounds" data-v="${r}" class="${c.rounds == r ? 'on' : ''}">${r}</button>`).join('')}</div></div>
    <div class="field"><label>Durée d'une manche</label><div class="seg">${S.init.pvp.roundTimes.map((r) => `<button data-cs="roundTime" data-v="${r}" class="${c.roundTime == r ? 'on' : ''}">${r >= 60 ? (r / 60) + ' min' : r + ' s'}</button>`).join('')}</div></div>
    <div class="field"><label>Catégorie d'arme</label><div class="seg">${S.init.categories.map((k) => `<button data-cs="category" data-v="${k.id}" class="${c.category === k.id ? 'on' : ''}">${esc(k.label)}</button>`).join('')}</div></div>
  </div>
  <div class="grid g3" style="margin-top:14px">
    ${S.init.stake.enabled ? `<div class="field"><label>Mise par joueur (${money(S.init.stake.min)} – ${money(S.init.stake.max)})</label><input class="input" data-c="stake" type="number" min="${S.init.stake.min}" max="${S.init.stake.max}" step="${S.init.stake.step}" value="${c.stake}"></div>` : '<div></div>'}
    <div class="field"><label>Visibilité</label><div class="row"><div class="toggle ${c.private ? 'on' : ''}" data-ct="private"></div><span>${c.private ? 'Privée (invitation / mot de passe)' : 'Publique'}</span></div></div>
    <div class="field"><label>Mot de passe (facultatif)</label><input class="input" data-c="password" maxlength="16" value="${esc(c.password)}" placeholder="Aucun"></div>
  </div>
  <div class="small muted" style="margin-top:10px">${c.private ? (S.init.pvp.ranked.private ? 'Partie classée.' : 'Les parties privées ne comptent pas au classement.') : 'Partie publique classée (si elle dure assez longtemps).'}</div>`;
}

function renderPvpLobby(p) {
  const L = S.lobby;
  const me = [...L.teams.A, ...L.teams.B].find((x) => x.me) || {};
  const slots = (team) => {
    const list = L.teams[team];
    let h = list.map((x, i) => `<div class="slot ${x.me ? 'me' : ''}" style="animation-delay:${i * 60}ms">${rankImg(x.rank)}<div class="nm">${esc(x.name)} ${x.host ? '👑' : ''}</div>
      <span class="small muted">${esc((L.weapons.find((w) => w.id === x.weapon) || {}).label || '')}</span>
      <span class="rdy ${x.ready ? 'on' : ''}">${x.ready ? 'PRÊT' : 'ATTENTE'}</span>
      ${L.isHost && !x.me ? `<button class="btn sm ghost" data-kick="${x.id}" title="Expulser">✕</button>` : ''}</div>`).join('');
    for (let i = list.length; i < L.size; i++) h += `<div class="slot emptyslot">PLACE LIBRE</div>`;
    return h;
  };
  p.innerHTML = `
  <div class="row" style="margin-bottom:14px"><div><div class="title" style="font-size:26px">${esc(L.name)}</div>
    <div class="muted small">${esc(L.mapLabel)} · ${esc(L.format)} · ${L.rounds} manche(s) · ${L.roundTime} s · ${esc(catLabel(L.category))}${L.private ? ' · privée' : ''}${L.ranked ? ' · <b style="color:var(--ely-warn)">CLASSÉE</b>' : ''}</div></div>
    <div class="sp"></div>${L.isHost ? '<button class="btn ghost sm" data-act="invite">Inviter</button>' : ''}<button class="btn ghost sm" data-act="leave">Quitter</button></div>
  <div class="lobby">
    <div class="team A"><h3>${esc(L.teamNames.A)}</h3>${slots('A')}${me.team !== 'A' && !me.ready ? '<button class="btn sm red" data-team="A">Rejoindre</button>' : ''}</div>
    <div class="vs"><div class="big">VS</div>${L.stake ? `<div class="pot"><div class="small muted">POT</div><div class="v">${money(L.pot)}</div><div class="small muted">mise ${money(L.stake)}</div></div>` : '<div class="small muted">SANS MISE</div>'}</div>
    <div class="team B"><h3>${esc(L.teamNames.B)}</h3>${slots('B')}${me.team !== 'B' && !me.ready ? '<button class="btn sm blue" data-team="B">Rejoindre</button>' : ''}</div>
  </div>
  <div class="card holo" style="margin-top:16px"><h3>Ton arme · ${esc(catLabel(L.category))}</h3><div class="weapons">${L.weapons.map((w) => `<div class="weapon ${me.weapon === w.id ? 'on' : ''}" data-weapon="${w.id}"><div class="wn">${esc(w.label)}</div>
    <div class="sbar">DÉGÂTS<i><b style="width:${Math.min(100, w.damage)}%"></b></i></div><div class="sbar">PORTÉE<i><b style="width:${Math.min(100, w.range / 2.5)}%"></b></i></div>
    <div class="sbar">CADENCE<i><b style="width:${Math.min(100, w.rpm / 9)}%"></b></i></div></div>`).join('')}</div></div>
  <div class="row" style="margin-top:16px">
    <button class="btn ${me.ready ? 'ghost' : 'ok'}" data-act="ready">${me.ready ? 'Annuler « prêt »' : (L.stake ? `Prêt — payer ${money(L.stake)}` : 'Je suis prêt')}</button>
    <div class="sp"></div>${L.isHost ? '<button class="btn" data-act="start">Lancer la partie</button>' : '<span class="muted small">En attente du lancement par l\'hôte…</span>'}
  </div>`;
}

/* ---------------- CLASSEMENTS */
const LB = {
  pvp: [['pvp_points', 'Meilleurs joueurs', 'Points'], ['pvp_ratio', 'Meilleurs ratios', 'Ratio'], ['pvp_wins', 'Plus de victoires', 'Victoires'], ['pvp_rank', 'Meilleurs rangs', 'Pic'], ['pvp_streak', 'Plus longues séries', 'Série']],
};
// Une liste vide envoyée par le jeu peut arriver comme un objet {} : toujours la remettre en tableau
const asList = (x) => (Array.isArray(x) ? x : (x && typeof x === 'object' ? Object.values(x) : []));
async function loadBoard() {
  const want = S.lb.kind;
  const r = await rpc('lb:get', S.lb.kind, S.lb.page);
  if (want !== S.lb.kind || S.tab !== 'ranks') return;            // l'onglet a changé pendant le chargement
  if (r.ok && r.data) { S.lb.data = r.data; drawBoard(); }
  else if (!S.lb.data || S.lb.data.kind !== want) { const b = $('#board'); if (b) b.innerHTML = `<div class="empty">Classement indisponible pour le moment.<br><button class="btn sm ghost" data-lbp="0" style="margin-top:10px">Réessayer</button></div>`; }
}
function pageRanks(p) {
  p.innerHTML = `<div class="seg" style="margin-bottom:14px">${LB.pvp.map(([k, l]) => `<button data-lbk="${k}" class="${S.lb.kind === k ? 'on' : ''}">${l}</button>`).join('')}</div>
    <div class="card holo" id="board"><div class="empty">Chargement…</div></div>`;
  loadBoard();
  S.lbTimer = setInterval(loadBoard, 30000);   // actualisation automatique
}
function drawBoard() {
  const d = S.lb.data;
  if (!d || !$('#board')) return;
  d.rows = asList(d.rows);
  d.page = Number(d.page) || 1; d.pages = Math.max(1, Number(d.pages) || 1); d.total = Number(d.total) || 0;
  const def = LB.pvp.find((x) => x[0] === d.kind) || [];
  const rows = d.rows.map((r) => `<tr class="${r.pos <= 3 ? 'top' + r.pos : ''}"><td class="pos">#${r.pos}</td>
    <td>${rankImg(r.rank)} <b>${esc(`${r.firstname} ${r.lastname}`)}</b></td>
    <td class="score">${esc(r.v)}</td>
    <td class="muted small">${r.wins ?? '—'} V · ${r.losses ?? '—'} D · ${fmt(r.points ?? r.v)} pts</td></tr>`).join('');
  $('#board').innerHTML = `<h3>${esc(def[1] || '')}</h3>${d.rows.length ? `<table class="lb"><tr><th>#</th><th>Joueur</th><th>${esc(def[2] || '')}</th><th>Détails</th></tr>${rows}</table>` : '<div class="empty">Personne pour l\'instant.</div>'}
    <div class="row" style="margin-top:12px"><span class="muted small">Actualisé ${new Date((d.t || Date.now() / 1000) * 1000).toLocaleTimeString('fr-FR')} · ${d.total} entrées</span><div class="sp"></div>
    <button class="btn sm ghost" data-lbp="-1" ${d.page <= 1 ? 'disabled' : ''}>‹</button><span class="chip">${d.page} / ${d.pages}</span><button class="btn sm ghost" data-lbp="1" ${d.page >= d.pages ? 'disabled' : ''}>›</button></div>`;
}

/* ---------------- PROFIL */
async function pageProfile(p) {
  const r0 = await rpc('profile:get');
  if (r0.ok) S.init.profile = r0.data;
  const pr = S.init.profile;
  const r = rankOf(pr.rank);
  p.innerHTML = `<div class="card holo"><div class="profile-hero">
    <div class="emblem" style="--rank-glow:${r.color}88">${rankImg(pr.rank, '')}</div>
    <div><div class="muted" style="letter-spacing:.3em;font-size:11px;font-weight:800">${esc(pr.firstname)} ${esc(pr.lastname)}</div>
      <div class="rankname" style="color:${r.color};text-shadow:0 0 22px ${r.color}88">${esc(r.label)}</div>
      <div class="row" style="margin:6px 0 14px"><span class="chip">${fmt(pr.points)} points</span><span class="chip">Pic ${fmt(pr.peak)}</span>${pr.position ? `<span class="chip warn">#${pr.position} du serveur</span>` : ''}</div>
      <div class="bar"><i style="width:${Math.round(pr.progress * 100)}%"></i></div>
      <div class="small muted" style="margin-top:6px">${pr.next ? `${fmt(pr.next.min - pr.points)} points avant ${esc(pr.next.label)}` : 'Rang maximum : LÉGENDE'}</div>
      <div class="row wrap" style="margin-top:14px">${S.init.ranks.map((k) => `<img src="ranks/${k.id}.png" title="${esc(k.label)} · ${fmt(k.min)}" style="width:42px;opacity:${k.min <= pr.points ? 1 : .25}">`).join('')}</div></div></div></div>
  <div class="grid g4" style="margin-top:16px">${[['Victoires', pr.wins], ['Défaites', pr.losses], ['Égalités', pr.draws], ['Matchs joués', pr.matches], ['Éliminations', pr.kills], ['Morts', pr.deaths], ['Ratio É/M', pr.ratio], ['Meilleure série', pr.bestStreak]]
    .map(([l, v]) => `<div class="stat"><div class="v">${esc(v)}</div><div class="l">${l}</div></div>`).join('')}</div>
`;
}

/* ---------------- HISTORIQUE */
async function pageHistory(p) {
  p.innerHTML = '<div class="empty">Chargement…</div>';
  const r = await rpc('history:get');
  const rows = r.ok ? asList(r.data) : [];
  const res = { win: ['VICTOIRE', 'ok'], loss: ['DÉFAITE', 'red'], draw: ['ÉGALITÉ', ''], left: ['ABANDON', 'warn'] };
  p.innerHTML = `<div class="card holo"><h3>Dernières parties</h3>${rows.length ? `<table class="lb"><tr><th>Date</th><th>Format</th><th>Arène</th><th>Résultat</th><th>Score</th><th>É / M</th><th>Points</th><th>Gain</th></tr>
    ${rows.map((h) => { const rr = res[h.result] || [h.result, ''];
      return `<tr><td class="small">${dateFr(h.created_at)}</td><td><span class="chip">${esc(h.format || 'PVP')}</span></td>
      <td>${esc(h.mapLabel || mapOf(h.map).label || '')}</td><td><span class="chip ${rr[1]}">${rr[0]}</span></td>
      <td class="score"><span class="a">${h.score_a ?? 0}</span> — <span class="b">${h.score_b ?? 0}</span></td>
      <td>${h.kills} / ${h.deaths}</td><td style="color:${h.points_delta > 0 ? 'var(--ely-ok)' : h.points_delta < 0 ? 'var(--lg-red)' : 'inherit'}">${(h.points_delta > 0 ? '+' : '') + h.points_delta}</td>
      <td>${h.payout ? money(h.payout) : '—'}</td></tr>`; }).join('')}</table>` : '<div class="empty">Aucune partie jouée.</div>'}</div>`;
}

/* ---------------- PARAMÈTRES */
function pageSettings(p) {
  const s = S.settings;
  p.innerHTML = `<div class="card holo" style="max-width:640px"><h3>Préférences</h3>
    <div class="field"><label>Volume des effets (${Math.round(s.volume * 100)} %)</label><input type="range" min="0" max="1" step="0.05" value="${s.volume}" data-set="volume"></div>
    <div class="field" style="margin-top:14px"><label>Taille du HUD (${Math.round(s.hudScale * 100)} %)</label><input type="range" min="0.7" max="1.4" step="0.05" value="${s.hudScale}" data-set="hudScale"></div>
    <div class="row" style="margin-top:14px"><div class="toggle ${s.effects ? 'on' : ''}" data-setb="effects"></div><span>Effets visuels (particules, secousses, filtres)</span></div>
    <div class="row" style="margin-top:18px"><button class="btn ghost" data-act="testsound">Tester le son</button></div>
    <p class="small muted" style="margin-top:16px">Touches : <b>E</b> interagir (modifiable dans Paramètres GTA › Raccourcis › FiveM), <b>F7</b> menu de partie (quitter), <b>R</b> recharger, <b>← →</b> changer de joueur observé.</p></div>`;
}
function saveSettings() { post('settings', S.settings); document.documentElement.style.setProperty('--hud-scale', S.settings.hudScale); }

/* ---------------- STAFF */
async function loadAdmin() {
  const r = await rpc('admin:open');
  if (r.ok) { S.admin = r.data; if (S.tab === 'admin') pageAdmin($('#page')); }
}
function num(id, v, w = 90) { return `<input class="input" style="width:${w}px" data-num="${id}" value="${v ?? ''}">`; }
function pageAdmin(p) {
  if (!S.admin) { p.innerHTML = '<div class="empty">Chargement…</div>'; loadAdmin(); return; }
  const A = S.admin.settings;
  const t = S.adminTab;
  const tabs = [['games', 'Parties'], ['arenas', 'Arènes'], ['pvp', 'PVP'], ['weapons', 'Armes'], ['npcs', 'PNJ'], ['players', 'Joueurs'], ['logs', 'Journaux']];
  let h = `<div class="tabs">${tabs.map(([id, l]) => `<button data-atab="${id}" class="${t === id ? 'on' : ''}">${l}</button>`).join('')}</div>`;
  if (t === 'games') {
    const games = S.admin.games;
    h += `<div class="card holo"><h3>Parties et lobbies (${games.length})</h3>${games.length ? `<table class="adm-table"><tr><th>Partie</th><th>Mode</th><th>Phase</th><th>Carte</th><th>Joueurs</th><th>Score</th><th></th></tr>
      ${games.map((g) => `<tr><td><b>${esc(g.name)}</b><div class="small muted">${g.uid} · hôte ${esc(g.host)}</div></td><td>${g.mode}${g.format ? ' ' + g.format : ''}</td><td>${g.phase}</td><td>${esc(g.map)}</td>
      <td>${g.players.map((x) => `<div class="small">${esc(x.name)} <button class="btn sm ghost" data-akick="${g.uid}|${x.id}">expulser</button></div>`).join('')}</td>
      <td>${g.score?.A ?? 0} - ${g.score?.B ?? 0}</td><td><button class="btn sm red" data-astop="${g.uid}">Arrêter</button></td></tr>`).join('')}</table>` : '<div class="empty">Aucune partie.</div>'}
      <div class="row" style="margin-top:10px"><button class="btn sm ghost" data-act="arefresh">Actualiser</button><div class="sp"></div><span class="small muted">Framework : ${esc(A.framework)}</span></div></div>`;
  } else if (t === 'pvp') {
    const P = A.pvp, K = A.stake;
    h += `<div class="grid g2"><div class="card holo"><h3>Mode PVP</h3>
      ${[['enabled', 'Mode PVP activé'], ['requireEqualTeams', 'Équipes égales obligatoires'], ['requireFullTeams', 'Équipes complètes obligatoires'], ['oneHitElimination', 'Élimination en un tir'], ['friendlyFire', 'Tirs alliés']].map(([k, l]) => `<div class="row" style="margin-bottom:8px"><div class="toggle ${P[k] ? 'on' : ''}" data-apb="${k}"></div><span>${l}</span></div>`).join('')}
      <table class="adm-table">${[['shield', 'Bouclier (PV)'], ['minRankedDuration', 'Durée min. classée (s)'], ['lobbyIdleTimeout', 'Lobby inactif (s)'], ['defaultRoundTime', 'Durée par défaut (s)'], ['defaultRounds', 'Manches par défaut']].map(([k, l]) => `<tr><td>${l}</td><td>${num('pvp.' + k, P[k])}</td></tr>`).join('')}</table>
      <button class="btn sm" data-asave="pvp">Enregistrer</button></div>
      <div class="card holo"><h3>Mises (argent RP)</h3><div class="row" style="margin-bottom:8px"><div class="toggle ${K.enabled ? 'on' : ''}" data-askb="enabled"></div><span>Mises activées</span></div>
      <table class="adm-table">${[['min', 'Mise minimale'], ['max', 'Mise maximale'], ['step', 'Pas'], ['houseFeePct', 'Commission (%)']].map(([k, l]) => `<tr><td>${l}</td><td>${num('stake.' + k, K[k], 120)}</td></tr>`).join('')}</table>
      <button class="btn sm" data-asave="stake">Enregistrer</button>
      <h3 style="margin-top:18px">Formats</h3><div class="row wrap">${A.formats.map((f) => `<span class="row"><div class="toggle ${f.enabled ? 'on' : ''}" data-aformat="${f.id}"></div>${esc(f.label)}</span>`).join('')}</div>
      <h3 style="margin-top:18px">Seuils des rangs</h3><table class="adm-table">${A.ranks.map((r, i) => `<tr><td>${rankImg(r.id)} ${esc(r.label)}</td><td>${i === 0 ? '0' : num('rank.' + r.id, r.min)}</td></tr>`).join('')}</table>
      <button class="btn sm" data-asave="ranks">Enregistrer les seuils</button></div></div>`;
  } else if (t === 'weapons') {
    h += `<div class="card holo"><h3>Armes laser</h3><table class="adm-table"><tr><th>Arme</th><th>Cat.</th><th>Dégâts</th><th>Portée</th><th>Cadence</th><th>Dispersion</th><th>Chargeur</th><th>Recharge ms</th><th>Active</th><th></th></tr>
      ${A.weapons.map((w) => `<tr><td><b>${esc(w.label)}</b></td><td>${esc(catLabel(w.cat))}</td>
      ${['damage', 'range', 'rpm', 'spread', 'mag', 'reload'].map((k) => `<td>${num(`w.${w.id}.${k}`, w[k], 72)}</td>`).join('')}
      <td><div class="toggle ${w.disabled ? '' : 'on'}" data-awoff="${w.id}"></div></td><td><button class="btn sm" data-awsave="${w.id}">OK</button></td></tr>`).join('')}</table></div>`;
  } else if (t === 'arenas') {
    h += arenasAdmin(A);
  } else if (t === 'npcs') {
    h += `<div class="card holo"><h3>PNJ LaserGame</h3><p class="small muted">Les PNJ peuvent aussi être posés avec l'éditeur de map d'admin_menu (rôle « LaserGame »).</p>
      <table class="adm-table"><tr><th>Nom</th><th>Modèle</th><th>Position</th><th></th></tr>${A.npcs.map((n) => `<tr><td>${esc(n.label)}</td><td>${esc(n.model)}</td><td class="small">${n.x.toFixed(1)}, ${n.y.toFixed(1)}, ${n.z.toFixed(1)}</td><td><button class="btn sm red" data-anpcdel="${esc(n.id)}">Retirer</button></td></tr>`).join('')}</table>
      <div class="row" style="margin-top:12px"><input class="input" id="npcLabel" placeholder="Nom affiché" style="max-width:220px"><input class="input" id="npcModel" placeholder="Modèle (s_m_y_ammucity_01)" style="max-width:260px"><button class="btn sm" data-act="npcadd">Poser ici</button><button class="btn sm ghost" data-act="npcrestore">Rétablir ceux du fichier</button></div></div>`;
  } else if (t === 'players') {
    h += `<div class="card holo"><h3>Joueurs</h3><div class="row"><input class="input" id="psearch" placeholder="Nom RP ou identifiant…" style="max-width:340px"><button class="btn sm" data-act="psearch">Rechercher</button></div><div id="presults" style="margin-top:12px"></div></div><div id="pdetail" style="margin-top:16px"></div>`;
  } else if (t === 'logs') {
    const cat = S.sub.logcat || '';
    h += `<div class="card holo"><div class="seg" style="margin-bottom:12px">${[['', 'Tous'], ['admin', 'Staff'], ['money', 'Argent'], ['pvp', 'PVP'], ['security', 'Sécurité'], ['error', 'Erreurs']].map(([id, l]) => `<button data-logcat="${id}" class="${cat === id ? 'on' : ''}">${l}</button>`).join('')}</div><div id="logs"><div class="empty">Chargement…</div></div></div>`;
    rpc('admin:logs', cat, 1).then((r) => { const el = $('#logs'); if (el) el.innerHTML = r.ok && r.data.length ? r.data.map((l) => `<div class="log ${l.category}"><span class="muted">${dateFr(l.created_at)} [${l.category}]</span> ${esc(l.name ? l.name + ' : ' : '')}${esc(l.message)}</div>`).join('') : '<div class="empty">Aucun journal.</div>'; });
  }
  p.innerHTML = h;
}
// Onglet « Arènes » : création à la position du staff, outils « à ma position », réglages, activation.
// Le dessin en visant (coins, apparitions avec direction) et la décoration se font depuis admin_menu.
const WEATHERS = ['', 'CLEAR', 'EXTRASUNNY', 'CLOUDS', 'OVERCAST', 'FOGGY', 'RAIN', 'THUNDER', 'SMOG', 'SNOW', 'XMAS', 'HALLOWEEN'];
function arenasAdmin(A) {
  const list = A.arenas || [];
  const open = S.sub.arena && list.find((a) => a.id === S.sub.arena) ? S.sub.arena : (list[0] || {}).id;
  S.sub.arena = open;
  const T = A.teams || { A: 'ROUGE', B: 'BLEUE' };
  const card = (a) => {
    const st = a.valid ? (a.enabled ? '<span class="chip ok">OUVERTE</span>' : '<span class="chip">FERMÉE</span>') : '<span class="chip warn">INCOMPLÈTE</span>';
    const use = a.inUse ? `<span class="chip red">${a.inUse === 'running' ? 'PARTIE EN COURS' : 'LOBBY OUVERT'}</span>` : '';
    if (a.id !== open) return `<div class="card holo arena-row" data-aopen="${esc(a.id)}"><div class="row"><div class="arena-mini">${shapeSvg(a.shape)}</div><div class="sp"><b>${esc(a.label)}</b><div class="small muted">${a.corners} coins · ${a.spawnsA} ${esc(T.A)} · ${a.spawnsB} ${esc(T.B)} · ${esc(a.size)}${a.area ? ' · ' + fmt(a.area) + ' m²' : ''}</div></div>${st}${use}</div></div>`;
    return `<div class="card holo arena-open"><div class="row"><h3 style="margin:0">${esc(a.label)}</h3>${st}${use}<div class="sp"></div>
        <div class="toggle ${a.enabled ? 'on' : ''}" data-arena="update" data-k="enabled" title="${a.valid ? 'Ouvrir / fermer aux joueurs' : 'Termine l\'arène d\'abord'}"></div></div>
      ${a.issues && a.issues.length ? `<div class="issues">À faire : ${a.issues.map(esc).join(' · ')}</div>` : '<div class="issues ok">Arène jouable.</div>'}
      <div class="arena-grid"><div class="arena-big">${shapeSvg(a.shape)}</div><div>
        <table class="adm-table">
          <tr><td>Nom</td><td><input class="input" id="arLabel" maxlength="32" value="${esc(a.label)}"></td></tr>
          <tr><td>Description</td><td><input class="input" id="arDesc" maxlength="160" value="${esc(a.description || '')}" placeholder="Entrepôt néon, deux étages…"></td></tr>
          <tr><td>Joueurs max. par équipe</td><td><select class="input" id="arMax">${[1, 2, 3, 4, 5, 6].map((n) => `<option ${n === a.maxPerTeam ? 'selected' : ''}>${n}</option>`).join('')}</select></td></tr>
          <tr><td>Heure forcée (0-23)</td><td><input class="input" id="arTime" type="number" min="0" max="23" value="${a.time ?? ''}" placeholder="heure du serveur"></td></tr>
          <tr><td>Météo forcée</td><td><select class="input" id="arWeather">${WEATHERS.map((w) => `<option value="${w}" ${w === (a.weather || '') ? 'selected' : ''}>${w || 'météo du serveur'}</option>`).join('')}</select></td></tr>
          <tr><td>Sol / plafond (z)</td><td><input class="input" id="arMinZ" type="number" step="0.5" value="${a.zone?.minZ ?? ''}" style="width:110px"> <input class="input" id="arMaxZ" type="number" step="0.5" value="${a.zone?.maxZ ?? ''}" style="width:110px"></td></tr>
        </table>
        <div class="row wrap" style="margin-top:10px"><button class="btn sm" data-arena="save">Enregistrer</button><button class="btn sm ghost" data-arena="show">Voir la zone (60 s)</button><button class="btn sm ghost" data-arena="tp">Y aller</button></div>
      </div></div>
      <h3 style="margin-top:16px">Construire à ma position</h3>
      <p class="small muted">Place-toi sur le point, puis appuie. Avec admin_menu, tu peux aussi dessiner en visant : ${A.adminMenu ? '<b>admin_menu › LaserGame › Arènes</b> (coins, sol, plafond, apparitions tournées comme la caméra).' : 'admin_menu n\'est pas démarré sur ce serveur.'}
        Le décor se pose avec l'<b>éditeur de map</b> d'admin_menu, à l'endroit de l'arène : il est visible dans l'instance de la partie.</p>
      <div class="row wrap"><button class="btn sm" data-arena="corner_here">+ Coin de la zone (${a.corners})</button><button class="btn sm ghost" data-arena="floor_here">Sol = moi − 2 m</button><button class="btn sm ghost" data-arena="ceiling_here">Plafond = moi + 3 m</button><button class="btn sm ghost" data-arena="center_here">Centre = moi</button></div>
      <div class="row wrap" style="margin-top:8px"><button class="btn sm red" data-arena="spawn_here" data-team="A">+ Apparition ${esc(T.A)} (${a.spawnsA})</button><button class="btn sm blue" data-arena="spawn_here" data-team="B">+ Apparition ${esc(T.B)} (${a.spawnsB})</button>
        <span class="small muted">la flèche suit ton orientation</span></div>
      <div class="row wrap" style="margin-top:8px"><button class="btn sm ghost" data-arena="clear" data-what="A">Effacer ${esc(T.A)}</button><button class="btn sm ghost" data-arena="clear" data-what="B">Effacer ${esc(T.B)}</button><button class="btn sm ghost" data-arena="clear" data-what="zone">Effacer la zone et les apparitions</button><div class="sp"></div><button class="btn sm red" data-arena="delete">Supprimer l'arène</button></div>
    </div>`;
  };
  return `<div class="card holo"><div class="row wrap"><h3 style="margin:0">Arènes (${list.length})</h3><div class="sp"></div><input class="input" id="arNew" maxlength="32" placeholder="Nom de la nouvelle arène" style="max-width:260px"><button class="btn sm" data-arena="create">Créer ici (ma position)</button></div>
    <p class="small muted" style="margin:8px 0 0">1. Crée l'arène là où tu es · 2. dessine la zone de combat · 3. pose les apparitions des deux équipes · 4. décore avec l'éditeur de map · 5. ouvre-la aux joueurs. Chaque partie se joue dans sa propre instance : plusieurs parties peuvent utiliser la même arène en même temps.</p></div>
    ${list.length ? list.map(card).join('') : '<div class="card holo"><div class="empty">Aucune arène : crée la première à ta position.</div></div>'}`;
}
async function arenaAction(action, data) {
  const r = await rpc('admin:arena', action, data);
  if (r.ok && r.data) { if (r.data.arenas) S.admin.settings.arenas = r.data.arenas; if (r.data.message) toast(r.data.message, 'success'); if (S.tab === 'admin') pageAdmin($('#page')); }
  return r;
}
const nv = (id) => { const el = $(`[data-num="${id}"]`); return el ? Number(String(el.value).replace(',', '.')) : undefined; };
async function adminSet(section, payload, key) {
  const r = await rpc('admin:set', section, payload, key);
  if (r.ok) { S.admin.settings = r.data; toast('Réglage enregistré.', 'success'); pageAdmin($('#page')); }
}
async function showPlayer(cid) {
  const r = await rpc('admin:players.get', cid);
  if (!r.ok) return;
  const pr = r.data.profile;
  $('#pdetail').innerHTML = `<div class="card holo"><div class="row">${rankImg(pr.rank, '')}<style>#pdetail img{width:70px}</style><div><div class="rankname" style="font-size:22px">${esc(pr.firstname)} ${esc(pr.lastname)}</div>
    <div class="muted small">${esc(pr.citizenid)} · ${fmt(pr.points)} pts · ${pr.wins} V / ${pr.losses} D${pr.banned ? ' · <b style="color:var(--lg-red)">EXCLU</b> ' + esc(pr.banReason || '') : ''}${pr.online ? ' · <span style="color:var(--ely-ok)">en ligne</span>' : ''}</div></div></div>
    <div class="row wrap" style="margin-top:12px"><input class="input" id="ppoints" value="${pr.points}" style="width:110px"><button class="btn sm" data-pset="points">Fixer les points</button>
      <select class="input" id="prank" style="width:200px">${S.init.ranks.map((k) => `<option value="${k.id}" ${k.id === pr.rank ? 'selected' : ''}>${esc(k.label)}</option>`).join('')}</select><button class="btn sm" data-pset="rank">Fixer le rang</button>
      <button class="btn sm ghost" data-pset="reset:pvp">Remettre les statistiques à zéro</button></div>
    <div class="row wrap" style="margin-top:10px">${pr.banned ? '<button class="btn sm ok" data-pset="unexclude">Lever l\'exclusion</button>' : '<input class="input" id="pbanr" placeholder="Raison" style="max-width:260px"><input class="input" id="pbanh" placeholder="Heures (0 = définitif)" style="width:170px"><button class="btn sm red" data-pset="exclude">Exclure du LaserGame</button>'}</div>
    <h3 style="margin-top:16px">Historique</h3>${r.data.history.slice(0, 12).map((h) => `<div class="log pvp">${dateFr(h.created_at)} · ${esc(h.format || 'PVP')} · ${esc(h.mapLabel || '')} · ${h.result} · ${h.kills}/${h.deaths} · ${h.points_delta > 0 ? '+' : ''}${h.points_delta} pts</div>`).join('') || '<div class="empty">Aucune partie.</div>'}</div>`;
  S.sub.pcid = pr.citizenid;
}

/* ------------------------------------------------------------------ actions du menu */
document.addEventListener('click', async (e) => {
  const t = e.target.closest('[data-tab],[data-sub],[data-act],[data-join],[data-spec],[data-cs],[data-ct],[data-team],[data-weapon],[data-kick],[data-qf],[data-lbk],[data-lbp],[data-setb],[data-go],[data-atab],[data-asave],[data-apb],[data-askb],[data-aformat],[data-awsave],[data-awoff],[data-arena],[data-aopen],[data-anpcdel],[data-akick],[data-astop],[data-logcat],[data-pick],[data-pset],[data-invite]');
  if (!t) return;
  const d = t.dataset;
  if (d.arena) {
    const id = S.sub.arena;
    if (d.arena === 'create') return arenaAction('create', { label: $('#arNew')?.value || '' }).then((r) => { if (r.ok && r.data?.arenas) { S.sub.arena = r.data.arenas[r.data.arenas.length - 1]?.id; pageAdmin($('#page')); } });
    if (d.arena === 'save') {
      const num = (v) => (v === '' || v == null ? undefined : Number(v));
      return arenaAction('update', { id, label: $('#arLabel').value, description: $('#arDesc').value, maxPerTeam: Number($('#arMax').value),
        time: $('#arTime').value, weather: $('#arWeather').value, minZ: num($('#arMinZ').value), maxZ: num($('#arMaxZ').value) });
    }
    if (d.arena === 'update' && d.k === 'enabled') { const a = S.admin.settings.arenas.find((x) => x.id === id); return arenaAction('update', { id, enabled: !a.enabled }); }
    if (d.arena === 'delete' && !confirm('Supprimer définitivement cette arène ? (les objets posés avec l\'éditeur de map restent en place)')) return;
    if (d.arena === 'clear' && !confirm('Effacer ces points ?')) return;
    return arenaAction(d.arena, { id, team: d.team, what: d.what });
  }
  if (d.aopen) { S.sub.arena = d.aopen; return pageAdmin($('#page')); }
  if (d.tab) return go(d.tab, d.sub);
  if (d.go) return go(d.go);
  if (d.sub) { S.sub[S.tab] = d.sub; return render(); }
  if (d.qf) { S.sub.quickFormat = d.qf; return render(); }
  if (d.cs) { S.create[d.cs] = isNaN(d.v) ? d.v : Number(d.v); return render(); }
  if (d.ct) { S.create[d.ct] = !S.create[d.ct]; return render(); }
  if (d.join) {
    let pw = '';
    if (d.pw === '1') { pw = prompt('Mot de passe de la partie :') || ''; }
    const r = await rpc('pvp:join', d.join, pw);
    if (r.ok) go('pvp');
    return;
  }
  if (d.spec) { const r = await rpc('spectate:join', d.spec); if (r.ok) toast('Mode spectateur : ← → pour changer de joueur, F7 pour quitter.', 'info'); return; }
  if (d.team) return rpc('pvp:team', d.team);
  if (d.weapon) return rpc('pvp:weapon', d.weapon);
  if (d.kick) return rpc('pvp:kick', Number(d.kick));
  if (d.invite) { const r = await rpc('pvp:invite', Number(d.invite)); if (r.ok) toast('Invitation envoyée.', 'success'); return; }
  if (d.lbk) { S.lb.kind = d.lbk; S.lb.page = 1; return render(); }
  if (d.lbp !== undefined) { S.lb.page = Math.max(1, Math.min((S.lb.data && S.lb.data.pages) || 999, S.lb.page + Number(d.lbp))); return loadBoard(); }
  if (d.setb) { S.settings[d.setb] = !S.settings[d.setb]; saveSettings(); return render(); }
  // staff
  if (d.atab) { S.adminTab = d.atab; return pageAdmin($('#page')); }
  if (d.asave === 'pvp') return adminSet('pvp', Object.fromEntries(['shield', 'minRankedDuration', 'lobbyIdleTimeout', 'defaultRoundTime', 'defaultRounds'].map((k) => [k, nv('pvp.' + k)])));
  if (d.asave === 'stake') return adminSet('stake', Object.fromEntries(['min', 'max', 'step', 'houseFeePct'].map((k) => [k, nv('stake.' + k)])));
  if (d.asave === 'ranks') { for (const r of S.admin.settings.ranks.slice(1)) await rpc('admin:set', 'rank', { min: nv('rank.' + r.id) }, r.id); return loadAdmin(); }
  if (d.apb) return adminSet('pvp', { [d.apb]: !S.admin.settings.pvp[d.apb] });
  if (d.askb) return adminSet('stake', { enabled: !S.admin.settings.stake.enabled });
  if (d.aformat) { const f = S.admin.settings.formats.find((x) => x.id === d.aformat); return adminSet('format', { enabled: !f.enabled }, d.aformat); }
  if (d.awsave) return adminSet('weapon', Object.fromEntries(['damage', 'range', 'rpm', 'spread', 'mag', 'reload'].map((k) => [k, nv(`w.${d.awsave}.${k}`)])), d.awsave);
  if (d.awoff) { const w = S.admin.settings.weapons.find((x) => x.id === d.awoff); return adminSet('weapon', { disabled: !w.disabled }, d.awoff); }
  if (d.anpcdel) { const r = await rpc('admin:npc', 'remove', { id: d.anpcdel }); if (r.ok) { S.admin.settings = r.data; pageAdmin($('#page')); } return; }
  if (d.akick) { const [uid, id] = d.akick.split('|'); const r = await rpc('admin:game', uid, 'kick', Number(id)); if (r.ok) { S.admin.games = r.data; pageAdmin($('#page')); } return; }
  if (d.astop) { if (!confirm('Arrêter cette partie ? Les mises seront remboursées.')) return; const r = await rpc('admin:game', d.astop, 'stop'); if (r.ok) { S.admin.games = r.data; pageAdmin($('#page')); } return; }
  if (d.logcat !== undefined) { S.sub.logcat = d.logcat; return pageAdmin($('#page')); }
  if (d.pick) return showPlayer(d.pick);
  if (d.pset) {
    const [action, scope] = d.pset.split(':');
    let value = scope, extra = null;
    if (action === 'points') value = Number($('#ppoints').value);
    if (action === 'rank') value = $('#prank').value;
    if (action === 'exclude') extra = { reason: $('#pbanr').value, hours: Number($('#pbanh').value) || 0 };
    if (action === 'reset' && !confirm('Réinitialiser ces statistiques ?')) return;
    const r = await rpc('admin:players.set', S.sub.pcid, action, value, extra);
    if (r.ok) { toast('Joueur mis à jour.', 'success'); showPlayer(S.sub.pcid); }
    return;
  }
  // actions simples
  switch (d.act) {
    case 'close': return closeUI();
    case 'create': {
      const c = Object.assign({}, S.create);
      $$('[data-c]').forEach((el) => { c[el.dataset.c] = el.type === 'number' ? Number(el.value) : el.value; });
      S.create = c;
      const r = await rpc('pvp:create', c);
      if (r.ok) toast('Lobby créé. Invite tes amis ou attends des joueurs.', 'success');
      return;
    }
    case 'quick': {
      S.sub.quickStake = Number($('#qstake')?.value || 0);
      const r = await rpc('pvp:quick', S.sub.quickFormat || '2v2', S.sub.quickStake);
      if (r.ok) toast(r.extra ? 'Aucune partie trouvée : un lobby a été ouvert.' : 'Partie trouvée !', 'success');
      return;
    }
    case 'ready': { const me = [...S.lobby.teams.A, ...S.lobby.teams.B].find((x) => x.me); return rpc('pvp:ready', !me?.ready); }
    case 'start': return rpc('pvp:start');
    case 'leave': { await rpc('lobby:leave'); S.lobby = null; return render(); }
    case 'invite': return openInviteList();
    case 'testsound': return Snd.play('victory');
    case 'arefresh': return loadAdmin();
    case 'npcadd': { const r = await rpc('admin:npc', 'add', { label: $('#npcLabel').value, model: $('#npcModel').value }); if (r.ok) { S.admin.settings = r.data; pageAdmin($('#page')); } return; }
    case 'npcrestore': { const r = await rpc('admin:npc', 'restore', {}); if (r.ok) { S.admin.settings = r.data; pageAdmin($('#page')); } return; }
    case 'psearch': {
      const r = await rpc('admin:players.search', $('#psearch').value);
      $('#presults').innerHTML = r.ok ? `<table class="adm-table">${r.data.map((x) => `<tr><td>${rankImg(x.rank)} <b>${esc(x.firstname)} ${esc(x.lastname)}</b></td><td class="small muted">${esc(x.citizenid)}</td><td>${fmt(x.points)} pts</td><td>${x.wins} V · ${x.losses} D</td><td>${x.banned ? '<span class="chip red">EXCLU</span>' : ''}</td><td><button class="btn sm" data-pick="${esc(x.citizenid)}">Ouvrir</button></td></tr>`).join('')}</table>` : '';
      return;
    }
    case 'leaveGame': $('#gameMenu').classList.add('hidden'); post('leaveGame'); post('gameMenuClose'); return;
    case 'resume': $('#gameMenu').classList.add('hidden'); post('gameMenuClose'); return;
    default:
  }
});
document.addEventListener('input', (e) => {
  const el = e.target;
  if (el.dataset.set) { S.settings[el.dataset.set] = Number(el.value); saveSettings(); const lbl = el.previousElementSibling; if (lbl) lbl.textContent = lbl.textContent.replace(/\(\d+ %\)/, `(${Math.round(el.value * 100)} %)`); }
  if (el.dataset.c) S.create[el.dataset.c] = el.type === 'number' ? Number(el.value) : el.value;
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    if (!$('#gameMenu').classList.contains('hidden')) { $('#gameMenu').classList.add('hidden'); post('gameMenuClose'); return; }
    if (!$('#app').classList.contains('hidden')) closeUI();
  }
  if (e.key === 'Enter' && document.activeElement?.id === 'psearch') $('[data-act="psearch"]').click();
});

async function openInviteList() {
  const r = await rpc('lobby:nearby');
  if (!r.ok) return;
  const list = r.data || [];
  const el = document.createElement('div');
  el.className = 'card holo invite';
  el.innerHTML = `<h3>Inviter un joueur proche</h3>${list.length ? list.map((x) => `<div class="row" style="margin-bottom:6px"><span class="sp">${esc(x.name)} <span class="muted small">#${x.id}</span></span><button class="btn sm" data-invite="${x.id}">Inviter</button></div>`).join('') : '<div class="empty">Personne à moins de 40 m.</div>'}<button class="btn sm ghost" style="margin-top:8px;width:100%">Fermer</button>`;
  el.querySelector('.btn.ghost').onclick = () => el.remove();
  $('#invites').appendChild(el);
  setTimeout(() => el.remove(), 30000);
}

function closeUI() {
  const app = $('#app');
  if (app.classList.contains('hidden')) return;
  app.classList.add('closing');
  clearInterval(S.lbTimer);
  setTimeout(() => { app.classList.add('hidden'); app.classList.remove('closing'); }, 240);
  post('close');
}

/* ------------------------------------------------------------------ HUD */
const H = { mode: null, endsAt: 0, offset: 0 };
function hudInit(d) {
  H.mode = d.mode; H.role = d.role; H.team = d.team;
  const teamColor = d.team === 'A' ? 'var(--lg-red)' : d.team === 'B' ? 'var(--lg-blue)' : 'var(--ely-violet)';
  document.documentElement.style.setProperty('--team', teamColor);
  document.documentElement.style.setProperty('--hud-scale', S.settings.hudScale);
  const root = $('#hudScale');
  root.innerHTML = `<div class="hud-top"><div class="hs A" id="hsA">0</div><div class="hmid"><div class="tm mono" id="htime">--:--</div><div class="rd" id="hround">MANCHE 1</div></div><div class="hs B" id="hsB">0</div></div>
    <div class="alive"><div class="grp A" id="alA"></div><div class="grp B" id="alB"></div></div>
    <div class="mates" id="mates"></div><div class="killfeed" id="kf"></div>
    ${d.role === 'player' ? `<div class="shield" id="shield"><div class="lbl">BOUCLIER <b id="shv">${d.shield}</b></div><div class="sb"><b id="shb"></b></div></div><div class="ammo" id="ammo"></div>` : ''}
    <div class="crosshair hidden" id="cross"><i></i><i></i><i></i><i></i><b></b></div><div class="hitmarker" id="hm"><i></i><i></i><i></i><i></i></div><div class="dmgdir" id="dd"></div>
    <div class="vignette" id="vig"></div><div class="center-msg" id="cmsg"></div><div class="specbar hidden" id="spec"></div><div class="progress hidden" id="prog"></div>`;
  $('#hud').classList.remove('hidden');
  clearInterval(H.tick);
  H.tick = setInterval(hudTick, 250);
}
function hudTick() {
  const el = $('#htime');
  if (el && H.endsAt) {
    const left = Math.max(0, Math.round(H.endsAt - (Date.now() / 1000 + H.offset)));
    el.textContent = `${String(Math.floor(left / 60)).padStart(2, '0')}:${String(left % 60).padStart(2, '0')}`;
    el.classList.toggle('low', left <= 10);
  }
}
function centerMsg(html, ms) {
  const c = $('#cmsg'); if (!c) return;
  c.innerHTML = html;
  clearTimeout(H.cm);
  if (ms) H.cm = setTimeout(() => { c.innerHTML = ''; }, ms);
}
function setBar(v, max, hit) {
  const b = $('#shb'), t = $('#shv'), s = $('#shield');
  if (!b) return;
  b.style.width = `${Math.max(0, Math.min(100, v / Math.max(1, max) * 100))}%`;
  t.textContent = Math.max(0, Math.round(v));
  if (hit) { s.classList.remove('hit'); void s.offsetWidth; s.classList.add('hit'); flashVignette(); }
}
function flashVignette() {
  const v = $('#vig'); if (!v) return;
  v.style.opacity = 1;
  clearTimeout(H.vg); H.vg = setTimeout(() => { v.style.opacity = 0; }, 350);
}

const ON = {
  open(d) {
    S.init = d.init; S.list = d.init.games || []; S.lobby = d.init.lobby || null;
    if (d.settings) Object.assign(S.settings, d.settings);
    $('#mark').innerHTML = Ely.mark({ anim: true, live: true, size: 64 });
    $('#sky').innerHTML = Ely.skyline({ w: 600, h: 170, seed: 11, lit: 0.22 });
    $('#app').classList.remove('hidden');
    go(S.lobby ? 'pvp' : (d.tab || 'home'));
    if (d.admin) { S.admin = null; go('admin'); }
  },
  close() { $('#app').classList.add('hidden'); clearInterval(S.lbTimer); },
  tab(t) { go(t); },
  list(list) { S.list = list || []; if (!$('#app').classList.contains('hidden') && ['home', 'pvp'].includes(S.tab) && !S.lobby) render(); },
  lobby(v) { const first = !S.lobby; S.lobby = v; if (!$('#app').classList.contains('hidden')) { if (first) go('pvp'); else if (S.tab === 'pvp') render(); } },
  lobbyClosed(d) { if (S.lobby && S.lobby.uid === d.uid) { S.lobby = null; if (d.reason && d.reason !== 'a quitté') toast(`Lobby fermé : ${d.reason}`, 'warn'); render(); } },
  gameClosed(d) { S.list = S.list.filter((g) => g.uid !== d.uid); },
  invite(inv) {
    const el = document.createElement('div');
    el.className = 'card holo invite';
    el.innerHTML = `<h3>Invitation PVP</h3><div><b>${esc(inv.host)}</b> t'invite à « ${esc(inv.name)} ».</div><div class="small muted" style="margin:6px 0 10px">Rends-toi auprès d'un PNJ LaserGame pour accepter (E).</div>
      <div class="row"><button class="btn sm ok">Accepter</button><button class="btn sm ghost">Ignorer</button></div>`;
    const [ok, no] = el.querySelectorAll('button');
    ok.onclick = async () => { el.remove(); const r = await rpc('pvp:join', inv.uid, ''); if (r.ok) toast('Tu as rejoint la partie.', 'success'); };
    no.onclick = () => el.remove();
    $('#invites').appendChild(el);
    setTimeout(() => el.remove(), (inv.ttl || 120) * 1000);
  },
  toast(d) { toast(d.text, d.kind); },
  sound(d) { Snd.play(d.name, d.volume); },
  prompt(d) {
    const p = $('#prompt');
    if (!d) return p.classList.add('hidden');
    p.innerHTML = `<div class="key">${esc(d.key || 'E')}</div><div><div class="tt">${esc(d.title || '')}</div><div class="lb">${esc(d.label || '')}</div></div>${d.price != null ? `<div class="pr ${d.money === false ? 'no' : ''}">${fmt(d.price)} $</div>` : ''}`;
    p.classList.remove('hidden');
  },
  loading(d) {
    $('#loadingMode').textContent = d.role === 'spectator' ? 'MODE SPECTATEUR' : 'PVP ARENA';
    $('#loadingName').textContent = d.mapLabel || mapOf(d.map).label || d.name || '';
    const tips = ['Le laser est arrêté par les couvertures : sers-t\'en.', 'Recharge (R) à l\'abri.', 'Les spectateurs ne voient pas ce que tu prépares.', 'La paroi violette marque la limite de l\'arène.', 'Un éliminé observe ses coéquipiers : guide-les.', 'Change de position après chaque élimination.'];
    $('#loadingTip').textContent = tips[Math.floor(Math.random() * tips.length)];
    $('#loadingBar').style.width = '0%';
    $('#loading').classList.remove('hidden');
    $('#app').classList.add('hidden');
  },
  loadingProgress(k) { $('#loadingBar').style.width = `${Math.round(k * 100)}%`; },
  loadingDone() { setTimeout(() => $('#loading').classList.add('hidden'), 400); },
  hud(d) { if (!d) { $('#hud').classList.add('hidden'); clearInterval(H.tick); $('#results').classList.add('hidden'); return; } hudInit(d); if (d.shield) setBar(d.shield, d.maxShield || d.shield); },
  crosshair(on) { const c = $('#cross'); if (c) c.classList.toggle('hidden', !on); },
  hitmarker(d) { const h = $('#hm'); if (!h) return; h.classList.toggle('kill', !!d.kill); h.classList.remove('go'); void h.offsetWidth; h.classList.add('go'); },
  damageDir(d) { const e = $('#dd'); if (!e) return; e.style.transform = `rotate(${-d.angle}deg)`; e.classList.remove('go'); void e.offsetWidth; e.classList.add('go'); },
  shield(d) { setBar(d.shield, d.max, d.hit); },
  ammo(d) {
    const a = $('#ammo'); if (!a) return;
    if (!d) { a.innerHTML = ''; return; }
    a.innerHTML = `<div class="wn">${esc(d.label)}</div>${d.mag > 0 ? `<div class="am mono">${d.ammo}<small> / ${d.mag}</small></div>` : '<div class="am">∞</div>'}${d.reloading ? '<div class="rl">RECHARGE</div>' : ''}
      ${d.slots && d.slots.length > 1 ? `<div class="slots">${d.slots.map((s, i) => `<span class="${s === d.current ? 'on' : ''}">${i + 1}</span>`).join('')}</div>` : ''}`;
  },
  countdown(d) { let n = d.seconds; const tickN = () => { if (n <= 0) return; centerMsg(`<div class="cd">${n}</div><div class="banner neutral" style="font-size:22px">MANCHE ${d.round}${d.rounds ? ' / ' + d.rounds : ''}</div>`); n -= 1; if (n > 0) H.cdT = setTimeout(tickN, 1000); }; clearTimeout(H.cdT); tickN(); },
  roundStart(d) { clearTimeout(H.cdT); H.endsAt = d.endsAt; centerMsg('<div class="banner neutral">GO !</div>', 1000); },
  roundEnd(d) {
    H.endsAt = 0;
    const cls = d.winner == null ? 'neutral' : (d.mine ? 'win' : 'lose');
    const txt = d.winner == null ? 'ÉGALITÉ' : (d.mine ? 'MANCHE GAGNÉE' : 'MANCHE PERDUE');
    const why = { elimination: 'ÉQUIPE ÉLIMINÉE', temps: 'TEMPS ÉCOULÉ', double: 'ÉLIMINATION MUTUELLE', abandon: 'ABANDON' }[d.reason] || '';
    centerMsg(`<div class="banner ${cls}">${txt}<span class="sub">${why} · ${d.score.A} — ${d.score.B}</span></div>`, 4500);
  },
  pvpState(s) {
    H.offset = (s.serverTime || Date.now() / 1000) - Date.now() / 1000;
    if (s.endsAt) H.endsAt = s.endsAt;
    const a = $('#hsA'); if (!a) return;
    a.textContent = s.score.A; $('#hsB').textContent = s.score.B;
    $('#hround').textContent = `MANCHE ${s.round}${s.rounds ? ' / ' + s.rounds : ''}`;
    const dots = (team) => s.players.filter((p) => p.team === team).map((p) => `<i class="${p.alive ? 'on' : ''}"></i>`).join('');
    $('#alA').innerHTML = dots('A'); $('#alB').innerHTML = dots('B');
    const mates = s.players.filter((p) => s.role === 'spectator' || p.team === s.myTeam);
    $('#mates').innerHTML = mates.map((p) => `<div class="mate ${p.alive ? '' : 'dead'}" style="--c:${p.team === 'A' ? 'var(--lg-red)' : 'var(--lg-blue)'}">${esc(p.name)}${p.me ? ' (toi)' : ''}<span class="mb"><b style="width:${p.shield != null ? Math.max(0, p.shield) : (p.alive ? 100 : 0)}%"></b></span><span class="small">${p.kills}</span></div>`).join('');
  },
  eliminated(d) { centerMsg(`<div class="banner lose">ÉLIMINÉ<span class="sub">${d.by ? 'PAR ' + esc(d.by).toUpperCase() + ' · ' : ''}${esc(d.weapon || '')}</span></div>`, 3000); setBar(0, 100, true); },
  killfeed(k) {
    const f = $('#kf'); if (!f) return;
    const el = document.createElement('div');
    el.className = `kf ${k.mine ? 'mine' : ''}`;
    el.innerHTML = k.left ? `<span class="${k.victimTeam}">${esc(k.victim)}</span><span class="w">a quitté la partie</span>` : `<span class="${k.killerTeam}">${esc(k.killer || '?')}</span><span class="w">⟶ ${esc(k.weapon || 'laser')}</span><span class="${k.victimTeam}">${esc(k.victim)}</span>`;
    f.prepend(el); while (f.children.length > 6) f.lastChild.remove();
    setTimeout(() => el.remove(), 5600);
  },
  spectate(d) {
    const s = $('#spec'); if (!s) return;
    if (!d) return s.classList.add('hidden');
    s.classList.remove('hidden');
    s.innerHTML = `<div class="small muted" style="letter-spacing:.3em">${d.scope === 'team' ? 'TES COÉQUIPIERS' : 'SPECTATEUR'}</div><div class="who" style="color:${d.team === 'A' ? 'var(--lg-red)' : d.team === 'B' ? 'var(--lg-blue)' : '#fff'}">${esc(d.name || 'En attente…')}</div>
      <div class="keys">← → CHANGER DE JOUEUR · MOLETTE ZOOM${d.scope === 'all' ? ' · F7 QUITTER' : ''}</div>`;
  },
  matchEnd(d) { showResults(d); },
  confirmLeave() { ON.gameMenu({}); },
  gameMenu(d) {
    const m = $('#gameMenu');
    m.innerHTML = `<div class="card holo"><h3>Menu de partie</h3><p class="muted small">${d.role === 'spectator' ? 'Arrêter de regarder et revenir au RP.' : 'Quitter maintenant compte comme un abandon (mise perdue, pénalité de points en partie classée).'}</p>
      <button class="btn ${d.role === 'spectator' ? '' : 'red'}" data-act="leaveGame">${d.role === 'spectator' ? 'Quitter le mode spectateur' : 'Abandonner la partie'}</button><button class="btn ghost" data-act="resume">Reprendre</button></div>`;
    m.classList.remove('hidden');
  },
  progress(d) {
    const p = $('#prog'); if (!p) return;
    if (!d) { p.classList.add('hidden'); return; }
    p.classList.remove('hidden');
    p.innerHTML = `<div class="tt" style="font:800 italic 16px var(--ely-font-display)">${esc(d.label)}</div><div class="bar"><i id="progBar" style="width:0%"></i></div>`;
    const start = performance.now(), dur = (d.duration || 4) * 1000;
    const step = (t) => { const b = $('#progBar'); if (!b) return; const k = Math.min(1, (t - start) / dur); b.style.width = `${k * 100}%`; if (k < 1) requestAnimationFrame(step); };
    requestAnimationFrame(step);
  },
};

/* ------------------------------------------------------------------ écrans de fin */
function confetti(colors) {
  if (!S.settings.effects) return;
  const c = $('#confetti');
  c.innerHTML = '';
  for (let i = 0; i < 90; i++) {
    const e = document.createElement('i');
    e.style.left = `${Math.random() * 100}%`;
    e.style.background = colors[i % colors.length];
    e.style.boxShadow = `0 0 8px ${colors[i % colors.length]}`;
    e.style.animationDuration = `${2.2 + Math.random() * 2.5}s`;
    e.style.animationDelay = `${Math.random() * 1.2}s`;
    e.style.setProperty('--rot', `${Math.random() * 720 - 360}deg`);
    c.appendChild(e);
  }
  setTimeout(() => { c.innerHTML = ''; }, 6000);
}
function showResults(d) {
  const r = $('#results');
  const me = d.me || {};
  const res = me.result || (d.winner ? 'loss' : 'draw');
  r.className = res === 'win' ? 'win' : res === 'loss' || res === 'left' ? 'lose' : '';
  const big = { win: 'VICTOIRE', loss: 'DÉFAITE', draw: 'ÉGALITÉ', left: 'ABANDON' }[res] || (d.winner ? `VICTOIRE ${d.teamNames[d.winner]}` : 'ÉGALITÉ');
  const rk = me.rank ? rankOf(me.rank) : null;
  r.innerHTML = `<div class="res"><div class="big glitch go" data-text="${big}">${big}</div>
    <div class="final"><span style="color:var(--lg-red)">${d.score.A}</span> — <span style="color:var(--lg-blue)">${d.score.B}</span></div>
    ${d.mvp ? `<div class="chip warn" style="font-size:14px;padding:8px 16px">MVP · ${esc(d.mvp)}</div>` : ''}
    ${rk ? `<div class="rankbox ${me.rankUp ? 'up' : ''}"><img src="ranks/${me.rank}.png"><div style="text-align:left"><div class="rankname" style="font-size:26px;color:${rk.color}">${esc(rk.label)}</div>
      <div class="delta ${me.delta > 0 ? 'pos' : me.delta < 0 ? 'neg' : ''}">${me.delta > 0 ? '+' : ''}${me.delta} pts</div><div class="muted">${fmt(me.points)} points${!d.ranked ? ' · partie non classée' : ''}</div>
      ${me.rankUp ? '<div class="chip ok" style="margin-top:6px">NOUVEAU RANG !</div>' : ''}${me.rankDown ? '<div class="chip red" style="margin-top:6px">RANG PERDU</div>' : ''}</div></div>` : ''}
    ${me.payout ? `<div class="pot"><div class="small muted">GAIN</div><div class="v" style="font-size:34px">+${money(me.payout)}</div></div>` : ''}
    <div class="card holo" style="margin-top:18px"><table class="lb"><tr><th>Joueur</th><th>Équipe</th><th>Éliminations</th><th>Morts</th><th></th></tr>
    ${d.players.sort((a, b) => b.kills - a.kills).map((p) => `<tr><td><b>${esc(p.name)}</b></td><td style="color:${p.team === 'A' ? 'var(--lg-red)' : 'var(--lg-blue)'}">${esc(d.teamNames[p.team])}</td><td>${p.kills}</td><td>${p.deaths}</td><td class="small muted">${p.result === 'left' ? 'abandon' : ''}</td></tr>`).join('')}</table></div>
    <div class="muted small" style="margin-top:12px">Retour au RP dans quelques secondes…</div></div>`;
  r.classList.remove('hidden');
  if (res === 'win') confetti(['#3EE6B0', '#B57BFF', '#FFC94A', '#ffffff']);
  if (me.rankUp) setTimeout(() => Snd.play('rankup'), 1600);
  setTimeout(() => r.classList.add('hidden'), 12500);
}
window.addEventListener('message', (e) => {
  const m = e.data || {};
  const fn = ON[m.action];
  if (fn) { try { fn(m.data); } catch (err) { console.error('[lasergame]', m.action, err); } }
});

/* ------------------------------------------------------------------ mode démo (navigateur, tests) */
const Demo = {
  post(name, data) {
    if (name !== 'rpc') return Promise.resolve({ ok: true });
    const [a0] = data.args || [];
    const R = {
      'ui:init': Demo.init, 'profile:get': Demo.init.profile, 'history:get': Demo.history, 'lb:get': Demo.board(a0), 'list:get': Demo.init.games,
      'admin:open': Demo.admin, 'admin:logs': Demo.logs, 'lobby:nearby': [{ id: 12, name: 'Lina Morel' }, { id: 31, name: 'Sacha Diallo' }],
      'admin:players.search': [{ citizenid: 'ELY12345', firstname: 'Nora', lastname: 'Vance', points: 1612, wins: 48, losses: 20, banned: 0, rank: 'diamond' }],
      'admin:arena': { message: 'Arène enregistrée.', arenas: Demo.admin.settings.arenas },
    };
    return Promise.resolve({ ok: true, data: R[data.name] ?? true });
  },
  board(kind) {
    const names = [['Nora', 'Vance'], ['Kenji', 'Mori'], ['Lina', 'Morel'], ['Sacha', 'Diallo'], ['Ivy', 'Stone'], ['Malo', 'Ruiz'], ['Yara', 'Benali'], ['Tom', 'Keller'], ['Ezra', 'Lopez'], ['Mia', 'Hart']];
    const rk = ['legend', 'grandmaster', 'master', 'diamond', 'diamond', 'platinum', 'gold', 'gold', 'silver', 'bronze'];
    return { kind: kind || 'pvp_points', page: 1, pages: 3, total: 27, t: Date.now() / 1000, rows: names.map(([f, l], i) => ({ pos: i + 1, firstname: f, lastname: l,
      v: 2140 - i * 61, rank: rk[i], wins: 120 - i * 9, losses: 30 + i * 4, points: 2140 - i * 61, kills: 3000 - i * 200 })) };
  },
};
Demo.init = {
  me: { id: 1, name: 'Elyzea Fa', firstname: 'Elyzea', lastname: 'Fa' }, isAdmin: true, spectator: true,
  profile: { firstname: 'Elyzea', lastname: 'Fa', points: 1612, peak: 1688, rank: 'diamond', rankLabel: 'ELYZEA DIAMOND', progress: 0.41, position: 7, next: { id: 'master', label: 'ELYZEA MASTER', min: 1700 },
    wins: 48, losses: 21, draws: 3, kills: 512, deaths: 233, matches: 72, ratio: 2.2, streak: 3, bestStreak: 9 },
  pvp: { enabled: true, formats: [1, 2, 3, 4, 5, 6].map((n) => ({ id: `${n}v${n}`, label: `${n} VS ${n}`, size: n })), rounds: [1, 3, 5, 7, 9], roundTimes: [60, 90, 120, 180, 240, 300], defaultRounds: 3, defaultRoundTime: 120, ranked: { public: true, private: false } },
  stake: { enabled: true, min: 0, max: 250000, step: 100, fee: 0 },
  maps: [
    { id: 'arena_1', label: 'ENTREPÔT NÉON', size: 'M', maxPerTeam: 4, description: 'Docks de Elysian Island, deux étages', shape: { poly: [[8, 20], [92, 20], [92, 80], [8, 80]], A: [[16, 30], [16, 50], [16, 70]], B: [[84, 30], [84, 50], [84, 70]] } },
    { id: 'arena_2', label: 'TOITS DE VINEWOOD', size: 'L', maxPerTeam: 6, description: 'Trois toits reliés', shape: { poly: [[5, 40], [40, 5], [95, 30], [80, 95], [20, 85]], A: [[20, 50], [25, 60]], B: [[75, 40], [70, 70]] } },
    { id: 'arena_3', label: 'PARKING DU PIER', size: 'S', maxPerTeam: 2, description: '', shape: { poly: [[30, 5], [70, 5], [70, 95], [30, 95]], A: [[50, 12]], B: [[50, 88]] } },
  ],
  categories: [['melee', 'Mêlée'], ['pistol', 'Pistolet'], ['smg', 'Mitraillette'], ['rifle', 'Fusil d\'assaut'], ['sniper', 'Sniper']].map(([id, label]) => ({ id, label })),
  ranks: [['bronze', 'ELYZEA BRONZE', 0, '#C98A55'], ['silver', 'ELYZEA SILVER', 1100, '#C9D3E0'], ['gold', 'ELYZEA GOLD', 1250, '#FFC94A'], ['platinum', 'ELYZEA PLATINUM', 1400, '#7FE3D8'],
    ['diamond', 'ELYZEA DIAMOND', 1550, '#6FB6FF'], ['master', 'ELYZEA MASTER', 1700, '#B57BFF'], ['grandmaster', 'ELYZEA GRANDMASTER', 1850, '#FF4D8D'], ['legend', 'ELYZEA LEGEND', 2000, '#FFE7A3']]
    .map(([id, label, min, color], i) => ({ id, label, min, color, tier: i + 1 })),
  teams: { A: { name: 'ROUGE', hex: '#FF2D46' }, B: { name: 'BLEUE', hex: '#288CFF' } },
  games: [
    { uid: 'PVP1', mode: 'pvp', name: 'Finale du jeudi', host: 'Nora Vance', format: '5v5', mapLabel: 'TOITS DE VINEWOOD', players: 10, max: 10, phase: 'round', score: { A: 2, B: 1 }, round: 4, stake: 5000, spectators: 3, ranked: true },
    { uid: 'PVP2', mode: 'pvp', name: 'Duel au néon', host: 'Kenji Mori', format: '1v1', mapLabel: 'ENTREPÔT NÉON', players: 1, max: 2, phase: 'lobby', stake: 0, ranked: true },
    { uid: 'PVP3', mode: 'pvp', name: 'Entraînement', host: 'Lina Morel', format: '3v3', mapLabel: 'PARKING DU PIER', players: 4, max: 6, phase: 'lobby', stake: 1000, hasPassword: true },
  ],
};
Demo.history = [
  { mode: 'pvp', format: '5v5', map: 'arena_2', mapLabel: 'TOITS DE VINEWOOD', result: 'win', score_a: 3, score_b: 1, kills: 9, deaths: 3, points_delta: 24, payout: 10000, created_at: 1761990000 },
  { mode: 'pvp', format: '1v1', map: 'arena_3', mapLabel: 'PARKING DU PIER', result: 'loss', score_a: 1, score_b: 2, kills: 3, deaths: 4, points_delta: -15, payout: 0, created_at: 1761800000 },
];
Demo.logs = [{ category: 'money', name: 'Nora Vance', message: 'gain de 25 000 $ (partie PVP1761990000001)', created_at: 1761990000 },
  { category: 'security', name: 'Inconnu', message: 'événement suspect : cadence de tir dépassée (n°1)', created_at: 1761980000 },
  { category: 'admin', name: 'Staff Elyzea', message: 'réglage modifié : stake', created_at: 1761970000 }];
Demo.admin = {
  games: [{ uid: 'PVP1761990000001', mode: 'pvp', name: 'Finale du jeudi', host: 'Nora Vance', phase: 'round', map: 'TOITS DE VINEWOOD', format: '5v5', score: { A: 2, B: 1 }, round: 4, players: [{ id: 3, name: 'Nora Vance' }, { id: 7, name: 'Kenji Mori' }] }],
  settings: {
    framework: 'elyzea',
    pvp: { enabled: true, requireEqualTeams: true, requireFullTeams: false, oneHitElimination: false, friendlyFire: false, shield: 100, minRankedDuration: 45, lobbyIdleTimeout: 1200, defaultRoundTime: 120, defaultRounds: 3 },
    stake: { enabled: true, min: 0, max: 250000, step: 100, houseFeePct: 0 },
    formats: Demo.init.pvp.formats.map((f) => ({ ...f, enabled: true })), ranks: Demo.init.ranks,
    weapons: [{ id: 'photon_p9', label: 'Photon P9', cat: 'pistol', damage: 25, range: 60, rpm: 240, spread: 1.2, mag: 12, reload: 1400 }, { id: 'helios', label: 'Hélios Railgun', cat: 'sniper', damage: 90, range: 250, rpm: 45, spread: 0.05, mag: 5, reload: 3000 }],
    teams: { A: 'ROUGE', B: 'BLEUE' }, adminMenu: true,
    arenas: [
      { ...Demo.init.maps[0], enabled: true, valid: true, issues: [], area: 3120, corners: 4, spawnsA: 3, spawnsB: 3, time: 22, weather: 'CLEAR', zone: { minZ: 4.5, maxZ: 38 }, inUse: 'running' },
      { ...Demo.init.maps[1], enabled: true, valid: true, issues: [], area: 5400, corners: 5, spawnsA: 2, spawnsB: 2, zone: { minZ: 140, maxZ: 170 } },
      { id: 'arena_4', label: 'CHANTIER (en construction)', size: '—', maxPerTeam: 6, enabled: false, valid: false, issues: ['aucune apparition pour l\'équipe BLEUE'], area: 900, corners: 4, spawnsA: 2, spawnsB: 0,
        zone: { minZ: 20, maxZ: 50 }, shape: { poly: [[10, 10], [90, 10], [90, 90], [10, 90]], A: [[20, 20], [20, 30]], B: [] } },
    ],
    npcs: [{ id: 'lg_accueil', label: 'LaserGame ElyzeaFA', model: 's_m_y_ammucity_01', x: -1256.66, y: -1440.81, z: 4.37 }],
  },
};

(function demo() {
  if (IN_GAME) return;
  document.body.classList.add('demo');
  const q = new URLSearchParams(location.search).get('demo') || 'home';
  const send = (action, data) => window.postMessage({ action, data }, '*');
  const open = (tab, admin) => send('open', { init: Demo.init, tab, admin });
  const lobbyPvp = { uid: 'PVP2', mode: 'pvp', name: 'Duel au néon', host: 'Elyzea Fa', isHost: true, format: '3v3', size: 3, map: 'arena_1', mapLabel: 'ENTREPÔT NÉON', rounds: 5, roundTime: 120, category: 'rifle', stake: 5000, pot: 25000, ranked: true,
    teamNames: { A: 'ROUGE', B: 'BLEUE' }, teams: { A: [{ id: 1, name: 'Elyzea Fa', ready: true, weapon: 'nova_ar', host: true, rank: 'diamond', me: true }, { id: 4, name: 'Malo Ruiz', ready: false, weapon: 'spectre', rank: 'gold' }],
      B: [{ id: 5, name: 'Kenji Mori', ready: true, weapon: 'quasar', rank: 'grandmaster' }, { id: 6, name: 'Ivy Stone', ready: true, weapon: 'nova_ar', rank: 'platinum' }, { id: 8, name: 'Tom Keller', ready: false, weapon: 'nova_ar', rank: 'silver' }] },
    weapons: [{ id: 'nova_ar', label: 'Nova AR', damage: 20, range: 90, rpm: 560 }, { id: 'spectre', label: 'Spectre-7', damage: 22, range: 95, rpm: 520 }, { id: 'quasar', label: 'Quasar Bullpup', damage: 26, range: 100, rpm: 480 }] };
  setTimeout(() => {
    if (q === 'home' || q === 'pvp' || q === 'ranks' || q === 'profile' || q === 'history' || q === 'settings') open(q);
    else if (q === 'admin') open('admin', true);
    else if (q === 'arenas') { open('admin', true); setTimeout(() => { S.adminTab = 'arenas'; pageAdmin($('#page')); }, 150); }
    else if (q === 'lobby') { open('pvp'); setTimeout(() => send('lobby', lobbyPvp), 100); }
    else if (q === 'create') { open('pvp'); setTimeout(() => { S.sub.pvp = 'create'; render(); }, 100); }
    else if (q === 'loading') { send('loading', { map: 'arena_2', mapLabel: 'TOITS DE VINEWOOD', mode: 'pvp', name: 'Finale' }); send('loadingProgress', 0.64); }
    else if (q === 'hud-pvp') {
      S.init = Demo.init;
      send('hud', { mode: 'pvp', role: 'player', team: 'A', rounds: 5, shield: 100, maxShield: 100 });
      send('pvpState', { score: { A: 2, B: 1 }, round: 4, rounds: 5, endsAt: Date.now() / 1000 + 74, serverTime: Date.now() / 1000, myTeam: 'A', role: 'player',
        players: [{ id: 1, name: 'Elyzea Fa', team: 'A', alive: true, shield: 64, kills: 6, me: true }, { id: 4, name: 'Malo Ruiz', team: 'A', alive: true, shield: 100, kills: 2 }, { id: 2, name: 'Lina Morel', team: 'A', alive: false, shield: 0, kills: 1 },
          { id: 5, name: 'Kenji Mori', team: 'B', alive: true, kills: 4 }, { id: 6, name: 'Ivy Stone', team: 'B', alive: false, kills: 2 }, { id: 8, name: 'Tom Keller', team: 'B', alive: true, kills: 1 }] });
      send('shield', { shield: 64, max: 100 }); send('crosshair', true);
      send('ammo', { label: 'Nova AR', ammo: 17, mag: 30 });
      send('killfeed', { killer: 'Elyzea Fa', killerTeam: 'A', victim: 'Ivy Stone', victimTeam: 'B', weapon: 'Nova AR', mine: true });
      send('killfeed', { killer: 'Kenji Mori', killerTeam: 'B', victim: 'Lina Morel', victimTeam: 'A', weapon: 'Quasar Bullpup' });
      send('prompt', { key: 'E', title: 'LaserGame', label: 'Ouvrir le LaserGame' });
    } else if (q === 'results') {
      S.init = Demo.init;
      send('matchEnd', { winner: 'A', score: { A: 3, B: 1 }, ranked: true, mvp: 'Elyzea Fa', teamNames: { A: 'ROUGE', B: 'BLEUE' },
        players: [{ name: 'Elyzea Fa', team: 'A', kills: 11, deaths: 3 }, { name: 'Malo Ruiz', team: 'A', kills: 6, deaths: 5 }, { name: 'Kenji Mori', team: 'B', kills: 7, deaths: 6 }, { name: 'Ivy Stone', team: 'B', kills: 2, deaths: 7 }],
        me: { result: 'win', team: 'A', kills: 11, deaths: 3, payout: 10000, delta: 28, points: 1712, rank: 'master', rankLabel: 'ELYZEA MASTER', rankUp: true } });
    }
  }, 50);
})();
