/* =====================================================================
   ELYZEA MÉCANO - atelier : Esthétique / Performance / Prestations, aperçu en direct,
   devis (envoi, paiement, installation), liste des interventions pendant l'installation,
   suivi en direct pour le client, remise des clés.
   Les prix affichés viennent du serveur ; le total réel est recalculé par le serveur.
   ===================================================================== */
const W = { d: null, mode: 'cosmetic', cat: null, item: null, sub: null, opts: null, cur: null, cart: [], customer: null, quote: null, busy: false, result: null, live: false };

/* ---------- Icônes (traits fins) ---------- */
const ICO = {
  cosmetic: '<path d="M3 15l2-5c.4-1 1.2-2 2.6-2h8.8c1.4 0 2.2 1 2.6 2l2 5v3H3z"/><circle cx="7" cy="18" r="1.8"/><circle cx="17" cy="18" r="1.8"/>',
  paint: '<path d="M4 4h12v5H4z"/><path d="M16 6h3v6h-8v3"/><path d="M10 15h2v6h-2z"/>',
  wheels: '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="3"/><path d="M12 3.5v5.5M12 15v5.5M3.5 12H9M15 12h5.5"/>',
  lights: '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z"/>',
  interior: '<path d="M7 20v-6c0-1 .8-2 2-2h6c1.2 0 2 1 2 2v6"/><path d="M8 12V6a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v6"/><path d="M5 20h14"/>',
  perf: '<path d="M4 16a8 8 0 1 1 16 0"/><path d="M12 16l4.5-5"/><circle cx="12" cy="16" r="1.4"/>',
  service: '<path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18v3h3l6.3-6.3a4 4 0 0 0 5.4-5.4l-2.6 2.6-2.4-.6-.6-2.4z"/>',
  engine: '<path d="M4 10h3l2-3h6v3h2l2 2v4h-2v2h-4l-2 2H7v-4H4z"/>',
  brake: '<circle cx="12" cy="12" r="8.5"/><path d="M12 6a6 6 0 0 1 6 6"/><circle cx="12" cy="12" r="2"/>',
  wheel: '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="3"/>',
  lift: '<path d="M4 20V5M20 20V5M4 12h16M7 12V9h10v3"/>',
  hood: '<path d="M3 16l3-7h12l3 7z"/><path d="M8 9l1-3h6l1 3"/>',
  shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>',
  front: '<path d="M4 14h16v4H4z"/><path d="M6 14l2-5h8l2 5"/>',
  rear: '<path d="M4 14h16v4H4z"/><path d="M7 14l1.5-5h7L17 14"/><path d="M8 16h2M14 16h2"/>',
  trunk: '<path d="M4 9h16v9H4z"/><path d="M4 9l3-4h10l3 4"/>',
  side: '<path d="M2 14l3-5h9l5 5h3v3H2z"/><circle cx="7" cy="17" r="1.6"/><circle cx="17" cy="17" r="1.6"/>',
  roof: '<path d="M4 15l3-7h10l3 7z"/><path d="M2 15h20"/>',
  glass: '<path d="M5 18l3-11h8l3 11z"/><path d="M9 10l5 6"/>',
  light: '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z"/>',
  neon: '<path d="M3 17h18"/><path d="M5 20h14" opacity=".5"/><path d="M6 14l2-5h8l2 5"/>',
  plate: '<rect x="3" y="8" width="18" height="8" rx="1.5"/><path d="M7 12h10"/>',
  seat: '<path d="M7 20v-6c0-1 .8-2 2-2h6c1.2 0 2 1 2 2v6"/><path d="M8 12V6a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v6"/>',
  key: '<circle cx="8" cy="15" r="4"/><path d="M11 12l9-9M17 6l2 2M15 8l2 2"/>',
  check: '<path d="M5 12l5 5L20 7"/>',
};
const icon = (k, cls = 'ico') => `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${ICO[k] || ICO.cosmetic}</svg>`;

