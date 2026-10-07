/* =========================================================
   VÉHICULES › PERSONNALISATION
   Comme en concession / chez LsCustom, mais gratuit et en direct
   sur le véhicule que le staff conduit.
   ========================================================= */
(() => {
    const VC = { sub: 'spawn', info: null, cat: null, opts: null, wheelType: null, version: 0, picker: null, loading: false };
    const GROUPS = [
        { id: 'perf', label: 'Performance' }, { id: 'body', label: 'Carrosserie' }, { id: 'wheels', label: 'Roues' },
        { id: 'paint', label: 'Peinture et vitres' }, { id: 'lights', label: 'Lumières' }, { id: 'interior', label: 'Intérieur' },
    ];
    const CUSTOM = { paint1: 'paint', paint2: 'paint', neon: 'light', smoke: 'light' };
    const FINISHES = [{ id: 0, label: 'Normal' }, { id: 1, label: 'Métallisé' }, { id: 2, label: 'Nacré' }, { id: 3, label: 'Mat' }, { id: 4, label: 'Métal' }, { id: 5, label: 'Chrome' }];
    const bump = () => { VC.version += 1; render(); };

    // Le rafraîchissement automatique du menu ne reconstruit pas cet écran pour rien
    const prevSig = STABLE_VIEWS.vehicles;
    STABLE_VIEWS.vehicles = () => (VC.sub === 'custom' ? `vc|${VC.version}|${has('vehicle_custom')}` : (prevSig ? prevSig() : null));

    const baseView = VIEWS.vehicles;
    VIEWS.vehicles = () => {
        if (!has('vehicle_custom')) return baseView();
        const nav = `<div class="segmented">
            <button class="seg ${VC.sub === 'spawn' ? 'active' : ''}" data-vcs="spawn">Apparition et outils</button>
            <button class="seg ${VC.sub === 'custom' ? 'active' : ''}" data-vcs="custom">Personnalisation</button></div>`;
        return nav + (VC.sub === 'spawn' ? baseView() : customView());
    };

    async function loadInfo() {
        VC.loading = true;
        VC.info = await post('vc_info');
        VC.loading = false;
        if (VC.info && VC.info.inVehicle && VC.cat && !VC.info.cats.some((c) => c.key === VC.cat)) { VC.cat = null; VC.opts = null; }
        bump();
    }

    async function loadOptions(key, wheelType) {
        VC.cat = key;
        const r = await post('vc_options', { key, wheelType });
        VC.opts = r || { options: [] };
        if (r && r.wheelType !== undefined && r.wheelType !== null) VC.wheelType = r.wheelType;
        if (CUSTOM[key]) initPicker(key, VC.opts.current);
        bump();
    }

    /* ---------- Couleur libre ---------- */
    const hsvToRgb = (h, s, v) => { const f = (n) => { const k = (n + h / 60) % 6; return v - v * s * Math.max(0, Math.min(k, 4 - k, 1)); }; return [f(5), f(3), f(1)].map((x) => Math.round(x * 255)); };
    const rgbToHsv = (r, g, b) => { r /= 255; g /= 255; b /= 255; const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn; let h = 0;
        if (d) h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4; return { h: (h * 60 + 360) % 360, s: mx ? d / mx : 0, v: mx }; };
    const toHex = (c) => `#${c.map((x) => x.toString(16).padStart(2, '0')).join('')}`;
    const parseRgb = (v) => { const m = /^rgb:(\d+),(\d+),(\d+):?(\d*)$/.exec(String(v || '')); return m ? { rgb: [+m[1], +m[2], +m[3]], finish: m[4] === '' ? null : +m[4] } : null; };
    function initPicker(key, value) {
        const p = parseRgb(value);
        VC.picker = { key, ...rgbToHsv(...(p ? p.rgb : [217, 181, 106])), finish: p && p.finish !== null ? p.finish : 1 };
    }
    const pickerValue = () => { const p = VC.picker; const [r, g, b] = hsvToRgb(p.h, p.s, p.v); return CUSTOM[p.key] === 'paint' ? `rgb:${r},${g},${b}:${p.finish}` : `rgb:${r},${g},${b}`; };

    function pickerHTML() {
        const p = VC.picker;
        const hex = toHex(hsvToRgb(p.h, p.s, p.v));
        return `<div class="card" style="padding:14px;margin-bottom:12px">
            <div class="inline" style="margin-bottom:10px;align-items:center"><strong style="flex:1">Couleur libre</strong>
                <span id="vcSwatch" style="width:30px;height:30px;border-radius:50%;background:${hex};border:2px solid var(--signal)"></span>
                <span class="keycap" id="vcHex">${hex.toUpperCase()}</span></div>
            <div id="vcSV" style="position:relative;height:130px;border-radius:8px;cursor:crosshair;background-color:hsl(${Math.round(p.h)},100%,50%);
                background-image:linear-gradient(to top,#000,transparent),linear-gradient(to right,#fff,transparent)">
                <span id="vcDot" style="position:absolute;left:${p.s * 100}%;top:${(1 - p.v) * 100}%;width:14px;height:14px;margin:-7px 0 0 -7px;border-radius:50%;border:2px solid #fff;box-shadow:0 0 0 1px #000;pointer-events:none"></span></div>
            <div id="vcHue" style="position:relative;height:14px;margin-top:10px;border-radius:7px;cursor:pointer;background:linear-gradient(to right,#f00,#ff0,#0f0,#0ff,#00f,#f0f,#f00)">
                <span id="vcHDot" style="position:absolute;top:50%;left:${(p.h / 360) * 100}%;width:16px;height:16px;margin:-8px 0 0 -8px;border-radius:50%;background:#fff;border:2px solid var(--signal);pointer-events:none"></span></div>
            ${CUSTOM[p.key] === 'paint' ? `<div class="chips" style="margin-top:10px">${FINISHES.map((f) => `<button class="chip ${p.finish === f.id ? 'on' : ''}" data-vcfin="${f.id}">${f.label}</button>`).join('')}</div>` : ''}
        </div>`;
    }
    function refreshPicker() {
        const p = VC.picker; if (!p) return;
        const hex = toHex(hsvToRgb(p.h, p.s, p.v));
        const set = (id, fn) => { const el = document.getElementById(id); if (el) fn(el); };
        set('vcSwatch', (e) => { e.style.background = hex; }); set('vcHex', (e) => { e.textContent = hex.toUpperCase(); });
        set('vcSV', (e) => { e.style.backgroundColor = `hsl(${Math.round(p.h)},100%,50%)`; });
        set('vcDot', (e) => { e.style.left = `${p.s * 100}%`; e.style.top = `${(1 - p.v) * 100}%`; });
        set('vcHDot', (e) => { e.style.left = `${(p.h / 360) * 100}%`; });
    }
    let sendTimer = null;
    function applyPicker(final) {
        const value = pickerValue();
        clearTimeout(sendTimer);
        const send = () => post('vc_apply', { key: VC.cat, value }).then((r) => { if (VC.opts && r) VC.opts.current = r.current; if (final) bump(); });
        if (final) send(); else sendTimer = setTimeout(send, 70);
    }

    /* ---------- Écran ---------- */
    function customView() {
        if (!VC.info && !VC.loading) { VC.loading = true; setTimeout(loadInfo, 0); }
        if (!VC.info) return '<div class="empty">Lecture du véhicule…</div>';
        const i = VC.info;
        if (!i.inVehicle) {
            return `<div class="empty" style="padding:40px">🚗 Monte au volant du véhicule à personnaliser, puis
                <button class="btn primary" data-vca="reload" style="margin-left:8px">Actualiser</button></div>`;
        }
        const cats = i.cats;
        const o = VC.opts;
        const cur = o ? String(o.current) : null;
        const catLabel = VC.cat ? (cats.find((c) => c.key === VC.cat) || {}).label : '';
        return `
            <div class="duty-bar" style="margin-bottom:14px"><span>🚗 <b>${esc(i.label)}</b> <span class="keycap">${esc(i.plate)}</span>
                · gratuit, appliqué tout de suite sur ton véhicule</span>
                <span class="btn-row" style="margin:0">
                    <button class="btn" data-vca="max">⚡ Performances max</button>
                    <button class="btn" data-vtool="repair">🔧 Réparer</button>
                    ${i.canRevert ? '<button class="btn" data-vca="revert">↺ Annuler mes changements</button>' : ''}
                    ${i.canSave ? '<button class="btn primary" data-vca="save">💾 Enregistrer sur le véhicule</button>' : ''}
                    <button class="btn" data-vca="reload" title="Après avoir changé de véhicule">↻</button>
                </span></div>
            <div style="display:grid;grid-template-columns:230px 1fr;gap:16px;align-items:start">
                <div class="card" style="padding:8px;max-height:calc(100vh - 330px);overflow-y:auto">
                    ${GROUPS.map((g) => {
                        const list = cats.filter((c) => c.group === g.id);
                        if (!list.length) return '';
                        return `<div class="tab-group" style="padding:10px 8px 4px">${g.label}</div>${list.map((c) => `<button class="tab ${VC.cat === c.key ? 'active' : ''}" data-vccat="${c.key}" style="width:100%">${esc(c.label)}</button>`).join('')}`;
                    }).join('')}
                </div>
                <div>
                    ${!VC.cat ? '<div class="empty">Choisis une catégorie à gauche. Chaque choix s\'applique immédiatement.</div>' : `
                    <h2 style="margin-bottom:10px">${esc(catLabel)}</h2>
                    ${VC.cat === 'wheels' ? `<div class="chips" style="margin-bottom:10px">${i.wheelTypes.map((w) => `<button class="chip ${Number(VC.wheelType) === w.id ? 'on' : ''}" data-vcwt="${w.id}">${esc(w.label)}</button>`).join('')}</div>` : ''}
                    ${CUSTOM[VC.cat] && VC.picker ? pickerHTML() : ''}
                    ${o && o.options.length ? `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(150px,1fr))">${o.options.map((x) => `
                        <button class="tile ${String(x.value) === cur ? 'active' : ''}" data-vcval="${esc(x.value)}"><strong>${esc(x.label)}</strong>${String(x.value) === cur ? '<span>Actuel</span>' : ''}</button>`).join('')}</div>`
                        : '<div class="empty">Rien de disponible pour ce véhicule.</div>'}`}
                </div>
            </div>`;
    }

    /* ---------- Événements ---------- */
    let drag = null;
    function pickAt(e) {
        const el = document.getElementById(drag === 'sv' ? 'vcSV' : 'vcHue');
        if (!el || !VC.picker) return;
        const r = el.getBoundingClientRect();
        const x = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width));
        const y = Math.max(0, Math.min(1, (e.clientY - r.top) / r.height));
        if (drag === 'sv') { VC.picker.s = x; VC.picker.v = 1 - y; } else { VC.picker.h = x * 360; }
        refreshPicker();
        applyPicker(false);
    }
    document.addEventListener('mousedown', (e) => {
        if (!isOpen || tab !== 'vehicles' || VC.sub !== 'custom' || e.button !== 0) return;
        if (e.target.closest('#vcSV')) drag = 'sv'; else if (e.target.closest('#vcHue')) drag = 'hue'; else return;
        e.preventDefault();
        pickAt(e);
    });
    document.addEventListener('mousemove', (e) => { if (drag) pickAt(e); });
    document.addEventListener('mouseup', () => { if (drag) { drag = null; applyPicker(true); } });

    document.addEventListener('click', async (e) => {
        if (!isOpen || tab !== 'vehicles') return;
        let n;
        if ((n = e.target.closest('[data-vcs]'))) {
            VC.sub = n.dataset.vcs;
            if (VC.sub === 'custom') { VC.info = null; }
            return bump();
        }
        if (VC.sub !== 'custom') return;
        if ((n = e.target.closest('[data-vccat]'))) { VC.wheelType = null; return loadOptions(n.dataset.vccat); }
        if ((n = e.target.closest('[data-vcwt]'))) return loadOptions('wheels', Number(n.dataset.vcwt));
        if ((n = e.target.closest('[data-vcfin]'))) { VC.picker.finish = Number(n.dataset.vcfin); return applyPicker(true); }
        if ((n = e.target.closest('[data-vcval]'))) {
            const raw = n.dataset.vcval;
            const value = /^-?\d+$/.test(raw) ? Number(raw) : raw;
            const r = await post('vc_apply', { key: VC.cat, value });
            if (VC.opts && r) VC.opts.current = r.current;
            if (CUSTOM[VC.cat]) initPicker(VC.cat, VC.opts.current);
            return bump();
        }
        if ((n = e.target.closest('[data-vca]'))) {
            const a = n.dataset.vca;
            if (a === 'reload') { VC.info = null; VC.cat = null; VC.opts = null; return loadInfo(); }
            if (a === 'max') { await post('vc_max'); toast('Performances au maximum.', 'success'); if (VC.cat) return loadOptions(VC.cat, VC.wheelType); return; }
            if (a === 'revert') {
                if (!(await confirmBox('Annuler tes changements ?', 'Le véhicule revient exactement comme à l\'ouverture de cet onglet (ou au dernier enregistrement).'))) return;
                await post('vc_revert'); toast('Changements annulés.', 'success');
                if (VC.cat) return loadOptions(VC.cat, VC.wheelType);
                return;
            }
            if (a === 'save') { await post('vc_save'); return; }
        }
    });
})();
