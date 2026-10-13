/* =====================================================================
   BANK HEIST - interface : menu autonome, marchand, ordinateur de piratage, sac
   Les prix, montants et résultats viennent du serveur ; l'interface n'envoie que des choix.
   ===================================================================== */
const S = { panel: null, data: null, imagePath: '', busy: false, hack: null };
const $ = (s) => document.querySelector(s);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'bank_heist';
async function post(name, body = {}) {
  try { const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }); return await r.json(); } catch (e) { return {}; }
}
const req = (action, data) => post('req', { action, data });
const notify = (text, kind) => post('notify', { text, kind });
const ICO = { buy: '🛒', rob: '🔫', hack: '💻', c4: '🧨', cash: '💵', bag: '🎒' };
function icon(name) {
  const main = S.imagePath ? S.imagePath.replace('%s', name) : `img/${name}.png`;
  return `<img src="${esc(main)}" alt="" onerror="this.onerror=null;this.src='img/${esc(name)}.png'">`;
}
const head = (ico, title, sub) => `<div class="head"><div class="ico">${ico}</div><div><h1>${esc(title)}</h1>${sub ? `<small>${esc(sub)}</small>` : ''}</div><button class="x" data-close>✕</button></div>`;

function drawPanel() {
  const p = $('#panel');
  if (!S.panel || S.panel === 'hack') { p.classList.add('hidden'); return; }
  p.classList.remove('hidden');
  p.classList.toggle('small', S.panel === 'menu');
  const d = S.data;
  if (S.panel === 'menu') {
    p.innerHTML = head('🏦', d.title, 'Choisissez une action') + `<div class="body">${d.options.map((o) => `<button class="opt" data-opt="${esc(o.id)}" ${o.disabled ? 'disabled' : ''}>
      <span class="oi">${ICO[o.icon] || '•'}</span><span>${esc(o.label)}${o.desc ? `<small>${esc(o.desc)}</small>` : ''}</span></button>`).join('')}</div>`;
  } else if (S.panel === 'shop') {
    p.innerHTML = head('🧰', d.name, `Paiement : ${d.payment}`) + `<div class="body">${d.list.map((it) => `<div class="item"><div class="pic">${icon(it.item)}</div>
      <div><b>${esc(it.label)}</b><p>${esc(it.description)}</p><div class="price">${money(it.price)}</div><p>Possédé : ${it.owned}${it.max ? ` / ${it.max} max.` : ''}</p></div>
      <button class="btn go" data-buy="${esc(it.id)}" ${it.max && it.owned >= it.max ? 'disabled' : ''}>Acheter</button></div>`).join('') || '<p class="note">Rien à vendre.</p>'}
      <p class="note">Le paiement et l'objet sont vérifiés par le serveur.</p></div>`;
  }
}

function close(extra = {}) {
  if (S.hack && S.hack.el && S.hack.el._cleanup) S.hack.el._cleanup();
  if (S.hack && S.hack.timer) clearInterval(S.hack.timer);
  S.panel = null; S.data = null; S.hack = null;
  $('#hack').classList.add('hidden'); $('#hack').innerHTML = '';
  drawPanel();
  post('close', extra);
}