const PERF_LABEL = { engine: 'Moteur', brakes: 'Freins', transmission: 'Transmission', suspension: 'Suspension', armor: 'Blindage', turbo: 'Turbo' };
const PERF_ICON = { engine: 'engine', brakes: 'brake', transmission: 'perf', suspension: 'lift', armor: 'shield', turbo: 'perf' };
const PERF_FX = {
  engine: 'Plus d\'accélération et de vitesse de pointe.',
  brakes: 'Freinage plus puissant, distance d\'arrêt réduite.',
  transmission: 'Passage des rapports plus rapide, meilleures reprises.',
  suspension: 'Caisse abaissée et plus stable en virage.',
  armor: 'La carrosserie encaisse mieux les chocs et les tirs.',
  turbo: 'Surcroît de puissance à l\'accélération.',
};
const MODES = [
  { id: 'cosmetic', label: 'Esthétique', icon: 'cosmetic', cats: ['cosmetic', 'paint', 'wheels', 'lights', 'interior'] },
  { id: 'perf', label: 'Performance', icon: 'perf', cats: ['perf'] },
  { id: 'service', label: 'Prestations', icon: 'service', cats: ['service'] },
];
const modeOf = (cat) => (MODES.find((m) => m.cats.includes(cat)) || MODES[0]).id;
// Caméra placée sur la pièce choisie
const BODY_FOCUS = { 0: 'rear', 1: 'front', 2: 'rear', 3: 'left', 4: 'rear', 5: 'top', 6: 'front', 7: 'hood', 8: 'left', 9: 'right', 10: 'top', 14: 'front', 37: 'rear',
  38: 'wheel', 39: 'hood', 40: 'hood', 41: 'hood', 42: 'wheel', 43: 'top', 44: 'left', 45: 'left', 46: 'left', 47: 'left', 49: 'top' };
const CAT_FOCUS = { cosmetic: 'overview', paint: 'overview', wheels: 'wheel', lights: 'front', interior: 'interior', perf: 'hood', service: 'overview' };
const ITEM_FOCUS = { neon: 'left', xenon: 'front', tint: 'left', plate: 'rear', platetext: 'rear', livery: 'left', roofliv: 'top', smoke: 'wheel' };
const camFocus = (f) => { if (f) post('wsCam', { focus: f }); };

const slotOf = (spec, item) => {
  if (item.kind === 'perf') return `perf:${item.mod}`;
  if (item.kind === 'service' || item.kind === 'custom') return `svc:${item.code}`;
  if (!spec) return `cos:${item.mod}`;
  if (spec.t === 'mod') return `cos:mod${spec.id}`;
  if (spec.t === 'paint') return `cos:paint${spec.slot}`;
  if (spec.t === 'extra') return `cos:extra${spec.id}`;
  return `cos:${spec.t}`;
};
const curPerf = (mod) => Math.max(Number((W.d.live || {})[mod] || 0), Number((W.d.data.savedPerf || {})[mod] || 0));
const lineTotal = (l) => l.price * (l.qty || 1);
const cartTotal = () => W.cart.reduce((s, l) => s + lineTotal(l), 0);

function wsCats(mode) {
  const items = W.d.data.items;
  const allowed = W.d.data.ws.categories || [];
  return (MODES.find((m) => m.id === mode) || MODES[0]).cats
    .filter((c) => allowed.includes(c) && items.some((i) => i.category === c))
    .map((c) => ({ id: c, label: (W.d.data.categories || {})[c] || c, n: W.cart.filter((l) => l.category === c).length }));
}
const modeCount = (mode) => W.cart.filter((l) => modeOf(l.category) === mode).length;

/* ---------- Rendu ---------- */
function gauge(label, v) {
  v = Math.max(0, Math.min(100, Number(v) || 0));
  const col = v > 70 ? 'var(--green)' : v > 35 ? 'var(--orange)' : 'var(--red)';
  return `<div class="gauge"><span>${esc(label)}</span><i><b style="width:${v}%;background:${col}"></b></i><em class="mono">${v}%</em></div>`;
}

