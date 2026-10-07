'use strict';
/* =========================================================
   GARAGE — mes véhicules et livraison par un voiturier PNJ
   ========================================================= */
const Gar = { data: null, filter: 'all', active: null, live: null, readyAt: 0, timer: null, pay: null };
const STATE_LABEL = { garage: 'Au garage', out: 'Sorti', impound: 'En fourrière' };
const STATE_COLOR = { garage: '#3FBF8E', out: '#4C8DFF', impound: '#FF6B7A' };

async function modelLabels(list) {
  // les noms des modèles sont traduits par le jeu (côté client)
  if (IS_BROWSER) return list;
  const r = await post('vehicleLabels', { models: list.map(v => v.model) });
  (r.labels || []).forEach((l, i) => { if (list[i]) list[i].name = l; });
  return list;
}

Views.garage = async ({ tab } = {}) => {
  frame({ title: t('Garage'), body: loading() });
  const r = IS_BROWSER ? Mock.garageList() : await api('garageList');
  if (S.currentApp !== 'garage') return;
  if (!r.ok) { $('.app__body', appView).innerHTML = empty(t('Garage indisponible'), t('Le service de garage est désactivé sur ce serveur.')); return; }
  Gar.data = r;
  await modelLabels(r.vehicles);
  if (r.active) { Gar.active = r.active; Gar.readyAt = Date.now() + (r.active.readyIn || 0) * 1000; }
  else if (Gar.active && Gar.live?.stage !== 'delivered') { Gar.active = null; Gar.live = null; }
  tab = tab || (Gar.active ? 'track' : 'list');
  frame({ title: t('Garage'), tabs: tabsHtml([['list', t('Mes véhicules')], ['track', t('Livraison')]], tab, 'data-gt'), body: '' });
  appView.querySelector('.app').classList.add('gar');
  $$('[data-gt]', appView).forEach(b => b.onclick = () => { setParams({ tab: b.dataset.gt }); Views.garage({ tab: b.dataset.gt }); });
  if (tab === 'track') return renderValetTrack();
  renderGarageList();
};

function renderGarageList() {
  const body = $('.app__body', appView);
  const all = Gar.data.vehicles || [];
  const counts = { all: all.length, garage: 0, out: 0, impound: 0 };
  all.forEach(v => counts[v.state] = (counts[v.state] || 0) + 1);
  const list = all.filter(v => Gar.filter === 'all' || v.state === Gar.filter);
  const fmt = (d) => d >= 1000 ? `${(d / 1000).toFixed(1)} km` : `${d} m`;
  body.innerHTML = `
    ${Gar.active ? `<button class="lv-banner gar-banner" data-gotrack>${icon('car')}<span>${t('Un voiturier vous apporte un véhicule. Suivre la livraison')}</span>${icon('chev')}</button>` : ''}
    <div class="chips">${[['all', t('Tous')], ['garage', t('Au garage')], ['out', t('Sortis')], ['impound', t('Fourrière')]].map(([k, l]) =>
      `<button class="${Gar.filter === k ? 'active' : ''}" data-gf="${k}">${l} <span class="chip-n">${counts[k] || 0}</span></button>`).join('')}</div>
    ${list.length ? list.map((v, i) => `<article class="gar-card">
      <div class="gar-card__head"><span class="gar-card__ic" style="--c:${STATE_COLOR[v.state]}">${icon('car')}</span>
        <div class="row__main"><div class="row__title">${esc(v.name || v.model)}</div><div class="row__sub"><span class="gar-plate">${esc(v.plate)}</span></div></div>
        <span class="gar-state" style="--c:${STATE_COLOR[v.state]}">${t(STATE_LABEL[v.state])}</span></div>
      <p class="row__sub row__sub--wrap" style="margin-top:8px">${v.state === 'garage' ? t('Garé à : {g}', { g: esc(v.garage || t('garage')) })
        : v.state === 'out' ? (v.inWorld ? t('Dans la ville, à {d}', { d: fmt(v.distance) }) : t('Sorti, position inconnue')) : t('Récupérez-le à la fourrière.')}</p>
      <div class="gar-stats">
        <span>${icon('wrench')}${t('Moteur')} <b>${v.engine}%</b></span><span>${icon('car')}${t('Carrosserie')} <b>${v.body}%</b></span><span>${icon('drop')}${t('Essence')} <b>${v.fuel}%</b></span></div>
      ${v.state === 'garage' ? `<button class="btn btn--block" data-deliver="${esc(v.plate)}" ${Gar.active ? 'disabled' : ''}>${icon('car')}${t('Me l\'apporter')}, ${money(Gar.data.price)}</button>`
        : v.state === 'out' && v.inWorld ? `<button class="btn btn--ghost btn--block" data-locate="${esc(v.plate)}">${icon('pin')}${t('Localiser sur le GPS')}</button>` : ''}
    </article>`).join('')
      : empty(t('Aucun véhicule'), Gar.filter === 'all' ? t('Les véhicules que vous possédez apparaîtront ici.') : t('Aucun véhicule dans cette catégorie.'))}`;
  $$('[data-gf]', appView).forEach(b => b.onclick = () => { Gar.filter = b.dataset.gf; renderGarageList(); });
  $('[data-gotrack]', appView)?.addEventListener('click', () => { setParams({ tab: 'track' }); Views.garage({ tab: 'track' }); });
  $$('[data-locate]', appView).forEach(b => b.onclick = () => {
    const v = all.find(x => x.plate === b.dataset.locate);
    post('waypointTo', { x: v.x, y: v.y });
    notify({ app: 'maps', title: t('Itinéraire défini'), text: `${v.name || v.model} (${v.plate})` });
  });
  $$('[data-deliver]', appView).forEach(b => b.onclick = () => deliverSheet(all.find(x => x.plate === b.dataset.deliver)));
}

