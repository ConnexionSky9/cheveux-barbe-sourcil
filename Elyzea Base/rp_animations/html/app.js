'use strict';
// =====================================================================
//  rp_animations : interface du menu (NUI)
// =====================================================================
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

async function post(name, data = {}) {
  if (!RES) return window.__rpaMock ? window.__rpaMock(name, data) : null;
  try {
    const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) });
    return await r.json();
  } catch (e) { return null; }
}

const S = {
  open: false, cats: [], list: [], byId: {}, statuses: {}, sources: {},
  favorites: [], recents: [], prefs: {}, avail: {}, checked: false, current: null,
  cat: 'romantiques', filter: 'all', q: '', sel: 0, keys: {},
  incoming: null, outgoing: null, inviteFor: null, invRole: 'A', invTarget: null, nearbyTimer: null,
};

const ICONS = {
  heart: '<path d="M12 20s-7-4.4-8.8-8.8C2 8 4 4.8 7.2 4.8c1.9 0 3.4 1 4.8 2.7 1.4-1.7 2.9-2.7 4.8-2.7C20 4.8 22 8 20.8 11.2 19 15.6 12 20 12 20z"/>',
  rings: '<circle cx="9" cy="14" r="5"/><circle cx="15" cy="14" r="5"/><path d="M10 5l2-2 2 2"/>',
  flame: '<path d="M12 21c4 0 6.5-2.6 6.5-6.3 0-3.7-3-6-4.4-9.7-2.2 2-2.6 4.1-2.4 5.6-1.5-.8-2.4-2.4-2.5-4C6.6 8.6 5.5 11.4 5.5 14.7 5.5 18.4 8 21 12 21z"/>',
  rose: '<path d="M12 12c-3 0-5-2-5-5 2 0 3 .5 5 2 2-1.5 3-2 5-2 0 3-2 5-5 5z"/><path d="M12 12v9M12 17c-2-1-3.5-1-5 0M12 15c1.5-1 3-1.2 4.5-.5"/>',
  embrace: '<circle cx="8" cy="6" r="2.5"/><circle cx="16" cy="6" r="2.5"/><path d="M5 21v-6a3 3 0 0 1 3-3h8a3 3 0 0 1 3 3v6M8 15l4 2 4-2"/>',
  person: '<circle cx="12" cy="5" r="2.5"/><path d="M12 8v6M12 14l-4 7M12 14l4 7M7 10l5-2 5 2"/>',
  disco: '<circle cx="12" cy="13" r="7"/><path d="M12 6V2M5 13h14M12 6c-2.5 2-2.5 12 0 14M12 6c2.5 2 2.5 12 0 14"/>',
  spark: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 17l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  star: '<path d="M12 3.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>',
  clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
};
const icon = (k) => `<svg viewBox="0 0 24 24">${ICONS[k] || ''}</svg>`;

// ── Données ──────────────────────────────────────────────────────────────
function setCatalog(cat) {
  S.cats = cat.cats || [];
  S.list = cat.list || [];
  S.statuses = cat.statuses || {};
  S.sources = cat.sources || {};
  S.byId = {};
  S.list.forEach((e) => { S.byId[e.id] = e; });
}

function adultOk() { return S.prefs.adult === true; }

// Raison pour laquelle une fiche n'est pas lançable (null = lançable)
function blockReason(e) {
  if (!e.playable) return `« ${e.label} » n'est pas encore disponible : animation à créer.`;
  if (S.avail[e.id] === false) return `« ${e.label} » est indisponible : fichiers d'animation absents sur ce serveur.`;
  if (e.adult && !adultOk()) return 'Active les animations adultes dans les réglages pour y accéder.';
  return null;
}

