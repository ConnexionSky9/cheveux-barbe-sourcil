/* BLACKPHONE - application Grossesse (données de elyzea_famille, privées : seule la personne concernée les voit)
   Statut, trimestre, temps écoulé, durée totale, temps avant le trimestre suivant et avant l'accouchement, historique. */
(() => {
  const P = window.BPPhone;
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'blackphone';
  const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const ICONE = '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
    + '<circle cx="12" cy="5" r="2.4"/><path d="M10 8.5c-1.6.8-2.6 2.6-2.6 4.6 0 1.6.6 2.9 1.6 3.8L9 21"/><path d="M14 8.5c.6.6 1 1.4 1 2.3"/>'
    + '<path d="M11 11.5c2.8-.6 5.6 1 5.6 3.8 0 2.2-1.9 3.7-4.4 3.7H9.4"/></svg>';

  const charger = () => fetch(`https://${RES}/famille_grossesse`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
    .then((r) => r.json()).catch(() => ({ erreur: 'Le téléphone n\'a pas de réseau.' }));
  const ligne = (k, v) => `<div class="row"><span class="lb">${esc(k)}</span><span class="vl">${esc(v)}</span></div>`;

  function vue(el, r) {
    if (!r || r.erreur || r.indisponible) {
      el.innerHTML = `<div class="group"><h3>Grossesse</h3><div class="row"><span class="lb">${esc((r && r.erreur) || 'Service indisponible.')}</span></div></div>`;
      return;
    }
    const histo = (r.historique || []).slice().reverse();
    const blocHisto = `<div class="group"><h3>Historique</h3>${histo.length ? histo.map((e) => `<div class="row" style="align-items:flex-start">
        <span class="lb"><b>${esc(e.titre)}</b><br><small style="opacity:.7">${esc(e.description || '')}</small></span>
        <span class="vl" style="white-space:nowrap">${esc(e.date || '')}</span></div>`).join('') : '<div class="row"><span class="lb">Aucun événement.</span></div>'}</div>`;
    if (r.statut === 'en_cours') {
      const g = r.grossesse || {};
      const pct = Math.round((g.pct || 0) * 100);
      el.innerHTML = `<div class="group"><h3>Grossesse en cours</h3>
          <div class="row"><span class="lb"><b>${g.terme ? 'Terme atteint' : `${g.trimestre}${g.trimestre === 1 ? 'er' : 'e'} trimestre`}</b></span><span class="vl">${esc(g.etape || '')}</span></div>
          <div class="row"><div style="flex:1;height:6px;border-radius:3px;background:rgba(255,255,255,.12);overflow:hidden">
            <div style="width:${pct}%;height:100%;background:#b3161b"></div></div><span class="vl" style="margin-left:8px">${pct} %</span></div>
          ${ligne('Temps écoulé', `${g.ecouleTexte} · ${g.joursEcoules} j`)}
          ${ligne('Durée totale', g.totalTexte)}
          ${g.avantTrimestreTexte ? ligne('Avant le trimestre suivant', g.avantTrimestreTexte) : ''}
          ${ligne('Avant l\'accouchement', g.terme ? 'terme atteint' : `${g.avantTermeTexte} · ${g.joursAvantTerme} j`)}
          ${ligne('Début (calendrier du serveur)', g.debutTexte)}
          ${ligne('Bébés', g.bebes ? (g.bebes === 1 ? 'un bébé' : (g.bebes === 2 ? 'jumeaux' : 'triplés')) : 'examen EMS nécessaire')}</div>${blocHisto}`;
    } else if (r.statut === 'terminee') {
      const f = r.fin || {};
      el.innerHTML = `<div class="group"><h3>${f.status === 'accouchee' ? 'Accouchement terminé' : 'Grossesse terminée'}</h3>
          ${ligne('Le', f.date || '—')}${ligne('Début (calendrier du serveur)', f.debutTexte || '—')}</div>${blocHisto}`;
    } else {
      el.innerHTML = `<div class="group"><h3>Grossesse</h3><div class="row"><span class="lb">Aucune grossesse connue.</span></div>
          <div class="row"><span class="lb" style="opacity:.7">Un test de grossesse ou un examen EMS permet de le savoir.</span></div></div>`;
    }
  }

  P.registerApp({
    id: 'grossesse', name: 'Grossesse', order: 20, icon: ICONE,
    render(el) {
      el.innerHTML = '<div class="group"><div class="row"><span class="lb">Chargement…</span></div></div>';
      charger().then((r) => { if (el.isConnected) vue(el, r); });
    },
  });
})();