function quoteView(q, data) {
  const steps = [['pending', 'Devis envoyé'], ['accepted', 'Paiement reçu'], ['install', 'Installation'], ['keys', 'Remise des clés']];
  const at = q.status === 'pending' ? 0 : q.status === 'accepted' ? 1 : 3;
  return `<div class="qv">
    <div class="timeline">${steps.map(([, l], i) => `<div class="tl ${i < at ? 'done' : i === at ? 'now' : ''}"><i>${i < at ? icon('check', 'ico s') : i + 1}</i><span>${l}</span></div>`).join('<b class="tl-bar"></b>')}</div>
    <div class="qv-head"><div><div class="eyebrow">Devis ${esc(q.uid)}</div><h3>${esc(QST[q.status] || q.status)}</h3></div><div class="qv-total mono">${money(q.total)}</div></div>
    <div class="q-items">${q.items.map((l) => `<div class="bill-line"><span>${esc(l.label)}${l.qty > 1 ? ` <em>×${l.qty}</em>` : ''}</span><b class="mono">${money(l.total)}</b></div>`).join('')}</div>
    ${q.customer ? `<p class="faint">Client : ${esc(q.customer)}</p>` : ''}
    ${q.status === 'pending' ? '<div class="note wait">⏳ Le client consulte le devis sur son écran. Rien n\'est installé avant son paiement.</div>' : ''}
    ${q.status === 'accepted' ? '<div class="note ok">✅ Paiement confirmé. Lancez l\'installation : une flèche vous montre chaque point d\'intervention autour du véhicule, un mini-jeu pose la pièce.</div>' : ''}
    ${W.result ? `<div class="note">${esc(W.result)}</div>` : ''}
    <div class="actions">${q.status === 'accepted' && data.canInstall !== false ? `<button class="btn primary glow" data-ws="install">${icon('service', 'ico s')} Commencer l'installation</button>` : ''}
      ${q.status === 'pending' || q.status === 'accepted' ? '<button class="btn danger" data-ws="cancelQuote">Annuler le devis</button>' : ''}
      ${!['pending', 'accepted'].includes(q.status) ? '<button class="btn" data-ws="newQuote">Nouveau devis</button>' : ''}</div></div>`;
}

function perfView(list) {
  const d = W.d;
  const mods = [...new Set(list.map((i) => i.mod))];
  return `<div class="perf-grid">${mods.map((m) => {
    const cur = curPerf(m), max = (d.maxLv || {})[m] || 0;
    const inCart = W.cart.find((l) => l.slot === `perf:${m}`);
    const lv = list.filter((i) => i.mod === m).sort((a, b) => a.level - b.level);
    const top = m === 'turbo' ? 1 : Math.max(max, lv.length ? lv[lv.length - 1].level : 0);
    const want = inCart ? (lv.find((i) => i.code === inCart.code) || {}).level || 0 : 0;
    const status = !max ? '<span class="pill off">Non compatible</span>' : inCart ? '<span class="pill cyan">Dans le devis</span>'
      : cur > 0 ? `<span class="pill on">${m === 'turbo' ? 'Installé' : `Installé · niv. ${cur}`}</span>` : '<span class="pill">Origine</span>';
    const seg = Array.from({ length: Math.max(1, top) }, (_, k) => `<i class="${k < cur ? 'have' : k < want ? 'want' : ''}"></i>`).join('');
    return `<div class="perf-card ${inCart ? 'sel' : ''} ${!max ? 'na' : ''}">
      <div class="pc-head">${icon(PERF_ICON[m])}<div><b>${esc(PERF_LABEL[m] || m)}</b><small>${esc(PERF_FX[m] || '')}</small></div>${status}</div>
      <div class="pc-levels"><span>Actuel <b class="mono">${m === 'turbo' ? (cur ? 'oui' : 'non') : cur}</b></span><div class="seg">${seg}</div><span>Proposé <b class="mono">${want ? (m === 'turbo' ? 'oui' : want) : '—'}</b></span></div>
      <div class="pc-opts">${lv.map((i) => { const bad = i.locked || i.level <= cur || i.level > max;
        return `<button class="opt ${inCart && inCart.code === i.code ? 'on' : ''}" data-perf="${esc(i.code)}" ${bad ? 'disabled' : ''} title="${esc(i.reason || (i.level <= cur ? 'Déjà installé' : i.level > max ? 'Non compatible avec ce véhicule' : ''))}">
          ${esc(m === 'turbo' ? 'Turbo' : `Niveau ${i.level}`)}<small class="mono">${money(i.price)}</small>${!bad && m !== 'turbo' ? `<em>+${i.level - cur} palier${i.level - cur > 1 ? 's' : ''}</em>` : ''}</button>`; }).join('')}</div></div>`;
  }).join('')}</div>`;
}

function cosmeticView(list) {
  const d = W.d, data = d.data;
  if (!W.item || !list.find((i) => i.code === W.item)) W.item = (list.find((i) => !((d.groups || {})[i.mod] || {}).empty) || list[0] || {}).code;
  const it = list.find((i) => i.code === W.item);
  const grp = it ? (d.groups || {})[it.mod] || {} : {};
  let html = `<div class="subtabs">${list.map((i) => { const g = (d.groups || {})[i.mod] || {};
    return `<button class="${i.code === W.item ? 'on' : ''} ${i.mod === 'drift' ? 'drift' : ''}" data-witem="${esc(i.code)}" ${g.empty ? 'disabled title="Rien de compatible avec ce véhicule"' : ''}>${esc(i.name)}${i.mod === 'drift' ? ' <span class="badge-drift">DRIFT</span>' : ''}<small class="mono">${money(i.price)}${i.mod === 'newtyres' ? ' / pneu' : ''}</small></button>`; }).join('')}</div>`;
  if (!it) return html + '<div class="empty">Aucune option.</div>';
  if (it.description) html += `<p class="item-desc">${esc(it.description)}</p>`;
  if (it.locked) return html + `<div class="empty">${esc(it.reason || 'Indisponible pour votre grade.')}</div>`;
  if (grp.empty) return html + `<div class="empty">${it.mod === 'platetext' ? 'La plaque personnalisée ne se pose que sur un véhicule de joueur (carte grise).' : it.mod === 'drift' ? 'Pneus DRIFT indisponibles : le serveur doit tourner avec sv_enforceGameBuild 2944 ou plus.' : 'Aucune option compatible avec ce véhicule.'}</div>`;
  if (grp.text) {
    const inCart = W.cart.find((l) => l.code === it.code);
    return html + `<div class="plate-edit"><div class="plate-now">Actuelle <span class="mono">${esc(data.plate)}</span></div>
      <input class="input mono plate-in" id="wsPlate" maxlength="8" value="${esc(inCart ? inCart.spec.v : '')}" placeholder="${esc(data.plate)}">
      <button class="btn primary" data-wplate="1">${inCart ? 'Modifier' : 'Ajouter au devis'} · ${money(it.price)}</button></div>
      <p class="faint small">1 à 8 caractères, unique sur le serveur. Visible sur le véhicule pendant la saisie ; carte grise, clés et coffre suivent à l'installation.</p>`;
  }
  if (grp.subs) html += `<div class="chips">${grp.subs.map((s) => `<button class="chip ${String(W.sub) === s.id ? 'on' : ''}" data-wsub="${esc(s.id)}">${esc(s.label)}</button>`).join('')}</div>`;
  if (grp.subs && W.sub === null) return html + '<div class="empty">Choisissez l\'élément à modifier : la caméra se place dessus.</div>';
  if (RGB_GROUPS[it.mod]) html += rgbCard(it);
  if (!W.opts) return html + '<div class="empty loading-dots">Lecture des options du véhicule</div>';
  const inCart = W.cart.find((l) => l.code === it.code && l.slot === slotOf(W.opts[0] && W.opts[0].spec, it));
  return html + `<div class="opt-grid">${W.opts.map((o, i) => {
    const on = inCart && JSON.stringify(inCart.spec) === JSON.stringify(o.spec);
    const cur = String(o.value) === String(W.cur);
    return `<button class="opt ${on ? 'on' : ''} ${cur ? 'cur' : ''}" data-wopt="${i}">${o.badge ? `<span class="badge-drift">${esc(o.badge)}</span>` : ''}${esc(o.label)}
      ${cur ? '<small>Actuel</small>' : ''}${o.qty > 1 ? `<small class="mono">${o.qty} × ${money(it.price)}</small>` : ''}</button>`; }).join('') || '<div class="empty">Aucune option.</div>'}</div>`;
}

