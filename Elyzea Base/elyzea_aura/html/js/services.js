'use strict';
/* =========================================================
   SERVICES — annuaire de TOUTES les entreprises
   · Liste fournie par le téléphone de service (elyzea_jobphone) :
     restaurants, boîtes, concessions, police, EMS, mécano, Dynasty 8, presse…
   · Ouverte / fermée (décidé par l'entreprise dans son appli « Entreprise »),
     nombre d'employés en service, numéro public.
   · « Appeler » : sonne sur le téléphone de service des employés en service.
   · « Message » : conversation normale dans Messages avec le numéro public ;
     les réponses de l'entreprise y arrivent.
   ========================================================= */
const Svc = { list: null, q: '', filter: 'all' };

// Nom de l'entreprise à la place de son numéro (Messages, Téléphone, écran d'appel)
function svcRemember(list) {
  S.bizNames = S.bizNames || {};
  (list || []).forEach(b => { if (b.number) S.bizNames[b.number] = b.label; });
}
async function svcLoadNames() {
  const r = await api('servicesList');
  if (r && r.ok) svcRemember(r.list);
}

Views.services = async () => {
  const action = `<button class="icon-btn" data-svc-maj aria-label="${t('Actualiser')}">${icon('reset')}</button>`;
  frame({ title: t('Services'), action, body: loading() });
  $('[data-svc-maj]', appView).onclick = () => Views.services();
  const r = await api('servicesList');
  if (S.currentApp !== 'services') return;
  if (!r || !r.ok) { $('.app__body', appView).innerHTML = empty(t('Services indisponibles'), esc(t((r && r.error) || 'Réessayez dans un instant.'))); return; }
  Svc.list = r.list || [];
  svcRemember(Svc.list);
  frame({ title: t('Services'), action,
    tabs: tabsHtml([['all', t('Toutes')], ['open', t('Ouvertes')]], Svc.filter, 'data-svc-tab'),
    body: `<input class="field svc-search" id="svc-q" placeholder="${t('Rechercher une entreprise…')}" value="${esc(Svc.q)}"><div id="svc-list"></div>` });
  appView.querySelector('.app').classList.add('svc');
  $('[data-svc-maj]', appView).onclick = () => Views.services();
  $$('[data-svc-tab]', appView).forEach(b => b.onclick = () => { Svc.filter = b.dataset.svcTab; Views.services(); });
  $('#svc-q').oninput = (e) => { Svc.q = e.target.value; svcRender(); };
  svcRender();
};

function svcRender() {
  const box = $('#svc-list', appView); if (!box) return;
  const q = Svc.q.trim().toLowerCase();
  const list = Svc.list.filter(b => (Svc.filter !== 'open' || b.open)
    && (!q || `${b.label} ${b.jobLabel} ${b.number}`.toLowerCase().includes(q)));
  if (!list.length) {
    box.innerHTML = empty(Svc.filter === 'open' ? t('Aucune entreprise ouverte') : t('Aucune entreprise'),
      Svc.filter === 'open' ? t('Revenez plus tard ou laissez un message.') : t('Aucun résultat.'));
    return;
  }
  const groups = [];
  list.forEach(b => { let g = groups.find(x => x.k === b.jobLabel); if (!g) groups.push(g = { k: b.jobLabel, items: [] }); g.items.push(b); });
  box.innerHTML = groups.map(g => `<p class="section-label">${esc(t(g.k || ''))}</p>
    <div class="svc-cards">${g.items.map(b => `<div class="svc-card ${b.open ? 'is-open' : 'is-closed'}" style="--svc:${esc(b.color || '#7C6CFF')}">
      <div class="svc-card__top"><span class="svc-card__dot"></span>
        <div class="svc-card__main"><div class="svc-card__name">${esc(b.label)}</div>
          <div class="svc-card__sub">${esc(b.number)}${b.onDuty ? ` · ${t('{n} en service', { n: b.onDuty })}` : ''}</div></div>
        <span class="svc-state">${b.disabled ? t('Indisponible') : b.open ? t('Ouverte') : t('Fermée')}</span></div>
      <div class="svc-card__actions">
        <button class="btn btn--sm ${b.open ? '' : 'btn--ghost'}" data-svc-call="${esc(b.number)}">${icon('phone')}${t('Appeler')}</button>
        <button class="btn btn--sm btn--ghost" data-svc-msg="${esc(b.number)}">${icon('messages')}${t('Message')}</button>
      </div></div>`).join('')}</div>`).join('');
  $$('[data-svc-call]', box).forEach(b => b.onclick = () => startCall(b.dataset.svcCall));
  $$('[data-svc-msg]', box).forEach(b => b.onclick = () => openApp('messages', { number: b.dataset.svcMsg }));
}
