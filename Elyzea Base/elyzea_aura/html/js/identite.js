'use strict';
/* =========================================================
   IDENTITÉ — carte d'identité, permis de conduire, PPA
   · Mes cartes : carrousel animé, « Montrer » à un téléphone sorti
     à proximité, « Enregistrer » dans la galerie.
   · Reçues : cartes montrées par les autres ; enregistrables dans
     la galerie (le propriétaire est prévenu).
   · Police en service : suspendre / rétablir un permis (une catégorie
     ou tout) ou le PPA ; la carte reste avec « SUSPENDU ».
   Tout est vérifié par le serveur (elyzea_papiers).
   ========================================================= */
APPS.identite = { label: 'Identité' };
APP_ICONS.identite = { c1: '#C9A6FF', c2: '#6D28D9',
  fill: '<rect x="2.5" y="5" width="19" height="14" rx="3"/>',
  line: '<circle cx="8.5" cy="11" r="2.2"/><path d="M5.5 16a3 3 0 0 1 6 0M14 10h4.5M14 13.5h3"/>' };
GRID.splice(1, 0, 'identite');
NOTIFS.idSaved = { title: 'Identité', text: '{device} a enregistré votre {card}' };
NOTIFS.idShown = { title: 'Identité', text: '{device} vous montre sa carte' };
P.gallery = '<rect x="3" y="4" width="18" height="16" rx="3.5"/><circle cx="9" cy="10" r="1.8"/><path d="m21 16-5-5-9 9"/>';

const Idt = { docs: null, police: false, idx: 0, received: [], photo: null };
const ID_ORDER = [['id', "Carte d'identité"], ['licence', 'Permis de conduire'], ['ppa', "Permis de port d'arme"]];
const nowSec = () => Math.floor(Date.now() / 1000);
const cardW = () => 318;

function idCardHtml(doc, photo, enter = true) {
  return ElyCards.render(Object.assign({ photo, now: nowSec() }, doc), { width: cardW(), enter });
}

Views.identite = async ({ tab = 'mine' } = {}) => {
  frame({ title: t('Identité'), tabs: tabsHtml([['mine', t('Mes cartes')], ['rec', `${t('Reçues')}${Idt.received.length ? ` · ${Idt.received.length}` : ''}`]], tab, 'data-idt'), body: loading() });
  appView.querySelector('.app').classList.add('idt');
  $$('[data-idt]', appView).forEach(b => b.onclick = () => { setParams({ tab: b.dataset.idt }); Views.identite({ tab: b.dataset.idt }); });
  if (tab === 'rec') return idtReceived();
  const [r, ph] = await Promise.all([api('idDocs'), Idt.photo ? Promise.resolve({ url: Idt.photo }) : post('idPhoto')]);
  if (S.currentApp !== 'identite') return;
  Idt.photo = ph?.url || null;
  if (!r || !r.ok) { $('.app__body', appView).innerHTML = empty(t('Papiers indisponibles'), esc(t((r && r.error) || 'Réessayez dans un instant.'))); return; }
  Idt.docs = r.docs || {}; Idt.police = !!r.police;
  idtMine();
};

function idtMine() {
  const body = $('.app__body', appView); if (!body) return;
  const have = ID_ORDER.filter(([k]) => Idt.docs[k]);
  if (!have.length) {
    body.innerHTML = empty(t('Aucun document'), t('Obtenez votre carte d\'identité au guichet du gouvernement, votre permis à l\'auto-école et votre PPA auprès des EMS.'));
    return;
  }
  Idt.idx = Math.min(Idt.idx, have.length - 1);
  body.innerHTML = `<div class="idt-stage" id="idt-stage"></div>
    <div class="idt-dots">${have.map((_, i) => `<button class="idt-dot ${i === Idt.idx ? 'on' : ''}" data-dot="${i}" aria-label="${i + 1}"></button>`).join('')}</div>
    <div class="idt-actions">
      <button class="btn" data-idt-show>${icon('drop')}${t('Montrer')}</button>
      <button class="btn btn--ghost" data-idt-save>${icon('gallery')}${t('Enregistrer')}</button>
    </div>
    <p class="idt-hint">${t('Pour montrer une carte, la personne doit avoir son téléphone sorti, à quelques pas de vous.')}</p>
    ${ID_ORDER.filter(([k]) => !Idt.docs[k]).map(([, l]) => `<p class="idt-missing">${t('Pas de {doc}', { doc: t(l).toLowerCase() })}</p>`).join('')}`;
  const draw = (dir = 0) => {
    const [k, label] = have[Idt.idx];
    const st = $('#idt-stage');
    st.innerHTML = `<p class="section-label idt-label">${t(label)}</p><div class="idt-card ${dir ? (dir > 0 ? 'from-r' : 'from-l') : ''}">${idCardHtml(Idt.docs[k], Idt.photo, !dir)}</div>`;
    $$('.idt-dot', body).forEach((d, i) => d.classList.toggle('on', i === Idt.idx));
    idtTilt($('.ely-card', st));
  };
  draw();
  $$('[data-dot]', body).forEach(b => b.onclick = () => { const n = +b.dataset.dot; const d = n > Idt.idx ? 1 : -1; Idt.idx = n; draw(d); });
  // Glisser pour changer de carte
  let sx = null;
  const st = $('#idt-stage');
  st.addEventListener('pointerdown', (e) => { sx = e.clientX; });
  st.addEventListener('pointerup', (e) => {
    if (sx == null) return; const dx = e.clientX - sx; sx = null;
    if (Math.abs(dx) < 40 || have.length < 2) return;
    Idt.idx = (Idt.idx + (dx < 0 ? 1 : have.length - 1)) % have.length; draw(dx < 0 ? 1 : -1);
  });
  $('[data-idt-show]', body).onclick = () => idtShowSheet(have[Idt.idx][0]);
  $('[data-idt-save]', body).onclick = async () => {
    const res = await api('idSaveOwn', { kind: have[Idt.idx][0] });
    notify({ app: 'identite', title: res.ok ? t('Carte enregistrée') : t('Identité'), text: res.ok ? t('Disponible dans la galerie.') : t(res.error || 'Échec') });
  };
}