function visibleEntries() {
  const q = S.q.trim().toLowerCase();
  let items;
  if (q) {
    items = S.list.filter((e) => (e.label + ' ' + (e.desc || '') + ' ' + e.id).toLowerCase().includes(q));
  } else if (S.cat === 'favoris') {
    items = S.favorites.map((id) => S.byId[id]).filter(Boolean);
  } else if (S.cat === 'recents') {
    items = S.recents.map((id) => S.byId[id]).filter(Boolean);
  } else {
    items = S.list.filter((e) => e.cat === S.cat);
  }
  if (!adultOk()) items = items.filter((e) => !e.adult);
  if (S.filter !== 'all') items = items.filter((e) => e.type === S.filter);
  if (!q && S.cat !== 'favoris' && S.cat !== 'recents') {
    // Jouables d'abord, puis les « à créer »
    items = items.slice().sort((a, b) => (a.playable === b.playable ? a.n - b.n : a.playable ? -1 : 1));
  }
  return items;
}

// ── Rendu ────────────────────────────────────────────────────────────────
function renderCats() {
  const count = (id) => S.list.filter((e) => e.cat === id && e.playable && (!e.adult || adultOk())).length;
  const rows = S.cats.map((c) => `
    <button class="cat ${c.adult ? 'adult' : ''} ${S.cat === c.id && !S.q ? 'on' : ''}" data-cat="${esc(c.id)}">
      ${icon(c.icon)}<span>${esc(c.label)}</span><span class="cnt">${c.adult && !adultOk() ? '🔒' : count(c.id)}</span>
    </button>`).join('');
  $('cats').innerHTML = rows + `<div class="sep"></div>
    <button class="cat ${S.cat === 'favoris' && !S.q ? 'on' : ''}" data-cat="favoris">${icon('star')}<span>Favoris</span><span class="cnt">${S.favorites.length}</span></button>
    <button class="cat ${S.cat === 'recents' && !S.q ? 'on' : ''}" data-cat="recents">${icon('clock')}<span>Récents</span><span class="cnt">${S.recents.length}</span></button>`;
}

function catInfo() {
  if (S.q.trim()) return { label: 'Résultats', desc: `Recherche : « ${S.q.trim()} »` };
  if (S.cat === 'favoris') return { label: 'Favoris', desc: 'Tes animations préférées (étoile sur une carte, ou F).' };
  if (S.cat === 'recents') return { label: 'Récemment utilisées', desc: 'Les dernières animations lancées.' };
  return S.cats.find((c) => c.id === S.cat) || { label: '', desc: '' };
}

function renderList() {
  const info = catInfo();
  $('catTitle').textContent = info.label;
  $('catDesc').textContent = info.desc || '';
  const items = visibleEntries();
  S.items = items;
  if (S.sel >= items.length) S.sel = Math.max(0, items.length - 1);

  if (S.cat === 'adulte' && !adultOk() && !S.q.trim()) {
    $('list').innerHTML = `<div class="empty">Catégorie réservée au roleplay entre personnages adultes.<br>
      Active-la dans les <b>réglages</b> (roue crantée) si tu le souhaites. Chaque invitation demandera ensuite ta confirmation explicite.</div>`;
    return;
  }
  if (!items.length) {
    $('list').innerHTML = `<div class="empty">${S.cat === 'favoris' ? 'Aucun favori pour l\'instant.' : S.cat === 'recents' ? 'Aucune animation récente.' : 'Aucune animation ne correspond.'}</div>`;
    return;
  }
  $('list').innerHTML = items.map((e, i) => {
    const reason = blockReason(e);
    const fav = S.favorites.includes(e.id);
    const missing = e.playable && S.avail[e.id] === false;
    const playing = S.current && S.current.id === e.id;
    const tags = [
      `<span class="tag ${e.type}">${e.type === 'duo' ? 'Duo' : 'Solo'}</span>`,
      e.adult ? '<span class="tag adult">Adulte</span>' : '',
      missing ? '<span class="tag missing">Fichiers absents</span>' : `<span class="tag st-${esc(e.status)}">${esc(S.statuses[e.status] || e.status)}</span>`,
      e.steps > 1 ? `<span class="tag">${e.steps} étapes</span>` : '',
    ].join('');
    const action = e.type === 'duo' ? 'Inviter' : 'Lancer';
    return `<div class="card ${reason ? 'off' : ''} ${i === S.sel ? 'sel' : ''} ${playing ? 'playing' : ''}" role="option" data-i="${i}" aria-selected="${i === S.sel}">
      <div class="c-top"><span class="c-n">${e.n}</span><span class="c-name">${esc(e.label)}</span>
        <button class="star ${fav ? 'on' : ''}" data-fav="${esc(e.id)}" title="Favori (F)" aria-label="Favori">${icon('star')}</button></div>
      <div class="c-desc">${esc(e.desc || '')}</div>
      ${e.note && e.playable ? `<div class="c-note">${esc(e.note)}</div>` : ''}
      <div class="tags">${tags}</div>
      <div class="c-act"><button class="go ${e.type}" data-go="${i}" ${reason ? 'disabled' : ''}>${playing ? 'En cours' : action}</button></div>
    </div>`;
  }).join('');
}

