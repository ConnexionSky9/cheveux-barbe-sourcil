/* =====================================================================
   BANK HEIST - interface : guichet bancaire, indic, marchand, menu autonome,
   ordinateur de piratage, boîtier d'alarme (fils), perceuse, HUD du butin, bandeaux, sons.
   Montants, prix, énigmes et résultats viennent du serveur ; l'interface n'envoie que des choix.
   ===================================================================== */
const S = { panel: null, data: null, imagePath: '', busy: false, hack: null, tab: 'home', game: null };
const $ = (s, r = document) => r.querySelector(s);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'bank_heist';
async function post(name, body = {}) {
  if (window.MOCK) return window.MOCK(name, body);
  try { const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }); return await r.json(); } catch (e) { return {}; }
}
const req = (action, data) => post('req', { action, data });
const notify = (text, kind) => post('notify', { text, kind });
const ICO = { buy: '🛒', rob: '🔫', hack: '💻', c4: '🧨', cash: '💵', bag: '🎒', talk: '💬', bank: '🏦', alarm: '🚨', drill: '🛠️' };
const mark = (size, anim = true) => (window.Ely ? Ely.mark({ size, anim, live: true }) : '');
function icon(name) {
  const main = S.imagePath ? S.imagePath.replace('%s', name) : `img/${name}.png`;
  return `<img src="${esc(main)}" alt="" onerror="this.onerror=null;this.src='img/${esc(name)}.png'">`;
}
const head = (title, sub) => `<div class="head"><div class="mk">${mark(46)}</div><div><h1>${esc(title)}</h1>${sub ? `<small>${esc(sub)}</small>` : ''}</div><button class="x" data-close>✕</button></div>`;

