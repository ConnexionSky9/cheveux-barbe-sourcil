/* =========================================================
   BUILDER STUDIO - INTERFACE (panneaux)
   Palettes par mode, inspecteur, matériaux, historique, export, aide.
   ========================================================= */
'use strict';

const Panels = {};
window.Panels = Panels;

const GLASS = [['verre_clair', 'Verre transparent'], ['verre_teinte', 'Verre teinté'], ['verre_opaque', 'Verre opaque']];
const DOORMATS = [['bois', 'Bois'], ['metal', 'Métal'], ['acier', 'Acier'], ['aluminium', 'Aluminium'], ['verre_clair', 'Verre']];

function kitOf(id) { return (S.init?.kits || []).find((k) => k.id === id) || { materials: [] }; }
function matsOf(kitId) { return kitOf(kitId).materials || []; }
function matLabel(kitId, id) { const m = matsOf(kitId).find((x) => x.id === id); return m ? m.label : id; }
function options(list, cur) { return list.map(([v, l]) => `<option value="${esc(v)}"${String(v) === String(cur) ? ' selected' : ''}>${esc(l)}</option>`).join(''); }

// ---------------------------------------------------------
//  Petites fenêtres
// ---------------------------------------------------------
Panels.prompt = (title, label, value, ok) => {
    const b = openModal(title, `<div class="row"><label>${esc(label)}</label><input type="text" id="pv" value="${esc(value || '')}"></div><div class="btns"><button class="primary" id="pok">Valider</button></div>`);
    const go = () => { const v = $('#pv').value.trim(); if (v) { closeModal(); ok(v); } };
    $('#pok').onclick = go;
    $('#pv').addEventListener('keydown', (e) => { if (e.key === 'Enter') go(); });
    setTimeout(() => $('#pv').select(), 30);
};
Panels.confirm = (title, html, ok) => {
    openModal(title, `<p>${html}</p><div class="btns"><button class="danger" id="cok">Confirmer</button><button id="cno">Annuler</button></div>`);
    $('#cok').onclick = () => { closeModal(); ok(); };
    $('#cno').onclick = closeModal;
};
Panels.newProjectDialog = () => Panels.prompt('Nouveau projet', 'Nom', 'Nouveau projet', (v) => post('project:create', { name: v }));

// ---------------------------------------------------------
//  Modèles d'éléments (outils de construction)
// ---------------------------------------------------------
function tpl(type, params, extra) {
    return Object.assign({ type, kit: S.newKit, mat: S.newMat, params: clone(params || {}) }, extra || {});
}
const BUILD_TOOLS = [
    { id: 'foundation', t: 'Fondation', s: 'Dalle épaisse au sol', tool: () => ({ kind: 'element', template: tpl('foundation', { width: 8, depth: 8, thickness: 0.6 }) }) },
    { id: 'floor', t: 'Sol / étage', s: 'Dalle praticable', tool: () => ({ kind: 'element', template: tpl('floor', { width: 8, depth: 8 }) }) },
    { id: 'wall', t: 'Mur', s: '2 clics : début, fin', tool: () => ({ kind: 'line', template: tpl('wall', { height: 3, openings: [] }) }) },
    { id: 'partition', t: 'Cloison', s: '2 clics, 2,5 m', tool: () => ({ kind: 'line', template: tpl('partition', { height: 2.5, openings: [] }) }) },
    { id: 'facade', t: 'Façade', s: 'Fenêtres répétitives', tool: () => ({ kind: 'line', template: tpl('facade', { floors: 3, floorHeight: 3, winW: 1.5, winH: 1.5, sill: 1, spacing: 3, style: 'fenetres', glass: 'verre_teinte' }) }) },
    { id: 'curtain', t: 'Mur rideau', s: 'Façade tout verre', tool: () => ({ kind: 'line', template: tpl('facade', { floors: 3, floorHeight: 3, style: 'mur_rideau', glass: 'verre_teinte' }) }) },
    { id: 'ceiling', t: 'Plafond', s: 'Dalle à 3 m', tool: () => ({ kind: 'element', template: tpl('ceiling', { width: 8, depth: 8, height: 3 }) }) },
    { id: 'roof1', t: 'Toit plat', s: 'Avec acrotère', tool: () => ({ kind: 'element', template: tpl('roof', { width: 8, depth: 8, style: 'plat', parapet: 0.5 }) }) },
    { id: 'roof2', t: 'Toit 2 pans', s: 'Faîtage central', tool: () => ({ kind: 'element', template: tpl('roof', { width: 8, depth: 8, style: 'deux_pans', pitch: 30 }) }) },
    { id: 'roof3', t: 'Toit 1 pente', s: 'Appentis', tool: () => ({ kind: 'element', template: tpl('roof', { width: 8, depth: 6, style: 'une_pente', pitch: 15 }) }) },
    { id: 'stairs', t: 'Escalier', s: 'Droit, 3 m', tool: () => ({ kind: 'element', template: tpl('stairs', { width: 1.5, height: 3 }) }) },
    { id: 'column', t: 'Colonne', s: '0,4 m', tool: () => ({ kind: 'element', template: tpl('column', { height: 3 }) }) },
    { id: 'pillar', t: 'Pilier', s: '0,8 m', tool: () => ({ kind: 'element', template: tpl('pillar', { height: 6 }) }) },
    { id: 'balcony', t: 'Balcon', s: 'Garde-corps vitré', tool: () => ({ kind: 'element', template: tpl('balcony', { width: 3, depth: 1.5, railing: 1, railingMat: 'verre_clair' }) }) },
    { id: 'terrace', t: 'Terrasse', s: 'Avec garde-corps', tool: () => ({ kind: 'element', template: tpl('terrace', { width: 8, depth: 6, railing: 1, railingMat: 'metal' }) }) },
    { id: 'elevator', t: 'Ascenseur', s: 'Cage + paliers', tool: () => ({ kind: 'element', template: tpl('elevator', { width: 2, depth: 2, levels: [0, 3, 6], levelHeight: 3 }) }) },
];
const OPENING_TOOLS = [
    ['fenetre', 'Fenêtre', { w: 1.5, h: 1.5, y: 1, glass: 'verre_clair' }],
    ['fenetre', 'Fenêtre + volets', { w: 1, h: 1.5, y: 1, glass: 'verre_clair', shutters: true }],
    ['vitrine', 'Vitrine', { w: 3, h: 2.5, y: 0, glass: 'verre_clair' }],
    ['porte', 'Porte', {}], ['porte_double', 'Porte double', {}],
    ['porte_coulissante', 'Porte coulissante', { w: 2 }], ['porte_auto', 'Porte automatique', {}], ['vide', 'Ouverture vide', { w: 1, h: 2, y: 0 }],
];
const LIGHT_TOOLS = [
    ['plafonnier', 'Plafonnier', { range: 6, intensity: 3 }], ['spot', 'Spot', { range: 12, intensity: 6 }],
    ['neon', 'Néon', { length: 2, color: { r: 255, g: 60, b: 200 }, range: 4, intensity: 6 }],
    ['led', 'Bande LED', { length: 3, color: { r: 80, g: 160, b: 255 }, range: 3, intensity: 4 }], ['lampe', 'Lampe', { range: 4, intensity: 2 }],
];
const BUILDING_PRESETS = [
    { t: 'Maison', s: '2 niveaux, toit 2 pans', o: { floors: 2, width: 10, depth: 8, facade: 'fenetres', winW: 1, winH: 1.5, spacing: 3, shutters: true, roof: 'deux_pans' } },
    { t: 'Petit immeuble', s: '4 étages, fenêtres', o: { floors: 4, width: 12, depth: 10, facade: 'fenetres', winW: 1.5, winH: 1.5, spacing: 3 } },
    { t: 'Commerce + logements', s: 'RDC vitrines', o: { floors: 5, width: 16, depth: 12, facade: 'fenetres', shop: true, elevator: true } },
    { t: 'Tour de bureaux', s: '15 étages, ascenseur', o: { floors: 15, width: 20, depth: 20, facade: 'fenetres', winW: 2, winH: 2, spacing: 2.5, elevator: true, glass: 'verre_teinte' } },
    { t: 'Gratte-ciel vitré', s: '40 étages, mur rideau', o: { floors: 40, width: 24, depth: 24, facade: 'mur_rideau', elevator: true, glass: 'verre_teinte' } },
    { t: 'Parking souterrain', s: '2 sous-sols', o: { floors: 1, basements: 2, width: 24, depth: 30, facade: 'plein', elevator: true } },
    { t: 'Entrepôt', s: 'Grand volume', o: { floors: 1, floorHeight: 8, width: 30, depth: 40, facade: 'plein', roof: 'plat' } },
];

