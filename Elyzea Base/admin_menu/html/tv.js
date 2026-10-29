/* =========================================================
   ÉCRANS / TV (ressource elyzea_tv, permission « tv_manage »)
   Écrans posés n'importe où (taille libre, écran géant) · télés du jeu allumées · vidéos YouTube
   ========================================================= */
(() => {
    TABS.push({
        id: 'tv', group: 4, label: 'Écrans / TV', ico: '📺',
        sub: 'Pose un écran où tu veux, à la taille que tu veux (écran géant), et lance des vidéos YouTube. Les télés à écran plat du jeu marchent avec ALT.',
        show: () => has('tv_manage') && !!(D && D.tv),
        count: () => ((D && D.tv && D.tv.screens) || []).filter((s) => s.state).length + ((D && D.tv && D.tv.flats) || []).length,
    });
    const T = { draft: {} };
    const send = (name, data = {}) => action('tv', { name, data });
    const later = () => setTimeout(() => post('refresh'), 600);
    const val = (k, saved) => (T.draft[k] !== undefined ? T.draft[k] : (saved ?? ''));
    const take = (k) => { const v = T.draft[k]; delete T.draft[k]; return v; };
    const arr = (x) => (Array.isArray(x) ? x : Object.values(x || {}));
    const fmt = (s) => { s = Math.max(0, Math.floor(s || 0)); const m = Math.floor(s / 60); return `${m}:${String(s % 60).padStart(2, '0')}`; };
    const stTxt = (st, now) => (st ? `${st.paused ? '⏸ en pause' : '▶ en lecture'} · <b>${esc(st.id)}</b> · ${fmt(st.paused ? st.pausedAt : (st.offset || 0) + (now - st.startAt))} · par ${esc(st.by || '?')}` : '⏻ éteint');
    const SIZES = [['Télé 1,6 × 0,9 m', 1.6, 0.9], ['Écran 4 × 2,25 m', 4, 2.25], ['Grand 8 × 4,5 m', 8, 4.5], ['Géant 16 × 9 m', 16, 9], ['Façade 30 × 17 m', 30, 16.9]];

    function screenCard(s, now, lim) {
        const d = s.data;
        return `<div class="card"><div class="card-head"><strong>#${s.id} ${esc(s.name)}</strong>
                <span class="muted">${Number(d.w).toFixed(2)} × ${Number(d.hgt).toFixed(2)} m · ${d.public === false ? '🔒 staff seulement' : '🔓 public'} · son ${d.range} m</span></div>
            <p class="hint">${stTxt(s.state, now)}</p>
            <div class="inline" style="max-width:720px;margin-top:6px"><input class="input" data-tk="url:${s.id}" maxlength="300" placeholder="Lien YouTube" value="${esc(val(`url:${s.id}`, ''))}">
                <button class="btn primary" data-tplay="${s.id}">▶ Lire</button>
                ${s.state ? `<button class="btn" data-tctl="${s.id}" data-a="${s.state.paused ? 'resume' : 'pause'}">${s.state.paused ? '▶ Reprendre' : '⏸ Pause'}</button>
                <button class="btn danger" data-tctl="${s.id}" data-a="stop">⏻ Éteindre</button>` : ''}</div>
            <div class="form-grid" style="grid-template-columns:repeat(6, minmax(110px,1fr));align-items:end;margin-top:8px">
                <div><label>Nom</label><input class="input" data-tk="name:${s.id}" maxlength="40" value="${esc(val(`name:${s.id}`, s.name))}"></div>
                <div><label>Largeur (m)</label><input class="input" type="number" step="0.1" min="${lim.minW}" max="${lim.maxW}" data-tk="w:${s.id}" value="${esc(val(`w:${s.id}`, d.w))}"></div>
                <div><label>Hauteur (m)</label><input class="input" type="number" step="0.1" min="${lim.minH}" max="${lim.maxH}" data-tk="h:${s.id}" value="${esc(val(`h:${s.id}`, d.hgt))}"></div>
                <div><label>Portée du son (m)</label><input class="input" type="number" min="5" max="300" data-tk="range:${s.id}" value="${esc(val(`range:${s.id}`, d.range))}"></div>
                <div><label>Volume (%)</label><input class="input" type="number" min="0" max="100" data-tk="vol:${s.id}" value="${esc(val(`vol:${s.id}`, s.state ? s.state.volume : d.volume))}"></div>
                <div><label>Accès</label><select class="input" data-tk="pub:${s.id}"><option value="1" ${val(`pub:${s.id}`, d.public === false ? '0' : '1') === '1' ? 'selected' : ''}>Tout le monde (E)</option>
                    <option value="0" ${val(`pub:${s.id}`, d.public === false ? '0' : '1') === '0' ? 'selected' : ''}>Staff seulement</option></select></div>
            </div>
            <div class="btn-row" style="margin-top:8px"><button class="btn" data-tsave="${s.id}">💾 Enregistrer</button>
                <button class="btn" data-tedit="${s.id}" title="Déplacer, tourner, agrandir en jeu">🎯 Placer / modifier en jeu</button>
                <button class="btn" data-ttp="${s.id}">🚀 Aller à la télécommande</button>
                <button class="btn danger" data-tdel="${s.id}">🗑 Supprimer</button></div></div>`;
    }

    VIEWS.tv = () => {
        const t = D.tv;
        if (!t.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(t.resource || 'elyzea_tv')}</b> ne répond pas : vérifie « ensure elyzea_tv » dans server.cfg.</span></div>`;
        const lim = t.limits || { minW: 0.4, maxW: 60, minH: 0.25, maxH: 35 };
        const screens = arr(t.screens), flats = arr(t.flats);
        return `<div class="stats"><div class="stat"><b>${screens.length}</b><span>Écran(s) posé(s)</span></div>
            <div class="stat"><b>${screens.filter((s) => s.state).length}</b><span>Écran(s) allumé(s)</span></div>
            <div class="stat"><b>${flats.length}</b><span>Télé(s) du jeu allumée(s)</span></div></div>
        <div class="section"><h2>Nouvel écran</h2>
            <p class="hint">Choisis une taille, puis clique <b>Placer en jeu</b> : l'écran suit ton regard et se colle au mur / à la façade visé(e), tourné vers toi.
                Clic gauche fige l'endroit, <b>molette</b> = taille, <b>Q / E</b> = tourner, <b>Page préc. / suiv.</b> = hauteur, <b>flèches</b> = déplacer, <b>MAJ</b> = précis,
                <b>ENTRÉE</b> enregistre. <b>Là où tu te tiens en validant devient la télécommande</b> (E) de l'écran.</p>
            <div class="form-grid" style="grid-template-columns:1fr 130px 130px auto;max-width:900px;align-items:end">
                <div><label>Nom</label><input class="input" data-tk="new:name" maxlength="40" placeholder="Écran géant du parc" value="${esc(val('new:name', ''))}"></div>
                <div><label>Largeur (m)</label><input class="input" type="number" step="0.1" min="${lim.minW}" max="${lim.maxW}" data-tk="new:w" value="${esc(val('new:w', 4))}"></div>
                <div><label>Hauteur (m)</label><input class="input" type="number" step="0.1" min="${lim.minH}" max="${lim.maxH}" data-tk="new:h" value="${esc(val('new:h', 2.25))}"></div>
                <button class="btn primary" data-tnew>📍 Placer en jeu</button></div>
            <div class="btn-row" style="margin-top:8px">${SIZES.map(([l, w, h]) => `<button class="btn" data-tsize="${w}" data-h="${h}">${l}</button>`).join('')}</div></div>
        ${!screens.length ? '<div class="empty">Aucun écran posé.</div>' : screens.map((s) => screenCard(s, t.now, lim)).join('')}
        <div class="section"><h2>Télés du jeu allumées</h2>
            <p class="hint">Les télés à écran plat se commandent en jeu avec <b>ALT</b> (Télécommande). Tu peux les couper d'ici.</p>
            ${!flats.length ? '<div class="empty">Aucune télé allumée.</div>' : `<table class="loot wide"><tr><th>Modèle</th><th>Position</th><th>État</th><th></th></tr>
                ${flats.map((f) => `<tr><td>${esc(f.model)}</td><td>${Number(f.x).toFixed(1)}, ${Number(f.y).toFixed(1)}, ${Number(f.z).toFixed(1)}</td><td>${stTxt(f.state, t.now)}</td>
                    <td style="text-align:right"><button class="btn danger" data-tflat="${esc(f.key)}">⏻ Éteindre</button></td></tr>`).join('')}</table>`}
            <div class="btn-row" style="margin-top:10px"><button class="btn danger" data-tall>⏻ Tout éteindre (écrans et télés)</button></div></div>`;
    };

    const on = () => isOpen && tab === 'tv' && D && D.tv && D.tv.available;
    document.addEventListener('click', async (ev) => {
        if (!on()) return;
        const b = ev.target.closest('[data-tnew],[data-tsize],[data-tplay],[data-tctl],[data-tsave],[data-tedit],[data-ttp],[data-tdel],[data-tflat],[data-tall]');
        if (!b) return;
        const ds = b.dataset;
        if (ds.tsize) { T.draft['new:w'] = ds.tsize; T.draft['new:h'] = ds.h; return render(); }
        if (ds.tnew !== undefined) { send('screen_new', { name: take('new:name') || '', w: Number(val('new:w', 4)), h: Number(val('new:h', 2.25)) }); return post('close'); }
        if (ds.tplay) { send('play', { id: Number(ds.tplay), url: take(`url:${ds.tplay}`) || '' }); return later(); }
        if (ds.tctl) { send('control', { id: Number(ds.tctl), action: ds.a }); return later(); }
        if (ds.tsave) {
            const id = ds.tsave;
            const w = take(`w:${id}`), h = take(`h:${id}`);
            if (w !== undefined || h !== undefined) {
                const s = arr(D.tv.screens).find((x) => x.id === Number(id));
                send('screen_size', { id: Number(id), w: Number(w ?? s.data.w), h: Number(h ?? s.data.hgt) });
            }
            const pub = take(`pub:${id}`);
            const vol = take(`vol:${id}`);
            send('screen_set', { id: Number(id), name: take(`name:${id}`), range: take(`range:${id}`), volume: vol, public: pub === undefined ? undefined : pub === '1' });
            // vidéo en cours : le nouveau volume s'applique tout de suite
            const sc = arr(D.tv.screens).find((x) => x.id === Number(id));
            if (vol !== undefined && sc && sc.state) send('control', { id: Number(id), action: 'volume', value: Number(vol) });
            return later();
        }
        if (ds.tedit) { send('screen_edit', { id: Number(ds.tedit) }); return post('close'); }
        if (ds.ttp) return send('tp', { id: Number(ds.ttp) });
        if (ds.tdel) { if (await confirmBox('Supprimer cet écran ?', 'Il disparaît pour tout le monde.')) { send('screen_delete', { id: Number(ds.tdel) }); later(); } return; }
        if (ds.tflat) { send('control', { key: ds.tflat, action: 'stop' }); return later(); }
        if (ds.tall !== undefined) { if (await confirmBox('Tout éteindre ?', 'Toutes les vidéos s\'arrêtent, écrans et télés.')) { send('stop_all'); later(); } }
    });
    const keep = (ev) => { if (on() && ev.target.dataset && ev.target.dataset.tk) T.draft[ev.target.dataset.tk] = ev.target.value; };
    document.addEventListener('input', keep);
    document.addEventListener('change', keep);
})();
