'use strict';
/* =========================================================
   APPLI « MAISON » — logements Dynasty 8 (elyzea_dynasty)
   Visible seulement si le joueur a des droits sur au moins un logement.
   · Accueil : mes logements (nom, adresse, statut, améliorations, équipements), sonnettes en attente
   · Surveillance : caméras en DIRECT (image du jeu dans l'écran), changer de caméra, quitter
   · Services privés : danseuse (animation, durée, venir, changer, renvoyer)
   · Gestion : code de la porte, visiteurs autorisés, locataires et leurs droits, améliorations
   Toutes les actions sont revérifiées par le serveur (droits, achat, limites).
   ========================================================= */
const MZ = { list: null, bells: [], pid: null, prop: null, tab: 'home', cam: null };
const mzCall = (action, data = {}) => api('maisonCall', { action, data });
const MZ_UP = { cameras: ['📹', 'Caméras'], dancer: ['💃', 'Danseuse'], cannabis: ['🌿', 'Culture'] };
const MZ_CAT = { apartment: '🏢', house: '🏠', villa: '🏡', garage: '🚗' };
const MZ_RIGHTS = [['stash', 'Coffre'], ['manage', 'Gestion'], ['garage', 'Garage'], ['code', 'Code et visiteurs'], ['upgrades', 'Améliorations'], ['cameras', 'Caméras'], ['dancer', 'Danseuse']];
const mzDate = (ts) => ts ? new Date(ts * 1000).toLocaleDateString(locale(), { day: '2-digit', month: '2-digit', year: '2-digit' }) : '—';
const mzMin = (s) => `${Math.max(1, Math.ceil((s || 0) / 60))} min`;

function mzToast(r, okMsg) {
  if (!r) return;
  if (r.ok === false || r.error) notify({ app: 'maison', title: 'Maison', text: t(r.error || 'Action impossible.') });
  else if (r.message || okMsg) notify({ app: 'maison', title: 'Maison', text: r.message || okMsg });
}

function mzShell(inner, opts = {}) {
  frame({ title: opts.title || t('Maison'), body: `<div class="mz">${inner}</div>`, back: true,
    action: opts.refresh !== false ? `<button class="icon-btn" data-mz-refresh aria-label="${t('Actualiser')}">${icon('reset')}</button>` : '' });
  $('[data-back]', appView).onclick = () => { if (MZ.pid && opts.inProp) { mzCamStop(); MZ.pid = null; MZ.prop = null; mzHome(); } else back(); };
  const rf = $('[data-mz-refresh]', appView);
  if (rf) rf.onclick = () => (MZ.pid ? mzOpenProp(MZ.pid, MZ.tab) : Views.maison());
  return $('.mz', appView);
}

Views.maison = async () => {
  S.onLeave = mzCamStop;
  MZ.pid = null; MZ.prop = null;
  const main = mzShell(loading());
  const r = await mzCall('home');
  if (S.currentApp !== 'maison') return;
  if (!r || !r.ok) { main.innerHTML = empty(t('Maison indisponible'), esc(t((r && r.error) || 'Réessayez dans un instant.'))); return; }
  MZ.list = r.list || []; MZ.bells = r.bells || [];
  mzHome();
};