function renderBar() {
  const on = !!S.current;
  $('now').classList.toggle('on', on);
  $('nowText').textContent = on ? `${S.current.preparing ? 'Mise en place : ' : 'En cours : '}${S.current.label}${S.current.role ? ' (rôle ' + S.current.role + ')' : ''}` : 'Aucune animation en cours';
  $('btnStop').disabled = !on;
  const k = S.keys;
  $('keysHint').innerHTML = `<span><kbd>${esc(k.stop || 'X')}</kbd> arrêter</span><span><kbd>Entrée</kbd> lancer</span><span><kbd>F</kbd> favori</span><span><kbd>Échap</kbd> fermer</span>`;
  document.querySelectorAll('.k-stop').forEach((n) => { n.textContent = k.stop || 'X'; });
  $('fadeHint').textContent = `${k.stop || 'X'} ou /stopanim pour arrêter`;
}

function render() { renderCats(); renderList(); renderBar(); }

// ── Actions ──────────────────────────────────────────────────────────────
function notify(text, kind = 'info') {
  const n = document.createElement('div');
  n.className = `toast ${kind}`;
  n.textContent = text;
  $('toasts').appendChild(n);
  setTimeout(() => { n.classList.add('bye'); setTimeout(() => n.remove(), 300); }, 4500);
}

function activate(i) {
  const e = S.items && S.items[i];
  if (!e) return;
  const reason = blockReason(e);
  if (reason) return notify(reason, 'err');
  if (e.type === 'duo') return openInvite(e);
  post('play', { id: e.id });
}

async function toggleFav(id) {
  const on = !S.favorites.includes(id);
  const res = await post('favorite', { id, on });
  S.favorites = Array.isArray(res) ? res : (on ? [...S.favorites, id] : S.favorites.filter((x) => x !== id));
  render();
}

function closeMenu() { post('close'); }

// ── Fenêtres ─────────────────────────────────────────────────────────────
function openModal(id) { $(id).classList.add('open'); $(id).setAttribute('aria-hidden', 'false'); }
function closeModal(id) {
  $(id).classList.remove('open'); $(id).setAttribute('aria-hidden', 'true');
  if (id === 'modalInvite') { clearInterval(S.nearbyTimer); S.nearbyTimer = null; S.inviteFor = null; }
}
const anyModal = () => document.querySelector('.modal.open');

function openInvite(e) {
  S.inviteFor = e; S.invRole = 'A'; S.invTarget = null;
  $('invTitle').textContent = `Inviter : ${e.label}`;
  $('invDesc').textContent = e.desc || '';
  $('invFadeRow').hidden = !e.fade;
  $('invFade').checked = false;
  renderRole();
  openModal('modalInvite');
  refreshNearby();
  S.nearbyTimer = setInterval(refreshNearby, 1500);
}