let activeCard = null;
function startTool(card, t) {
    if (!S.project) return toast('Ouvre ou crée d\'abord un projet.', 'error');
    if (!can('build')) return toast('Permission refusée (construction).', 'error');
    $$('.card.active').forEach((c) => c.classList.remove('active'));
    if (card) card.classList.add('active');
    activeCard = card;
    post('tool', t);
}

// ---------------------------------------------------------
//  Palettes (panneau du bas)
// ---------------------------------------------------------
const P = { cat: 'all', q: '', filter: 'all', room: { width: 5, depth: 4, height: 3, doorKind: 'porte' }, terrain: { cols: 16, rows: 16, cell: 4, amplitude: 12, seed: 7, base: 0 }, veg: { radius: 25, count: 40, gap: 3, models: ['prop_tree_pine_01', 'prop_tree_pine_02', 'prop_bush_lrg_04b'] }, building: { floorHeight: 3, roof: 'plat' } };

function kitSide() {
    const kits = S.init?.kits || [];
    const mats = matsOf(S.newKit);
    if (!mats.find((m) => m.id === S.newMat)) S.newMat = kitOf(S.newKit).defaultMaterial || (mats[0] && mats[0].id);
    const st = S.kitStatus && S.kitStatus[S.newKit];
    const warn = st && st.present === 0 ? `<div class="note bad">Aucun modèle de ce kit n'est installé : rien n'apparaîtra en jeu. ${S.newKit === 'ubk' ? 'Installe builder_studio_kit (voir README) ou utilise le kit « Blocs vanilla ».' : ''}</div>` : '';
    return `<h5>Kit des nouveaux éléments</h5>
        <select id="newKit" style="width:100%">${options(kits.map((k) => [k.id, k.label]), S.newKit)}</select>
        ${st ? `<div class="hint">${st.present} / ${st.total} modèles présents</div>` : ''}${warn}
        <h5>Matériau</h5>
        <select id="newMat" style="width:100%">${options(mats.map((m) => [m.id, m.label + (S.newKit === 'ubk' && S.ubkMaterials[m.id] === false ? ' (absent)' : '')]), S.newMat)}</select>`;
}
function bindKitSide(root) {
    const k = $('#newKit', root), m = $('#newMat', root);
    if (k) k.onchange = () => { S.kitChosen = true; S.newKit = k.value; S.newMat = kitOf(k.value).defaultMaterial; Panels.renderPalette(); };
    if (m) m.onchange = () => { S.newMat = m.value; };
}

function cardsHtml(list, attr) {
    return `<div class="cards">${list.map((c, i) => `<div class="card" data-${attr}="${i}"><div class="t">${esc(c.t)}</div><div class="s">${esc(c.s || '')}</div></div>`).join('')}</div>`;
}

Panels.renderPalette = () => {
    const root = $('#palette');
    if (!root || !S.init) return;
    const mode = S.mode;
    if (mode === 'construction') {
        const wall = selectedWall();
        root.innerHTML = `<div class="palSide">${kitSide()}</div>
            <div class="palMain"><h5>Structure</h5>${cardsHtml(BUILD_TOOLS, 'bt')}
            <h5>Ouvertures ${wall ? '— sur « ' + esc(wall.name) + ' »' : '(sélectionne d\'abord un mur)'}</h5>
            <div class="cards">${OPENING_TOOLS.map((o, i) => `<div class="card${wall ? '' : ' missing'}" data-op="${i}"><div class="t">${esc(o[1])}</div><div class="s">découpe réelle du mur</div></div>`).join('')}</div></div>`;
        bindKitSide(root);
        $$('[data-bt]', root).forEach((c) => c.onclick = () => { const b = BUILD_TOOLS[+c.dataset.bt]; startTool(c, Object.assign({ label: b.t }, b.tool())); });
        $$('[data-op]', root).forEach((c) => c.onclick = () => addOpening(OPENING_TOOLS[+c.dataset.op]));
    } else if (mode === 'decoration') {
        renderCatalog(root);
    } else if (mode === 'interieur') {
        const r = P.room;
        root.innerHTML = `<div class="palSide">${kitSide()}
            <h5>Dimensions de la pièce</h5><div class="formgrid">
            <label>Largeur</label><input type="number" data-room="width" value="${r.width}" step="0.5">
            <label>Profondeur</label><input type="number" data-room="depth" value="${r.depth}" step="0.5">
            <label>Hauteur</label><input type="number" data-room="height" value="${r.height}" step="0.5">
            <label>Porte</label><select data-room="doorKind">${options([['porte', 'Porte'], ['porte_double', 'Double'], ['porte_coulissante', 'Coulissante'], ['vide', 'Ouverture']], r.doorKind)}</select></div></div>
            <div class="palMain"><h5>Pièces meublées (sol, murs, porte, plafond, plafonnier, meubles)</h5>
            <div class="cards">${(S.init.roomPresets || []).map((p) => `<div class="card" data-room-preset="${p.id}"><div class="t">${esc(p.label)}</div><div class="s">${p.items} meuble(s)</div></div>`).join('')}</div>
            <h5>Éclairage (vraies lumières dynamiques)</h5>
            <div class="cards">${LIGHT_TOOLS.map((l, i) => `<div class="card" data-light="${i}"><div class="t">${esc(l[1])}</div><div class="s">${l[0]}</div></div>`).join('')}</div>
            <h5>Mobilier & décoration</h5>
            <div class="cards">${['mobilier', 'bureau', 'cuisine', 'commerce', 'entrepot', 'eclairage', 'decoration'].map((c) => `<div class="card" data-gocat="${c}"><div class="t">${esc((S.init.categories.find((x) => x.id === c) || {}).label || c)}</div><div class="s">ouvrir le catalogue</div></div>`).join('')}</div>
            <div class="note">Les intérieurs construits ici sont des objets posés dans le monde. Un vrai intérieur GTA (MLO avec pièces, portails, occlusion) se crée dans CodeWalker à partir de l'export.</div></div>`;
        bindKitSide(root);
        $$('[data-room]', root).forEach((i) => i.onchange = () => { P.room[i.dataset.room] = i.type === 'number' ? +i.value : i.value; });
        $$('[data-room-preset]', root).forEach((c) => c.onclick = () => startTool(c, { kind: 'room', preset: c.dataset.roomPreset, label: c.querySelector('.t').textContent, opts: { ...P.room, kit: S.newKit, mat: S.newMat } }));
        $$('[data-light]', root).forEach((c) => c.onclick = () => { const l = LIGHT_TOOLS[+c.dataset.light]; startTool(c, { kind: 'element', label: l[1], template: { type: 'light', name: l[1], params: { kind: l[0], ...clone(l[2]) } } }); });
        $$('[data-gocat]', root).forEach((c) => c.onclick = () => { P.cat = c.dataset.gocat; $('#modes [data-mode="decoration"]').click(); });
    } else if (mode === 'terrain') {
        const t = P.terrain, v = P.veg;
        const veg = (S.init.catalog || []).filter((i) => i.cat === 'vegetation' || i.cat === 'rochers');
        root.innerHTML = `<div class="palSide"><h5>Grille du terrain</h5><div class="formgrid">
            <label>Colonnes</label><input type="number" data-ter="cols" value="${t.cols}" min="1" max="128">
            <label>Rangées</label><input type="number" data-ter="rows" value="${t.rows}" min="1" max="128">
            <label>Case (m)</label><input type="number" data-ter="cell" value="${t.cell}" step="0.5">
            <label>Amplitude</label><input type="number" data-ter="amplitude" value="${t.amplitude}">
            <label>Graine</label><input type="number" data-ter="seed" value="${t.seed}">
            <label>Niveau de base</label><input type="number" data-ter="base" value="${t.base}"></div>
            <div class="hint">${t.cols * t.rows} cases · ${t.cols * t.cell} × ${t.rows * t.cell} m</div></div>
            <div class="palMain"><h5>Reliefs (dalles + talus, collisions réelles, kit architectural)</h5>
            <div class="cards">${Object.entries(S.init.terrains || {}).map(([k, l]) => `<div class="card" data-ter-preset="${k}"><div class="t">${esc(l)}</div><div class="s">${t.cols}×${t.rows}</div></div>`).join('')}</div>
            <h5>Végétation / forêt (posée sur le vrai sol)</h5>
            <div class="row"><label>Rayon</label><input type="number" data-veg="radius" value="${v.radius}"><label style="width:auto">Nombre</label><input type="number" data-veg="count" value="${v.count}"><label style="width:auto">Écart</label><input type="number" data-veg="gap" value="${v.gap}"><button class="primary" id="vegGo">Planter</button></div>
            <div class="chips">${veg.map((i) => `<button data-vm="${i.model}" class="${v.models.includes(i.model) ? 'active' : ''}">${esc(i.label)}</button>`).join('')}</div>
            <div class="note">Le relief se sculpte ensuite : sélectionne le terrain › Propriétés › Sculpter. Grandes îles : la grille en jeu sert à l'ébauche ; pour une vraie île (relief lisse, LOD, collisions optimisées), exporte la grille en heightmap et utilise le pipeline tools/ (OBJ → Blender/Sollumz → YDR/YBN/YMAP).</div>
            <div class="note bad">Lacs, rivières et cascades : non disponibles en jeu. GTA ne permet pas d'ajouter de l'eau à la volée (il faut un water.xml complet chargé au démarrage) ; ce n'est pas encore implémenté.</div></div>`;
        $$('[data-ter]', root).forEach((i) => i.onchange = () => { P.terrain[i.dataset.ter] = +i.value; Panels.renderPalette(); });
        $$('[data-veg]', root).forEach((i) => i.onchange = () => { P.veg[i.dataset.veg] = +i.value; });
        $$('[data-vm]', root).forEach((b) => b.onclick = () => { const m = b.dataset.vm; v.models = v.models.includes(m) ? v.models.filter((x) => x !== m) : [...v.models, m]; b.classList.toggle('active'); });
        $$('[data-ter-preset]', root).forEach((c) => c.onclick = () => {
            post('terrainHeights', { kind: c.dataset.terPreset, cols: t.cols, rows: t.rows, amplitude: t.amplitude, seed: t.seed }).then((r) => {
                startTool(c, { kind: 'element', label: 'Terrain : ' + c.querySelector('.t').textContent, template: { type: 'terrain', kit: (S.kitStatus && S.kitStatus.ubk && S.kitStatus.ubk.present > 0) ? 'ubk' : S.newKit, name: 'Terrain ' + c.querySelector('.t').textContent, params: { cols: t.cols, rows: t.rows, cell: t.cell, base: t.base, heights: r.heights || [] } } });
            });
        });
        $('#vegGo').onclick = (e) => {
            if (!v.models.length) return toast('Choisis au moins un modèle.', 'error');
            startTool(null, { kind: 'scatter', label: 'Végétation', template: { type: 'scatter', name: 'Végétation', params: { radius: v.radius, count: v.count, gap: v.gap, models: v.models.slice() } } });
        };
    } else if (mode === 'urbanisme') {
        const b = P.building;
        root.innerHTML = `<div class="palSide">${kitSide()}<h5>Immeubles</h5><div class="formgrid">
            <label>Hauteur d'étage</label><input type="number" data-bld="floorHeight" value="${b.floorHeight}" step="0.5">
            <label>Toiture</label><select data-bld="roof">${options([['plat', 'Plate'], ['deux_pans', '2 pans'], ['une_pente', '1 pente']], b.roof)}</select></div></div>
            <div class="palMain"><h5>Voirie (clics successifs, Entrée pour terminer)</h5>
            <div class="cards">${Object.entries(S.init.roads || {}).map(([k, l]) => `<div class="card" data-road="${k}"><div class="t">${esc(l)}</div><div class="s">${k === 'pont' ? 'garde-corps + piliers' : k === 'tunnel' ? 'murs + voûte' : k === 'quai' ? 'pieux' : 'asphalte'}</div></div>`).join('')}</div>
            <h5>Bâtiments et gratte-ciel (étage par étage, chaque étage reste modifiable)</h5>
            ${cardsHtml(BUILDING_PRESETS, 'bp')}
            <div class="note">Zones résidentielles / industrielles : combine ces immeubles, entrepôts et routes. Après création : sélectionne un étage dans la hiérarchie › « Dupliquer l'étage ».</div></div>`;
        bindKitSide(root);
        $$('[data-bld]', root).forEach((i) => i.onchange = () => { P.building[i.dataset.bld] = i.type === 'number' ? +i.value : i.value; });
        $$('[data-road]', root).forEach((c) => c.onclick = () => {
            const k = c.dataset.road;
            startTool(c, { kind: 'path', label: c.querySelector('.t').textContent, template: tpl('road', { kind: k, width: k === 'quai' ? 6 : 8, rail: k !== 'route', lift: k === 'pont' ? 0 : 0.05, pillarEvery: k === 'quai' ? 6 : 15, pillarDepth: k === 'quai' ? 4 : 12, tunnelHeight: 6 }, { mat: S.newKit === 'ubk' ? (k === 'quai' ? 'bois' : 'asphalte') : S.newMat, name: c.querySelector('.t').textContent }) });
        });
        $$('[data-bp]', root).forEach((c) => c.onclick = () => {
            const pr = BUILDING_PRESETS[+c.dataset.bp];
            startTool(c, { kind: 'building', label: pr.t, opts: Object.assign({ kit: S.newKit, mat: S.newMat, name: pr.t, floorHeight: P.building.floorHeight, roof: P.building.roof }, pr.o, pr.o.roof ? { roof: pr.o.roof } : {}) });
        });
    }
};

