'use strict';

/* ════════════════════════════════════════════════════════════
   Communication avec le client Lua
   ════════════════════════════════════════════════════════════ */

const IN_GAME = typeof window.GetParentResourceName === 'function';
const RES = IN_GAME ? window.GetParentResourceName() : 'ely_creator';

async function post(name, data = {}) {
    if (!IN_GAME) return mockResponse(name, data);
    try {
        const r = await fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        });
        return await r.json();
    } catch (e) {
        return {};
    }
}

// Regroupe les mises à jour rapides (sliders, couleurs) en un seul envoi toutes les 35 ms
const pending = new Map();
let queueTimer = null;
function queue(key, payload) {
    pending.set(key, payload);
    if (!queueTimer) queueTimer = setTimeout(flushQueue, 35);
}
function flushQueue() {
    queueTimer = null;
    if (!pending.size) return;
    const items = [...pending.values()];
    pending.clear();
    post('batch', { items });
}

function throttle(fn, ms) {
    let last = 0, timer = null, args = null;
    return (...a) => {
        args = a;
        const now = Date.now();
        if (now - last >= ms) {
            last = now;
            fn(...args);
        } else if (!timer) {
            timer = setTimeout(() => { timer = null; last = Date.now(); fn(...args); }, ms - (now - last));
        }
    };
}

/* ════════════════════════════════════════════════════════════
   Données GTA V (valeurs de base du jeu)
   ════════════════════════════════════════════════════════════ */

const PARENTS = [
    'Benjamin', 'Daniel', 'Joshua', 'Noah', 'Andrew', 'Juan', 'Alex', 'Isaac', 'Evan', 'Ethan',
    'Vincent', 'Angel', 'Diego', 'Adrian', 'Gabriel', 'Michael', 'Santiago', 'Kevin', 'Louis', 'Samuel',
    'Anthony', 'Hannah', 'Audrey', 'Jasmine', 'Giselle', 'Amelia', 'Isabella', 'Zoe', 'Ava', 'Camila',
    'Violet', 'Sophia', 'Evelyn', 'Nicole', 'Ashley', 'Grace', 'Brianna', 'Natalie', 'Olivia', 'Elizabeth',
    'Charlotte', 'Emma', 'Claude', 'Niko', 'John', 'Misty'
];
const MOTHERS = [...Array.from({ length: 21 }, (_, i) => i + 21), 45];
const FATHERS = [...Array.from({ length: 21 }, (_, i) => i), 42, 43, 44];

const FEATURE_GROUPS = [
    { title: 'Nez', items: [
        [0, 'Largeur', 'Étroit', 'Large'],
        [1, 'Hauteur de la pointe', 'Haute', 'Basse'],
        [2, 'Longueur', 'Long', 'Court'],
        [3, "Hauteur de l'arête", 'Creusée', 'Bombée'],
        [4, 'Abaissement de la pointe', 'Relevée', 'Tombante'],
        [5, "Déviation de l'arête", 'Gauche', 'Droite']
    ] },
    { title: 'Sourcils', items: [
        [6, 'Hauteur', 'Hauts', 'Bas'],
        [7, 'Profondeur', 'Rentrés', 'Saillants']
    ] },
    { title: 'Pommettes et joues', items: [
        [8, 'Hauteur des pommettes', 'Hautes', 'Basses'],
        [9, 'Largeur des pommettes', 'Étroites', 'Larges'],
        [10, 'Volume des joues', 'Pleines', 'Creusées']
    ] },
    { title: 'Yeux et lèvres', items: [
        [11, 'Ouverture des yeux', 'Ouverts', 'Plissés'],
        [12, 'Épaisseur des lèvres', 'Fines', 'Épaisses']
    ] },
    { title: 'Mâchoire', items: [
        [13, 'Largeur', 'Étroite', 'Large'],
        [14, 'Forme', 'Ronde', 'Carrée']
    ] },
    { title: 'Menton', items: [
        [15, 'Hauteur', 'Haut', 'Bas'],
        [16, 'Profondeur', 'Rentré', 'Avancé'],
        [17, 'Largeur', 'Étroit', 'Large'],
        [18, 'Fossette', 'Aucune', 'Marquée']
    ] },
    { title: 'Cou', items: [
        [19, 'Épaisseur', 'Fin', 'Épais']
    ] }
];

const EYE_COLORS = [
    ['Vert', '#3f7d3a'], ['Émeraude', '#1f8a5b'], ['Bleu clair', '#7fb7e6'], ['Bleu océan', '#2f6fb3'],
    ['Brun clair', '#a0703f'], ['Brun foncé', '#5a3a22'], ['Noisette', '#8e6b3a'], ['Gris foncé', '#4b4f55'],
    ['Gris clair', '#9aa1a8'], ['Rose', '#e48fb4'], ['Jaune', '#e8c84a'], ['Violet', '#7d4fc1'],
    ['Noir total', '#151515'], ['Nuances de gris', '#777777'], ['Tequila Sunrise', '#e8763a'], ['Atomique', '#5ee0a0'],
    ['Distorsion', '#9b59d0'], ['ECola', '#c0392b'], ['Space Ranger', '#3aa0e8'], ['Yin-yang', '#dddddd'],
    ['Cible', '#d93636'], ['Lézard', '#7ac143'], ['Dragon', '#e05a1e'], ['Extraterrestre', '#58e05a'],
    ['Chèvre', '#c9a227'], ['Smiley', '#f5d742'], ['Possédé', '#b31212'], ['Démon', '#8b0000'],
    ['Infecté', '#9acd32'], ['Alien', '#00c8a0'], ['Mort-vivant', '#b8c4a0'], ['Zombie', '#8fa36b']
];