function serviceView(list) {
  return `<div class="svc-list">${list.map((i) => { const inCart = W.cart.find((l) => l.code === i.code);
    return `<div class="svc"><div><b>${esc(i.name)}</b><small>${esc(i.description || '')}</small></div>
      <button class="btn ${inCart ? 'success' : ''}" data-svc="${esc(i.code)}" ${i.locked ? 'disabled' : ''}>${inCart ? '✓ Ajoutée' : money(i.price)}</button></div>`; }).join('')}</div>`;
}

function wsRender() {
  const d = W.d, data = d.data, q = W.quote;
  let main;
  if (q) main = quoteView(q, data);
  else if (!W.cat) main = `<div class="empty big">${icon(W.mode === 'perf' ? 'perf' : 'cosmetic', 'ico xl')}<p>Choisissez une rubrique.</p><small>Chaque option s'affiche tout de suite sur le véhicule et s'ajoute au devis (re-cliquez pour la retirer). Rien n'est facturé avant le paiement du client ; ce qui n'est pas payé et installé est retiré en quittant l'atelier.</small></div>`;
  else {
    const list = data.items.filter((i) => i.category === W.cat);
    main = W.cat === 'perf' ? perfView(list) : W.cat === 'service' ? serviceView(list) : cosmeticView(list);
  }
  const customers = data.customers || [];
  const groups = MODES.map((m) => ({ m, lines: W.cart.filter((l) => modeOf(l.category) === m.id) })).filter((g) => g.lines.length);
  $('#workshop').innerHTML = `
    <div class="ws-head">
      <div class="ws-id"><div class="eyebrow">${icon('service', 'ico s')} ${esc(data.ws.label)}</div>
        <h2>${esc(d.model)} <span class="plate-chip mono">${esc(data.plate)}</span>${data.drift ? ' <span class="badge-drift">DRIFT</span>' : ''}</h2>
        <div class="meta">${data.owned ? `Propriétaire : ${esc(data.owner || 'inconnu')}` : 'Véhicule sans carte grise : rien n\'est sauvegardé après sa disparition'}</div></div>
      <div class="ws-gauges">${gauge('Moteur', d.health.engine)}${gauge('Carrosserie', d.health.body)}</div>
      <button class="icon-btn" data-ws="close" title="Fermer (Échap)">✕</button></div>
    ${q ? '' : `<div class="ws-modes">${MODES.filter((m) => wsCats(m.id).length).map((m) => `<button class="mode ${W.mode === m.id ? 'on' : ''}" data-wmode="${m.id}">${icon(m.icon, 'ico s')}<span>${m.label}</span>${modeCount(m.id) ? `<em>${modeCount(m.id)}</em>` : ''}</button>`).join('')}</div>`}
    <div class="ws-body ${q ? 'noside' : ''}">${q ? '' : `<nav class="ws-cats">${wsCats(W.mode).map((c) => `<button class="ws-cat ${W.cat === c.id ? 'active' : ''}" data-wcat="${c.id}">
        ${icon(c.id === 'cosmetic' ? 'cosmetic' : c.id)}<span>${esc(c.label)}</span>${c.n ? `<em>${c.n}</em>` : ''}</button>`).join('')}</nav>`}
      <div class="ws-main">${main}</div></div>
    ${q ? '' : `<div class="ws-cart">
      <div class="cart-head"><span>Devis</span><small>${W.cart.length} ligne(s)</small></div>
      <div class="cart-lines">${groups.map((g) => `<div class="cart-group"><div class="cg-title">${icon(g.m.icon, 'ico s')} ${g.m.label}</div>${g.lines.map((l) => `<div class="line"><span>${esc(l.label)}${l.qty > 1 ? ` <em>×${l.qty}</em>` : ''}</span><span><b class="mono">${money(lineTotal(l))}</b><button data-wdel="${W.cart.indexOf(l)}" title="Retirer">✕</button></span></div>`).join('')}</div>`).join('') || '<div class="faint small">Aucune ligne : sélectionnez des options.</div>'}</div>
      <div class="ws-total"><div class="tot"><small>Total</small><b class="mono">${money(cartTotal())}</b></div>
        <select class="input" id="wsCustomer">${customers.length ? customers.map((c) => `<option value="${c.id}" ${String(W.customer) === String(c.id) ? 'selected' : ''}>${c.self ? `Moi-même${c.owner ? ' (propriétaire)' : ''} · je paie` : c.owner ? `${esc(c.name || '')} (propriétaire)` : `Personne · ID ${c.id}`}</option>`).join('') : '<option value="">Aucun client à côté</option>'}</select>
        <button class="btn" data-ws="clear" ${W.cart.length ? '' : 'disabled'}>Vider</button>
        <button class="btn primary glow" data-ws="send" ${W.cart.length && customers.length ? '' : 'disabled'}>Envoyer le devis</button></div></div>`}
    <div class="cam-hint">🖱️ clic droit + glisser : tourner · molette : zoom · double-clic : recentrer</div>`;
}

