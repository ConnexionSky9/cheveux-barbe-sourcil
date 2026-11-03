/* =====================================================================
   ELYZEA PIER · interface (billetterie, panneau d'attente / de trajet, notifications)
   Hors FiveM : index.html?demo=menu | tickets | hud-queue | hud-wheel | hud-coaster
   ===================================================================== */
'use strict';
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'elyzea_pier';
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
const S = { info: null, tab: 'wheel', qty: { wheel: 1, coaster: 1 }, busy: false };

async function post(name, data) {
  if (!IN_GAME) return Demo.post(name, data);
  try {
    const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}) });
    return await r.json();
  } catch (e) { return null; }
}

function toast(text, kind = 'info') {
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.innerHTML = `<i></i><span>${esc(text)}</span>`;
  $('#toasts').appendChild(el);
  setTimeout(() => el.remove(), 5200);
}

const DESC = {
  wheel: 'La grande roue originale du ponton de Del Perro : 16 cabines, 2 passagers par cabine, un tour complet au-dessus de l\'océan avec vue sur Vespucci et le centre-ville.',
  coaster: 'Les montagnes russes originales du ponton : 4 wagons, 8 passagers, montée à la chaîne, descentes à plus de 60 km/h et virages au-dessus de l\'eau.',
};

// Illustrations vectorielles légères (roue / rail)
const ART = {
  wheel: `<svg viewBox="0 0 300 270"><defs><radialGradient id="g1" cx=".5" cy=".4" r=".7"><stop offset="0" stop-color="#3b1f7a"/><stop offset="1" stop-color="#0a0518"/></radialGradient></defs>
    <rect width="300" height="270" fill="url(#g1)"/><g class="spin">${Array.from({ length: 16 }, (_, i) => { const a = i * Math.PI / 8; const x = 150 + 92 * Math.sin(a), y = 120 - 92 * Math.cos(a);
      return `<line x1="150" y1="120" x2="${x.toFixed(1)}" y2="${y.toFixed(1)}" stroke="#5FD3FF" stroke-opacity=".55" stroke-width="2"/><circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="7" fill="#FFC94A"/>`; }).join('')}
    <circle cx="150" cy="120" r="92" fill="none" stroke="#5FD3FF" stroke-width="4"/><circle cx="150" cy="120" r="14" fill="#B57BFF"/></g>
    <path d="M150 120 L95 262 M150 120 L205 262" stroke="#9fb3ff" stroke-width="6"/><rect y="250" width="300" height="20" fill="#2a1a10"/></svg>`,
  coaster: `<svg viewBox="0 0 300 270"><defs><linearGradient id="g2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a0f3d"/><stop offset="1" stop-color="#0a0518"/></linearGradient></defs>
    <rect width="300" height="270" fill="url(#g2)"/><path d="M10 230 C60 230 70 60 120 60 C170 60 160 200 200 200 C240 200 250 110 290 110" fill="none" stroke="#FF4D8D" stroke-width="5"/>
    ${[30, 70, 110, 150, 190, 230, 270].map((x) => `<line x1="${x}" y1="250" x2="${x}" y2="${x < 140 ? 140 - Math.abs(x - 120) * 0.6 : 200 - Math.abs(x - 200) * 0.6}" stroke="#b07bd1" stroke-opacity=".5" stroke-width="3"/>`).join('')}
    <g transform="translate(108 40) rotate(-8)"><rect width="34" height="16" rx="4" fill="#FFC94A"/><circle cx="8" cy="18" r="4" fill="#fff"/><circle cx="26" cy="18" r="4" fill="#fff"/></g>
    <rect y="250" width="300" height="20" fill="#2a1a10"/></svg>`,
};