const OVERLAYS = {
    0: { name: 'Imperfections', palette: null },
    1: { name: 'Barbe', palette: 'hair' },
    2: { name: 'Sourcils', palette: 'hair' },
    3: { name: 'Vieillissement', palette: null },
    4: { name: 'Maquillage des yeux', palette: null },
    5: { name: 'Blush', palette: 'makeup' },
    6: { name: 'Teint', palette: null },
    7: { name: 'Dommages du soleil', palette: null },
    8: { name: 'Rouge à lèvres', palette: 'makeup' },
    9: { name: 'Taches de rousseur et grains de beauté', palette: null },
    10: { name: 'Pilosité du torse', palette: 'hair' },
    11: { name: 'Imperfections du corps', palette: null },
    12: { name: 'Imperfections du corps (suite)', palette: null }
};

const COMPONENTS = [
    [11, 'Haut'], [8, 'Sous-haut'], [3, 'Bras et gants'], [4, 'Bas'], [6, 'Chaussures'],
    [7, 'Cou et bijoux'], [9, 'Gilet'], [5, 'Sac'], [1, 'Masque'], [10, 'Badges et logos']
];

const PROPS = [
    [0, 'Chapeau et casque'], [1, 'Lunettes'], [2, 'Oreilles'], [6, 'Montre'], [7, 'Bracelet']
];

const ICONS = {
    identity: '<path d="M4 6h16v12H4z"/><circle cx="9" cy="11" r="2"/><path d="M6.5 15.5c.6-1.4 1.5-2 2.5-2s1.9.6 2.5 2M14 10h4M14 13h3"/>',
    heritage: '<circle cx="7" cy="7" r="2.5"/><circle cx="17" cy="7" r="2.5"/><circle cx="12" cy="16" r="2.5"/><path d="M7 9.5v1.5a3 3 0 0 0 3 3M17 9.5v1.5a3 3 0 0 1-3 3"/>',
    face: '<path d="M12 3c4 0 7 3 7 7.5S16 20 12 21c-4-1-7-6-7-10.5S8 3 12 3z"/><path d="M12 9v4l-1 1M10 17h4"/>',
    eyes: '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    hair: '<path d="M5 13c0-5 3-9 7-9s7 4 7 9"/><path d="M5 13c1-3 3-4 6-4.5M19 13c-1-2-3-3.5-5-4M5 13v6M19 13v6"/>',
    skin: '<circle cx="12" cy="12" r="8.5"/><circle cx="9" cy="10" r=".8"/><circle cx="14.5" cy="13.5" r=".8"/><circle cx="11" cy="15" r=".6"/>',
    makeup: '<path d="M9 21h6v-8H9zM10 13V7l4-3v9"/>',
    clothes: '<path d="M8 3 4 6l2 4 2-1v12h8V9l2 1 2-4-4-3c-.5 1.5-2 2.5-4 2.5S8.5 4.5 8 3z"/>',
    props: '<circle cx="7" cy="14" r="3.5"/><circle cx="17" cy="14" r="3.5"/><path d="M10.5 14c.5-.6 2.5-.6 3 0M3.5 14 3 9M20.5 14 21 9"/>'
};

const TABS = [
    { id: 'identity', title: 'Identité', desc: 'Votre nom, votre âge, vos origines.' },
    { id: 'heritage', title: 'Hérédité', desc: 'Choisissez vos parents. Ils définissent la base du visage et la couleur de peau.' },
    { id: 'face', title: 'Visage', desc: 'Affinez chaque trait. Double-cliquez sur un curseur pour le remettre au centre.' },
    { id: 'eyes', title: 'Yeux et sourcils', desc: 'Couleur du regard et forme des sourcils.' },
    { id: 'hair', title: 'Cheveux et pilosité', desc: 'Coupe, couleurs, barbe et poils du torse.' },
    { id: 'skin', title: 'Peau', desc: 'Grain de peau, âge apparent, taches et marques.' },
    { id: 'makeup', title: 'Maquillage', desc: 'Yeux, joues et lèvres.' },
    { id: 'clothes', title: 'Tenue', desc: 'Choisissez votre tenue de départ. Vous pourrez en changer en boutique.' }
];

const RANDOMIZABLE = new Set(['heritage', 'face', 'eyes', 'hair', 'skin', 'makeup']);

/* ════════════════════════════════════════════════════════════
   État
   ════════════════════════════════════════════════════════════ */

const state = {
    tab: 0,
    visited: new Set([0]),
    skin: null,
    limits: null,
    palettes: { hair: [], makeup: [] },
    cfg: null,
    identity: null,
    angle: 0
};

const $ = (s) => document.querySelector(s);
const body = $('#panelBody');

function el(tag, cls, html) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
}

function txt(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    e.textContent = text;
    return e;
}

/* ════════════════════════════════════════════════════════════
   Composants d'interface
   ════════════════════════════════════════════════════════════ */

function group(title, note) {
    const g = el('div', 'group');
    if (title) {
        const t = el('div', 'group-title');
        t.append(document.createTextNode(title));
        if (note) t.append(txt('small', null, note));
        g.append(t);
    }
    body.append(g);
    return g;
}

function fieldShell(parent, label) {
    const f = el('div', 'field');
    const head = el('div', 'field-head');
    head.append(txt('span', 'label', label));
    const value = el('span', 'value');
    head.append(value);
    f.append(head);
    parent.append(f);
    return { f, value };
}

function slider(parent, o) {
    const { f, value } = fieldShell(parent, o.label);
    const input = el('input', 'range' + (o.centered ? ' centered' : ''));
    input.type = 'range';
    input.min = o.min; input.max = o.max; input.step = o.step; input.value = o.value;
    const paint = () => {
        const p = ((input.value - o.min) / (o.max - o.min)) * 100;
        input.style.setProperty('--p', p + '%');
        value.textContent = o.fmt ? o.fmt(+input.value) : input.value;
    };
    input.addEventListener('input', () => { paint(); o.onInput(+input.value); });
    if (o.reset !== undefined) {
        input.addEventListener('dblclick', () => { input.value = o.reset; paint(); o.onInput(+o.reset); });
    }
    f.append(input);
    if (o.left || o.right) {
        const ends = el('div', 'ends');
        ends.append(txt('span', null, o.left || ''), txt('span', null, o.right || ''));
        f.append(ends);
    }
    paint();
    return { set(v) { input.value = v; paint(); } };
}