function selectedWall() {
    const el = S.elements[S.selection[0]];
    return el && (el.type === 'wall' || el.type === 'partition') ? el : null;
}

function addOpening(def) {
    const wall = selectedWall();
    if (!wall) return toast('Sélectionne d\'abord un mur ou une cloison.', 'error');
    const el = clone(wall);
    el.params.openings = el.params.openings || [];
    const L = +el.params.length || 4;
    const o = Object.assign({ kind: def[0], w: 1, h: 2, y: 0 }, clone(def[2]));
    o.x = Math.max(0, Math.round((L / 2 - (o.w || 1) / 2) * 2) / 2);
    el.params.openings.push(o);
    post('updateElements', { elements: [el], label: 'Ouverture : ' + def[1] });
}

// ---------------------------------------------------------
//  Catalogue
// ---------------------------------------------------------
function renderCatalog(root) {
    const cats = S.init.categories || [];
    const all = [...(S.init.catalog || []), ...S.custom.map((c) => ({ ...c, cat: 'custom' }))];
    const q = P.q.toLowerCase();
    let list = all.filter((i) => (P.cat === 'all' || i.cat === P.cat) && (!q || i.model.toLowerCase().includes(q) || String(i.label).toLowerCase().includes(q)));
    if (P.filter === 'fav') list = list.filter((i) => S.fav.includes(i.model));
    if (P.filter === 'recent') list = S.recent.map((m) => all.find((i) => i.model === m) || { model: m, label: m, cat: 'custom' }).filter((i) => !q || i.model.includes(q));
    root.innerHTML = `<div class="palSide">
        <input type="search" id="catQ" placeholder="Rechercher un objet…" value="${esc(P.q)}">
        <div class="chips"><button data-f="all" class="${P.filter === 'all' ? 'active' : ''}">Tous</button><button data-f="fav" class="${P.filter === 'fav' ? 'active' : ''}">★ Favoris</button><button data-f="recent" class="${P.filter === 'recent' ? 'active' : ''}">Récents</button></div>
        <h5>Catégories</h5><div class="chips"><button data-c="all" class="${P.cat === 'all' ? 'active' : ''}">Toutes</button>${cats.map((c) => `<button data-c="${c.id}" class="${P.cat === c.id ? 'active' : ''}">${esc(c.label)}</button>`).join('')}</div>
        ${can('import') ? '<button class="wide" id="importModel">+ Importer un modèle</button>' : ''}
        <div class="hint">Clic : placer · ⊙ : aperçu en jeu · ★ : favori. Les modèles absents de ton jeu sont grisés.</div></div>
        <div class="palMain"><div class="cards">${list.map((i) => {
            const ok = S.modelStatus[i.model] !== false;
            return `<div class="card${ok ? '' : ' missing'}" data-model="${esc(i.model)}" data-veh="${i.type === 'vehicle' ? 1 : 0}" title="${esc(i.model)}">
                <span class="fav${S.fav.includes(i.model) ? ' on' : ''}" data-fav="${esc(i.model)}">★</span>
                <div class="t">${esc(i.label)}</div><div class="s">${esc(i.model)}</div>
                <span class="st"><span data-prev="${esc(i.model)}" title="Aperçu">⊙</span> ${ok ? '' : 'absent'}${i.type === 'vehicle' ? ' véhicule' : ''}</span></div>`;
        }).join('') || '<div class="hint">Aucun objet.</div>'}</div></div>`;
    $('#catQ', root).oninput = (e) => { P.q = e.target.value; clearTimeout(P._t); P._t = setTimeout(() => { Panels.renderPalette(); const i = $('#catQ'); i.focus(); i.setSelectionRange(i.value.length, i.value.length); }, 200); };
    $$('[data-f]', root).forEach((b) => b.onclick = () => { P.filter = b.dataset.f; Panels.renderPalette(); });
    $$('[data-c]', root).forEach((b) => b.onclick = () => { P.cat = b.dataset.c; Panels.renderPalette(); });
    const imp = $('#importModel', root);
    if (imp) imp.onclick = importDialog;
    $$('.card[data-model]', root).forEach((c) => c.onclick = (e) => {
        const m = c.dataset.model;
        if (e.target.dataset.fav) {
            S.fav = S.fav.includes(m) ? S.fav.filter((x) => x !== m) : [...S.fav, m];
            post('prefs:set', { fav: S.fav });
            return Panels.renderPalette();
        }
        if (e.target.dataset.prev) return post('preview', { model: m });
        if (c.classList.contains('missing')) return toast('Ce modèle n\'existe pas dans ton jeu (ressource non démarrée ?).', 'error');
        const label = c.querySelector('.t').textContent;
        startTool(c, { kind: 'element', label, template: { type: 'prop', model: m, name: label, vehicle: c.dataset.veh === '1' } });
    });
}

