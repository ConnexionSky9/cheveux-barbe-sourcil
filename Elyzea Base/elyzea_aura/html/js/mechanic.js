'use strict';
/* =========================================================
   HELPMÉCANO — dépannage par un mécanicien PNJ
   ========================================================= */
const Mecha = { info: null, vehicle: null, selected: null, active: null, live: null, readyAt: 0, timer: null };
const SERVICE_ICON = { clean: 'sparkle', repair: 'wrench', flip: 'reset', full: 'star' };
const STEP_LABEL = { clean: 'Nettoyage en cours', repair: 'Réparation en cours', flip: 'Remise sur roues en cours' };

Views.helpmecano = async ({ tab } = {}) => {
  frame({ title: 'HelpMécano', body: loading() });
  const r = await api('mechanicInfo');
  if (S.currentApp !== 'helpmecano') return;
  if (!r.ok) { $('.app__body', appView).innerHTML = empty(t('Dépannage indisponible'), t('Le service de dépannage est désactivé sur ce serveur.')); return; }
  Mecha.info = r;
  if (r.active) { Mecha.active = r.active; Mecha.readyAt = Date.now() + (r.active.readyIn || 0) * 1000; }
  else if (Mecha.active && Mecha.live?.stage !== 'done') { Mecha.active = null; Mecha.live = null; }
  tab = tab || (Mecha.active ? 'track' : 'request');
  frame({ title: 'HelpMécano', tabs: tabsHtml([['request', t('Dépannage')], ['track', t('Suivi')], ['history', t('Historique')]], tab, 'data-mt'), body: '' });
  appView.querySelector('.app').classList.add('hm');
  $$('[data-mt]', appView).forEach(b => b.onclick = () => { setParams({ tab: b.dataset.mt }); Views.helpmecano({ tab: b.dataset.mt }); });
  if (tab === 'request') return renderMechRequest();
  if (tab === 'track') return renderMechTrack();
  return renderMechHistory();
};

