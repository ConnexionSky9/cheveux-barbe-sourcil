/* =========================================================
   DROGUES · EFFETS (ressource elyzea_drogues, permission « drugs_effects »)
   Durée de défonce et délai par drogue · hallucinations des champignons · joueurs sous effet
   Chaque action est revalidée par elyzea_drogues.
   ========================================================= */
(() => {
    TABS.push({
        id: 'drogues', group: 6, label: 'Drogues (effets)', ico: '💊',
        sub: 'Durée de défonce, délai entre deux prises, drogues activées, hallucinations des champignons (créatures), joueurs sous effet.',
        show: () => has('drugs_effects') && !!(D && D.drogues),
    });
    const G = { draft: null };
    const send = (name, data = {}) => action('drogues', { name, data });
    const later = () => setTimeout(() => post('refresh'), 400);
    const fmtS = (s) => (s >= 60 ? `${Math.floor(s / 60)} min${s % 60 ? ` ${s % 60} s` : ''}` : `${s} s`);
    const on = () => isOpen && tab === 'drogues' && D && D.drogues && D.drogues.available;

    function draftFrom(d) {
        const s = { drugs: {}, trip: { ...d.trip }, creatures: {} };
        d.drugs.forEach((x) => { s.drugs[x.id] = { enabled: x.enabled, duration: x.duration, cooldown: x.cooldown }; });
        d.creatures.forEach((c) => { s.creatures[c.model] = c.on; });
        return s;
    }

    VIEWS.drogues = () => {
        const d = D.drogues;
        if (!d.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_drogues')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        if (d.denied) return '<div class="protect">⛔ <span>Permission « drugs_effects » refusée par elyzea_drogues.</span></div>';
        if (!G.draft) G.draft = draftFrom(d);
        const s = G.draft;
        const num = (k, path, v, min, max, help) => `<div><label>${esc(k)}</label><input class="input" type="number" min="${min}" max="${max}" data-dn="${path}" value="${esc(v)}">${help ? `<p class="hint" style="margin:3px 0 0">${esc(help)}</p>` : ''}</div>`;
        return `
        <div class="section"><h2>Joueurs sous effet (${d.users.length})</h2>
            ${d.users.length ? `<table class="loot wide"><tr><th>Joueur</th><th>Drogues</th><th></th></tr>${d.users.map((u) => `<tr><td>${esc(u.name)} <span class="muted">#${u.id}</span></td>
                <td>${u.drugs.map((x) => `${esc(x.label)} <span class="muted">(${fmtS(x.left)})</span>`).join(' · ')}</td>
                <td style="text-align:right"><button class="btn" data-dstop="${u.id}">Arrêter les effets</button></td></tr>`).join('')}</table>` : '<p class="muted">Personne n\'est sous l\'effet d\'une drogue.</p>'}
            <div class="inline" style="max-width:420px;margin-top:8px"><input class="input" type="number" min="1" id="drg-stop-id" placeholder="ID du joueur"><button class="btn" data-dstopid>Arrêter ses effets</button></div></div>

        <div class="section"><h2>Drogues</h2>
            <p class="hint">Durée de défonce et délai avant de pouvoir en reprendre. Reprendre la même drogue prolonge l'effet (jusqu'à 2 fois sa durée).
                ${d.emsLinked ? 'Chaque prise est enregistrée pour le laboratoire EMS.' : '<b>elyzea_ems n\'est pas démarré : les prises ne sont pas enregistrées pour le laboratoire.</b>'}</p>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:12px">${d.drugs.map((x) => { const v = s.drugs[x.id]; return `<div class="card recipe">
                <div class="card-head"><strong>${esc(x.icon)} ${esc(x.label)}</strong>
                    <div class="tile toggle-tile ${v.enabled ? 'on' : ''}" data-dtog="${esc(x.id)}" style="padding:4px 8px"><div><span>${v.enabled ? 'Activée' : 'Désactivée'}</span></div><div class="switch"></div></div></div>
                <p class="hint" style="margin:4px 0 8px">${esc(x.desc)}</p>
                <div class="form-grid" style="grid-template-columns:1fr 1fr">
                    ${num('Durée de défonce (s)', `drugs.${x.id}.duration`, v.duration, 10, 3600, fmtS(v.duration))}
                    ${num('Délai entre deux prises (s)', `drugs.${x.id}.cooldown`, v.cooldown, 0, 3600)}</div>
                <p class="hint" style="margin-top:6px">Objets : ${x.items.map((i) => `<code>${esc(i)}</code>`).join(' ')} · labo : <code>${esc(x.substance)}</code></p>
                <div class="btn-row" style="margin-top:6px"><button class="btn" data-dtest="${esc(x.id)}" title="Applique l'effet sur toi, sans objet">🧪 Tester sur moi</button></div></div>`; }).join('')}</div></div>

        <div class="section"><h2>🍄 Hallucinations des champignons</h2>
            <p class="hint">Les créatures n'apparaissent que chez le joueur qui a pris des champignons : personne d'autre ne les voit. Quand elles le frappent, il tombe sans perdre de vie.</p>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(180px,1fr))">
                ${num('Créatures en même temps', 'trip.maxCreatures', s.trip.maxCreatures, 1, 12)}
                ${num('Une nouvelle toutes les (s)', 'trip.spawnEvery', s.trip.spawnEvery, 2, 120)}
                ${num('Délai entre deux coups (s)', 'trip.hitCooldown', s.trip.hitCooldown, 1, 60)}
                ${num('Temps au sol (s)', 'trip.fallTime', s.trip.fallTime, 1, 15)}
                ${num('Durée de vie d\'une créature (s)', 'trip.lifetime', s.trip.lifetime, 5, 300)}</div>
            <h3 class="sub-h" style="margin-top:12px">Créatures possibles</h3>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr))">${d.creatures.map((c) => `<div class="tile toggle-tile ${s.creatures[c.model] !== false ? 'on' : ''}" data-dcre="${esc(c.model)}"><div><strong>${esc(c.label)}</strong><span>${esc(c.model)} · ${c.kind === 'animal' ? 'animal' : 'frappe'}</span></div><div class="switch"></div></div>`).join('')}</div></div>

        <div class="btn-row"><button class="btn primary" data-dact="save">💾 Enregistrer</button><button class="btn" data-dact="cancel">Annuler les modifications</button>
            <button class="btn danger" data-dact="reset">Revenir à config.lua</button></div>`;
    };

    document.addEventListener('click', async (ev) => {
        if (!on()) return;
        const t = ev.target.closest('[data-dtog],[data-dcre],[data-dact],[data-dstop],[data-dstopid],[data-dtest]');
        if (!t) return;
        const s = G.draft;
        if (t.dataset.dtog) { s.drugs[t.dataset.dtog].enabled = !s.drugs[t.dataset.dtog].enabled; return render(); }
        if (t.dataset.dcre) { s.creatures[t.dataset.dcre] = s.creatures[t.dataset.dcre] === false; return render(); }
        if (t.dataset.dstop) { send('stop_player', { id: Number(t.dataset.dstop) }); return later(); }
        if (t.dataset.dstopid !== undefined) { const id = Number((document.getElementById('drg-stop-id') || {}).value); if (id) { send('stop_player', { id }); later(); } return; }
        if (t.dataset.dtest) return send('test_self', { id: t.dataset.dtest });
        const a = t.dataset.dact;
        if (a === 'save') { send('settings_save', { settings: s }); G.draft = null; return later(); }
        if (a === 'cancel') { G.draft = null; return render(); }
        if (a === 'reset' && await confirmBox('Revenir aux réglages de config.lua ?', 'Les réglages faits dans le menu seront effacés.')) { send('settings_reset'); G.draft = null; later(); }
    });
    document.addEventListener('input', (ev) => {
        if (!on() || !ev.target.dataset.dn || !G.draft) return;
        const parts = ev.target.dataset.dn.split('.');
        let o = G.draft;
        for (let i = 0; i < parts.length - 1; i++) o = o[parts[i]];
        o[parts[parts.length - 1]] = Number(ev.target.value);
    });
})();