function importDialog() {
    openModal('Importer un modèle personnalisé', `
        <div class="note">Le modèle doit être STREAMÉ par une ressource démarrée sur le serveur (fichiers .ydr / .ytyp / .ytd dans son dossier stream/). Builder Studio l'ajoute au catalogue et vérifie qu'il existe dans le jeu ; il ne convertit pas les fichiers 3D (voir tools/ et README).</div>
        <div class="formgrid"><label>Nom du modèle</label><input type="text" id="imModel" placeholder="mon_prop_01">
        <label>Libellé</label><input type="text" id="imLabel" placeholder="Mon objet">
        <label>Type</label><select id="imType"><option value="prop">Objet</option><option value="vehicle">Véhicule décoratif</option></select></div>
        <div class="btns" style="margin-top:8px"><button class="primary" id="imOk">Ajouter au catalogue</button></div>
        <h5>Objets personnalisés</h5><table class="list"><tr><th>Modèle</th><th>Libellé</th><th>En jeu</th><th></th></tr>
        ${S.custom.map((c) => `<tr><td>${esc(c.model)}</td><td>${esc(c.label)}</td><td>${S.modelStatus[c.model] === false ? 'absent' : 'présent'}</td><td><button data-rm="${esc(c.model)}" class="danger">Retirer</button></td></tr>`).join('')}</table>`);
    $('#imOk').onclick = () => {
        const model = $('#imModel').value.trim();
        if (!/^[\w-]{1,64}$/.test(model)) return toast('Nom de modèle invalide.', 'error');
        post('checkModels', { models: [model] }).then((r) => {
            if (r.models && r.models[model] === false) toast('Attention : ce modèle n\'existe pas (encore) dans ton jeu.', 'error');
            post('custom:add', { model, label: $('#imLabel').value.trim() || model, type: $('#imType').value });
            closeModal();
        });
    };
    $$('[data-rm]').forEach((b) => b.onclick = () => { post('custom:remove', { model: b.dataset.rm }); closeModal(); });
}

// ---------------------------------------------------------
//  Inspecteur
// ---------------------------------------------------------
const F = (key, label, kind, extra) => ({ key, label, kind, ...(extra || {}) });
const PARAMS = {
    wall: [F('length', 'Longueur (m)', 'num'), F('height', 'Hauteur (m)', 'num')],
    partition: [F('length', 'Longueur (m)', 'num'), F('height', 'Hauteur (m)', 'num')],
    facade: [F('length', 'Longueur (m)', 'num'), F('floors', 'Étages', 'num', { step: 1 }), F('floorHeight', 'Hauteur d\'étage', 'num'),
        F('style', 'Style', 'sel', { opts: [['fenetres', 'Fenêtres'], ['mur_rideau', 'Mur rideau']] }), F('winW', 'Largeur fenêtre', 'num'), F('winH', 'Hauteur fenêtre', 'num'),
        F('sill', 'Allège', 'num'), F('spacing', 'Entraxe', 'num'), F('glass', 'Verre', 'sel', { opts: GLASS }), F('frame', 'Cadres', 'bool', { def: true }), F('shutters', 'Volets', 'bool'), F('groundShop', 'RDC commercial', 'bool')],
    floor: [F('width', 'Largeur X (m)', 'num'), F('depth', 'Profondeur Y (m)', 'num')],
    ceiling: [F('width', 'Largeur X (m)', 'num'), F('depth', 'Profondeur Y (m)', 'num'), F('height', 'Hauteur (m)', 'num')],
    foundation: [F('width', 'Largeur X (m)', 'num'), F('depth', 'Profondeur Y (m)', 'num'), F('thickness', 'Épaisseur (m)', 'num')],
    roof: [F('width', 'Largeur X (m)', 'num'), F('depth', 'Profondeur Y (m)', 'num'), F('style', 'Forme', 'sel', { opts: [['plat', 'Plat'], ['deux_pans', 'Deux pans'], ['une_pente', 'Une pente']] }), F('pitch', 'Pente (°)', 'num'), F('parapet', 'Acrotère (m)', 'num')],
    stairs: [F('width', 'Largeur (m)', 'num'), F('height', 'Hauteur (m)', 'num')],
    column: [F('height', 'Hauteur (m)', 'num')], pillar: [F('height', 'Hauteur (m)', 'num')],
    balcony: [F('width', 'Largeur (m)', 'num'), F('depth', 'Profondeur (m)', 'num'), F('railing', 'Garde-corps (m)', 'num'), F('railingMat', 'Garde-corps', 'mat')],
    terrace: [F('width', 'Largeur (m)', 'num'), F('depth', 'Profondeur (m)', 'num'), F('railing', 'Garde-corps (m)', 'num'), F('railingMat', 'Garde-corps', 'mat')],
    light: [F('kind', 'Type', 'sel', { optsFrom: 'lights' }), F('color', 'Couleur', 'color'), F('range', 'Portée (m)', 'num'), F('intensity', 'Intensité', 'num'), F('length', 'Longueur (néon/LED)', 'num'), F('shadow', 'Ombres (coûteux)', 'bool'), F('fixture', 'Luminaire (modèle)', 'text')],
    terrain: [F('cols', 'Colonnes', 'num', { step: 1 }), F('rows', 'Rangées', 'num', { step: 1 }), F('cell', 'Case (m)', 'num'), F('base', 'Niveau de base', 'num')],
    road: [F('kind', 'Type', 'sel', { optsFrom: 'roads' }), F('width', 'Largeur (m)', 'num'), F('rail', 'Garde-corps', 'bool'), F('railHeight', 'Hauteur garde-corps', 'num'), F('tunnelHeight', 'Hauteur tunnel', 'num'), F('pillarEvery', 'Piliers tous les (m)', 'num'), F('pillarDepth', 'Profondeur piliers', 'num'), F('railMat', 'Matériau garde-corps', 'mat')],
    elevator: [F('width', 'Largeur (m)', 'num'), F('depth', 'Profondeur (m)', 'num'), F('levels', 'Niveaux (m, séparés par ;)', 'levels'), F('levelHeight', 'Hauteur d\'étage', 'num')],
    scatter: [],
    group: [],
};

let pendingUpdate = null, pendingTimer = null;
function queueUpdate(el, label) {
    S.elements[el.id] = el;
    pendingUpdate = { el, label };
    clearTimeout(pendingTimer);
    pendingTimer = setTimeout(() => { post('updateElements', { elements: [pendingUpdate.el], label: pendingUpdate.label }); pendingUpdate = null; }, 350);
}

function fieldHtml(f, v, el) {
    const id = `f_${f.key}`;
    if (f.kind === 'num') return `<input type="number" data-p="${f.key}" step="${f.step || 0.5}" value="${v ?? ''}">`;
    if (f.kind === 'bool') return `<input type="checkbox" data-p="${f.key}" ${(v ?? f.def) ? 'checked' : ''}>`;
    if (f.kind === 'text') return `<input type="text" data-p="${f.key}" value="${esc(v ?? '')}">`;
    if (f.kind === 'color') { const c = v || { r: 255, g: 240, b: 220 }; const hex = '#' + [c.r, c.g, c.b].map((x) => (+x).toString(16).padStart(2, '0')).join(''); return `<input type="color" data-p="${f.key}" value="${hex}">`; }
    if (f.kind === 'levels') return `<input type="text" data-p="${f.key}" value="${(v || []).join(' ; ')}">`;
    if (f.kind === 'sel') {
        const opts = f.opts || Object.entries(S.init[f.optsFrom] || {});
        return `<select data-p="${f.key}">${options(opts, v)}</select>`;
    }
    if (f.kind === 'mat') return `<select data-p="${f.key}">${options(matsOf(el.kit || 'ubk').map((m) => [m.id, m.label]), v)}</select>`;
    return '';
}

