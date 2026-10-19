/* =========================================================
   FAMILLE (ressource elyzea_famille, permission « famille_manage »)
   Durée et déroulé du moment intime, risque de grossesse, effets de la contraception.
   Brouillon puis « Enregistrer » ; elyzea_famille revalide chaque valeur et les règles croisées.
   ========================================================= */
(() => {
    TABS.push({
        id: 'famille', group: 5, label: 'Famille', ico: '👪',
        sub: 'Moment intime, risque de grossesse, test, étapes, symptômes, fin de grossesse, ventre, contraception, bébés et équipements.',
        show: () => has('famille_manage') && !!(D && D.famille),
    });

    const F = { draft: null };
    const send = (name, data = {}) => action('famille', { name, data });
    const pct = (v) => {
        const x = Number(v) * 100;
        // petits risques (ex. 0,0024 %) : chiffres significatifs plutôt qu'un « 0 % » trompeur
        const opts = x !== 0 && Math.abs(x) < 1 ? { maximumSignificantDigits: 2 } : { maximumFractionDigits: 2 };
        return `${x.toLocaleString('fr-FR', opts)} %`;
    };
    const shown = (d, v) => (d.type === 'pct' ? pct(v) : d.type === 'bool' ? (v ? 'Activé' : 'Désactivé') : `${v}${d.unit ? ' ' + d.unit : ''}`);

    function field(d) {
        const v = F.draft[d.key];
        const def = D.famille.defaults[d.key];
        const changed = JSON.stringify(v) !== JSON.stringify(def);
        const tag = changed ? `<span class="muted" style="font-size:12px">défaut : ${esc(shown(d, def))}</span>` : '';
        if (d.type === 'bool') {
            return `<div class="tile toggle-tile ${v ? 'on' : ''}" data-ft="${esc(d.key)}"><div><strong>${esc(d.label)}</strong><span>${esc(d.help)}</span>${tag}</div><div class="switch"></div></div>`;
        }
        if (d.type === 'choix') {
            const opts = (d.choices || []).map((c) => `<option value="${esc(c)}" ${c === v ? 'selected' : ''}>${esc(c)}</option>`).join('');
            return `<div class="field"><label>${esc(d.label)}</label>
            <select class="input" data-fs="${esc(d.key)}">${opts}</select>
            <p class="hint" style="margin:4px 0 0">${esc(d.help)}</p>${tag}</div>`;
        }
        if (d.type === 'str') {
            return `<div class="field"><label>${esc(d.label)}</label>
            <input class="input" type="text" data-fs="${esc(d.key)}" maxlength="${d.max || 64}" value="${esc(v ?? '')}">
            <p class="hint" style="margin:4px 0 0">${esc(d.help)}</p>${tag}</div>`;
        }
        const isPct = d.type === 'pct';
        const val = isPct ? Math.round(Number(v) * 10000) / 100 : v;
        const min = isPct ? d.min * 100 : d.min; const max = isPct ? d.max * 100 : d.max;
        const step = isPct ? 0.01 : (d.step || 1);
        const unit = isPct ? '%' : (d.unit || '');
        return `<div class="field"><label>${esc(d.label)}${unit ? ` (${esc(unit)})` : ''}</label>
            <input class="input" type="number" data-ff="${esc(d.key)}" data-pct="${isPct ? 1 : 0}" min="${min}" max="${max}" step="${step}" value="${esc(val ?? '')}">
            <p class="hint" style="margin:4px 0 0">${esc(d.help)} <span class="muted">(${esc(String(min))} à ${esc(String(max))})</span></p>${tag}</div>`;
    }

    // Diagnostic des bébés, porte-bébés et poussettes (lu à l'ouverture de l'onglet)
    const diag = (lignes) => (Array.isArray(lignes) ? `<div class="section"><h2>Diagnostic : bébés, porte-bébés, poussettes</h2>
        <pre style="white-space:pre-wrap;font-size:12px;max-height:260px;overflow:auto;margin:0">${esc(lignes.length ? lignes.join('\n') : 'Aucun bébé, porte-bébé ni poussette en jeu.')}</pre>
        <p class="hint">Rouvrez l'onglet pour actualiser. Détail complet : /bebe_diag (console serveur).</p></div>` : '');

    VIEWS.famille = () => {
        const f = D.famille;
        if (!f.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(f.resource || 'elyzea_famille')}</b> ne répond pas${f.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        if (f.denied) return `<div class="protect">⛔ <span>Permission « famille_manage » refusée par elyzea_famille.</span></div>`;
        if (!F.draft) F.draft = JSON.parse(JSON.stringify(f.values));
        const bar = `<div class="section"><div class="btn-row"><button class="btn primary" data-fa="save">💾 Enregistrer</button>
                <button class="btn" data-fa="cancel">Annuler les modifications</button><button class="btn" data-fa="reset">Valeurs par défaut</button>
                <span class="muted" style="align-self:center">Appliqué aux prochains moments ; un moment déjà commencé garde ses réglages.</span></div></div>`;
        const sections = f.sections.map((s) => {
            const fields = f.schema.filter((d) => d.section === s.id);
            const bools = fields.filter((d) => d.type === 'bool').map(field).join('');
            const nums = fields.filter((d) => d.type !== 'bool').map(field).join('');
            return `<div class="section"><h2>${esc(s.label)}</h2>
                ${bools ? `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(320px,1fr));margin-bottom:12px">${bools}</div>` : ''}
                ${nums ? `<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px;max-width:1150px">${nums}</div>` : ''}</div>`;
        }).join('');
        const d = F.draft;
        const exemple = d['conception.probaAccidentelle'] * (1 - d['contraception.preservatif.fiabilite']) * (1 - d['contraception.pilule.fiabilite']);
        return `<div class="stats">
                <div class="stat"><b>${esc(String(f.values['intimite.duree']))} s</b><span>Durée actuelle</span></div>
                <div class="stat"><b>${pct(f.values['conception.probaAccidentelle'])}</b><span>Risque accidentel</span></div>
                <div class="stat"><b>${pct(f.values['conception.probaVolontaire'])}</b><span>Risque volontaire</span></div>
                <div class="stat"><b>${esc(String(f.sessions || 0))}</b><span>Moment(s) en cours</span></div></div>
            <p class="hint">Exemple avec le brouillon : moment accidentel + préservatif + pilule = <b>${pct(exemple)}</b> de risque.
                X arrête toujours un moment, pour les deux personnes (non désactivable).</p>
            ${bar}${sections}${diag(f.diagnostic)}${bar}`;
    };

    const on = () => isOpen && tab === 'famille' && F.draft;
    document.addEventListener('input', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.fs) { F.draft[t.dataset.fs] = t.value; return; }
        if (!t.dataset.ff) return;
        if (t.value === '') { F.draft[t.dataset.ff] = null; return; }
        const n = Number(t.value);
        F.draft[t.dataset.ff] = t.dataset.pct === '1' ? n / 100 : n;
    });
    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'famille' || !F.draft) return;
        let n;
        if ((n = ev.target.closest('[data-ft]'))) { F.draft[n.dataset.ft] = !F.draft[n.dataset.ft]; return render(); }
        if (!(n = ev.target.closest('[data-fa]'))) return;
        switch (n.dataset.fa) {
            case 'save': send('save', { values: F.draft }); F.draft = null; return;
            case 'cancel': F.draft = null; return render();
            case 'reset':
                if (await confirmBox('Valeurs par défaut ?', 'Tous les réglages Famille reviennent à ceux du fichier config.lua d\'elyzea_famille.')) { F.draft = null; send('reset'); }
                return;
        }
    });
})();