/* ---------- Couleur personnalisée (RVB) : peinture et fumée ---------- */
const RGB_GROUPS = { paint: true, smoke: true };
const RGB_FINISH = [[0, 'Normal'], [1, 'Métallisé'], [2, 'Nacré'], [3, 'Mat'], [4, 'Métal'], [5, 'Chrome']];
const hexToRgb = (h) => [1, 3, 5].map((i) => parseInt(String(h).slice(i, i + 2), 16) || 0);
function rgbCard(it) {
  const prev = (W.rgb && W.rgb[it.mod]) || { hex: '#d9b56a', finish: 1 };
  return `<div class="rgb-card"><span>🎨 Couleur personnalisée</span><input type="color" id="wsRgb" value="${esc(prev.hex)}">
    ${it.mod === 'paint' ? `<select class="input" id="wsRgbFin">${RGB_FINISH.map(([v, l]) => `<option value="${v}" ${prev.finish === v ? 'selected' : ''}>${l}</option>`).join('')}</select>` : ''}
    <button class="btn primary" data-wrgb="add">Ajouter · ${money(it.price)}</button></div>`;
}
function rgbSpec(it) {
  const hex = ($('#wsRgb') || {}).value || '#ffffff', rgb = hexToRgb(hex);
  const finish = Number(($('#wsRgbFin') || {}).value || 1);
  W.rgb = W.rgb || {}; W.rgb[it.mod] = { hex, finish };
  const label = `perso ${hex.toUpperCase()}`;
  if (it.mod === 'paint') return { spec: { t: 'paint', slot: Number(W.sub) || 1, color: rgb, finish }, label: `${Number(W.sub) === 2 ? 'secondaire' : 'principale'} ${label}` };
  return { spec: { t: 'smoke', rgb }, label };
}

async function wsLoadOptions() {
  const it = W.d.data.items.find((i) => i.code === W.item);
  if (!it) return wsRender();
  const grp = (W.d.groups || {})[it.mod] || {};
  if (grp.text || grp.empty) { W.opts = []; return wsRender(); }
  if (grp.subs && W.sub === null) { W.opts = null; return wsRender(); }
  W.opts = null; wsRender();
  const r = await post('wsOptions', { group: it.mod, sub: W.sub });
  W.opts = r.options || []; W.cur = r.current;
  wsRender();
}
function wsAdd(line) { W.cart = W.cart.filter((l) => l.slot !== line.slot); W.cart.push(line); wsRender(); }
const wsReapply = () => post('wsReapply', { specs: W.cart.map((l) => l.preview).filter(Boolean) });
const dropLive = () => { if (W.live) { W.live = false; wsReapply(); } };
let liveTimer = null, livePending = null;
function livePreview(spec) {
  W.live = true; livePending = spec;
  if (liveTimer) return;
  liveTimer = setTimeout(() => { liveTimer = null; post('wsPreview', { spec: livePending }); }, 60);
}
const itemOf = (code) => W.d.data.items.find((i) => i.code === code);

