/* =========================================================
   SANTÉ (ressource elyzea_ems) — permission « health_manage »
   Maladies et blessures (rhume, MST, jambe blessée après une chute),
   attelle, rendez-vous EMS, postes des dossiers médicaux,
   donner / soigner une maladie à un joueur. Tout est revérifié par elyzea_ems.
   ========================================================= */
(() => {
    TABS.push({
        id: 'sante', group: 6, label: 'Santé', ico: '🩺',
        sub: 'Maladies (rhume, MST), blessures (chute, attelle), rendez-vous EMS, postes des dossiers médicaux, joueurs malades.',
        show: () => has('health_manage') && !!(D && D.sante),
    });
    const G = { draft: null, sig: '', give: {}, pointLabel: '' };
    const send = (op, data = {}) => action('sante', { op, data });
    const later = (ms = 500) => setTimeout(() => post('refresh'), ms);
    const clone = (x) => JSON.parse(JSON.stringify(x));
    const on = () => isOpen && tab === 'sante' && D && D.sante && D.sante.available;
    const TYPE = { illness: 'Maladie', injury: 'Blessure', std: 'MST' };
    const CURE = { treat: 'Traitement EMS', splint: 'Attelle EMS' };
    const ago = (t) => { const s = Math.max(0, Math.floor(Date.now() / 1000 - t)); return s < 3600 ? `${Math.max(1, Math.floor(s / 60))} min` : `${Math.floor(s / 3600)} h`; };

    function draftOf(d) {
        const sig = JSON.stringify([d.enabled, d.fall, d.splint, d.conditions, d.appointments]);
        if (!G.draft || G.sig !== sig) {
            G.sig = sig;
            G.draft = {
                enabled: d.enabled, fall: clone(d.fall), splint: { healMinutes: d.splint.healMinutes },
                conditions: Object.fromEntries(d.conditions.map((c) => [c.id, clone(c)])),
                appt: { enabled: d.appointments.enabled, expireMinutes: d.appointments.expireMinutes, acceptedHours: d.appointments.acceptedHours,
                    maxOpen: d.appointments.maxOpen, typesOff: Object.fromEntries(d.appointments.types.map((t) => [t.id, !t.enabled])) },
            };
        }
        return G.draft;
    }
    const sw = (key, v, label) => `<div class="tile toggle-tile ${v ? 'on' : ''}" data-hsw="${key}" style="padding:4px 10px"><div><span>${esc(label)}</span></div><div class="switch"></div></div>`;
    const n = (key, v, min, max, step = 1) => `<input class="input" type="number" min="${min}" max="${max}" step="${step}" data-hn="${key}" value="${esc(v)}" style="max-width:110px">`;

    function view() {
        const d = D.sante;
        if (!d.available) return `<div class="section"><div class="empty">La ressource <b>${esc(d.resource || 'elyzea_ems')}</b> n'est pas démarrée.</div></div>`;
        const g = draftOf(d);
        const condRows = d.conditions.map((c) => {
            const x = g.conditions[c.id];
            const k = (f) => `c.${c.id}.${f}`;
            return `<tr>
                <td>${sw(k('enabled'), x.enabled, x.enabled ? 'Activée' : 'Désactivée')}</td>
                <td><input class="input" data-ht="${k('label')}" value="${esc(x.label)}" maxlength="60"><small class="muted">${TYPE[c.type] || ''} · ${CURE[c.cure] || ''}</small></td>
                <td>${sw(k('known'), x.known, x.known ? 'Le joueur le sait' : 'Examen EMS')}</td>
                <td>${c.type === 'injury' ? '<span class="muted">jusqu\'à l\'attelle</span>' : `${n(k('durationMin'), x.durationMin, 0, 100000)} → ${n(k('durationMax'), x.durationMax, 0, 100000)}<br><small class="muted">min · 0 = soin EMS obligatoire</small>`}</td>
                <td>${c.id === 'cold' ? `${n(k('randomPerHour'), x.randomPerHour, 0, 100, 0.1)} % / h<br><small class="muted">au hasard</small><br>${n(k('contagionChance'), x.contagionChance, 0, 100, 0.5)} % / min à ${n(k('contagionRadius'), x.contagionRadius, 0, 20, 0.5)} m<br><small class="muted">contagion</small>`
                    : c.type === 'std' ? `${n(k('transmission'), x.transmission, 0, 100, 1)} %<br><small class="muted">sans préservatif</small>` : '<span class="muted">chute</span>'}</td>
                <td>${c.type === 'injury' ? '<span class="muted">boite, ne court plus</span>' : `${n(k('symptomEvery'), x.symptomEvery, 0, 86400, 10)} s<br><small class="muted">0 = aucun symptôme</small>`}</td>
            </tr>`;
        }).join('');
        const kinds = d.conditions;
        const players = d.players || [];
        return `<div class="section"><h2>Réglages généraux</h2>
            <div class="grid" style="grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:10px">
                ${sw('enabled', g.enabled, g.enabled ? 'Maladies et blessures actives' : 'Maladies et blessures désactivées')}
                ${sw('fall.enabled', g.fall.enabled, g.fall.enabled ? 'Blessure en cas de chute' : 'Chutes sans blessure')}
                <div></div></div>
            <div class="form-grid" style="grid-template-columns:repeat(2,minmax(0,320px));gap:12px">
                <div><label>Hauteur de chute qui blesse la jambe (m)</label>${n('fall.minHeight', g.fall.minHeight, 2, 100, 0.5)}<p class="hint" style="margin:3px 0 0">À pied seulement (pas en véhicule ni en parachute).</p></div>
                <div><label>Après l'attelle : minutes sans pouvoir courir</label>${n('splint.healMinutes', g.splint.healMinutes, 0, 1440)}<p class="hint" style="margin:3px 0 0">0 = guéri dès que l'attelle est posée.</p></div>
            </div></div>
        <div class="section"><h2>Maladies et blessures</h2>
            <p class="hint">Rhume : attrapé au hasard ou près d'un malade, il passe tout seul (ou traitement EMS). Jambe : après une chute, le joueur boite jusqu'à la pose d'une attelle par un EMS (ALT sur le patient).
                MST : transmises lors d'un moment intime <b>sans préservatif</b> (elyzea_famille), découvertes par un examen EMS, soignées par un traitement EMS.</p>
            <table class="loot wide"><tr><th>État</th><th>Nom</th><th>Connue</th><th>Durée (min)</th><th>Attraper</th><th>Symptômes</th></tr>${condRows}</table></div>
        <div class="section"><h2>📅 Rendez-vous (application Santé ↔ téléphone de service EMS)</h2>
            <div class="grid" style="grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:10px">${sw('appt.enabled', g.appt.enabled, g.appt.enabled ? 'Rendez-vous ouverts' : 'Rendez-vous fermés')}</div>
            <div class="form-grid" style="grid-template-columns:repeat(3,minmax(0,260px));gap:12px">
                <div><label>Annulée si personne ne l'accepte après (min)</label>${n('appt.expireMinutes', g.appt.expireMinutes, 5, 10080)}</div>
                <div><label>Rendez-vous accepté : terminé après (h)</label>${n('appt.acceptedHours', g.appt.acceptedHours, 1, 720)}</div>
                <div><label>Demandes en cours par joueur</label>${n('appt.maxOpen', g.appt.maxOpen, 1, 10)}</div></div>
            <label style="margin-top:10px">Types proposés</label>
            <div class="grid" style="grid-template-columns:repeat(4,1fr);gap:8px">${d.appointments.types.map((t) => sw('apptType.' + t.id, !g.appt.typesOff[t.id], `${t.icon || ''} ${t.label}`)).join('')}</div>
            <div class="btn-row" style="margin-top:14px"><button class="btn primary" data-hsave>💾 Enregistrer les réglages</button><button class="btn" data-hcancel>Annuler les modifications</button></div></div>
        <div class="section"><h2>🖥️ Postes des dossiers médicaux (${d.points.length})</h2>
            <p class="hint">Les dossiers médicaux ne s'ouvrent plus dans la tablette EMS : seulement à un poste. Place-toi devant le PC voulu (ex. accueil de l'hôpital) et clique « Placer ici ».
                Au poste, un EMS appuie sur <span class="keycap">E</span> : recherche par nom et prénom, puis dossier complet. La direction EMS peut aussi les placer (tablette › Garage).</p>
            ${d.points.length ? `<table class="loot wide"><tr><th>Nom</th><th>Position</th><th></th></tr>${d.points.map((p) => `<tr><td><b>${esc(p.label)}</b></td>
                <td class="muted">${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}</td><td><button class="btn danger" data-hprm="${p.id}">Retirer</button></td></tr>`).join('')}</table>` : '<div class="empty">Aucun poste : les EMS ne peuvent consulter aucun dossier.</div>'}
            <div class="inline" style="max-width:620px;margin-top:10px"><input class="input" data-hpl placeholder="Nom du poste (ex : Accueil – Pillbox Hill)" value="${esc(G.pointLabel)}" maxlength="60">
                <button class="btn primary" data-hpadd>📍 Placer ici</button></div></div>
        <div class="section"><h2>Joueurs connectés (${players.length})</h2>
            <table class="loot wide"><tr><th>Joueur</th><th>Maladies et blessures</th><th>Rendre malade</th></tr>
            ${players.map((p) => `<tr><td><b>[${p.id}] ${esc(p.name)}</b></td>
                <td>${p.conditions.length ? p.conditions.map((c) => `<span class="zbadge">${esc(c.label)}${c.splinted ? ' (attelle)' : ''}${c.diagnosed ? '' : ' · non découvert'} · ${ago(c.since)}
                    <button class="kick-owner" data-hcure="${p.id}" data-kind="${esc(c.kind)}" title="Soigner">✕</button></span>`).join(' ') + ` <button class="btn" data-hcureall="${p.id}">Tout soigner</button>` : '<span class="muted">En bonne santé</span>'}</td>
                <td><div class="inline"><select class="input" data-hgk="${p.id}">${kinds.map((c) => `<option value="${esc(c.id)}" ${G.give[p.id] === c.id ? 'selected' : ''}>${esc(c.label)}</option>`).join('')}</select>
                    <button class="btn" data-hgive="${p.id}">Donner</button></div></td></tr>`).join('')}</table></div>`;
    }

    // Contenu de l'onglet (rendu par le menu)
    VIEWS.sante = view;
    // Pas de reconstruction pendant la saisie : seulement si les données ou un interrupteur changent
    G.v = 0;
    STABLE_VIEWS.sante = () => `${G.v}|${JSON.stringify(D && D.sante)}`;

    const setPath = (o, p, v) => { const ks = p.split('.'); let a = o; for (let i = 0; i < ks.length - 1; i++) a = a[ks[i]]; a[ks[ks.length - 1]] = v; };
    function draftPath(key) {
        if (key.startsWith('c.')) { const [, id, f] = key.split('.'); return [G.draft.conditions[id], f]; }
        if (key.startsWith('apptType.')) return [G.draft.appt.typesOff, key.slice(9)];
        return [G.draft, key];
    }
    document.addEventListener('click', (ev) => {
        if (!on()) return;
        const t = ev.target;
        let b;
        if ((b = t.closest('[data-hsw]'))) {
            const key = b.dataset.hsw;
            const [o, f] = draftPath(key);
            if (key.startsWith('apptType.')) o[f] = !o[f];
            else if (f.includes('.')) { const cur = f.split('.').reduce((a, k) => a[k], o); setPath(o, f, !cur); }
            else o[f] = !o[f];
            return renderNow();
        }
        if (t.closest('[data-hcancel]')) { G.draft = null; return renderNow(); }
        if (t.closest('[data-hsave]')) {
            const g = G.draft;
            const conditions = {};
            Object.entries(g.conditions).forEach(([id, c]) => { conditions[id] = { enabled: c.enabled, known: c.known, label: c.label, durationMin: Number(c.durationMin), durationMax: Number(c.durationMax),
                randomPerHour: Number(c.randomPerHour), contagionChance: Number(c.contagionChance), contagionRadius: Number(c.contagionRadius), transmission: Number(c.transmission), symptomEvery: Number(c.symptomEvery) }; });
            send('save', { health: { enabled: g.enabled, fall: { enabled: g.fall.enabled, minHeight: Number(g.fall.minHeight) }, splint: { healMinutes: Number(g.splint.healMinutes) }, conditions },
                appointments: { enabled: g.appt.enabled, expireMinutes: Number(g.appt.expireMinutes), acceptedHours: Number(g.appt.acceptedHours), maxOpen: Number(g.appt.maxOpen), typesOff: g.appt.typesOff } });
            G.draft = null;
            return later();
        }
        if ((b = t.closest('[data-hpadd]'))) { send('pointAdd', { label: G.pointLabel }); G.pointLabel = ''; return later(); }
        if ((b = t.closest('[data-hprm]'))) { send('pointRemove', { id: Number(b.dataset.hprm) }); return later(); }
        if ((b = t.closest('[data-hcure]'))) { send('cure', { target: Number(b.dataset.hcure), kind: b.dataset.kind }); return later(); }
        if ((b = t.closest('[data-hcureall]'))) { send('cureAll', { target: Number(b.dataset.hcureall) }); return later(); }
        if ((b = t.closest('[data-hgive]'))) {
            const id = Number(b.dataset.hgive);
            const sel = document.querySelector(`[data-hgk="${id}"]`);
            send('give', { target: id, kind: sel ? sel.value : (D.sante.conditions[0] || {}).id });
            return later();
        }
    });
    const onInput = (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.hn !== undefined) { const [o, f] = draftPath(t.dataset.hn); if (f.includes('.')) setPath(o, f, t.value); else o[f] = t.value; }
        if (t.dataset.ht !== undefined) { const [o, f] = draftPath(t.dataset.ht); o[f] = t.value; }
        if (t.dataset.hpl !== undefined) G.pointLabel = t.value;
        if (t.dataset.hgk !== undefined) G.give[t.dataset.hgk] = t.value;
    };
    document.addEventListener('input', onInput);
    document.addEventListener('change', onInput);
    function renderNow() { G.v++; render(); }
})();
