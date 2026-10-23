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

    // Durée totale de grossesse calculée à partir du brouillon (même calcul que le serveur : somme des trimestres)
    const UNITES = { secondes: 1, minutes: 60, heures: 3600, jours: 86400 };
    const duree = (s) => {
        s = Math.max(0, Math.round(s));
        if (s < 60) return `${s} s`;
        if (s < 3600) return `${Math.floor(s / 60)} min${s % 60 ? ` ${s % 60} s` : ''}`;
        if (s < 86400) return `${Math.floor(s / 3600)} h${Math.floor((s % 3600) / 60) ? ` ${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}` : ''}`;
        return `${Math.floor(s / 86400)} j${Math.floor((s % 86400) / 3600) ? ` ${Math.floor((s % 86400) / 3600)} h` : ''}`;
    };
    const totalBrouillon = (d) => {
        const u = UNITES[d['grossesse.unite']] ?? 3600;
        const t = ['grossesse.t1', 'grossesse.t2', 'grossesse.t3'].map((k) => { const v = Number(d[k]); return Number.isFinite(v) && v > 0 ? v : 0; });
        return (t[0] + t[1] + t[2]) * u;
    };
    // Durées cumulées depuis le début : passage au 2e, au 3e trimestre, terme
    const cumul = (d) => {
        const u = UNITES[d['grossesse.unite']] ?? 3600;
        const t = ['grossesse.t1', 'grossesse.t2', 'grossesse.t3'].map((k) => { const v = Number(d[k]); return Number.isFinite(v) && v > 0 ? v * u : 0; });
        return `Depuis le début : 2e trimestre à <b>${esc(duree(t[0]))}</b> · 3e trimestre à <b>${esc(duree(t[0] + t[1]))}</b> · terme à <b>${esc(duree(t[0] + t[1] + t[2]))}</b>.`;
    };
    // Tests : grossesse de test pour un joueur (ID en jeu), puis fin sans naissance (historique conservé)
    const tests = () => `<div class="section"><h2>Tests de grossesse</h2>
        <div class="btn-row"><input class="input" type="number" min="1" id="famTestSid" placeholder="ID du joueur" style="max-width:160px">
        <button class="btn" data-fa="test_debut">Démarrer une grossesse de test</button>
        <button class="btn" data-fa="test_fin">Terminer la grossesse de test</button>
        <button class="btn" data-fa="diag_suivi">Vérifier son suivi (application Grossesse)</button></div>
        <div class="btn-row" style="margin-top:8px"><input class="input" type="text" id="famSecoursMotif" maxlength="200" placeholder="Motif (obligatoire) : ex. aucun EMS connecté" style="max-width:420px">
        <button class="btn" data-fa="accouchement_secours">Accouchement de secours (sans EMS)</button></div>
        <p class="hint">V8 : l'accouchement normal se fait uniquement avec un EMS en service (menu ALT sur la patiente). Le secours est refusé
            s'il y a un EMS en service (réglable), demande un motif et est journalisé.</p>
        <p class="hint">Utilise les durées enregistrées (réglez par ex. 20 s par trimestre et enregistrez d'abord). La fin de test ne crée pas de bébé, garde l'historique et ne bloque pas une nouvelle grossesse.</p></div>`;

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
                ${nums ? `<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px;max-width:1150px">${nums}</div>` : ''}
                ${s.id === 'progression' ? `<p class="hint" id="famCumul">${cumul(F.draft)}</p>` : ''}</div>`;
        }).join('');
        const d = F.draft;
        const exemple = d['conception.probaAccidentelle'] * (1 - d['contraception.preservatif.fiabilite']) * (1 - d['contraception.pilule.fiabilite']);
        return `<div class="stats">
                <div class="stat"><b>${esc(String(f.values['intimite.duree']))} s</b><span>Durée actuelle</span></div>
                <div class="stat"><b id="famTotal">${esc(duree(totalBrouillon(d)))}</b><span>Durée totale de grossesse${totalBrouillon(d) !== totalBrouillon(f.values) ? ' (brouillon)' : ''}</span></div>
                <div class="stat"><b>${pct(f.values['conception.probaAccidentelle'])}</b><span>Risque accidentel</span></div>
                <div class="stat"><b>${pct(f.values['conception.probaVolontaire'])}</b><span>Risque volontaire</span></div>
                <div class="stat"><b>${esc(String(f.sessions || 0))}</b><span>Moment(s) en cours</span></div></div>
            <p class="hint">Exemple avec le brouillon : moment accidentel + préservatif + pilule = <b>${pct(exemple)}</b> de risque.
                X arrête toujours un moment, pour les deux personnes (non désactivable).</p>
            ${bar}${sections}${tests()}${diag(f.diagnostic)}${bar}`;
    };

    const on = () => isOpen && tab === 'famille' && F.draft;
    document.addEventListener('input', (ev) => {
        if (!on()) return;
        const t = ev.target;
        const majTotal = () => {
            const el = document.getElementById('famTotal'); if (el) el.textContent = duree(totalBrouillon(F.draft));
            const c = document.getElementById('famCumul'); if (c) c.innerHTML = cumul(F.draft);
        };
        if (t.dataset.fs) { F.draft[t.dataset.fs] = t.value; majTotal(); return; }
        if (!t.dataset.ff) return;
        if (t.value === '') { F.draft[t.dataset.ff] = null; return; }
        const n = Number(t.value);
        F.draft[t.dataset.ff] = t.dataset.pct === '1' ? n / 100 : n;
        majTotal();
    });
    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'famille' || !F.draft) return;
        let n;
        if ((n = ev.target.closest('[data-ft]'))) { F.draft[n.dataset.ft] = !F.draft[n.dataset.ft]; return render(); }
        if (!(n = ev.target.closest('[data-fa]'))) return;
        switch (n.dataset.fa) {
            case 'save': send('save', { values: F.draft }); F.draft = null; return;
            case 'cancel': F.draft = null; return render();
            case 'test_debut': case 'test_fin': case 'diag_suivi': {
                const sid = Number((document.getElementById('famTestSid') || {}).value);
                if (!Number.isInteger(sid) || sid < 1) return;
                send(n.dataset.fa, { sid });
                return;
            }
            case 'accouchement_secours': {
                const sid = Number((document.getElementById('famTestSid') || {}).value);
                const raison = String((document.getElementById('famSecoursMotif') || {}).value || '').trim();
                if (!Number.isInteger(sid) || sid < 1) return;
                if (!(await confirmBox('Accouchement de secours ?', `Le bébé naîtra sans EMS pour le joueur ${sid}. À utiliser seulement si aucun EMS n'est disponible.`))) return;
                send('accouchement_secours', { sid, raison });
                return;
            }
            case 'reset':
                if (await confirmBox('Valeurs par défaut ?', 'Tous les réglages Famille reviennent à ceux du fichier config.lua d\'elyzea_famille.')) { F.draft = null; send('reset'); }
                return;
        }
    });
})();