function renderRole() {
  const e = S.inviteFor;
  if (!e) return;
  document.querySelectorAll('#invRole button').forEach((b) => b.classList.toggle('on', b.dataset.r === S.invRole));
  const roles = e.roles || { A: 'Guide', B: 'Partenaire' };
  $('invRoleHint').textContent = `A : ${roles.A} (reste sur place) · B : ${roles.B} (rejoint sa place). Les rôles ne dépendent pas du personnage.`;
}

async function refreshNearby() {
  const list = (await post('nearby')) || [];
  if (!S.inviteFor) return;
  if (S.invTarget && !list.some((p) => p.id === S.invTarget && p.canInvite)) S.invTarget = null;
  $('invPeople').innerHTML = list.length ? list.map((p) => `
    <button class="person ${S.invTarget === p.id ? 'on' : ''}" data-p="${p.id}" ${p.canInvite ? '' : 'disabled'}>
      Une personne <span class="muted">(ID ${p.id})</span><span class="d">${String(p.dist).replace('.', ',')} m${p.canInvite ? '' : ' · trop loin'}</span>
    </button>`).join('') : '<div class="muted small">Personne à proximité. Approche-toi à moins de 3 mètres.</div>';
  $('invSend').disabled = !S.invTarget;
}

function showConfirm(inv) {
  if (!inv) return;
  $('cfLabel').textContent = inv.label;
  $('cfFrom').textContent = inv.from;
  $('cfRole').textContent = `${inv.role} (${inv.roleLabel || ''})`;
  document.querySelector('#modalConfirm .warn').hidden = !inv.adult;
  $('cfOk').closest('.check').hidden = !inv.adult;
  $('cfOk').checked = false;
  $('cfFadeRow').hidden = !inv.fade;
  $('cfFade').checked = false;
  $('cfYes').disabled = inv.adult;
  openModal('modalConfirm');
}

function renderSettings() {
  $('stDnd').checked = S.prefs.dnd === true;
  $('stAdult').checked = S.prefs.adult === true;
  const missing = S.list.filter((e) => e.playable && S.avail[e.id] === false).length;
  const playable = S.list.filter((e) => e.playable).length;
  $('stCheck').textContent = S.checked ? `${playable - missing} / ${playable} animations jouables trouvées.${missing ? ' Détail : /rpanim_check (F8).' : ''}` : 'Vérification en cours…';
}

// ── Invitations hors menu ────────────────────────────────────────────────
function timerBar(el, seconds) {
  el.style.transition = 'none'; el.style.transform = 'scaleX(1)';
  void el.offsetWidth;
  el.style.transition = `transform ${seconds}s linear`; el.style.transform = 'scaleX(0)';
}

function showIncoming(inv) {
  S.incoming = inv;
  $('tiFrom').textContent = inv.from;
  $('tiLabel').textContent = inv.label;
  $('tiRole').textContent = ` · ton rôle : ${inv.role}`;
  const k = S.keys;
  $('tiKeys').innerHTML = inv.adult
    ? `<span><b>${esc(k.accept || 'Y')}</b> voir et confirmer</span><span><b>${esc(k.refuse || 'L')}</b> refuser</span>`
    : `<span><b>${esc(k.accept || 'Y')}</b> accepter</span><span><b>${esc(k.refuse || 'L')}</b> refuser</span>`;
  $('toastIn').hidden = false;
  timerBar($('tiBar'), inv.timeout || 20);
  if (S.open) showConfirm(inv);
}

function hideIncoming(id) {
  if (S.incoming && id !== undefined && S.incoming.id !== id) return;
  S.incoming = null;
  $('toastIn').hidden = true;
  closeModal('modalConfirm');
}

function showOutgoing(inv) {
  S.outgoing = inv;
  $('toTo').textContent = inv.to;
  $('toLabel').textContent = inv.label;
  $('toastOut').hidden = false;
  timerBar($('toBar'), inv.timeout || 20);
}

