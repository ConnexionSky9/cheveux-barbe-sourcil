/* =========================================================
   ELYZEA CLOTHING · INTERFACE
   Boutique (rayons, filtres de packs, essayage, panier), « Ma tenue », renommer.
   ========================================================= */
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'elyzea_clothing';
if (!IN_GAME) document.documentElement.classList.add('preview');
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const post = (ev, data = {}) => (IN_GAME
  ? fetch(`https://${RES}/${ev}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).then((r) => r.json()).catch(() => ({}))
  : Promise.resolve(mock(ev, data)));

/* ---------- Icônes ---------- */
const P = {
  top: '<path d="M8 3l4 2 4-2 5 4-3 4-2-1v11H8V10l-2 1-3-4z"/>',
  tshirt: '<path d="M8 4h8l5 3-2.5 4L16 10v10H8V10l-2.5 1L3 7z"/><path d="M10 4a2 2 0 0 0 4 0"/>',
  pants: '<path d="M7 3h10l1 18h-4l-2-11-2 11H6z"/><path d="M7 7h10"/>',
  shoe: '<path d="M3 15c0-3 1-6 2-8h4l1 3c2 1 6 2 9 3 1.5.5 2 1.5 2 3v1H3z"/><path d="M3 18h19"/>',
  bag: '<rect x="5" y="7" width="14" height="13" rx="2"/><path d="M9 7V5a3 3 0 0 1 6 0v2M9 12h6"/>',
  vest: '<path d="M8 3h2l2 3 2-3h2l3 4v13H5V7z"/><path d="M12 6v14M8.5 11h1M14.5 11h1"/>',
  glove: '<path d="M7 21v-6l-2-4V7a1.5 1.5 0 0 1 3 0v3V5a1.5 1.5 0 0 1 3 0v5V4a1.5 1.5 0 0 1 3 0v6V6a1.5 1.5 0 0 1 3 0v8l-2 7z"/>',
  chain: '<path d="M7 3c0 6 2 10 5 12 3-2 5-6 5-12"/><circle cx="12" cy="18" r="3"/>',
  mask: '<path d="M4 6c5-2 11-2 16 0v6c0 5-4 8-8 8s-8-3-8-8z"/><path d="M7 10.5c1-1 3-1 4 0M13 10.5c1-1 3-1 4 0M9 16c2 1 4 1 6 0"/>',
  decal: '<path d="M12 3l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.4 6.8 19.1l1-5.8L3.5 9.2l5.9-.9z"/>',
  hat: '<path d="M4 16c2-1 14-1 16 0M6 16V12a6 6 0 0 1 12 0v4"/><path d="M2 17c4 2 16 2 20 0"/>',
  glasses: '<circle cx="7" cy="14" r="4"/><circle cx="17" cy="14" r="4"/><path d="M11 13.5c.7-.6 1.3-.6 2 0M3 13l-1-4M21 13l1-4"/>',
  earring: '<path d="M9 3a5 5 0 0 1 6 6c-1 3-4 3-4 6"/><circle cx="11" cy="18" r="3"/>',
  watch: '<rect x="7" y="7" width="10" height="10" rx="3"/><path d="M9 7l1-4h4l1 4M9 17l1 4h4l1-4M12 10v2l1.5 1"/>',
  bracelet: '<ellipse cx="12" cy="12" rx="8" ry="4.5"/><path d="M4 12c0 2.5 3.6 4.5 8 4.5s8-2 8-4.5"/><circle cx="12" cy="7.6" r="1.2"/>',
  none: '<circle cx="12" cy="12" r="8"/><path d="M6.5 6.5l11 11"/>',
};
const svg = (k, cls = '') => `<svg class="${cls}" viewBox="0 0 24 24" aria-hidden="true">${P[k] || P.top}</svg>`;
const ICON = {
  full: '<path d="M12 4a2 2 0 1 1 0 4 2 2 0 0 1 0-4zM8 10h8l-1 5h-1l-1 6h-2l-1-6H9z"/>',
  head: '<circle cx="12" cy="9" r="5"/><path d="M5 21c1-4 4-6 7-6s6 2 7 6"/>',
  torso: '<path d="M8 3l4 2 4-2 5 4-3 4-2-1v11H8V10l-2 1-3-4z"/>',
  legs: '<path d="M7 3h10l1 18h-4l-2-11-2 11H6z"/>',
  feet: '<path d="M3 15c0-3 1-6 2-8h4l1 3c2 1 6 2 9 3 1.5.5 2 1.5 2 3v1H3z"/>',
  left: '<path d="M4 12a8 8 0 1 0 2.3-5.6M4 4v4h4"/>',
  right: '<path d="M20 12a8 8 0 1 1-2.3-5.6M20 4v4h-4"/>',
  hands: '<path d="M7 11V5.5a1.5 1.5 0 0 1 3 0V10V4.5a1.5 1.5 0 0 1 3 0V10V5.5a1.5 1.5 0 0 1 3 0V13l-2 8H9l-4-6.5a1.6 1.6 0 0 1 2.6-1.8L9 14"/>',
};
const ico = (k) => `<svg viewBox="0 0 24 24" aria-hidden="true">${ICON[k]}</svg>`;

/* ---------- État ---------- */
let S = null;               // boutique ouverte
let cat = null;             // rayon affiché
let sel = null;             // { d, t, n } modèle choisi
let filter = 'all';         // 'all' | 'gta' | id de pack | 'hidden' (staff)
const cart = new Map();     // clé (rayon|modèle|coloris) -> { key, cat, drawable, texture, price, wear }
const MAX_CART = 30;        // même limite que le serveur (Config.MaxCart)
const keyOf = (c, d, t) => `${c}|${d}|${t}`;
const inCat = (id) => [...cart.values()].filter((x) => x.cat === id);
const wornOf = (id) => inCat(id).find((x) => x.wear) || null;
let wearNow = false, method = 'cash', shown = 60, query = '', camView = 'full', hands = false, busy = false;
const PAY = { cash: 'Liquide', bank: 'Banque' };
const money = (n) => `${Math.round(n || 0).toLocaleString('fr-FR')} ${S ? S.currency : '$'}`;
const catById = (id) => S.categories.find((c) => c.id === id);
const packById = (id) => S.packs.find((p) => p.id === id);
// Vêtements cachés par le staff : invisibles et invendables pour tout le monde (le staff les voit, marqués « Caché »)
const hidSet = (c) => c._hid || (c._hid = new Set(c.hidden || []));
const isHidden = (c, d) => d >= 0 && hidSet(c).has(d);

/* ---------- Packs : à quel pack appartient un modèle ? ---------- */
// Les modèles d'un pack se suivent : le rayon donne des blocs { from, to, pack, sold }
function rangeOf(c, d) {
  if (d < 0) return null;
  for (const r of c.ranges || []) if (d >= r.from && d <= r.to) return r;
  return null;
}
function info(c, d) {
  const r = rangeOf(c, d);
  if (!r) return { pack: null, num: d, sold: d < 0 || S.gta };
  return { pack: packById(r.pack) || { id: r.pack, label: r.pack, price: 100, folder: r.pack }, num: d - r.from, sold: r.sold };
}
function priceOf(c, d) {
  if (d < 0) return 0;
  const { pack } = info(c, d);
  let p = c.base * S.shop.multiplier / 100;
  if (pack) p = p * pack.price / 100;
  return Math.floor(p + 0.5);
}
const label = (c, d) => {
  if (d < 0) return `Retirer : ${c.label.toLowerCase()}`;
  const i = info(c, d);
  return i.pack ? `${c.single} ${i.pack.label} n°${i.num}` : `${c.single} n°${d}`;
};

/* ---------- Images réelles des vêtements ----------
   GTA  : images/<sexe>/<rayon>/<n°>_<coloris>.<ext>
   Pack : images/<sexe>/<rayon>/<pack>/<n° dans le pack>_<coloris>.<ext>
   Image absente : coloris 1 du même modèle, puis icône du rayon. Chaque adresse est testée une seule fois. */
const IMG = (() => {
  const seen = new Map();
  let cfg = null;
  function setup(im) {
    cfg = null;
    if (!im || !im.enabled) return;
    let base = String(im.base || 'images/');
    if (!base.endsWith('/')) base += '/';
    const exts = [im.ext || 'webp', ...(Array.isArray(im.fallbackExt) ? im.fallbackExt : [])].filter((e, i, a) => e && a.indexOf(e) === i);
    cfg = { base, exts, textureFallback: im.textureFallback !== false };
  }
  function build(c, d, t, ext) {
    const i = info(c, d);
    return i.pack ? `${cfg.base}${S.sex}/${c.id}/${i.pack.folder}/${i.num}_${t}.${ext}` : `${cfg.base}${S.sex}/${c.id}/${d}_${t}.${ext}`;
  }
  function candidates(c, d, t, strict) {
    if (!cfg || !c || d < 0) return [];
    const out = cfg.exts.map((e) => ({ url: build(c, d, t, e), tfb: false }));
    if (!strict && cfg.textureFallback && t > 0) cfg.exts.forEach((e) => out.push({ url: build(c, d, 0, e), tfb: true }));
    return out;
  }
  function probe(url) {
    const st = seen.get(url);
    if (st === true || st === false) return Promise.resolve(st);
    if (st) return st;
    const p = new Promise((res) => {
      const im = new Image();
      im.onload = () => { seen.set(url, true); res(true); };
      im.onerror = () => { seen.set(url, false); res(false); };
      im.src = url;
    });
    seen.set(url, p);
    return p;
  }
  function known(c, d, t, strict) {
    for (const k of candidates(c, d, t, strict)) {
      const st = seen.get(k.url);
      if (st === true) return k;
      if (st !== false) return undefined;
    }
    return null;
  }
  async function resolve(c, d, t, strict) {
    for (const k of candidates(c, d, t, strict)) if (await probe(k.url)) return k;
    return null;
  }
  return { setup, known, resolve, on: () => !!cfg };
})();

function photo(c, d, t, cls = 'img', strict = false) {
  if (!IMG.on() || !c || d < 0) return '';
  const k = IMG.known(c, d, t, strict);
  if (k === null) return '';
  if (k) return `<img class="${cls}${k.tfb ? ' tfb' : ''}" src="${esc(k.url)}" alt="" draggable="false">`;
  return `<i class="${cls} pending" data-ph="${c.id}|${d}|${t}|${strict ? 1 : 0}"></i>`;
}
let imgIO = null;
function hydrate(root) {
  if (!root) return;
  root.querySelectorAll('img.img, img.thumb').forEach((im) => im.parentNode.classList.add('hasimg'));
  const phs = root.querySelectorAll('[data-ph]');
  if (!phs.length) return;
  if (!imgIO) imgIO = new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { imgIO.unobserve(e.target); loadPh(e.target); } }), { rootMargin: '300px' });
  phs.forEach((p) => imgIO.observe(p));
}
async function loadPh(ph) {
  const [id, d, t, strict] = ph.dataset.ph.split('|');
  const k = await IMG.resolve(catById(id), Number(d), Number(t), strict === '1');
  if (!ph.isConnected) return;
  if (!k) { ph.remove(); return; }
  const im = new Image();
  im.className = `${ph.className.replace('pending', '').trim()} fade${k.tfb ? ' tfb' : ''}`;
  im.alt = ''; im.draggable = false; im.src = k.url;
  const parent = ph.parentNode;
  ph.replaceWith(im);
  parent.classList.add('hasimg');
}
function cardTexture(d, t) {
  const card = document.querySelector(`.card[data-d="${d}"]`);
  if (!card || !IMG.on()) return;
  card.querySelectorAll('.img').forEach((n) => n.remove());
  card.classList.remove('hasimg');
  card.insertAdjacentHTML('afterbegin', photo(cat, d, t));
  hydrate(card);
}

/* ---------- Liste des modèles d'un rayon (filtre de pack + recherche) ---------- */
function list(c) {
  const black = new Set(c.blacklist || []);
  const out = [];
  if (c.type === 'prop' && !S.itemsMode && (filter === 'all' || filter === 'gta')) out.push(-1);
  const hid = hidSet(c);
  if (filter === 'hidden') {
    if (!S.manage) return out;
    return [...hid].filter((d) => d < c.count && (!query || String(d).includes(query))).sort((a, b) => a - b);
  }
  for (let d = 0; d < c.count; d++) {
    if (!S.manage && hid.has(d)) continue;
    const r = rangeOf(c, d);
    if (r) {
      if (!r.sold || (filter !== 'all' && filter !== r.pack)) continue;
      if (query && !String(d - r.from).includes(query)) continue;
    } else {
      if (!S.gta || black.has(d) || (filter !== 'all' && filter !== 'gta')) continue;
      if (query && !String(d).includes(query)) continue;
    }
    out.push(d);
  }
  return out;
}
// Nombre de modèles par filtre pour un rayon
function counts(c) {
  const out = { all: 0, gta: 0 };
  const black = new Set(c.blacklist || []);
  let inPacks = 0;
  for (const r of c.ranges || []) {
    if (!r.sold) { inPacks += r.to - r.from + 1; continue; }
    const n = r.to - r.from + 1;
    out[r.pack] = (out[r.pack] || 0) + n;
    out.all += n;
    inPacks += n;
  }
  if (S.gta) {
    let g = c.count - inPacks;
    black.forEach((d) => { if (d < c.count && !rangeOf(c, d)) g -= 1; });
    out.gta = Math.max(0, g);
    out.all += out.gta;
  }
  const hid = [...hidSet(c)].filter((d) => d < c.count);
  if (S.manage) out.hidden = hid.length;
  else hid.forEach((d) => {
    const r = rangeOf(c, d);
    if (r) { if (r.sold) { out[r.pack] -= 1; out.all -= 1; } } else if (S.gta && !black.has(d)) { out.gta -= 1; out.all -= 1; }
  });
  return out;
}

/* ---------- Rendu ---------- */
// Nombre de modèles par filtre, tous rayons confondus (barre des collections)
let totals = null;
function allCounts() {
  if (totals) return totals;
  totals = { per: {}, sum: { all: 0, gta: 0 } };
  for (const c of S.categories) {
    const n = counts(c);
    totals.per[c.id] = n;
    for (const k in n) totals.sum[k] = (totals.sum[k] || 0) + n[k];
  }
  return totals;
}
const countIn = (c, f) => (allCounts().per[c.id] || {})[f] || 0;

function renderRail() {
  const cats = filter === 'all' ? S.categories : S.categories.filter((c) => countIn(c, filter) > 0);
  $('#rail').innerHTML = cats.map((c) => `<button class="${cat && c.id === cat.id ? 'on' : ''}" data-cat="${c.id}" title="${esc(c.label)}">
    ${svg(c.icon)}<span>${esc(c.label)}</span>${filter !== 'all' ? `<em class="cnt">${countIn(c, filter)}</em>` : ''}${inCat(c.id).length ? `<i class="dot">${inCat(c.id).length}</i>` : ''}</button>`).join('');
}
// Barre « Collection » : Tout / GTA / un bouton par pack, valable pour toute la boutique
function renderFilters() {
  const n = allCounts().sum;
  const packs = S.packs.filter((p) => n[p.id]);
  const staff = S.manage && n.hidden ? `<button class="${filter === 'hidden' ? 'on' : ''} hidchip" data-filter="hidden" title="Staff : vêtements cachés (personne d'autre ne les voit)">🙈 Cachés<i>${n.hidden}</i></button>` : '';
  if (!packs.length && !staff) { $('#filters').innerHTML = ''; $('#filters').style.display = 'none'; filter = 'all'; return; }
  $('#filters').style.display = '';
  if (filter !== 'all' && !n[filter]) filter = 'all';
  const chip = (id, txt, k) => `<button class="${filter === id ? 'on' : ''}" data-filter="${esc(id)}">${esc(txt)}<i>${k}</i></button>`;
  $('#filters').innerHTML = '<span class="flabel">Collection</span>' + chip('all', 'Tout', n.all) + (S.gta && n.gta ? chip('gta', 'GTA', n.gta) : '')
    + packs.map((p) => chip(p.id, p.label, n[p.id])).join('') + staff;
}
// Choisir une collection : le menu de gauche ne garde que les rayons où elle a des modèles
function setFilter(f) {
  filter = f; shown = 60;
  renderFilters();
  if (filter !== 'all' && countIn(cat, filter) === 0) {
    const first = S.categories.find((c) => countIn(c, filter) > 0);
    if (first) return chooseCat(first.id);
  }
  renderRail(); renderGrid();
}
function renderGrid(keepScroll) {
  const g = $('#grid'), top = g.scrollTop;
  const all = list(cat);
  $('#catTitle').textContent = cat.label;
  const models = all.filter((d) => d >= 0);
  // Prix le plus bas des modèles affichés (un modèle par pack suffit : même prix dans un pack)
  const sample = new Map();
  models.forEach((d) => { const k = (rangeOf(cat, d) || { pack: 'gta' }).pack; if (!sample.has(k)) sample.set(k, d); });
  const from = sample.size ? Math.min(...[...sample.values()].map((d) => priceOf(cat, d))) : 0;
  $('#catSub').textContent = `${models.length} modèle${models.length > 1 ? 's' : ''}${sample.size ? ` · à partir de ${money(from)}` : ''}`;
  const byD = new Map(inCat(cat.id).map((x) => [x.drawable, x]));
  g.innerHTML = all.slice(0, shown).map((d) => {
    const i = info(cat, d);
    const worn = d === cat.current.drawable, isSel = sel && sel.d === d, inCart = byD.get(d), isCart = !!inCart;
    const t = isSel ? sel.t : isCart ? inCart.texture : worn ? cat.current.texture : 0;
    return `<button class="card ${isSel ? 'sel' : ''} ${d < 0 ? 'none' : ''} ${isHidden(cat, d) ? 'hidden-item' : ''}" data-d="${d}" aria-label="${esc(label(cat, d))}">
      ${photo(cat, d, t)}${svg(d < 0 ? 'none' : cat.icon, 'ico')}
      <span class="num">${d < 0 ? 'AUCUN' : '#' + i.num}</span>
      ${i.pack ? `<span class="pack">${esc(i.pack.label)}</span>` : ''}
      ${isHidden(cat, d) ? '<span class="tag hid">Caché</span>' : isCart ? '<span class="tag incart">Panier</span>' : worn ? '<span class="tag worn">Porté</span>' : ''}
      <span class="foot"><b>${d < 0 ? 'Gratuit' : money(priceOf(cat, d))}</b><span class="live">Sur toi</span></span></button>`;
  }).join('') + (all.length > shown ? `<div class="more">Défile pour voir plus (${all.length - shown} restants)</div>` : '')
    + (all.length ? '' : '<div class="empty">Aucun modèle ne correspond.</div>');
  g.scrollTop = keepScroll ? top : 0;
  hydrate(g);
}
function renderDetail() {
  const el = $('#detail');
  if (!sel) { el.innerHTML = '<p style="color:var(--muted)">Choisis un modèle pour l\'essayer.</p>'; return; }
  const p = priceOf(cat, sel.d), i = info(cat, sel.d);
  const n = inCat(cat.id).length;
  const same = cart.has(keyOf(cat.id, sel.d, sel.t));
  const worn = sel.d === cat.current.drawable && sel.t === cat.current.texture;
  const full = cart.size >= MAX_CART && S.itemsMode;
  const hidden = isHidden(cat, sel.d);
  const forSale = sel.d < 0 || (i.sold && !hidden);
  const sws = Array.from({ length: sel.n }, (_, k) => `<button class="${k === sel.t ? 'on' : ''}" data-t="${k}" aria-label="Coloris ${k + 1}">${photo(cat, sel.d, k, 'thumb', true)}<span class="n">${k + 1}</span></button>`).join('');
  el.innerHTML = `<div class="drow"><div class="dname"><b>${esc(label(cat, sel.d))}${i.pack ? `<span class="dpack">${esc(i.pack.label)}</span>` : ''}<span class="badge-live">Sur toi</span></b>
      <span>${sel.d < 0 ? 'Retire l\'accessoire porté' : `${sel.n} coloris disponible${sel.n > 1 ? 's' : ''}`}</span></div>
      <div class="price ${p ? '' : 'free'}">${p ? money(p) : 'Gratuit'}</div></div>
    ${sel.d >= 0 && sel.n > 1 ? `<div class="tex"><label>Coloris</label><button class="arrow" data-tstep="-1" aria-label="Coloris précédent">‹</button><div class="sw">${sws}</div><button class="arrow" data-tstep="1" aria-label="Coloris suivant">›</button></div>` : '<div style="height:12px"></div>'}
    <button class="btn primary wide" id="add" ${same || (worn && !n) || !forSale || full ? 'disabled' : ''}>${hidden ? 'Caché : pas en vente' : !forSale ? 'Pas vendu ici'
      : same ? '✓ Dans le panier' : worn && !n ? 'Tu le portes déjà' : full ? `Panier plein (${MAX_CART} articles)` : n && !S.itemsMode ? 'Remplacer dans le panier'
      : n ? `Ajouter au panier <small>· ${n} ${n > 1 ? esc(cat.label.toLowerCase()) : esc(cat.single.toLowerCase())} déjà</small>` : 'Ajouter au panier'}</button>
    ${S.manage && sel.d >= 0 ? `<button class="btn ghost wide staffhide" id="hideBtn" title="Staff · toutes les boutiques, tous les coloris de ce modèle">${hidden ? '👁 Remettre en vente pour tout le monde' : '🙈 Cacher pour tout le monde'}</button>` : ''}`;
  hydrate(el);
  const on = el.querySelector('.sw .on');
  if (on) on.scrollIntoView({ block: 'nearest', inline: 'nearest' });
}
function renderCart() {
  const items = [...cart.values()];
  const groups = S.categories.map((c) => ({ c, list: inCat(c.id) })).filter((g) => g.list.length);
  $('#cartN').textContent = items.length;
  $('#cartClear').hidden = !items.length;
  $('#cartSum').textContent = items.length ? `${items.length} article${items.length > 1 ? 's' : ''} · ${groups.length} rayon${groups.length > 1 ? 's' : ''}` : '';
  $('#cartItems').innerHTML = items.length ? groups.map(({ c, list }) => {
    const sub = list.reduce((a, b) => a + b.price, 0);
    return `<div class="cgroup"><div class="ghead">${svg(c.icon)}<b>${esc(c.label)}</b><i>${list.length}</i><span>${money(sub)}</span></div>
      ${list.map((it) => {
        const i = info(c, it.drawable);
        const multi = S.itemsMode && list.length > 1;
        return `<div class="ci ${it.wear && multi ? 'worn' : ''}"><span class="th">${svg(it.drawable < 0 ? 'none' : c.icon)}${photo(c, it.drawable, it.texture, 'thumb')}</span>
          <span class="tx" data-goto="${esc(it.key)}" title="Voir sur moi"><b>${esc(label(c, it.drawable))}</b><span>${it.drawable >= 0 ? `Coloris ${it.texture + 1}` : ''}${i.pack ? ` · ${esc(i.pack.label)}` : ''}</span></span>
          ${multi ? `<button class="wearbtn ${it.wear ? 'on' : ''}" data-wear="${esc(it.key)}" title="${it.wear ? 'C\'est la pièce que tu vois sur toi' : 'Voir cette pièce sur moi'}">${it.wear ? 'Sur toi' : 'Essayer'}</button>` : ''}
          <span class="p">${it.price ? money(it.price) : 'Gratuit'}</span><button class="rm" data-rm="${esc(it.key)}" aria-label="Retirer du panier">✕</button></div>`;
      }).join('')}</div>`;
  }).join('') : `<div class="cempty"><b>Ton panier est vide</b>Survole un vêtement pour le voir sur toi, puis « Ajouter au panier ».${S.itemsMode ? '<br>Tu peux prendre <b>plusieurs hauts, plusieurs pantalons…</b> : chaque vêtement arrive dans ton inventaire.' : ''}</div>`;
  hydrate($('#cartItems'));
  const total = items.reduce((a, b) => a + b.price, 0);
  const pays = S.payments.filter((k) => PAY[k]);
  if (!pays.includes(method)) method = pays[0];
  const short = (S.money[method] || 0) < total;
  const several = groups.some((g) => g.list.length > 1);
  const wearOpt = S.itemsMode ? `<label class="wear"><input type="checkbox" id="wearNow" ${wearNow ? 'checked' : ''}><span>Porter tout de suite<small>${wearNow
    ? (several ? 'Une pièce par rayon : celle marquée « Sur toi ». Le reste et tes vêtements actuels vont dans ton inventaire.' : 'Tes vêtements actuels iront dans ton inventaire.')
    : 'Tout ce que tu achètes va dans ton inventaire.'}</small></span></label>` : '';
  $('#cartFoot').innerHTML = `<div class="total"><span>Total</span><b>${money(total)}</b></div>${wearOpt}
    <div class="pay">${pays.map((k) => `<button class="${k === method ? 'on' : ''} ${(S.money[k] || 0) < total ? 'short' : ''}" data-pay="${k}"><small>${PAY[k]}</small><b>${money(S.money[k])}</b></button>`).join('')}</div>
    ${items.length && short ? `<p class="warn">Solde ${PAY[method].toLowerCase()} insuffisant : il manque ${money(total - (S.money[method] || 0))}.</p>` : ''}
    <button class="btn primary wide" id="payBtn" ${!items.length || short || busy ? 'disabled' : ''}>${busy ? 'Paiement…' : items.length ? `Payer ${money(total)}` : 'Payer'}</button>`;
}
function renderTools() {
  const v = (id, l) => `<button class="${camView === id ? 'on' : ''}" data-view="${id}">${ico(id)}<span>${l}</span></button>`;
  $('#tools').innerHTML = `${v('full', 'Entier')}${v('head', 'Tête')}${v('torso', 'Haut')}${v('legs', 'Bas')}${v('feet', 'Pieds')}
    <span class="sep"></span><button data-rot="-1" aria-label="Pivoter à gauche">${ico('left')}</button><button data-rot="1" aria-label="Pivoter à droite">${ico('right')}</button>
    <span class="sep"></span><button class="${hands ? 'on' : ''}" data-hands="1">${ico('hands')}<span>Mains</span></button>`;
}
function sendLayout() {
  const W = window.innerWidth;
  const shop = document.querySelector('.shop').getBoundingClientRect();
  const cartEl = document.querySelector('.cart').getBoundingClientRect();
  const left = W > 760 ? shop.right : 0, right = W > 760 ? cartEl.left : W;
  post('layout', { frac: ((left + right) / 2 - W / 2) / (W / 2) });
}
window.addEventListener('resize', () => { if (S) sendLayout(); });

/* ---------- Actions ---------- */
const CAM_OF = { torso: 'torso', head: 'head', legs: 'legs', feet: 'feet', back: 'back', hand: 'hand', full: 'full' };
function setView(v) { camView = v; post('view', { view: v }); renderTools(); }
async function chooseCat(id) {
  cat = catById(id);
  query = ''; $('#search').value = ''; shown = 60;
  const w = wornOf(id);
  const d = w ? w.drawable : cat.current.drawable, t = w ? w.texture : cat.current.texture;
  sel = { d, t, n: 1 };
  renderRail(); renderFilters(); renderGrid();
  const r = await post('textures', { cat: id, drawable: d }) || {};
  sel.n = r.textures || sel.n;
  renderDetail();
  setView(CAM_OF[cat.cam] || 'full');
}
async function tryOn(d, t = 0) {
  const r = await post('try', { cat: cat.id, drawable: d, texture: t }) || {};
  sel = { d, t: r.texture ?? t, n: r.textures || 1 };
  renderGrid(true); renderDetail();
}
function refreshAll() { renderRail(); renderGrid(true); renderDetail(); renderCart(); }
// Ce que montre le personnage pour un rayon : la pièce « Sur toi » du panier, sinon ce qu'il portait
function showCat(id) {
  const c = catById(id), w = wornOf(id);
  post('try', { cat: id, drawable: w ? w.drawable : c.current.drawable, texture: w ? w.texture : c.current.texture });
  if (cat.id === id) sel = { d: w ? w.drawable : c.current.drawable, t: w ? w.texture : c.current.texture, n: sel ? sel.n : 1 };
}
function addToCart() {
  if (!sel) return;
  if (sel.d >= 0 && (!info(cat, sel.d).sold || isHidden(cat, sel.d))) return;
  const k = keyOf(cat.id, sel.d, sel.t);
  if (cart.has(k)) return;
  if (!S.itemsMode) inCat(cat.id).forEach((x) => cart.delete(x.key));   // sans inventaire : un seul article par rayon
  if (cart.size >= MAX_CART) return toast(`Panier plein : ${MAX_CART} articles au maximum.`, 'err');
  inCat(cat.id).forEach((x) => { x.wear = false; });
  cart.set(k, { key: k, cat: cat.id, drawable: sel.d, texture: sel.t, price: priceOf(cat, sel.d), wear: true });
  const n = inCat(cat.id).length;
  toast(n > 1 ? `${label(cat, sel.d)} ajouté · ${n} ${cat.label.toLowerCase()} dans le panier.` : `${label(cat, sel.d)} ajouté au panier.`, 'ok');
  refreshAll();
}
function removeFromCart(k) {
  const it = cart.get(k);
  if (!it) return;
  cart.delete(k);
  if (it.wear) { const rest = inCat(it.cat); if (rest.length) rest[rest.length - 1].wear = true; }
  showCat(it.cat);
  refreshAll();
}
// Choisir la pièce d'un rayon que l'on voit sur soi (et que l'on porte en sortant si « Porter tout de suite »)
function setWear(k) {
  const it = cart.get(k);
  if (!it) return;
  inCat(it.cat).forEach((x) => { x.wear = x.key === k; });
  showCat(it.cat);
  refreshAll();
}
function clearCart() {
  const cats = [...new Set([...cart.values()].map((x) => x.cat))];
  cart.clear();
  cats.forEach(showCat);
  refreshAll();
  toast('Panier vidé : ta tenue d\'avant est remise.', 'ok');
}
function pay() {
  if (busy || !cart.size) return;
  busy = true; renderCart();
  post('pay', { method, wearNow, cart: [...cart.values()].map((x) => ({ cat: x.cat, drawable: x.drawable, texture: x.texture, wear: x.wear })) });
}
function askClose() {
  if (!cart.size) return doClose();
  $('#modal').innerHTML = `<div class="modal"><div class="mbox" role="dialog" aria-labelledby="mt"><h3 id="mt">Quitter sans payer ?</h3>
    <p>Les ${cart.size} article${cart.size > 1 ? 's' : ''} du panier ne seront pas achetés et tu retrouveras ta tenue d'avant.</p>
    <div class="row"><button class="btn ghost" data-m="stay">Rester</button><button class="btn primary" data-m="leave">Quitter</button></div></div></div>`;
  $('#modal [data-m=stay]').focus();
}
function doClose() { $('#modal').innerHTML = ''; post('close'); }
let toastT;
function toast(text, kind = '') { const t = $('#toast'); t.textContent = text; t.className = `toast on ${kind}`; clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('on'), 2600); }

/* ---------- Événements de la boutique ---------- */
$('#rail').addEventListener('click', (e) => { const b = e.target.closest('[data-cat]'); if (b) chooseCat(b.dataset.cat); });
$('#filters').addEventListener('click', (e) => {
  const b = e.target.closest('[data-filter]'); if (!b) return;
  setFilter(b.dataset.filter);
});
$('#grid').addEventListener('click', (e) => { const b = e.target.closest('[data-d]'); if (b) { hover = null; tryOn(Number(b.dataset.d), 0); } });

// Aperçu direct : survoler un modèle le montre sur le personnage ; quitter la grille remet le modèle choisi
let hover = null, hoverT = null;
function liveBadge(on) { const b = document.querySelector('.badge-live'); if (b) b.style.visibility = on ? '' : 'hidden'; }
function preview(d, t) {
  liveBadge(!sel || sel.d === d);
  clearTimeout(hoverT);
  hoverT = setTimeout(() => post('try', { cat: cat.id, drawable: d, texture: t }), 70);
}
function endPreview() {
  if (hover === null) return;
  hover = null;
  document.querySelectorAll('.card.pv').forEach((c) => c.classList.remove('pv'));
  if (sel) preview(sel.d, sel.t);
}
$('#grid').addEventListener('mouseover', (e) => {
  const b = e.target.closest('[data-d]');
  if (!b) return;
  const d = Number(b.dataset.d);
  if (hover === d) return;
  document.querySelectorAll('.card.pv').forEach((c) => c.classList.remove('pv'));
  hover = d;
  b.classList.add('pv');
  if (!sel || sel.d !== d) preview(d, 0); else preview(sel.d, sel.t);
});
$('#grid').addEventListener('mouseleave', endPreview);
$('#detail').addEventListener('mouseover', (e) => {
  const t = e.target.closest('[data-t]');
  if (t && sel) { hover = sel.d; preview(sel.d, Number(t.dataset.t)); cardTexture(sel.d, Number(t.dataset.t)); }
});
$('#detail').addEventListener('mouseleave', () => { if (hover !== null) { hover = null; if (sel) { preview(sel.d, sel.t); cardTexture(sel.d, sel.t); } } });

function stepModel(delta) {
  const all = list(cat);
  if (!all.length) return;
  let i = all.indexOf(sel ? sel.d : all[0]);
  i = Math.max(0, Math.min(all.length - 1, (i < 0 ? 0 : i) + delta));
  if (i >= shown) shown = i + 30;
  tryOn(all[i], 0).then(() => { const c = document.querySelector(`.card[data-d="${all[i]}"]`); if (c) c.scrollIntoView({ block: 'nearest' }); });
}
$('#grid').addEventListener('scroll', (e) => {
  const g = e.target;
  if (g.scrollTop + g.clientHeight > g.scrollHeight - 200 && list(cat).length > shown) { shown += 60; renderGrid(true); }
});
$('#detail').addEventListener('click', (e) => {
  const t = e.target.closest('[data-t]'); if (t) return tryOn(sel.d, Number(t.dataset.t));
  const st = e.target.closest('[data-tstep]'); if (st) return tryOn(sel.d, (sel.t + Number(st.dataset.tstep) + sel.n) % sel.n);
  if (e.target.closest('#add')) addToCart();
  const hb = e.target.closest('#hideBtn');
  if (hb && S.manage && sel && sel.d >= 0) { hb.disabled = true; post('setHidden', { cat: cat.id, drawable: sel.d, hide: !isHidden(cat, sel.d) }); }
});
$('#cartItems').addEventListener('click', (e) => {
  const r = e.target.closest('[data-rm]'); if (r) return removeFromCart(r.dataset.rm);
  const w = e.target.closest('[data-wear]'); if (w) return setWear(w.dataset.wear);
  const g = e.target.closest('[data-goto]');
  if (g) { const it = cart.get(g.dataset.goto); if (it) { setWear(it.key); if (cat.id !== it.cat) chooseCat(it.cat); } }
});
$('#cartClear').addEventListener('click', () => {
  $('#modal').innerHTML = `<div class="modal"><div class="mbox" role="dialog" aria-labelledby="mt"><h3 id="mt">Vider le panier ?</h3>
    <p>Les ${cart.size} article${cart.size > 1 ? 's' : ''} sont retirés et tu retrouves ta tenue d'avant.</p>
    <div class="row"><button class="btn ghost" data-m="stay">Garder</button><button class="btn primary" data-m="clear">Vider</button></div></div></div>`;
});
$('#cartFoot').addEventListener('change', (e) => { if (e.target.id === 'wearNow') { wearNow = e.target.checked; renderCart(); } });
$('#cartFoot').addEventListener('click', (e) => {
  const p = e.target.closest('[data-pay]'); if (p) { method = p.dataset.pay; return renderCart(); }
  if (e.target.closest('#payBtn')) pay();
});
$('#tools').addEventListener('click', (e) => {
  const v = e.target.closest('[data-view]'); if (v) return setView(v.dataset.view);
  const r = e.target.closest('[data-rot]'); if (r) return post('rotate', { delta: 45 * Number(r.dataset.rot) });
  if (e.target.closest('[data-hands]')) { hands = !hands; post('hands', { on: hands }); renderTools(); }
});
$('#search').addEventListener('input', (e) => { query = e.target.value.replace(/\D/g, ''); e.target.value = query; shown = 60; renderGrid(); });
$('#close').addEventListener('click', askClose);
$('#modal').addEventListener('click', (e) => {
  const m = e.target.closest('[data-m]'); if (!m) return;
  if (m.dataset.m === 'leave') doClose();
  else if (m.dataset.m === 'clear') { $('#modal').innerHTML = ''; clearCart(); }
  else $('#modal').innerHTML = '';
});

// Glisser sur la zone centrale pour tourner le personnage
let drag = null, acc = 0, rotT = null;
$('#stage').addEventListener('mousedown', (e) => { drag = e.clientX; $('#stage').classList.add('drag'); });
window.addEventListener('mouseup', () => { drag = null; $('#stage').classList.remove('drag'); });
window.addEventListener('mousemove', (e) => {
  if (drag === null) return;
  acc += (e.clientX - drag) * 0.6; drag = e.clientX;
  if (!rotT) rotT = setTimeout(() => { if (Math.abs(acc) > 0.5) post('rotate', { delta: acc }); acc = 0; rotT = null; }, 40);
});
document.addEventListener('keydown', (e) => {
  if ($('#app').classList.contains('hidden') || e.target.tagName === 'INPUT') { if (e.key === 'Escape' && e.target.tagName === 'INPUT') e.target.blur(); return; }
  if (e.key === 'Escape') { if ($('#modal').innerHTML) $('#modal').innerHTML = ''; else askClose(); }
  if (e.key === 'a' || e.key === 'q') post('rotate', { delta: -15 });
  if (e.key === 'e' || e.key === 'd') post('rotate', { delta: 15 });
  const cols = Math.max(1, Math.round($('#grid').clientWidth / 132));
  if (e.key === 'ArrowRight') { e.preventDefault(); stepModel(1); }
  if (e.key === 'ArrowLeft') { e.preventDefault(); stepModel(-1); }
  if (e.key === 'ArrowDown') { e.preventDefault(); stepModel(cols); }
  if (e.key === 'ArrowUp') { e.preventDefault(); stepModel(-cols); }
  if (e.key === 'Enter' && sel && $('#add') && !$('#add').disabled) addToCart();
});

/* ---------- « Ma tenue » ---------- */
let W = null;
function renderWardrobe() {
  if (!W) return;
  $('#wList').innerHTML = W.list.map((c) => `<div class="wi ${c.naked ? 'naked' : ''}"><span class="th">${svg(c.icon)}</span>
      <span class="tx"><b>${esc(c.naked ? 'Rien' : c.title)}</b><span>${esc(c.label)}${c.naked ? '' : ` · coloris ${c.texture + 1}`}${!c.naked && c.pack ? ` · ${esc(c.pack)}` : ''}</span></span>
      ${W.itemsMode && !c.naked ? `<button class="mini gold" data-wren="${c.id}" data-name="${esc((W.names || {})[c.id] || '')}">Renommer</button><button class="mini" data-woff="${c.id}" title="Ranger dans l'inventaire">Ranger</button>` : ''}</div>`).join('');
  $('#wFoot').innerHTML = W.itemsMode
    ? '« Ranger » met la pièce dans ton inventaire. Pour remettre un vêtement, utilise-le depuis ton inventaire : ce que tu portais à sa place y retourne.'
    : 'Les vêtements en objets demandent elyzea_inventory.';
}
function closeWardrobe() { $('#wardrobe').classList.add('hidden'); W = null; if (oDlg) closeODlg(false); post('wardrobeClose'); }
$('#wList').addEventListener('click', (e) => {
  const off = e.target.closest('[data-woff]'); if (off) { off.disabled = true; return post('unequip', { cat: off.dataset.woff }); }
  const rn = e.target.closest('[data-wren]'); if (rn) post('renameWorn', { cat: rn.dataset.wren, name: rn.dataset.name });
});
$('#wClose').addEventListener('click', closeWardrobe);

/* ---------- Mes tenues (tenues enregistrées) ---------- */
let O = null;               // { outfits, categories, max, maxCategories, nameMax, itemsMode }
let wTab = 'worn', oCat = 'all', oDlg = null;
const plural = (n, one, many) => `${n} ${n > 1 ? many : one}`;
const oCatLabel = (id) => (O && O.categories.find((c) => c.id === id) || {}).label || 'Sans catégorie';
const pieceName = (cat) => ((W && W.list.find((c) => c.id === cat)) || {}).single || cat;
function setWTab(t) {
  wTab = t;
  document.querySelectorAll('[data-wtab]').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.wtab === t)));
  $('#paneWorn').classList.toggle('hidden', t !== 'worn');
  $('#paneOutfits').classList.toggle('hidden', t !== 'outfits');
  if (t === 'outfits') { if (!O) $('#oList').innerHTML = '<div class="oempty">Chargement…</div>'; post('outfitsList'); }
}
document.querySelector('.wtabs').addEventListener('click', (e) => { const b = e.target.closest('[data-wtab]'); if (b) setWTab(b.dataset.wtab); });
function renderOutfits() {
  if (!O) return;
  const list = O.outfits, customs = O.categories.filter((c) => !c.default);
  $('#oCount').textContent = list.length || '';
  if (oCat !== 'all' && oCat !== '' && !O.categories.some((c) => c.id === oCat)) oCat = 'all';
  const n = (id) => list.filter((o) => o.category === id).length;
  const chips = [`<button data-ocat="all" class="${oCat === 'all' ? 'on' : ''}">Toutes <i>${list.length}</i></button>`]
    .concat(O.categories.map((c) => `<button data-ocat="${esc(c.id)}" class="${oCat === c.id ? 'on' : ''}">${esc(c.label)} <i>${n(c.id)}</i></button>`));
  if (n('')) chips.push(`<button data-ocat="" class="${oCat === '' ? 'on' : ''}">Sans catégorie <i>${n('')}</i></button>`);
  if (customs.length < O.maxCategories) chips.push('<button class="add" data-ocatnew title="Créer une catégorie">＋ Catégorie</button>');
  $('#oCats').innerHTML = chips.join('');
  const cur = O.categories.find((c) => c.id === oCat);
  const bar = cur && !cur.default
    ? `<div class="ocatbar"><span>Catégorie personnelle</span><button class="mini" data-ocatren>Renommer</button><button class="mini" data-ocatdel>Supprimer</button></div>` : '';
  const shown = list.filter((o) => oCat === 'all' || o.category === oCat);
  $('#oList').innerHTML = bar + (shown.length ? shown.map((o) => {
    const warn = [];
    if (o.wrongSex) warn.push(`Tenue de personnage ${o.sex === 'male' ? 'homme' : 'femme'} : impossible à porter`);
    if (!o.wrongSex && o.unavailable && o.unavailable.length) warn.push(`Pack absent : ${o.unavailable.map(pieceName).join(', ')}`);
    if (!o.wrongSex && O.itemsMode && o.missing && o.missing.length) warn.push(`Pas dans ton inventaire : ${o.missing.map(pieceName).join(', ')}`);
    return `<div class="oi" data-oid="${o.id}"><div class="h"><b>${esc(o.name)}</b></div>
      <div class="meta">${esc(oCatLabel(o.category))} · ${plural(o.count, 'pièce', 'pièces')}</div>
      ${warn.map((w) => `<div class="warnline">${esc(w)}</div>`).join('')}
      <div class="acts"><button class="mini wear" data-oact="wear" ${o.wrongSex ? 'disabled' : ''}>Porter</button>
        <button class="mini" data-oact="edit">Modifier</button>
        <button class="mini" data-oact="replace" title="Remplacer par ce que je porte maintenant">Remplacer</button>
        <button class="mini danger" data-oact="delete">Supprimer</button></div></div>`;
  }).join('') : `<div class="oempty"><b>${list.length ? 'Aucune tenue ici' : 'Pas encore de tenue'}</b>${list.length ? 'Choisis une autre catégorie.' : 'Habille-toi, puis « Enregistrer ma tenue actuelle ».'}</div>`);
  $('#oFoot').innerHTML = `${list.length} / ${O.max} tenues. ` + (O.itemsMode
    ? '« Porter » met en une fois les vêtements de la tenue qui sont dans ton inventaire ; ce que tu portais y retourne.'
    : '« Porter » remet toute la tenue en une fois.');
  $('#oSaveBtn').disabled = list.length >= O.max;
}
// Fenêtre : champs (texte / liste), confirmation
function catOptions(sel) {
  return [`<option value="">Sans catégorie</option>`].concat(O.categories.map((c) => `<option value="${esc(c.id)}" ${c.id === sel ? 'selected' : ''}>${esc(c.label)}</option>`)).join('');
}
function openODlg(d) {
  oDlg = d;
  $('#oDlgT').textContent = d.title; $('#oDlgP').textContent = d.text || ''; $('#oDlgP').hidden = !d.text;
  $('#oDlgBody').innerHTML = (d.fields || []).map((f) => f.type === 'select'
    ? `<label for="oF_${f.id}">${esc(f.label)}</label><select id="oF_${f.id}">${f.options}</select>`
    : `<label for="oF_${f.id}">${esc(f.label)}</label><input id="oF_${f.id}" maxlength="${O ? O.nameMax : 32}" value="${esc(f.value || '')}" placeholder="${esc(f.placeholder || '')}" autocomplete="off">`).join('');
  $('#oDlgOk').textContent = d.ok || 'Valider';
  $('#oDlgOk').classList.toggle('danger', !!d.danger);
  $('#oDlg').classList.remove('hidden');
  const first = $('#oDlgBody input'); setTimeout(() => (first || $('#oDlgOk')).focus(), 30);
}
function closeODlg(ok) {
  const d = oDlg; oDlg = null;
  $('#oDlg').classList.add('hidden');
  if (!ok || !d) return;
  const v = {}; (d.fields || []).forEach((f) => { v[f.id] = $(`#oF_${f.id}`).value.trim(); });
  d.onOk(v);
}
$('#oDlgOk').addEventListener('click', () => closeODlg(true));
$('#oDlgCancel').addEventListener('click', () => closeODlg(false));
// Fenêtre ouverte : Échap l'annule, Entrée la valide (avant tous les autres raccourcis)
window.addEventListener('keydown', (e) => {
  if (!oDlg) return;
  if (e.key === 'Escape') { e.stopImmediatePropagation(); e.preventDefault(); closeODlg(false); }
  else if (e.key === 'Enter' && e.target.tagName !== 'BUTTON') { e.stopImmediatePropagation(); e.preventDefault(); closeODlg(true); }
}, true);
$('#oSaveBtn').addEventListener('click', () => openODlg({
  title: 'Enregistrer ma tenue', text: 'Tous les vêtements et accessoires portés maintenant, avec leurs coloris.',
  fields: [{ id: 'name', label: 'Nom', placeholder: 'ex : Tenue de soirée' }, { id: 'cat', label: 'Catégorie', type: 'select', options: catOptions(oCat === 'all' ? '' : oCat) }],
  ok: 'Enregistrer', onOk: (v) => { if (!v.name) return toast('Donne un nom à ta tenue.', 'err'); post('outfitSave', { name: v.name, category: v.cat }); },
}));
$('#oCats').addEventListener('click', (e) => {
  if (e.target.closest('[data-ocatnew]')) {
    return openODlg({ title: 'Nouvelle catégorie', fields: [{ id: 'name', label: 'Nom', placeholder: 'ex : Mariage' }], ok: 'Créer',
      onOk: (v) => { if (v.name) post('outfitCategory', { action: 'create', name: v.name }); } });
  }
  const b = e.target.closest('[data-ocat]'); if (b) { oCat = b.dataset.ocat; renderOutfits(); }
});
$('#oList').addEventListener('click', (e) => {
  const cur = O && O.categories.find((c) => c.id === oCat);
  if (e.target.closest('[data-ocatren]') && cur) {
    return openODlg({ title: 'Renommer la catégorie', fields: [{ id: 'name', label: 'Nom', value: cur.label }],
      onOk: (v) => { if (v.name) post('outfitCategory', { action: 'rename', id: cur.id, name: v.name }); } });
  }
  if (e.target.closest('[data-ocatdel]') && cur) {
    return openODlg({ title: 'Supprimer la catégorie ?', text: `« ${cur.label} » sera supprimée. Ses tenues sont gardées, sans catégorie.`, ok: 'Supprimer', danger: true,
      onOk: () => post('outfitCategory', { action: 'delete', id: cur.id }) });
  }
  const a = e.target.closest('[data-oact]'); if (!a) return;
  const o = O.outfits.find((x) => String(x.id) === a.closest('[data-oid]').dataset.oid); if (!o) return;
  const act = a.dataset.oact;
  if (act === 'wear') { a.disabled = true; post('outfitWear', { id: o.id }); }
  if (act === 'edit') {
    openODlg({ title: 'Modifier la tenue', fields: [{ id: 'name', label: 'Nom', value: o.name }, { id: 'cat', label: 'Catégorie', type: 'select', options: catOptions(o.category) }],
      onOk: (v) => { if (!v.name) return toast('Le nom ne peut pas être vide.', 'err'); post('outfitEdit', { id: o.id, name: v.name, category: v.cat }); } });
  }
  if (act === 'replace') {
    openODlg({ title: 'Remplacer la tenue ?', text: `« ${o.name} » prendra tous les vêtements et accessoires que tu portes maintenant.`, ok: 'Remplacer',
      onOk: () => post('outfitReplace', { id: o.id }) });
  }
  if (act === 'delete') {
    openODlg({ title: 'Supprimer la tenue ?', text: `« ${o.name} » sera supprimée. Les vêtements restent dans ton inventaire.`, ok: 'Supprimer', danger: true,
      onOk: () => post('outfitDelete', { id: o.id }) });
  }
});

/* ---------- Renommer ---------- */
function openRename(name) {
  $('#rename').classList.remove('hidden');
  const i = $('#rnInput'); i.value = name || ''; $('#rnCount').textContent = `${i.value.length} / 32`;
  setTimeout(() => { i.focus(); i.select(); }, 30);
}
function closeRename(ok) {
  $('#rename').classList.add('hidden');
  post('renameDone', ok ? { name: $('#rnInput').value.trim() } : { cancel: true });
}
$('#rnInput').addEventListener('input', (e) => { $('#rnCount').textContent = `${e.target.value.length} / 32`; });
$('#rnInput').addEventListener('keydown', (e) => { if (e.key === 'Enter') closeRename(true); if (e.key === 'Escape') closeRename(false); e.stopPropagation(); });
$('#rnOk').addEventListener('click', () => closeRename(true));
$('#rnCancel').addEventListener('click', () => closeRename(false));
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !$('#wardrobe').classList.contains('hidden') && $('#rename').classList.contains('hidden') && !oDlg) closeWardrobe();
});