function deliverSheet(v) {
  const c = Gar.data;
  let pay = Gar.pay || (c.pay || ['bank'])[0];
  const draw = (sh) => {
    sh.innerHTML = `<h2 class="sheet__title">${t('Livraison du véhicule')}</h2>
      <div class="list"><div class="row"><span class="gar-card__ic" style="--c:#3FBF8E">${icon('car')}</span>
        <div class="row__main"><div class="row__title">${esc(v.name || v.model)}</div><div class="row__sub">${esc(v.plate)}, ${esc(v.garage || '')}</div></div></div></div>
      <p class="sheet__text" style="margin-top:12px">${t('Un voiturier sort votre véhicule du garage et vous l\'apporte où que vous soyez. Il se gare à côté de vous et vous remet les clés.')}</p>
      ${(c.pay || []).length > 1 && c.cash ? `<div class="seg" style="margin-bottom:12px">${c.pay.map(m => `<button data-pay="${m}" class="${pay === m ? 'active' : ''}">${m === 'cash' ? t('Espèces') : t('Banque')}</button>`).join('')}</div>` : ''}
      <p class="error-text" id="gar-err"></p>
      <button class="btn btn--block" id="gar-go">${t('Me l\'apporter')}, ${money(c.price)}</button>`;
    $$('[data-pay]', sh).forEach(b => b.onclick = () => { pay = Gar.pay = b.dataset.pay; draw(sh); });
    $('#gar-go', sh).onclick = async (e) => {
      e.currentTarget.disabled = true;
      const r = IS_BROWSER ? Mock.garageOrder(v) : await api('garageOrder', { plate: v.plate, pay, label: v.name || v.model });
      if (!r.ok) { $('#gar-err', sh).textContent = t(r.error || 'Demande impossible.'); e.currentTarget.disabled = false; return; }
      Gar.active = Object.assign({ label: v.name || v.model }, r.order); Gar.live = { stage: 'pending' };
      Gar.readyAt = Date.now() + (r.order.readyIn || 15) * 1000;
      closeSheet(true);
      notify({ app: 'garage', title: t('Livraison confirmée'), text: t('Le voiturier sort {vehicle} du garage.', { vehicle: v.name || v.model }) });
      setParams({ tab: 'track' }); Views.garage({ tab: 'track' });
    };
  };
  openSheet('', '', draw).classList.add('gar');
}

