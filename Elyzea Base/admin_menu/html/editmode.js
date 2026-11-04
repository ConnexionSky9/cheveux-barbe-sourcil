/* =========================================================
   ÉDITEUR DE MAP - MODE ÉDITION (interface)
   Tous les props du jeu (allprops.txt) + catalogue classé, recherche, aperçu au survol
   (image + objet 3D devant la caméra), objet en main avec rotation X / Y / Z,
   sélection d'un prop posé (déplacer, dupliquer, supprimer).
   ========================================================= */
(() => {
    const EM = { all: null, cat: 'all', q: '', st: {}, folders: [], hover: null, timer: 0 };
    const MAX = 300;
    const root = document.createElement('div');
    root.id = 'emode';
    root.className = 'hidden';
    document.body.appendChild(root);
    const em = (a, extra = {}) => post('emode', { a, ...extra });
    const groups = () => (window.CATALOG && CATALOG.props) || [];
    const imgTpl = () => (window.CATALOG && CATALOG.propImage) || '';

    function loadAll() {
        if (EM.all) return Promise.resolve(EM.all);
        return fetch('allprops.txt').then((r) => r.text()).then((t) => {
            EM.all = t.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
            return EM.all;
        }).catch(() => { EM.all = []; return EM.all; });
    }
    function items() {
        const q = EM.q.trim().toLowerCase();
        let src;
        if (EM.cat === 'all') src = EM.all || [];
        else if (EM.cat === 'cat') src = groups().flatMap((g) => g.items);
        else src = (groups()[Number(EM.cat)] || { items: [] }).items;
        if (!q) return src;
        const words = q.split(/\s+/);
        return src.filter((n) => words.every((w) => n.includes(w)));
    }
    function drawList() {
        const el = root.querySelector('#em-list');
        if (!el) return;
        const list = items();
        const shown = list.slice(0, MAX);
        el.innerHTML = shown.map((n) => `<button class="em-item ${EM.st.model === n && !EM.st.moving ? 'on' : ''}" data-em-pick="${esc(n)}">${esc(n)}</button>`).join('')
            + (list.length > shown.length ? `<p class="em-more">${(list.length - shown.length).toLocaleString('fr-FR')} autres : précise ta recherche.</p>` : '')
            + (!list.length ? `<p class="em-more">${EM.all ? 'Aucun prop ne correspond.' : 'Chargement de la liste…'}</p>` : '');
        const c = root.querySelector('#em-n');
        if (c) c.textContent = list.length.toLocaleString('fr-FR');
    }
    function previewHTML(name) {
        if (!name) return '<div class="em-pv-empty">Survole un prop pour voir son aperçu.<br><small>Clique pour le prendre en main.</small></div>';
        const remote = imgTpl() ? imgTpl().replace('{name}', name) : '';
        return `<img src="props/${esc(name)}.webp" alt="" data-remote="${esc(remote)}"
                onerror="if(this.dataset.remote&&this.src!==this.dataset.remote){this.src=this.dataset.remote}else{this.style.display='none';this.nextElementSibling.style.display='flex'}">
            <div class="em-pv-none" style="display:none">📦<small>Pas d'image : regarde l'aperçu 3D devant la caméra</small></div>
            <b>${esc(name)}</b>`;
    }
    const fmt = (v) => Math.round(Number(v) || 0);
    function barHTML() {
        const st = EM.st;
        if (st.model) {
            return `<div class="em-bar">
                <span>${st.moving ? '✥ Déplacement' : '✋ En main'} : <b>${esc(st.model)}</b></span>
                <label>X <input type="range" min="-180" max="180" step="1" value="${fmt(st.rx)}" data-em-rot="rx"><em>${fmt(st.rx)}°</em></label>
                <label>Y <input type="range" min="-180" max="180" step="1" value="${fmt(st.ry)}" data-em-rot="ry"><em>${fmt(st.ry)}°</em></label>
                <label>Z <input type="range" min="0" max="359" step="1" value="${fmt(st.rz)}" data-em-rot="rz"><em>${fmt(st.rz)}°</em></label>
                <button data-em="rotReset" title="Remettre droit (R)">⟲ Droit</button>
                <button data-em="drop">Lâcher</button>
                <span class="em-hint">Clic dans le monde pour poser</span></div>`;
        }
        if (st.sel) {
            return `<div class="em-bar"><span>Sélection : <b>${esc(st.sel.model || st.sel.kind)}</b>${st.sel.id ? ` <small>#${st.sel.id}</small>` : ''}</span>
                ${st.sel.kind === 'prop' ? '<button data-em="move">✥ Déplacer / tourner</button><button data-em="dup">⧉ Dupliquer</button>' : ''}
                <button class="danger" data-em="delete">🗑 Supprimer</button></div>`;
        }
        return '';
    }
    function drawBar() { const b = root.querySelector('#em-barwrap'); if (b) b.innerHTML = barHTML(); }

    function render() {
        const st = EM.st, g = groups();
        root.innerHTML = `<div class="em-view" id="em-view"></div>
        <aside class="em-panel">
            <div class="em-head"><div><small>Éditeur de map</small><b>Mode édition</b></div><button class="em-x" data-em="close" title="Quitter (Échap)">✕</button></div>
            <label class="em-switch ${st.snap ? 'on' : ''}" data-em="snap"><span><b>Coller aux surfaces</b><small>${st.snap ? 'Le prop se pose sur ce que vise la souris' : 'Le prop flotte (Pg.Préc / Pg.Suiv : distance)'}</small></span><i></i></label>
            <select class="em-folder" id="em-folder"><option value="0">Ranger : sans dossier</option>${EM.folders.map((f) => `<option value="${f.id}" ${Number(st.folder) === f.id ? 'selected' : ''}>Ranger dans 📁 ${esc(f.name)}</option>`).join('')}</select>
            <input class="em-search" id="em-q" placeholder="Rechercher parmi tous les props…" value="${esc(EM.q)}">
            <div class="em-cats">
                <button class="${EM.cat === 'all' ? 'on' : ''}" data-em-cat="all">🌐 Tous les props du jeu</button>
                <button class="${EM.cat === 'cat' ? 'on' : ''}" data-em-cat="cat">📚 Catalogue classé</button>
                ${g.map((x, i) => `<button class="${EM.cat === String(i) ? 'on' : ''}" data-em-cat="${i}">${x.icon || ''} ${esc(x.cat)}</button>`).join('')}
            </div>
            <div class="em-count"><span id="em-n">0</span> props${st.count ? ` · ${st.count} posé(s) pendant ce mode` : ''}</div>
            <div class="em-list" id="em-list"></div>
            <div class="em-pv" id="em-pv">${previewHTML(EM.hover)}</div>
            <div class="em-keys"><span><kbd>Z Q S D</kbd> voler</span><span><kbd>Espace</kbd><kbd>Ctrl</kbd> monter / descendre</span><span><kbd>Maj</kbd> vite / rotation fine</span>
              <span><kbd>Clic droit</kbd> regarder</span><span><kbd>Molette</kbd> tourner (Z)</span><span><kbd>↑ ↓</kbd> pencher (X)</span><span><kbd>← →</kbd> incliner (Y)</span>
              <span><kbd>R</kbd> remettre droit</span><span><kbd>G</kbd> coller</span><span><kbd>Suppr</kbd> supprimer</span><span><kbd>Échap</kbd> lâcher / quitter</span></div>
        </aside>
        <div id="em-barwrap">${barHTML()}</div>`;
        drawList();
    }

    root.addEventListener('mouseover', (e) => {
        const it = e.target.closest('[data-em-pick]');
        if (!it) return;
        const m = it.dataset.emPick;
        if (m === EM.hover) return;
        EM.hover = m;
        const pv = root.querySelector('#em-pv');
        if (pv) pv.innerHTML = previewHTML(m);
        clearTimeout(EM.timer);
        EM.timer = setTimeout(() => { if (EM.hover === m) em('preview', { model: m }); }, 140);
    });
    root.addEventListener('mouseout', (e) => {
        if (e.target.closest && e.target.closest('#em-list') && !(e.relatedTarget && e.relatedTarget.closest && e.relatedTarget.closest('#em-list'))) {
            EM.hover = null; clearTimeout(EM.timer); em('preview', {});
        }
    });
    root.addEventListener('contextmenu', (e) => e.preventDefault());
    root.addEventListener('click', (e) => {
        let b;
        if (e.target.id === 'em-view') return em('click');
        if ((b = e.target.closest('[data-em-pick]'))) { EM.hover = null; clearTimeout(EM.timer); return em('pick', { model: b.dataset.emPick }); }
        if ((b = e.target.closest('[data-em-cat]'))) { EM.cat = b.dataset.emCat; render(); const l = root.querySelector('#em-list'); if (l) l.scrollTop = 0; return; }
        if (!(b = e.target.closest('[data-em]'))) return;
        const a = b.dataset.em;
        if (a === 'snap') return em('snap', { on: !EM.st.snap });
        em(a);
    });
    root.addEventListener('input', (e) => {
        const t = e.target;
        if (t.id === 'em-q') { EM.q = t.value; drawList(); return; }
        if (t.dataset.emRot) {
            EM.st[t.dataset.emRot] = Number(t.value);
            const lab = t.nextElementSibling; if (lab) lab.textContent = `${t.value}°`;
            em('rot', { rx: EM.st.rx, ry: EM.st.ry, rz: EM.st.rz });
        }
    });
    root.addEventListener('change', (e) => { if (e.target.id === 'em-folder') em('folder', { id: Number(e.target.value) || 0 }); });
    root.addEventListener('focusin', (e) => { if (e.target.id === 'em-q') em('typing', { on: true }); });
    root.addEventListener('focusout', (e) => { if (e.target.id === 'em-q') em('typing', { on: false }); });
    document.addEventListener('keydown', (e) => {
        if (root.classList.contains('hidden')) return;
        if (e.key === 'Escape') {
            e.stopImmediatePropagation(); e.preventDefault();
            if (e.target.id === 'em-q') { e.target.blur(); return; }
            em(EM.st.model ? 'drop' : 'close');
        }
    }, true);

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action !== 'emode') return;
        if (m.show === true) {
            EM.folders = m.folders || []; EM.st = { snap: true, folder: m.folder }; EM.hover = null;
            root.classList.remove('hidden'); render();
            loadAll().then(drawList);
            return;
        }
        if (m.show === false) { root.classList.add('hidden'); root.innerHTML = ''; return; }
        if (m.state) {
            const prev = EM.st;
            EM.st = m;
            // Pendant qu'on tourne l'objet, seule la barre change (la liste et la recherche restent en place)
            if (prev.model === m.model && prev.snap === m.snap && !!prev.sel === !!m.sel && prev.count === m.count && root.querySelector('#em-list')) {
                const dragging = document.activeElement && document.activeElement.dataset && document.activeElement.dataset.emRot;
                if (!dragging) drawBar();
                return;
            }
            const keepQ = document.activeElement && document.activeElement.id === 'em-q';
            const sc = (root.querySelector('#em-list') || {}).scrollTop || 0;
            render();
            const l = root.querySelector('#em-list'); if (l) l.scrollTop = sc;
            if (keepQ) { const i = root.querySelector('#em-q'); i.focus(); i.setSelectionRange(i.value.length, i.value.length); }
        }
    });
})();