/* ---------- Messages du jeu ---------- */
window.addEventListener('message', (e) => {
  const m = e.data || {};
  switch (m.action) {
    case 'open':
      S = { shop: m.shop, sex: m.sex, categories: m.categories, packs: m.packs || [], gta: m.gta !== false, money: m.money || {},
        payments: m.payments || ['cash', 'bank'], currency: m.currency || '$', itemsMode: !!m.itemsMode, manage: !!m.manage };
      IMG.setup(m.images);
      cart.clear(); wearNow = false; busy = false; hands = false; camView = 'full'; filter = 'all'; totals = null; method = S.payments[0];
      $('#shopName').textContent = S.shop.name;
      $('#app').classList.remove('hidden', 'closing');
      $('#modal').innerHTML = '';
      cat = S.categories[0];
      renderRail(); renderCart(); renderTools(); sendLayout(); chooseCat(cat.id);
      break;
    case 'hidden': {
      if (!S) break;
      for (const c of S.categories) { if (m.cats && m.cats[c.id]) { c.hidden = m.cats[c.id]; c._hid = null; } }
      totals = null;
      // un article caché ne reste pas dans le panier d'un joueur
      let removed = 0;
      for (const it of [...cart.values()]) {
        const c = catById(it.cat);
        if (c && !S.manage && isHidden(c, it.drawable)) {
          cart.delete(it.key); removed += 1;
          if (it.wear) { const rest = inCat(it.cat); if (rest.length) rest[rest.length - 1].wear = true; }
          showCat(it.cat);
        }
      }
      if (removed) toast(removed > 1 ? `${removed} articles de ton panier ne sont plus en vente.` : 'Un article de ton panier n\'est plus en vente.', 'err');
      if (filter === 'hidden' && !allCounts().sum.hidden) filter = 'all';
      renderFilters(); renderRail(); renderGrid(true); renderDetail(); renderCart();
      break;
    }
    case 'close': $('#app').classList.add('closing'); setTimeout(() => $('#app').classList.add('hidden'), 250); break;
    case 'error': busy = false; if (m.money) S.money = m.money; renderCart(); toast(m.text, 'err'); break;
    case 'paid':
      $('#modal').innerHTML = `<div class="done"><div><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M7 12.5l3 3 7-7"/></svg><b>Merci pour ton achat !</b><span>${esc(m.text)}</span></div></div>`;
      break;
    case 'wardrobe': {
      const opening = $('#wardrobe').classList.contains('hidden');
      W = m.data; $('#wardrobe').classList.remove('hidden'); renderWardrobe();
      if (opening && wTab === 'outfits') post('outfitsList');
      break;
    }
    case 'wardrobeClose': $('#wardrobe').classList.add('hidden'); W = null; if (oDlg) closeODlg(false); break;
    case 'outfits':
      if (m.data) { O = m.data; renderOutfits(); } else if (O) renderOutfits();   // réactive les boutons
      if (m.msg) toast(m.msg, m.kind === 'error' ? 'err' : 'ok');
      break;
    case 'rename': openRename(m.name); break;
    default: break;
  }
});