function readField(input, f) {
    if (f.kind === 'num') return input.value === '' ? undefined : +input.value;
    if (f.kind === 'bool') return input.checked;
    if (f.kind === 'color') { const h = input.value; return { r: parseInt(h.substr(1, 2), 16), g: parseInt(h.substr(3, 2), 16), b: parseInt(h.substr(5, 2), 16) }; }
    if (f.kind === 'levels') return input.value.split(/[;,]/).map((x) => +x.trim()).filter((x) => !isNaN(x));
    return input.value;
}

const vecHtml = (k, v, step) => `<div class="vec">${['x', 'y', 'z'].map((a) => `<span class="ax ${a}">${a.toUpperCase()}</span><input type="number" data-v="${k}.${a}" step="${step}" value="${round((v || {})[a] || 0, 3)}">`).join('')}</div>`;

Panels.renderInspector = () => {
    const root = $('#inspector');
    if (!root) return;
    if (pendingUpdate) return;
    const sel = S.selection.map((id) => S.elements[id]).filter(Boolean);
    if (!sel.length) {
        root.innerHTML = `<div class="hint">${S.project ? 'Clique sur un élément dans la vue ou dans la hiérarchie.' : 'Aucun projet ouvert.'}</div>` + (S.project ? projectInfoHtml() : '');
        bindProjectInfo(root);
        return;
    }
    const el = sel[0];
    const types = S.init.types || {};
    const fields = PARAMS[el.type] || [];
    const p = el.params || {};
    const arch = !['prop', 'group', 'light', 'scatter'].includes(el.type);
    let html = '';
    if (sel.length > 1) html += `<div class="note">${sel.length} éléments sélectionnés. Les champs modifient le premier ; matériau, verrou et suppression s'appliquent à tous.</div>`;
    for (const w of S.warnings || []) html += `<div class="warn">${esc(w)}</div>`;
    html += `<div class="sect"><h4>${esc(types[el.type] || el.type)} <span>${el.locked ? '🔒 verrouillé' : ''}</span></h4><div class="body">
        <div class="row"><label>Nom</label><input type="text" data-name value="${esc(el.name || '')}"></div>
        ${el.type === 'prop' ? `<div class="row"><label>Modèle</label><span>${esc(el.model)}${el.vehicle ? ' (véhicule)' : ''}</span></div>` : ''}
        <div class="row"><label>Position</label>${vecHtml('pos', el.pos, 0.1)}</div>
        <div class="row"><label>Rotation (°)</label>${vecHtml('rot', el.rot, 1)}</div>
        ${el.type === 'prop' ? `<div class="row"><label>Échelle (visuelle)</label>${vecHtml('scale', el.scale || { x: 1, y: 1, z: 1 }, 0.05)}</div><div class="hint">L'échelle ne change que l'apparence : le moteur garde la collision d'origine.</div>` : ''}
        <div class="row"><label>Étage</label><input type="number" data-level step="1" value="${el.level || 0}"></div>
        <div class="btns"><button data-cmd="focus">Centrer</button><button data-cmd="ground">Au sol</button><button data-cmd="duplicate">Dupliquer</button><button data-cmd="lock">${el.locked ? 'Déverrouiller' : 'Verrouiller'}</button><button data-cmd="delete" class="danger">Supprimer</button></div>
    </div></div>`;
    if (arch) {
        html += `<div class="sect"><h4>Kit & matériau</h4><div class="body">
            <div class="row"><label>Kit</label><select data-kit>${options((S.init.kits || []).map((k) => [k.id, k.label]), el.kit)}</select></div>
            <div class="row"><label>Matériau</label><select data-mat>${options(matsOf(el.kit).map((m) => [m.id, m.label]), el.mat)}</select></div></div></div>`;
    }
    if (fields.length) {
        html += `<div class="sect"><h4>Paramètres</h4><div class="body">${fields.map((f) => `<div class="row"><label>${esc(f.label)}</label>${fieldHtml(f, p[f.key], el)}</div>`).join('')}</div></div>`;
    }
    if (el.type === 'wall' || el.type === 'partition') html += openingsHtml(el);
    if (el.type === 'floor' || el.type === 'ceiling') html += holesHtml(el);
    if (el.type === 'terrain') html += `<div class="sect"><h4>Relief</h4><div class="body">
        <div class="row"><label>Forme</label><select id="terKind">${options(Object.entries(S.init.terrains || {}), 'ile')}</select></div>
        <div class="row"><label>Amplitude</label><input type="number" id="terAmp" value="12"><label style="width:auto">Graine</label><input type="number" id="terSeed" value="7"></div>
        <div class="btns"><button id="terApply">Appliquer la forme</button></div>
        <h5>Sculpter</h5><div class="row"><label>Force (m)</label><input type="number" id="scStr" value="0.5" step="0.5"><label style="width:auto">Rayon</label><input type="number" id="scRad" value="1" step="1"></div>
        <div class="btns"><button class="primary" id="scGo">Sculpter (clic / Maj+clic)</button><button id="scFlat">Aplanir à</button><input type="number" id="scFlatTo" value="0" step="0.5"></div>
        <div class="btns" style="margin-top:6px"><button id="terExport">Exporter la heightmap (JSON)</button></div></div></div>`;
    if (el.type === 'group') html += `<div class="sect"><h4>Groupe / étage</h4><div class="body">
        <div class="row"><label>Copies</label><input type="number" id="dfCount" value="1" min="1" step="1"><label style="width:auto">Hauteur</label><input type="number" id="dfH" value="3" step="0.5"></div>
        <div class="btns"><button class="primary" id="dfGo">Dupliquer l'étage vers le haut</button><button data-cmd="ungroup">Dégrouper</button></div>
        <div class="hint">Chaque copie est indépendante : modifie ensuite chaque étage séparément.</div></div></div>`;
    if (el.type === 'scatter') html += `<div class="sect"><h4>Végétation</h4><div class="body"><div>${(p.points || []).length} plants · ${(p.models || []).map(esc).join(', ')}</div></div></div>`;
    if (el.type === 'road') html += `<div class="sect"><h4>Tracé</h4><div class="body">${(p.points || []).length} points (relatifs à l'origine).</div></div>`;
    root.innerHTML = html;
    bindInspector(root, el, fields);
};

function projectInfoHtml() {
    const pr = S.project;
    return `<div class="sect" style="margin-top:8px"><h4>Projet</h4><div class="body">
        <div class="row"><label>Nom</label><span>${esc(pr.name)}</span></div>
        <div class="row"><label>État</label><span>${pr.active ? 'publié (visible par tous)' : 'brouillon (visible par les éditeurs)'}</span></div>
        <div class="row"><label>Éléments</label><span>${Object.keys(S.elements).length}</span></div>
        <div class="btns"><button data-cmd="save">Enregistrer</button><button data-cmd="snapshot">Point de restauration</button><button data-cmd="publish">${pr.active ? 'Retirer du jeu' : 'Publier'}</button><button data-cmd="export">Exporter</button></div></div></div>`;
}
function bindProjectInfo() {}

function openingsHtml(el) {
    const kinds = Object.entries(S.init.openings || {});
    const list = el.params.openings || [];
    return `<div class="sect"><h4>Ouvertures (${list.length})</h4><div class="body">
        ${list.map((o, i) => `<div class="op" data-oi="${i}">
            <div class="row"><select data-o="kind">${options(kinds, o.kind)}</select><button data-orm="${i}" class="danger">✕</button></div>
            <div class="row"><label>X / Y (m)</label><input type="number" data-o="x" step="0.5" value="${o.x ?? 0}"><input type="number" data-o="y" step="0.5" value="${o.y ?? 0}"></div>
            <div class="row"><label>Largeur / hauteur</label><input type="number" data-o="w" step="0.5" value="${o.w ?? 1}"><input type="number" data-o="h" step="0.5" value="${o.h ?? 1}"></div>
            ${['fenetre', 'vitrine'].includes(o.kind) ? `<div class="row"><label>Verre</label><select data-o="glass">${options(GLASS, o.glass || 'verre_clair')}</select></div>` : ''}
            ${o.kind && o.kind.startsWith('porte') ? `<div class="row"><label>Battant</label><select data-o="doorMat">${options(DOORMATS, o.doorMat || (o.kind === 'porte_auto' ? 'verre_clair' : 'bois'))}</select></div>` : ''}
            <div class="row"><label>Cadre</label><input type="checkbox" data-o="frame" ${o.frame !== false ? 'checked' : ''}>${o.kind === 'fenetre' ? `<label style="width:auto">Volets</label><input type="checkbox" data-o="shutters" ${o.shutters ? 'checked' : ''}>` : ''}</div>
        </div>`).join('')}
        <div class="hint">Les dimensions sont alignées sur la grille du kit (0,5 m). Les portes prennent la taille du battant (1 × 2 m, 2 × 2 m en double).</div></div></div>`;
}

function holesHtml(el) {
    const list = el.params.holes || [];
    return `<div class="sect"><h4>Trémies (${list.length})</h4><div class="body">
        ${list.map((h, i) => `<div class="row" data-hi="${i}"><input type="number" data-h="x" value="${h.x}" step="0.5" title="X"><input type="number" data-h="y" value="${h.y}" step="0.5" title="Y"><input type="number" data-h="w" value="${h.w}" step="0.5" title="Largeur"><input type="number" data-h="d" value="${h.d}" step="0.5" title="Profondeur"><button data-hrm="${i}" class="danger">✕</button></div>`).join('')}
        <div class="btns"><button id="holeAdd">+ Trémie (escalier, ascenseur)</button></div></div></div>`;
}

function bindInspector(root, el0, fields) {
    const get = () => clone(S.elements[el0.id]);
    const nm = $('[data-name]', root);
    if (nm) nm.onchange = () => { const el = get(); el.name = nm.value; queueUpdate(el, 'Renommage'); };
    $$('[data-v]', root).forEach((i) => i.onchange = () => {
        const [k, a] = i.dataset.v.split('.');
        const el = get();
        el[k] = el[k] || { x: 1, y: 1, z: 1 };
        el[k][a] = +i.value;
        queueUpdate(el, k === 'pos' ? 'Position' : k === 'rot' ? 'Rotation' : 'Échelle');
    });
    const lv = $('[data-level]', root);
    if (lv) lv.onchange = () => { const el = get(); el.level = +lv.value; queueUpdate(el, 'Étage'); };
    const kit = $('[data-kit]', root), mat = $('[data-mat]', root);
    const applyAll = (fn, label) => {
        const list = S.selection.map((id) => S.elements[id]).filter(Boolean).map((e) => { const c = clone(e); fn(c); return c; });
        post('updateElements', { elements: list, label });
    };
    if (kit) kit.onchange = () => applyAll((c) => { if (!['prop', 'group', 'light', 'scatter'].includes(c.type)) { c.kit = kit.value; c.mat = kitOf(kit.value).defaultMaterial; } }, 'Kit');
    if (mat) mat.onchange = () => applyAll((c) => { if (c.kit === el0.kit) c.mat = mat.value; }, 'Matériau');
    $$('[data-p]', root).forEach((i) => {
        const f = fields.find((x) => x.key === i.dataset.p);
        if (!f) return;
        i.onchange = () => { const el = get(); el.params = el.params || {}; el.params[f.key] = readField(i, f); queueUpdate(el, f.label); };
    });
    // ouvertures
    $$('[data-oi]', root).forEach((box) => {
        const idx = +box.dataset.oi;
        $$('[data-o]', box).forEach((i) => i.onchange = () => {
            const el = get();
            const o = el.params.openings[idx];
            const k = i.dataset.o;
            o[k] = i.type === 'checkbox' ? i.checked : (i.type === 'number' ? +i.value : i.value);
            pendingUpdate = null;
            post('updateElements', { elements: [el], label: 'Ouverture' });
        });
    });
    $$('[data-orm]', root).forEach((b) => b.onclick = () => { const el = get(); el.params.openings.splice(+b.dataset.orm, 1); post('updateElements', { elements: [el], label: 'Suppression d\'ouverture' }); });
    // trémies
    $$('[data-hi]', root).forEach((row) => {
        const idx = +row.dataset.hi;
        $$('[data-h]', row).forEach((i) => i.onchange = () => { const el = get(); el.params.holes[idx][i.dataset.h] = +i.value; post('updateElements', { elements: [el], label: 'Trémie' }); });
    });
    $$('[data-hrm]', root).forEach((b) => b.onclick = () => { const el = get(); el.params.holes.splice(+b.dataset.hrm, 1); post('updateElements', { elements: [el], label: 'Trémie' }); });
    const ha = $('#holeAdd', root);
    if (ha) ha.onclick = () => { const el = get(); el.params.holes = el.params.holes || []; el.params.holes.push({ x: 1, y: 1, w: 2, d: 3 }); post('updateElements', { elements: [el], label: 'Trémie' }); };
    // terrain
    const ta = $('#terApply', root);
    if (ta) {
        ta.onclick = () => {
            const el = get();
            post('terrainHeights', { kind: $('#terKind').value, cols: el.params.cols || 8, rows: el.params.rows || 8, amplitude: +$('#terAmp').value, seed: +$('#terSeed').value }).then((r) => {
                if (!r.heights) return;
                el.params.heights = r.heights;
                post('updateElements', { elements: [el], label: 'Relief' });
            });
        };
        $('#scGo').onclick = () => post('tool', { kind: 'sculpt', eid: el0.id, strength: +$('#scStr').value, radius: +$('#scRad').value, label: 'Sculpture' });
        $('#scFlat').onclick = () => post('tool', { kind: 'sculpt', eid: el0.id, radius: +$('#scRad').value, flatten: true, flattenTo: +$('#scFlatTo').value, label: 'Aplanir' });
        $('#terExport').onclick = () => {
            const el = get();
            openModal('Heightmap du terrain', `<div class="note">Copie ce JSON dans un fichier .json puis : <b>node tools/heightmap_to_obj.js terrain.json terrain.obj</b> → importe l'OBJ dans Blender (Sollumz) pour créer le vrai terrain lisse (YDR + collision YBN).</div><textarea style="width:100%;height:260px">${esc(JSON.stringify({ cols: el.params.cols, rows: el.params.rows, cell: el.params.cell, base: el.params.base || 0, heights: el.params.heights || [], origin: el.pos, heading: el.rot ? el.rot.z : 0 }))}</textarea>`);
        };
    }
    const df = $('#dfGo', root);
    if (df) df.onclick = () => post('duplicateFloor', { id: el0.id, count: +$('#dfCount').value, floorHeight: +$('#dfH').value });
}

// ---------------------------------------------------------
//  Matériaux
// ---------------------------------------------------------
Panels.renderMaterials = () => {
    const root = $('#materials');
    if (!root || !S.init) return;
    const sel = S.selection.map((id) => S.elements[id]).filter(Boolean);
    const el = sel[0];
    const kitId = el && el.kit ? el.kit : S.newKit;
    const mats = matsOf(kitId);
    const cur = el && el.kit ? el.mat : S.newMat;
    const kit = kitOf(kitId);
    let html = `<div class="note">${el && el.kit ? 'Clic : applique le matériau à la sélection.' : 'Aucun élément architectural sélectionné : le choix s\'applique aux nouveaux éléments.'}</div>
        <div class="sect"><h4>${esc(kit.label || '')}</h4><div class="body"><div class="swatches">`;
    html += mats.map((m) => {
        const off = kit.custom && S.ubkMaterials[m.id] === false;
        const color = m.color || `hsl(${(m.tint || 0) * 22}, 35%, ${30 + (m.tint || 0) * 2}%)`;
        return `<div class="sw${m.id === cur ? ' sel' : ''}${off ? ' off' : ''}" data-mat="${m.id}" title="${off ? 'Modèles non installés' : ''}"><div class="chip" style="background:${color}"></div>${esc(m.label)}${off ? '<span class="badge">absent</span>' : ''}</div>`;
    }).join('');
    html += `</div></div></div>`;
    if (el && (el.type === 'prop' || ['wall', 'facade', 'partition', 'balcony'].includes(el.type))) {
        html += `<div class="sect"><h4>Rendu de l'objet</h4><div class="body">
            ${el.type === 'prop' ? `<div class="row"><label>Teinte (0-15)</label><input type="number" id="tint" min="0" max="15" step="1" value="${el.tint ?? 0}"></div><div class="hint">Seuls les props qui ont des variantes de couleur réagissent (SetObjectTextureVariation).</div>` : ''}
            <div class="row"><label>Transparence</label><input type="range" id="alpha" min="0" max="255" value="${el.alpha ?? 255}"><span id="alphaV">${el.alpha ?? 255}</span></div>
            <div class="hint">Sur un mur, la transparence ne s'applique qu'aux vitres (SetEntityAlpha). Les surfaces opaques ne sont pas rendues transparentes : GTA les affiche mal.</div></div></div>`;
    }
    html += `<div class="sect"><h4>Ce que le moteur permet</h4><div class="body"><table class="list">
        <tr><th>Réglage</th><th>En jeu</th></tr>
        <tr><td>Matériau (béton, brique, bois…)</td><td>Oui : chaque matériau est un vrai modèle texturé du kit</td></tr>
        <tr><td>Couleur</td><td>Teinte de palette (props compatibles) ; texture du kit sinon</td></tr>
        <tr><td>Transparence</td><td>Oui pour le verre et les props (SetEntityAlpha)</td></tr>
        <tr><td>Répétition / échelle / orientation de texture</td><td>Non (UV figés dans le modèle) : réglées à la génération du kit (tools/kit_generator.js --scale / --rotate)</td></tr>
        <tr><td>Réflexion</td><td>Non modifiable en jeu : définie par le shader (Sollumz)</td></tr>
        <tr><td>Texture personnalisée</td><td>Oui, en jeu : image du PC ou lien importé ci-dessous, remplacement réel d'une texture du jeu (AddReplaceTexture)</td></tr>
        </table></div></div>`;
    html += Panels.texturesHtml();
    root.innerHTML = html;
    $$('[data-mat]', root).forEach((s) => s.onclick = () => {
        if (el && el.kit) {
            const list = sel.filter((e) => e.kit === kitId).map((e) => { const c = clone(e); c.mat = s.dataset.mat; return c; });
            post('updateElements', { elements: list, label: 'Matériau' });
        } else { S.newMat = s.dataset.mat; Panels.renderMaterials(); Panels.renderPalette(); }
    });
    const tint = $('#tint', root);
    if (tint) tint.onchange = () => { const c = clone(el); c.tint = +tint.value; post('updateElements', { elements: [c], label: 'Teinte' }); };
    const alpha = $('#alpha', root);
    if (alpha) {
        alpha.oninput = () => { $('#alphaV').textContent = alpha.value; };
        alpha.onchange = () => { const c = clone(el); c.alpha = +alpha.value; post('updateElements', { elements: [c], label: 'Transparence' }); };
    }
    Panels.wireTextures(root);
};

// ---------------------------------------------------------
//  Textures : bibliothèque importée EN JEU (image du PC ou lien https)
//  et remplacements du projet (texture du jeu visée → texture de la bibliothèque)
// ---------------------------------------------------------
const texLib = () => S.texLib || [];
const texById = (id) => texLib().find((t) => t.id === id);
function texThumb(t) {
    if (!t) return '<div class="texThumb empty">?</div>';
    const src = t.kind === 'url' ? t.url : (S.texData && S.texData[t.id]) || '';
    if (t.kind !== 'url' && !src) post('tex:preview', { id: t.id });
    return `<img class="texThumb" data-texprev="${esc(t.id)}" src="${esc(src)}" alt="">`;
}
function texRows() {
    if (!S.texRows) S.texRows = clone((S.project && S.project.textures) || []);
    return S.texRows;
}
Panels.texturesHtml = () => {
    const lib = texLib(), rows = texRows(), sizes = (S.init && S.init.texSizes) || [256, 512, 1024];
    const canImp = can('import');
    const presets = (S.init && S.init.ubkTextures) || [];
    return `<div class="sect"><h4>Bibliothèque de textures <span class="hint">${lib.length}</span></h4><div class="body">
        <div class="hint">Importe une image depuis ton PC ou un lien https : elle est disponible tout de suite, sans copier de fichier ni redémarrer.</div>
        ${canImp ? `<div class="texImport">
            <div class="row"><label>Nom</label><input type="text" id="texName" maxlength="40" placeholder="ex. Brique rouge"></div>
            <div class="row"><label>Résolution</label><select id="texW">${sizes.map((v) => `<option value="${v}" ${v === 512 ? 'selected' : ''}>${v}</option>`).join('')}</select>
              <span>×</span><select id="texH">${sizes.map((v) => `<option value="${v}" ${v === 512 ? 'selected' : ''}>${v}</option>`).join('')}</select></div>
            <div class="btns"><label class="btnlike">🖼️ Image du PC<input type="file" id="texFile" accept="image/png,image/jpeg,image/webp,image/gif" hidden></label></div>
            <div class="row"><input type="text" id="texUrl" placeholder="https://… (lien direct vers une image)"><button id="texUrlAdd">Ajouter le lien</button></div>
            <div class="hint" id="texMsg"></div></div>` : '<div class="note bad">Importer des textures demande la permission « Builder Studio : importer » (admin_menu).</div>'}
        <div class="texGrid">${lib.map((t) => `<div class="texCard" title="${esc(t.name)} · ${t.w}×${t.h}${t.by ? ' · ' + esc(t.by) : ''}">${texThumb(t)}
            <div class="texName">${esc(t.name)}</div><div class="hint">${t.kind === 'url' ? 'lien' : 'image'} · ${t.w}×${t.h}</div>
            ${canImp ? `<button class="mini" data-texdel="${esc(t.id)}" title="Supprimer de la bibliothèque">✕</button>` : ''}</div>`).join('') || '<div class="hint">Bibliothèque vide.</div>'}</div>
        </div></div>
        <div class="sect"><h4>Remplacements du projet</h4><div class="body">
        <div class="hint">GTA ne permet pas de peindre un objet seul : on remplace une texture du jeu (dictionnaire + nom, visibles dans CodeWalker) et TOUS les objets qui l'utilisent changent. Avec le kit architectural, choisis directement un matériau.</div>
        <datalist id="texTargets">${presets.map((p) => `<option value="${esc(p.txd)}|${esc(p.txn)}">Matériau ${esc(p.label)}</option>`).join('')}</datalist>
        <div id="texRows">${rows.map((r, i) => texRowHtml(r, i)).join('') || '<div class="hint">Aucun remplacement.</div>'}</div>
        <div class="btns"><button id="texAdd" ${canImp && S.project ? '' : 'disabled'}>+ Remplacement</button><button class="primary" id="texSave" ${canImp && S.project ? '' : 'disabled'}>Appliquer</button></div></div></div>`;
};
function texRowHtml(r, i) {
    const lib = texLib();
    const target = r.txd ? `${r.txd}|${r.txn}` : '';
    const cur = r.tex || (r.file ? 'file:' + r.file : '');
    return `<div class="texRow" data-i="${i}"><input type="text" data-t="target" list="texTargets" placeholder="dictionnaire|texture (ou un matériau)" value="${esc(target)}">
        <select data-t="tex">${r.file ? `<option value="file:${esc(r.file)}" selected>Fichier ${esc(r.file)}</option>` : ''}<option value="">— texture —</option>${lib.map((t) => `<option value="${esc(t.id)}" ${t.id === cur ? 'selected' : ''}>${esc(t.name)}</option>`).join('')}</select>
        ${texThumb(texById(r.tex))}<button class="mini" data-texrm="${i}" title="Retirer">✕</button></div>`;
}
function readRows(root) {
    return $$('.texRow', root).map((row) => {
        const [txd, txn] = ($('[data-t=target]', row).value || '').trim().split('|').map((x) => (x || '').trim());
        const v = $('[data-t=tex]', row).value;
        const r = { txd: txd || '', txn: txn || '' };
        if (v.startsWith('file:')) r.file = v.slice(5); else if (v) r.tex = v;
        return r;
    });
}
// Image du PC → PNG à la résolution choisie (le jeu demande des puissances de 2)
function imageToPng(file, w, h) {
    return new Promise((resolve, reject) => {
        const fr = new FileReader();
        fr.onerror = () => reject(new Error('Lecture du fichier impossible.'));
        fr.onload = () => {
            const img = new Image();
            img.onerror = () => reject(new Error('Ce fichier n\'est pas une image lisible.'));
            img.onload = () => {
                const c = document.createElement('canvas');
                c.width = w; c.height = h;
                c.getContext('2d').drawImage(img, 0, 0, w, h);
                resolve(c.toDataURL('image/png'));
            };
            img.src = fr.result;
        };
        fr.readAsDataURL(file);
    });
}
Panels.wireTextures = (root) => {
    const msg = (t, bad) => { const m = $('#texMsg', root); if (m) { m.textContent = t; m.style.color = bad ? 'var(--err)' : ''; } };
    const nameOf = (fallback) => ($('#texName', root).value || '').trim() || fallback;
    const file = $('#texFile', root);
    if (file) file.onchange = async () => {
        const f = file.files[0];
        if (!f) return;
        const w = +$('#texW', root).value, h = +$('#texH', root).value;
        msg('Préparation de l\'image…');
        try {
            const data = await imageToPng(f, w, h);
            const max = (S.init && S.init.texMaxBytes) || 3000000;
            if (data.length > max) { msg(`Image trop lourde à ${w}×${h} (${Math.round(data.length / 1000)} Ko) : choisis une résolution plus petite.`, true); return; }
            S.texData = S.texData || {};
            msg('Envoi au serveur…');
            post('tex:upload', { name: nameOf(f.name.replace(/\.[^.]+$/, '').slice(0, 40)), kind: 'image', data, w, h });
        } catch (e) { msg(e.message, true); }
        file.value = '';
    };
    const urlAdd = $('#texUrlAdd', root);
    if (urlAdd) urlAdd.onclick = () => {
        const url = ($('#texUrl', root).value || '').trim();
        if (!/^https:\/\/\S+$/.test(url)) { msg('Le lien doit commencer par https://', true); return; }
        post('tex:upload', { name: nameOf(url.split('/').pop().split('?')[0].slice(0, 40) || 'Image'), kind: 'url', url, w: +$('#texW', root).value, h: +$('#texH', root).value });
        msg('Lien envoyé au serveur…');
    };
    $$('[data-texdel]', root).forEach((b) => b.onclick = () => Panels.confirm('Supprimer la texture', 'Elle disparaît de la bibliothèque. Les remplacements qui l\'utilisent ne s\'afficheront plus.', () => post('tex:remove', { id: b.dataset.texdel })));
    const keep = () => { S.texRows = readRows(root); };
    $$('.texRow input, .texRow select', root).forEach((el) => { el.onchange = () => { keep(); Panels.renderMaterials(); }; });
    $$('[data-texrm]', root).forEach((b) => b.onclick = () => { keep(); S.texRows.splice(+b.dataset.texrm, 1); Panels.renderMaterials(); });
    const add = $('#texAdd', root);
    if (add) add.onclick = () => { keep(); S.texRows.push({ txd: '', txn: '' }); Panels.renderMaterials(); };
    const save = $('#texSave', root);
    if (save) save.onclick = () => {
        keep();
        const bad = S.texRows.find((r) => !r.txd || !r.txn || !/^[\w-]+$/.test(r.txd) || !/^[\w-]+$/.test(r.txn) || !(r.tex || r.file));
        if (bad) { toast('Chaque remplacement : « dictionnaire|texture » (lettres, chiffres, _ ou -) et une texture de la bibliothèque.', 'error'); return; }
        post('textures:set', { list: S.texRows.map((r) => (r.file ? { txd: r.txd, txn: r.txn, file: r.file } : { txd: r.txd, txn: r.txn, tex: r.tex })) });
    };
};

// ---------------------------------------------------------
//  Historique et points de restauration
// ---------------------------------------------------------
Panels.renderHistory = () => {
    const root = $('#historyPanel');
    if (!root) return;
    if (!S.project) { root.innerHTML = '<div class="hint">Aucun projet ouvert.</div>'; return; }
    const versions = (S.project.versions || (S.projects.find((p) => p.id === S.project.id) || {}).versions || []).slice().reverse();
    root.innerHTML = `<div class="sect"><h4>Points de restauration <button data-cmd="snapshot">+ Créer</button></h4><div class="body">
        ${versions.map((v) => `<div class="row"><span style="flex:1">n°${v.n} · ${esc(v.label)}<br><span class="hint">${fmtDate(v.t)} · ${esc(v.by || '')} · ${v.elements || 0} éléments</span></span><button data-rest="${v.n}" ${can('edit') ? '' : 'disabled'}>Restaurer</button></div>`).join('') || '<div class="hint">Aucun point de restauration.</div>'}
        </div></div>
        <div class="sect"><h4>Modifications (serveur)</h4><div class="body"><table class="list">${S.history.slice().reverse().slice(0, 150).map((h) => `<tr><td class="hint">${fmtDate(h.t)}</td><td>${esc(h.by)}</td><td>${esc(h.label)}${h.n ? ' (' + h.n + ')' : ''}</td></tr>`).join('')}</table></div></div>`;
    $$('[data-rest]', root).forEach((b) => b.onclick = () => Panels.confirm('Restaurer', `Revenir au point n°${b.dataset.rest} ? L'état actuel est sauvegardé automatiquement avant.`, () => post('project:restore', { id: S.project.id, n: +b.dataset.rest })));
};
Panels.versionsDialog = () => {
    $$('#right .tabs button').find((b) => b.dataset.tab === 'historique').click();
    post('project:history', { id: S.project.id });
};

// ---------------------------------------------------------
//  Export
// ---------------------------------------------------------
Panels.exportDialog = () => {
    const name = 'map_' + S.project.name.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^\w]+/g, '_').replace(/^_|_$/g, '');
    openModal('Exporter en ressource FiveM', `
        <div class="formgrid"><label>Nom de la ressource</label><input type="text" id="exName" value="${esc(name)}">
        <label>Placement XML CodeWalker</label><label class="chk"><input type="checkbox" id="exYmap" checked> générer &lt;nom&gt;.ymap.xml</label></div>
        <div class="note">L'export crée <b>builder_studio/exports/&lt;nom&gt;/</b> : fxmanifest.lua, scripts client / serveur, data.json, config.lua et LISEZMOI.txt. Cette ressource fonctionne seule (sans builder_studio) dès qu'elle est copiée dans resources/ et démarrée.</div>
        <div class="note bad">Le fichier .ymap.xml est le format texte de CodeWalker, PAS un .ymap : il doit être importé dans CodeWalker pour obtenir le binaire. Les modèles YDR/YTD/YBN du kit architectural sont produits par le pipeline tools/ (Blender + Sollumz), pas par l'export.</div>
        <div class="btns"><button class="primary" id="exGo">Exporter</button></div><div id="exResult"></div>`, 'export');
    $('#exGo').onclick = () => { $('#exResult').innerHTML = '<div class="hint">Export en cours…</div>'; post('export', { name: $('#exName').value, ymap: $('#exYmap').checked }); };
};
Panels.showExportResult = (r) => {
    const box = $('#exResult');
    const html = r.ok
        ? `<div class="note">Export réussi : <b>${esc(r.name)}</b> (${r.pieces} modules statiques)<br>${esc(r.path)}</div><pre class="files">${(r.files || []).map(esc).join('\n')}</pre>${(r.warnings || []).map((w) => `<div class="warn">${esc(w)}</div>`).join('')}`
        : `<div class="note bad">Échec : ${esc(r.error)}</div>`;
    if (box) box.innerHTML = html; else openModal('Export', html);
};

