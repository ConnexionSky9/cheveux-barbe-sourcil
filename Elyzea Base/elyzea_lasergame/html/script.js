/* =====================================================================
   ELYZEA LASERGAME · INTERFACE (NUI)
   Menu (accueil, PVP, Zombie, classements, profil, historique, paramètres, staff),
   lobbies, HUD de partie, chargement, résultats, invites, notifications, sons.
   Hors FiveM (navigateur), un mode démo avec des données fictives permet de tester l'interface :
   index.html?demo=home | pvp | lobby | zombie | zlobby | ranks | profile | history | admin | hud-pvp | hud-zombie | results | loading
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
  lb: { group: 'pvp', kind: 'pvp_points', page: 1, data: null }, create: {}, zcreate: {}, hud: null, timer: null, lbTimer: null };

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
  zombie: '<path d="M12 2a8 8 0 0 0-8 8v3l-2 3h4v4h3v-2h2v2h2v-2h2v2h3v-4h4l-2-3v-3a8 8 0 0 0-8-8zm-3 7a2 2 0 1 1 0 4 2 2 0 0 1 0-4zm6 0a2 2 0 1 1 0 4 2 2 0 0 1 0-4z"/>',
  ranks: '<path d="M7 3h10v3a5 5 0 0 1-4 4.9V14h3v3H8v-3h3v-3.1A5 5 0 0 1 7 6zM3 4h3v3a3 3 0 0 1-3-3zm15 0h3a3 3 0 0 1-3 3zM6 19h12v2H6z"/>',
  profile: '<path d="M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10zm0 2c-5 0-9 2.5-9 5.5V22h18v-2.5c0-3-4-5.5-9-5.5z"/>',
  history: '<path d="M13 3a9 9 0 1 0 8.5 12h-2.1A7 7 0 1 1 13 5V2l4 4-4 4V7zm-1 4h2v5l4 2-1 1.7-5-3z"/>',
  settings: '<path d="M19.4 13a7.5 7.5 0 0 0 0-2l2.1-1.6-2-3.5-2.5 1a7 7 0 0 0-1.7-1L15 3h-4l-.4 2.9a7 7 0 0 0-1.7 1l-2.5-1-2 3.5L6.6 11a7.5 7.5 0 0 0 0 2l-2.1 1.6 2 3.5 2.5-1a7 7 0 0 0 1.7 1L11 21h4l.4-2.9a7 7 0 0 0 1.7-1l2.5 1 2-3.5zM13 15.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z"/>',
  staff: '<path d="M12 2l8 3v6c0 5-3.4 9.4-8 11-4.6-1.6-8-6-8-11V5zm-1 13l6-6-1.4-1.4L11 12.2 8.4 9.6 7 11z"/>',
  // atouts
  juggernaut: '<path d="M12 2l8 3v6c0 5-3.4 9.4-8 11-4.6-1.6-8-6-8-11V5zm0 4l-4 2v3c0 3 1.7 5.6 4 6.7 2.3-1.1 4-3.7 4-6.7V8z"/>',
  speed: '<path d="M13 2L4 14h6l-1 8 9-12h-6z"/>',
  fastreload: '<path d="M12 4V1L7 6l5 5V7a5 5 0 1 1-5 5H5a7 7 0 1 0 7-8z"/>',
  doubledmg: '<path d="M2 12l6-6v4h8V6l6 6-6 6v-4H8v4z"/>',
  acidres: '<path d="M12 2s-6 7-6 12a6 6 0 0 0 12 0c0-5-6-12-6-12zm-2 13a2 2 0 0 1-2-2h2z"/>',
  quickrevive: '<path d="M10 3h4v7h7v4h-7v7h-4v-7H3v-4h7z"/>',
  regen: '<path d="M12 21l-1.4-1.3C5.4 15 2 12 2 8.5A5.5 5.5 0 0 1 12 5a5.5 5.5 0 0 1 10 3.5c0 3.5-3.4 6.5-8.6 11.2z"/>',
  armor: '<path d="M5 3h14v8c0 5-3 8.6-7 10-4-1.4-7-5-7-10z"/>',
};
const svg = (name, size = 18) => `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="currentColor">${I[name] || ''}</svg>`;
const rankImg = (id, cls = 'rk') => `<img class="${cls}" src="ranks/${esc(id || 'bronze')}.png" alt="">`;
const rankOf = (id) => (S.init?.ranks || []).find((r) => r.id === id) || { label: 'ELYZEA BRONZE', color: '#C98A55' };
const mapOf = (id) => (S.init?.maps || []).find((m) => m.id === id) || { label: id };
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
  ['home', 'ACCUEIL', 'Bienvenue au complexe'], ['pvp', 'PVP ARENA', 'Laser compétitif 1v1 → 6v6'], ['zombie', 'MODE ZOMBIE', 'Survie de 1 à 4 joueurs'],
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
  const fn = { home: pageHome, pvp: pagePvp, zombie: pageZombie, ranks: pageRanks, profile: pageProfile, history: pageHistory, settings: pageSettings, admin: pageAdmin }[S.tab] || pageHome;
  fn(p);
}

/* ---------------- ACCUEIL */
function gameRow(g) {
  const run = g.phase !== 'lobby';
  const mode = g.mode === 'pvp' ? `<span class="chip">${esc(g.format)}</span>` : '<span class="chip ok">ZOMBIE</span>';
  const score = g.mode === 'pvp' && run ? `<span class="score"><span class="a">${g.score?.A ?? 0}</span> — <span class="b">${g.score?.B ?? 0}</span></span>` : (g.mode === 'zombie' && run ? `<span class="score">MANCHE ${g.round}</span>` : '');
  const action = run
    ? (S.init?.spectator ? `<button class="btn sm ghost" data-spec="${g.uid}">Regarder</button>` : '')
    : `<button class="btn sm" data-join="${g.uid}" data-mode="${g.mode}" data-pw="${g.hasPassword ? 1 : 0}">Rejoindre</button>`;
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
    <p>Deux équipes, des lasers, aucune seconde chance. Affronte les meilleurs de la ville en PVP classé, ou survis aux vagues du complexe ELYZEA-7.</p>
    <div class="row"><button class="btn red" data-tab="pvp">${svg('pvp')}PVP ARENA</button><button class="btn acid" data-tab="zombie">${svg('zombie')}MODE ZOMBIE</button></div>
  </div>
  <div class="grid g2" style="margin-top:16px">
    <div class="mode pvp" data-tab="pvp"><span class="chip">${S.init.pvp.enabled ? 'OUVERT' : 'FERMÉ'}</span><h2><span>PVP</span> <em>ARENA</em></h2><div class="muted">1v1 à 6v6 · 4 arènes · mises · 8 rangs</div></div>
    <div class="mode zb" data-tab="zombie"><span class="chip ok">${S.init.zombie.enabled ? 'OUVERT' : 'FERMÉ'}</span><h2>MODE ZOMBIE</h2><div class="muted">1 à 4 joueurs · 8 secteurs · atouts · armes murales</div></div>
  </div>
  <div class="grid g3" style="margin-top:16px;grid-template-columns:1.2fr 1fr 1fr">
    <div class="card holo"><h3>Matchs en direct</h3><div class="live">${running.length ? running.slice(0, 5).map(gameRow).join('') : '<div class="empty">Aucune partie en cours.</div>'}</div></div>
    <div class="card holo"><h3>Lobbies ouverts</h3><div class="live">${open.length ? open.slice(0, 5).map(gameRow).join('') : '<div class="empty">Aucun lobby : crée le tien !</div>'}</div></div>
    <div class="card holo" style="text-align:center">${rankImg(pr.rank, '')}<style>.card img{width:120px}</style>
      <div class="rankname" style="font-size:20px;color:${r.color}">${esc(r.label)}</div><div class="muted">${fmt(pr.points)} points${pr.position ? ' · #' + pr.position : ''}</div>
      <div class="bar" style="margin:12px 0 6px"><i style="width:${Math.round((pr.progress || 0) * 100)}%"></i></div>
      <div class="small muted">${pr.next ? `Prochain rang : ${esc(pr.next.label)} (${fmt(pr.next.min)})` : 'Rang maximum atteint'}</div>
      <div class="grid g3" style="margin-top:12px"><div class="stat"><div class="v">${pr.wins}</div><div class="l">Victoires</div></div><div class="stat"><div class="v">${pr.ratio}</div><div class="l">Ratio</div></div><div class="stat"><div class="v">${pr.zbBestRound}</div><div class="l">Manche Z</div></div></div>
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
    const c = Object.assign({ format: '2v2', map: (S.init.maps.find((m) => m.mode === 'pvp' && m.enabled) || {}).id, rounds: S.init.pvp.defaultRounds, roundTime: S.init.pvp.defaultRoundTime,
      category: 'rifle', stake: 0, private: false, password: '', name: '' }, S.create);
    S.create = c;
    p.innerHTML = tabs + `<div class="card holo"><h3>Nouvelle partie</h3>${createForm(c)}<div class="row" style="margin-top:18px"><button class="btn" data-act="create">Créer le lobby</button></div></div>`;
  }
}