/* ---------- Diagnostic & choix du service ---------- */
function gauge(label, value, warn) {
  const v = Math.max(0, Math.min(100, value));
  const color = v >= 80 ? 'var(--ok)' : v >= 45 ? 'var(--ambre)' : 'var(--danger)';
  return `<div class="gauge"><div class="gauge__top"><span>${label}</span><b style="color:${color}">${v}%</b></div>
    <div class="gauge__bar"><i style="width:${v}%;background:${color}"></i></div>${warn ? `<p class="gauge__warn">${warn}</p>` : ''}</div>`;
}
function recommended(v) {
  if (!v) return null;
  const needs = [v.upside, v.engine < 90 || v.body < 90, v.clean < 60].filter(Boolean).length;
  if (needs >= 2) return 'full';
  if (v.upside) return 'flip';
  if (v.engine < 90 || v.body < 90) return 'repair';
  if (v.clean < 60) return 'clean';
  return null;
}
async function renderMechRequest() {
  const body = $('.app__body', appView);
  if (Mecha.active) {
    body.innerHTML = `<button class="lv-banner hm-banner" data-gotrack>${icon('car')}<span>${t('Une dépanneuse est en route. Suivre l\'intervention')}</span>${icon('chev')}</button>`;
    $('[data-gotrack]', appView).onclick = () => { setParams({ tab: 'track' }); Views.helpmecano({ tab: 'track' }); };
    return;
  }
  if (Mecha.info.blocked) {
    body.innerHTML = empty(t('Mécaniciens en service'), t('Des mécaniciens sont en service : contactez-les via l\'app Urgences'), `<button class="btn" data-open="alert">${t('Ouvrir Urgences')}</button>`);
    return;
  }
  body.innerHTML = `<p class="section-label">${t('Mes véhicules sortis')}</p><div id="hm-list">${loading()}</div><div id="hm-car-detail"></div><div id="hm-services"></div>`;
  const r = IS_BROWSER ? Mock.mechVehicles() : await post('mechanicVehicles');
  if (S.currentApp !== 'helpmecano') return;
  Mecha.vehicles = r.vehicles || [];
  Mecha.maxDistance = r.maxDistance || 300;
  if (!Mecha.vehicles.length) {
    $('#hm-list').innerHTML = `<div class="empty" style="padding:26px 10px"><strong>${t('Aucun véhicule sorti')}</strong>${t('Sortez un véhicule du garage ou approchez-vous d\'un véhicule, puis actualisez.')}
      <button class="btn" style="margin-top:14px" data-redetect>${icon('reset')}${t('Actualiser')}</button></div>`;
    $('[data-redetect]', appView).onclick = renderMechRequest;
    return;
  }
  const reachable = (v) => v.distance <= Mecha.maxDistance;
  if (Mecha.pick === undefined || !Mecha.vehicles[Mecha.pick] || !reachable(Mecha.vehicles[Mecha.pick])) {
    Mecha.pick = Mecha.vehicles.findIndex(reachable);
  }
  const fmt = (d) => d >= 1000 ? `${(d / 1000).toFixed(1)} km` : `${d} m`;
  $('#hm-list').innerHTML = `<div class="list">${Mecha.vehicles.map((v, i) => {
    const ok = reachable(v);
    return `<div class="row hm-veh ${i === Mecha.pick ? 'active' : ''} ${ok ? '' : 'disabled'}" data-veh="${i}" role="button" tabindex="0">
      <span class="chip-ic" style="--c:${ok ? '#F2711C' : '#8A90A8'}">${icon('car')}</span>
      <div class="row__main"><div class="row__title">${esc(v.name)} ${v.borrowed ? `<em class="hm-tag">${t('À proximité')}</em>` : ''}${v.upside ? `<em class="hm-tag hm-tag--warn">${t('Retourné')}</em>` : ''}</div>
        <div class="row__sub">${esc(v.plate)}, ${ok ? t('à {d}', { d: fmt(v.distance) }) : t('trop loin ({d})', { d: fmt(v.distance) })}</div></div>
      ${ok ? `<span class="hm-radio"></span>` : (v.x ? `<button class="chip" data-locate="${i}">${t('Localiser')}</button>` : '')}</div>`;
  }).join('')}</div>
    <button class="link-btn" data-redetect style="width:100%">${icon('reset')} ${t('Actualiser')}</button>`;
  $('[data-redetect]', appView).onclick = renderMechRequest;
  $$('[data-veh]', appView).forEach(el => el.onclick = (e) => {
    if (e.target.closest('[data-locate]')) return;
    const i = +el.dataset.veh;
    if (!reachable(Mecha.vehicles[i])) return;
    Mecha.pick = i; renderMechRequest();
  });
  $$('[data-locate]', appView).forEach(b => b.onclick = () => {
    const v = Mecha.vehicles[+b.dataset.locate];
    post('waypointTo', { x: v.x, y: v.y });
    notify({ app: 'maps', title: t('Itinéraire défini'), text: `${v.name} (${v.plate})` });
  });
  if (Mecha.pick < 0) {
    $('#hm-car-detail').innerHTML = `<p class="row__sub row__sub--wrap" style="text-align:center;margin:14px 10px">${t('Vos véhicules sont trop loin. Rapprochez-vous à moins de {d} m pour appeler une dépanneuse.', { d: Math.round(Mecha.maxDistance) })}</p>`;
    return;
  }
  const v = Mecha.vehicles[Mecha.pick];
  Mecha.vehicle = v;
  const rec = recommended(v);
  if (!Mecha.selected || !Mecha.info.services.some(s => s.id === Mecha.selected)) Mecha.selected = rec || 'repair';
  $('#hm-car-detail').innerHTML = `<p class="section-label">${t('État de {name}', { name: esc(v.name) })}</p>
    <div class="hm-car">${v.upside ? `<p class="hm-alert">${icon('alert')}${t('Votre véhicule est retourné')}</p>` : ''}
      ${gauge(t('Moteur'), v.engine)}${gauge(t('Carrosserie'), v.body)}${gauge(t('Propreté'), v.clean)}</div>`;
  drawServices(rec);
}
function drawServices(rec) {
  const c = Mecha.info;
  const svc = c.services.find(s => s.id === Mecha.selected);
  let pay = Mecha.pay || (c.pay || ['bank'])[0];
  $('#hm-services').innerHTML = `<p class="section-label">${t('Choisissez un service')}</p>
    <div class="hm-services">${c.services.map(s => `<button class="hm-service ${s.id === Mecha.selected ? 'active' : ''}" data-svc="${s.id}">
      <span class="hm-service__ic">${icon(SERVICE_ICON[s.id] || 'wrench')}</span>
      <span class="row__main"><span class="row__title">${esc(t(s.label))}${s.id === rec ? `<em class="hm-rec">${t('Recommandé')}</em>` : ''}</span>
      <span class="row__sub row__sub--wrap">${esc(t(s.desc))}</span><span class="row__sub">${t('Intervention : {n} s', { n: s.duration })}</span></span>
      <b class="hm-service__price">${money(s.price)}</b></button>`).join('')}</div>
    ${(c.pay || []).length > 1 && c.cash ? `<p class="section-label">${t('Paiement')}</p>
      <div class="seg" id="hm-pay">${c.pay.map(m => `<button data-pay="${m}" class="${pay === m ? 'active' : ''}">${m === 'cash' ? t('Espèces') : t('Banque')}</button>`).join('')}</div>` : ''}
    <p class="error-text" id="hm-err" style="margin-top:10px"></p>
    <button class="btn btn--block" id="hm-order">${icon('car')}${t('Appeler la dépanneuse')}, ${money(svc?.price || 0)}</button>`;
  $$('[data-svc]', appView).forEach(b => b.onclick = () => { Mecha.selected = b.dataset.svc; drawServices(rec); });
  $$('[data-pay]', appView).forEach(b => b.onclick = () => { Mecha.pay = b.dataset.pay; drawServices(rec); });
  $('#hm-order').onclick = async (e) => {
    e.currentTarget.disabled = true;
    const v = Mecha.vehicle;
    const r = await api('mechanicOrder', { service: Mecha.selected, pay, netId: v.netId, vehicle: v.name, plate: v.plate });
    if (!r.ok) { $('#hm-err').textContent = t(r.error || 'Demande impossible.'); e.currentTarget.disabled = false; return; }
    Mecha.active = r.job; Mecha.live = { stage: 'pending' };
    Mecha.readyAt = Date.now() + (r.job.readyIn || 10) * 1000;
    notify({ app: 'helpmecano', title: t('Demande envoyée'), text: t('Une dépanneuse va partir de {garage}', { garage: r.job.garage }) });
    setParams({ tab: 'track' }); Views.helpmecano({ tab: 'track' });
  };
}

