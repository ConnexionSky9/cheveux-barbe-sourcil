'use strict';
/* ELYZEA MANUTENTION · interface : suivi de mission, annonces, menu du responsable */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_manutention';
const $ = (s) => document.querySelector(s);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (n) => Math.round(Number(n) || 0).toLocaleString('fr-FR');
const post = (ep, data = {}) => fetch(`https://${RES}/${ep}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).catch(() => {});

/* ---------- suivi de mission ---------- */
function hud(d) {
  const el = $('#hud');
  if (!d || !d.show) { el.classList.add('hidden'); return; }
  el.classList.remove('hidden');
  $('#hud-step').textContent = `${d.stage}/3`;
  $('#hud-stage').textContent = d.stageTitle || '';
  document.querySelectorAll('.hud__steps i').forEach((i) => {
    const s = +i.dataset.s;
    i.className = s < d.stage ? 'done' : s === d.stage ? 'on' : '';
  });
  const full = d.boxes >= d.required;
  const b = $('#hud-boxes');
  b.textContent = `${d.boxes}/${d.required}`;
  b.classList.toggle('full', full);
  const bar = $('#hud-bar');
  bar.style.width = `${Math.min(100, (d.boxes / Math.max(1, d.required)) * 100)}%`;
  bar.classList.toggle('full', full);
  $('#hud-obj').textContent = d.objective || '—';
  const dest = $('#hud-dest');
  dest.classList.toggle('hidden', !d.destination);
  $('#hud-dest-txt').textContent = d.destination ? `${d.destination}${d.distance != null ? ` · ${fmt(d.distance)} m` : ''}` : '';
  $('#hud-tip').textContent = full && d.stage === 1 ? 'Monte sur ton Fenwick' : d.stage === 1 ? (d.carrying ? (d.sprint ? '[E] poser le carton' : '[E] poser · course impossible') : '[E] prendre un carton')
    : d.stage === 2 ? '[E] charger la palette' : '[E] livrer · [G] reposer';
  $('#hud-earn').textContent = d.delivered > 0 ? `${d.delivered} livrée(s) · ${fmt(d.earned)} $` : `${fmt(d.pay)} $ / palette`;
}

/* ---------- annonce ---------- */
let banTimer = null;
function banner(d) {
  const el = $('#banner');
  clearTimeout(banTimer);
  el.className = `banner ${d.kind || 'info'}`;
  $('#banner-title').textContent = d.title || '';
  $('#banner-text').textContent = d.text || '';
  banTimer = setTimeout(() => { el.classList.add('out'); setTimeout(() => el.classList.add('hidden'), 450); }, d.ms || 5500);
}

/* ---------- menu du responsable ---------- */
function menu(d) {
  const el = $('#menu');
  if (!d || !d.open) { el.classList.add('hidden'); return; }
  const pay = `${fmt(d.pay)} $`;
  const where = d.account === 'cash' ? 'en liquide' : 'sur ton compte';
  let body;
  if (d.working) {
    body = `<p>Tu travailles en ce moment. Tu gardes ton métier principal : l'intérim se fait en plus.</p>
      <div class="facts"><div><b>${fmt(d.delivered)}</b><span>palette(s) livrée(s)</span></div><div><b>${fmt(d.earned)} $</b><span>gagnés</span></div><div><b>${pay}</b><span>par palette</span></div></div>
      <p>Terminer le travail rend ta tenue, retire ton Fenwick et efface les objectifs.</p>
      <div class="actions">
        ${d.forklift ? `<button class="btn ghost" data-act="replace">🚜 ${d.hasForklift ? 'Remplacer mon Fenwick' : 'Demander un Fenwick'}</button>` : ''}
        <button class="btn danger" data-act="finish">Terminer le travail</button>
      </div>`;
  } else {
    body = `${d.enabled === false ? '<div class="closed">⛔ L\'agence ne recrute pas pour le moment.</div>' : ''}
      <p>Mission d'intérim à l'entrepôt, <b>en plus de ton métier principal</b> (tu ne le perds pas). On te fournit la tenue et un Fenwick.</p>
      <ul class="steps">
        <li><b>1</b>Récupère les cartons dans le stock (un à la fois${d.sprint ? '' : ', sans courir'})</li>
        <li><b>2</b>Empile-les sur ta palette : exactement ${fmt(d.boxes)} cartons</li>
        <li><b>3</b>Glisse les fourches du Fenwick sous la palette et soulève-la</li>
        <li><b>4</b>Dépose-la dans la zone de livraison : payé ${pay} ${where}</li>
      </ul>
      <div class="facts"><div><b>${fmt(d.boxes)}</b><span>cartons / palette</span></div><div><b>${pay}</b><span>par palette livrée</span></div><div><b>∞</b><span>livraisons</span></div></div>
      <div class="actions"><button class="btn ghost" data-close>Plus tard</button><button class="btn primary" data-act="accept" ${d.enabled === false ? 'disabled' : ''}>Accepter le travail</button></div>`;
  }
  $('#menu-body').innerHTML = body;
  el.classList.remove('hidden');
}

document.addEventListener('click', (e) => {
  const a = e.target.closest('[data-act]');
  if (a && !a.disabled) { post('menu', { action: a.dataset.act }); return; }
  if (e.target.closest('[data-close]')) post('close');
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('#menu').classList.contains('hidden')) post('close'); });

window.addEventListener('message', (ev) => {
  const m = ev.data || {};
  if (m.action === 'hud') hud(m.data);
  else if (m.action === 'banner') banner(m.data || {});
  else if (m.action === 'menu') menu(m.data);
});
window.__manut = { hud, banner, menu };