// ---------------------------------------------------------
//  Aide
// ---------------------------------------------------------
Panels.helpDialog = () => openModal('Raccourcis et limites', `
    <table class="list">
    <tr><th>Caméra</th><td>ZQSD / flèches : déplacer · A / E (ou Pg.Préc / Pg.Suiv) : descendre / monter · clic droit maintenu : regarder · molette : avancer · Maj : rapide · Ctrl : lent</td></tr>
    <tr><th>Sélection</th><td>Clic : sélectionner (le groupe parent) · Alt+clic : l'élément seul · Maj/Ctrl+clic : ajouter · Ctrl+A : tout · Échap : désélectionner</td></tr>
    <tr><th>Gizmo</th><td>2 déplacer · 3 rotation · 4 échelle · T repère monde / local · X magnétisme · glisser une flèche (axe) ou le centre (plan horizontal)</td></tr>
    <tr><th>Édition</th><td>Ctrl+Z / Ctrl+Y · Ctrl+C / Ctrl+V · Ctrl+D dupliquer · Suppr · Ctrl+G grouper · Ctrl+Maj+G dégrouper · L verrouiller · H masquer · Fin poser au sol · F centrer</td></tr>
    <tr><th>Placement</th><td>Molette : tourner · Maj+clic : poser plusieurs / enchaîner les murs · Entrée : finir une route</td></tr>
    </table>
    <h5>Limites réelles du moteur GTA V / FiveM</h5>
    <ul>
    <li>Pas de géométrie créée à la volée : murs, sols et toits sont assemblés à partir de modules (kit). Les ouvertures sont de vrais trous dans cet assemblage.</li>
    <li>L'échelle d'un prop est seulement visuelle : la collision reste celle d'origine. Les éléments architecturaux changent donc de dimensions par modules (collision exacte).</li>
    <li>Le relief du sol de GTA ne se modifie pas : les terrains sont des dalles posées par-dessus ; une vraie île lisse passe par le pipeline (OBJ → Sollumz → YDR/YBN).</li>
    <li>L'eau (lacs, rivières, cascades) n'est pas modifiable en jeu ; non implémentée.</li>
    <li>Les intérieurs créés sont des objets dans le monde, pas des MLO (portails, occlusion, ambiance) : à faire dans CodeWalker.</li>
    <li>Lumières : vraies lumières dynamiques, dessinées seulement près de la caméra (limite configurable).</li>
    </ul>`);
Panels.kitsDialog = () => {
    post('kitStatus').then((r) => {
        openModal('État des kits', `<table class="list"><tr><th>Kit</th><th>Modèles présents</th></tr>${Object.entries(r.kits || {}).map(([k, v]) => `<tr><td>${esc(kitOf(k).label || k)}</td><td>${v.present} / ${v.total}</td></tr>`).join('')}</table>
        <div class="note">Détail des modèles absents : commande <b>/${esc(S.settings.command || 'mapping')}_kit</b> (console F8).</div>`);
    });
};