/* ---------- Aperçu hors jeu (navigateur) ---------- */
function mock(ev, d) {
  if (ev === 'try' || ev === 'textures') {
    const n = d.drawable < 0 ? 1 : 1 + ((d.drawable * 7 + 3) % 9);
    return { textures: n, texture: Math.min(d.texture || 0, n - 1) };
  }
  if (ev === 'setHidden') {
    const c = catById(d.cat), h = new Set(c.hidden || []);
    if (d.hide) h.add(d.drawable); else h.delete(d.drawable);
    setTimeout(() => window.postMessage({ action: 'hidden', cats: { [d.cat]: [...h] } }, '*'), 150);
  }
  if (ev === 'pay') setTimeout(() => window.postMessage({ action: 'paid', text: 'Achat réglé.' }, '*'), 600);
  if (ev.startsWith('outfit')) mockOutfits(ev, d);
  return {};
}
if (!IN_GAME) {
  const cats = [
    ['tops', 'Hauts', 'Haut', 'top', 'component', 520, 120, 'torso', 15, [[392, 451, 'maison_elyzea'], [452, 519, 'streetwear_la']]],
    ['pants', 'Pantalons', 'Pantalon', 'pants', 'component', 210, 90, 'legs', 21, [[172, 209, 'streetwear_la']]],
    ['shoes', 'Chaussures', 'Chaussures', 'shoe', 'component', 131, 80, 'feet', 34, []],
    ['hats', 'Chapeaux', 'Chapeau', 'hat', 'prop', 186, 60, 'head', -1, []],
  ].map(([id, lab, single, icon, type, count, base, camv, cur, ranges]) => ({ id, label: lab, single, icon, type, count, base, cam: camv,
    current: { drawable: cur, texture: 0 }, blacklist: [], ranges: ranges.map(([from, to, pack]) => ({ from, to, pack, sold: true })) }));
  window.postMessage({ action: 'open', shop: { name: 'Ponsonbys', multiplier: 100 }, sex: 'male', categories: cats, gta: true,
    packs: [{ id: 'maison_elyzea', label: 'Maison Elyzea', price: 250, folder: 'maison_elyzea' }, { id: 'streetwear_la', label: 'Streetwear LA', price: 100, folder: 'streetwear_la' }],
    money: { cash: 1840, bank: 26350 }, payments: ['cash', 'bank'], currency: '$', images: { enabled: false }, itemsMode: true, manage: /staff/.test(location.search) }, '*');
}

