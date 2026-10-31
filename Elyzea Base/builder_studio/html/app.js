/* =========================================================
   BUILDER STUDIO - INTERFACE (noyau)
   État, communication avec le jeu, entrées souris / clavier,
   menus, hiérarchie (outliner), projets.
   ========================================================= */
'use strict';

const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'builder_studio';
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const clone = (o) => JSON.parse(JSON.stringify(o));
const round = (v, d = 3) => Math.round(v * 10 ** d) / 10 ** d;

const S = {
    open: false, init: null, perms: {}, projects: [], project: null, elements: {}, selection: [], warnings: [],
    mode: 'construction', tool: null, custom: [], fav: [], recent: [], modelStatus: {}, kitStatus: null, ubkMaterials: {},
    history: [], settings: {}, newKit: 'ubk', newMat: 'beton', undo: 0, redo: 0, collapsed: {},
};
window.S = S;

// ---------------------------------------------------------
//  Communication
// ---------------------------------------------------------
function post(name, data) {
    if (!IN_GAME) return Promise.resolve(window.DemoPost ? window.DemoPost(name, data || {}) : { ok: true });
    return fetch(`https://${RES}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({}));
}
window.post = post;

function toast(msg, kind = 'info') {
    const t = document.createElement('div');
    t.className = 'toast ' + kind;
    t.textContent = msg;
    $('#toasts').appendChild(t);
    setTimeout(() => t.remove(), kind === 'error' ? 6000 : 3500);
}
window.toast = toast;

const can = (p) => !!(S.perms[p] || S.perms.admin);
window.can = can;

// ---------------------------------------------------------
//  Messages du jeu
// ---------------------------------------------------------
const handlers = {
    open(d) {
        S.open = true;
        S.init = d; S.perms = d.perms || {}; S.projects = d.projects || []; S.custom = d.custom || [];
        S.settings = d.settings || {};
        $('#app').classList.remove('hidden');
        $('#snap').checked = S.settings.snap !== false;
        $('#grid').value = S.settings.grid || 0.5;
        $('#angle').value = S.settings.angle || 15;
        $('#showGrid').checked = S.settings.showGrid !== false;
        setGizmo(S.settings.gizmo || 'move', S.settings.space || 'world', true);
        applyPerms();
        post('prefs:get').then((r) => {
            S.fav = r.fav || []; S.recent = r.recent || [];
            if (r.layout && r.layout.noBottom) $('#app').classList.add('noBottom');
            Panels.renderPalette();
        });
        refreshModelStatus();
        renderProjects();
        Panels.renderPalette();
        if (!d.current) openHome();
        updateEmpty();
    },
    close() { S.open = false; $('#app').classList.add('hidden'); closeModal(); },
    projects(d) { S.projects = d.projects || []; renderProjects(); },
    project(d) {
        S.project = d.project;
        S.elements = Array.isArray(d.project.elements) ? {} : (d.project.elements || {});
        S.selection = [];
        $('#projName').textContent = d.project.name;
        renderOutliner(); Panels.renderInspector(); Panels.renderMaterials(); renderProjects(); updateEmpty();
        post('project:history', { id: d.project.id });
        if ($('#modal').dataset.kind === 'home') closeModal();
    },
    projectClosed() {
        S.project = null; S.elements = {}; S.selection = [];
        $('#projName').textContent = 'Aucun projet';
        renderOutliner(); Panels.renderInspector(); updateEmpty();
    },
    meta(d) {
        const s = d.summary || {};
        if (S.project && s.id === S.project.id) {
            if (s.name) { S.project.name = s.name; $('#projName').textContent = s.name; }
            if (s.active !== undefined) S.project.active = s.active;
            if (s.versions) S.project.versions = s.versions;
            Panels.renderHistory();
        }
    },
    applied(d) {
        if (!S.project || d.pid !== S.project.id) return;
        for (const op of d.ops || []) {
            if (op.kind === 'remove') for (const id of op.ids || []) delete S.elements[id];
            else for (const el of op.elements || []) S.elements[el.id] = el;
        }
        if (d.selection) S.selection = d.selection;
        if (d.summary) { S.project.summary = d.summary; $('#saveState').textContent = `${d.summary.elements} éléments · ${d.summary.pieces} modules`; }
        renderOutliner(); Panels.renderInspector(); Panels.renderMaterials();
        if (S.mode === 'construction') Panels.renderPalette();
        clearTimeout(handlers._hist); handlers._hist = setTimeout(() => post('project:history', { id: S.project.id }), 600);
    },
    selection(d) { S.selection = d.ids || []; S.warnings = d.warnings || []; renderOutliner(); Panels.renderInspector(); Panels.renderMaterials(); if (S.mode === 'construction') Panels.renderPalette(); $('#stSel').textContent = `${S.selection.length} sélectionné(s)`; },
    notify(d) { toast(d.msg, d.kind); },
    history(d) { if (S.project && d.pid === S.project.id) { S.history = d.history || []; Panels.renderHistory(); } },
    undoState(d) { S.undo = d.undo; S.redo = d.redo; $('#stUndo').textContent = `Annuler : ${d.undo} · Rétablir : ${d.redo}`; },
    status(d) {
        if (d.cam) $('#stCam').textContent = `Caméra ${d.cam.x}, ${d.cam.y}, ${d.cam.z} · cap ${d.cam.h}°`;
        $('#stEnt').textContent = `${d.entities} entités · ${d.loaded} éléments chargés`;
        $('#stFps').textContent = `${d.fps} i/s`;
    },
    tool(d) {
        S.tool = d.active ? d : null;
        const hints = { element: 'Clic : poser · molette : tourner · Maj+clic : poser plusieurs · Échap : annuler', line: 'Clic : début puis fin du mur · Maj : enchaîner · Échap : annuler', path: 'Clics : points · Entrée : terminer · Échap : annuler', room: 'Clic : poser la pièce · molette : tourner', building: 'Clic : poser l\'immeuble · molette : tourner', scatter: 'Clic : centre de la zone', sculpt: 'Clic : élever · Maj+clic : abaisser · Échap : terminer' };
        $('#toolHint').textContent = d.active ? (d.label ? d.label + ' — ' : '') + (hints[d.kind] || '') : '';
        if (!d.active) $$('.card.active').forEach((c) => c.classList.remove('active'));
    },
    dragInfo(d) { const el = $('#dragInfo'); el.textContent = d.text || ''; el.classList.toggle('hidden', !d.text); },
    custom(d) { S.custom = d.custom || []; refreshModelStatus(); Panels.renderPalette(); },
    textures(d) { if (S.project) { S.project.textures = d.textures; Panels.renderMaterials(); } },
    exported(d) { Panels.showExportResult(d.result); },
    recent(d) {
        S.recent = [d.model, ...S.recent.filter((m) => m !== d.model)].slice(0, 30);
        post('prefs:set', { recent: S.recent });
    },
};
window.addEventListener('message', (e) => {
    const d = e.data || {};
    const h = handlers[d.action];
    if (h) { try { h(d); } catch (err) { console.error(d.action, err); } }
});
window.handlers = handlers;

function updateEmpty() { $('#emptyHint').classList.toggle('hidden', !!S.project); }

function applyPerms() {
    $$('[data-perm]').forEach((el) => {
        const ok = can(el.dataset.perm);
        el.classList.toggle('disabled', !ok);
        if (el.tagName === 'BUTTON') el.disabled = !ok;
    });
}

function refreshModelStatus() {
    const models = [...(S.init?.catalog || []), ...S.custom].map((i) => i.model);
    post('checkModels', { models }).then((r) => { if (r.models) { Object.assign(S.modelStatus, r.models); Panels.renderPalette(); } });
    post('kitStatus').then((r) => { if (r.kits) { S.kitStatus = r.kits; S.ubkMaterials = r.ubkMaterials || {}; Panels.renderMaterials(); Panels.renderPalette(); } });
}
window.refreshModelStatus = refreshModelStatus;

// ---------------------------------------------------------
//  Vue 3D : souris
// ---------------------------------------------------------
const vp = $('#viewport');
let looking = false, lookAcc = { dx: 0, dy: 0 }, lookTimer = null, moveQueued = null;
const norm = (e) => ({ x: e.clientX / window.innerWidth, y: e.clientY / window.innerHeight });
const mods = (e) => ({ shift: e.shiftKey, ctrl: e.ctrlKey, alt: e.altKey });

vp.addEventListener('contextmenu', (e) => e.preventDefault());
vp.addEventListener('mousedown', (e) => {
    closeMenus();
    if (document.activeElement && document.activeElement !== document.body) document.activeElement.blur();
    if (e.button === 2) { looking = true; return; }
    if (e.button === 0) post('mouse', { t: 'down', b: 0, ...norm(e), ...mods(e) });
});
window.addEventListener('mouseup', (e) => {
    if (e.button === 2) { looking = false; return; }
    if (e.button === 0) post('mouse', { t: 'up', b: 0, ...norm(e), ...mods(e) });
});
window.addEventListener('mousemove', (e) => {
    if (!S.open) return;
    if (looking) {
        lookAcc.dx += e.movementX; lookAcc.dy += e.movementY;
        if (!lookTimer) lookTimer = setTimeout(() => { post('look', lookAcc); lookAcc = { dx: 0, dy: 0 }; lookTimer = null; }, 16);
        return;
    }
    if (e.target !== vp && !vp.contains(e.target)) return;
    const wasQueued = !!moveQueued;
    moveQueued = { t: 'move', ...norm(e), ...mods(e) };
    if (!wasQueued) requestAnimationFrame(() => { post('mouse', moveQueued); moveQueued = null; });
});
vp.addEventListener('wheel', (e) => { e.preventDefault(); post('wheel', { dy: e.deltaY, ...mods(e) }); }, { passive: false });

// ---------------------------------------------------------
//  Clavier
// ---------------------------------------------------------
const CAM_KEYS = new Set(['KeyW', 'KeyA', 'KeyS', 'KeyD', 'KeyQ', 'KeyE', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'PageUp', 'PageDown', 'ShiftLeft', 'ShiftRight', 'ControlLeft']);
const typing = (e) => ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName) && e.target.type !== 'checkbox';
const down = new Set();

window.addEventListener('keydown', (e) => {
    if (!S.open) return;
    if (e.code === 'Escape') {
        e.preventDefault();
        if (!$('#modal').classList.contains('hidden')) return closeModal();
        if (closeMenus()) return;
        if (S.tool) return post('action', { name: 'cancelTool' });
        if (S.selection.length) return post('select', { ids: [] });
        return post('close');
    }
    if (typing(e)) return;
    if (CAM_KEYS.has(e.code) && !e.ctrlKey || e.code === 'ShiftLeft' || e.code === 'ControlLeft') {
        if (!down.has(e.code)) { down.add(e.code); post('key', { code: e.code, down: true }); }
    }
    const k = e.code, c = e.ctrlKey;
    const run = (cmd) => { e.preventDefault(); command(cmd); };
    if (c && k === 'KeyZ' && !e.shiftKey) return run('undo');
    if (c && (k === 'KeyY' || (k === 'KeyZ' && e.shiftKey))) return run('redo');
    if (c && k === 'KeyC') return run('copy');
    if (c && k === 'KeyV') return run('paste');
    if (c && k === 'KeyD') return run('duplicate');
    if (c && k === 'KeyA') return run('selectAll');
    if (c && k === 'KeyS') return run('save');
    if (c && k === 'KeyG') return run(e.shiftKey ? 'ungroup' : 'group');
    if (c) return;
    if (k === 'Delete' || k === 'Backspace') return run('delete');
    if (k === 'Enter') return run('finishPath');
    if (k === 'Digit2' || k === 'Numpad2') return setGizmo('move');
    if (k === 'Digit3' || k === 'Numpad3') return setGizmo('rotate');
    if (k === 'Digit4' || k === 'Numpad4') return setGizmo('scale');
    if (k === 'KeyT') return setGizmo(null, S.settings.space === 'world' ? 'local' : 'world');
    if (k === 'KeyX') return run('toggleSnap');
    if (k === 'KeyF') return run('focus');
    if (k === 'KeyL') return run('lock');
    if (k === 'KeyH') return run('hide');
    if (k === 'End') return run('ground');
});
window.addEventListener('keyup', (e) => {
    if (down.has(e.code)) { down.delete(e.code); post('key', { code: e.code, down: false }); }
});
window.addEventListener('blur', () => { down.clear(); post('keysReset'); });
document.addEventListener('focusin', (e) => { if (typing(e)) { down.clear(); post('keysReset'); } });

// ---------------------------------------------------------
//  Barre d'outils et menus
// ---------------------------------------------------------
function setGizmo(mode, space, silent) {
    if (mode) S.settings.gizmo = mode;
    if (space) S.settings.space = space;
    $$('[data-gizmo]').forEach((b) => b.classList.toggle('active', b.dataset.gizmo === S.settings.gizmo));
    $('#btnSpace').textContent = S.settings.space === 'local' ? 'Local' : 'Monde';
    if (!silent) post('setGizmo', { mode: S.settings.gizmo, space: S.settings.space });
}
$$('[data-gizmo]').forEach((b) => b.addEventListener('click', () => setGizmo(b.dataset.gizmo)));
$('#btnSpace').addEventListener('click', () => setGizmo(null, S.settings.space === 'world' ? 'local' : 'world'));
const pushSnap = () => post('setSnap', { snap: $('#snap').checked, grid: +$('#grid').value, angle: +$('#angle').value, showGrid: $('#showGrid').checked });
['snap', 'grid', 'angle', 'showGrid'].forEach((id) => $('#' + id).addEventListener('change', pushSnap));

function closeMenus() {
    const open = $$('.menu.open');
    open.forEach((m) => m.classList.remove('open'));
    return open.length > 0;
}
$$('.menu').forEach((m) => {
    m.addEventListener('click', (e) => {
        if (e.target.closest('.dropdown')) return;
        const was = m.classList.contains('open');
        closeMenus();
        if (!was) m.classList.add('open');
    });
    m.addEventListener('mouseenter', () => { if ($$('.menu.open').length && !m.classList.contains('open')) { closeMenus(); m.classList.add('open'); } });
});
document.addEventListener('click', (e) => {
    const a = e.target.closest('[data-cmd]');
    if (a && !a.classList.contains('disabled') && !a.disabled) { closeMenus(); command(a.dataset.cmd); }
});
$('#btnClose').addEventListener('click', () => post('close'));
$$('#modes button').forEach((b) => b.addEventListener('click', () => {
    S.mode = b.dataset.mode;
    $$('#modes button').forEach((x) => x.classList.toggle('active', x === b));
    Panels.renderPalette();
}));
$$('.tabs').forEach((tabs) => {
    const panel = tabs.parentElement;
    $$('button', tabs).forEach((b) => b.addEventListener('click', () => {
        $$('button', tabs).forEach((x) => x.classList.toggle('active', x === b));
        $$('.tabpage', panel).forEach((p) => p.classList.toggle('hidden', p.dataset.page !== b.dataset.tab));
        if (b.dataset.tab === 'historique' && S.project) post('project:history', { id: S.project.id });
    }));
});

const needProject = () => { if (!S.project) { toast('Ouvre ou crée d\'abord un projet.', 'error'); return false; } return true; };

function command(cmd) {
    const sel = S.selection;
    const A = (name, extra) => post('action', { name, ...(extra || {}) });
    const map = {
        home: openHome, newProject: () => Panels.newProjectDialog(),
        save: () => needProject() && post('project:save', { id: S.project.id }),
        snapshot: () => needProject() && Panels.prompt('Point de restauration', 'Nom du point de restauration', 'Avant modifications', (v) => post('project:snapshot', { id: S.project.id, label: v })),
        versions: () => needProject() && Panels.versionsDialog(),
        publish: () => needProject() && post('project:active', { id: S.project.id, active: !S.project.active }),
        export: () => needProject() && Panels.exportDialog(),
        closeProject: () => { post('project:close'); handlers.projectClosed(); },
        quit: () => post('close'),
        undo: () => A('undo'), redo: () => A('redo'), copy: () => A('copy'), paste: () => A('paste'),
        duplicate: () => A('duplicate'), delete: () => sel.length && A('delete'), group: () => A('group'), ungroup: () => A('ungroup'),
        lock: () => A('lock'), hide: () => sel.length && post('toggleHidden', { ids: sel, hidden: !(S.elements[sel[0]] || {}).hidden }),
        selectAll: () => A('selectAll'), deselect: () => post('select', { ids: [] }),
        ground: () => A('ground'), focus: () => A('focus'), test: () => A('testHere'), finishPath: () => A('finishPath'),
        toggleGrid: () => { $('#showGrid').checked = !$('#showGrid').checked; pushSnap(); },
        toggleSnap: () => { $('#snap').checked = !$('#snap').checked; pushSnap(); toast($('#snap').checked ? 'Magnétisme activé' : 'Magnétisme désactivé'); },
        toggleBottom: () => { $('#app').classList.toggle('noBottom'); post('prefs:set', { layout: { noBottom: $('#app').classList.contains('noBottom') } }); },
        help: () => Panels.helpDialog(), kits: () => Panels.kitsDialog(),
    };
    for (const ax of ['X', 'Y', 'Z']) {
        for (const m of ['min', 'center', 'max']) map['align' + ax + m] = () => A('align', { axis: ax.toLowerCase(), mode: m });
        map['dist' + ax] = () => A('distribute', { axis: ax.toLowerCase() });
    }
    if (map[cmd]) map[cmd]();
}
window.command = command;

// ---------------------------------------------------------
//  Fenêtres modales
// ---------------------------------------------------------
function openModal(title, html, kind) {
    $('#modalTitle').textContent = title;
    $('#modalBody').innerHTML = html;
    $('#modal').dataset.kind = kind || '';
    $('#modal').classList.remove('hidden');
    return $('#modalBody');
}
function closeModal() { $('#modal').classList.add('hidden'); $('#modal').dataset.kind = ''; }
window.openModal = openModal; window.closeModal = closeModal;
$('#modalClose').addEventListener('click', closeModal);

// ---------------------------------------------------------
//  Hiérarchie (outliner)
// ---------------------------------------------------------
const ICONS = { group: '▣', prop: '◈', wall: '▤', partition: '▥', facade: '▦', floor: '▭', ceiling: '▔', foundation: '▬', roof: '⌂', stairs: '☰', column: '▯', pillar: '▮', balcony: '⊓', terrace: '⊔', light: '✦', scatter: '♣', terrain: '⛰', road: '═', elevator: '⇕' };
let dragId = null;

function renderOutliner() {
    const root = $('#outliner');
    const filter = ($('#outlinerFilter').value || '').toLowerCase();
    const kids = {};
    const els = S.elements;
    for (const id in els) {
        const p = els[id].parent && els[els[id].parent] ? els[id].parent : '_root';
        (kids[p] = kids[p] || []).push(id);
    }
    const sortFn = (a, b) => {
        const A = els[a], B = els[b];
        if ((A.type === 'group') !== (B.type === 'group')) return A.type === 'group' ? -1 : 1;
        if ((A.level ?? 0) !== (B.level ?? 0)) return (A.level ?? 0) - (B.level ?? 0);
        return String(A.name).localeCompare(String(B.name));
    };
    const selSet = new Set(S.selection);
    const matches = (id) => !filter || String(els[id].name || '').toLowerCase().includes(filter) || (kids[id] || []).some(matches);
    const html = [];
    const walk = (id, depth) => {
        const el = els[id];
        if (!matches(id)) return;
        const has = (kids[id] || []).length > 0;
        const col = S.collapsed[id] && !filter;
        html.push(`<div class="node${selSet.has(id) ? ' sel' : ''}" draggable="true" data-id="${id}">
            <span class="caret" data-caret="${has ? id : ''}">${has ? (col ? '▸' : '▾') : ''}</span>
            <span class="ico">${ICONS[el.type] || '•'}</span>
            <span class="nm${el.hidden ? ' hid' : ''}">${esc(el.name || el.type)}</span>
            <span class="tg${el.hidden ? '' : ' on'}" data-eye="${id}" title="Masquer / afficher">👁</span>
            <span class="tg${el.locked ? ' on' : ''}" data-lock="${id}" title="Verrouiller">${el.locked ? '🔒' : '🔓'}</span></div>`);
        if (has && !col) {
            html.push('<div class="children">');
            kids[id].sort(sortFn).forEach((k) => walk(k, depth + 1));
            html.push('</div>');
        }
    };
    (kids._root || []).sort(sortFn).forEach((id) => walk(id, 0));
    root.innerHTML = html.join('') || `<div class="hint">${S.project ? 'Projet vide : choisis un outil dans le panneau du bas.' : 'Aucun projet ouvert.'}</div>`;
}
window.renderOutliner = renderOutliner;
$('#outlinerFilter').addEventListener('input', renderOutliner);

$('#outliner').addEventListener('click', (e) => {
    const caret = e.target.closest('[data-caret]');
    if (caret && caret.dataset.caret) { S.collapsed[caret.dataset.caret] = !S.collapsed[caret.dataset.caret]; return renderOutliner(); }
    const eye = e.target.closest('[data-eye]');
    if (eye) { const el = S.elements[eye.dataset.eye]; return post('toggleHidden', { ids: [el.id], hidden: !el.hidden }); }
    const lock = e.target.closest('[data-lock]');
    if (lock) {
        const el = clone(S.elements[lock.dataset.lock]);
        el.locked = !el.locked;
        return post('updateElements', { elements: [el], label: el.locked ? 'Verrouillage' : 'Déverrouillage' });
    }
    const n = e.target.closest('.node');
    if (n) post('select', { ids: [n.dataset.id], additive: e.ctrlKey || e.shiftKey });
});
$('#outliner').addEventListener('dblclick', (e) => {
    const n = e.target.closest('.node');
    if (n) { post('select', { ids: [n.dataset.id] }).then(() => command('focus')); }
});
$('#outliner').addEventListener('dragstart', (e) => { const n = e.target.closest('.node'); dragId = n && n.dataset.id; });
$('#outliner').addEventListener('dragover', (e) => {
    e.preventDefault();
    $$('.node.dropTarget').forEach((x) => x.classList.remove('dropTarget'));
    const n = e.target.closest('.node');
    if (n && S.elements[n.dataset.id]?.type === 'group') n.classList.add('dropTarget');
});
$('#outliner').addEventListener('drop', (e) => {
    e.preventDefault();
    $$('.node.dropTarget').forEach((x) => x.classList.remove('dropTarget'));
    const n = e.target.closest('.node');
    if (!dragId) return;
    const target = n && S.elements[n.dataset.id]?.type === 'group' ? n.dataset.id : null;
    if (target === dragId) return;
    const ids = S.selection.includes(dragId) ? S.selection : [dragId];
    post('reparent', { ids, parent: target });
    dragId = null;
});

// ---------------------------------------------------------
//  Projets
// ---------------------------------------------------------
const fmtDate = (t) => t ? new Date(t * 1000).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }) : '—';
window.fmtDate = fmtDate;

function projectCard(p) {
    const cur = S.project && S.project.id === p.id;
    return `<div class="proj${cur ? ' cur' : ''}" data-pid="${p.id}">
        <div class="nm">${esc(p.name)} ${p.active ? '<span class="tag on">publié</span>' : '<span class="tag">brouillon</span>'}</div>
        <div class="meta">${p.elements || 0} éléments · ${p.pieces || 0} modules · ${esc(p.ownerName || '')} · ${fmtDate(p.updated)}</div>
        <div class="btns">
            <button data-pa="open" class="${cur ? '' : 'primary'}">${cur ? 'Ouvert' : 'Ouvrir'}</button>
            <button data-pa="goto" title="Aller à l'origine">◎</button>
            <button data-pa="rename" ${can('edit') ? '' : 'disabled'}>Renommer</button>
            <button data-pa="dup" ${can('build') ? '' : 'disabled'}>Dupliquer</button>
            <button data-pa="pub" ${can('edit') ? '' : 'disabled'}>${p.active ? 'Retirer' : 'Publier'}</button>
            <button data-pa="del" class="danger" ${can('delete') ? '' : 'disabled'}>Supprimer</button>
        </div></div>`;
}

function renderProjects() {
    const html = S.projects.map(projectCard).join('') || '<div class="hint">Aucun projet pour l\'instant.</div>';
    $('#projectList').innerHTML = html;
    if ($('#modal').dataset.kind === 'home') { const l = $('#homeList'); if (l) l.innerHTML = html; }
}
window.renderProjects = renderProjects;

function projectAction(e) {
    const b = e.target.closest('[data-pa]');
    if (!b) return;
    const pid = b.closest('[data-pid]').dataset.pid;
    const p = S.projects.find((x) => x.id === pid);
    if (!p) return;
    const a = b.dataset.pa;
    if (a === 'open') { post('project:load', { id: pid }); if (p.origin) post('project:goto', { pos: p.origin }); }
    if (a === 'goto' && p.origin) post('project:goto', { pos: p.origin });
    if (a === 'rename') Panels.prompt('Renommer le projet', 'Nouveau nom', p.name, (v) => post('project:rename', { id: pid, name: v }));
    if (a === 'dup') Panels.prompt('Dupliquer le projet', 'Nom de la copie', p.name + ' (copie)', (v) => post('project:duplicate', { id: pid, name: v }));
    if (a === 'pub') post('project:active', { id: pid, active: !p.active });
    if (a === 'del') Panels.confirm('Supprimer le projet', `Supprimer définitivement « ${esc(p.name)} » et ses points de restauration ?`, () => post('project:delete', { id: pid }));
}
$('#projectList').addEventListener('click', projectAction);

function openHome() {
    const body = openModal('Gestionnaire de projets', `
        <div class="row"><input type="text" id="homeName" placeholder="Nom du nouveau projet" value="Nouveau projet">
        <button class="primary" id="homeCreate" ${can('build') ? '' : 'disabled'}>Créer ici</button></div>
        <div class="note">Le projet est créé à la position de la caméra. Chaque projet est indépendant : coordonnées, rotations, dimensions, modèles, matériaux, groupes et métadonnées sont enregistrés côté serveur (sauvegarde automatique, points de restauration).</div>
        <div id="homeList"></div>`, 'home');
    $('#homeList').innerHTML = S.projects.map(projectCard).join('') || '<div class="hint">Aucun projet pour l\'instant.</div>';
    $('#homeList').addEventListener('click', projectAction);
    $('#homeCreate').addEventListener('click', () => { post('project:create', { name: $('#homeName').value }); });
}
window.openHome = openHome;
