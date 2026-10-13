/* =====================================================================
   JEWELRY HEIST - interface : menu autonome, contenu du sac, achat / revente, progression
   Le serveur calcule tous les montants : l'interface n'envoie que l'identifiant du bijou et la quantité.
   ===================================================================== */
const S = { panel: null, data: null, imagePath: '', tab: 'sell', qty: {}, busy: false };
const $ = (s) => document.querySelector(s);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'jewelry_heist';
async function post(name, body = {}) {
  try { const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }); return await r.json(); } catch (e) { return {}; }
}
const req = (action, data) => post('req', { action, data });
const notify = (text, kind) => post('notify', { text, kind });

// Icône : image de l'inventaire, sinon copie locale (html/img)
function icon(id) {
  const main = S.imagePath ? S.imagePath.replace('%s', id) : `img/${id}.png`;
  return `<img src="${esc(main)}" alt="" onerror="this.onerror=null;this.src='img/${esc(id)}.png'">`;
}
const ICO = { bag: '🎒', open: '👜', buy: '🛒', sell: '💰', rob: '🔫' };

function head(ico, title, sub) {
  return `<div class="head"><div class="ico">${ico}</div><div><h1>${esc(title)}</h1>${sub ? `<small>${esc(sub)}</small>` : ''}</div><button class="x" data-close>✕</button></div>`;
}

function renderMenu(d) {
  return head('💎', d.title, 'Choisissez une action') + `<div class="body">${d.options.map((o) => `<button class="opt ${o.id === 'rob' ? 'danger' : ''}" data-opt="${esc(o.id)}" ${o.disabled ? 'disabled' : ''}>
      <span class="oi">${ICO[o.icon] || '•'}</span><span>${esc(o.label)}${o.desc ? `<small>${esc(o.desc)}</small>` : ''}</span></button>`).join('')}</div>`;
}

function renderBag(b) {
  const rows = (b.money > 0 ? `<div class="money"><div class="pic">💵</div><div><b>${money(b.money)}</b><div class="meta">${esc(b.moneyLabel || '')}</div></div>
      <div class="act"><button class="btn" data-take="money">Prendre</button></div></div>` : '')
    + b.items.map((it) => `<div class="gem"><div class="pic">${icon(it.id)}</div><div><b>${esc(it.label)}</b><div class="meta">Quantité : <span class="p">${it.count}</span></div></div>
      <div class="act"><button class="btn" data-take="${esc(it.id)}">Prendre</button></div></div>`).join('');
  const empty = b.money <= 0 && !b.items.length;
  return head('🎒', 'Sac de butin', b.owner ? `Braquage de ${b.owner}` : 'Contenu du sac') + `<div class="body">${empty ? '<div class="empty">Le sac est vide.</div>' : rows}
    <div class="foot">${b.canSeize ? '<button class="btn red" data-seize>Saisir le contenu (police)</button>' : ''}<button class="btn gold" data-take="all" ${empty ? 'disabled' : ''}>Tout prendre</button></div>
    <p class="note">Ce qui ne rentre pas dans votre inventaire reste dans le sac.</p></div>`;
}

function renderTrade(d) {
  const canBuy = d.buy && d.kind === 'shop', canSell = d.sell;
  if (!canBuy) S.tab = 'sell';
  if (!canSell) S.tab = 'buy';
  const tabs = canBuy && canSell ? `<div class="tabs"><button class="tab ${S.tab === 'buy' ? 'on' : ''}" data-tab="buy">Acheter</button><button class="tab ${S.tab === 'sell' ? 'on' : ''}" data-tab="sell">Vendre</button></div>` : '';
  const rows = d.list.map((it) => {
    const unit = S.tab === 'buy' ? it.buy : it.sell;
    const max = S.tab === 'buy' ? d.maxPerTx : Math.min(d.maxPerTx, it.owned);
    const q = Math.max(1, Math.min(S.qty[it.id] || 1, Math.max(1, max)));
    const dis = max < 1;
    return `<div class="gem"><div class="pic">${icon(it.id)}</div>
      <div><b>${esc(it.label)}</b><div class="meta">Prix unitaire : <span class="p">${money(unit)}</span> · Possédé : ${it.owned}</div></div>
      <div><div class="act"><div class="qty"><button data-q="${esc(it.id)}" data-d="-1">−</button><input type="number" min="1" max="${Math.max(1, max)}" value="${q}" data-qi="${esc(it.id)}"><button data-q="${esc(it.id)}" data-d="1">+</button></div>
        <button class="btn gold" data-trade="${esc(it.id)}" ${dis ? 'disabled' : ''}>${S.tab === 'buy' ? 'Acheter' : 'Vendre'}</button></div>
        <div class="total" data-total="${esc(it.id)}">Total : ${money(unit * q)}</div></div></div>`;
  }).join('');
  return head(d.kind === 'buyer' ? '🕶️' : '💍', d.name, `Paiement : ${d.payment || ''} · ${d.maxPerTx} max. par transaction`) + `<div class="body">${tabs}${rows || '<div class="empty">Aucun bijou ici.</div>'}</div>`;
}