// Petit effet 3D au survol (léger : une seule transformation)
function idtTilt(card) {
  if (!card) return;
  card.addEventListener('pointermove', (e) => {
    const r = card.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width - .5, y = (e.clientY - r.top) / r.height - .5;
    card.style.transform = `perspective(700px) rotateY(${x * 10}deg) rotateX(${-y * 8}deg)`;
  });
  card.addEventListener('pointerleave', () => { card.style.transform = ''; });
}

// Choisir à qui montrer la carte : téléphones sortis à proximité
function idtShowSheet(kind) {
  const sh = openSheet(t('Montrer ma carte'), `<p class="sheet__text">${t('Seuls les téléphones sortis, à quelques pas de vous, apparaissent ici.')}</p>
    <div class="radar"><i></i><i></i><i></i><div class="radar__me">${icon('drop')}</div></div><div id="idt-dev">${loading()}</div>`);
  let alive = true;
  sh.addEventListener('sheetclose', () => { alive = false; });
  const scan = async () => {
    if (!alive) return;
    const r = await api('idNearby');
    const box = $('#idt-dev', sh); if (!box) return;
    const list = r.devices || [];
    box.innerHTML = list.length ? `<div class="list">${list.map(d => `<button class="row" data-dev="${d.id}">${avatar(d.device, d.id)}
        <div class="row__main"><div class="row__title">${esc(d.device)}</div><div class="row__sub">${t('{n} m', { n: d.distance })}</div></div>${icon('send')}</button>`).join('')}</div>`
      : `<p class="sheet__text" style="text-align:center">${t('Aucun téléphone sorti à proximité.')}</p>`;
    $$('[data-dev]', box).forEach(b => b.onclick = async () => {
      b.disabled = true;
      const res = await api('idShow', { id: +b.dataset.dev, kind });
      if (!res.ok) { b.disabled = false; notify({ app: 'identite', title: t('Identité'), text: t(res.error || 'Appareil hors de portée') }); return; }
      closeSheet();
      notify({ app: 'identite', title: t('Carte montrée'), text: t('Vous montrez votre carte à {device}', { device: res.device }) });
    });
    setTimeout(scan, 2500);
  };
  scan();
}

// ---------- Cartes reçues ----------
function idtReceived() {
  const body = $('.app__body', appView); if (!body) return;
  if (!Idt.received.length) { body.innerHTML = empty(t('Aucune carte reçue'), t('Quand quelqu\'un vous montre sa carte, elle apparaît ici.')); return; }
  body.innerHTML = Idt.received.map((r, i) => `<div class="idt-rec">
      <p class="section-label">${esc(r.device)} · ${timeAgo(r.ts)}</p>
      <button class="idt-rec__card" data-rec="${i}">${idCardHtml(r.doc, r.photo, false)}</button></div>`).join('');
  $$('[data-rec]', body).forEach(b => b.onclick = () => idtOpenReceived(Idt.received[+b.dataset.rec]));
}