/* ---------- Accueil : mes logements + sonnette ---------- */
function mzBells() {
  if (!MZ.bells.length) return '';
  return `<section class="mz-bells">${MZ.bells.map((b) => `<div class="mz-bell" data-bell="${b.id}">
      <div class="mz-bell__ico">🔔</div>
      <div class="mz-bell__tx"><b>${esc(b.visitor)}</b><small>${t('sonne à')} ${esc(b.property)} · ${mzMin(b.left)}</small></div>
      <select class="mz-sel" data-bell-min>${[10, 30, 60, 120].map((m) => `<option value="${m}" ${m === 30 ? 'selected' : ''}>${m} min</option>`).join('')}</select>
      <button class="mz-chip ok" data-bell-yes>${t('Ouvrir')}</button><button class="mz-chip no" data-bell-no>${t('Refuser')}</button></div>`).join('')}</section>`;
}
function mzHome() {
  const list = MZ.list || [];
  const main = mzShell(`${mzBells()}
    <div class="mz-hero"><small>${t('Mes logements')}</small><b>${list.length}</b></div>
    ${list.length ? list.map((h) => `<button class="mz-card" data-prop="${h.id}">
        <div class="mz-card__ico">${MZ_CAT[h.category] || '🏠'}</div>
        <div class="mz-card__main"><b>${esc(h.name)}</b><small>${esc(h.address || '')}</small>
          <div class="mz-tags"><span class="mz-tag ${h.role === 'holder' ? 'gold' : ''}">${h.role === 'holder' ? t('Titulaire') : t('Locataire')}</span>
            <span class="mz-tag">${h.kind === 'rent' ? `${t('Loué jusqu\'au')} ${mzDate(h.ends)}` : t('Propriété')}</span>
            ${h.dancer ? '<span class="mz-tag live">💃 ' + t('en cours') + '</span>' : ''}</div>
          <div class="mz-eq">${(h.upgrades || []).map((u) => `<span title="${esc((MZ_UP[u] || [])[1] || u)}">${(MZ_UP[u] || ['✨'])[0]}</span>`).join('')}
            ${h.garage ? `<span>🚗 ${h.garage}</span>` : ''}${h.stash ? `<span>📦 ${h.stash}</span>` : ''}${h.hasCode ? '<span>🔢</span>' : ''}</div></div>
        <span class="mz-card__go">›</span></button>`).join('') : `<div class="mz-welcome">
          <div class="mz-welcome__ico">🏡</div><b>${t('Bienvenue dans Maison')}</b>
          <p>${t('Achetez ou louez un logement auprès de Dynasty 8 : il apparaîtra ici automatiquement.')}</p>
          <ul><li>📹 ${t('Caméras de surveillance en direct')}</li><li>🔔 ${t('Ouvrir la porte à distance quand on sonne')}</li>
            <li>🔢 ${t('Code de la porte et visiteurs autorisés')}</li><li>👥 ${t('Locataires et leurs droits')}</li><li>💃 ${t('Services privés')}</li></ul></div>`}`);
  mzWireBells(main);
  $$('[data-prop]', main).forEach((b) => b.onclick = () => mzOpenProp(Number(b.dataset.prop), 'home'));
}
function mzWireBells(main) {
  $$('[data-bell]', main).forEach((el) => {
    const id = Number(el.dataset.bell);
    const answer = async (accept) => {
      const r = await mzCall('bellAnswer', { id, accept, minutes: Number($('[data-bell-min]', el).value) });
      mzToast(r);
      MZ.bells = MZ.bells.filter((b) => b.id !== id);
      el.remove();
    };
    $('[data-bell-yes]', el).onclick = () => answer(true);
    $('[data-bell-no]', el).onclick = () => answer(false);
  });
}

/* ---------- Fiche d'un logement ---------- */
async function mzOpenProp(pid, tab) {
  MZ.pid = pid; MZ.tab = tab || MZ.tab || 'home';
  const main = mzShell(loading(), { inProp: true });
  const r = await mzCall('prop', { pid });
  if (S.currentApp !== 'maison' || MZ.pid !== pid) return;
  if (!r || !r.ok) { main.innerHTML = empty(t('Logement indisponible'), esc(t((r && r.error) || ''))); return; }
  MZ.prop = r.prop;
  mzRenderProp();
}
function mzTabs() {
  const p = MZ.prop, r = p.rights || {}, up = (p.upgrades && p.upgrades.list) || [];
  const owned = (k) => up.some((x) => x.kind === k && x.owned);
  const tabs = [['home', t('Aperçu')]];
  if (r.cameras && owned('cameras')) tabs.push(['surv', t('Surveillance')]);
  if (r.dancer && p.upgrades && p.upgrades.dancer) tabs.push(['svc', t('Services')]);
  if (r.code || r.holder || r.manage) tabs.push(['mng', t('Gestion')]);
  if (!tabs.find((x) => x[0] === MZ.tab)) MZ.tab = 'home';
  return tabs;
}
function mzRenderProp() {
  const p = MZ.prop;
  const tabs = mzTabs();
  const head = `<div class="mz-head"><div class="mz-head__ico">${MZ_CAT[p.category] || '🏠'}</div><div><b>${esc(p.name)}</b><small>${esc(p.address || '')} · ${esc(p.catLabel || '')}</small></div></div>
    <div class="mz-tabs">${tabs.map(([k, l]) => `<button class="${MZ.tab === k ? 'on' : ''}" data-mz-tab="${k}">${l}</button>`).join('')}</div>`;
  const body = ({ home: mzOverview, surv: mzSurv, svc: mzSvc, mng: mzManage }[MZ.tab] || mzOverview)();
  const main = mzShell(head + `<div id="mz-body">${body}</div>`, { inProp: true });
  $$('[data-mz-tab]', main).forEach((b) => b.onclick = () => { mzCamStop(); MZ.tab = b.dataset.mzTab; mzRenderProp(); });
  ({ home: mzWireOverview, surv: mzWireSurv, svc: mzWireSvc, mng: mzWireManage }[MZ.tab] || mzWireOverview)(main);
}