$('#workshop').addEventListener('click', async (e) => {
  let b;
  if (W.busy) return;
  if ((b = e.target.closest('[data-wmode],[data-wcat],[data-witem],[data-wsub]'))) dropLive();
  if ((b = e.target.closest('[data-wmode]'))) {
    W.mode = b.dataset.wmode; const cats = wsCats(W.mode);
    W.cat = cats.length === 1 ? cats[0].id : null; W.item = null; W.sub = null; W.opts = null;
    camFocus(CAT_FOCUS[W.cat || (W.mode === 'perf' ? 'perf' : 'cosmetic')]);
    if (W.cat && !['perf', 'service'].includes(W.cat)) return wsLoadOptions();
    return wsRender();
  }
  if ((b = e.target.closest('[data-wcat]'))) {
    W.cat = b.dataset.wcat; W.item = null; W.sub = null; W.opts = null;
    camFocus(CAT_FOCUS[W.cat]);
    if (!['perf', 'service'].includes(W.cat)) return wsLoadOptions();
    return wsRender();
  }
  if ((b = e.target.closest('[data-witem]'))) { W.item = b.dataset.witem; W.sub = null; W.opts = null; const it = itemOf(W.item); if (it) camFocus(ITEM_FOCUS[it.mod]); return wsLoadOptions(); }
  if ((b = e.target.closest('[data-wsub]'))) {
    W.sub = b.dataset.wsub;
    const it = itemOf(W.item);
    if (it && it.mod === 'body') camFocus(BODY_FOCUS[Number(W.sub)] || 'overview');
    else if (it && it.mod === 'interior') camFocus('interior');
    else if (it && it.mod === 'neon') camFocus(W.sub === '0010' ? 'front' : W.sub === '0001' ? 'rear' : 'left');
    return wsLoadOptions();
  }
  if ((b = e.target.closest('[data-wopt]'))) {
    const it = itemOf(W.item), o = W.opts[Number(b.dataset.wopt)];
    if (!it || !o) return;
    const slot = slotOf(o.spec, it), inCart = W.cart.find((l) => l.slot === slot);
    W.live = false;
    if (inCart && JSON.stringify(inCart.spec) === JSON.stringify(o.spec)) { W.cart = W.cart.filter((l) => l !== inCart); wsReapply(); return wsRender(); }
    post('wsPreview', { spec: o.spec });
    return wsAdd({ code: it.code, name: it.name, kind: it.kind, category: it.category, price: it.price, qty: o.qty || 1, spec: o.spec, preview: o.spec, slot, label: `${it.name} : ${o.label}` });
  }
  if ((b = e.target.closest('[data-wrgb]'))) {
    const it = itemOf(W.item); if (!it) return;
    const { spec, label } = rgbSpec(it);
    post('wsPreview', { spec }); W.live = false;
    return wsAdd({ code: it.code, name: it.name, kind: it.kind, category: it.category, price: it.price, spec, preview: spec, slot: slotOf(spec, it), label: `${it.name} : ${label}` });
  }
  if ((b = e.target.closest('[data-wplate]'))) {
    const it = itemOf(W.item);
    const v = String(($('#wsPlate') || {}).value || '').toUpperCase().replace(/[^A-Z0-9 ]/g, '').trim();
    if (!v || v.length > 8) return toast('Plaque invalide : 1 à 8 caractères (lettres, chiffres, espaces).', false);
    if (v === String(W.d.data.plate).toUpperCase()) return toast('C\'est déjà la plaque du véhicule.', false);
    const spec = { t: 'platetext', v };
    post('wsPreview', { spec }); W.live = false;
    return wsAdd({ code: it.code, name: it.name, kind: it.kind, category: it.category, price: it.price, spec, preview: spec, slot: 'cos:platetext', label: `${it.name} : ${v}` });
  }
  if ((b = e.target.closest('[data-perf]'))) {
    const it = itemOf(b.dataset.perf); if (!it) return;
    const spec = { t: 'perf', mod: it.mod, level: it.level };
    const inCart = W.cart.find((l) => l.slot === `perf:${it.mod}`);
    if (inCart && inCart.code === it.code) { W.cart = W.cart.filter((l) => l !== inCart); wsReapply(); return wsRender(); }
    post('wsPreview', { spec });
    return wsAdd({ code: it.code, name: it.name, kind: 'perf', category: 'perf', price: it.price, preview: spec, slot: `perf:${it.mod}`, label: it.name, current: curPerf(it.mod) });
  }
  if ((b = e.target.closest('[data-svc]'))) {
    const it = itemOf(b.dataset.svc); if (!it) return;
    if (W.cart.find((l) => l.code === it.code)) { W.cart = W.cart.filter((l) => l.code !== it.code); return wsRender(); }
    return wsAdd({ code: it.code, name: it.name, kind: it.kind, category: 'service', price: it.price, slot: `svc:${it.code}`, label: it.name, qty: 1 });
  }
  if ((b = e.target.closest('[data-wdel]'))) { W.cart.splice(Number(b.dataset.wdel), 1); wsReapply(); return wsRender(); }
  if ((b = e.target.closest('[data-ws]'))) {
    const a = b.dataset.ws;
    if (a === 'close') return post('close', { ui: 'workshop' });
    if (a === 'clear') { if (!(await confirmBox('Vider le devis ?', 'Les aperçus sont retirés du véhicule.', 'Vider', true))) return; W.cart = []; post('wsRevert'); return wsRender(); }
    if (a === 'send') {
      const customer = Number(($('#wsCustomer') || {}).value);
      if (!customer) return toast('Choisissez le client.', false);
      W.customer = customer;
      const selfQ = (W.d.data.customers || []).some((c) => c.self && String(c.id) === String(customer));
      if (!(await confirmBox(selfQ ? 'Payer votre devis ?' : 'Envoyer le devis ?', selfQ
        ? `${W.cart.length} ligne(s) · <b>${money(cartTotal())}</b> (prix officiels, recalculés par le serveur).<br>Devis pour vous-même : le montant est prélevé tout de suite (banque puis liquide), puis vous installez. Les pièces non posées sont remboursées.`
        : `${W.cart.length} ligne(s) · <b>${money(cartTotal())}</b> (prix officiels, recalculés par le serveur).<br>Le client consulte le devis et paie sur son écran. Aucune installation n'est possible avant son paiement.`, selfQ ? 'Payer et continuer' : 'Envoyer'))) return;
      W.busy = true; b.classList.add('loading');
      const r = await post('wsSend', { customer, items: W.cart.map((l) => ({ code: l.code, spec: l.kind === 'cosmetic' ? l.spec : undefined, label: l.label, current: l.current, qty: l.qty })) });
      W.busy = false; b.classList.remove('loading');
      if (r.error) return toast(r.error, false);
      W.quote = r.quote; W.result = selfQ ? r.message : null;
      W.d.data.canInstall = true;   // le mécanicien qui envoie le devis peut l'installer
      return wsRender();
    }
    if (a === 'cancelQuote') {
      if (!(await confirmBox('Annuler le devis ?', W.quote.status === 'accepted' ? 'Le client est remboursé (pièces déjà posées facturées).' : 'Le client ne pourra plus l\'accepter.', 'Annuler le devis', true))) return;
      const r = await post('wsCancelQuote', { uid: W.quote.uid });
      if (r.ok) { W.quote = null; W.cart = []; post('wsRevert'); }
      return wsRender();
    }
    if (a === 'install') {
      if (!(await confirmBox('Commencer l\'installation ?', 'L\'atelier se ferme. Une flèche montre chaque point d\'intervention autour du véhicule : placez-vous dessus et appuyez sur <b>E</b> pour le mini-jeu. La pièce est posée à la fin du mini-jeu.<br>Maintenir <b>X</b> : interrompre (reprise possible).', 'Commencer'))) return;
      W.busy = true; b.classList.add('loading');
      const r = await post('wsInstall', { uid: W.quote.uid });
      W.busy = false;
      if (r.error) { b.classList.remove('loading'); return toast(r.error, false); }
      return;
    }
    if (a === 'newQuote') { W.quote = null; W.result = null; W.cart = []; return wsRender(); }
  }
});
$('#workshop').addEventListener('change', (e) => {
  if (e.target.id === 'wsCustomer') W.customer = e.target.value;
  if (e.target.id === 'wsRgbFin') { const it = itemOf(W.item); if (it) livePreview(rgbSpec(it).spec); }
});
$('#workshop').addEventListener('input', (e) => {
  const it = W.d && itemOf(W.item);
  if (!it) return;
  if (e.target.id === 'wsRgb') return livePreview(rgbSpec(it).spec);
  if (e.target.id === 'wsPlate') {
    const v = String(e.target.value || '').toUpperCase().replace(/[^A-Z0-9 ]/g, '').trim();
    if (v && v.length <= 8) return livePreview({ t: 'platetext', v });
    return dropLive();
  }
});