/**
 * Sélecteur à flèches. Valeurs entières de min à max (inclus), avec rebouclage.
 * o.names(v) -> libellé ; sinon un champ numérique éditable (1-indexé pour l'affichage).
 */
function stepper(parent, o) {
    const { f, value } = fieldShell(parent, o.label);
    const row = el('div', 'stepper');
    const prev = el('button', 'step-btn', '‹');
    const next = el('button', 'step-btn', '›');
    const mid = el('div', 'step-mid');
    const name = el('span', 'step-name');
    const input = el('input', 'step-input');
    input.type = 'number';
    mid.append(o.names ? name : input);
    row.append(prev, mid, next);
    f.append(row);

    let v = o.value, min = o.min, max = o.max;

    const render = () => {
        const total = max - min + 1;
        if (o.names) name.textContent = o.names(v);
        else input.value = v - min + 1;
        value.textContent = total > 0 ? `${v - min + 1} / ${total}` : 'Aucune variante';
        prev.disabled = next.disabled = total <= 1;
        input.disabled = total <= 1;
    };

    const set = (nv, fire = true, wrap = true) => {
        if (max < min) { v = min; render(); return; }
        if (wrap) {
            if (nv > max) nv = min;
            if (nv < min) nv = max;
        } else {
            nv = Math.max(min, Math.min(max, nv));
        }
        if (nv === v && fire) { render(); return; }
        v = nv;
        render();
        if (fire) o.onChange(v);
    };

    prev.addEventListener('click', () => set(v - 1));
    next.addEventListener('click', () => set(v + 1));
    input.addEventListener('change', () => {
        const n = parseInt(input.value, 10);
        if (Number.isNaN(n)) return render();
        set(n - 1 + min, true, false);
    });
    row.addEventListener('wheel', (e) => {
        e.preventDefault();
        e.stopPropagation();
        set(v + (e.deltaY > 0 ? 1 : -1));
    }, { passive: false });

    render();
    return {
        set: (nv) => set(nv, false, false),
        setMax(m) { max = m; if (v > max) v = Math.max(min, max); render(); },
        get value() { return v; }
    };
}

function swatches(parent, label, colors, current, onPick) {
    const { f, value } = fieldShell(parent, label);
    const grid = el('div', 'swatches');
    const buttons = colors.map((c, i) => {
        const b = el('button', 'swatch' + (i === current ? ' active' : ''));
        b.style.background = `rgb(${c[0]}, ${c[1]}, ${c[2]})`;
        b.title = `Teinte ${i + 1}`;
        b.addEventListener('click', () => {
            buttons.forEach((x) => x.classList.remove('active'));
            b.classList.add('active');
            value.textContent = `${i + 1} / ${colors.length}`;
            onPick(i);
        });
        grid.append(b);
        return b;
    });
    value.textContent = colors.length ? `${current + 1} / ${colors.length}` : '';
    f.append(grid);
}

/* ════════════════════════════════════════════════════════════
   Envoi des modifications
   ════════════════════════════════════════════════════════════ */

const seq = {};
function nextSeq(key) { seq[key] = (seq[key] || 0) + 1; return seq[key]; }

function sendHeritage() {
    queue('heritage', { type: 'heritage', ...state.skin.heritage });
}

function sendOverlay(id) {
    queue('overlay' + id, { type: 'overlay', id, ...state.skin.overlays[id] });
}

function overlayControls(parent, id, opts = {}) {
    const o = state.skin.overlays[id];
    const count = state.limits.overlays[id] || 0;
    const meta = OVERLAYS[id];

    stepper(parent, {
        label: opts.styleLabel || 'Style',
        value: o.style, min: -1, max: count - 1,
        names: (v) => (v < 0 ? 'Aucun' : `Style ${v + 1}`),
        onChange: (v) => { o.style = v; sendOverlay(id); }
    });

    slider(parent, {
        label: 'Intensité', min: 0, max: 1, step: 0.01, value: o.opacity,
        fmt: (v) => Math.round(v * 100) + ' %',
        onInput: (v) => { o.opacity = v; sendOverlay(id); }
    });

    if (meta.palette) {
        const colors = state.palettes[meta.palette] || [];
        if (colors.length) {
            swatches(parent, 'Couleur', colors, Math.min(o.color, colors.length - 1), (i) => {
                o.color = i;
                sendOverlay(id);
            });
        }
    }
}

/* ════════════════════════════════════════════════════════════
   Onglets
   ════════════════════════════════════════════════════════════ */

function ageFrom(y, m, d) {
    const now = new Date();
    let age = now.getFullYear() - y;
    if (now.getMonth() + 1 < m || (now.getMonth() + 1 === m && now.getDate() < d)) age--;
    return age;
}

function daysIn(y, m) { return new Date(y, m, 0).getDate(); }

