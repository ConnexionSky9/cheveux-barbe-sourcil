/* =========================================================
   PARC DE DEL PERRO (ressource elyzea_pier, permission « pier_manage »)
   État en direct de la grande roue et des montagnes russes, prix des tickets, paiement,
   durées, vendeur de tickets (placé à ta position), remise à zéro, tickets offerts.
   Réglages appliqués tout de suite et gardés après un redémarrage (sur le serveur).
   ========================================================= */
(() => {
    TABS.push({
        id: 'pier', group: 5, label: 'Parc de Del Perro', ico: '🎡',
        sub: 'Grande roue et montagnes russes : ouvrir / fermer, prix des tickets, durées, vendeur de tickets, passagers, remise à zéro.',
        show: () => has('pier_manage') && !!(D && D.pier),
        count: () => { const p = D && D.pier; return p && p.available ? (p.wheel.riders.length + p.coaster.riders.length) : 0; },
    });
    const st = { armed: null, give: { target: '', kind: 'wheel', qty: 1 } };
    const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
    const send = (name, data = {}, refresh = true) => { action('pier', { name, data }); if (refresh) setTimeout(() => post('refresh'), 450); };
    const tog = (id, on, title, sub) => `<div class="tile toggle-tile ${on ? 'on' : ''}" data-ptog="${id}"><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;
    const field = (k, label, v, min, max, unit = '') => `<div><label>${label}${unit ? ` (${unit})` : ''}</label><input class="input" type="number" data-pf="${k}" min="${min}" max="${max}" value="${v}"></div>`;

    function rideCard(ico, title, r, kind) {
        return `<div class="card">
            <div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap">
                <b>${ico} ${title}</b><span class="zbadge">${esc(r.status)}</span></div>
            <p class="hint" style="margin:6px 0">👥 ${r.capacity - r.free}/${r.capacity} places occupées · ⏳ ${r.queue} en file</p>
            <p class="hint" style="margin:0 0 8px">${r.riders.length ? r.riders.map((p) => `${esc(p.name)} <small>#${p.id}${p.place ? ' · ' + esc(p.place) : ''}</small>`).join(' · ') : 'Aucun passager.'}</p>
            <div class="btn-row"><button class="btn" data-ptp="${kind}">🧭 Y aller</button>
                <button class="btn danger" data-preset="${kind}">${st.armed === 'reset:' + kind ? '⚠️ Confirmer' : '🔄 Remettre à zéro'}</button></div></div>`;
    }

    VIEWS.pier = () => {
        const d = D.pier;
        if (!d.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_pier')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ' : vérifie « ensure elyzea_pier » dans server.cfg'}.</span></div>`;
        const S = d.settings, N = S.npc;
        return `
            <div class="stats">
                <div class="stat"><b>${S.wheelEnabled ? '🟢' : '🔴'}</b><span>Grande roue ${S.wheelEnabled ? 'ouverte' : 'fermée'}</span></div>
                <div class="stat"><b>${S.coasterEnabled ? '🟢' : '🔴'}</b><span>Montagnes russes ${S.coasterEnabled ? 'ouvertes' : 'fermées'}</span></div>
                <div class="stat"><b>${fmt(S.wheelPrice)} $</b><span>Ticket grande roue</span></div>
                <div class="stat"><b>${fmt(S.coasterPrice)} $</b><span>Ticket montagnes russes</span></div>
            </div>
            <h3 class="sub-h">🎢 En direct</h3>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(320px,1fr))">
                ${rideCard('🎡', 'Grande roue', d.wheel, 'wheel')}${rideCard('🎢', 'Montagnes russes', d.coaster, 'coaster')}
            </div>
            <div class="btn-row" style="margin:8px 0 18px"><button class="btn danger" data-preset="all">${st.armed === 'reset:all' ? '⚠️ Confirmer' : '🔄 Tout remettre à zéro'}</button></div>

            <div class="section"><h2>Ouverture et tickets</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr));margin-bottom:12px">
                    ${tog('wheelEnabled', S.wheelEnabled, 'Grande roue ouverte', 'Fermée : plus d\'embarquement (les passagers finissent leur tour)')}
                    ${tog('coasterEnabled', S.coasterEnabled, 'Montagnes russes ouvertes', 'Fermées : plus d\'embarquement')}
                    ${tog('cash', S.cash, 'Paiement en liquide', 'Accepté à la billetterie')}
                    ${tog('bank', S.bank, 'Paiement par carte', 'Accepté à la billetterie')}
                </div>
                <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr));align-items:end">
                    ${field('wheelPrice', 'Prix du ticket grande roue', S.wheelPrice, 0, 100000, '$')}
                    ${field('coasterPrice', 'Prix du ticket montagnes russes', S.coasterPrice, 0, 100000, '$')}
                    ${field('maxPerPurchase', 'Tickets maximum par achat', S.maxPerPurchase, 1, 50)}
                    ${field('maxOwned', 'Tickets maximum par joueur (0 = illimité)', S.maxOwned, 0, 500)}
                </div></div>
            <div class="section"><h2>Durées</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr));margin-bottom:12px">
                    ${tog('idleRotation', S.idleRotation, 'La roue tourne à vide', 'Comme dans le jeu : la roue tourne même sans passager')}
                </div>
                <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr));align-items:end">
                    ${field('turnDuration', 'Tour complet de la grande roue', S.turnDuration, 60, 900, 's')}
                    ${field('stopDuration', 'Arrêt en gare (roue)', S.stopDuration, 5, 60, 's')}
                    ${field('boardingTime', 'Embarquement des montagnes russes', S.boardingTime, 5, 180, 's')}
                    ${field('fullDepartDelay', 'Départ anticipé si train plein', S.fullDepartDelay, 0, 60, 's')}
                    ${field('coasterDuration', `Parcours des montagnes russes (0 = vitesse du jeu, ${d.coaster.natural} s)`, S.coasterDuration, 0, 300, 's')}
                </div>
                ${d.pendingDuration ? '<p class="hint" style="color:var(--warn,#e0a33b)">⏳ Nouvelle durée du parcours en attente : appliquée quand le train revient en gare.</p>' : ''}
                <div class="btn-row"><button class="btn primary" data-psave>💾 Enregistrer les tickets et les durées</button></div></div>

            <div class="section"><h2>🧑‍💼 Vendeur de tickets</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr));margin-bottom:12px">
                    ${tog('npcEnabled', N.enabled, 'Vendeur présent', 'Désactivé : la billetterie est fermée')}
                    ${tog('npcBlip', N.blip, 'Icône sur la carte', '« Parc de Del Perro »')}
                </div>
                <p class="hint">Position : <b>${N.x.toFixed(1)}, ${N.y.toFixed(1)}, ${N.z.toFixed(1)}</b> · orientation ${Math.round(N.h)}°</p>
                <div class="btn-row" style="margin-bottom:12px"><button class="btn primary" data-pact="npcHere">📍 Placer le vendeur à ma position</button><button class="btn" data-ptp="npc">🧭 Y aller</button></div>
                <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(220px,1fr));align-items:end">
                    <div><label>Modèle</label><input class="input" data-pn="model" value="${esc(N.model)}"></div>
                    <div><label>Animation (scénario GTA, vide = aucune)</label><input class="input" data-pn="scenario" value="${esc(N.scenario || '')}"></div>
                    <div><label>Orientation (0 à 359°)</label><input class="input" type="number" data-pn="h" min="0" max="359" value="${Math.round(N.h)}"></div>
                </div>
                <div class="btn-row"><button class="btn primary" data-pnsave>💾 Enregistrer le vendeur</button></div></div>

            <div class="section"><h2>🎟️ Offrir des tickets</h2>
                <div class="form-grid" style="grid-template-columns:minmax(220px,1fr) minmax(200px,1fr) 120px auto;align-items:end;max-width:880px">
                    <div><label>Joueur connecté (ID)</label><input class="input" list="pier-players" data-pg="target" placeholder="ID serveur" value="${esc(st.give.target)}">
                        <datalist id="pier-players">${(d.players || []).map((p) => `<option value="${p.id}">${esc(p.name)}</option>`).join('')}</datalist></div>
                    <div><label>Ticket</label><select class="input" data-pg="kind"><option value="wheel" ${st.give.kind === 'wheel' ? 'selected' : ''}>Grande roue</option><option value="coaster" ${st.give.kind === 'coaster' ? 'selected' : ''}>Montagnes russes</option></select></div>
                    <div><label>Quantité</label><input class="input" type="number" data-pg="qty" min="1" max="50" value="${st.give.qty}"></div>
                    <button class="btn primary" data-pgive>🎁 Donner</button>
                </div></div>

            <div class="section"><h2>💾 Sauvegardes</h2>
                <p class="hint">Chaque modification est enregistrée sur le serveur et gardée après un redémarrage.</p>
                <div class="btn-row"><button class="btn" data-pact="reload">🔄 Recharger les réglages enregistrés</button>
                    <button class="btn danger" data-pact="defaults">${st.armed === 'defaults' ? '⚠️ Confirmer' : '↺ Revenir aux réglages de config.lua'}</button></div></div>`;
    };

    const arm = (key) => {
        if (st.armed === key) { st.armed = null; return true; }
        st.armed = key; render();
        setTimeout(() => { if (st.armed === key) { st.armed = null; render(); } }, 4000);
        return false;
    };
    document.addEventListener('input', (ev) => {
        const g = ev.target.closest('[data-pg]');
        if (g && tab === 'pier') st.give[g.dataset.pg] = g.value;
    });
    document.addEventListener('click', (ev) => {
        if (!isOpen || tab !== 'pier' || !D.pier || !D.pier.available) return;
        const S = D.pier.settings;
        const t = ev.target.closest('[data-ptog],[data-psave],[data-pnsave],[data-pact],[data-ptp],[data-preset],[data-pgive]');
        if (!t) return;
        if (t.dataset.ptog) {
            const k = t.dataset.ptog;
            if (k === 'npcEnabled') return send('npc', { enabled: !S.npc.enabled });
            if (k === 'npcBlip') return send('npc', { blip: !S.npc.blip });
            return send('settings', { [k]: !S[k] });
        }
        if (t.dataset.psave !== undefined) {
            const v = {}; document.querySelectorAll('[data-pf]').forEach((e) => { v[e.dataset.pf] = Number(e.value); });
            return send('settings', v);
        }
        if (t.dataset.pnsave !== undefined) {
            const g = (k) => document.querySelector(`[data-pn="${k}"]`).value;
            return send('npc', { model: g('model').trim(), scenario: g('scenario').trim(), h: Number(g('h')) });
        }
        if (t.dataset.ptp) { send('teleport', { to: t.dataset.ptp }, false); post('close'); return; }
        if (t.dataset.preset && arm('reset:' + t.dataset.preset)) return send('reset', { what: t.dataset.preset });
        if (t.dataset.pgive !== undefined) return send('give', { target: Number(st.give.target), kind: st.give.kind, qty: Number(st.give.qty) });
        if (t.dataset.pact) {
            const a = t.dataset.pact;
            if (a === 'npcHere' || a === 'reload') return send(a);
            if (a === 'defaults' && arm('defaults')) return send('defaults', { confirm: true });
        }
    });
})();