/* ---------- Suivi ---------- */
function mechStage() {
  const s = Mecha.live?.stage;
  if (s === 'done') return 'done';
  if (s === 'working') return 'working';
  if (s === 'arrived') return 'arrived';
  if (s === 'enroute' || Mecha.active?.status === 'enroute') return 'enroute';
  if (Mecha.active?.status === 'working') return 'working';
  return 'pending';
}
function renderMechTrack() {
  const body = $('.app__body', appView);
  const a = Mecha.active;
  if (!a) {
    body.innerHTML = empty(t('Aucune intervention en cours'), t('Une panne, un accident, une voiture sale ? Un mécanicien vient à vous.'), `<button class="btn" data-goreq>${t('Demander un dépannage')}</button>`);
    $('[data-goreq]', appView).onclick = () => { setParams({ tab: 'request' }); Views.helpmecano({ tab: 'request' }); };
    return;
  }
  const stage = mechStage();
  const titles = {
    pending: t('Préparation de la dépanneuse'),
    enroute: t('La dépanneuse est en route'),
    arrived: t('Le mécanicien est arrivé'),
    working: t('Intervention en cours'),
    done: t('Votre véhicule est comme neuf !'),
  };
  const idx = { pending: 0, enroute: 1, arrived: 1, working: 2, done: 3 }[stage];
  body.innerHTML = `
    <h2 class="lv-status">${titles[stage]}</h2>
    <p class="row__sub row__sub--wrap" id="hm-sub" style="margin:4px 4px 0"></p>
    ${stage === 'working' || stage === 'done' ? `<div class="hm-work">
        <div class="hm-work__ic">${icon(SERVICE_ICON[Mecha.live?.step] || SERVICE_ICON[a.service] || 'wrench')}</div>
        <p class="row__title" id="hm-step">${stage === 'done' ? esc(t(a.label)) : esc(t(STEP_LABEL[Mecha.live?.step] || 'Intervention en cours'))}</p>
        <div class="gauge__bar" style="margin-top:12px"><i id="hm-progress" style="width:${stage === 'done' ? 100 : (Mecha.live?.progress || 0)}%;background:#F2711C"></i></div>
        <p class="row__sub" id="hm-pct" style="margin-top:6px">${stage === 'done' ? '100 %' : `${Mecha.live?.progress || 0} %`}</p></div>`
      : `<div class="radar-map" id="hm-radar">
        <i class="rm-ring" style="--r:33%"></i><i class="rm-ring" style="--r:66%"></i><i class="rm-ring" style="--r:100%"></i>
        <svg class="rm-line" viewBox="0 0 100 100" preserveAspectRatio="none"><line id="hm-line" x1="50" y1="50" x2="50" y2="50"/></svg>
        <span class="rm-north">N</span><span class="rm-me">${icon('user')}</span>
        <span class="rm-car hm-truck ${stage === 'pending' ? 'hidden' : ''}" id="hm-truck">${icon('wrench')}</span>
        <span class="rm-scale" id="hm-scale"></span>
        ${stage === 'pending' ? `<div class="rm-wait"><span class="spinner" style="margin:0 auto 8px"></span>${t('Départ depuis {garage}', { garage: esc(a.garage) })}</div>` : ''}
      </div>
      <div class="grid-2"><div class="widget" style="min-height:0"><span class="widget__label">${t('Distance')}</span><span class="widget__value" id="hm-dist" style="font-size:20px">--</span></div>
        <div class="widget" style="min-height:0"><span class="widget__label">${t('Arrivée estimée')}</span><span class="widget__value" id="hm-eta" style="font-size:20px">--</span></div></div>`}
    <div class="lv-steps hm-steps">${[t('Demande reçue'), t('En route'), t('Intervention'), t('Terminé')].map((l, i) => `<div class="lv-stepper ${i <= idx ? 'done' : ''} ${i === idx ? 'now' : ''}"><i></i><span>${l}</span></div>`).join('')}</div>
    <div class="list" style="margin-top:12px">
      <div class="row"><span class="chip-ic" style="--c:#F2711C">${icon(SERVICE_ICON[a.service] || 'wrench')}</span><div class="row__main"><div class="row__title">${esc(t(a.label))}</div><div class="row__sub">${esc(a.vehicle)}${a.plate ? ', ' + esc(a.plate) : ''}</div></div><span class="row__title">${money(a.price)}</span></div></div>
    ${stage === 'done' ? `<button class="btn btn--block" style="margin-top:14px" data-again>${t('Terminer')}</button>`
      : stage === 'pending' || stage === 'enroute' ? `<button class="btn btn--danger btn--block" style="margin-top:14px" data-cancel>${t('Annuler l\'intervention')}</button>` : ''}
    <p class="row__sub row__sub--wrap" style="text-align:center;margin-top:12px">${t('Restez près de votre véhicule : le mécanicien le rejoint là où il se trouve.')}</p>`;
  $('[data-cancel]', appView)?.addEventListener('click', () => confirmSheet(t('Annuler l\'intervention ?'),
    stage === 'pending' ? t('Vous serez remboursé intégralement.') : t('La dépanneuse est déjà partie : 20 % du prix sont retenus pour le déplacement.'),
    t('Annuler l\'intervention'), async () => {
      const r = await api('mechanicCancel');
      if (r.ok) notify({ app: 'helpmecano', title: t('Intervention annulée'), text: t('{amount} remboursés', { amount: money(r.refund) }) });
      else if (r.error) notify({ app: 'helpmecano', title: 'HelpMécano', text: t(r.error) });
      if (r.ok) { Mecha.active = null; Mecha.live = null; }
      Views.helpmecano({ tab: r.ok ? 'request' : 'track' });
    }));
  $('[data-again]', appView)?.addEventListener('click', () => { Mecha.active = null; Mecha.live = null; setParams({ tab: 'request' }); Views.helpmecano({ tab: 'request' }); });
  updateMechTrack();
  clearInterval(Mecha.timer);
  if (stage === 'pending') Mecha.timer = setInterval(() => { if (!$('#hm-sub')) return clearInterval(Mecha.timer); updateMechTrack(); }, 1000);
}
function updateMechTrack() {
  const live = Mecha.live || {}, stage = mechStage();
  const sub = $('#hm-sub'); if (!sub) return;
  if (stage === 'pending') {
    const s = Math.max(0, Math.round((Mecha.readyAt - Date.now()) / 1000));
    sub.textContent = s > 0 ? t('Départ de {garage} dans {s} s', { garage: Mecha.active.garage, s }) : t('La dépanneuse prend la route…');
    return;
  }
  if (stage === 'enroute') sub.textContent = live.street ? t('Actuellement sur {street}', { street: live.street }) : t('Partie de {garage}', { garage: live.garage || Mecha.active.garage });
  if (stage === 'arrived') sub.textContent = t('Il se dirige vers votre véhicule.');
  if (stage === 'working') sub.textContent = t('Le mécanicien s\'occupe de votre véhicule.');
  if (stage === 'done') sub.textContent = t('Merci d\'avoir fait appel à HelpMécano.');
  if (stage === 'working' || stage === 'done') {
    const pct = stage === 'done' ? 100 : (live.progress || 0);
    const bar = $('#hm-progress'); if (bar) bar.style.width = pct + '%';
    const p = $('#hm-pct'); if (p) p.textContent = `${pct} %`;
    const st = $('#hm-step'); if (st && stage === 'working') st.textContent = t(STEP_LABEL[live.step] || 'Intervention en cours');
    return;
  }
  const dist = live.distance ?? 0;
  const de = $('#hm-dist'), ee = $('#hm-eta');
  if (de) de.textContent = stage === 'enroute' ? (dist >= 1000 ? `${(dist / 1000).toFixed(1)} km` : `${dist} m`) : '—';
  if (ee) ee.textContent = stage === 'enroute' ? (live.eta >= 60 ? t('{n} min', { n: Math.round(live.eta / 60) }) : t('{s} s', { s: live.eta || 0 })) : (stage === 'arrived' ? t('Maintenant') : '—');
  const rel = live.rel || { x: 0, y: 0 };
  const range = Math.max(80, Math.hypot(rel.x, rel.y) * 1.2);
  const px = 50 + (rel.x / range) * 50, py = 50 - (rel.y / range) * 50;
  const tr = $('#hm-truck'); if (tr) { tr.style.left = px + '%'; tr.style.top = py + '%'; }
  const line = $('#hm-line'); if (line) { line.setAttribute('x2', px); line.setAttribute('y2', py); }
  const sc = $('#hm-scale'); if (sc) sc.textContent = `${Math.round(range / 3)} m`;
}

