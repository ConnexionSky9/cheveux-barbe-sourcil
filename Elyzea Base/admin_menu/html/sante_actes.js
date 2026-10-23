/* =========================================================
   SANTÉ › ACTES MÉDICAUX EN MINI-JEUX (ressource elyzea_ems) — permission « health_manage »
   Ajouté à l'onglet « Santé » (sante.js) : activation, durée, difficulté, grade minimum,
   matériel de chaque acte, blessures, hémorragies, réanimation, attelle / plâtre, vaccins,
   comptes rendus types, blessures des joueurs connectés. Tout est revérifié par elyzea_ems.
   Les contrôles de sécurité (distance, service, permission, consentement, anti-doublon) ne sont pas réglables.
   ========================================================= */
(() => {
    const base = VIEWS.sante;
    const P = { draft: null, sig: '', inj: {} };
    const send = (op, data = {}) => action('sante', { op, data });
    const later = (ms = 500) => setTimeout(() => post('refresh'), ms);
    const clone = (x) => JSON.parse(JSON.stringify(x));
    // une table Lua vide arrive en {} (objet) et non en [] : toujours lue comme une liste
    const arr = (v) => (Array.isArray(v) ? v : (v && typeof v === 'object' ? Object.values(v) : []));
    const on = () => isOpen && tab === 'sante' && D && D.sante && D.sante.available && D.sante.procedures;
    const DIFF = { 1: 'Facile', 2: 'Intermédiaire', 3: 'Difficile' };
    const TYPES = { hemorrhage: 'Hémorragie', fracture: 'Fracture', internal: 'Lésion interne' };

    function draftOf(d) {
        const sig = JSON.stringify(d);
        if (!P.draft || P.sig !== sig) {
            P.sig = sig;
            P.draft = {
                enabled: d.enabled,
                acts: Object.fromEntries(arr(d.acts).map((a) => [a.id, { enabled: a.enabled, duration: a.duration, difficulty: a.difficulty, minLevel: a.minLevel, maxMistakes: a.maxMistakes, retry: a.retry,
                    items: [...clone(arr(a.items)), { item: '', count: 1, consume: true }] }])),
                injuries: { enabled: d.injuries.enabled, fractureChance: d.injuries.fractureChance, internalChance: d.injuries.internalChance, healMinutes: d.injuries.healMinutes, bleed: clone(d.injuries.bleed) },
                // tableau Lua { [1], [2], [3] } → tableau JSON (indices 0 à 2)
                hemostasis: { seconds: Array.isArray(d.hemostasis.seconds) ? { 1: d.hemostasis.seconds[0], 2: d.hemostasis.seconds[1], 3: d.hemostasis.seconds[2] }
                    : { 1: d.hemostasis.seconds['1'], 2: d.hemostasis.seconds['2'], 3: d.hemostasis.seconds['3'] }, dressingFrom: d.hemostasis.dressingFrom },
                cpr: { passScore: d.cpr.passScore, base: d.cpr.base, perScore: d.cpr.perScore, stabilized: d.cpr.stabilized, defibrillator: d.cpr.defibrillator, bleeding: d.cpr.bleeding, max: d.cpr.max },
                castItems: Object.fromEntries(arr(d.materials).map((m) => [m.id, m.item])),
                vaccines: Object.fromEntries(arr(d.vaccines).map((v) => [v.id, { enabled: v.enabled, label: v.label, item: v.item, delayHours: v.delayHours, protectionDays: v.protectionDays, boosterDays: v.boosterDays }])),
                reports: Object.fromEntries(arr(d.reports).map((r) => [r.key, r.text])),
            };
        }
        return P.draft;
    }
    const sw = (key, v, label) => `<div class="tile toggle-tile ${v ? 'on' : ''}" data-psw="${key}" style="padding:4px 10px"><div><span>${esc(label)}</span></div><div class="switch"></div></div>`;
    const n = (key, v, min, max, step = 1, w = 90) => `<input class="input" type="number" min="${min}" max="${max}" step="${step}" data-pn="${key}" value="${esc(v)}" style="max-width:${w}px">`;
    const t = (key, v, max = 60, w = 170) => `<input class="input" data-pt="${key}" value="${esc(v)}" maxlength="${max}" style="max-width:${w}px">`;

    function procView() {
        const d = D.sante.procedures;
        if (!d) return '';
        const g = draftOf(d);
        const actRows = arr(d.acts).map((a) => {
            const x = g.acts[a.id];
            const k = (f) => `a.${a.id}.${f}`;
            return `<tr><td>${sw(k('enabled'), x.enabled, x.enabled ? 'Actif' : 'Coupé')}</td>
                <td><b>${a.icon} ${esc(a.label)}</b><br><small class="muted">permission « ${esc(a.perm || '—')} »${a.consent === 'always' ? ' · consentement obligatoire' : a.consent ? ' · consentement si conscient' : ' · urgence'}</small></td>
                <td>${n(k('duration'), x.duration, 8, 120)} s</td>
                <td><select class="input" data-pn="${k('difficulty')}" style="max-width:150px">${[1, 2, 3].map((v) => `<option value="${v}" ${Number(x.difficulty) === v ? 'selected' : ''}>${DIFF[v]}</option>`).join('')}</select></td>
                <td>${n(k('maxMistakes'), x.maxMistakes, 0, 10)}</td>
                <td>${n(k('minLevel'), x.minLevel, 0, 50)}<br><small class="muted">0 = tous</small></td>
                <td>${sw(k('retry'), x.retry, x.retry ? 'Peut recommencer' : 'Pas de reprise')}</td>
                <td>${x.items.map((it, i) => `<div class="inline" style="margin-bottom:3px">${t(`i.${a.id}.${i}.item`, it.item, 50, 150)}×${n(`i.${a.id}.${i}.count`, it.count, 1, 20, 1, 60)}
                    <label class="muted" style="font-size:11px"><input type="checkbox" data-pc="i.${a.id}.${i}.consume" ${it.consume ? 'checked' : ''}> retiré</label></div>`).join('')}
                    <small class="muted">nom vide = pas d'objet</small></td></tr>`;
        }).join('');
        const vacRows = arr(d.vaccines).map((v) => {
            const x = g.vaccines[v.id];
            const k = (f) => `v.${v.id}.${f}`;
            return `<tr><td>${sw(k('enabled'), x.enabled, x.enabled ? 'Proposé' : 'Retiré')}</td><td>${t(k('label'), x.label, 60, 220)}<br><small class="muted">protège de : ${esc(arr(v.protects).join(', ') || 'rien (acte RP)')}</small></td>
                <td>${t(k('item'), x.item, 50, 150)}</td><td>${n(k('delayHours'), x.delayHours, 0, 720, 0.5)} h</td><td>${n(k('protectionDays'), x.protectionDays, 0, 3650)} j<br><small class="muted">0 = à vie</small></td>
                <td>${n(k('boosterDays'), x.boosterDays, 0, 3650)} j</td></tr>`;
        }).join('');
        const players = arr(D.sante.players);
        const zones = arr(d.zones);
        return `<div class="section"><h2>🧰 Actes médicaux (mini-jeux)</h2>
            <p class="hint">Les EMS réalisent les actes depuis <b>ALT</b> sur le patient › « Actes et examens… », le menu <span class="keycap">F6</span> ou la fenêtre d'examen.
                Grades autorisés : tablette EMS › Direction › Grades › Permissions (imagerie, vaccination, implant…) ; ici seulement un grade minimum en plus.
                La distance, le service, le consentement, la durée minimale réelle et les verrous anti-doublon sont toujours vérifiés par le serveur.</p>
            <div class="grid" style="grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:10px">${sw('enabled', g.enabled, g.enabled ? 'Mini-jeux actifs' : 'Mini-jeux coupés (anciens actes simples)')}</div>
            <table class="loot wide"><tr><th>État</th><th>Acte</th><th>Durée</th><th>Difficulté</th><th>Erreurs tolérées</th><th>Grade min.</th><th>Échec</th><th>Matériel</th></tr>${actRows}</table></div>
        <div class="section"><h2>🩸 Blessures, hémorragies, réanimation</h2>
            <div class="grid" style="grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:10px">${sw('injuries.enabled', g.injuries.enabled, g.injuries.enabled ? 'Blessures par les coups reçus' : 'Pas de blessure par les coups')}</div>
            <div class="form-grid" style="grid-template-columns:repeat(4,minmax(0,230px));gap:12px">
                <div><label>Hémorragie légère dès (dégâts)</label>${n('injuries.bleed.light', g.injuries.bleed.light, 1, 200)}</div>
                <div><label>Importante dès</label>${n('injuries.bleed.major', g.injuries.bleed.major, 1, 200)}</div>
                <div><label>Critique dès</label>${n('injuries.bleed.critical', g.injuries.bleed.critical, 1, 400)}</div>
                <div><label>Chance de fracture (coup violent) %</label>${n('injuries.fractureChance', g.injuries.fractureChance, 0, 100)}</div>
                <div><label>Chance de lésion interne %</label>${n('injuries.internalChance', g.injuries.internalChance, 0, 100)}</div>
                <div><label>Guérison après soin (min)</label>${n('injuries.healMinutes', g.injuries.healMinutes, 0, 1440)}<p class="hint" style="margin:3px 0 0">0 = guérie dès le soin</p></div>
                <div><label>Compression : légère (s)</label>${n('hemostasis.seconds.1', g.hemostasis.seconds[1], 5, 60)}</div>
                <div><label>Importante (s)</label>${n('hemostasis.seconds.2', g.hemostasis.seconds[2], 5, 60)}</div>
                <div><label>Critique (s)</label>${n('hemostasis.seconds.3', g.hemostasis.seconds[3], 5, 60)}</div>
                <div><label>Pansement compressif à part dès la gravité</label>${n('hemostasis.dressingFrom', g.hemostasis.dressingFrom, 1, 4)}<p class="hint" style="margin:3px 0 0">1 légère · 2 importante · 3 critique · 4 jamais</p></div>
            </div>
            <h3 style="margin-top:14px">Massage cardiaque (aucune reprise garantie, un échec ne tue jamais)</h3>
            <div class="form-grid" style="grid-template-columns:repeat(4,minmax(0,230px));gap:12px">
                <div><label>Séquence validée dès (part dans le rythme)</label>${n('cpr.passScore', g.cpr.passScore, 0.3, 0.95, 0.05)}</div>
                <div><label>Chance de base</label>${n('cpr.base', g.cpr.base, 0, 1, 0.01)}</div>
                <div><label>+ régularité ×</label>${n('cpr.perScore', g.cpr.perScore, 0, 1, 0.01)}</div>
                <div><label>+ patient stabilisé</label>${n('cpr.stabilized', g.cpr.stabilized, 0, 1, 0.01)}</div>
                <div><label>+ défibrillateur</label>${n('cpr.defibrillator', g.cpr.defibrillator, 0, 1, 0.01)}</div>
                <div><label>− hémorragie non contrôlée</label>${n('cpr.bleeding', g.cpr.bleeding, 0, 1, 0.01)}</div>
                <div><label>Chance maximale</label>${n('cpr.max', g.cpr.max, 0, 1, 0.01)}</div>
            </div>
            <h3 style="margin-top:14px">Attelle / plâtre : objets</h3>
            <div class="form-grid" style="grid-template-columns:repeat(4,minmax(0,230px));gap:12px">${arr(d.materials).map((m) => `<div><label>${esc(m.label)}</label>${t(`m.${m.id}`, g.castItems[m.id], 50)}</div>`).join('')}</div></div>
        <div class="section"><h2>💉 Vaccins</h2>
            <table class="loot wide"><tr><th>État</th><th>Nom</th><th>Objet</th><th>Délai</th><th>Protection</th><th>Rappel possible après</th></tr>${vacRows}</table>
            <p class="hint">L'implant contraceptif garde sa durée réglée dans l'onglet Famille (elyzea_famille).</p></div>
        <div class="section"><h2>📝 Comptes rendus types</h2>
            <p class="hint">{zone}, {level}, {type}, {material}, {day}, {days}, {babies} sont remplacés. Les résultats viennent toujours des blessures et grossesses enregistrées : rien n'est inventé.</p>
            <table class="loot wide">${arr(d.reports).map((r) => `<tr><td class="muted" style="width:140px">${esc(r.key)}</td><td><input class="input" data-pt="r.${esc(r.key)}" value="${esc(g.reports[r.key])}" maxlength="240"></td></tr>`).join('')}</table>
            <div class="btn-row" style="margin-top:14px"><button class="btn primary" data-psave>💾 Enregistrer les actes médicaux</button><button class="btn" data-pcancel>Annuler les modifications</button></div></div>
        <div class="section"><h2>🦴 Blessures des joueurs connectés</h2>
            <p class="hint">Pour préparer un scénario ou tester avec deux joueurs : ajoute une hémorragie, une fracture ou une lésion interne à un joueur.</p>
            <table class="loot wide"><tr><th>Joueur</th><th>Blessures</th><th>Ajouter</th></tr>
            ${players.map((p) => { const s = P.inj[p.id] || { type: 'hemorrhage', zone: (zones[0] || {}).id, severity: 1 };
                return `<tr><td><b>[${p.id}] ${esc(p.name)}</b></td>
                <td>${arr(p.injuries).length ? arr(p.injuries).map((i) => `<span class="zbadge">${esc(i.label)} · ${esc(i.zone)} · ${esc(i.status)}<button class="kick-owner" data-pheal="${p.id}" data-id="${i.id}" title="Soigner">✕</button></span>`).join(' ') + ` <button class="btn" data-phealall="${p.id}">Tout soigner</button>` : '<span class="muted">Aucune</span>'}</td>
                <td><div class="inline"><select class="input" data-pis="${p.id}.type">${Object.entries(TYPES).map(([k, v]) => `<option value="${k}" ${s.type === k ? 'selected' : ''}>${v}</option>`).join('')}</select>
                    <select class="input" data-pis="${p.id}.zone">${zones.map((z) => `<option value="${esc(z.id)}" ${s.zone === z.id ? 'selected' : ''}>${esc(z.label)}</option>`).join('')}</select>
                    <select class="input" data-pis="${p.id}.severity">${[1, 2, 3].map((v) => `<option value="${v}" ${Number(s.severity) === v ? 'selected' : ''}>Gravité ${v}</option>`).join('')}</select>
                    <button class="btn" data-pgive="${p.id}">Ajouter</button></div></td></tr>`; }).join('')}</table></div>`;
    }

    VIEWS.sante = () => { const html = base(); return D && D.sante && D.sante.available ? html + procView() : html; };
    const baseStable = STABLE_VIEWS.sante;
    P.v = 0;
    STABLE_VIEWS.sante = () => `${baseStable()}|${P.v}`;

    function target(key) {
        const g = P.draft, ks = key.split('.');
        if (ks[0] === 'a') return [g.acts[ks[1]], ks[2]];
        if (ks[0] === 'i') return [g.acts[ks[1]].items[Number(ks[2])], ks[3]];
        if (ks[0] === 'v') return [g.vaccines[ks[1]], ks[2]];
        if (ks[0] === 'm') return [g.castItems, ks[1]];
        if (ks[0] === 'r') return [g.reports, ks.slice(1).join('.')];
        let o = g;
        for (let i = 0; i < ks.length - 1; i++) o = o[ks[i]];
        return [o, ks[ks.length - 1]];
    }
    function payload() {
        const g = P.draft;
        const num = (v) => Number(v);
        const acts = {};
        Object.entries(g.acts).forEach(([id, a]) => {
            acts[id] = { enabled: a.enabled, retry: a.retry, duration: num(a.duration), difficulty: num(a.difficulty), maxMistakes: num(a.maxMistakes), minLevel: num(a.minLevel),
                items: a.items.filter((it) => String(it.item || '').trim() !== '').map((it) => ({ item: String(it.item).trim(), count: num(it.count) || 1, consume: it.consume !== false })) };
        });
        const vaccines = {};
        Object.entries(g.vaccines).forEach(([id, v]) => { vaccines[id] = { enabled: v.enabled, label: v.label, item: v.item, delayHours: num(v.delayHours), protectionDays: num(v.protectionDays), boosterDays: num(v.boosterDays) }; });
        return { enabled: g.enabled, acts,
            injuries: { enabled: g.injuries.enabled, fractureChance: num(g.injuries.fractureChance), internalChance: num(g.injuries.internalChance), healMinutes: num(g.injuries.healMinutes),
                bleed: { light: num(g.injuries.bleed.light), major: num(g.injuries.bleed.major), critical: num(g.injuries.bleed.critical) } },
            hemostasis: { seconds: { 1: num(g.hemostasis.seconds[1]), 2: num(g.hemostasis.seconds[2]), 3: num(g.hemostasis.seconds[3]) }, dressingFrom: num(g.hemostasis.dressingFrom) },
            cpr: Object.fromEntries(Object.entries(g.cpr).map(([k, v]) => [k, num(v)])),
            castItems: g.castItems, vaccines, reports: g.reports };
    }

    document.addEventListener('click', (ev) => {
        if (!on()) return;
        const el = ev.target;
        let b;
        if ((b = el.closest('[data-psw]'))) { const [o, f] = target(b.dataset.psw); o[f] = !o[f]; P.v++; return render(); }
        if (el.closest('[data-pcancel]')) { P.draft = null; P.v++; return render(); }
        if (el.closest('[data-psave]')) { send('procSave', { procedures: payload() }); P.draft = null; return later(); }
        if ((b = el.closest('[data-pgive]'))) {
            const id = Number(b.dataset.pgive);
            const s = P.inj[id] || {};
            const get = (f) => { const x = document.querySelector(`[data-pis="${id}.${f}"]`); return x ? x.value : s[f]; };
            send('injuryGive', { target: id, type: get('type'), zone: get('zone'), severity: Number(get('severity')) });
            return later();
        }
        if ((b = el.closest('[data-pheal]'))) { send('injuryHeal', { target: Number(b.dataset.pheal), id: Number(b.dataset.id) }); return later(); }
        if ((b = el.closest('[data-phealall]'))) { send('injuryHeal', { target: Number(b.dataset.phealall) }); return later(); }
    });
    const onInput = (ev) => {
        if (!on() || !P.draft) return;
        const el = ev.target;
        if (el.dataset.pn !== undefined) { const [o, f] = target(el.dataset.pn); o[f] = el.value; }
        if (el.dataset.pt !== undefined) { const [o, f] = target(el.dataset.pt); o[f] = el.value; }
        if (el.dataset.pc !== undefined) { const [o, f] = target(el.dataset.pc); o[f] = el.checked; }
        if (el.dataset.pis !== undefined) { const [id, f] = el.dataset.pis.split('.'); P.inj[id] = P.inj[id] || {}; P.inj[id][f] = el.value; }
    };
    document.addEventListener('input', onInput);
    document.addEventListener('change', onInput);
})();