// Compteur animé (sans à-coups : requestAnimationFrame, s'arrête tout seul)
function countTo(el, to, ms = 700) {
  if (!el) return;
  const from = Number(el.dataset.v || 0); to = Number(to) || 0;
  el.dataset.v = to;
  if (from === to) { el.textContent = money(to); return; }
  const t0 = performance.now();
  const step = (t) => {
    const k = Math.min(1, (t - t0) / ms), e = 1 - Math.pow(1 - k, 3);
    el.textContent = money(from + (to - from) * e);
    if (k < 1 && el.dataset.v == to) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
function toast(text, err) {
  const host = $('#panel'); if (!host || !text) return;
  host.querySelectorAll('.toast').forEach((t) => t.remove());
  host.insertAdjacentHTML('beforeend', `<div class="toast ${err ? 'err' : ''}">${esc(text)}</div>`);
  setTimeout(() => host.querySelectorAll('.toast').forEach((t) => t.remove()), 2700);
}

// ---------------------------------------------------------------------
// Panneaux
// ---------------------------------------------------------------------
function drawPanel() {
  const p = $('#panel');
  if (!S.panel || ['hack', 'wires', 'drill'].includes(S.panel)) { p.classList.add('hidden'); p.innerHTML = ''; return; }
  p.classList.remove('hidden', 'out');
  p.className = S.panel === 'menu' ? 'small' : (S.panel === 'bank' ? 'wide' : '');
  const d = S.data || {};
  if (S.panel === 'menu') {
    p.innerHTML = head(d.title, 'Choisissez une action') + `<div class="body stagger">${(d.options || []).map((o) => `<button class="opt ${o.icon === 'rob' && !o.disabled ? 'rob' : ''}" data-opt="${esc(o.id)}" ${o.disabled ? 'disabled' : ''}>
      <span class="oi">${ICO[o.icon] || '•'}</span><span>${esc(o.label)}${o.desc ? `<small>${esc(o.desc)}</small>` : ''}</span></button>`).join('')}</div>`;
  } else if (S.panel === 'shop') {
    p.innerHTML = head(d.name, `Matériel de braqueur · paiement : ${d.payment}`) + `<div class="body stagger">${(d.list || []).map((it) => `<div class="item"><div class="pic">${icon(it.item)}</div>
      <div><b>${esc(it.label)}</b><p>${esc(it.description)}</p><div class="price">${money(it.price)}</div><div class="own">Possédé : ${it.owned}${it.max ? ` / ${it.max} max.` : ''}</div></div>
      <button class="btn" data-buy="${esc(it.id)}" ${it.max && it.owned >= it.max ? 'disabled' : ''}>Acheter</button></div>`).join('') || '<p class="note">Rien à vendre.</p>'}
      <p class="note">Le paiement et l'objet sont vérifiés par le serveur.</p></div>`;
  } else if (S.panel === 'talk') drawTalk(p, d);
  else if (S.panel === 'bank') drawBank(p, d);
}

function close(extra = {}) {
  stopGame();
  const was = S.panel;
  S.panel = null; S.data = null;
  const p = $('#panel');
  if (!p.classList.contains('hidden') && ['menu', 'shop', 'talk', 'bank'].includes(was)) {
    p.classList.add('out');
    setTimeout(() => { if (!S.panel) { p.classList.add('hidden'); p.innerHTML = ''; } }, 220);
  } else drawPanel();
  $('#hack').classList.add('hidden'); $('#hack').innerHTML = '';
  post('close', extra);
}
function stopGame() {
  const g = S.hack || S.game;
  if (g) { if (g.el && g.el._cleanup) g.el._cleanup(); if (g.timer) clearInterval(g.timer); if (g.stop) g.stop(); }
  S.hack = null; S.game = null;
}

// ---------------------------------------------------------------------
// Indic : dialogue (texte tapé), paiement, position du vendeur sur le GPS
// ---------------------------------------------------------------------
let typing = null;
function type(el, text, done) {
  if (typing) cancelAnimationFrame(typing);
  const chars = [...String(text || '')]; let i = 0, last = 0;
  el.innerHTML = '<span></span><i class="caret"></i>';
  const span = el.firstChild;
  const step = (t) => {
    if (t - last > 22) { last = t; i += 1; span.textContent = chars.slice(0, i).join(''); if (i % 3 === 0) Sfx.play('click', 0.25); }
    if (i < chars.length) typing = requestAnimationFrame(step); else { typing = null; if (done) done(); }
  };
  typing = requestAnimationFrame(step);
}
function drawTalk(p, d) {
  const initials = String(d.name || '?').replace(/[«»"']/g, '').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
  const canPay = !d.waitMin && d.hasMerchant !== false;
  p.innerHTML = `<div class="talk"><button class="x" data-close style="position:absolute;right:16px;top:16px">✕</button>
    <div class="portrait"><span>${esc(initials)}</span></div>
    <div><div class="who">${esc(d.name)}</div><span class="tag">Indicateur</span><div class="bubble" id="bub"></div></div>
    <div class="acts" id="acts">
      <button class="btn ghost" data-close>Partir</button>
      <button class="btn" id="pay" ${canPay ? '' : 'disabled'}>Payer ${money(d.price)} · ${esc(d.payment)}</button>
    </div></div>`;
  const msg = d.waitMin ? `« Je t'ai déjà tout dit. Reviens dans ${d.waitMin} min. »` : (d.hasMerchant === false ? '« Y\'a plus personne qui vend, en ce moment. »' : d.greeting);
  type($('#bub'), msg);
  $('#pay').onclick = async (e) => {
    const b = e.currentTarget; if (S.busy) return;
    S.busy = true; b.classList.add('busy');
    const r = await req('infoPay', { id: d.id });
    S.busy = false;
    if (S.panel !== 'talk') return;
    b.classList.remove('busy');
    if (r.error) { Sfx.play('ko'); type($('#bub'), r.error); return; }
    Sfx.play('cash'); b.remove();
    type($('#bub'), r.answer, () => {
      if (!r.merchant || S.panel !== 'talk') return;
      $('.talk').insertAdjacentHTML('beforeend', `<div class="gpscard"><div class="pin">📍</div><div><b>${esc(r.merchant.name)}</b>
        <small>Position marquée sur votre GPS pendant ${r.minutes} min.</small></div></div>`);
      Sfx.play('ok');
      post('gps', { x: r.merchant.x, y: r.merchant.y, z: r.merchant.z, name: r.merchant.name, minutes: r.minutes });
    });
  };
}

// ---------------------------------------------------------------------
// Guichet bancaire : aperçu, dépôt, retrait, virement, historique
// ---------------------------------------------------------------------
const TABS = [['home', '🏠', 'Aperçu'], ['deposit', '⬇️', 'Déposer'], ['withdraw', '⬆️', 'Retirer'], ['transfer', '🔁', 'Virement'], ['history', '🧾', 'Historique']];
function fmtDate(t) { if (!t) return ''; const d = new Date(Number(t) * 1000); return d.toLocaleDateString('fr-FR') + ' · ' + d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }); }
function histRows(list, n) {
  const rows = (list || []).slice(0, n);
  if (!rows.length) return '<div class="empty">Aucune opération pour le moment.</div>';
  return `<div class="hist">${rows.map((h) => { const neg = Number(h.amount) < 0; return `<div class="hrow ${neg ? 'neg' : ''}"><div class="hi">${neg ? '↗' : '↙'}</div>
    <div>${esc(h.label)}<small>${esc(fmtDate(h.t))}</small></div><b class="num">${neg ? '−' : '+'} ${money(Math.abs(h.amount))}</b></div>`; }).join('')}</div>`;
}
function drawBank(p, d) {
  p.innerHTML = `<div class="bank"><aside>
      <div class="brand">${mark(40)}<div><span class="ely-word">Elyzea <b>Bank</b></span><small>${esc(d.bankName)}</small></div></div>
      <div class="card ely-shine"><div class="arc"></div><div class="mk">${mark(56, false)}</div><div class="chipc"></div>
        <div class="no">${esc(d.account)}</div><div class="nm">${esc(d.name)}</div></div>
      <div class="nav">${TABS.filter((t) => t[0] !== 'transfer' || d.transfers).map((t) => `<button data-tab="${t[0]}" class="${S.tab === t[0] ? 'on' : ''}"><i>${t[1]}</i>${t[2]}</button>`).join('')}</div>
      <div class="sky">${window.Ely ? Ely.skyline({ w: 270, h: 120, seed: 11, palm: false }) : ''}</div>
    </aside><main><div class="top"><div><h2 id="ttl"></h2><small id="sub"></small></div><button class="x" data-close>✕</button></div><div class="view" id="view"></div></main></div>`;
  drawView();
}
function drawView() {
  const d = S.data, v = $('#view'); if (!v) return;
  const T = TABS.find((t) => t[0] === S.tab) || TABS[0];
  $('#ttl').textContent = T[2];
  document.querySelectorAll('[data-tab]').forEach((b) => b.classList.toggle('on', b.dataset.tab === S.tab));
  v.style.animation = 'none'; void v.offsetWidth; v.style.animation = '';
  const amount = (max, label) => `<div class="field"><label>${label}</label><div class="amount"><input id="amt" inputmode="numeric" placeholder="0" maxlength="12"><span>$</span></div></div>
    <div class="chips">${[100, 500, 1000, 5000, 10000].map((n) => `<button data-q="${n}">${n.toLocaleString('fr-FR')} $</button>`).join('')}<button data-q="${Math.floor(max)}">Tout (${money(max)})</button></div>`;
  if (S.tab === 'home') {
    $('#sub').textContent = `Bonjour ${d.name}`;
    v.innerHTML = `<div class="stats stagger"><div class="stat main"><span class="ico">🏦</span><label>Solde du compte</label><b class="num" id="bal" data-v="0">${money(0)}</b></div>
      <div class="stat"><span class="ico">💵</span><label>Liquide sur vous</label><b class="num" id="cash" data-v="0">${money(0)}</b></div>
      <div class="stat"><span class="ico">📱</span><label>Numéro lié</label><b>${esc(d.phone || '—')}</b></div></div>
      <div class="quick stagger"><button data-tab="deposit"><i>⬇️</i>Déposer</button><button data-tab="withdraw"><i>⬆️</i>Retirer</button>${d.transfers ? '<button data-tab="transfer"><i>🔁</i>Virement</button>' : '<button data-tab="history"><i>🧾</i>Historique</button>'}</div>
      <div><label style="font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.1em">Dernières opérations</label></div>${histRows(d.history, 4)}`;
    countTo($('#bal'), d.balance, 900); countTo($('#cash'), d.cash, 900);
  } else if (S.tab === 'deposit' || S.tab === 'withdraw') {
    const dep = S.tab === 'deposit', max = dep ? d.cash : d.balance;
    $('#sub').textContent = dep ? `Liquide disponible : ${money(d.cash)}` : `Solde disponible : ${money(d.balance)}`;
    v.innerHTML = `${amount(max, dep ? 'Montant à déposer' : 'Montant à retirer')}
      <div class="sum"><span>${dep ? 'Nouveau solde' : 'Liquide après retrait'}</span><b class="num" id="after">${money(dep ? d.balance : d.cash)}</b></div>
      <button class="btn ${dep ? 'ok' : ''}" id="go" style="height:52px">${dep ? 'Déposer sur mon compte' : 'Retirer en liquide'}</button>
      <p class="note">Minimum ${money(d.min)} · opération vérifiée par la banque.</p>`;
    const amt = $('#amt');
    const upd = () => { amt.value = amt.value.replace(/[^0-9]/g, ''); const a = Number(amt.value) || 0; $('#after').textContent = money((dep ? d.balance : d.cash) + a); };
    amt.addEventListener('input', upd); amt.focus();
    amt.addEventListener('keydown', (e) => { if (e.key === 'Enter') $('#go').click(); });
    v.querySelectorAll('[data-q]').forEach((b) => { b.onclick = () => { amt.value = b.dataset.q; upd(); Sfx.play('click'); }; });
    $('#go').onclick = () => bankOp(S.tab, { amount: Number(amt.value) || 0 }, $('#go'));
  } else if (S.tab === 'transfer') {
    $('#sub').textContent = `Vers un numéro de téléphone · frais ${d.fee || 0} %`;
    v.innerHTML = `<div class="field"><label>Numéro du destinataire</label><input class="plain" id="num" inputmode="numeric" placeholder="555 0123" maxlength="20"></div>
      ${amount(Math.min(d.balance, d.max || d.balance), 'Montant')}
      <div class="sum"><span>Frais · total débité</span><b class="num" id="fee">0 $ · 0 $</b></div>
      <button class="btn" id="go" style="height:52px">Envoyer le virement</button><p class="note">Maximum ${money(d.max)} par virement. Le destinataire peut être hors ligne.</p>`;
    const amt = $('#amt'), num = $('#num');
    const upd = () => { amt.value = amt.value.replace(/[^0-9]/g, ''); const a = Number(amt.value) || 0; const f = Math.floor(a * (d.fee || 0) / 100); $('#fee').textContent = `${money(f)} · ${money(a + f)}`; };
    amt.addEventListener('input', upd); num.addEventListener('input', () => { num.value = num.value.replace(/[^0-9 ]/g, ''); }); num.focus();
    v.querySelectorAll('[data-q]').forEach((b) => { b.onclick = () => { amt.value = b.dataset.q; upd(); Sfx.play('click'); }; });
    $('#go').onclick = () => bankOp('transfer', { amount: Number(amt.value) || 0, number: num.value }, $('#go'));
  } else {
    $('#sub').textContent = '30 dernières opérations';
    v.innerHTML = histRows(d.history, 30);
  }
}
async function bankOp(op, data, btn) {
  if (S.busy) return;
  if (!(data.amount > 0)) { toast('Indiquez un montant.', true); return; }
  S.busy = true; btn.classList.add('busy');
  const r = await post('bank', { op, data });
  S.busy = false; btn.classList.remove('busy');
  if (S.panel !== 'bank') return;
  if (!r || r.error) { Sfx.play('ko'); toast((r && r.error) || 'Opération refusée.', true); return; }
  S.data = Object.assign({}, S.data, r);
  S.tab = 'home'; drawView();
  $('#bal') && $('#bal').parentElement.classList.add('bump');
  Sfx.play('ok'); toast(r.message || 'Opération effectuée.');
}

// ---------------------------------------------------------------------
// Ordinateur de piratage (la porte du coffre)
// ---------------------------------------------------------------------
function screen(title, right, time) {
  const box = $('#hack');
  box.classList.remove('hidden');
  box.innerHTML = `<div class="screen"><div class="wm">${mark(90, false)}</div><div class="bar"><span class="t">${esc(title)}</span>${right}<button class="x" data-close>QUITTER</button></div>
    <div class="timer"><i></i></div><div class="game"></div></div>`;
  const el = box.querySelector('.game'), bar = box.querySelector('.timer i');
  const end = performance.now() + time * 1000;
  const g = { el, done: false, bar, end, time };
  g.timer = setInterval(() => {
    const left = Math.max(0, g.end - performance.now());
    bar.style.width = `${(left / (time * 1000)) * 100}%`;
    bar.classList.toggle('low', left < 6000);
    if (left <= 0 && !g.done && g.onTimeout) g.onTimeout();
  }, 100);
  return g;
}
function openHack(d) {
  const tries = Array.from({ length: d.attemptsMax }, (_, i) => `<i class="${i < d.attemptsLeft ? 'on' : ''}"></i>`).join('');
  const g = screen(`VAULT_SEC // ${String(d.label || '').toUpperCase()}`, `<span class="lv">NIVEAU ${d.difficulty}</span><span class="tries">Tentatives restantes ${tries} <b>${d.attemptsLeft}/${d.attemptsMax}</b></span>`, d.time);
  S.hack = g;
  g.onTimeout = () => { req('hackAbort'); result(g, false, 'TEMPS ÉCOULÉ'); };
  g.el.innerHTML = '<div class="rule">Connexion au module de la porte…</div>';
  Sfx.play('open');
  const api = {
    submit: async (answer) => {
      if (g.done) return;
      const r = await req('hackSubmit', { answer });
      if (r.error) { notify(r.error, 'error'); return; }
      result(g, r.success === true);
    },
    guess: async (digits) => {
      const r = await req('hackGuess', { guess: digits });
      if (r.error) { notify(r.error, 'error'); return r; }
      Sfx.play(r.done && r.success ? 'ok' : 'beep');
      if (r.done) setTimeout(() => result(g, r.success === true), 500);
      return r;
    },
  };
  setTimeout(() => { if (S.hack === g && Games[d.game]) Games[d.game](g.el, d.data, api); }, 650);
}
function result(g, ok, text, sub) {
  if (!g || g.done) return;
  g.done = true;
  if (g.el._cleanup) g.el._cleanup();
  clearInterval(g.timer); if (g.stop) g.stop();
  Sfx.play(ok ? 'ok' : 'ko');
  g.el.innerHTML = `<div class="result ${ok ? 'ok' : 'ko'}">${ok ? 'ACCÈS AUTORISÉ' : esc(text || 'ACCÈS REFUSÉ')}</div>
    <p class="rule">${esc(sub || (ok ? 'Déverrouillage de la porte du coffre…' : 'Tentative perdue.'))}</p>`;
  setTimeout(() => { if (S.hack === g || S.game === g) close({ done: true }); }, 1800);
}

// ---------------------------------------------------------------------
// Boîtier d'alarme : couper les bons fils dans le bon ordre
// ---------------------------------------------------------------------
const WC = { rouge: '#E23B3B', bleu: '#2F6BFF', jaune: '#F5C518', vert: '#22B357', blanc: '#EEEEEE', noir: '#2B2B2B' };
function openWires(d) {
  const g = screen('ALARM_CTRL // BOÎTIER DE SÉCURITÉ', '<span class="lv">SABOTAGE</span>', d.time || 20);
  S.game = g;
  const need = d.wires.filter((w) => w.led === 'verte' || w.color === d.target).length;
  const cuts = [];
  g.el.innerHTML = `<h2>Couper l'alarme</h2>
    <p class="rule">Coupez d'abord les fils au <b>voyant vert</b>, du plus <b>petit</b> numéro au plus grand.<br>Puis les fils <b>${esc(d.target.toUpperCase())}</b> (étiquette), du plus <b>grand</b> numéro au plus petit. Un mauvais fil fait échouer le sabotage.</p>
    <div class="wires"><div class="lab">ÉTIQUETTE : ${esc(d.target.toUpperCase())}</div>
    ${d.wires.map((w, i) => `<div class="wire" data-w="${i + 1}" style="--c:${WC[w.color] || '#888'}"><span class="n">${w.num}</span><span class="led ${esc(w.led === 'éteinte' ? '' : w.led)}"></span>
      <div class="cable" style="background:${WC[w.color] || '#888'}"><span class="l"></span><span class="r"></span></div><span class="term"></span></div>`).join('')}</div>
    <div class="legend"><span>${need} fil(s) à couper</span><span id="cnt">0 / ${need}</span></div>`;
  const submit = async () => {
    if (g.done) return;
    g.el.querySelectorAll('.wire').forEach((w) => { w.style.pointerEvents = 'none'; });
    const r = await req('alarmSubmit', { cuts });
    result(g, r.success === true, 'SABOTAGE RATÉ', r.success ? 'Alarme coupée. Silence…' : 'Le boîtier a signalé la tentative.');
  };
  g.onTimeout = submit;
  g.el.querySelector('.wires').addEventListener('click', (e) => {
    const w = e.target.closest('[data-w]'); if (!w || w.classList.contains('cut') || g.done) return;
    w.classList.add('cut'); cuts.push(Number(w.dataset.w)); Sfx.play('cut');
    w.insertAdjacentHTML('beforeend', `<span class="ord">#${cuts.length}</span>`);
    $('#cnt').textContent = `${cuts.length} / ${need}`;
    if (cuts.length >= need) setTimeout(submit, 350);
  });
}

// ---------------------------------------------------------------------
// Perceuse : maintenir pour percer, relâcher pour refroidir, quatre goupilles à casser
// ---------------------------------------------------------------------
function openDrill(d) {
  const time = Math.max(3, Number(d.time) || 25), rate = Math.max(0.2, Number(d.heatRate) || 1);
  const g = screen('DRILL_OS // COFFRES INDIVIDUELS', '<span class="lv">PERÇAGE</span>', 9999);
  g.el.parentElement.querySelector('.timer').style.visibility = 'hidden';
  S.game = g;
  const C = 2 * Math.PI * 110;
  g.el.innerHTML = `<h2>Percer les serrures</h2><p class="rule">Maintenez <b>CLIC</b> ou <b>ESPACE</b> pour percer. Relâchez avant la <b>surchauffe</b> : la mèche se bloque si elle dépasse 100 %.</p>
    <div class="drill"><div class="dial"><svg viewBox="0 0 260 260"><defs><linearGradient id="dg"><stop offset="0" stop-color="#7B2FF7"/><stop offset="1" stop-color="#C9A6FF"/></linearGradient></defs>
      <circle class="ring" cx="130" cy="130" r="110"/><circle class="prog" id="pr" cx="130" cy="130" r="110" stroke-dasharray="${C}" stroke-dashoffset="${C}"/></svg>
      <div class="pins">${[0, 1, 2, 3].map((i) => { const a = ((i + 1) / 4) * 2 * Math.PI - Math.PI / 2; return `<span class="pin" style="left:${130 + Math.cos(a) * 110}px;top:${130 + Math.sin(a) * 110}px"></span>`; }).join('')}</div>
      <div class="bit" id="bit"></div><div class="sparks" id="sp"></div><div class="pct" id="pct">0 %</div></div>
    <div class="heat"><small>TEMPÉRATURE DE LA MÈCHE</small><div class="hb"><i id="hb"></i></div><small id="hs">Prête</small>
      <button class="hold" id="hold">MAINTENIR POUR PERCER</button></div></div>`;
  let prog = 0, heat = 0, on = false, locked = false, last = performance.now(), raf, pins = 0, sparkT = 0;
  const pr = $('#pr'), bit = $('#bit'), hb = $('#hb'), hs = $('#hs'), pct = $('#pct'), sp = $('#sp'), hold = $('#hold');
  const press = (v) => { if (g.done) return; v = v && !locked; if (v === on) return; on = v; hold.classList.toggle('on', on); bit.classList.toggle('spin', on); post('drillPress', { on }); };
  const tick = (t) => {
    const dt = Math.min(0.1, (t - last) / 1000); last = t;
    if (on && !locked) {
      prog = Math.min(1, prog + dt / time);
      heat += dt * 13 * rate;
      if (heat >= 100) { heat = 100; locked = true; press(false); Sfx.play('ko'); }
      if (t - sparkT > 60) {
        sparkT = t;
        const a = Math.random() * Math.PI * 2, r = 50 + Math.random() * 70;
        const s = document.createElement('i'); s.style.setProperty('--dx', `${Math.cos(a) * r}px`); s.style.setProperty('--dy', `${Math.sin(a) * r}px`);
        sp.appendChild(s); setTimeout(() => s.remove(), 520);
      }
    } else heat = Math.max(0, heat - dt * 24);
    if (locked && heat < 35) locked = false;
    pr.style.strokeDashoffset = C * (1 - prog);
    pct.textContent = `${Math.floor(prog * 100)} %`;
    hb.style.width = `${heat}%`;
    bit.classList.toggle('hot', heat > 70);
    hs.className = locked ? 'warn' : ''; hs.textContent = locked ? 'SURCHAUFFE · REFROIDISSEMENT' : (heat > 70 ? 'Attention : ça chauffe' : (on ? 'Perçage…' : 'Prête'));
    hold.disabled = locked;
    const np = Math.floor(prog * 4 + 1e-6);
    while (pins < np) { g.el.querySelectorAll('.pin')[pins].classList.add('done'); pins += 1; Sfx.play(pins === 4 ? 'unlock' : 'beep'); }
    if (prog >= 1) { press(false); result(g, true, '', 'Serrures percées : remplissez le sac !'); g.el.querySelector('.result').textContent = 'COFFRES OUVERTS'; return; }
    raf = requestAnimationFrame(tick);
  };
  raf = requestAnimationFrame(tick);
  hold.addEventListener('mousedown', () => press(true));
  const up = () => press(false);
  const kd = (e) => { if (e.code === 'Space') { e.preventDefault(); if (!e.repeat) press(true); } };
  const ku = (e) => { if (e.code === 'Space') press(false); };
  document.addEventListener('mouseup', up); document.addEventListener('keydown', kd); document.addEventListener('keyup', ku);
  g.stop = () => { cancelAnimationFrame(raf); document.removeEventListener('mouseup', up); document.removeEventListener('keydown', kd); document.removeEventListener('keyup', ku); if (on) post('drillPress', { on: false }); on = false; };
}

// ---------------------------------------------------------------------
// HUD du braquage (haut à droite) : butin de l'équipe, ma part, sac, porte, alarme, temps restant
// ---------------------------------------------------------------------
const HUD = { heist: null, bag: null, closeAt: 0, timer: null };
const DOOR = { locked: ['Verrouillée', 'red'], hacking: ['Décryptage…', ''], c4: ['Charge armée', 'red'], open: ['Ouverte', 'okc'] };
function drawHud() {
  const el = $('#hud'), h = HUD.heist, b = HUD.bag;
  if (!h && !b) { el.classList.add('hidden'); el.innerHTML = ''; clearInterval(HUD.timer); HUD.timer = null; return; }
  const first = el.classList.contains('hidden') || !el.innerHTML;
  if (first) {
    el.innerHTML = `<div class="ht"><div class="mk">${mark(30)}</div><div><b id="hT"></b><small id="hS"></small></div><span class="live" id="hL"><i></i>LIVE</span></div>
      <div id="hH"><div class="big num" id="hTot" data-v="0">0 $</div><div class="lbl">Butin de l'équipe</div>
      <div class="rows"><div class="cell"><small>Ma part</small><b class="num" id="hMine" data-v="0">0 $</b></div><div class="cell" id="hDc"><small>Coffre</small><b id="hDoor"></b></div>
      <div class="cell" id="hAc"><small>Alarme</small><b id="hAl"></b></div><div class="cell"><small>Braqueurs</small><b id="hRob"></b></div></div>
      <div class="timer2" id="hTi"><span>Fermeture du coffre</span><b id="hTime">--:--</b></div></div>
      <div class="bag" id="hB"><div class="bl"><span>🎒 Sac</span><span><b class="num" id="hBag" data-v="0">0 $</b> / <span id="hCap"></span></span></div><div class="bar2" id="hBb"><i id="hBi"></i></div></div>`;
    el.classList.remove('hidden');
  }
  $('#hT').textContent = h ? 'Braquage' : 'Sac de billets';
  $('#hS').textContent = h ? h.bank : 'Encaissez-le à un point de dépôt';
  $('#hL').style.display = h ? '' : 'none';
  $('#hH').style.display = h ? '' : 'none';
  el.classList.toggle('alarm', !!(h && h.alarm));
  if (h) {
    countTo($('#hTot'), h.total); countTo($('#hMine'), h.mine || 0);
    const dr = DOOR[h.door] || ['—', '']; $('#hDoor').textContent = dr[0]; $('#hDc').className = `cell ${dr[1]}`;
    $('#hAl').textContent = h.alarm ? 'Déclenchée' : 'Coupée'; $('#hAc').className = `cell ${h.alarm ? 'red' : 'okc'}`;
    $('#hRob').textContent = h.robbers || 1;
    HUD.closeAt = h.closeIn != null ? performance.now() + h.closeIn * 1000 : 0;
    $('#hTi').style.display = HUD.closeAt ? '' : 'none';
    if (HUD.closeAt && !HUD.timer) HUD.timer = setInterval(tickHud, 500);
    tickHud();
  }
  $('#hB').style.display = b ? '' : 'none';
  if (b) {
    countTo($('#hBag'), b.money);
    $('#hCap').textContent = money(b.capacity);
    const pct = b.capacity ? Math.min(100, (b.money / b.capacity) * 100) : 0;
    $('#hBi').style.width = `${pct}%`; $('#hBb').classList.toggle('full', pct >= 99.5);
  }
}
function tickHud() {
  const t = $('#hTime'); if (!t || !HUD.closeAt) return;
  const s = Math.max(0, Math.round((HUD.closeAt - performance.now()) / 1000));
  t.textContent = `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
  $('#hTi').classList.toggle('low', s <= 60);
}
function floatGain(amount) {
  const f = document.createElement('div'); f.className = 'float'; f.textContent = `+ ${money(amount)}`;
  const hud = $('#hud'); if (hud && !hud.classList.contains('hidden')) f.style.top = `${hud.getBoundingClientRect().bottom + 6}px`;
  document.body.appendChild(f); setTimeout(() => f.remove(), 1350);
}

// Bandeau d'annonce (braquage, coffre ouvert, charge armée…)
let bannerT = null;
function banner(m) {
  const b = $('#banner');
  clearTimeout(bannerT);
  b.className = m.kind || 'info';
  b.innerHTML = `<div class="bx"><div class="mk">${mark(54)}</div><h3>${esc(m.title)}</h3>${m.sub ? `<p>${esc(m.sub)}</p>` : ''}</div>`;
  bannerT = setTimeout(() => { b.classList.add('out'); bannerT = setTimeout(() => b.classList.add('hidden'), 520); }, m.time || 3800);
}
function alarmFx(m) {
  const f = $('#flash');
  Sfx.alarm(!!m.on, m.volume);
  f.classList.toggle('on', !!m.on && (m.volume || 0) > 0.05);
  f.style.setProperty('--a', String(Math.min(0.8, (m.volume || 0) * 1.1)));
}

// ---------------------------------------------------------------------
// Événements
// ---------------------------------------------------------------------
document.addEventListener('click', async (e) => {
  let n;
  if (e.target.closest('[data-close]')) { Sfx.play('click'); return close({ done: !!((S.hack && S.hack.done) || (S.game && S.game.done)) }); }
  if ((n = e.target.closest('[data-tab]')) && S.panel === 'bank') { S.tab = n.dataset.tab; Sfx.play('click'); return drawView(); }
  if ((n = e.target.closest('[data-opt]')) && !n.disabled) { const id = n.dataset.opt; S.panel = null; drawPanel(); return post('menuSelect', { id }); }
  if ((n = e.target.closest('[data-buy]')) && !n.disabled && !S.busy) {
    S.busy = true; n.classList.add('busy');
    const r = await req('shopBuy', { merchant: S.data.id, item: n.dataset.buy });
    if (r.error) { notify(r.error, 'error'); Sfx.play('ko'); } else Sfx.play('cash');
    const d = await req('shopData', { merchant: S.data.id });
    S.busy = false;
    if (S.panel !== 'shop') return;
    if (d.error) return close();
    S.data = d; drawPanel();
  }
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && S.panel) close({ done: !!((S.hack && S.hack.done) || (S.game && S.game.done)) }); });

window.addEventListener('message', (ev) => {
  const m = ev.data || {};
  switch (m.action) {
    case 'open':
      stopGame();
      S.imagePath = m.imagePath || S.imagePath;
      S.panel = m.panel; S.data = m.data || {}; S.busy = false;
      if (m.panel === 'bank') S.tab = 'home';
      $('#hack').classList.add('hidden'); $('#hack').innerHTML = '';
      drawPanel();
      if (m.panel === 'hack') openHack(S.data);
      else if (m.panel === 'wires') openWires(S.data);
      else if (m.panel === 'drill') openDrill(S.data);
      else if (m.panel !== 'menu') Sfx.play('open');
      break;
    case 'close':
      stopGame(); S.panel = null; S.data = null; S.busy = false;
      $('#hack').classList.add('hidden'); $('#hack').innerHTML = ''; drawPanel();
      break;
    case 'hud': HUD.heist = m.show ? (m.heist || null) : null; HUD.bag = m.show ? (m.bag || null) : null; drawHud(); break;
    case 'grabbed': floatGain(m.amount); break;
    case 'banner': banner(m); break;
    case 'sfx': Sfx.play(m.name, m.volume == null ? 1 : m.volume); break;
    case 'alarm': alarmFx(m); break;
    default: break;
  }
});

if (/[?&]demo=/.test(location.search)) { const s = document.createElement('script'); s.src = 'demo.js'; document.body.appendChild(s); }