function createForm(c) {
  const maps = S.init.maps.filter((m) => m.mode === 'pvp');
  return `<div class="grid g2">
    <div class="field"><label>Nom du match</label><input class="input" data-c="name" maxlength="28" value="${esc(c.name)}" placeholder="Partie de ${esc(S.init.me.firstname)}"></div>
    <div class="field"><label>Format</label><div class="seg">${S.init.pvp.formats.map((f) => `<button data-cs="format" data-v="${f.id}" class="${c.format === f.id ? 'on' : ''}">${esc(f.label)}</button>`).join('')}</div></div>
  </div>
  <div class="field" style="margin-top:14px"><label>Carte</label><div class="mapcards">${maps.map((m) => `<div class="mapcard ${c.map === m.id ? 'on' : ''} ${m.enabled ? '' : 'off'}" data-cs="map" data-v="${m.id}"><img src="images/maps/${m.id}.png"><div>${esc(m.label)} <span class="chip" style="float:right">${m.size}</span></div></div>`).join('')}</div></div>
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

/* ---------------- ZOMBIE */
function pageZombie(p) {
  if (S.lobby && S.lobby.mode === 'zombie') return renderZombieLobby(p);
  if (!S.init.zombie.enabled) { p.innerHTML = '<div class="empty">Le mode Zombie est fermé par le staff.</div>'; return; }
  const games = S.list.filter((g) => g.mode === 'zombie');
  const zm = mapOf('zombie_map');
  const z = S.zcreate;
  p.innerHTML = `<div class="grid g2" style="grid-template-columns:1.3fr 1fr">
    <div class="card holo"><h3>${esc(zm.label || 'Complexe Elyzea-7')}</h3><img src="images/maps/zombie_map.png" style="width:100%;border-radius:12px;border:1px solid var(--ely-line)">
      <p class="muted small">${esc(zm.description || '')}</p></div>
    <div class="grid" style="align-content:start">
      <div class="card holo"><h3>Survie</h3><p class="muted small">Pistolet laser, munitions illimitées, portes fermées. Gagne de l'argent Zombie en éliminant les vagues (jamais converti en argent RP).</p>
        <div class="grid g2"><button class="btn acid" data-act="zsolo">Partie solo</button><button class="btn ghost" data-act="zgroup">Créer un groupe</button></div>
        <div class="grid g2" style="margin-top:10px"><input class="input" id="zname" maxlength="28" placeholder="Nom du groupe" value="${esc(z.name || '')}"><input class="input" id="zpw" maxlength="16" placeholder="Mot de passe (facultatif)" value="${esc(z.password || '')}"></div></div>
      <div class="card holo"><h3>Groupes ouverts</h3><div class="live">${games.length ? games.map(gameRow).join('') : '<div class="empty">Aucun groupe.</div>'}</div></div>
      <div class="card holo"><h3>Atouts (max ${S.init.zombie.maxPerks})</h3><div class="row wrap">${S.init.zombie.perks.map((k) => `<span class="chip" style="color:${k.color};border-color:${k.color}55" title="${esc(k.desc)}">${svg(k.icon, 14)} ${esc(k.label)} · ${money(k.price)}</span>`).join('')}</div></div>
    </div></div>`;
}

function renderZombieLobby(p) {
  const L = S.lobby;
  const me = L.players.find((x) => x.id === S.init.me.id) || {};
  let slots = L.players.map((x) => `<div class="slot ${x.id === S.init.me.id ? 'me' : ''}"><div class="nm">${esc(x.name)} ${x.host ? '👑' : ''}</div><span class="rdy ${x.ready ? 'on' : ''}">${x.ready ? 'PRÊT' : 'ATTENTE'}</span>
    ${L.isHost && x.id !== S.init.me.id ? `<button class="btn sm ghost" data-zkick="${x.id}">✕</button>` : ''}</div>`).join('');
  for (let i = L.players.length; i < L.max; i++) slots += '<div class="slot emptyslot">PLACE LIBRE</div>';
  p.innerHTML = `<div class="row" style="margin-bottom:14px"><div class="title" style="font-size:26px">${esc(L.name)}</div><div class="sp"></div>
    ${L.isHost ? '<button class="btn ghost sm" data-act="zinvite">Inviter</button>' : ''}<button class="btn ghost sm" data-act="leave">Quitter</button></div>
    <div class="grid g2"><div class="card holo"><h3>Escouade (${L.players.length}/${L.max})</h3>${slots}</div>
    <div class="card holo"><h3>${esc(L.mapLabel)}</h3><img src="images/maps/zombie_map.png" style="width:100%;border-radius:10px"></div></div>
    <div class="row" style="margin-top:16px"><button class="btn ${me.ready ? 'ghost' : 'ok'}" data-act="zready">${me.ready ? 'Annuler « prêt »' : 'Je suis prêt'}</button><div class="sp"></div>
    ${L.isHost ? '<button class="btn acid" data-act="zstart">Lancer la survie</button>' : '<span class="muted small">En attente de l\'hôte…</span>'}</div>`;
}

/* ---------------- CLASSEMENTS */
const LB = {
  pvp: [['pvp_points', 'Meilleurs joueurs', 'Points'], ['pvp_ratio', 'Meilleurs ratios', 'Ratio'], ['pvp_wins', 'Plus de victoires', 'Victoires'], ['pvp_rank', 'Meilleurs rangs', 'Pic'], ['pvp_streak', 'Plus longues séries', 'Série']],
  zombie: [['zb_round', 'Plus grandes manches', 'Manche'], ['zb_kills', 'Plus de zombies tués', 'Zombies'], ['zb_solo', 'Meilleurs joueurs solo', 'Manche solo'], ['zb_teams', 'Meilleures équipes', 'Manche'], ['zb_global', 'Meilleures performances', 'Manche']],
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
  const g = S.lb.group;
  p.innerHTML = `<div class="tabs">${[['pvp', 'PVP'], ['zombie', 'ZOMBIE']].map(([id, l]) => `<button data-lbg="${id}" class="${g === id ? 'on' : ''}">${l}</button>`).join('')}</div>
    <div class="seg" style="margin-bottom:14px">${LB[g].map(([k, l]) => `<button data-lbk="${k}" class="${S.lb.kind === k ? 'on' : ''}">${l}</button>`).join('')}</div>
    <div class="card holo" id="board"><div class="empty">Chargement…</div></div>`;
  loadBoard();
  S.lbTimer = setInterval(loadBoard, 30000);   // actualisation automatique
}
function drawBoard() {
  const d = S.lb.data;
  if (!d || !$('#board')) return;
  d.rows = asList(d.rows);
  d.page = Number(d.page) || 1; d.pages = Math.max(1, Number(d.pages) || 1); d.total = Number(d.total) || 0;
  const def = [...LB.pvp, ...LB.zombie].find((x) => x[0] === d.kind) || [];
  const team = d.kind === 'zb_teams' || d.kind === 'zb_global';
  const zb = d.kind.startsWith('zb');
  const rows = d.rows.map((r) => `<tr class="${r.pos <= 3 ? 'top' + r.pos : ''}"><td class="pos">#${r.pos}</td>
    <td>${!zb ? rankImg(r.rank) + ' ' : ''}<b>${esc(team ? r.names : `${r.firstname} ${r.lastname}`)}</b></td>
    <td class="score">${esc(r.v)}</td>
    <td class="muted small">${zb ? (team ? `${r.players} joueur(s) · ${fmt(r.kills)} zombies · ${dateFr(r.created_at)}` : `${fmt(r.zb_kills ?? r.v)} zombies · ${money(r.zb_money)} · ${r.zb_games} parties · ${dateFr(r.zb_best_date)}`)
      : `${r.wins ?? '—'} V · ${r.losses ?? '—'} D · ${fmt(r.points)} pts`}</td></tr>`).join('');
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
  <div class="card holo" style="margin-top:16px"><h3>Mode Zombie</h3><div class="grid g4">${[['Meilleure manche', pr.zbBestRound], ['Meilleure manche solo', pr.zbBestSolo], ['Zombies tués', fmt(pr.zbKills)], ['Argent Zombie gagné', money(pr.zbMoney)], ['Parties', pr.zbGames], ['Réanimations', pr.zbRevives], ['Date du record', dateFr(pr.zbBestDate)]]
    .map(([l, v]) => `<div class="stat"><div class="v" style="font-size:20px">${esc(v)}</div><div class="l">${l}</div></div>`).join('')}</div></div>`;
}