function wsOpen(m) {
  Object.assign(W, { d: m, mode: 'cosmetic', cat: null, item: null, sub: null, opts: null, cart: [], customer: (m.data.customers[0] || {}).id, quote: m.data.quote || null, result: null, live: false, busy: false });
  if (!wsCats('cosmetic').length) W.mode = wsCats('perf').length ? 'perf' : 'service';
  show('#workshop', true); wsRender();
}

/* =====================================================================
   Pendant l'installation : liste des interventions (sans curseur)
   ===================================================================== */
function installRender(m) {
  const el = $('#install');
  if (!m.show) { el.classList.add('hidden'); return; }
  const jobs = m.jobs || [];
  const done = jobs.filter((j) => j.done).length;
  el.innerHTML = `<div class="in-head"><div><div class="eyebrow">Intervention · <span class="mono">${esc(m.plate || '')}</span></div><b>${done}/${jobs.length} étape(s)</b></div>
      <div class="ring" style="--p:${jobs.length ? done / jobs.length : 0}"><span class="mono">${jobs.length ? Math.round(done / jobs.length * 100) : 0}%</span></div></div>
    <div class="in-list">${jobs.map((j) => `<div class="in-job ${j.done ? 'done' : ''} ${j.next ? 'next' : ''} ${m.active === j.key ? 'active' : ''}">
      ${icon(j.done ? 'check' : j.icon, 'ico s')}<div><b>${esc(j.label)}</b><small>${j.lines.map((l) => `${l.failed ? '✗ ' : ''}${esc(l.label)}`).join(' · ')}</small></div></div>`).join('')}</div>
    <div class="in-help"><span class="kbd">E</span> sur le point fléché · <span class="kbd">X</span> maintenu : interrompre</div>`;
  el.classList.remove('hidden');
}