/* ---------- Historique ---------- */
async function renderMechHistory() {
  const body = $('.app__body', appView);
  body.innerHTML = loading();
  const r = await api('mechanicHistory');
  if (S.currentApp !== 'helpmecano') return;
  const jobs = r.jobs || [];
  const label = { done: t('Terminé'), cancelled: t('Annulée'), refunded: t('Remboursée'), pending: t('En attente'), enroute: t('En route'), working: t('Intervention') };
  body.innerHTML = jobs.length ? `<div class="list">${jobs.map(j => `<div class="row"><span class="chip-ic" style="--c:${j.status === 'done' ? '#F2711C' : '#8A90A8'}">${icon(SERVICE_ICON[j.service] || 'wrench')}</span>
    <div class="row__main"><div class="row__title">${esc(t(j.label))}, ${esc(j.vehicle || '')}</div>
    <div class="row__sub">${esc(j.garage)}, ${label[j.status] || j.status}, ${timeAgo(j.ts)}</div></div><span class="row__title">${money(j.price)}</span></div>`).join('')}</div>`
    : empty(t('Aucune intervention'), t('Vos dépannages passés apparaîtront ici.'));
}

// Mises à jour envoyées par le jeu pendant l'intervention
function onMechanicUpdate(d) {
  if (d.stage === 'aborted') {
    Mecha.active = null; Mecha.live = null;
    if (S.currentApp === 'helpmecano') Views.helpmecano({ tab: 'request' });
    return;
  }
  const prev = mechStage();
  Mecha.live = Object.assign({}, Mecha.live, d);
  if (Mecha.active) Mecha.active.status = d.stage === 'done' ? 'done' : d.stage === 'working' ? 'working' : 'enroute';
  if (S.open && S.currentApp === 'helpmecano' && $('#hm-sub')) {
    if (prev !== mechStage()) renderMechTrack(); else updateMechTrack();
  }
}