/* Aperçu : contrat, équipements, améliorations (achat) */
function mzOverview() {
  const p = MZ.prop, c = p.contract || {}, r = p.rights || {};
  const ups = (p.upgrades && p.upgrades.list) || [];
  return `<div class="mz-grid">
      <div class="mz-stat"><small>${t('Contrat')}</small><b>${c.kind === 'rent' ? t('Location') : t('Propriété')}</b></div>
      <div class="mz-stat"><small>${c.kind === 'rent' ? t('Fin') : t('Depuis')}</small><b>${mzDate(c.kind === 'rent' ? c.ends : c.starts)}</b></div>
      <div class="mz-stat"><small>${t('Garage')}</small><b>${p.garage ? `${p.garage} ${t('places')}` : '—'}</b></div>
      <div class="mz-stat"><small>${t('Coffre')}</small><b>${p.stash ? `${p.stash} ${t('emplacements')}` : '—'}</b></div></div>
    <h3 class="mz-h">${t('Améliorer mon logement')}</h3>
    ${ups.map((u) => `<div class="mz-up ${u.owned ? 'on' : ''}"><span class="mz-up__ico">${(MZ_UP[u.kind] || ['✨'])[0]}</span>
        <div class="mz-up__tx"><b>${esc(u.label)}</b><small>${u.owned ? t('Installée') : u.enabled ? money(u.price) : t('Indisponible')}</small></div>
        ${!u.owned && u.enabled && r.upgrades ? `<button class="mz-chip ok" data-buy="${u.kind}">${t('Acheter')}</button>` : u.owned ? '<span class="mz-ok">✓</span>' : ''}</div>`).join('')}
    ${p.upgrades && p.upgrades.cannabis ? `<p class="mz-note">🌿 ${p.upgrades.cannabis.plants.length} / ${p.upgrades.cannabis.max} ${t('pots')} · ${p.upgrades.cannabis.plants.filter((x) => x.ready).length} ${t('prête(s)')} — ${t('entretien sur place.')}</p>` : ''}
    <div class="mz-row"><button class="btn btn--ghost btn--block" data-gps>📍 ${t('Itinéraire')}</button></div>
    <p class="mz-note">${p.role === 'holder' ? t('Vous êtes titulaire du contrat.') : t('Vous êtes locataire ajouté : vos droits sont fixés par le titulaire.')}</p>`;
}
function mzWireOverview(main) {
  $$('[data-buy]', main).forEach((b) => b.onclick = () => {
    const u = MZ.prop.upgrades.list.find((x) => x.kind === b.dataset.buy);
    openSheet(esc(u.label), `<p class="sheet__text">${t('Prix')} : <b>${money(u.price)}</b></p>
      <div class="form"><button class="btn btn--block" data-pay="bank">${t('Payer par carte')}</button><button class="btn btn--ghost btn--block" data-pay="cash">${t('Payer en espèces')}</button></div>`, (sh) => {
      $$('[data-pay]', sh).forEach((x) => x.onclick = async () => {
        closeSheet();
        const r = await mzCall('buy', { pid: MZ.pid, kind: u.kind, method: x.dataset.pay });
        mzToast(r);
        if (r && r.ok) mzOpenProp(MZ.pid, 'home');
      });
    });
  });
  const g = $('[data-gps]', main);
  if (g) g.onclick = () => { if (MZ.prop.gps) { post('setWaypoint', { x: MZ.prop.gps.x, y: MZ.prop.gps.y }); notify({ app: 'maison', title: 'Maison', text: t('Itinéraire tracé.') }); } };
}

