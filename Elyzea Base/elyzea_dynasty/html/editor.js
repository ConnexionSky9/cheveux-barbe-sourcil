/* =====================================================================
   ELYZEA DYNASTY 8 - interface du MODE ÉDITEUR de décoration
   Panneau des objets (recherche, catégories), aperçu au survol, objet en main,
   sélection d'un objet posé (déplacer, tourner, retirer), « coller au sol ».
   ===================================================================== */
(() => {
  const HE = { data: null, cat: '', q: '', st: {} };
  const root = document.createElement('div');
  root.id = 'hedit';
  root.className = 'hidden';
  document.body.appendChild(root);
  const he = (a, extra = {}) => post('he', { a, ...extra });

  function items() {
    const q = HE.q.trim().toLowerCase();
    return (HE.data.catalog || []).filter((x) => (!HE.cat || x.cat === HE.cat) && (!q || `${x.label} ${x.model} ${x.cat}`.toLowerCase().includes(q)));
  }
  function drawList() {
    const el = $('#he-list', root);
    if (!el) return;
    const st = HE.st;
    el.innerHTML = items().map((x) => `<button class="he-item ${st.model === x.model && !st.moving ? 'on' : ''}" data-he-pick="${esc(x.model)}">
        <span class="he-item__ico">${ICO[x.cat] || '📦'}</span><span class="he-item__tx"><b>${esc(x.label)}</b><small>${esc(x.cat)}</small></span></button>`).join('')
      || '<p class="he-empty">Aucun objet ne correspond.</p>';
  }
  const ICO = { Salon: '🛋️', Cuisine: '🍳', Chambre: '🛏️', 'Éclairage': '💡', 'Décoration': '🪴', Rangement: '📚', 'Salle de bain': '🛁', Divers: '📦' };

  function render() {
    const d = HE.data, st = HE.st;
    const cats = [...new Set((d.catalog || []).map((x) => x.cat))];
    root.innerHTML = `<div class="he-view" id="he-view"></div>
      <aside class="he-panel">
        <div class="he-head"><div><small>Mode éditeur</small><b>${esc(d.name || 'Mon logement')}</b></div><button class="he-x" data-he="close" title="Quitter (Échap)">✕</button></div>
        <div class="he-count"><span>${st.placed ?? d.placed} / ${st.limit ?? d.limit}</span> objets posés<i style="width:${Math.min(100, ((st.placed ?? d.placed) / Math.max(1, st.limit ?? d.limit)) * 100)}%"></i></div>
        <label class="he-switch ${st.snap ? 'on' : ''}" data-he="snap"><span><b>Coller au sol</b><small>${st.snap ? 'L\'objet se pose sur ce que vise la souris' : 'L\'objet flotte (Pg.Préc / Pg.Suiv : distance)'}</small></span><i></i></label>
        <input class="he-search" id="he-q" placeholder="Rechercher un objet…" value="${esc(HE.q)}">
        <div class="he-cats"><button class="${!HE.cat ? 'on' : ''}" data-he-cat="">Tout</button>${cats.map((c) => `<button class="${HE.cat === c ? 'on' : ''}" data-he-cat="${esc(c)}">${ICO[c] || ''} ${esc(c)}</button>`).join('')}</div>
        <div class="he-list" id="he-list"></div>
        <div class="he-keys"><span><kbd>Z Q S D</kbd> voler</span><span><kbd>Espace</kbd><kbd>Ctrl</kbd> monter / descendre</span><span><kbd>Clic droit</kbd> regarder</span>
          <span><kbd>Molette</kbd> tourner l'objet</span><span><kbd>G</kbd> coller au sol</span><span><kbd>Échap</kbd> lâcher / quitter</span></div>
      </aside>
      <div class="he-bar ${st.model || st.sel ? '' : 'hidden'}">
        ${st.model ? `<span>${st.moving ? 'Déplacement' : 'En main'} : <b>${esc(label(st.model))}</b>${st.valid === false ? ' · <em>trop loin</em>' : ''}</span><span class="he-hint">Clic dans la pièce pour poser</span>
          <button data-he="rotl">⟲</button><button data-he="rotr">⟳</button><button data-he="drop">Lâcher</button>`
        : st.sel ? `<span>Sélection : <b>${esc(label(st.sel.model))}</b></span><button data-he="move">✥ Déplacer</button><button class="danger" data-he="delete">🗑 Retirer</button>` : ''}
      </div>`;
    drawList();
  }
  const label = (m) => ((HE.data.catalog || []).find((x) => x.model === m) || {}).label || m;

  root.addEventListener('mouseover', (e) => {
    const it = e.target.closest('[data-he-pick]');
    const m = it ? it.dataset.hePick : null;
    if (m !== HE.hover) { HE.hover = m; he('preview', { model: m }); }
  });
  root.addEventListener('mouseleave', () => { HE.hover = null; he('preview', {}); });
  root.addEventListener('contextmenu', (e) => e.preventDefault());
  root.addEventListener('click', (e) => {
    let b;
    if (e.target.id === 'he-view') return he('click');
    if ((b = e.target.closest('[data-he-pick]'))) { HE.hover = null; return he('pick', { model: b.dataset.hePick }); }
    if ((b = e.target.closest('[data-he-cat]'))) { HE.cat = b.dataset.heCat; return render(); }
    if (!(b = e.target.closest('[data-he]'))) return;
    const a = b.dataset.he;
    if (a === 'snap') return he('snap', { on: !HE.st.snap });
    if (a === 'rotl') return he('rotate', { deg: -15 });
    if (a === 'rotr') return he('rotate', { deg: 15 });
    he(a);
  });
  root.addEventListener('input', (e) => { if (e.target.id === 'he-q') { HE.q = e.target.value; drawList(); } });
  root.addEventListener('focusin', (e) => { if (e.target.id === 'he-q') he('typing', { on: true }); });
  root.addEventListener('focusout', (e) => { if (e.target.id === 'he-q') he('typing', { on: false }); });
  document.addEventListener('keydown', (e) => {
    if (root.classList.contains('hidden') || e.target.id === 'he-q') return;
    if (e.key === 'Escape') { e.stopImmediatePropagation(); e.preventDefault(); he(HE.st.model ? 'drop' : 'close'); }
  }, true);

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action !== 'hedit') return;
    if (m.show === true) { HE.data = m.data; HE.st = { snap: true, placed: m.data.placed, limit: m.data.limit }; root.classList.remove('hidden'); render(); return; }
    if (m.show === false) { root.classList.add('hidden'); root.innerHTML = ''; HE.data = null; return; }
    if (m.state && HE.data) {
      const keepQ = document.activeElement && document.activeElement.id === 'he-q';
      HE.st = m; render();
      if (keepQ) { const i = $('#he-q', root); i.focus(); i.setSelectionRange(i.value.length, i.value.length); }
    }
  });
})();