/* ---------- Suivi du voiturier ---------- */
function valetStage() {
  const s = Gar.live?.stage;
  if (s === 'delivered' || s === 'arrived') return s;
  if (s === 'enroute' || Gar.active?.status === 'enroute') return 'enroute';
  return 'pending';
}
function renderValetTrack() {
  const body = $('.app__body', appView);
  const a = Gar.active;
  if (!a) {
    body.innerHTML = empty(t('Aucune livraison en cours'), t('Choisissez un véhicule au garage : un voiturier vous l\'apporte.'), `<button class="btn" data-golist>${t('Mes véhicules')}</button>`);
    $('[data-golist]', appView).onclick = () => { setParams({ tab: 'list' }); Views.garage({ tab: 'list' }); };
    return;
  }
  const stage = valetStage();
  const titles = { pending: t('Sortie du véhicule du garage'), enroute: t('Votre véhicule arrive'), arrived: t('Le voiturier est arrivé'), delivered: t('Véhicule livré, bonne route !') };
  const idx = { pending: 0, enroute: 1, arrived: 2, delivered: 3 }[stage];
  body.innerHTML = `<h2 class="lv-status">${titles[stage]}</h2>
    <p class="row__sub row__sub--wrap" id="gar-sub" style="margin:4px 4px 0"></p>
    <div class="radar-map" id="gar-radar">
      <i class="rm-ring" style="--r:33%"></i><i class="rm-ring" style="--r:66%"></i><i class="rm-ring" style="--r:100%"></i>
      <svg class="rm-line" viewBox="0 0 100 100" preserveAspectRatio="none"><line id="gar-line" x1="50" y1="50" x2="50" y2="50"/></svg>
      <span class="rm-north">N</span><span class="rm-me">${icon('user')}</span>
      <span class="rm-car gar-car ${stage === 'pending' || stage === 'delivered' ? 'hidden' : ''}" id="gar-car">${icon('car')}</span>
      <span class="rm-scale" id="gar-scale"></span>
      ${stage === 'pending' ? `<div class="rm-wait"><span class="spinner" style="margin:0 auto 8px"></span>${t('Le voiturier récupère {vehicle}', { vehicle: esc(a.label || a.model) })}</div>` : ''}
    </div>
    <div class="grid-2"><div class="widget" style="min-height:0"><span class="widget__label">${t('Distance')}</span><span class="widget__value" id="gar-dist" style="font-size:20px">--</span></div>
      <div class="widget" style="min-height:0"><span class="widget__label">${t('Arrivée estimée')}</span><span class="widget__value" id="gar-eta" style="font-size:20px">--</span></div></div>
    <div class="lv-steps gar-steps">${[t('Demande reçue'), t('En route'), t('Arrivé'), t('Clés remises')].map((l, i) => `<div class="lv-stepper ${i <= idx ? 'done' : ''} ${i === idx ? 'now' : ''}"><i></i><span>${l}</span></div>`).join('')}</div>
    <div class="list" style="margin-top:12px"><div class="row"><span class="gar-card__ic" style="--c:#4C8DFF">${icon('car')}</span>
      <div class="row__main"><div class="row__title">${esc(a.label || a.model)}</div><div class="row__sub">${esc(a.plate)}</div></div><span class="row__title">${money(a.price)}</span></div></div>
    ${stage === 'pending' ? `<button class="btn btn--danger btn--block" style="margin-top:14px" data-cancel>${t('Annuler la livraison')}</button>`
      : stage === 'delivered' ? `<button class="btn btn--block" style="margin-top:14px" data-done>${t('Terminer')}</button>` : ''}`;
  $('[data-cancel]', appView)?.addEventListener('click', () => confirmSheet(t('Annuler la livraison ?'), t('Vous serez remboursé intégralement et le véhicule reste au garage.'), t('Annuler la livraison'), async () => {
    const r = await api('garageCancel');
    if (r.ok) notify({ app: 'garage', title: t('Livraison annulée'), text: t('{amount} remboursés', { amount: money(r.refund) }) });
    else if (r.error) notify({ app: 'garage', title: t('Garage'), text: t(r.error) });
    if (r.ok) { Gar.active = null; Gar.live = null; }
    Views.garage({ tab: r.ok ? 'list' : 'track' });
  }));
  $('[data-done]', appView)?.addEventListener('click', () => { Gar.active = null; Gar.live = null; setParams({ tab: 'list' }); Views.garage({ tab: 'list' }); });
  updateValetTrack();
  clearInterval(Gar.timer);
  if (stage === 'pending') Gar.timer = setInterval(() => { if (!$('#gar-sub')) return clearInterval(Gar.timer); updateValetTrack(); }, 1000);
}
function updateValetTrack() {
  const live = Gar.live || {}, stage = valetStage();
  const sub = $('#gar-sub'); if (!sub) return;
  if (stage === 'pending') {
    const s = Math.max(0, Math.round((Gar.readyAt - Date.now()) / 1000));
    sub.textContent = s > 0 ? t('Départ du garage dans {s} s', { s }) : t('Le voiturier prend la route…');
    return;
  }
  sub.textContent = stage === 'enroute' ? (live.street ? t('Actuellement sur {street}', { street: live.street }) : t('En route vers vous'))
    : stage === 'arrived' ? t('Il vient vous remettre les clés.') : t('Les clés sont à vous. Bonne route !');
  const dist = live.distance ?? 0;
  const de = $('#gar-dist'), ee = $('#gar-eta');
  if (de) de.textContent = stage === 'enroute' ? (dist >= 1000 ? `${(dist / 1000).toFixed(1)} km` : `${dist} m`) : '—';
  if (ee) ee.textContent = stage === 'enroute' ? (live.eta >= 60 ? t('{n} min', { n: Math.round(live.eta / 60) }) : t('{s} s', { s: live.eta || 0 })) : (stage === 'arrived' ? t('Maintenant') : '—');
  const rel = live.rel || { x: 0, y: 0 };
  const range = Math.max(80, Math.hypot(rel.x, rel.y) * 1.2);
  const px = 50 + (rel.x / range) * 50, py = 50 - (rel.y / range) * 50;
  const car = $('#gar-car'); if (car) { car.style.left = px + '%'; car.style.top = py + '%'; }
  const line = $('#gar-line'); if (line) { line.setAttribute('x2', stage === 'enroute' ? px : 50); line.setAttribute('y2', stage === 'enroute' ? py : 50); }
  const sc = $('#gar-scale'); if (sc) sc.textContent = `${Math.round(range / 3)} m`;
}

function onValetUpdate(d) {
  if (d.stage === 'aborted') {
    Gar.active = null; Gar.live = null;
    if (S.currentApp === 'garage') Views.garage({ tab: 'list' });
    return;
  }
  const prev = valetStage();
  Gar.live = Object.assign({}, Gar.live, d);
  if (Gar.active) Gar.active.status = d.stage === 'delivered' ? 'delivered' : 'enroute';
  if (S.open && S.currentApp === 'garage' && $('#gar-sub')) {
    if (prev !== valetStage()) renderValetTrack(); else updateValetTrack();
  }
}