/* Surveillance : caméras en direct */
function mzSurv() {
  const cams = (MZ.prop.upgrades.cameras || {}).list || [];
  const max = (MZ.prop.upgrades.cameras || {}).max || 0;
  return `<div class="mz-live hidden" id="mz-live"><div class="mz-live__vf" id="mz-vf"></div>
      <div class="mz-live__top"><span class="mz-rec">● REC</span><b id="mz-camname"></b></div>
      <div class="mz-live__bar"><button class="mz-round" data-cam-prev>‹</button><button class="mz-round stop" data-cam-quit>■</button><button class="mz-round" data-cam-next>›</button></div></div>
    <h3 class="mz-h">${t('Caméras')} · ${cams.length} / ${max}</h3>
    ${cams.map((c, i) => `<div class="mz-cam" data-cam="${i + 1}"><span class="mz-cam__dot"></span><div class="mz-cam__tx"><b>${esc(c.label)}</b><small>${t('angle')} ${Math.round(c.fov)}°</small></div>
        <button class="mz-chip ok" data-cam-view="${i + 1}">▶ ${t('Direct')}</button><button class="mz-chip" data-cam-ren="${c.id}">✎</button><button class="mz-chip no" data-cam-del="${c.id}">✕</button></div>`).join('') || `<p class="mz-note">${t('Aucune caméra installée.')}</p>`}
    ${cams.length < max ? `<div class="mz-row"><button class="btn btn--block" data-cam-place>➕ ${t('Installer une caméra')}</button></div>
      <p class="mz-note">${t('Placez-vous près du logement : le téléphone se range et vous réglez la caméra avec un aperçu en direct.')}</p>` : ''}`;
}
async function mzCamStart(idx) {
  const r = await mzCall('camView', { pid: MZ.pid });
  if (!r || !r.ok) return mzToast(r);
  const live = $('#mz-live');
  if (!live) return;
  live.classList.remove('hidden');
  const canvas = GameView.start(S.profile?.camera?.flipY);
  canvas.className = 'mz-live__canvas';
  $('#mz-vf').innerHTML = '';
  $('#mz-vf').appendChild(canvas);
  MZ.cam = { view: r, idx };
  await post('maisonCam', { op: 'start', view: r, idx });
  mzCamLabel();
}
function mzCamLabel() { const n = $('#mz-camname'); if (n && MZ.cam) { const c = MZ.cam.view.cams[MZ.cam.idx - 1]; n.textContent = `${c ? c.label : ''} · ${MZ.cam.idx}/${MZ.cam.view.cams.length}`; } }
function mzCamMove(d) {
  if (!MZ.cam) return;
  const n = MZ.cam.view.cams.length;
  MZ.cam.idx = ((MZ.cam.idx - 1 + d + n) % n) + 1;
  post('maisonCam', { op: 'set', idx: MZ.cam.idx });
  mzCamLabel();
}
function mzCamStop() {
  if (!MZ.cam) return;
  MZ.cam = null;
  GameView.stop();
  post('maisonCam', { op: 'stop' });
  const live = $('#mz-live'); if (live) live.classList.add('hidden');
}
function mzWireSurv(main) {
  $$('[data-cam-view]', main).forEach((b) => b.onclick = () => mzCamStart(Number(b.dataset.camView)));
  $('[data-cam-prev]', main).onclick = () => mzCamMove(-1);
  $('[data-cam-next]', main).onclick = () => mzCamMove(1);
  $('[data-cam-quit]', main).onclick = () => mzCamStop();
  $$('[data-cam-del]', main).forEach((b) => b.onclick = () => confirmSheet(t('Retirer la caméra ?'), t('Elle sera démontée.'), t('Retirer'), async () => {
    mzToast(await mzCall('camRemove', { pid: MZ.pid, id: Number(b.dataset.camDel) })); mzOpenProp(MZ.pid, 'surv');
  }));
  $$('[data-cam-ren]', main).forEach((b) => b.onclick = () => openSheet(t('Renommer'), `<div class="form"><input class="field" maxlength="40" id="mz-ren" placeholder="${t('Nom de la caméra')}">
      <button class="btn btn--block" data-ok>${t('Enregistrer')}</button></div>`, (sh) => {
    $('[data-ok]', sh).onclick = async () => { const v = $('#mz-ren', sh).value; closeSheet(); mzToast(await mzCall('camRename', { pid: MZ.pid, id: Number(b.dataset.camRen), label: v })); mzOpenProp(MZ.pid, 'surv'); };
  }));
  const pl = $('[data-cam-place]', main);
  if (pl) pl.onclick = async () => {
    const r = await mzCall('camInfo', { pid: MZ.pid });
    if (!r || !r.ok) return mzToast(r);
    post('maisonPlaceCam', { pid: MZ.pid });
  };
}