/* =====================================================================
   Client : suivi en direct de son véhicule
   ===================================================================== */
const WATCH = { uid: null, hideT: null };
function watchRender(d) {
  const el = $('#watch');
  if (d.uid && WATCH.uid !== d.uid) Object.assign(WATCH, { uid: d.uid, plate: null, mechanic: null, job: null, progress: 0, installed: 0, count: 0, finished: false, closed: false, paused: false });
  for (const k of ['plate', 'mechanic', 'installed', 'count']) if (d[k] !== undefined && d[k] !== null) WATCH[k] = d[k];
  if (d.job !== undefined) { WATCH.job = d.job; WATCH.progress = d.progress || 0; WATCH.active = d.active; WATCH.paused = false; }
  if (d.line) { WATCH.last = `${d.ok ? '✓' : '✗'} ${d.label}`; }
  if (d.paused) WATCH.paused = true;
  if (d.finished) WATCH.finished = true;
  if (d.closed) WATCH.closed = true;
  clearTimeout(WATCH.hideT);
  const pct = WATCH.count ? Math.round(WATCH.installed / WATCH.count * 100) : 0;
  el.innerHTML = `<div class="eyebrow">${icon('service', 'ico s')} Votre véhicule <span class="mono">${esc(WATCH.plate || '')}</span></div>
    ${WATCH.closed ? '<b class="ok">Clés remises · bonne route !</b>'
      : WATCH.finished ? '<b class="ok">Véhicule prêt : le mécanicien vient vous remettre les clés.</b>'
      : WATCH.paused ? '<b class="warn">Intervention en pause.</b>'
      : `<b>${esc(WATCH.active && WATCH.job ? WATCH.job : 'Intervention en cours')}</b>${WATCH.active ? `<div class="bar"><i style="width:${Math.round((WATCH.progress || 0) * 100)}%"></i></div>` : ''}`}
    <div class="w-foot"><span>${WATCH.installed}/${WATCH.count} pièce(s) posée(s)</span>${WATCH.mechanic ? `<span>${esc(WATCH.mechanic)}</span>` : ''}</div>
    ${WATCH.last && !WATCH.closed ? `<div class="w-last">${esc(WATCH.last)}</div>` : ''}
    <div class="bar total"><i style="width:${WATCH.closed || WATCH.finished ? 100 : pct}%"></i></div>`;
  el.classList.remove('hidden');
  if (WATCH.closed) WATCH.hideT = setTimeout(() => el.classList.add('hidden'), 7000);
}

function handoverRender(m) {
  const el = $('#handover');
  if (!m.show) { el.classList.add('hidden'); return; }
  el.innerHTML = `${icon('key', 'ico')}<div><b>Remettez les clés à ${esc(m.name || 'votre client')}</b><small>${m.done}/${m.total} pièce(s) posée(s) · véhicule <span class="mono">${esc(m.plate || '')}</span> · flèche verte au-dessus du client, puis <span class="kbd">E</span> à côté de lui</small></div>`;
  el.classList.remove('hidden');
}