function idtPoliceTools(r) {
  if (!r.police) return '';
  const d = r.doc || {};
  if (r.kind === 'ppa') {
    return `<p class="section-label">${t('Police')}</p><div class="form"><input class="field" id="idt-reason" maxlength="120" placeholder="${t('Motif (facultatif)')}">
      <button class="btn ${d.suspended ? '' : 'btn--danger'} btn--block" data-susp="ppa" data-on="${d.suspended ? 0 : 1}">${d.suspended ? t('Rétablir le PPA') : t('Suspendre le PPA')}</button></div>`;
  }
  if (r.kind === 'licence') {
    const cats = (d.data && d.data.categories) || [];
    const all = cats.length && cats.every(c => c.suspended);
    return `<p class="section-label">${t('Police')}</p><div class="form"><input class="field" id="idt-reason" maxlength="120" placeholder="${t('Motif (facultatif)')}">
      <div class="grid-2">${cats.map(c => `<button class="btn btn--sm ${c.suspended ? '' : 'btn--danger'}" data-susp="${c.key}" data-on="${c.suspended ? 0 : 1}">
        ${c.suspended ? t('Rétablir') : t('Suspendre')} ${esc(c.short)} · ${esc(t(c.label))}</button>`).join('')}</div>
      <button class="btn btn--block ${all ? '' : 'btn--danger'}" data-susp="licence" data-on="${all ? 0 : 1}">${all ? t('Rétablir tout le permis') : t('Suspendre tout le permis')}</button></div>`;
  }
  return '';
}

function idtOpenReceived(r) {
  if (!r) return;
  const sh = openSheet('', `<p class="section-label" style="margin-top:0">${t('{device} vous montre', { device: esc(r.device) })}</p>
    <div class="idt-sheet-card" id="idt-sc">${idCardHtml(r.doc, r.photo)}</div>
    <div class="form" style="margin-top:12px"><button class="btn btn--block" data-save ${r.saved ? 'disabled' : ''}>${icon('gallery')}${r.saved ? t('Enregistrée dans la galerie') : t('Enregistrer dans la galerie')}</button></div>
    <div id="idt-police">${idtPoliceTools(r)}</div>`, (s) => {
    idtTilt($('.ely-card', s));
    const bindPolice = () => $$('[data-susp]', s).forEach(b => b.onclick = async () => {
      b.disabled = true;
      const res = await api('idSuspend', { shareId: r.shareId, what: b.dataset.susp, on: b.dataset.on === '1', reason: $('#idt-reason', s)?.value || '' });
      if (!res.ok) { b.disabled = false; notify({ app: 'identite', title: t('Identité'), text: t(res.error || 'Refusé') }); return; }
      r.doc = res.doc || r.doc;
      $('#idt-sc', s).innerHTML = idCardHtml(r.doc, r.photo);
      $('#idt-police', s).innerHTML = idtPoliceTools(r);
      bindPolice();
      if (S.currentApp === 'identite') idtReceived();
    });
    bindPolice();
    s.querySelector('[data-save]').onclick = async (e) => {
      const btn = e.currentTarget; btn.disabled = true;
      const res = await api('idSave', { shareId: r.shareId });
      if (!res.ok) { notify({ app: 'identite', title: t('Identité'), text: t(res.error || 'Échec') }); if (res.error !== 'Carte déjà enregistrée') btn.disabled = false; return; }
      r.saved = true; btn.innerHTML = `${icon('gallery')}${t('Enregistrée dans la galerie')}`;
    };
  });
  return sh;
}

// Carte reçue (envoyée par le client Lua, via main.js)
function idtOnCard(d) {
  const r = { shareId: d.shareId, doc: d.doc, kind: d.kind, device: d.device, photo: d.photo, police: !!d.police, ts: nowSec() };
  Idt.received.unshift(r);
  Idt.received = Idt.received.slice(0, 15);
  if (S.open && !S.locked) {
    if (S.currentApp === 'identite') Views.identite({ tab: 'rec' });
    idtOpenReceived(r);
  } else {
    notify({ app: 'identite', key: 'idShown', params: { device: d.device } });
  }
}

// ---------- Galerie : vignette d'une carte enregistrée ----------
function galleryCardTile(p) {
  return `<button class="gal-card" data-item="${p.id}" aria-label="${t('Carte')}">${ElyCards.render(Object.assign({ now: nowSec() }, p.card || {}), { width: 150, enter: false })}</button>`;
}
function openGalleryCard(p, filter) {
  openSheet('', `<div class="idt-sheet-card">${ElyCards.render(Object.assign({ now: nowSec() }, p.card || {}), { width: cardW() })}</div>
    <p class="row__sub" style="margin:10px 6px 0">${t('Enregistrée')} ${timeAgo(p.ts)}</p>
    <div class="form" style="margin-top:12px"><button class="btn btn--danger btn--block" data-del>${t('Supprimer')}</button></div>`, (sh) => {
    sh.querySelector('[data-del]').onclick = () => confirmSheet(t('Supprimer cette carte ?'), t('Cette action est définitive.'), t('Supprimer'), async () => {
      await api('deletePhoto', { id: p.id }); Views.gallery({ filter });
    });
  });
}
