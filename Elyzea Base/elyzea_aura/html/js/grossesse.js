'use strict';
/* =========================================================
   GROSSESSE — suivi de grossesse (données de elyzea_famille)
   Privé : le serveur ne renvoie que la grossesse du personnage
   qui consulte. Statut, trimestre, temps écoulé et restant,
   date de début, historique (découverte, examens, trimestres,
   terme, naissance).
   ========================================================= */
const Gro = { data: null };

const groLigne = (ic, titre, valeur) => `<div class="row"><span class="tx-ic">${icon(ic)}</span>
  <div class="row__main"><div class="row__title">${titre}</div></div><span class="gro-val">${esc(valeur)}</span></div>`;

function groHistorique(h) {
  const list = (h || []).slice().reverse();     // le plus récent en premier
  return `<p class="section-label">${t('Historique')}</p>
    ${list.length ? `<div class="list">${list.map(e => `<div class="row gro-ev">
      <span class="tx-ic gro-ev__ic gro-ev__ic--${esc(e.kind || 'evenement')}">${icon(e.kind === 'naissance' ? 'heart' : e.kind === 'examen' ? 'shield' : e.kind === 'test' || e.kind === 'decouverte' ? 'check' : 'clock')}</span>
      <div class="row__main"><div class="row__title">${esc(e.titre)}</div><div class="row__sub row__sub--wrap">${esc(e.description || '')}</div></div>
      <span class="gro-date">${esc(e.date || '')}</span></div>`).join('')}</div>`
      : empty(t('Aucun événement'), t('Les étapes de la grossesse apparaîtront ici.'))}`;
}

function renderGrossesse() {
  const r = Gro.data, body = $('.app__body', appView);
  if (r.statut === 'en_cours') {
    const g = r.grossesse || {};
    const pct = Math.max(0, Math.min(100, Math.round((g.pct || 0) * 100)));
    const jours = (n) => ((g.joursTotal || 0) >= 1 ? ` · ${t('{n} j', { n })}` : '');   // jours : seulement pour une grossesse d'au moins un jour
    const tri = g.terme ? t('Terme atteint') : (g.trimestre === 1 ? t('1er trimestre') : t('{n}e trimestre', { n: g.trimestre }));
    body.innerHTML = `
      <div class="gro-hero">
        <span class="gro-hero__label">${t('Grossesse en cours')}</span>
        <span class="gro-hero__tri">${tri}</span>
        <span class="gro-hero__etape">${esc(g.etape || '')}</span>
        <div class="gauge__top"><span>${t('Progression')}</span><span>${pct} %</span></div>
        <div class="gauge__bar"><i style="width:${pct}%;background:var(--accent)"></i></div>
        <div class="gro-tris">${[1, 2, 3].map(n => `<i class="${g.terme || n < g.trimestre ? 'done' : n === g.trimestre ? 'now' : ''}">${n}</i>`).join('')}</div>
      </div>
      <div class="grid-2" style="margin-top:12px">
        <div class="widget" style="min-height:0"><span class="widget__label">${t('Temps écoulé')}</span><span class="widget__value" style="font-size:17px">${esc(g.ecouleTexte)}${jours(g.joursEcoules)}</span></div>
        <div class="widget" style="min-height:0"><span class="widget__label">${t('Avant l\'accouchement')}</span><span class="widget__value" style="font-size:17px">${g.terme ? t('Terme atteint') : esc(g.avantTermeTexte) + jours(g.joursAvantTerme)}</span></div></div>
      <div class="list" style="margin-top:12px">
        ${groLigne('clock', t('Durée totale'), g.totalTexte)}
        ${g.avantTrimestreTexte ? groLigne('arrowUp', t('Avant le trimestre suivant'), g.avantTrimestreTexte) : ''}
        ${groLigne('pin', t('Début'), g.debutTexte)}
        ${groLigne('heart', t('Bébés'), g.bebes ? (g.bebes === 1 ? t('Un bébé') : g.bebes === 2 ? t('Jumeaux') : t('Triplés')) : t('Examen médical nécessaire'))}
      </div>
      ${groHistorique(r.historique)}`;
  } else if (r.statut === 'terminee') {
    const f = r.fin || {};
    body.innerHTML = `
      <div class="gro-hero">
        <span class="gro-hero__label">${t('Grossesse terminée')}</span>
        <span class="gro-hero__tri">${f.status === 'accouchee' ? t('Accouchement terminé') : t('Grossesse terminée')}</span>
        <span class="gro-hero__etape">${esc(f.date || '')}</span>
      </div>
      <div class="list" style="margin-top:12px">${groLigne('pin', t('Début'), f.debutTexte || '—')}</div>
      ${groHistorique(r.historique)}`;
  } else {
    body.innerHTML = empty(t('Aucune grossesse connue'), t('Un test de grossesse ou un examen médical permet de le savoir.'));
  }
}

Views.grossesse = async () => {
  frame({ title: t('Grossesse'), action: `<button class="icon-btn" data-gro-maj aria-label="${t('Actualiser')}">${icon('reset')}</button>`, body: loading() });
  appView.querySelector('.app').classList.add('gro');
  $('[data-gro-maj]', appView).onclick = () => Views.grossesse();
  const r = await api('grossesseSuivi');
  if (S.currentApp !== 'grossesse') return;
  if (!r || !r.ok) {
    $('.app__body', appView).innerHTML = r && r.indisponible
      ? empty(t('Suivi indisponible'), t('Le suivi de grossesse n\'est pas disponible sur ce serveur.'))
      : empty(t('Suivi indisponible'), esc(t((r && r.error) || 'Réessayez dans un instant.')));
    return;
  }
  Gro.data = r;
  renderGrossesse();
};