/* ---------------- HISTORIQUE */
async function pageHistory(p) {
  p.innerHTML = '<div class="empty">Chargement…</div>';
  const r = await rpc('history:get');
  const rows = r.ok ? asList(r.data) : [];
  const res = { win: ['VICTOIRE', 'ok'], loss: ['DÉFAITE', 'red'], draw: ['ÉGALITÉ', ''], left: ['ABANDON', 'warn'] };
  p.innerHTML = `<div class="card holo"><h3>Dernières parties</h3>${rows.length ? `<table class="lb"><tr><th>Date</th><th>Mode</th><th>Carte</th><th>Résultat</th><th>Score / manche</th><th>É / M</th><th>Points</th><th>Gain</th></tr>
    ${rows.map((h) => { const rr = h.mode === 'zombie' ? [`MANCHE ${h.round}`, 'ok'] : (res[h.result] || [h.result, '']);
      return `<tr><td class="small">${dateFr(h.created_at)}</td><td>${h.mode === 'pvp' ? `<span class="chip">${esc(h.format || 'PVP')}</span>` : '<span class="chip ok">ZOMBIE</span>'}</td>
      <td>${esc(mapOf(h.map).label || h.map || '')}</td><td><span class="chip ${rr[1]}">${rr[0]}</span></td>
      <td class="score">${h.mode === 'pvp' ? `<span class="a">${h.score_a ?? 0}</span> — <span class="b">${h.score_b ?? 0}</span>` : h.round}</td>
      <td>${h.kills} / ${h.deaths}</td><td style="color:${h.points_delta > 0 ? 'var(--ely-ok)' : h.points_delta < 0 ? 'var(--lg-red)' : 'inherit'}">${h.mode === 'pvp' ? (h.points_delta > 0 ? '+' : '') + h.points_delta : '—'}</td>
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
    <p class="small muted" style="margin-top:16px">Touches : <b>E</b> interagir (modifiable dans Paramètres GTA › Raccourcis › FiveM), <b>F7</b> menu de partie (quitter), <b>R</b> recharger, <b>1 / 2</b> changer d'arme (Zombie), <b>← →</b> changer de joueur observé.</p></div>`;
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
  const tabs = [['games', 'Parties'], ['pvp', 'PVP'], ['weapons', 'Armes'], ['zombie', 'Zombie'], ['zprices', 'Prix Zombie'], ['maps', 'Cartes'], ['npcs', 'PNJ'], ['players', 'Joueurs'], ['logs', 'Journaux']];
  let h = `<div class="tabs">${tabs.map(([id, l]) => `<button data-atab="${id}" class="${t === id ? 'on' : ''}">${l}</button>`).join('')}</div>`;
  if (t === 'games') {
    const games = S.admin.games;
    h += `<div class="card holo"><h3>Parties et lobbies (${games.length})</h3>${games.length ? `<table class="adm-table"><tr><th>Partie</th><th>Mode</th><th>Phase</th><th>Carte</th><th>Joueurs</th><th>Score</th><th></th></tr>
      ${games.map((g) => `<tr><td><b>${esc(g.name)}</b><div class="small muted">${g.uid} · hôte ${esc(g.host)}</div></td><td>${g.mode}${g.format ? ' ' + g.format : ''}</td><td>${g.phase}</td><td>${esc(g.map)}</td>
      <td>${g.players.map((x) => `<div class="small">${esc(x.name)} <button class="btn sm ghost" data-akick="${g.uid}|${x.id}">expulser</button></div>`).join('')}</td>
      <td>${g.mode === 'pvp' ? `${g.score?.A ?? 0} - ${g.score?.B ?? 0}` : `manche ${g.round || 0}`}</td><td><button class="btn sm red" data-astop="${g.uid}">Arrêter</button></td></tr>`).join('')}</table>` : '<div class="empty">Aucune partie.</div>'}
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
    h += `<div class="card holo"><h3>Armes laser</h3><table class="adm-table"><tr><th>Arme</th><th>Cat.</th><th>Dégâts PVP</th><th>Dégâts Zombie</th><th>Portée</th><th>Cadence</th><th>Dispersion</th><th>Chargeur</th><th>Recharge ms</th><th>Active</th><th></th></tr>
      ${A.weapons.map((w) => `<tr><td><b>${esc(w.label)}</b>${w.zombieOnly ? ' <span class="chip ok">Z</span>' : ''}</td><td>${esc(catLabel(w.cat))}</td>
      ${['damage', 'zDamage', 'range', 'rpm', 'spread', 'mag', 'reload'].map((k) => `<td>${num(`w.${w.id}.${k}`, w[k], 72)}</td>`).join('')}
      <td><div class="toggle ${w.disabled ? '' : 'on'}" data-awoff="${w.id}"></div></td><td><button class="btn sm" data-awsave="${w.id}">OK</button></td></tr>`).join('')}</table></div>`;
  } else if (t === 'zombie') {
    const Z = A.zombie;
    h += `<div class="grid g2"><div class="card holo"><h3>Manches et difficulté</h3><div class="row" style="margin-bottom:8px"><div class="toggle ${Z.enabled ? 'on' : ''}" data-azon></div><span>Mode Zombie activé</span></div>
      <table class="adm-table">${[['countBase', 'Zombies manche 1'], ['countPerRound', '+ zombies / manche'], ['countMax', 'Zombies max / manche'], ['maxAlive', 'Présents en même temps'], ['hpBase', 'Résistance de base'], ['hpPerRound', '+ résistance / manche'], ['hpLinearUntil', 'Croissance linéaire jusqu\'à'], ['hpGrowth', 'Puis × par manche'], ['damageBase', 'Dégâts de base'], ['damagePerRound', '+ dégâts / manche'], ['damageMax', 'Dégâts max'], ['runFromRound', 'Course dès la manche'], ['sprintFromRound', 'Sprint dès la manche'], ['speedRamp', 'Accélération'], ['intermission', 'Pause entre manches (s)'], ['spawnInterval', 'Intervalle d\'apparition (ms)']]
        .map(([k, l]) => `<tr><td>${l}</td><td>${num('zr.' + k, Z.rounds[k])}</td></tr>`).join('')}</table><button class="btn sm" data-asave="zombieRounds">Enregistrer</button></div>
      <div class="grid" style="align-content:start"><div class="card holo"><h3>Types de zombies</h3><table class="adm-table"><tr><th>Type</th><th>Résist. ×</th><th>Dégâts ×</th><th>Vitesse ×</th><th>Récompense</th><th>Poids</th><th>Dès manche</th><th></th></tr>
        ${Z.types.map((z) => `<tr><td>${esc(z.label)}</td>${['hp', 'damage', 'speed', 'reward', 'weight', 'minRound'].map((k) => `<td>${num(`zt.${z.id}.${k}`, z[k], 62)}</td>`).join('')}<td><button class="btn sm" data-aztype="${z.id}">OK</button></td></tr>`).join('')}</table></div>
      <div class="card holo"><h3>Argent Zombie et joueurs</h3><table class="adm-table">${[['hit', 'Par impact'], ['meleeKillBonus', 'Bonus corps à corps'], ['reviveBonus', 'Bonus réanimation'], ['roundBonus', 'Bonus de manche'], ['startMoney', 'Argent de départ']].map(([k, l]) => `<tr><td>${l}</td><td>${num('zm.' + k, Z.money[k])}</td></tr>`).join('')}
        ${[['health', 'Vie du joueur'], ['regenDelay', 'Délai de régénération (ms)'], ['regenPerSecond', 'Régénération / s'], ['bleedout', 'Temps à terre (s)'], ['reviveTime', 'Durée de réanimation (s)']].map(([k, l]) => `<tr><td>${l}</td><td>${num('zp.' + k, Z.player[k])}</td></tr>`).join('')}</table>
        <div class="row"><button class="btn sm" data-asave="zombieMoney">Enregistrer l'argent</button><button class="btn sm" data-asave="zombiePlayer">Enregistrer les joueurs</button></div></div></div></div>`;
  } else if (t === 'zprices') {
    const Z = A.zombie;
    const wopts = (sel) => A.weapons.map((w) => `<option value="${w.id}" ${w.id === sel ? 'selected' : ''}>${esc(w.label)}</option>`).join('');
    h += `<div class="grid g3"><div class="card holo"><h3>Portes</h3><table class="adm-table">${Z.doors.map((d) => `<tr><td>${esc(d.label)}<div class="small muted">${d.id}</div></td><td>${num('door.' + d.id, d.price)}</td><td><button class="btn sm" data-adoor="${d.id}">OK</button></td></tr>`).join('')}</table></div>
      <div class="card holo"><h3>Armes murales</h3><table class="adm-table">${Z.wallbuys.map((w) => `<tr><td><select class="input" data-wbw="${w.id}">${wopts(w.weapon)}</select><div class="small muted">${esc(w.sector)}</div></td><td>${num('wb.' + w.id, w.price, 80)}</td><td><button class="btn sm" data-awb="${w.id}">OK</button></td></tr>`).join('')}</table></div>
      <div class="card holo"><h3>Atouts</h3><table class="adm-table">${Z.perks.map((k) => `<tr><td>${esc(k.label)}</td><td>${num('perk.' + k.id, k.price, 80)}</td><td><div class="toggle ${k.disabled ? '' : 'on'}" data-aperkoff="${k.id}"></div></td><td><button class="btn sm" data-aperk="${k.id}">OK</button></td></tr>`).join('')}</table>
        <div class="row" style="margin-top:10px">Atouts max ${num('maxPerks', Z.maxPerks, 60)}<button class="btn sm" data-asave="maxPerks">OK</button></div></div></div>`;
  } else if (t === 'maps') {
    h += `<div class="grid g2">${A.maps.map((m) => `<div class="card holo"><div class="row"><h3 style="margin:0">${esc(m.label)}</h3><span class="chip">${m.mode.toUpperCase()} · ${m.size}</span><div class="sp"></div><div class="toggle ${m.enabled ? 'on' : ''}" data-amapt="${m.id}"></div></div>
      <img src="images/maps/${m.id}.png" style="width:100%;margin:10px 0;border-radius:10px">
      <div class="small muted">${m.objects} objets GTA V · ancre ${m.anchor.x.toFixed(1)}, ${m.anchor.y.toFixed(1)}, ${m.anchor.z.toFixed(1)} · cap ${m.anchor.h}°${m.moved ? ' · <b style="color:var(--ely-warn)">déplacée</b>' : ''}</div>
      <div class="row wrap" style="margin-top:10px"><button class="btn sm" data-amap="${m.id}|here">Placer ici (ma position)</button><button class="btn sm ghost" data-amap="${m.id}|preview">Aperçu en jeu</button>
      <button class="btn sm ghost" data-amap="${m.id}|tp">Me téléporter</button>${m.moved ? `<button class="btn sm ghost" data-amap="${m.id}|reset">Position d'origine</button>` : ''}</div></div>`).join('')}</div>`;
  } else if (t === 'npcs') {
    h += `<div class="card holo"><h3>PNJ LaserGame</h3><p class="small muted">Les PNJ peuvent aussi être posés avec l'éditeur de map d'admin_menu (rôle « LaserGame »).</p>
      <table class="adm-table"><tr><th>Nom</th><th>Modèle</th><th>Position</th><th></th></tr>${A.npcs.map((n) => `<tr><td>${esc(n.label)}</td><td>${esc(n.model)}</td><td class="small">${n.x.toFixed(1)}, ${n.y.toFixed(1)}, ${n.z.toFixed(1)}</td><td><button class="btn sm red" data-anpcdel="${esc(n.id)}">Retirer</button></td></tr>`).join('')}</table>
      <div class="row" style="margin-top:12px"><input class="input" id="npcLabel" placeholder="Nom affiché" style="max-width:220px"><input class="input" id="npcModel" placeholder="Modèle (s_m_y_ammucity_01)" style="max-width:260px"><button class="btn sm" data-act="npcadd">Poser ici</button><button class="btn sm ghost" data-act="npcrestore">Rétablir ceux du fichier</button></div></div>`;
  } else if (t === 'players') {
    h += `<div class="card holo"><h3>Joueurs</h3><div class="row"><input class="input" id="psearch" placeholder="Nom RP ou identifiant…" style="max-width:340px"><button class="btn sm" data-act="psearch">Rechercher</button></div><div id="presults" style="margin-top:12px"></div></div><div id="pdetail" style="margin-top:16px"></div>`;
  } else if (t === 'logs') {
    const cat = S.sub.logcat || '';
    h += `<div class="card holo"><div class="seg" style="margin-bottom:12px">${[['', 'Tous'], ['admin', 'Staff'], ['money', 'Argent'], ['pvp', 'PVP'], ['zombie', 'Zombie'], ['security', 'Sécurité'], ['error', 'Erreurs']].map(([id, l]) => `<button data-logcat="${id}" class="${cat === id ? 'on' : ''}">${l}</button>`).join('')}</div><div id="logs"><div class="empty">Chargement…</div></div></div>`;
    rpc('admin:logs', cat, 1).then((r) => { const el = $('#logs'); if (el) el.innerHTML = r.ok && r.data.length ? r.data.map((l) => `<div class="log ${l.category}"><span class="muted">${dateFr(l.created_at)} [${l.category}]</span> ${esc(l.name ? l.name + ' : ' : '')}${esc(l.message)}</div>`).join('') : '<div class="empty">Aucun journal.</div>'; });
  }
  p.innerHTML = h;
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
    <div class="muted small">${esc(pr.citizenid)} · ${fmt(pr.points)} pts · ${pr.wins} V / ${pr.losses} D · manche Z ${pr.zbBestRound}${pr.banned ? ' · <b style="color:var(--lg-red)">EXCLU</b> ' + esc(pr.banReason || '') : ''}${pr.online ? ' · <span style="color:var(--ely-ok)">en ligne</span>' : ''}</div></div></div>
    <div class="row wrap" style="margin-top:12px"><input class="input" id="ppoints" value="${pr.points}" style="width:110px"><button class="btn sm" data-pset="points">Fixer les points</button>
      <select class="input" id="prank" style="width:200px">${S.init.ranks.map((k) => `<option value="${k.id}" ${k.id === pr.rank ? 'selected' : ''}>${esc(k.label)}</option>`).join('')}</select><button class="btn sm" data-pset="rank">Fixer le rang</button>
      <button class="btn sm ghost" data-pset="reset:pvp">Reset PVP</button><button class="btn sm ghost" data-pset="reset:zombie">Reset Zombie</button><button class="btn sm ghost" data-pset="reset:all">Reset tout</button></div>
    <div class="row wrap" style="margin-top:10px">${pr.banned ? '<button class="btn sm ok" data-pset="unexclude">Lever l\'exclusion</button>' : '<input class="input" id="pbanr" placeholder="Raison" style="max-width:260px"><input class="input" id="pbanh" placeholder="Heures (0 = définitif)" style="width:170px"><button class="btn sm red" data-pset="exclude">Exclure du LaserGame</button>'}</div>
    <h3 style="margin-top:16px">Historique</h3>${r.data.history.slice(0, 12).map((h) => `<div class="log ${h.mode}">${dateFr(h.created_at)} · ${h.mode} · ${h.result}${h.mode === 'pvp' ? ` · ${h.kills}/${h.deaths} · ${h.points_delta > 0 ? '+' : ''}${h.points_delta} pts` : ` · manche ${h.round} · ${h.kills} zombies`}</div>`).join('') || '<div class="empty">Aucune partie.</div>'}</div>`;
  S.sub.pcid = pr.citizenid;
}

/* ------------------------------------------------------------------ actions du menu */
document.addEventListener('click', async (e) => {
  const t = e.target.closest('[data-tab],[data-sub],[data-act],[data-join],[data-spec],[data-cs],[data-ct],[data-team],[data-weapon],[data-kick],[data-zkick],[data-qf],[data-lbg],[data-lbk],[data-lbp],[data-setb],[data-go],[data-atab],[data-asave],[data-apb],[data-askb],[data-aformat],[data-awsave],[data-awoff],[data-azon],[data-aztype],[data-adoor],[data-awb],[data-aperk],[data-aperkoff],[data-amap],[data-amapt],[data-anpcdel],[data-akick],[data-astop],[data-logcat],[data-pick],[data-pset],[data-invite]');
  if (!t) return;
  const d = t.dataset;
  if (d.tab) return go(d.tab);
  if (d.go) return go(d.go);
  if (d.sub) { S.sub[S.tab] = d.sub; return render(); }
  if (d.qf) { S.sub.quickFormat = d.qf; return render(); }
  if (d.cs) { S.create[d.cs] = isNaN(d.v) ? d.v : Number(d.v); return render(); }
  if (d.ct) { S.create[d.ct] = !S.create[d.ct]; return render(); }
  if (d.join) {
    let pw = '';
    if (d.pw === '1') { pw = prompt('Mot de passe de la partie :') || ''; }
    const r = await rpc(d.mode === 'zombie' ? 'zb:join' : 'pvp:join', d.join, pw);
    if (r.ok) go(d.mode === 'zombie' ? 'zombie' : 'pvp');
    return;
  }
  if (d.spec) { const r = await rpc('spectate:join', d.spec); if (r.ok) toast('Mode spectateur : ← → pour changer de joueur, F7 pour quitter.', 'info'); return; }
  if (d.team) return rpc('pvp:team', d.team);
  if (d.weapon) return rpc('pvp:weapon', d.weapon);
  if (d.kick) return rpc('pvp:kick', Number(d.kick));
  if (d.zkick) return rpc('zb:kick', Number(d.zkick));
  if (d.invite) { const r = await rpc(S.lobby?.mode === 'zombie' ? 'zb:invite' : 'pvp:invite', Number(d.invite)); if (r.ok) toast('Invitation envoyée.', 'success'); return; }
  if (d.lbg) { S.lb.group = d.lbg; S.lb.kind = LB[d.lbg][0][0]; S.lb.page = 1; return render(); }
  if (d.lbk) { S.lb.kind = d.lbk; S.lb.page = 1; return render(); }
  if (d.lbp !== undefined) { S.lb.page = Math.max(1, Math.min((S.lb.data && S.lb.data.pages) || 999, S.lb.page + Number(d.lbp))); return loadBoard(); }
  if (d.setb) { S.settings[d.setb] = !S.settings[d.setb]; saveSettings(); return render(); }
  // staff
  if (d.atab) { S.adminTab = d.atab; return pageAdmin($('#page')); }
  if (d.asave === 'pvp') return adminSet('pvp', Object.fromEntries(['shield', 'minRankedDuration', 'lobbyIdleTimeout', 'defaultRoundTime', 'defaultRounds'].map((k) => [k, nv('pvp.' + k)])));
  if (d.asave === 'stake') return adminSet('stake', Object.fromEntries(['min', 'max', 'step', 'houseFeePct'].map((k) => [k, nv('stake.' + k)])));
  if (d.asave === 'ranks') { for (const r of S.admin.settings.ranks.slice(1)) await rpc('admin:set', 'rank', { min: nv('rank.' + r.id) }, r.id); return loadAdmin(); }
  if (d.asave === 'zombieRounds') return adminSet('zombieRounds', Object.fromEntries(Object.keys(S.admin.settings.zombie.rounds).map((k) => [k, nv('zr.' + k)]).filter((x) => x[1] !== undefined && !isNaN(x[1]))));
  if (d.asave === 'zombieMoney') return adminSet('zombieMoney', Object.fromEntries(Object.keys(S.admin.settings.zombie.money).map((k) => [k, nv('zm.' + k)])));
  if (d.asave === 'zombiePlayer') return adminSet('zombiePlayer', Object.fromEntries(['health', 'regenDelay', 'regenPerSecond', 'bleedout', 'reviveTime'].map((k) => [k, nv('zp.' + k)])));
  if (d.asave === 'maxPerks') return adminSet('maxPerks', { value: nv('maxPerks') });
  if (d.apb) return adminSet('pvp', { [d.apb]: !S.admin.settings.pvp[d.apb] });
  if (d.askb) return adminSet('stake', { enabled: !S.admin.settings.stake.enabled });
  if (d.aformat) { const f = S.admin.settings.formats.find((x) => x.id === d.aformat); return adminSet('format', { enabled: !f.enabled }, d.aformat); }
  if (d.awsave) return adminSet('weapon', Object.fromEntries(['damage', 'zDamage', 'range', 'rpm', 'spread', 'mag', 'reload'].map((k) => [k, nv(`w.${d.awsave}.${k}`)])), d.awsave);
  if (d.awoff) { const w = S.admin.settings.weapons.find((x) => x.id === d.awoff); return adminSet('weapon', { disabled: !w.disabled }, d.awoff); }
  if (d.azon !== undefined) return adminSet('zombieEnabled', { enabled: !S.admin.settings.zombie.enabled });
  if (d.aztype) return adminSet('zombieType', Object.fromEntries(['hp', 'damage', 'speed', 'reward', 'weight', 'minRound'].map((k) => [k, nv(`zt.${d.aztype}.${k}`)])), d.aztype);
  if (d.adoor) return adminSet('door', { price: nv('door.' + d.adoor) }, d.adoor);
  if (d.awb) return adminSet('wallbuy', { price: nv('wb.' + d.awb), weapon: $(`[data-wbw="${d.awb}"]`).value }, d.awb);
  if (d.aperk) return adminSet('perk', { price: nv('perk.' + d.aperk) }, d.aperk);
  if (d.aperkoff) { const k = S.admin.settings.zombie.perks.find((x) => x.id === d.aperkoff); return adminSet('perk', { disabled: !k.disabled }, d.aperkoff); }
  if (d.amap) { const [id, action] = d.amap.split('|'); const r = await rpc('admin:map', id, action); if (r.ok && r.data && typeof r.data === 'object') { S.admin.settings = r.data; toast('Carte mise à jour.', 'success'); pageAdmin($('#page')); } return; }
  if (d.amapt) { const m = S.admin.settings.maps.find((x) => x.id === d.amapt); const r = await rpc('admin:map', d.amapt, m.enabled ? 'disable' : 'enable'); if (r.ok) { S.admin.settings = r.data; pageAdmin($('#page')); } return; }
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
    case 'invite': case 'zinvite': return openInviteList();
    case 'zsolo': { const r = await rpc('zb:create', { solo: true, name: $('#zname')?.value }); return r; }
    case 'zgroup': { const r = await rpc('zb:create', { name: $('#zname')?.value, password: $('#zpw')?.value, private: !!$('#zpw')?.value }); return r; }
    case 'zready': { const me = S.lobby.players.find((x) => x.id === S.init.me.id); return rpc('zb:ready', !me?.ready); }
    case 'zstart': return rpc('zb:start');
    case 'testsound': return Snd.play('victory');
    case 'arefresh': return loadAdmin();
    case 'npcadd': { const r = await rpc('admin:npc', 'add', { label: $('#npcLabel').value, model: $('#npcModel').value }); if (r.ok) { S.admin.settings = r.data; pageAdmin($('#page')); } return; }
    case 'npcrestore': { const r = await rpc('admin:npc', 'restore', {}); if (r.ok) { S.admin.settings = r.data; pageAdmin($('#page')); } return; }
    case 'psearch': {
      const r = await rpc('admin:players.search', $('#psearch').value);
      $('#presults').innerHTML = r.ok ? `<table class="adm-table">${r.data.map((x) => `<tr><td>${rankImg(x.rank)} <b>${esc(x.firstname)} ${esc(x.lastname)}</b></td><td class="small muted">${esc(x.citizenid)}</td><td>${fmt(x.points)} pts</td><td>${x.wins} V</td><td>manche ${x.zb_best_round}</td><td>${x.banned ? '<span class="chip red">EXCLU</span>' : ''}</td><td><button class="btn sm" data-pick="${esc(x.citizenid)}">Ouvrir</button></td></tr>`).join('')}</table>` : '';
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
const H = { mode: null, endsAt: 0, offset: 0, zmoney: 0 };
function hudInit(d) {
  H.mode = d.mode; H.role = d.role; H.team = d.team;
  const teamColor = d.team === 'A' ? 'var(--lg-red)' : d.team === 'B' ? 'var(--lg-blue)' : 'var(--ely-violet)';
  document.documentElement.style.setProperty('--team', teamColor);
  document.documentElement.style.setProperty('--hud-scale', S.settings.hudScale);
  const root = $('#hudScale');
  if (d.mode === 'pvp') {
    root.innerHTML = `<div class="hud-top"><div class="hs A" id="hsA">0</div><div class="hmid"><div class="tm mono" id="htime">--:--</div><div class="rd" id="hround">MANCHE 1</div></div><div class="hs B" id="hsB">0</div></div>
      <div class="alive"><div class="grp A" id="alA"></div><div class="grp B" id="alB"></div></div>
      <div class="mates" id="mates"></div><div class="killfeed" id="kf"></div>
      ${d.role === 'player' ? `<div class="shield" id="shield"><div class="lbl">BOUCLIER <b id="shv">${d.shield}</b></div><div class="sb"><b id="shb"></b></div></div><div class="ammo" id="ammo"></div>` : ''}
      <div class="crosshair hidden" id="cross"><i></i><i></i><i></i><i></i><b></b></div><div class="hitmarker" id="hm"><i></i><i></i><i></i><i></i></div><div class="dmgdir" id="dd"></div>
      <div class="vignette" id="vig"></div><div class="center-msg" id="cmsg"></div><div class="specbar hidden" id="spec"></div>`;
  } else {
    root.innerHTML = `<div class="zb-round" id="zround">I</div><div class="zb-left" id="zleft"></div><div class="mates" id="mates"></div><div class="zbfeed" id="zfeed"></div>
      ${d.role === 'player' ? `<div class="shield" id="shield"><div class="lbl">VIE <b id="shv">${d.hp}</b></div><div class="sb"><b id="shb"></b></div></div><div class="perks" id="perks"></div>
      <div class="zb-money" id="zmoney"><div class="v" id="zmv">${fmt(d.money)} $</div></div><div class="ammo" id="ammo"></div>` : ''}
      <div class="crosshair hidden" id="cross"><i></i><i></i><i></i><i></i><b></b></div><div class="hitmarker" id="hm"><i></i><i></i><i></i><i></i></div>
      <div class="vignette" id="vig"></div><div class="center-msg" id="cmsg"></div><div class="specbar hidden" id="spec"></div><div id="zdown"></div><div class="progress hidden" id="prog"></div>`;
    H.zmoney = d.money || 0;
  }
  $('#hud').classList.remove('hidden');
  clearInterval(H.tick);
  H.tick = setInterval(hudTick, 250);
}
function roman(n) { const m = [[1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'], [100, 'C'], [90, 'XC'], [50, 'L'], [40, 'XL'], [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I']]; let s = ''; for (const [v, r] of m) while (n >= v) { s += r; n -= v; } return s || '0'; }
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
function flashVignette(acid) {
  const v = $('#vig'); if (!v) return;
  v.classList.toggle('acid', !!acid); v.style.opacity = 1;
  clearTimeout(H.vg); H.vg = setTimeout(() => { v.style.opacity = 0; }, 350);
}

const ON = {
  open(d) {
    S.init = d.init; S.list = d.init.games || []; S.lobby = d.init.lobby || null;
    if (d.settings) Object.assign(S.settings, d.settings);
    $('#mark').innerHTML = Ely.mark({ anim: true, live: true, size: 64 });
    $('#sky').innerHTML = Ely.skyline({ w: 600, h: 170, seed: 11, lit: 0.22 });
    $('#app').classList.remove('hidden');
    go(S.lobby ? S.lobby.mode === 'zombie' ? 'zombie' : 'pvp' : (d.tab || 'home'));
    if (d.admin) { S.admin = null; go('admin'); }
  },
  close() { $('#app').classList.add('hidden'); clearInterval(S.lbTimer); },
  tab(t) { go(t); },
  list(list) { S.list = list || []; if (!$('#app').classList.contains('hidden') && ['home', 'pvp', 'zombie'].includes(S.tab) && !S.lobby) render(); },
  lobby(v) { const first = !S.lobby; S.lobby = v; if (!$('#app').classList.contains('hidden')) { if (first) go(v.mode === 'zombie' ? 'zombie' : 'pvp'); else if (S.tab === 'pvp' || S.tab === 'zombie') render(); } },
  lobbyClosed(d) { if (S.lobby && S.lobby.uid === d.uid) { S.lobby = null; if (d.reason && d.reason !== 'a quitté') toast(`Lobby fermé : ${d.reason}`, 'warn'); render(); } },
  gameClosed(d) { S.list = S.list.filter((g) => g.uid !== d.uid); },
  invite(inv) {
    const el = document.createElement('div');
    el.className = 'card holo invite';
    el.innerHTML = `<h3>Invitation ${inv.mode === 'zombie' ? 'Zombie' : 'PVP'}</h3><div><b>${esc(inv.host)}</b> t'invite à « ${esc(inv.name)} ».</div><div class="small muted" style="margin:6px 0 10px">Rends-toi auprès d'un PNJ LaserGame pour accepter (E).</div>
      <div class="row"><button class="btn sm ok">Accepter</button><button class="btn sm ghost">Ignorer</button></div>`;
    const [ok, no] = el.querySelectorAll('button');
    ok.onclick = async () => { el.remove(); const r = await rpc(inv.mode === 'zombie' ? 'zb:join' : 'pvp:join', inv.uid, ''); if (r.ok) toast('Tu as rejoint la partie.', 'success'); };
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
    $('#loadingBg').style.backgroundImage = d.map ? `url('images/maps/${d.map}.png')` : '';
    $('#loadingMode').textContent = d.role === 'spectator' ? 'MODE SPECTATEUR' : (d.mode === 'zombie' ? 'MODE ZOMBIE' : 'PVP ARENA');
    $('#loadingName').textContent = mapOf(d.map).label || d.name || '';
    const tips = ['Le laser est arrêté par les couvertures : sers-t\'en.', 'Recharge (R) à l\'abri.', 'Les spectateurs ne voient pas ce que tu prépares.', 'Les atouts sont perdus si tu es éliminé.', 'Mastodonte permet d\'encaisser 5 à 6 coups.', 'Le cracheur d\'acide laisse une flaque : bouge !'];
    $('#loadingTip').textContent = tips[Math.floor(Math.random() * tips.length)];
    $('#loadingBar').style.width = '0%';
    $('#loading').classList.remove('hidden');
    $('#app').classList.add('hidden');
  },
  loadingProgress(k) { $('#loadingBar').style.width = `${Math.round(k * 100)}%`; },
  loadingDone() { setTimeout(() => $('#loading').classList.add('hidden'), 400); },
  hud(d) { if (!d) { $('#hud').classList.add('hidden'); clearInterval(H.tick); $('#results').classList.add('hidden'); return; } hudInit(d); if (d.mode === 'pvp' && d.shield) setBar(d.shield, d.maxShield || d.shield); if (d.mode === 'zombie' && d.hp) setBar(d.hp, d.maxHp); },
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
  // ---- Zombie
  zbState(s) {
    if (!s) return;
    const r = $('#zround'); if (r && r.dataset.r != s.round) { r.dataset.r = s.round; r.textContent = roman(s.round || 0); }
    const l = $('#zleft'); if (l) l.textContent = s.phase === 'intermission' ? 'PAUSE · PRÉPARE-TOI' : `${s.remaining} ZOMBIE(S) RESTANT(S)`;
    const m = $('#mates');
    if (m) m.innerHTML = s.players.map((p) => `<div class="mate ${p.state === 'dead' ? 'dead' : ''} ${p.state === 'down' ? 'down' : ''}" style="--c:${p.me ? 'var(--ely-violet-hi)' : 'var(--lg-acid)'}">${esc(p.name)}${p.me ? ' (toi)' : ''}
      <span class="mb"><b style="width:${Math.max(0, p.hp / Math.max(1, p.maxHp) * 100)}%"></b></span><span class="small">${fmt(p.money)} $</span></div>`).join('');
  },
  zbRound(d) { const r = $('#zround'); if (r) { r.textContent = roman(d.round); r.classList.remove('flash'); void r.offsetWidth; r.classList.add('flash'); } centerMsg(`<div class="banner lose">MANCHE ${d.round}<span class="sub">${d.count} ZOMBIES</span></div>`, 2600); },
  zbRoundEnd(d) { centerMsg(`<div class="banner win">MANCHE ${d.round} SURVÉCUE<span class="sub">PROCHAINE VAGUE DANS ${d.next} S</span></div>`, 4000); },
  zbMoney(d) {
    const v = $('#zmv'); if (!v) return;
    v.textContent = `${fmt(d.money)} $`;
    if (d.delta) { const e = document.createElement('div'); e.className = `d ${d.delta < 0 ? 'neg' : ''}`; e.textContent = `${d.delta > 0 ? '+' : ''}${fmt(d.delta)}`; $('#zmoney').appendChild(e); setTimeout(() => e.remove(), 1200); }
    if (d.hit) ON.hitmarker({ kill: d.kill });
  },
  zbHealth(d) { setBar(d.hp, d.maxHp, !d.regen); if (d.kind === 'acid') flashVignette(true); },
  zbPerks(d) {
    const p = $('#perks'); if (!p) return;
    const defs = Object.fromEntries((S.init?.zombie?.perks || []).map((k) => [k.id, k]));
    p.innerHTML = (d.perks || []).map((id) => `<div class="perk" style="--c:${defs[id]?.color || '#B57BFF'}" title="${esc(defs[id]?.label || id)}"><svg viewBox="0 0 24 24">${I[defs[id]?.icon || id] || ''}</svg></div>`).join('');
    if (d.maxHp) setBar(d.hp, d.maxHp);
    if (d.bought) centerMsg(`<div class="banner win" style="font-size:30px">${esc(defs[d.bought]?.label || d.bought)}</div>`, 2000);
  },
  zbFeed(d) {
    const f = $('#zfeed'); if (!f) return;
    const txt = { down: `${d.name} est à terre !`, revive: `${d.name} a été réanimé${d.by ? ' par ' + d.by : ''}`, dead: `${d.name} a succombé`, left: `${d.name} a quitté la partie`, door: `${d.name} a ouvert une porte` }[d.kind] || '';
    const e = document.createElement('div'); e.textContent = txt; f.prepend(e); setTimeout(() => e.remove(), 4600);
  },
  zbDowned(d) {
    const z = $('#zdown'); if (!z) return;
    let left = d.bleedout;
    z.innerHTML = `<div class="downed"><div><div class="t">À TERRE</div><div class="s">${d.selfRevive ? 'RÉANIMATION RAPIDE : TU TE RELÈVES…' : 'UN COÉQUIPIER PEUT TE RÉANIMER'}</div><div class="s" id="bleed" style="font-size:28px;margin-top:14px">${left}</div></div></div>`;
    clearInterval(H.bleed);
    H.bleed = setInterval(() => { left -= 1; const b = $('#bleed'); if (b) b.textContent = Math.max(0, left); if (left <= 0) clearInterval(H.bleed); }, 1000);
  },
  zbReviving(d) { if (!d) return ON.progress(false); ON.progress({ label: `${d.by} te réanime…`, duration: d.duration }); },
  zbRevived(d) { clearInterval(H.bleed); const z = $('#zdown'); if (z) z.innerHTML = ''; ON.progress(false); setBar(d.hp, d.maxHp); if (d.perks) ON.zbPerks({ perks: d.perks }); },
  zbDead() { clearInterval(H.bleed); const z = $('#zdown'); if (z) z.innerHTML = ''; centerMsg('<div class="banner lose">TU AS SUCCOMBÉ<span class="sub">RETOUR À LA PROCHAINE MANCHE</span></div>', 4000); ON.zbPerks({ perks: [] }); },
  zbGameOver(d) { clearInterval(H.bleed); const z = $('#zdown'); if (z) z.innerHTML = ''; showZombieResults(d); },
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
function showZombieResults(d) {
  const r = $('#results');
  r.className = 'lose';
  r.innerHTML = `<div class="res"><div class="big glitch go" data-text="FIN DE PARTIE" style="font-size:90px">FIN DE PARTIE</div>
    <div class="final" style="color:#FF1E3C">MANCHE ${d.round}</div><div class="muted">${fmt(d.kills)} zombies éliminés · ${Math.floor(d.duration / 60)} min ${d.duration % 60} s</div>
    <div class="card holo" style="margin-top:18px"><table class="lb"><tr><th>Joueur</th><th>Zombies</th><th>Argent gagné</th><th>À terre</th><th>Réanimations</th></tr>
    ${d.players.map((p) => `<tr><td><b>${esc(p.name)}</b>${p.left ? ' <span class="chip warn">parti</span>' : ''}</td><td>${p.kills}</td><td>${money(p.money)}</td><td>${p.downs}</td><td>${p.revives}</td></tr>`).join('')}</table></div>
    <div class="muted small" style="margin-top:12px">L'argent Zombie n'existe que dans la partie. Retour au RP…</div></div>`;
  r.classList.remove('hidden');
  setTimeout(() => r.classList.add('hidden'), 11500);
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
      'admin:players.search': [{ citizenid: 'ELY12345', firstname: 'Nora', lastname: 'Vance', points: 1612, wins: 48, zb_best_round: 27, banned: 0, rank: 'diamond' }],
    };
    return Promise.resolve({ ok: true, data: R[data.name] ?? true });
  },
  board(kind) {
    const names = [['Nora', 'Vance'], ['Kenji', 'Mori'], ['Lina', 'Morel'], ['Sacha', 'Diallo'], ['Ivy', 'Stone'], ['Malo', 'Ruiz'], ['Yara', 'Benali'], ['Tom', 'Keller'], ['Ezra', 'Lopez'], ['Mia', 'Hart']];
    const rk = ['legend', 'grandmaster', 'master', 'diamond', 'diamond', 'platinum', 'gold', 'gold', 'silver', 'bronze'];
    const zb = String(kind || '').startsWith('zb');
    return { kind: kind || 'pvp_points', page: 1, pages: 3, total: 27, t: Date.now() / 1000, rows: names.map(([f, l], i) => ({ pos: i + 1, firstname: f, lastname: l, names: `${f} ${l}, ${names[(i + 1) % 10][0]} ${names[(i + 1) % 10][1]}`,
      v: zb ? 42 - i * 3 : 2140 - i * 61, rank: rk[i], wins: 120 - i * 9, losses: 30 + i * 4, points: 2140 - i * 61, zb_kills: 4100 - i * 300, zb_money: 410000 - i * 31000, zb_games: 60 - i * 4, zb_best_date: 1761900000 - i * 86400,
      kills: 3000 - i * 200, players: 3, created_at: 1761900000 })) };
  },
};
Demo.init = {
  me: { id: 1, name: 'Elyzea Fa', firstname: 'Elyzea', lastname: 'Fa' }, isAdmin: true, spectator: true,
  profile: { firstname: 'Elyzea', lastname: 'Fa', points: 1612, peak: 1688, rank: 'diamond', rankLabel: 'ELYZEA DIAMOND', progress: 0.41, position: 7, next: { id: 'master', label: 'ELYZEA MASTER', min: 1700 },
    wins: 48, losses: 21, draws: 3, kills: 512, deaths: 233, matches: 72, ratio: 2.2, streak: 3, bestStreak: 9, zbBestRound: 27, zbBestSolo: 19, zbKills: 3120, zbMoney: 284500, zbGames: 41, zbRevives: 37, zbBestDate: 1761900000 },
  pvp: { enabled: true, formats: [1, 2, 3, 4, 5, 6].map((n) => ({ id: `${n}v${n}`, label: `${n} VS ${n}`, size: n })), rounds: [1, 3, 5, 7, 9], roundTimes: [60, 90, 120, 180, 240, 300], defaultRounds: 3, defaultRoundTime: 120, ranked: { public: true, private: false } },
  stake: { enabled: true, min: 0, max: 250000, step: 100, fee: 0 },
  zombie: { enabled: true, maxPlayers: 4, maxPerks: 4, perks: [
    { id: 'quickrevive', label: 'Réanimation rapide', price: 1500, color: '#5FD3FF', icon: 'quickrevive', desc: '' }, { id: 'speed', label: 'Rapidité', price: 2000, color: '#FFB020', icon: 'speed', desc: '' },
    { id: 'acidres', label: 'Résistance acide', price: 2000, color: '#9BFF3E', icon: 'acidres', desc: '' }, { id: 'juggernaut', label: 'Mastodonte', price: 2500, color: '#FF3355', icon: 'juggernaut', desc: '' },
    { id: 'regen', label: 'Régénération', price: 2500, color: '#FF77D0', icon: 'regen', desc: '' }, { id: 'fastreload', label: 'Rechargement rapide', price: 3000, color: '#3EE6B0', icon: 'fastreload', desc: '' },
    { id: 'armor', label: 'Protection', price: 3000, color: '#C9D3E0', icon: 'armor', desc: '' }, { id: 'doubledmg', label: 'Double dégâts', price: 5000, color: '#B57BFF', icon: 'doubledmg', desc: '' }] },
  maps: [['pvp_small', 'ELYSIUM COMBAT', 'S'], ['pvp_medium', 'NEON DISTRICT', 'M'], ['pvp_large', 'BLACKSITE', 'L'], ['pvp_xlarge', 'LAST STAND', 'XL'], ['zombie_map', 'COMPLEXE ELYZEA-7', 'XL']]
    .map(([id, label, size]) => ({ id, label, size, mode: id.startsWith('pvp') ? 'pvp' : 'zombie', enabled: true, description: 'Complexe de recherche abandonné : 8 secteurs, portes payantes, armes murales et atouts.' })),
  categories: [['melee', 'Mêlée'], ['pistol', 'Pistolet'], ['smg', 'Mitraillette'], ['rifle', 'Fusil d\'assaut'], ['sniper', 'Sniper']].map(([id, label]) => ({ id, label })),
  ranks: [['bronze', 'ELYZEA BRONZE', 0, '#C98A55'], ['silver', 'ELYZEA SILVER', 1100, '#C9D3E0'], ['gold', 'ELYZEA GOLD', 1250, '#FFC94A'], ['platinum', 'ELYZEA PLATINUM', 1400, '#7FE3D8'],
    ['diamond', 'ELYZEA DIAMOND', 1550, '#6FB6FF'], ['master', 'ELYZEA MASTER', 1700, '#B57BFF'], ['grandmaster', 'ELYZEA GRANDMASTER', 1850, '#FF4D8D'], ['legend', 'ELYZEA LEGEND', 2000, '#FFE7A3']]
    .map(([id, label, min, color], i) => ({ id, label, min, color, tier: i + 1 })),
  teams: { A: { name: 'ROUGE', hex: '#FF2D46' }, B: { name: 'BLEUE', hex: '#288CFF' } },
  games: [
    { uid: 'PVP1', mode: 'pvp', name: 'Finale du jeudi', host: 'Nora Vance', format: '5v5', mapLabel: 'BLACKSITE', players: 10, max: 10, phase: 'round', score: { A: 2, B: 1 }, round: 4, stake: 5000, spectators: 3, ranked: true },
    { uid: 'PVP2', mode: 'pvp', name: 'Duel au néon', host: 'Kenji Mori', format: '1v1', mapLabel: 'NEON DISTRICT', players: 1, max: 2, phase: 'lobby', stake: 0, ranked: true },
    { uid: 'PVP3', mode: 'pvp', name: 'Entraînement', host: 'Lina Morel', format: '3v3', mapLabel: 'ELYSIUM COMBAT', players: 4, max: 6, phase: 'lobby', stake: 1000, hasPassword: true },
    { uid: 'ZB1', mode: 'zombie', name: 'Escouade Omega', host: 'Sacha Diallo', mapLabel: 'COMPLEXE ELYZEA-7', players: 3, max: 4, phase: 'round', round: 14 },
  ],
};
Demo.history = [
  { mode: 'pvp', format: '5v5', map: 'pvp_large', result: 'win', score_a: 3, score_b: 1, kills: 9, deaths: 3, points_delta: 24, payout: 10000, created_at: 1761990000 },
  { mode: 'zombie', map: 'zombie_map', result: 'loss', round: 27, kills: 412, deaths: 4, points_delta: 0, payout: 0, created_at: 1761900000 },
  { mode: 'pvp', format: '1v1', map: 'pvp_small', result: 'loss', score_a: 1, score_b: 2, kills: 3, deaths: 4, points_delta: -15, payout: 0, created_at: 1761800000 },
];
Demo.logs = [{ category: 'money', name: 'Nora Vance', message: 'gain de 25 000 $ (partie PVP1761990000001)', created_at: 1761990000 },
  { category: 'security', name: 'Inconnu', message: 'événement suspect : cadence de tir dépassée (n°1)', created_at: 1761980000 },
  { category: 'admin', name: 'Staff Elyzea', message: 'réglage modifié : stake', created_at: 1761970000 }];
Demo.admin = {
  games: [{ uid: 'PVP1761990000001', mode: 'pvp', name: 'Finale du jeudi', host: 'Nora Vance', phase: 'round', map: 'pvp_large', format: '5v5', score: { A: 2, B: 1 }, round: 4, players: [{ id: 3, name: 'Nora Vance' }, { id: 7, name: 'Kenji Mori' }] }],
  settings: {
    framework: 'elyzea',
    pvp: { enabled: true, requireEqualTeams: true, requireFullTeams: false, oneHitElimination: false, friendlyFire: false, shield: 100, minRankedDuration: 45, lobbyIdleTimeout: 1200, defaultRoundTime: 120, defaultRounds: 3 },
    stake: { enabled: true, min: 0, max: 250000, step: 100, houseFeePct: 0 },
    formats: Demo.init.pvp.formats.map((f) => ({ ...f, enabled: true })), ranks: Demo.init.ranks,
    weapons: [{ id: 'photon_p9', label: 'Photon P9', cat: 'pistol', damage: 25, zDamage: 45, range: 60, rpm: 240, spread: 1.2, mag: 12, reload: 1400 }, { id: 'helios', label: 'Hélios Railgun', cat: 'sniper', damage: 90, zDamage: 600, range: 250, rpm: 45, spread: 0.05, mag: 5, reload: 3000 }],
    maps: Demo.init.maps.map((m) => ({ ...m, objects: 300, anchor: { x: -1336, y: -3044, z: 13.94, h: 150 }, moved: m.id === 'pvp_small' })),
    zombie: { enabled: true, maxPerks: 4, rounds: { countBase: 6, countPerRound: 3, countMax: 120, maxAlive: 22, hpBase: 110, hpPerRound: 40, hpLinearUntil: 9, hpGrowth: 1.1, damageBase: 34, damagePerRound: 1.5, damageMax: 60, runFromRound: 3, sprintFromRound: 7, speedRamp: 0.12, intermission: 10, spawnInterval: 1500 },
      money: { hit: 10, meleeKillBonus: 30, reviveBonus: 100, roundBonus: 0, startMoney: 500 }, player: { health: 100, regenDelay: 4000, regenPerSecond: 35, bleedout: 30, reviveTime: 4 },
      types: [{ id: 'classic', label: 'Zombie', hp: 1, damage: 1, speed: 1, reward: 100, weight: 100, minRound: 1 }, { id: 'spitter', label: 'Cracheur d\'acide', hp: 1.4, damage: 0.6, speed: 0.9, reward: 300, weight: 10, minRound: 4 }],
      perks: Demo.init.zombie.perks, doors: [{ id: 'd_corridor', label: 'Couloir industriel', price: 750 }], wallbuys: [{ id: 'wb_vector', sector: 'corridor', price: 500, weapon: 'photon_p9' }] },
    npcs: [{ id: 'lg_accueil', label: 'LaserGame ElyzeaFA', model: 's_m_y_ammucity_01', x: -1256.66, y: -1440.81, z: 4.37 }],
  },
};

(function demo() {
  if (IN_GAME) return;
  document.body.classList.add('demo');
  const q = new URLSearchParams(location.search).get('demo') || 'home';
  const send = (action, data) => window.postMessage({ action, data }, '*');
  const open = (tab, admin) => send('open', { init: Demo.init, tab, admin });
  const lobbyPvp = { uid: 'PVP2', mode: 'pvp', name: 'Duel au néon', host: 'Elyzea Fa', isHost: true, format: '3v3', size: 3, map: 'pvp_medium', mapLabel: 'NEON DISTRICT', rounds: 5, roundTime: 120, category: 'rifle', stake: 5000, pot: 25000, ranked: true,
    teamNames: { A: 'ROUGE', B: 'BLEUE' }, teams: { A: [{ id: 1, name: 'Elyzea Fa', ready: true, weapon: 'nova_ar', host: true, rank: 'diamond', me: true }, { id: 4, name: 'Malo Ruiz', ready: false, weapon: 'spectre', rank: 'gold' }],
      B: [{ id: 5, name: 'Kenji Mori', ready: true, weapon: 'quasar', rank: 'grandmaster' }, { id: 6, name: 'Ivy Stone', ready: true, weapon: 'nova_ar', rank: 'platinum' }, { id: 8, name: 'Tom Keller', ready: false, weapon: 'nova_ar', rank: 'silver' }] },
    weapons: [{ id: 'nova_ar', label: 'Nova AR', damage: 20, range: 90, rpm: 560 }, { id: 'spectre', label: 'Spectre-7', damage: 22, range: 95, rpm: 520 }, { id: 'quasar', label: 'Quasar Bullpup', damage: 26, range: 100, rpm: 480 }] };
  setTimeout(() => {
    if (q === 'home' || q === 'pvp' || q === 'zombie' || q === 'ranks' || q === 'profile' || q === 'history' || q === 'settings') open(q);
    else if (q === 'admin') open('admin', true);
    else if (q === 'lobby') { open('pvp'); setTimeout(() => send('lobby', lobbyPvp), 100); }
    else if (q === 'zlobby') { open('zombie'); setTimeout(() => send('lobby', { uid: 'ZB2', mode: 'zombie', name: 'Escouade Elyzea', host: 'Elyzea Fa', isHost: true, mapLabel: 'COMPLEXE ELYZEA-7', max: 4, players: [{ id: 1, name: 'Elyzea Fa', ready: true, host: true }, { id: 9, name: 'Yara Benali', ready: false }] }), 100); }
    else if (q === 'create') { open('pvp'); setTimeout(() => { S.sub.pvp = 'create'; render(); }, 100); }
    else if (q === 'loading') { send('loading', { map: 'pvp_large', mode: 'pvp', name: 'Finale' }); send('loadingProgress', 0.64); }
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
    } else if (q === 'hud-zombie') {
      S.init = Demo.init;
      send('hud', { mode: 'zombie', role: 'player', hp: 100, maxHp: 200, money: 4350 });
      send('zbState', { round: 14, phase: 'round', remaining: 37, players: [{ id: 1, name: 'Elyzea Fa', state: 'alive', hp: 140, maxHp: 200, money: 4350, me: true }, { id: 9, name: 'Yara Benali', state: 'down', hp: 0, maxHp: 100, money: 2210 }, { id: 3, name: 'Nora Vance', state: 'alive', hp: 100, maxHp: 100, money: 6800 }] });
      send('zbPerks', { perks: ['juggernaut', 'speed', 'doubledmg'], hp: 140, maxHp: 200 });
      send('ammo', { label: 'Hellbringer', ammo: 38, mag: 50, slots: ['photon_p9', 'hellbringer'], current: 'hellbringer' });
      send('crosshair', true);
      send('zbFeed', { kind: 'down', name: 'Yara Benali' });
      send('prompt', { key: 'E', title: 'Zone de haute sécurité', label: 'Ouvrir', price: 3500, money: true });
    } else if (q === 'results') {
      S.init = Demo.init;
      send('matchEnd', { winner: 'A', score: { A: 3, B: 1 }, ranked: true, mvp: 'Elyzea Fa', teamNames: { A: 'ROUGE', B: 'BLEUE' },
        players: [{ name: 'Elyzea Fa', team: 'A', kills: 11, deaths: 3 }, { name: 'Malo Ruiz', team: 'A', kills: 6, deaths: 5 }, { name: 'Kenji Mori', team: 'B', kills: 7, deaths: 6 }, { name: 'Ivy Stone', team: 'B', kills: 2, deaths: 7 }],
        me: { result: 'win', team: 'A', kills: 11, deaths: 3, payout: 10000, delta: 28, points: 1712, rank: 'master', rankLabel: 'ELYZEA MASTER', rankUp: true } });
    } else if (q === 'zresults') {
      S.init = Demo.init;
      send('zbGameOver', { round: 27, kills: 1104, duration: 3125, players: [{ name: 'Elyzea Fa', kills: 412, money: 61500, downs: 3, revives: 9 }, { name: 'Nora Vance', kills: 380, money: 55000, downs: 4, revives: 6 }] });
    }
  }, 50);
})();
