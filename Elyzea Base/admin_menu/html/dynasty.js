/* =========================================================
   ONGLET 🏠 GESTION IMMOBILIÈRE (permission « property_manage »)
   Ressource elyzea_dynasty. Tout se fait en jeu, sans toucher au Lua ni au SQL :
    · Créer un logement à ma position (la position devient l'entrée), puis placer
      les autres points avec l'assistant, puis « Valider » (activation) ;
    · Liste des logements : assistant, aller devant, activer / désactiver, supprimer ;
    · Gestion des améliorations immobilières : activer, prix, maximums, animations,
      emplacements des caméras (placés en jeu, avec aperçu), améliorations par logement.
   Le panneau détaillé (intérieurs, garages, décoration, contrats) reste disponible : /d8admin.
   ========================================================= */
(() => {
    TABS.push({
        id: 'dynasty', group: 5, label: 'Gestion immobilière', ico: '🏠',
        sub: 'Dynasty 8 : créer les logements et garages en jeu, placer leurs points, gérer les améliorations (caméras, danseuse, culture).',
        show: () => has('property_manage'),
        count: () => { const d = D && D.d8; return d && d.available ? d.props.length : 0; },
    });
    const st = { sel: null, q: '', armed: null, form: { name: '', address: '', category: 'house', interiorId: '', salePrice: 250000, rentPrice: 1500, garage: false, garageSize: 'medium', garageInterior: '' } };
    const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
    const send = (name, data = {}, refresh = true) => { action('d8', { name, data }); if (refresh) setTimeout(() => post('refresh'), 500); };
    const CAT_ICO = { apartment: '🏢', house: '🏠', villa: '🏡', garage: '🚗' };
    const UP = { cameras: ['📹', 'Caméras'], dancer: ['💃', 'Danseuse'], cannabis: ['🌿', 'Culture'] };
    const armBtn = (key, label, cls = 'danger') => `<button class="btn ${cls}" data-d8arm="${key}">${st.armed === key ? '⚠️ Confirmer' : label}</button>`;
    const tog = (k, on, title, sub) => `<div class="tile toggle-tile ${on ? 'on' : ''}" data-d8tog="${k}"><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;
    const num = (kind, k, label, v, min, max, step = 1) => `<div><label>${label}</label><input class="input" type="number" data-d8cfg="${kind}.${k}" min="${min}" max="${max}" step="${step}" value="${v}"></div>`;

    function createForm(d) {
        const f = st.form;
        const kinds = f.category === 'garage' ? [] : d.interiors.filter((i) => i.kind !== 'garage');
        const gInts = d.interiors.filter((i) => i.kind === 'garage');
        return `<div class="section"><h2>➕ Créer un logement à ma position</h2>
            <p class="hint">Place-toi <b>devant la porte</b> : ta position devient l'entrée. Le logement est créé désactivé ; place ensuite les autres points avec l'assistant puis valide.</p>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr));align-items:end">
                <div><label>Nom</label><input class="input" data-d8f="name" maxlength="80" value="${esc(f.name)}" placeholder="Villa Vinewood"></div>
                <div><label>Adresse <a href="#" data-d8street style="font-size:12px">(ma rue)</a></label><input class="input" data-d8f="address" maxlength="120" value="${esc(f.address)}"></div>
                <div><label>Type</label><select class="input" data-d8f="category">${Object.entries(d.categories).map(([k, l]) => `<option value="${k}" ${f.category === k ? 'selected' : ''}>${CAT_ICO[k] || ''} ${esc(l)}</option>`).join('')}</select></div>
                ${f.category !== 'garage' ? `<div><label>Intérieur</label><select class="input" data-d8f="interiorId"><option value="">— choisir —</option>${kinds.map((i) => `<option value="${i.id}" ${String(f.interiorId) === String(i.id) ? 'selected' : ''}>${esc(i.label)}</option>`).join('')}</select></div>` : ''}
                <div><label>Prix de vente ($)</label><input class="input" type="number" min="0" data-d8f="salePrice" value="${f.salePrice}"></div>
                <div><label>Loyer par jour ($)</label><input class="input" type="number" min="0" data-d8f="rentPrice" value="${f.rentPrice}"></div>
            </div>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:10px">
                ${f.category !== 'garage' ? tog('formGarage', f.garage, 'Garage lié', 'Ajoute un garage à ce logement') : ''}</div>
            ${f.garage || f.category === 'garage' ? `<div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr));align-items:end">
                <div><label>Taille du garage</label><select class="input" data-d8f="garageSize">${Object.entries(d.sizes).map(([k, s]) => `<option value="${k}" ${f.garageSize === k ? 'selected' : ''}>${esc(s.label)} (${s.capacity})</option>`).join('')}</select></div>
                <div><label>Intérieur du garage</label><select class="input" data-d8f="garageInterior"><option value="">— choisir —</option>${gInts.map((i) => `<option value="${i.id}" ${String(f.garageInterior) === String(i.id) ? 'selected' : ''}>${esc(i.label)}</option>`).join('')}</select></div></div>` : ''}
            <div class="btn-row"><button class="btn primary" data-d8create>📍 Créer ici</button></div></div>`;
    }

    function listView(d) {
        const q = st.q.trim().toLowerCase();
        const list = d.props.filter((p) => !q || `${p.id} ${p.name} ${p.address} ${p.holder || ''}`.toLowerCase().includes(q));
        return `<div class="section"><h2>🏘️ Logements (${d.props.length})</h2>
            <input class="input" data-d8q placeholder="Rechercher : nom, adresse, occupant, numéro" value="${esc(st.q)}" style="margin-bottom:10px">
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr))">${list.map((p) => `<div class="card ${st.sel === p.id ? 'sel' : ''}">
                <div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><b>${CAT_ICO[p.category] || ''} #${p.id} ${esc(p.name)}</b>
                    <span class="zbadge">${p.enabled ? (p.holder ? (p.kind === 'rent' ? 'Loué' : 'Vendu') : 'Disponible') : 'Désactivé'}</span></div>
                <p class="hint" style="margin:6px 0">${esc(p.address || '')}${p.holder ? ` · ${esc(p.holder)}` : ''} · ${fmt(p.salePrice)} $ / ${fmt(p.rentPrice)} $ j</p>
                <p class="hint" style="margin:0 0 8px">${(p.upgrades || []).map((u) => (UP[u] || ['✨'])[0]).join(' ') || '—'}${p.cams ? ` · ${p.cams} caméra(s)` : ''}${p.pots ? ` · ${p.pots} pot(s)` : ''}${p.dancer ? ' · 💃 en cours' : ''}</p>
                <div class="btn-row"><button class="btn primary" data-d8sel="${p.id}">🧭 Assistant</button><button class="btn" data-d8go="${p.id}" data-area="outside">Y aller</button></div></div>`).join('') || '<p class="hint">Aucun logement.</p>'}</div></div>`;
    }

    function pointRow(p, key, label, done, hint) {
        return `<div class="tile" style="display:flex;justify-content:space-between;align-items:center;gap:8px"><div><strong>${done ? '✅' : '⬜'} ${label}</strong><span>${hint || ''}</span></div>
            <div class="btn-row" style="margin:0"><button class="btn" data-d8pt="${key}">📍 Ici</button>${done && key !== 'enter' ? `<button class="btn danger" data-d8pt="${key}" data-remove="1">✕</button>` : ''}</div></div>`;
    }

    function wizard(d) {
        const p = d.props.find((x) => x.id === st.sel);
        if (!p) return '';
        const pt = p.points;
        const inHome = d.inside && d.inside.pid === p.id && d.inside.area === 'home';
        const inGarage = d.inside && d.inside.pid === p.id && d.inside.area === 'garage';
        const spots = d.spots.filter((s) => s.pid === p.id);
        const ready = pt.enter || pt.gEnter;
        return `<div class="section"><h2>🧭 Assistant · #${p.id} ${esc(p.name)}</h2>
            <p class="hint">Chaque bouton « Ici » enregistre ta position actuelle (et ton orientation). Les points intérieurs se placent une fois dans le logement.</p>
            <h3 class="sub-h">Extérieur</h3>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(320px,1fr))">
                ${p.category !== 'garage' ? pointRow(p, 'enter', 'Entrée', pt.enter, 'Devant la porte') + pointRow(p, 'bell', 'Sonnette (facultative)', pt.bell, 'Si elle est ailleurs que la porte') : ''}
                ${pt.garage ? pointRow(p, 'garage.enter', 'Entrée du garage', pt.gEnter, 'Rangement des véhicules') + pointRow(p, 'garage.spawn', 'Sortie des véhicules', pt.gSpawn, 'Au volant, dans le sens de sortie') : ''}</div>
            ${p.category !== 'garage' ? `<h3 class="sub-h">Intérieur ${inHome ? '<span class="zbadge">tu es dedans</span>' : ''}</h3>
                <div class="btn-row"><button class="btn" data-d8go="${p.id}" data-area="home">🚪 Aller à l'intérieur</button></div>
                ${inHome ? `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(320px,1fr))">${pointRow(p, 'exit', 'Sortie', pt.exit, 'À côté de la porte intérieure')}${pointRow(p, 'manage', 'Gestion du logement', pt.manage, '« Gérer mon logement »')}${pointRow(p, 'stash', 'Coffre', pt.stash, 'Rangement des objets')}</div>`
                    : `<p class="hint">Sortie ${pt.exit ? '✅' : '⬜'} · Gestion ${pt.manage ? '✅' : '⬜'} · Coffre ${pt.stash ? '✅' : '⬜'} — entre dans le logement pour les placer.</p>`}` : ''}
            ${pt.garage ? `<h3 class="sub-h">Garage ${inGarage ? '<span class="zbadge">tu es dedans</span>' : ''} · ${pt.slots} place(s)</h3>
                <div class="btn-row"><button class="btn" data-d8go="${p.id}" data-area="garage">🚗 Aller dans le garage</button></div>
                ${inGarage ? `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(320px,1fr))">${pointRow(p, 'garage.inside', 'Arrivée à pied', pt.gInside, '')}${pointRow(p, 'garage.exit', 'Sortie à pied', pt.gExit, '')}</div>
                    <div class="btn-row"><button class="btn primary" data-d8slot>➕ Ajouter une place ici</button></div>` : ''}` : ''}
            <div class="btn-row" style="margin-top:14px">${!p.enabled ? `<button class="btn primary" data-d8enable="1" ${ready ? '' : 'disabled'}>✅ Valider et activer</button>` : '<button class="btn" data-d8enable="0">⏸️ Désactiver</button>'}
                <button class="btn" data-d8go="${p.id}" data-area="outside">🧭 Y aller</button><button class="btn" data-d8open>🛠️ Panneau détaillé</button>
                ${armBtn('del:' + p.id, '🗑️ Supprimer')}</div>

            <h3 class="sub-h">📹 Emplacements des caméras (${spots.length})</h3>
            <p class="hint">Facultatif : sans emplacement, le joueur pose ses caméras librement autour de l'entrée. Avec des emplacements, il choisit parmi eux et oriente la caméra dans la plage permise. Place-toi à l'endroit voulu, tourné vers ce qu'elle doit filmer.</p>
            ${spots.map((s) => `<div class="form-grid" data-spot="${s.id}" style="grid-template-columns:1.4fr repeat(5,minmax(70px,1fr)) auto;align-items:end">
                <div><label>Nom</label><input class="input" data-sf="label" value="${esc(s.label)}"></div>
                <div><label>Cap (°)</label><input class="input" type="number" data-sf="rz" value="${Math.round(s.rz)}"></div>
                <div><label>Inclinaison</label><input class="input" type="number" data-sf="rx" value="${Math.round(s.rx)}"></div>
                <div><label>Angle de vue</label><input class="input" type="number" data-sf="fov" value="${Math.round(s.fov)}"></div>
                <div><label>± horizontal</label><input class="input" type="number" data-sf="yaw" value="${Math.round(s.yaw)}"></div>
                <div><label>± vertical</label><input class="input" type="number" data-sf="pitch" value="${Math.round(s.pitch)}"></div>
                <div class="btn-row" style="margin:0"><button class="btn primary" data-spotsave>💾</button><button class="btn" data-spottest>👁️</button><button class="btn" data-spothere title="Replacer à ma position">📍</button><button class="btn danger" data-spotdel>✕</button></div></div>`).join('')}
            <div class="btn-row"><input class="input" data-d8spotlabel placeholder="Nom de l'emplacement (ex. Portail)" style="max-width:260px"><button class="btn primary" data-d8spot>➕ Emplacement ici</button></div>

            <h3 class="sub-h">✨ Améliorations de ce logement</h3>
            ${p.holder ? `<div class="btn-row">${(p.upgrades || []).map((u) => armBtn(`reset:${p.id}:${u}`, `🔄 Réinitialiser ${(UP[u] || ['', u])[1]}`)).join('') || '<span class="hint">Aucune amélioration achetée.</span>'}
                ${p.dancer ? '<button class="btn" data-d8dancerstop>■ Renvoyer la danseuse</button>' : ''}</div>` : '<p class="hint">Aucun contrat en cours sur ce logement.</p>'}</div>`;
    }

    function upgradesSettings(d) {
        const c = d.cfg;
        const anims = c.dancer.anims || [];
        return `<div class="section"><h2>⚙️ Gestion des améliorations immobilières</h2>
            <p class="hint">Réglages appliqués tout de suite et gardés après un redémarrage. Les améliorations déjà achetées restent installées.</p>
            <h3 class="sub-h">📹 Caméras de surveillance</h3>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:10px">${tog('cameras.enabled', c.cameras.enabled, 'Proposées aux joueurs', 'Désactivé : plus d\'achat ni de visionnage')}</div>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(170px,1fr));align-items:end">
                ${num('cameras', 'price', 'Prix ($)', c.cameras.price, 0, 50000000)}${num('cameras', 'max', 'Caméras max / logement', c.cameras.max, 0, 12)}
                ${num('cameras', 'radius', 'Pose libre : rayon (m)', c.cameras.radius, 5, 80)}${num('cameras', 'fovMin', 'Angle min (°)', c.cameras.fovMin, 10, 80)}${num('cameras', 'fovMax', 'Angle max (°)', c.cameras.fovMax, 30, 120)}
                <div><label>Paiement</label><select class="input" data-d8cfg="cameras.payTo"><option value="agency" ${c.cameras.payTo !== 'none' ? 'selected' : ''}>Versé à l'agence</option><option value="none" ${c.cameras.payTo === 'none' ? 'selected' : ''}>Retiré du jeu</option></select></div></div>
            <div class="btn-row"><button class="btn primary" data-d8save="cameras">💾 Enregistrer les caméras</button></div>

            <h3 class="sub-h">💃 Danseuse privée</h3>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:10px">${tog('dancer.enabled', c.dancer.enabled, 'Proposée aux joueurs', 'Désactivé : les danseuses présentes repartent')}</div>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(170px,1fr));align-items:end">
                ${num('dancer', 'price', 'Prix ($)', c.dancer.price, 0, 50000000)}${num('dancer', 'max', 'Danseuses max en même temps', c.dancer.max, 1, 12)}
                ${num('dancer', 'maxMinutes', 'Durée max (min)', c.dancer.maxMinutes, 1, 240)}${num('dancer', 'cooldownSeconds', 'Attente entre deux (s)', c.dancer.cooldownSeconds, 0, 600)}
                <div><label>Paiement</label><select class="input" data-d8cfg="dancer.payTo"><option value="agency" ${c.dancer.payTo !== 'none' ? 'selected' : ''}>Versé à l'agence</option><option value="none" ${c.dancer.payTo === 'none' ? 'selected' : ''}>Retiré du jeu</option></select></div></div>
            <label class="hint">Animations proposées</label>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(220px,1fr));margin:6px 0 10px">${anims.map((a) => `<label class="tile" style="display:flex;gap:8px;align-items:center"><input type="checkbox" data-d8anim="${a.id}" ${a.on ? 'checked' : ''}><span>${esc(a.label)}</span></label>`).join('')}</div>
            <div class="btn-row"><button class="btn primary" data-d8save="dancer">💾 Enregistrer la danseuse</button></div>

            <h3 class="sub-h">🌿 Culture de cannabis</h3>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:10px">${tog('cannabis.enabled', c.cannabis.enabled, 'Proposée aux joueurs', 'Désactivé : plus d\'achat ni d\'entretien')}</div>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(170px,1fr));align-items:end">
                ${num('cannabis', 'price', 'Prix ($)', c.cannabis.price, 0, 50000000)}${num('cannabis', 'maxPots', 'Pots max / logement', c.cannabis.maxPots, 0, 12)}${num('cannabis', 'speed', 'Vitesse de pousse (×)', c.cannabis.speed, 0.1, 20, 0.1)}
                <div><label>Paiement</label><select class="input" data-d8cfg="cannabis.payTo"><option value="none" ${c.cannabis.payTo !== 'agency' ? 'selected' : ''}>Retiré du jeu</option><option value="agency" ${c.cannabis.payTo === 'agency' ? 'selected' : ''}>Versé à l'agence</option></select></div></div>
            <div class="btn-row"><button class="btn primary" data-d8save="cannabis">💾 Enregistrer la culture</button>${armBtn('defaults', '↺ Revenir à config.lua')}</div></div>`;
    }

    VIEWS.dynasty = () => {
        const d = D.d8;
        const top = `<div class="section"><h2>Gestion immobilière</h2>
            <p class="hint">Ressource <b>elyzea_dynasty</b>. Panneau détaillé (intérieurs, garages, décoration, contrats) : <span class="keycap">/d8admin</span>.</p>
            <button class="btn" data-d8open>🛠️ Ouvrir le panneau détaillé</button></div>`;
        if (!d || !d.available) return top + `<div class="protect">⚠️ <span>La ressource <b>elyzea_dynasty</b> ne répond pas${d && d.error ? ' (redémarre-la après la mise à jour)' : ' : vérifie « ensure elyzea_dynasty » dans server.cfg'}.</span></div>`;
        if (st.sel && !d.props.find((p) => p.id === st.sel)) st.sel = null;
        const stats = `<div class="stats"><div class="stat"><b>${d.props.length}</b><span>Logements</span></div>
            <div class="stat"><b>${d.props.filter((p) => p.holder).length}</b><span>Occupés</span></div>
            <div class="stat"><b>${d.props.filter((p) => (p.upgrades || []).length).length}</b><span>Avec améliorations</span></div>
            <div class="stat"><b>${d.spots.length}</b><span>Emplacements caméra</span></div></div>`;
        return stats + top + createForm(d) + wizard(d) + listView(d) + upgradesSettings(d);
    };

    const arm = (key) => {
        if (st.armed === key) { st.armed = null; return true; }
        st.armed = key; render();
        setTimeout(() => { if (st.armed === key) { st.armed = null; render(); } }, 4000);
        return false;
    };
    window.addEventListener('message', (e) => { if (e.data && e.data.action === 'd8Select') { st.sel = Number(e.data.id); if (tab === 'dynasty') render(); } });
    document.addEventListener('input', (ev) => {
        if (tab !== 'dynasty') return;
        const f = ev.target.closest('[data-d8f]');
        if (f) { st.form[f.dataset.d8f] = f.value; if (f.dataset.d8f === 'category') render(); return; }
        if (ev.target.matches('[data-d8q]')) { st.q = ev.target.value; const pos = ev.target.selectionStart; render(); const n = document.querySelector('[data-d8q]'); if (n) { n.focus(); n.setSelectionRange(pos, pos); } }
    });
    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'dynasty') return;
        const t = ev.target.closest('[data-d8open],[data-d8street],[data-d8create],[data-d8tog],[data-d8sel],[data-d8go],[data-d8pt],[data-d8slot],[data-d8enable],[data-d8arm],[data-d8spot],[data-spotsave],[data-spottest],[data-spothere],[data-spotdel],[data-d8save],[data-d8dancerstop]');
        if (!t) return;
        ev.preventDefault();
        const d = D.d8 || {};
        if (t.dataset.d8open !== undefined) return post('d8_open');
        if (t.dataset.d8street !== undefined) { const r = await post('d8_street'); if (r && r.street) { st.form.address = r.street; render(); } return; }
        if (!d.available) return;
        if (t.dataset.d8tog) {
            const k = t.dataset.d8tog;
            if (k === 'formGarage') { st.form.garage = !st.form.garage; return render(); }
            const [kind, key] = k.split('.');
            return send('upSettings', { kind, patch: { [key]: !d.cfg[kind][key] } });
        }
        if (t.dataset.d8create !== undefined) {
            const f = st.form;
            return send('quickCreate', { name: f.name, address: f.address, category: f.category, interiorId: Number(f.interiorId) || null, salePrice: Number(f.salePrice), rentPrice: Number(f.rentPrice),
                garage: f.garage || f.category === 'garage', garageSize: f.garageSize, garageInterior: Number(f.garageInterior) || null, interiorIdGarage: Number(f.garageInterior) || null });
        }
        if (t.dataset.d8sel) { st.sel = Number(t.dataset.d8sel); return render(); }
        if (t.dataset.d8go) { send('teleport', { id: Number(t.dataset.d8go), area: t.dataset.area }, false); return post('close'); }
        if (t.dataset.d8pt) return send('point', { id: st.sel, key: t.dataset.d8pt, remove: t.dataset.remove === '1' });
        if (t.dataset.d8slot !== undefined) return send('slot', { id: st.sel });
        if (t.dataset.d8enable) return send('propEnable', { id: st.sel, enabled: t.dataset.d8enable === '1' });
        if (t.dataset.d8dancerstop !== undefined) return send('dancerStop', { pid: st.sel });
        if (t.dataset.d8arm) {
            const k = t.dataset.d8arm;
            if (!arm(k)) return;
            if (k === 'defaults') return send('upDefaults');
            if (k.startsWith('del:')) { st.sel = null; return send('propDelete', { id: Number(k.split(':')[1]) }); }
            if (k.startsWith('reset:')) { const [, pid, kind] = k.split(':'); return send('upReset', { pid: Number(pid), kind }); }
            return;
        }
        if (t.dataset.d8spot !== undefined) return send('spotAdd', { pid: st.sel, label: (document.querySelector('[data-d8spotlabel]') || {}).value || '' });
        const row = t.closest('[data-spot]');
        if (row) {
            const id = Number(row.dataset.spot);
            const v = (k) => (row.querySelector(`[data-sf="${k}"]`) || {}).value;
            if (t.dataset.spotsave !== undefined) return send('spotEdit', { id, label: v('label'), rz: Number(v('rz')), rx: Number(v('rx')), fov: Number(v('fov')), yaw: Number(v('yaw')), pitch: Number(v('pitch')) });
            if (t.dataset.spothere !== undefined) return send('spotEdit', { id, here: true });
            if (t.dataset.spottest !== undefined) { send('spotTest', { id }, false); return post('close'); }
            if (t.dataset.spotdel !== undefined) return send('spotDel', { id });
        }
        if (t.dataset.d8save) {
            const kind = t.dataset.d8save;
            const patch = {};
            document.querySelectorAll(`[data-d8cfg^="${kind}."]`).forEach((e) => { const k = e.dataset.d8cfg.split('.')[1]; patch[k] = e.tagName === 'SELECT' ? e.value : Number(e.value); });
            if (kind === 'dancer') { patch.animsOn = {}; document.querySelectorAll('[data-d8anim]').forEach((e) => { patch.animsOn[e.dataset.d8anim] = e.checked; }); }
            return send('upSettings', { kind, patch });
        }
    });
})();