function render() {
  const I = S.info;
  if (!I) return;
  const tabs = [['wheel', 1, 'Ticket grande roue'], ['coaster', 2, 'Ticket montagnes russes'], ['mine', 3, 'Mes tickets']];
  let body;
  if (S.tab === 'mine') {
    body = `<div class="mine">${['wheel', 'coaster'].map((k) => { const r = I.rides[k]; return `<div class="ticket ${k}"><div class="big">${r.owned}</div>
      <div><div class="nm">${esc(r.label.toUpperCase())}</div><div class="sm">Ticket valable une fois · ${fmt(r.price)} $</div><div class="sm">${r.owned ? 'Prêt à être utilisé à l\'entrée de l\'attraction.' : 'Aucun ticket.'}</div></div>
      <div class="stub">DEL PERRO PIER</div></div>`; }).join('')}
      <div class="hint">Tes tickets sont dans ton inventaire et sont conservés à la déconnexion. Un ticket n'est utilisé qu'au moment où tu montes réellement dans l'attraction
        (présente-toi à l'entrée et appuie sur <b>E</b>). Chaque ticket ne vaut que pour son attraction.</div></div>`;
  } else {
    const k = S.tab;
    const r = I.rides[k];
    const q = S.qty[k];
    const total = q * r.price;
    body = `<div class="ride ${k}"><div class="art">${ART[k]}</div><div>
      <h2>${esc(r.label)}</h2><div class="desc">${DESC[k]}</div>
      <div class="stats"><div class="stat price"><div class="v">${fmt(r.price)} $</div><div class="l">Prix du ticket</div></div>
        <div class="stat"><div class="v">${r.owned}</div><div class="l">Tickets possédés</div></div>
        <div class="stat"><div class="v">${r.free} / ${r.capacity}</div><div class="l">Places libres</div></div>
        <div class="stat"><div class="v">${r.queue ? `≈ ${r.wait} s` : 'aucune'}</div><div class="l">Attente${r.queue ? ` · ${r.queue} en file` : ''}</div></div></div>
      ${r.enabled ? `<div class="buy"><div class="qty"><button data-q="-1">−</button><span>${q}</span><button data-q="1">+</button></div>
        ${I.accounts.cash ? `<button class="pay" data-pay="cash" ${S.busy ? 'disabled' : ''}>Payer en liquide</button>` : ''}
        ${I.accounts.bank ? `<button class="pay bank" data-pay="bank" ${S.busy ? 'disabled' : ''}>Payer par carte</button>` : ''}
        <div class="total"><div class="l">TOTAL</div><div class="v">${fmt(total)} $</div></div></div>` : `<div class="desc"><b>Attraction fermée pour le moment.</b></div>`}
      <div class="wallet">Liquide : ${fmt(I.money.cash)} $ · Banque : ${fmt(I.money.bank)} $ · État : ${esc(r.status || '')}</div></div></div>`;
  }
  $('#menu').innerHTML = `<div class="booth"><div class="lights">${'<i></i>'.repeat(24)}</div>
    <div class="head"><div><div class="t">Bienvenue au parc d'attractions de <b>Del Perro</b> !</div><div class="s">Billetterie du ponton · Grande roue et montagnes russes</div></div>
    <button class="x" data-act="close">✕</button></div>
    <div class="tabs">${tabs.map(([id, n, l]) => `<button class="${S.tab === id ? 'on' : ''}" data-tab="${id}"><span class="n">${n}</span>${l}</button>`).join('')}</div>
    <div class="body">${body}</div></div>`;
}

document.addEventListener('click', async (e) => {
  const t = e.target.closest('[data-tab],[data-q],[data-pay],[data-act]');
  if (!t) return;
  if (t.dataset.tab) { S.tab = t.dataset.tab; return render(); }
  if (t.dataset.q) { const k = S.tab; S.qty[k] = Math.max(1, Math.min(S.info.max || 10, S.qty[k] + Number(t.dataset.q))); return render(); }
  if (t.dataset.act === 'close') return close();
  if (t.dataset.pay && !S.busy) {
    S.busy = true; render();
    const r = await post('buy', { kind: S.tab, qty: S.qty[S.tab], account: t.dataset.pay });
    S.busy = false;
    if (r && r.ok) { toast(r.msg, 'success'); if (r.info) S.info = r.info; S.qty[S.tab] = 1; }
    else toast((r && r.msg) || 'Achat impossible.', 'error');
    render();
  }
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('#menu').classList.contains('hidden')) close(); });

function close() { $('#menu').classList.add('hidden'); post('close'); }