// ── Messages du jeu ──────────────────────────────────────────────────────
function handle(m) {
  if (!m || !m.action) return;
  switch (m.action) {
    case 'open':
      setCatalog(m.catalog);
      S.favorites = m.favorites || []; S.recents = m.recents || []; S.prefs = m.prefs || {};
      S.avail = m.avail || {}; S.checked = !!m.checked; S.current = m.current || null; S.keys = m.keys || {};
      S.open = true;
      $('panel').classList.add('open'); $('panel').setAttribute('aria-hidden', 'false');
      render();
      if (m.incoming) showIncoming(m.incoming);
      if (m.outgoing) showOutgoing(m.outgoing);
      if (m.confirm && S.incoming && S.incoming.id === m.confirm) showConfirm(S.incoming);
      setTimeout(() => $('search').focus(), 50);
      break;
    case 'close':
      S.open = false;
      ['modalInvite', 'modalConfirm', 'modalSettings'].forEach(closeModal);
      $('panel').classList.remove('open'); $('panel').setAttribute('aria-hidden', 'true');
      break;
    case 'catalog': setCatalog(m.catalog); render(); break;
    case 'avail': S.avail = m.avail || {}; S.checked = !!m.checked; if (S.open) { render(); renderSettings(); } break;
    case 'recents': S.recents = m.list || []; if (S.open) render(); break;
    case 'current': S.current = m.id ? { id: m.id, label: m.label, role: m.role, preparing: m.preparing } : null; if (S.open) render(); break;
    case 'notify': notify(m.text, m.kind); break;
    case 'invite': showIncoming(m.invite); break;
    case 'inviteEnd': hideIncoming(m.id); break;
    case 'outgoing': showOutgoing(m.invite); break;
    case 'outgoingEnd': if (!S.outgoing || S.outgoing.id === m.id) { S.outgoing = null; $('toastOut').hidden = true; } break;
    case 'fade':
      $('fade').style.transitionDuration = `${(m.duration || 1500) / 1000}s`;
      $('fade').classList.toggle('on', !!m.on);
      break;
  }
}
window.addEventListener('message', (ev) => handle(ev.data));
window.__rpaHandle = handle;

// ── Événements de l'interface ────────────────────────────────────────────
$('cats').addEventListener('click', (ev) => {
  const b = ev.target.closest('[data-cat]');
  if (!b) return;
  S.cat = b.dataset.cat; S.q = ''; $('search').value = ''; S.sel = 0;
  render();
});
$('list').addEventListener('click', (ev) => {
  const fav = ev.target.closest('[data-fav]');
  if (fav) { ev.stopPropagation(); return toggleFav(fav.dataset.fav); }
  const card = ev.target.closest('.card');
  if (!card) return;
  S.sel = Number(card.dataset.i);
  activate(S.sel);
});
$('search').addEventListener('input', (ev) => { S.q = ev.target.value; S.sel = 0; render(); });
$('filters').addEventListener('click', (ev) => {
  const b = ev.target.closest('[data-f]');
  if (!b) return;
  S.filter = b.dataset.f; S.sel = 0;
  document.querySelectorAll('#filters button').forEach((x) => x.classList.toggle('on', x === b));
  render();
});
$('btnClose').addEventListener('click', closeMenu);
$('btnStop').addEventListener('click', () => post('stop'));
$('btnSettings').addEventListener('click', () => { renderSettings(); openModal('modalSettings'); });
document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', () => closeModal(b.closest('.modal').id)));

