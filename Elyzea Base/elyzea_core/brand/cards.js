/* =====================================================================
   ELYZEA FA · CARTES OFFICIELLES (rendu HTML)  — nécessite brand.js
   ElyCards.render(doc, { width, enter }) → HTML
   doc = { type: 'id' | 'licence' | 'ppa', data: {...}, photo, suspended, sub: 'civil'|'fdo', now }
     licence : data.categories = [{ key, short, label, date, suspended }]
   ===================================================================== */
window.ElyCards = (() => {
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const frDate = (v) => { const m = String(v || '').match(/^(\d{4})-(\d{2})-(\d{2})/); return m ? `${m[3]}/${m[2]}/${m[1]}` : String(v || ''); };
  const sexOf = (g) => (g === 1 || g === '1' || g === 'F' ? 'F' : 'M');
  const mrz = (s, n) => (String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().replace(/[^A-Z0-9]/g, '<') + '<'.repeat(n)).slice(0, n);
  const silhouette = '<svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4.5" fill="#C9A6FF"/><path d="M3 22a9 9 0 0 1 18 0z" fill="#C9A6FF"/></svg>';
  const f = (label, value, cls = '') => `<div class="c-f ${cls}"><small>${label}</small><b>${value}</b></div>`;
  const photo = (src) => `<div class="c-photo">${src ? `<img src="${esc(src)}" alt="" onerror="this.remove()">` : ''}${src ? '' : silhouette}</div>`;
  const deco = (seed) => `<div class="c-arc"></div><div class="c-wm">${Ely.mark({ size: 120 })}</div>
    <div class="c-sky">${Ely.skyline({ w: 680, h: 90, seed, lit: 0.25, palm: false })}</div><div class="c-band"></div>`;
  const head = (title, sub) => `<div class="c-head">${Ely.mark({ size: 60, live: true })}<div class="c-titles"><b>${title}</b><small>${sub}</small></div><div class="c-chip"></div></div>`;
  const stamp = (txt = 'SUSPENDU', sub = '') => `<div class="c-stamp">${txt}${sub ? `<small>${esc(sub)}</small>` : ''}</div>`;

  function idCard(d, doc) {
    const l1 = `ID${mrz('ELY', 3)}${mrz(d.lastname, 14)}<<${mrz(d.firstname, 12)}`;
    const l2 = `${mrz(d.number, 10)}${mrz(String(d.birthdate || '').replace(/\D/g, '').slice(2), 6)}${sexOf(d.gender)}${mrz(d.citizenid, 10)}`;
    return `${head("Carte d'identité", "République d'Elyzea · San Andreas")}
      <div class="c-body">${photo(doc.photo)}<div class="c-fields">
        ${f('Nom', esc(String(d.lastname || '').toUpperCase()))}${f('Prénom', esc(d.firstname))}
        ${f('Né(e) le', esc(frDate(d.birthdate)))}${f('Sexe', sexOf(d.gender))}
        ${f('Nationalité', esc(d.nationality || 'Elyzéenne'))}${f('Délivrée le', esc(d.issued || '—'))}
        ${f('N° de carte', `<span class="c-num">${esc(d.number || '—')}</span>`, 'w2')}
      </div></div><div class="c-mrz">${esc(l1)}<br>${esc(l2)}</div>`;
  }

  function licenceCard(d, doc) {
    const cats = Array.isArray(d.categories) ? d.categories : [];
    const all = [['car', 'B', 'Voiture'], ['moto', 'A', 'Moto'], ['truck', 'C', 'Poids lourd']];
    const chips = all.map(([k, s, l]) => {
      const c = cats.find((x) => x.key === k || x.short === s);
      if (!c) return `<div class="c-cat none"><i>${s}</i>${l}</div>`;
      return c.suspended ? `<div class="c-cat off"><i>${s}</i>${l}<em>SUSPENDU</em></div>` : `<div class="c-cat"><i>${s}</i>${l}<span style="opacity:.6">· ${esc(c.date || '')}</span></div>`;
    }).join('');
    return `${head('Permis de conduire', 'Elyzea · Sécurité routière')}
      <div class="c-body">${photo(doc.photo)}<div class="c-fields">
        ${f('Nom', esc(String(d.lastname || '').toUpperCase()))}${f('Prénom', esc(d.firstname))}
        ${f('Né(e) le', esc(frDate(d.birthdate)))}${f('Sexe', sexOf(d.gender))}
        ${f('N° de permis', `<span class="c-num">${esc(d.number || '—')}</span>`, 'w2')}
        ${f('Signature', `<span class="c-sign">${esc(d.firstname || '')} ${esc(String(d.lastname || '').slice(0, 1))}.</span>`, 'w2')}
      </div></div><div class="c-cats">${chips}</div>`;
  }

  function ppaCard(d, doc) {
    const fdo = doc.sub === 'fdo' || d.kind === 'fdo';
    const expired = d.expiresAt && doc.now && doc.now > d.expiresAt;
    const cats = Array.isArray(d.categories) && d.categories.length ? d.categories : (fdo ? ['Arme légère', 'Arme lourde'] : ['Pistolet']);
    return `${head("Permis de port d'arme", fdo ? "Forces de l'ordre · Aptitude médicale" : 'Civil · Aptitude médicale')}
      <div class="c-body">${photo(doc.photo)}<div class="c-fields">
        ${f('Nom', esc(String(d.lastname || '').toUpperCase()))}${f('Prénom', esc(d.firstname))}
        ${f('Délivré le', esc(d.issued || '—'))}${f("Valide jusqu'au", esc(d.expires || 'Illimité'))}
        ${f('Médecin', esc(d.doctor || '—'))}${f('N° PPA', `<span class="c-num">${esc(d.number || '—')}</span>`)}
      </div></div><div class="c-cats">${cats.map((c) => `<div class="c-cat ${doc.suspended ? 'off' : ''}"><i>✓</i>${esc(c)}</div>`).join('')}</div>
      ${doc.suspended ? '' : `<span class="c-badge ${expired ? 'bad' : ''}">${expired ? 'EXPIRÉ' : 'APTE'}</span>`}`;
  }

  function render(doc, { width = 340, enter = true } = {}) {
    const d = doc.data || {};
    const type = doc.type === 'ppa' ? 'ppa' : doc.type === 'licence' ? 'licence' : 'id';
    let body = type === 'ppa' ? ppaCard(d, doc) : type === 'licence' ? licenceCard(d, doc) : idCard(d, doc);
    const cats = Array.isArray(d.categories) ? d.categories : [];
    const allSusp = type === 'licence' && cats.length > 0 && cats.every((c) => c.suspended);
    const susp = (type === 'ppa' && doc.suspended) || allSusp;
    if (susp) body += stamp('SUSPENDU', doc.suspendedReason || '');
    const seed = String(d.number || d.lastname || 'ely').split('').reduce((a, c) => a + c.charCodeAt(0), 0);
    return `<div class="ely-card ely-card--${type} ${type === 'ppa' && (doc.sub === 'fdo' || d.kind === 'fdo') ? 'fdo' : ''} ${susp ? 'is-suspended' : ''} ${enter ? 'enter' : ''}"
      style="--cw:${Math.round(width)}px">${deco(seed)}${body}</div>`;
  }
  return { render, frDate };
})();