/* Aperçu hors jeu des tenues enregistrées : données fictives, gardées en mémoire */
function mockOutfits(ev, d) {
  const M = mockOutfits.db || (mockOutfits.db = { n: 3, cats: [{ id: 'quotidien', label: 'Quotidien', default: true }, { id: 'travail', label: 'Travail', default: true },
    { id: 'soiree', label: 'Soirée', default: true }, { id: 'sport', label: 'Sport', default: true }, { id: 'ceremonie', label: 'Cérémonie', default: true }],
    outfits: [{ id: 1, name: 'Tenue quotidienne', category: 'quotidien', sex: 'male', count: 7, missing: [], unavailable: [] },
      { id: 2, name: 'Costume du mariage', category: 'ceremonie', sex: 'male', count: 9, missing: ['hats'], unavailable: ['tops'] }] });
  let msg = null;
  if (ev === 'outfitSave') { M.outfits.push({ id: ++M.n, name: d.name, category: d.category, sex: 'male', count: 6, missing: [], unavailable: [] }); msg = `Tenue « ${d.name} » enregistrée.`; }
  if (ev === 'outfitEdit') { const o = M.outfits.find((x) => x.id === d.id); Object.assign(o, { name: d.name, category: d.category }); msg = 'Tenue modifiée.'; }
  if (ev === 'outfitDelete') { M.outfits = M.outfits.filter((x) => x.id !== d.id); msg = 'Tenue supprimée.'; }
  if (ev === 'outfitReplace') msg = 'Tenue remplacée par ta tenue actuelle.';
  if (ev === 'outfitWear') msg = 'Tenue portée.';
  if (ev === 'outfitCategory') {
    if (d.action === 'create') { M.cats.push({ id: `c${++M.n}`, label: d.name }); msg = `Catégorie « ${d.name} » créée.`; }
    if (d.action === 'rename') { M.cats.find((c) => c.id === d.id).label = d.name; msg = 'Catégorie renommée.'; }
    if (d.action === 'delete') { M.cats = M.cats.filter((c) => c.id !== d.id); M.outfits.forEach((o) => { if (o.category === d.id) o.category = ''; }); msg = 'Catégorie supprimée.'; }
  }
  M.outfits.sort((a, b) => a.name.localeCompare(b.name));
  const data = JSON.parse(JSON.stringify({ outfits: M.outfits, categories: M.cats, max: 40, maxCategories: 12, nameMax: 32, itemsMode: true }));
  setTimeout(() => window.postMessage({ action: 'outfits', data, msg, kind: 'success' }, '*'), 150);
}