function draw() {
  const p = $('#panel');
  if (!S.panel) { p.classList.add('hidden'); return; }
  p.classList.remove('hidden');
  p.classList.toggle('small', S.panel === 'menu');
  if (S.panel === 'menu') p.innerHTML = renderMenu(S.data);
  else if (S.panel === 'bag') p.innerHTML = renderBag(S.data);
  else if (S.panel === 'trade') p.innerHTML = renderTrade(S.data);
}

function close() {
  const bag = S.panel === 'bag' && S.data ? S.data.id : null;
  S.panel = null; S.data = null; draw();
  post('close', { bag });
}

async function refreshTrade() {
  const d = S.data;
  const r = d.kind === 'buyer' ? await req('buyerData', { buyer: d.id }) : await req('shopData', { shop: d.id });
  if (r.error) { notify(r.error, 'error'); return close(); }
  r.mode = d.mode; S.data = r; draw();
}

document.addEventListener('click', async (e) => {
  let n;
  if (e.target.closest('[data-close]')) return close();
  if ((n = e.target.closest('[data-opt]')) && !n.disabled) { const id = n.dataset.opt; S.panel = null; draw(); return post('menuSelect', { id }); }
  if ((n = e.target.closest('[data-tab]'))) { S.tab = n.dataset.tab; return draw(); }
  if ((n = e.target.closest('[data-q]'))) {
    const id = n.dataset.q; const inp = document.querySelector(`[data-qi="${id}"]`);
    S.qty[id] = Math.max(1, Math.min(Number(inp.max) || 1, (Number(inp.value) || 1) + Number(n.dataset.d)));
    return draw();
  }
  if (S.busy) return;
  if ((n = e.target.closest('[data-trade]')) && !n.disabled) {
    const id = n.dataset.trade; const d = S.data; const qty = S.qty[id] || 1;
    S.busy = true; n.disabled = true;
    const action = d.kind === 'buyer' ? 'buyerSell' : (S.tab === 'buy' ? 'shopBuy' : 'shopSell');
    const r = await req(action, d.kind === 'buyer' ? { buyer: d.id, gem: id, qty } : { shop: d.id, gem: id, qty });
    S.busy = false;
    if (r.error) notify(r.error, 'error');
    S.qty[id] = 1;
    return refreshTrade();
  }
  if ((n = e.target.closest('[data-take]')) && !n.disabled) {
    S.busy = true; n.disabled = true;
    const r = await req('bagTake', { bag: S.data.id, what: n.dataset.take });
    S.busy = false;
    if (r.error) { notify(r.error, 'error'); return close(); }
    if (r.empty) { S.panel = null; draw(); return post('close', {}); }
    S.data = r.bag; return draw();
  }
  if ((n = e.target.closest('[data-seize]'))) {
    S.busy = true;
    const r = await req('bagSeize', { bag: S.data.id });
    S.busy = false;
    if (r.error) notify(r.error, 'error');
    S.panel = null; draw(); return post('close', {});
  }
});
document.addEventListener('input', (e) => {
  const t = e.target;
  if (t.dataset.qi === undefined) return;
  const id = t.dataset.qi;
  S.qty[id] = Math.max(1, Math.min(Number(t.max) || 1, Math.floor(Number(t.value) || 1)));
  const it = S.data.list.find((x) => x.id === id);
  const unit = S.tab === 'buy' ? it.buy : it.sell;
  const tot = document.querySelector(`[data-total="${id}"]`);
  if (tot) tot.textContent = `Total : ${money(unit * S.qty[id])}`;
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && S.panel) close(); });

// Barre de progression (durée envoyée par le serveur)
let prog = null;
function progress(m) {
  const el = $('#progress');
  if (prog) { cancelAnimationFrame(prog.raf); prog = null; }
  if (!m.show) { el.classList.add('hidden'); return; }
  el.classList.remove('hidden');
  el.querySelector('.lbl').textContent = m.label;
  const bar = el.querySelector('.bar i'); bar.style.background = m.color || '';
  const total = Math.max(0.1, Number(m.seconds) || 0) * 1000; const start = performance.now();
  const tick = (t) => {
    const k = Math.min(1, (t - start) / total);
    bar.style.width = `${k * 100}%`;
    el.querySelector('.time').textContent = `${Math.max(0, Math.ceil((total - (t - start)) / 1000))} s`;
    if (k < 1) prog.raf = requestAnimationFrame(tick);
  };
  prog = { raf: requestAnimationFrame(tick) };
}

window.addEventListener('message', (ev) => {
  const m = ev.data || {};
  if (m.action === 'open') {
    S.panel = m.panel; S.data = m.data; S.imagePath = m.imagePath || S.imagePath; S.qty = {};
    if (m.panel === 'trade') S.tab = m.data.mode || 'sell';
    draw();
  } else if (m.action === 'close') { S.panel = null; S.data = null; draw(); }
  else if (m.action === 'progress') progress(m);
});