function hud(d) {
  const h = $('#hud');
  if (!d) { h.classList.add('hidden'); return; }
  h.className = d.ride;
  let rows = '';
  if (d.status === 'queue') {
    rows = `<div class="row"><span>Statut</span><b>File d'attente</b></div>${d.position ? `<div class="row"><span>Position</span><b>${d.position}</b></div>` : ''}
      <div class="row"><span>Attente estimée</span><b>${d.wait != null ? `≈ ${d.wait} s` : '…'}</b></div>${d.capacity ? `<div class="row"><span>Places libres</span><b>${d.free} / ${d.capacity}</b></div>` : ''}
      <div class="tip">Reste près de l'entrée. [E] pour quitter la file (ticket conservé).</div>`;
  } else if (d.status === 'boarding') {
    rows = `<div class="row"><span>Statut</span><b>Embarquement</b></div>${d.cabin ? `<div class="row"><span>Cabine</span><b>n°${d.cabin}</b></div>` : ''}${d.car ? `<div class="row"><span>Wagon</span><b>n°${d.car}</b></div>` : ''}
      ${d.departIn != null ? `<div class="row"><span>Départ dans</span><b>${d.departIn} s</b></div><div class="tip">[E] pour descendre avant le départ (ticket rendu).</div>` : ''}`;
  } else {
    rows = `<div class="row"><span>Statut</span><b>${d.ride === 'wheel' ? 'Tour en cours' : 'Trajet en cours'}</b></div>${d.cabin ? `<div class="row"><span>Cabine</span><b>n°${d.cabin}</b></div>` : ''}
      <div class="bar"><i style="width:${Math.round((d.progress || 0) * 100)}%"></i></div>${d.ride === 'coaster' ? '<div class="tip">[X] lever / baisser les bras</div>' : '<div class="tip">Profite de la vue : tu redescends automatiquement en gare.</div>'}`;
  }
  h.innerHTML = `<div class="k">PARC DE DEL PERRO</div><div class="n">${esc(d.label)}</div>${rows}`;
}

window.addEventListener('message', (e) => {
  const { action, data } = e.data || {};
  if (action === 'open') { S.info = data; S.tab = 'wheel'; $('#menu').classList.remove('hidden'); render(); }
  else if (action === 'close') $('#menu').classList.add('hidden');
  else if (action === 'toast') toast(data.text, data.kind);
  else if (action === 'hud') hud(data);
});

/* ---------------------------------------------------------------- démo (navigateur) */
const Demo = {
  info: { accounts: { cash: true, bank: true }, max: 10, money: { cash: 2350, bank: 48200 },
    rides: { wheel: { kind: 'wheel', label: 'Grande roue', price: 150, owned: 2, enabled: true, capacity: 32, free: 27, queue: 3, wait: 24, status: 'en rotation' },
      coaster: { kind: 'coaster', label: 'Montagnes russes', price: 250, owned: 0, enabled: true, capacity: 8, free: 5, queue: 0, wait: 12, status: 'embarquement' } } },
  post(name, data) {
    if (name === 'buy') { const r = Demo.info.rides[data.kind]; r.owned += data.qty; return Promise.resolve({ ok: true, msg: `${data.qty} ticket(s) ${r.label} acheté(s) pour ${data.qty * r.price} $.`, info: Demo.info }); }
    return Promise.resolve({ ok: true });
  },
};
(function () {
  if (IN_GAME) return;
  document.body.classList.add('demo');
  const q = new URLSearchParams(location.search).get('demo') || 'menu';
  const send = (action, data) => window.postMessage({ action, data }, '*');
  setTimeout(() => {
    if (q === 'menu' || q === 'tickets' || q === 'coaster') { send('open', Demo.info); if (q !== 'menu') setTimeout(() => document.querySelector(`[data-tab="${q === 'tickets' ? 'mine' : 'coaster'}"]`).click(), 50); }
    if (q === 'hud-queue') send('hud', { ride: 'wheel', label: 'Grande roue', status: 'queue', position: 3, wait: 24, free: 27, capacity: 32 });
    if (q === 'hud-wheel') send('hud', { ride: 'wheel', label: 'Grande roue', status: 'riding', cabin: 7, progress: 0.42 });
    if (q === 'hud-coaster') { send('hud', { ride: 'coaster', label: 'Montagnes russes', status: 'boarding', car: 2, departIn: 14 }); send('toast', { text: 'Embarquement : wagon 2, place 1. Départ dans 14 s.', kind: 'success' }); }
  }, 50);
})();