/* Services privés : danseuse (3 styles, 3 tarifs ; placée à son arrivée dans le logement) */
function mzSvc() {
  const d = MZ.prop.upgrades.dancer || {};
  const act = d.active;
  MZ.dn = MZ.dn || { style: (d.styles && d.styles[0] || {}).id, tariff: 1, method: 'bank' };
  const dur = (m) => (m >= 60 ? `${m / 60} h` : `${m} min`);
  return `<div class="mz-svc ${act ? 'live' : ''}"><div class="mz-svc__ico">💃</div><div><b>${t('Danseuse privée')}</b>
      <small>${act ? `${esc(act[0].label || '')} · ${t('encore')} ${mzMin(Math.max(...act.map((x) => x.left)))}${act.some((x) => x.placing) ? ' · ' + t('à placer dans le logement') : ''}` : t('Choisissez un style et une durée. À son arrivée, placez-la où vous voulez.')}</small></div></div>
    <p class="mz-h">${t('Style')}</p>
    <div class="mz-pick">${(d.styles || []).map((x) => `<button class="mz-opt ${MZ.dn.style === x.id ? 'on' : ''}" data-dn-style="${x.id}"><b>${esc(x.label)}</b><small>${esc(x.desc || '')}</small></button>`).join('')}</div>
    <p class="mz-h">${t('Durée')}</p>
    <div class="mz-pick">${(d.tariffs || []).map((x) => `<button class="mz-opt ${MZ.dn.tariff === x.i ? 'on' : ''}" data-dn-tariff="${x.i}"><b>${dur(x.minutes)}</b><small>${money(x.price)}</small></button>`).join('')}</div>
    <div class="mz-row two"><select class="field" id="mz-dnpay"><option value="bank" ${MZ.dn.method === 'bank' ? 'selected' : ''}>${t('Carte')}</option><option value="cash" ${MZ.dn.method === 'cash' ? 'selected' : ''}>${t('Espèces')}</option></select>
      <button class="btn" data-dn="start" ${act && act.length >= (d.max || 1) ? 'disabled' : ''}>💃 ${t('Faire venir')}</button></div>
    ${act ? `<div class="mz-row two"><button class="btn btn--ghost" data-dn="style">🔁 ${t('Style choisi')}</button><button class="btn btn--danger" data-dn="stop">■ ${t('Renvoyer')}</button></div>` : ''}`;
}
function mzWireSvc(main) {
  $$('[data-dn-style]', main).forEach((b) => b.onclick = () => { MZ.dn.style = b.dataset.dnStyle; mzRenderProp(); });
  $$('[data-dn-tariff]', main).forEach((b) => b.onclick = () => { MZ.dn.tariff = Number(b.dataset.dnTariff); mzRenderProp(); });
  const pay = $('#mz-dnpay', main); if (pay) pay.onchange = () => { MZ.dn.method = pay.value; };
  $$('[data-dn]', main).forEach((b) => b.onclick = async () => {
    const a = b.dataset.dn;
    const data = { pid: MZ.pid, style: MZ.dn.style, tariff: MZ.dn.tariff, method: MZ.dn.method };
    const r = await mzCall(a === 'start' ? 'dancerStart' : a === 'style' ? 'dancerStyle' : 'dancerStop', data);
    mzToast(r);
    if (r && r.ok) mzOpenProp(MZ.pid, 'svc');
  });
}