function cleanName(v) {
    return v
        .replace(/[^A-Za-zÀ-ÖØ-öø-ÿ' -]/g, '')
        .replace(/\s{2,}/g, ' ')
        .replace(/-{2,}/g, '-')
        .replace(/'{2,}/g, "'")
        .slice(0, state.cfg.identity.nameMax);
}

function capitalize(v) {
    return v.trim().toLowerCase().replace(/(^|[\s'-])(\p{L})/gu, (m, a, b) => a + b.toUpperCase());
}

const MONTHS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

function idCard() {
    const wrap = el('div', 'id-card');
    wrap.innerHTML = `
        <img class="id-wm" src="logo.jpg" alt="">
        <div class="id-top"><b></b><span>Carte d'identité</span></div>
        <div class="id-main">
            <div class="id-photo"><svg viewBox="0 0 64 70" fill="currentColor"><circle cx="32" cy="24" r="14"/><path d="M4 70c2-16 14-24 28-24s26 8 28 24z"/></svg></div>
            <div>
                <div class="id-name"></div>
                <div class="id-fields">
                    <div>Né(e) le<b data-k="dob"></b></div>
                    <div>Âge<b data-k="age"></b></div>
                    <div>Sexe<b data-k="sex"></b></div>
                    <div>Taille<b data-k="height"></b></div>
                    <div style="grid-column: span 2">Nationalité<b data-k="nat"></b></div>
                </div>
            </div>
        </div>
        <div class="id-mrz"></div>`;
    wrap.querySelector('.id-top b').textContent = state.cfg.serverName;
    const q = (k) => wrap.querySelector(`[data-k="${k}"]`);
    const nameEl = wrap.querySelector('.id-name');
    const mrzEl = wrap.querySelector('.id-mrz');

    const update = () => {
        const id = state.identity;
        const full = `${id.firstname} ${id.lastname}`.trim();
        nameEl.textContent = full || 'Prénom Nom';
        nameEl.classList.toggle('empty', !full);
        q('dob').textContent = `${String(id.day).padStart(2, '0')}/${String(id.month).padStart(2, '0')}/${id.year}`;
        q('age').textContent = `${ageFrom(id.year, id.month, id.day)} ans`;
        q('sex').textContent = id.sex === 'f' ? 'F' : 'M';
        q('height').textContent = `${(id.height / 100).toFixed(2).replace('.', ',')} m`;
        q('nat').textContent = id.nationality;
        const mrzName = (id.lastname + '<<' + id.firstname)
            .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
            .toUpperCase().replace(/[^A-Z<]/g, '<');
        mrzEl.textContent = ('IDELY' + mrzName + '<'.repeat(40)).slice(0, 40);
    };
    update();
    return { el: wrap, update };
}

const renderers = {
    identity() {
        const id = state.identity;
        const cfg = state.cfg.identity;

        const card = idCard();
        body.append(card.el);
        const refreshCard = card.update;

        const g1 = group('Nom');
        const names = el('div', 'row two');
        g1.append(names);
        [['firstname', 'Prénom'], ['lastname', 'Nom']].forEach(([key, label]) => {
            const { f } = fieldShell(names, label);
            const input = el('input', 'text-input');
            input.placeholder = label;
            input.maxLength = cfg.nameMax;
            input.value = id[key];
            input.addEventListener('input', () => {
                const pos = input.selectionStart;
                const cleaned = cleanName(input.value);
                if (cleaned !== input.value) {
                    input.value = cleaned;
                    input.setSelectionRange(Math.max(0, pos - 1), Math.max(0, pos - 1));
                }
                id[key] = cleaned;
                refreshCard();
            });
            input.addEventListener('blur', () => {
                input.value = capitalize(cleanName(input.value)).replace(/[-' ]+$/, '');
                id[key] = input.value;
                refreshCard();
            });
            f.append(input);
        });

        const g2 = group('Sexe', 'Change le modèle et réinitialise l\'apparence');
        const pick = el('div', 'sex-pick');
        const male = el('button', id.sex === 'm' ? 'active' : '', '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="10" cy="14" r="6"/><path d="M14.5 9.5 20 4M15 4h5v5"/></svg>Homme');
        const female = el('button', id.sex === 'f' ? 'active' : '', '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="9" r="6"/><path d="M12 15v7M9 19h6"/></svg>Femme');
        male.addEventListener('click', () => changeSex('m'));
        female.addEventListener('click', () => changeSex('f'));
        pick.append(male, female);
        g2.append(pick);
        g2.appendChild(el('div', null)).style.height = '10px';

        const g3 = group('Date de naissance');
        const ageNote = g3.querySelector('.group-title');
        const ageTag = txt('small', null, '');
        ageNote.append(ageTag);
        const row = el('div', 'row three');
        g3.append(row);

        const now = new Date().getFullYear();
        const daySel = el('select', 'select');
        const monSel = el('select', 'select');
        const yearSel = el('select', 'select');
        MONTHS.forEach((m, i) => monSel.append(new Option(m, i + 1)));
        for (let y = now - cfg.minAge; y >= now - cfg.maxAge; y--) yearSel.append(new Option(y, y));

        const fillDays = () => {
            const max = daysIn(id.year, id.month);
            if (id.day > max) id.day = max;
            daySel.replaceChildren();
            for (let d = 1; d <= max; d++) daySel.append(new Option(d, d));
            daySel.value = id.day;
        };
        const updateAge = () => {
            const age = ageFrom(id.year, id.month, id.day);
            const okAge = age >= cfg.minAge && age <= cfg.maxAge;
            ageTag.textContent = okAge ? `${age} ans` : `Âge requis : ${cfg.minAge} à ${cfg.maxAge} ans`;
            ageTag.style.color = okAge ? '' : 'var(--danger)';
            refreshCard();
        };
        monSel.value = id.month;
        yearSel.value = id.year;
        fillDays();
        daySel.addEventListener('change', () => { id.day = +daySel.value; updateAge(); });
        monSel.addEventListener('change', () => { id.month = +monSel.value; fillDays(); updateAge(); });
        yearSel.addEventListener('change', () => { id.year = +yearSel.value; fillDays(); updateAge(); });
        row.append(daySel, monSel, yearSel);
        g3.appendChild(el('div', null)).style.height = '14px';
        updateAge();

        const g4 = group('Physique et origines');
        slider(g4, {
            label: 'Taille', min: cfg.heightMin, max: cfg.heightMax, step: 1, value: id.height,
            fmt: (v) => `${(v / 100).toFixed(2).replace('.', ',')} m`,
            onInput: (v) => { id.height = v; refreshCard(); }
        });
        const { f: natField } = fieldShell(g4, 'Nationalité');
        const nat = el('select', 'select');
        state.cfg.nationalities.forEach((n) => nat.append(new Option(n, n)));
        nat.value = id.nationality;
        nat.addEventListener('change', () => { id.nationality = nat.value; refreshCard(); });
        natField.append(nat);
    },

    heritage() {
        const h = state.skin.heritage;
        const g = group('Parents');
        stepper(g, {
            label: 'Mère', value: Math.max(0, MOTHERS.indexOf(h.mom)), min: 0, max: MOTHERS.length - 1,
            names: (p) => PARENTS[MOTHERS[p]],
            onChange: (p) => { h.mom = MOTHERS[p]; sendHeritage(); }
        });
        stepper(g, {
            label: 'Père', value: Math.max(0, FATHERS.indexOf(h.dad)), min: 0, max: FATHERS.length - 1,
            names: (p) => PARENTS[FATHERS[p]],
            onChange: (p) => { h.dad = FATHERS[p]; sendHeritage(); }
        });

        const g2 = group('Mélange');
        slider(g2, {
            label: 'Ressemblance', min: 0, max: 1, step: 0.01, value: h.shapeMix, reset: 0.5,
            left: 'Mère', right: 'Père', fmt: (v) => `${Math.round((1 - v) * 100)} / ${Math.round(v * 100)}`,
            onInput: (v) => { h.shapeMix = v; sendHeritage(); }
        });
        slider(g2, {
            label: 'Couleur de peau', min: 0, max: 1, step: 0.01, value: h.skinMix, reset: 0.5,
            left: 'Mère', right: 'Père', fmt: (v) => `${Math.round((1 - v) * 100)} / ${Math.round(v * 100)}`,
            onInput: (v) => { h.skinMix = v; sendHeritage(); }
        });
    },

    face() {
        FEATURE_GROUPS.forEach((fg) => {
            const g = group(fg.title);
            fg.items.forEach(([i, label, left, right]) => {
                slider(g, {
                    label, min: -1, max: 1, step: 0.01, value: state.skin.faceFeatures[i], reset: 0,
                    centered: true, left, right,
                    fmt: (v) => (v > 0 ? '+' : '') + Math.round(v * 100),
                    onInput: (v) => {
                        state.skin.faceFeatures[i] = v;
                        queue('f' + i, { type: 'feature', index: i, value: v });
                    }
                });
            });
        });
    },

    eyes() {
        const g = group('Couleur des yeux');
        const label = txt('small', null, EYE_COLORS[state.skin.eyeColor][0]);
        g.querySelector('.group-title').append(label);
        const grid = el('div', 'eye-grid');
        const buttons = EYE_COLORS.map(([name, hex], i) => {
            const b = el('button', 'eye' + (i === state.skin.eyeColor ? ' active' : ''));
            b.style.background = `radial-gradient(circle, ${hex} 38%, ${hex}66 100%), #000`;
            b.title = name;
            b.addEventListener('click', () => {
                buttons.forEach((x) => x.classList.remove('active'));
                b.classList.add('active');
                state.skin.eyeColor = i;
                label.textContent = name;
                queue('eye', { type: 'eyeColor', value: i });
            });
            grid.append(b);
            return b;
        });
        g.append(grid);
        g.appendChild(el('div', null)).style.height = '10px';

        overlayControls(group('Sourcils'), 2);
    },

    hair() {
        const hair = state.skin.hair;
        const g = group('Coupe');
        let texStep;
        stepper(g, {
            label: 'Coiffure', value: hair.style, min: 0, max: state.limits.hair.drawables - 1,
            onChange: async (v) => {
                hair.style = v;
                hair.texture = 0;
                const token = nextSeq('hair');
                const res = await post('update', { type: 'hair', ...hair });
                if (token !== seq.hair || res.textures === undefined) return;
                state.limits.hair.textures = res.textures;
                hair.texture = res.texture || 0;
                texStep.setMax(Math.max(0, res.textures - 1));
                texStep.set(hair.texture);
            }
        });
        texStep = stepper(g, {
            label: 'Variante', value: hair.texture, min: 0, max: Math.max(0, state.limits.hair.textures - 1),
            onChange: (v) => { hair.texture = v; post('update', { type: 'hair', ...hair }); }
        });

        const g2 = group('Couleurs');
        swatches(g2, 'Couleur principale', state.palettes.hair, hair.color, (i) => {
            hair.color = i;
            queue('hairColor', { type: 'hairColor', color: hair.color, highlight: hair.highlight });
        });
        swatches(g2, 'Reflets', state.palettes.hair, hair.highlight, (i) => {
            hair.highlight = i;
            queue('hairColor', { type: 'hairColor', color: hair.color, highlight: hair.highlight });
        });

        overlayControls(group('Barbe'), 1);
        overlayControls(group('Pilosité du torse'), 10);
    },

    skin() {
        [0, 3, 6, 7, 9, 11, 12].forEach((id) => overlayControls(group(OVERLAYS[id].name), id));
    },

    makeup() {
        [4, 5, 8].forEach((id) => overlayControls(group(OVERLAYS[id].name), id));
    },

    clothes() {
        const list = outfitsFor();
        const g = group('Tenues disponibles');
        if (!list.length) { g.append(txt('p', 'outfit-empty', 'Aucune tenue configurée (Config.Outfits).')); return; }
        const grid = el('div', 'outfits');
        list.forEach((o, i) => {
            const b = el('button', 'outfit' + (state.outfit === i ? ' active' : ''));
            b.type = 'button';
            b.append(txt('span', 'outfit-num', String(i + 1).padStart(2, '0')));
            b.append(txt('b', null, o.label || `Tenue ${i + 1}`));
            if (o.desc) b.append(txt('small', null, o.desc));
            b.addEventListener('click', () => {
                applyOutfit(i);
                grid.querySelectorAll('.outfit').forEach((x) => x.classList.toggle('active', x === b));
            });
            grid.append(b);
        });
        g.append(grid);
    }
};

/* ════════════════════════════════════════════════════════════
   Tenues préfaites
   ════════════════════════════════════════════════════════════ */

function outfitsFor() {
    const all = (state.cfg && state.cfg.outfits) || {};
    return all[state.skin.sex] || all[String(state.skin.sex)] || [];
}

function applyOutfit(i) {
    const o = outfitsFor()[i];
    if (!o || !o.components) return;
    state.outfit = i;
    const items = [];
    Object.entries(o.components).forEach(([id, v]) => {
        const drawable = Array.isArray(v) ? v[0] : v.drawable;
        const texture = Array.isArray(v) ? v[1] : v.texture;
        state.skin.components[id] = { drawable: drawable | 0, texture: texture | 0 };
        items.push({ type: 'component', id: +id, drawable: drawable | 0, texture: texture | 0 });
    });
    // Pas d'accessoires : tout est retiré
    Object.keys(state.skin.props || {}).forEach((id) => {
        state.skin.props[id] = { drawable: -1, texture: 0 };
        items.push({ type: 'prop', id: +id, drawable: -1, texture: 0 });
    });
    post('batch', { items });
}

/* ════════════════════════════════════════════════════════════
   Aléatoire
   ════════════════════════════════════════════════════════════ */

const rnd = (n) => Math.floor(Math.random() * n);
const pickOf = (arr) => arr[rnd(arr.length)];
const soft = (amp) => +(((Math.random() + Math.random() + Math.random()) / 3 * 2 - 1) * amp).toFixed(2);

function randomOverlay(id, chance, maxOpacity = 1) {
    const o = state.skin.overlays[id];
    const count = state.limits.overlays[id] || 0;
    if (count > 0 && Math.random() < chance) {
        o.style = rnd(count);
        o.opacity = +(0.35 + Math.random() * (maxOpacity - 0.35)).toFixed(2);
    } else {
        o.style = -1;
    }
}

async function randomize() {
    const tab = TABS[state.tab].id;
    const s = state.skin;
    const male = s.sex === 0;
    const naturalHair = Math.min(state.palettes.hair.length, 20);

    if (tab === 'heritage') {
        s.heritage.mom = pickOf(MOTHERS);
        s.heritage.dad = pickOf(FATHERS);
        s.heritage.shapeMix = +(male ? 0.45 + Math.random() * 0.5 : 0.05 + Math.random() * 0.5).toFixed(2);
        s.heritage.skinMix = +Math.random().toFixed(2);
    } else if (tab === 'face') {
        for (let i = 0; i < 20; i++) s.faceFeatures[i] = soft(0.7);
    } else if (tab === 'eyes') {
        s.eyeColor = rnd(9);
        const o = s.overlays[2];
        o.style = rnd(state.limits.overlays[2] || 1);
        o.opacity = +(0.7 + Math.random() * 0.3).toFixed(2);
        o.color = s.hair.color;
    } else if (tab === 'hair') {
        s.hair.style = rnd(state.limits.hair.drawables);
        s.hair.texture = 0;
        s.hair.color = rnd(naturalHair);
        s.hair.highlight = Math.random() < 0.7 ? s.hair.color : rnd(state.palettes.hair.length);
        if (male) {
            randomOverlay(1, 0.7);
            randomOverlay(10, 0.4);
        } else {
            s.overlays[1].style = -1;
            s.overlays[10].style = -1;
        }
        s.overlays[1].color = s.hair.color;
        s.overlays[10].color = s.hair.color;
    } else if (tab === 'skin') {
        randomOverlay(0, 0.3, 0.6);
        randomOverlay(3, 0.3, 0.6);
        randomOverlay(6, 0.4, 0.6);
        randomOverlay(7, 0.2, 0.5);
        randomOverlay(9, 0.4, 0.7);
        randomOverlay(11, 0.15, 0.6);
        randomOverlay(12, 0.1, 0.6);
    } else if (tab === 'makeup') {
        const makeupColors = state.palettes.makeup.length || 1;
        randomOverlay(4, male ? 0.1 : 0.7, 0.9);
        randomOverlay(5, male ? 0 : 0.5, 0.6);
        randomOverlay(8, male ? 0 : 0.7, 0.9);
        s.overlays[5].color = rnd(makeupColors);
        s.overlays[8].color = rnd(makeupColors);
    } else {
        return;
    }

    const res = await post('applySkin', { skin: s });
    if (res.limits) state.limits = res.limits;
    if (tab === 'hair' && state.limits.hair) s.hair.texture = 0;
    render();
}

/* ════════════════════════════════════════════════════════════
   Navigation et rendu
   ════════════════════════════════════════════════════════════ */

function buildRail() {
    const rail = $('#rail');
    rail.replaceChildren();
    TABS.forEach((t, i) => {
        const b = el('button', null, `<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${ICONS[t.id]}</svg>`);
        b.append(txt('span', 'tip', t.title));
        b.setAttribute('aria-label', t.title);
        b.addEventListener('click', () => goTo(i));
        rail.append(b);
    });
}

function render() {
    const t = TABS[state.tab];
    $('#tabTitle').textContent = t.title;
    $('#tabDesc').textContent = t.desc;
    $('#randomBtn').classList.toggle('hidden', !RANDOMIZABLE.has(t.id));
    $('#stepLabel').textContent = `Étape ${state.tab + 1} sur ${TABS.length}`;
    $('#progressBar').style.width = `${((state.tab + 1) / TABS.length) * 100}%`;
    $('#prevBtn').disabled = state.tab === 0;
    $('#nextBtn').textContent = state.tab === TABS.length - 1 ? 'Terminer' : 'Suivant';

    [...$('#rail').children].forEach((b, i) => {
        b.classList.toggle('active', i === state.tab);
        b.classList.toggle('done', state.visited.has(i) && i !== state.tab);
    });

    body.replaceChildren();
    renderers[t.id]();
    body.scrollTop = 0;
}

const TAB_CAMERA = { identity: 'full', heritage: 'face', face: 'face', eyes: 'face', hair: 'face', skin: 'face', makeup: 'face', clothes: 'full', props: 'torso' };

function setCam(preset) {
    document.querySelectorAll('#camButtons button').forEach((b) => b.classList.toggle('active', b.dataset.cam === preset));
    post('camera', { preset });
}

function goTo(i) {
    if (i < 0 || i >= TABS.length || i === state.tab) return;
    flushQueue();
    state.tab = i;
    state.visited.add(i);
    setCam(TAB_CAMERA[TABS[i].id]);
    render();
}

async function changeSex(sex) {
    if (state.identity.sex === sex) return;
    showLoader(true);
    const res = await post('setSex', { sex: sex === 'f' ? 1 : 0 });
    showLoader(false);
    if (!res.skin) return toast('Le changement de modèle a échoué. Réessayez.');
    state.identity.sex = sex;
    state.skin = res.skin;
    state.limits = res.limits;
    state.outfit = 0; // le serveur a déjà appliqué la 1re tenue du nouveau sexe
    if (sex === 'f' && state.identity.height > 175) state.identity.height = 165;
    if (sex === 'm' && state.identity.height < 165) state.identity.height = 178;
    setCam(TAB_CAMERA[TABS[state.tab].id]);
    render();
}

/* ════════════════════════════════════════════════════════════
   Validation et sauvegarde
   ════════════════════════════════════════════════════════════ */

function validateIdentity() {
    const id = state.identity;
    const cfg = state.cfg.identity;
    id.firstname = capitalize(cleanName(id.firstname)).replace(/[-' ]+$/, '');
    id.lastname = capitalize(cleanName(id.lastname)).replace(/[-' ]+$/, '');
    if (id.firstname.length < cfg.nameMin) return 'Indiquez un prénom d\'au moins ' + cfg.nameMin + ' lettres.';
    if (id.lastname.length < cfg.nameMin) return 'Indiquez un nom d\'au moins ' + cfg.nameMin + ' lettres.';
    const age = ageFrom(id.year, id.month, id.day);
    if (age < cfg.minAge || age > cfg.maxAge) return `L'âge doit être compris entre ${cfg.minAge} et ${cfg.maxAge} ans.`;
    return null;
}

function finish() {
    flushQueue();
    const err = validateIdentity();
    if (err) {
        toast(err);
        if (state.tab !== 0) goTo(0); else render();
        return;
    }
    $('#modalCard').replaceChildren(idCard().el);
    $('#modal').classList.remove('hidden');
}

async function confirmSave() {
    const btn = $('#modalConfirm');
    btn.disabled = true;
    showLoader(true);
    const id = state.identity;
    const res = await post('save', {
        identity: {
            firstname: id.firstname,
            lastname: id.lastname,
            dob: `${id.year}-${String(id.month).padStart(2, '0')}-${String(id.day).padStart(2, '0')}`,
            sex: id.sex,
            height: id.height,
            nationality: id.nationality
        },
        skin: state.skin
    });
    btn.disabled = false;
    if (res.ok) {
        $('#modal').classList.add('hidden');
        return; // le client Lua ferme l'interface
    }
    showLoader(false);
    toast(res.msg || 'L\'enregistrement a échoué. Réessayez.');
}

/* ════════════════════════════════════════════════════════════
   Divers
   ════════════════════════════════════════════════════════════ */

function showLoader(on) { $('#loader').classList.toggle('hidden', !on); }

function toast(msg, ok = false) {
    const t = txt('div', 'toast' + (ok ? ' ok' : ''), msg);
    $('#toasts').append(t);
    setTimeout(() => t.remove(), 4500);
}

const sendRotate = throttle((angle) => post('rotate', { angle }), 30);
function setAngle(a) {
    a = ((a + 180) % 360 + 360) % 360 - 180;
    state.angle = a;
    const r = $('#rotateRange');
    r.value = Math.round(a);
    r.style.setProperty('--p', ((a + 180) / 360) * 100 + '%');
    sendRotate(a);
}

function bindStatic() {
    $('#prevBtn').addEventListener('click', () => goTo(state.tab - 1));
    $('#nextBtn').addEventListener('click', () => (state.tab === TABS.length - 1 ? finish() : goTo(state.tab + 1)));
    $('#randomBtn').addEventListener('click', randomize);
    $('#modalCancel').addEventListener('click', () => $('#modal').classList.add('hidden'));
    $('#modalConfirm').addEventListener('click', confirmSave);

    document.querySelectorAll('#camButtons button').forEach((b) => b.addEventListener('click', () => setCam(b.dataset.cam)));
    $('#rotateRange').addEventListener('input', (e) => setAngle(+e.target.value));

    const stage = $('#stage');
    let dragging = false, lastX = 0;
    stage.addEventListener('mousedown', (e) => { dragging = true; lastX = e.clientX; stage.classList.add('dragging'); });
    window.addEventListener('mouseup', () => { dragging = false; stage.classList.remove('dragging'); });
    window.addEventListener('mousemove', (e) => {
        if (!dragging) return;
        const dx = e.clientX - lastX;
        lastX = e.clientX;
        setAngle(state.angle + dx * 0.45);
    });
    const sendZoom = throttle((delta) => post('zoom', { delta }), 40);
    stage.addEventListener('wheel', (e) => sendZoom(e.deltaY), { passive: true });

    document.addEventListener('keydown', (e) => {
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT') return;
        if (!$('#modal').classList.contains('hidden')) {
            if (e.key === 'Escape') $('#modal').classList.add('hidden');
            return;
        }
        if (e.key === 'a' || e.key === 'q') setAngle(state.angle - 10);
        if (e.key === 'e' || e.key === 'd') setAngle(state.angle + 10);
    });
}

/* ════════════════════════════════════════════════════════════
   Ouverture / fermeture
   ════════════════════════════════════════════════════════════ */

function open(d) {
    state.skin = d.skin;
    state.limits = d.limits;
    state.palettes = d.palettes || { hair: [], makeup: [] };
    state.cfg = d.config;
    state.tab = 0;
    state.outfit = 0;
    state.visited = new Set([0]);
    state.angle = 0;

    const year = new Date().getFullYear() - 25;
    state.identity = {
        firstname: '', lastname: '', sex: 'm',
        day: 1, month: 1, year,
        height: 178,
        nationality: state.cfg.nationalities[0]
    };

    $('#brandName').textContent = state.cfg.serverName;
    $('#modal').classList.add('hidden');
    showLoader(false);
    setAngle(0);
    buildRail();
    render();
    $('#app').classList.remove('hidden');
}

function close() {
    $('#app').classList.add('hidden');
    $('#modal').classList.add('hidden');
    showLoader(false);
    body.replaceChildren();
}

/* ════════════════════════════════════════════════════════════
   Sélection des personnages (Qbox)
   ════════════════════════════════════════════════════════════ */

let selectedChar = null;

function openSelect(d) {
    const list = $('#selectList');
    list.replaceChildren();
    $('#selectBrand').textContent = d.serverName || 'Elyzea';
    $('#selectCount').textContent = `${d.characters.length} / ${d.max} personnage${d.max > 1 ? 's' : ''}`;
    selectedChar = d.characters[0] ? d.characters[0].citizenid : null;

    d.characters.forEach((c) => {
        const card = el('button', 'char-card' + (c.citizenid === selectedChar ? ' active' : ''));
        const av = txt('div', 'avatar', ((c.firstname || '?')[0] + (c.lastname || '?')[0]).toUpperCase());
        const info = el('div');
        info.append(txt('div', 'n', `${c.firstname} ${c.lastname}`));
        let dob = c.birthdate || '';
        const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(dob);
        if (m) dob = `${m[3]}/${m[2]}/${m[1]}`;
        const born = c.sex === 'f' ? 'née' : 'né';
        const parts = [c.sex === 'f' ? 'Femme' : 'Homme', dob && `${born} le ${dob}`, c.nationality].filter(Boolean);
        info.append(txt('div', 'm', parts.join(' · ')));
        card.append(av, info);
        card.addEventListener('click', () => {
            if (selectedChar === c.citizenid) return;
            selectedChar = c.citizenid;
            list.querySelectorAll('.char-card').forEach((x) => x.classList.remove('active'));
            card.classList.add('active');
            post('previewChar', { citizenid: c.citizenid });
        });
        card.addEventListener('dblclick', () => post('playChar', { citizenid: c.citizenid }));
        list.append(card);
    });

    for (let i = d.characters.length; i < d.max; i++) {
        list.append(txt('div', 'empty-slot', 'Emplacement libre'));
    }

    $('#newCharBtn').classList.toggle('hidden', !d.canCreate);
    $('#playBtn').disabled = !selectedChar;
    $('#select').classList.remove('hidden');
}

$('#playBtn').addEventListener('click', () => {
    if (!selectedChar) return;
    $('#playBtn').disabled = true;
    post('playChar', { citizenid: selectedChar });
});
$('#newCharBtn').addEventListener('click', () => post('newChar'));

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') open(d);
    else if (d.action === 'select') openSelect(d);
    else if (d.action === 'closeSelect') $('#select').classList.add('hidden');
    else if (d.action === 'close') close();
    else if (d.action === 'notify') toast(d.msg, d.ok);
});

bindStatic();

/* ════════════════════════════════════════════════════════════
   Aperçu navigateur (hors jeu) : ouvrez html/index.html directement
   ════════════════════════════════════════════════════════════ */

function mockResponse(name, data) {
    if (name === 'update') return { textures: 4, texture: 0 };
    if (name === 'save') return { ok: false, msg: 'Aperçu hors jeu : rien n\'est enregistré.' };
    if (name === 'setSex') return { skin: mockSkin(data.sex), limits: mockLimits() };
    if (name === 'applySkin') return { limits: mockLimits() };
    return {};
}

function mockSkin(sex = 0) {
    const overlays = {}, components = {}, props = {};
    for (let i = 0; i <= 12; i++) overlays[i] = { style: i === 2 ? 0 : -1, opacity: 1, color: 0 };
    COMPONENTS.forEach(([id]) => { components[id] = { drawable: 0, texture: 0 }; });
    PROPS.forEach(([id]) => { props[id] = { drawable: -1, texture: 0 }; });
    return {
        sex, heritage: { mom: 21, dad: 0, shapeMix: sex ? 0.2 : 0.8, skinMix: 0.5 },
        faceFeatures: Array(20).fill(0), eyeColor: 0, overlays,
        hair: { style: 0, texture: 0, color: 0, highlight: 0 }, components, props
    };
}

function mockLimits() {
    const overlays = {}, components = {}, props = {};
    [24, 29, 34, 15, 75, 7, 12, 11, 10, 18, 17, 12, 1].forEach((n, i) => { overlays[i] = n; });
    COMPONENTS.forEach(([id]) => { components[id] = { drawables: 200, textures: 6 }; });
    PROPS.forEach(([id]) => { props[id] = { drawables: 60, textures: 0 }; });
    return { hair: { drawables: 80, textures: 4 }, overlays, components, props };
}

if (!IN_GAME) {
    const gradient = (a, b, n) => Array.from({ length: n }, (_, i) => a.map((v, k) => Math.round(v + (b[k] - v) * (i / (n - 1)))));
    document.body.style.background = 'linear-gradient(120deg, #2a2f3a, #565b68)';
    open({
        skin: mockSkin(0),
        limits: mockLimits(),
        palettes: { hair: gradient([20, 16, 14], [235, 210, 160], 64), makeup: gradient([120, 20, 40], [250, 180, 200], 64) },
        config: {
            serverName: 'Elyzea',
            identity: { nameMin: 2, nameMax: 16, minAge: 18, maxAge: 90, heightMin: 150, heightMax: 210 },
            nationalities: ['Française', 'Belge', 'Suisse', 'Canadienne', 'Autre']
        }
    });
}
