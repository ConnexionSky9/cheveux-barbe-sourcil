'use strict';
/* =========================================================
   SANTÉ — grossesse, rendez-vous EMS, maladies et blessures
   · Grossesse : données privées d'elyzea_famille (même affichage
     que l'application Grossesse).
   · Rendez-vous : demande à l'EMS (consultation médicale,
     psychiatrique, prise de sang, suivi de grossesse) et suivi
     de la demande ; elyzea_ems revérifie tout.
   · Ma santé : maladies et blessures connues ou diagnostiquées.
   ========================================================= */
const San = { data: null, tab: 'rdv', type: null, reason: '' };
const SAN_ST = { pending: ['#F5A524', 'En attente'], accepted: ['#2BB673', 'Accepté'], done: ['#8A90A8', 'Terminé'], cancelled: ['#8A90A8', 'Annulé'], expired: ['#FF6B7A', 'Annulé : aucun EMS disponible'] };
const SAN_TYPE = { illness: 'Maladie', injury: 'Blessure', std: 'Infection' };
const sanDate = (ts) => ts ? new Date(ts * 1000).toLocaleString(locale(), { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '';
const sanLeft = (s) => { s = Math.max(0, Math.floor(s)); const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
  return s >= 3600 ? (m ? t('{h} h {m} min', { h, m }) : t('{h} h', { h })) : t('{m} min', { m: Math.max(1, Math.ceil(s / 60)) }); };

Views.sante = async ({ tab } = {}) => {
  San.tab = tab || San.tab || 'rdv';
  frame({ title: t('Santé'), action: `<button class="icon-btn" data-san-maj aria-label="${t('Actualiser')}">${icon('reset')}</button>`, body: loading() });
  $('[data-san-maj]', appView).onclick = () => Views.sante({ tab: San.tab });
  const r = await api('santeHome');
  if (S.currentApp !== 'sante') return;
  if (!r || !r.ok) { $('.app__body', appView).innerHTML = empty(t('Santé indisponible'), esc(t((r && r.error) || 'Réessayez dans un instant.'))); return; }
  San.data = r;
  frame({ title: t('Santé'), action: `<button class="icon-btn" data-san-maj aria-label="${t('Actualiser')}">${icon('reset')}</button>`,
    tabs: tabsHtml([['rdv', t('Rendez-vous')], ['health', t('Ma santé')], ['preg', t('Grossesse')]], San.tab, 'data-san-tab'), body: '' });
  appView.querySelector('.app').classList.add('san', 'gro');
  $('[data-san-maj]', appView).onclick = () => Views.sante({ tab: San.tab });
  $$('[data-san-tab]', appView).forEach(b => b.onclick = () => { San.tab = b.dataset.sanTab; setParams({ tab: San.tab }); Views.sante({ tab: San.tab }); });
  if (San.tab === 'preg') return sanPregnancy();
  if (San.tab === 'health') return sanHealth();
  return sanRdv();
};

/* ---------- Grossesse (même rendu que l'application Grossesse) ---------- */
function sanPregnancy() {
  const g = San.data.grossesse;
  const body = $('.app__body', appView);
  if (!g || !g.ok) {
    body.innerHTML = g && g.indisponible ? empty(t('Suivi indisponible'), t('Le suivi de grossesse n\'est pas disponible sur ce serveur.'))
      : empty(t('Suivi indisponible'), esc(t((g && g.error) || 'Réessayez dans un instant.')));
    return;
  }
  Gro.data = g;
  renderGrossesse();
  if (g.statut === 'en_cours') {
    body.insertAdjacentHTML('beforeend', `<button class="btn btn--ghost btn--block" style="margin-top:14px" data-san-preg-rdv>${icon('clock')}${t('Prendre un rendez-vous de suivi')}</button>`);
    $('[data-san-preg-rdv]', appView).onclick = () => { San.type = 'pregnancy'; San.tab = 'rdv'; setParams({ tab: 'rdv' }); Views.sante({ tab: 'rdv' }); };
  }
}

/* ---------- Rendez-vous ---------- */
function sanRdv() {
  const r = San.data.rdv || {}, body = $('.app__body', appView);
  if (!r.ok) {
    body.innerHTML = empty(t('Rendez-vous indisponibles'), r.indisponible ? t('L\'hôpital ne prend pas de rendez-vous sur ce serveur.') : t('Réessayez dans un instant.'));
    return;
  }
  const list = r.list || [];
  const open = list.filter(a => a.status === 'pending' || a.status === 'accepted');
  const past = list.filter(a => a.status !== 'pending' && a.status !== 'accepted');
  const now = Date.now() / 1000;
  if (!San.type || !r.types.some(x => x.id === San.type)) San.type = (r.types[0] || {}).id || null;
  const row = (a) => {
    const st = SAN_ST[a.status] || ['#8A90A8', a.statusLabel || a.status];
    const sub = a.status === 'pending' ? t('Demandé le {d} · annulé dans {l} si aucun EMS ne l\'accepte', { d: sanDate(a.created), l: sanLeft(a.created + r.expireMinutes * 60 - now) })
      : a.status === 'accepted' ? t('Accepté par {n} le {d}', { n: a.ems || 'un EMS', d: sanDate(a.accepted) })
      : t('Demandé le {d}', { d: sanDate(a.created) });
    return `<div class="row san-rdv">
      <span class="chip-ic" style="--c:${st[0]}">${icon(a.status === 'accepted' ? 'check' : a.status === 'pending' ? 'clock' : 'close')}</span>
      <div class="row__main"><div class="row__title">${esc(a.typeLabel)}</div>
        <div class="row__sub row__sub--wrap"><b style="color:${st[0]}">${esc(t(st[1]))}</b> · ${esc(sub)}</div>
        ${a.reason ? `<div class="row__sub row__sub--wrap">« ${esc(a.reason)} »</div>` : ''}</div>
      ${a.status === 'pending' || a.status === 'accepted' ? `<button class="chip" data-san-cancel="${a.id}">${t('Annuler')}</button>` : ''}</div>`;
  };
  const canAsk = r.enabled && r.types.length && open.length < (r.maxOpen || 2);
  body.innerHTML = `
    ${open.length ? `<p class="section-label">${t('Mes demandes en cours')}</p><div class="list">${open.map(row).join('')}</div>` : ''}
    <p class="section-label">${t('Nouveau rendez-vous')}</p>
    ${!r.enabled ? `<p class="row__sub row__sub--wrap">${t('L\'hôpital ne prend plus de rendez-vous pour le moment.')}</p>`
      : !canAsk ? `<p class="row__sub row__sub--wrap">${t('Vous avez déjà {n} demande(s) en cours : attendez la réponse ou annulez-en une.', { n: open.length })}</p>`
      : `<div class="san-types">${r.types.map(x => `<button class="san-type ${x.id === San.type ? 'active' : ''}" data-san-type="${esc(x.id)}"><span class="san-type__ic">${esc(x.icon || '🩺')}</span><span>${esc(t(x.label))}</span></button>`).join('')}</div>
        <textarea class="field" id="san-reason" rows="3" maxlength="200" placeholder="${t('Motif (facultatif) : symptômes, disponibilités…')}">${esc(San.reason)}</textarea>
        <p class="error-text" id="san-err" style="margin-top:8px"></p>
        <button class="btn btn--block" id="san-ask">${icon('clock')}${t('Demander le rendez-vous')}</button>
        <p class="row__sub row__sub--wrap" style="margin-top:8px;text-align:center">${t('Un EMS en service accepte votre demande : vous recevez une notification. Sans réponse sous {l}, elle est annulée.', { l: sanLeft(r.expireMinutes * 60) })}</p>`}
    ${past.length ? `<p class="section-label">${t('Historique')}</p><div class="list">${past.map(row).join('')}</div>` : ''}`;
  $$('[data-san-type]', appView).forEach(b => b.onclick = () => { San.reason = ($('#san-reason') || {}).value || ''; San.type = b.dataset.sanType; sanRdv(); });
  const ta = $('#san-reason'); if (ta) ta.oninput = () => { San.reason = ta.value; };
  const ask = $('#san-ask');
  if (ask) ask.onclick = async () => {
    ask.disabled = true;
    const x = await api('santeRdvCreate', { type: San.type, reason: San.reason });
    if (S.currentApp !== 'sante') return;
    if (!x || !x.ok) { ask.disabled = false; $('#san-err').textContent = t((x && x.error) || 'Réessayez dans un instant.'); return; }
    San.reason = '';
    notify({ app: 'sante', title: t('Santé'), text: x.message || t('Demande envoyée.') });
    Views.sante({ tab: 'rdv' });
  };
  $$('[data-san-cancel]', appView).forEach(b => b.onclick = async () => {
    b.disabled = true;
    const x = await api('santeRdvCancel', { id: +b.dataset.sanCancel });
    if (S.currentApp !== 'sante') return;
    if (x && x.ok) notify({ app: 'sante', title: t('Santé'), text: x.message || t('Rendez-vous annulé.') });
    Views.sante({ tab: 'rdv' });
  });
}

/* ---------- Ma santé ---------- */
function sanHealth() {
  const h = San.data.health || {}, body = $('.app__body', appView);
  if (!h.ok) { body.innerHTML = empty(t('Informations indisponibles'), t('Réessayez dans un instant.')); return; }
  const now = h.now || Date.now() / 1000;
  const advice = (c) => c.cure === 'splint'
    ? (c.splinted ? t('Attelle posée : évitez de courir.') : t('Allez à l\'hôpital ou appelez les EMS pour une attelle.'))
    : (c.expires ? t('Devrait passer d\'ici {l}. Un EMS peut vous donner un traitement.', { l: sanLeft(c.expires - now) }) : t('Un traitement par un EMS est nécessaire.'));
  body.innerHTML = `
    <p class="section-label">${t('En cours')}</p>
    ${h.current.length ? `<div class="list">${h.current.map(c => `<div class="row san-cond">
      <span class="chip-ic" style="--c:${c.type === 'injury' ? '#F5A524' : '#FF6B7A'}">${icon(c.type === 'injury' ? 'alert' : 'heart')}</span>
      <div class="row__main"><div class="row__title">${esc(c.label)}</div>
        <div class="row__sub row__sub--wrap">${esc(t(SAN_TYPE[c.type] || ''))} · ${t('depuis le {d}', { d: sanDate(c.since) })}</div>
        <div class="row__sub row__sub--wrap">${esc(advice(c))}</div></div></div>`).join('')}</div>`
      : `<div class="san-ok">${icon('check')}<span>${t('Rien à signaler.')}</span></div><p class="row__sub row__sub--wrap" style="text-align:center">${t('Certaines infections ne se voient pas : un examen par un EMS permet de le savoir.')}</p>`}
    ${h.current.length ? `<button class="btn btn--ghost btn--block" style="margin-top:12px" data-san-goto-rdv>${icon('clock')}${t('Prendre rendez-vous à l\'hôpital')}</button>` : ''}
    ${h.past.length ? `<p class="section-label">${t('Antécédents')}</p><div class="list">${h.past.map(c => `<div class="row"><span class="tx-ic">${icon('check')}</span>
      <div class="row__main"><div class="row__title">${esc(c.label)}</div><div class="row__sub">${sanDate(c.since)} → ${c.cured ? sanDate(c.cured) : '—'}${c.curedBy ? ` · ${esc(c.curedBy)}` : ''}</div></div></div>`).join('')}</div>` : ''}`;
  const go = $('[data-san-goto-rdv]', appView);
  if (go) go.onclick = () => { San.tab = 'rdv'; San.type = 'medical'; setParams({ tab: 'rdv' }); Views.sante({ tab: 'rdv' }); };
}