// ---------------------------------------------------------------------
// Ordinateur de piratage
// ---------------------------------------------------------------------
function openHack(d) {
  const box = $('#hack');
  box.classList.remove('hidden');
  const tries = Array.from({ length: d.attemptsMax }, (_, i) => `<i class="${i < d.attemptsLeft ? 'on' : ''}"></i>`).join('');
  box.innerHTML = `<div class="screen"><div class="bar"><span class="t">VAULT_SEC // ${esc(d.label.toUpperCase())}</span><span>Niveau ${d.difficulty}</span>
      <span class="tries">Tentatives restantes après celle-ci : ${tries} <b>${d.attemptsLeft}/${d.attemptsMax}</b></span><button class="x" data-close>QUITTER</button></div>
    <div class="timer"><i></i></div><div class="game"></div></div>`;
  const el = box.querySelector('.game');
  const end = performance.now() + d.time * 1000;
  const bar = box.querySelector('.timer i');
  S.hack = { el, done: false };
  S.hack.timer = setInterval(() => {
    const left = Math.max(0, end - performance.now());
    bar.style.width = `${(left / (d.time * 1000)) * 100}%`;
    bar.classList.toggle('low', left < 6000);
    if (left <= 0 && S.hack && !S.hack.done) { req('hackAbort'); result(false, 'TEMPS ÉCOULÉ'); }
  }, 100);
  const api = {
    submit: async (answer) => {
      if (!S.hack || S.hack.done) return;
      const r = await req('hackSubmit', { answer });
      if (r.error) { notify(r.error, 'error'); return; }
      result(r.success === true);
    },
    guess: async (digits) => {
      const r = await req('hackGuess', { guess: digits });
      if (r.error) { notify(r.error, 'error'); return r; }
      if (r.done) setTimeout(() => result(r.success === true), 500);
      return r;
    },
  };
  Games[d.game](el, d.data, api);
}

function result(ok, text) {
  if (!S.hack || S.hack.done) return;
  S.hack.done = true;
  if (S.hack.el._cleanup) S.hack.el._cleanup();
  clearInterval(S.hack.timer);
  S.hack.el.innerHTML = `<div class="result ${ok ? 'ok' : 'ko'}">${ok ? 'ACCÈS AUTORISÉ' : (text || 'ACCÈS REFUSÉ')}</div>
    <p class="rule">${ok ? 'Le coffre s\'ouvre.' : 'Tentative perdue.'}</p>`;
  setTimeout(() => close({ done: true }), 1800);
}

// ---------------------------------------------------------------------
// Événements
// ---------------------------------------------------------------------
document.addEventListener('click', async (e) => {
  let n;
  if (e.target.closest('[data-close]')) return close({ done: !!(S.hack && S.hack.done) });
  if ((n = e.target.closest('[data-opt]')) && !n.disabled) { const id = n.dataset.opt; S.panel = null; drawPanel(); return post('menuSelect', { id }); }
  if ((n = e.target.closest('[data-buy]')) && !n.disabled && !S.busy) {
    S.busy = true; n.disabled = true;
    const r = await req('shopBuy', { merchant: S.data.id, item: n.dataset.buy });
    if (r.error) notify(r.error, 'error');
    const d = await req('shopData', { merchant: S.data.id });
    S.busy = false;
    if (d.error) return close();
    S.data = d; drawPanel();
  }
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && S.panel) close({ done: !!(S.hack && S.hack.done) }); });

function bagHud(m) {
  const el = $('#bag');
  if (!m.show) { el.classList.add('hidden'); return; }
  el.classList.remove('hidden');
  const pct = m.capacity ? Math.min(100, (m.money / m.capacity) * 100) : 0;
  $('#bagMoney').textContent = money(m.money);
  $('#bagCap').textContent = `/ ${money(m.capacity)}`;
  $('#bagPct').textContent = `${pct.toLocaleString('fr-FR', { maximumFractionDigits: 1 })} %`;
  $('#bagBar').style.width = `${pct}%`;
}

window.addEventListener('message', (ev) => {
  const m = ev.data || {};
  if (m.action === 'open') {
    S.imagePath = m.imagePath || S.imagePath;
    S.panel = m.panel; S.data = m.data;
    if (m.panel === 'hack') { drawPanel(); openHack(m.data); } else drawPanel();
  } else if (m.action === 'close') {
    if (S.hack && S.hack.timer) clearInterval(S.hack.timer);
    if (S.hack && S.hack.el && S.hack.el._cleanup) S.hack.el._cleanup();
    S.panel = null; S.hack = null; $('#hack').classList.add('hidden'); $('#hack').innerHTML = ''; drawPanel();
  } else if (m.action === 'bag') bagHud(m);
});