$('invRole').addEventListener('click', (ev) => {
  const b = ev.target.closest('[data-r]');
  if (b) { S.invRole = b.dataset.r; renderRole(); }
});
$('invPeople').addEventListener('click', (ev) => {
  const b = ev.target.closest('[data-p]');
  if (!b || b.disabled) return;
  S.invTarget = Number(b.dataset.p);
  document.querySelectorAll('#invPeople .person').forEach((x) => x.classList.toggle('on', x === b));
  $('invSend').disabled = false;
});
$('invSend').addEventListener('click', () => {
  const e = S.inviteFor;
  if (!e || !S.invTarget) return;
  post('invite', { id: e.id, target: S.invTarget, role: S.invRole, fade: $('invFade').checked });
  closeModal('modalInvite');
});

$('cfOk').addEventListener('change', () => { $('cfYes').disabled = !$('cfOk').checked; });
$('cfYes').addEventListener('click', () => {
  const inv = S.incoming;
  if (!inv) return closeModal('modalConfirm');
  if (inv.adult && !$('cfOk').checked) return;
  post('respond', { id: inv.id, accept: true, confirmAdult: inv.adult && $('cfOk').checked, fade: $('cfFade').checked });
  hideIncoming(inv.id);
});
$('cfNo').addEventListener('click', () => {
  const inv = S.incoming;
  if (inv) post('respond', { id: inv.id, accept: false });
  hideIncoming(inv && inv.id);
});

$('stDnd').addEventListener('change', async () => { S.prefs = (await post('prefs', { dnd: $('stDnd').checked })) || { ...S.prefs, dnd: $('stDnd').checked }; });
$('stAdult').addEventListener('change', async () => {
  S.prefs = (await post('prefs', { adult: $('stAdult').checked })) || { ...S.prefs, adult: $('stAdult').checked };
  render();
});
$('stRecheck').addEventListener('click', () => { S.checked = false; renderSettings(); post('check'); });

// Clavier
function columns() {
  const cards = [...document.querySelectorAll('#list .card')];
  if (cards.length < 2) return 1;
  const top = cards[0].offsetTop;
  const n = cards.findIndex((c) => c.offsetTop !== top);
  return n === -1 ? cards.length : n;
}
function moveSel(d) {
  if (!S.items || !S.items.length) return;
  S.sel = Math.min(S.items.length - 1, Math.max(0, S.sel + d));
  renderList();
  const el = document.querySelector('#list .card.sel');
  if (el) el.scrollIntoView({ block: 'nearest' });
}
function moveCat(d) {
  const ids = [...S.cats.map((c) => c.id), 'favoris', 'recents'];
  const i = Math.max(0, ids.indexOf(S.cat));
  S.cat = ids[(i + d + ids.length) % ids.length]; S.q = ''; $('search').value = ''; S.sel = 0;
  render();
}
document.addEventListener('keydown', (ev) => {
  if (!S.open) return;
  const typing = document.activeElement === $('search');
  const modal = anyModal();
  if (ev.key === 'Escape') {
    ev.preventDefault();
    if (modal) return closeModal(modal.id);
    if (typing && S.q) { S.q = ''; $('search').value = ''; return render(); }
    return closeMenu();
  }
  if (modal) return;
  if (ev.key === '/' && !typing) { ev.preventDefault(); return $('search').focus(); }
  if (ev.key === 'PageDown') { ev.preventDefault(); return moveCat(1); }
  if (ev.key === 'PageUp') { ev.preventDefault(); return moveCat(-1); }
  if (ev.key === 'ArrowDown') { ev.preventDefault(); if (typing) $('search').blur(); return moveSel(columns()); }
  if (ev.key === 'ArrowUp') { ev.preventDefault(); return moveSel(-columns()); }
  if (!typing && ev.key === 'ArrowRight') { ev.preventDefault(); return moveSel(1); }
  if (!typing && ev.key === 'ArrowLeft') { ev.preventDefault(); return moveSel(-1); }
  if (ev.key === 'Enter') { ev.preventDefault(); return activate(S.sel); }
  if (!typing && (ev.key === 'f' || ev.key === 'F')) { const e = S.items && S.items[S.sel]; if (e) toggleFav(e.id); }
});