/* Gestion à distance : code, visiteurs, locataires */
function mzManage() {
  const p = MZ.prop, r = p.rights || {};
  let h = '';
  if (r.code || r.manage) {
    h += `<h3 class="mz-h">🔢 ${t('Code de la porte')}</h3>
      <div class="mz-row two"><input class="field" id="mz-code" inputmode="numeric" maxlength="${(p.codeLength || {}).max || 8}" placeholder="${p.hasCode ? t('Nouveau code') : t('Aucun code')}" value="${esc(p.code || '')}">
        <button class="btn" data-code="set">${t('Enregistrer')}</button></div>
      ${p.hasCode ? `<button class="btn btn--danger btn--block" data-code="del">${t('Supprimer le code')}</button>` : ''}
      <p class="mz-note">${t('Le code donne seulement l\'entrée (ni coffre, ni gestion).')}</p>`;
  }
  if (r.code || r.holder) {
    h += `<h3 class="mz-h">🚪 ${t('Visiteurs autorisés')}</h3>
      ${(p.grants || []).map((g) => `<div class="mz-person"><div><b>${esc(g.name)}</b><small>${esc(g.kind)} · ${mzMin(g.left)}</small></div><button class="mz-chip no" data-revoke="${g.src}">${t('Retirer')}</button></div>`).join('') || `<p class="mz-note">${t('Personne pour le moment.')}</p>`}
      <div class="mz-row three"><input class="field" id="mz-inv" inputmode="numeric" placeholder="${t('ID du joueur')}"><select class="field" id="mz-invmin">${(p.bellChoices || [10, 30, 60]).map((m) => `<option value="${m}">${m} min</option>`).join('')}</select>
        <button class="btn" data-invite>${t('Autoriser')}</button></div>`;
  }
  if (r.holder) {
    h += `<h3 class="mz-h">👥 ${t('Locataires')}</h3>
      ${(p.tenants || []).map((tn) => `<div class="mz-tenant" data-cid="${esc(tn.cid)}"><div class="mz-tenant__top"><b>${esc(tn.name)}</b><button class="mz-chip no" data-tn-del>${t('Retirer')}</button></div>
          <div class="mz-rights">${MZ_RIGHTS.map(([k, l]) => `<label><input type="checkbox" data-tr="${k}" ${tn[k] ? 'checked' : ''}><span>${t(l)}</span></label>`).join('')}</div></div>`).join('') || `<p class="mz-note">${t('Aucun locataire ajouté.')}</p>`}
      ${(p.near || []).length ? `<div class="mz-row two"><select class="field" id="mz-near">${p.near.map((n) => `<option value="${n.id}">${esc(n.name)} · ID ${n.id}</option>`).join('')}</select><button class="btn" data-tn-add>${t('Ajouter')}</button></div>
        <p class="mz-note">${t('Le nouveau locataire entre sans code ; cochez ensuite ses droits.')}</p>` : `<p class="mz-note">${t('Pour ajouter un locataire, il doit être à moins de 5 m de vous.')}</p>`}`;
  }
  return h || `<p class="mz-note">${t('Aucune gestion autorisée.')}</p>`;
}
function mzWireManage(main) {
  const reload = () => mzOpenProp(MZ.pid, 'mng');
  $$('[data-code]', main).forEach((b) => b.onclick = async () => {
    const r = await mzCall('setCode', { pid: MZ.pid, code: b.dataset.code === 'del' ? '' : $('#mz-code').value });
    mzToast(r); if (r && r.ok) reload();
  });
  $$('[data-revoke]', main).forEach((b) => b.onclick = async () => { mzToast(await mzCall('grantRevoke', { pid: MZ.pid, target: Number(b.dataset.revoke) })); reload(); });
  const inv = $('[data-invite]', main);
  if (inv) inv.onclick = async () => { const r = await mzCall('grantInvite', { pid: MZ.pid, target: Number($('#mz-inv').value), minutes: Number($('#mz-invmin').value) }); mzToast(r); if (r && r.ok) reload(); };
  $$('.mz-tenant', main).forEach((el) => {
    const cid = el.dataset.cid;
    $$('[data-tr]', el).forEach((x) => x.onchange = async () => {
      const data = { pid: MZ.pid, cid };
      $$('[data-tr]', el).forEach((y) => { data[y.dataset.tr] = y.checked; });
      mzToast(await mzCall('tenantSet', data));
    });
    $('[data-tn-del]', el).onclick = () => confirmSheet(t('Retirer ce locataire ?'), t('Il ne pourra plus entrer sans code.'), t('Retirer'), async () => { mzToast(await mzCall('tenantSet', { pid: MZ.pid, cid, remove: true })); reload(); });
  });
  const add = $('[data-tn-add]', main);
  if (add) add.onclick = async () => { const r = await mzCall('tenantAdd', { pid: MZ.pid, target: Number($('#mz-near').value) }); mzToast(r); if (r && r.ok) reload(); };
}

/* Icône visible seulement avec un logement : vérifié à chaque ouverture du téléphone */
function mzCheckHas() {
  return api('maisonHas').then((r) => {
    const has = !!(r && r.has);
    if (has !== !!S.maisonHas) { S.maisonHas = has; if (!S.currentApp && !S.locked && typeof renderHome === 'function') renderHome(); }
  }).catch(() => {});
}
