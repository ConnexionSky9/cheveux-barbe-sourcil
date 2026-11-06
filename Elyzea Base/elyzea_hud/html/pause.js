/* =========================================================
   MENU ÉCHAP ELYZEA FA (interface)
   Échap / Retour : reprendre · ↑ ↓ + Entrée : naviguer · Carte, Paramètres, Touches : écrans de GTA
   aux couleurs d'Elyzea · Quitter : avec confirmation.
   ========================================================= */
(() => {
  const ICON = {
    resume: '<path d="M8 5v14l11-7z" fill="currentColor"/>',
    map: '<path d="M9 4 3 6.5v13.5l6-2.5 6 2.5 6-2.5V4l-6 2.5zM9 4v13.5M15 6.5V20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>',
    settings: '<path d="M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7zM19.4 13.5l1.6 1.2-2 3.4-1.9-.7a7 7 0 0 1-1.9 1.1l-.3 2h-4l-.3-2a7 7 0 0 1-1.9-1.1l-1.9.7-2-3.4 1.6-1.2a7 7 0 0 1 0-3l-1.6-1.2 2-3.4 1.9.7a7 7 0 0 1 1.9-1.1l.3-2h4l.3 2a7 7 0 0 1 1.9 1.1l1.9-.7 2 3.4-1.6 1.2a7 7 0 0 1 0 3z" fill="none" stroke="currentColor" stroke-width="1.6"/>',
    keys: '<rect x="3" y="6" width="18" height="12" rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M7 10h.01M11 10h.01M15 10h.01M7 14h10" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    quit: '<path d="M14 4h5v16h-5M10 8l-4 4 4 4M6 12h10" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
  };
  const ITEMS = [
    ['resume', 'Reprendre', 'Échap'], ['map', 'Carte', 'P'], ['settings', 'Paramètres', ''], ['keys', 'Touches', ''], ['quit', 'Quitter Elyzea', ''],
  ];
  const root = document.createElement('div');
  root.id = 'pause';
  document.body.appendChild(root);
  const post = (a) => fetch(`https://${typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_hud'}/pause`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ a }) }).catch(() => {});
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const money = (v) => v == null ? '—' : `${Math.round(v).toLocaleString('fr-FR')} $`;
  let st = { sel: 0, tips: [], tip: 0, max: 128, players: null }, tipTimer = 0;

  function build(d) {
    const dots = Array.from({ length: 34 }, () => `<i style="left:${(Math.random() * 100).toFixed(1)}%;animation-duration:${(8 + Math.random() * 10).toFixed(1)}s;animation-delay:-${(Math.random() * 14).toFixed(1)}s"></i>`).join('');
    const name = (d.server || 'ELYZEA FA').split(' ');
    root.innerHTML = `<div class="pz-bg"></div><div class="pz-aurora"></div><div class="pz-grid"></div><div class="pz-dots">${dots}</div>
      <div class="pz-sky">${window.Ely ? Ely.skyline({ w: 1920, h: 280, seed: 11, lit: 0.2 }) : ''}</div><div class="pz-scan"></div>
      <div class="pz">
        <section class="pz-left">
          <div class="pz-brand"><div class="pz-logo">${window.Ely ? Ely.mark({ size: 150, live: true }) : ''}</div>
            <div class="pz-title"><small>BIENVENUE SUR</small><h1>${esc(name[0])} <b>${esc(name.slice(1).join(' '))}</b></h1><p>SERVEUR ROLEPLAY · LOS SANTOS</p></div></div>
          <nav class="pz-menu">${ITEMS.map(([k, l, key], i) => `<button class="pz-btn ${k === 'quit' ? 'danger' : ''}" data-pz="${k}" style="animation-delay:${0.08 + i * 0.07}s">
            <span class="n">0${i + 1}</span><span class="i"><svg viewBox="0 0 24 24">${ICON[k]}</svg></span>${l}${key ? `<small>${key}</small>` : ''}</button>`).join('')}</nav>
          <div class="pz-tip"><b>ASTUCE</b><span id="pz-tip"></span></div>
        </section>
        <aside class="pz-right">
          <div class="pz-card" style="animation-delay:.12s"><h3>MON PERSONNAGE</h3><div class="pz-me"><div class="pz-av" id="pz-av">E</div><div><b id="pz-name">—</b><span id="pz-job">Citoyen</span></div></div>
            <div class="pz-kv"><div><small>LIQUIDE</small><b id="pz-cash">—</b></div><div><small>BANQUE</small><b id="pz-bank">—</b></div><div><small>ID</small><b id="pz-id">—</b></div><div><small>SANTÉ</small><b id="pz-hp">—</b></div></div></div>
          <div class="pz-card" style="animation-delay:.22s"><h3>SERVEUR</h3><div class="pz-big"><b id="pz-pl">—</b><span id="pz-max">/ ${d.maxPlayers || 128} joueurs connectés</span></div>
            <div class="pz-bar"><i id="pz-plbar" style="width:0"></i></div>
            <div class="pz-kv"><div><small>HEURE EN VILLE</small><b id="pz-time">--:--</b></div><div><small>AUJOURD'HUI</small><b id="pz-date">—</b></div></div></div>
          <div class="pz-card" style="animation-delay:.32s"><h3>POSITION</h3><div class="pz-pos"><div class="pz-comp"><b>N</b><i id="pz-arrow"></i></div>
            <div><b id="pz-zone">—</b><span id="pz-street"></span></div><button class="pz-mini pz-mapbtn" data-pz="map">Carte</button></div></div>
          ${d.discord ? `<div class="pz-card" style="animation-delay:.42s"><div class="pz-disc"><span>Rejoignez la communauté</span><b>${esc(d.discord)}</b></div></div>` : ''}
        </aside>
      </div>
      <div class="pz-foot"><span><kbd>ÉCHAP</kbd>Reprendre</span><span><kbd>↑ ↓</kbd>Naviguer</span><span><kbd>ENTRÉE</kbd>Valider</span><span><kbd>P</kbd>Carte</span></div>
      <div class="pz-modal" id="pz-modal"><div><h2>Quitter Elyzea FA ?</h2><p>Votre personnage est sauvegardé. Vous pourrez revenir quand vous voulez.</p>
        <div class="row"><button data-pz="cancel">Rester</button><button class="q" data-pz="quitok">Quitter</button></div></div></div>`;
    st.tips = d.tips || []; st.tip = 0; st.max = d.maxPlayers || 128;
    showTip(); clearInterval(tipTimer); tipTimer = setInterval(() => { st.tip = (st.tip + 1) % Math.max(1, st.tips.length); showTip(); }, 6000);
    select(0);
  }
  function showTip() {
    const el = root.querySelector('#pz-tip'); if (!el) return;
    el.style.opacity = 0;
    setTimeout(() => { el.textContent = st.tips[st.tip] || ''; el.style.opacity = 1; }, 250);
  }
  function player(p) {
    if (!p) return;
    const set = (id, v) => { const el = root.querySelector('#' + id); if (el) el.textContent = v; };
    const fn = p.firstname || '', ln = p.lastname || '';
    set('pz-name', `${fn} ${ln.toUpperCase()}`.trim() || '—');
    set('pz-av', ((fn[0] || '') + (ln[0] || '')).toUpperCase() || 'E');
    set('pz-job', p.job ? `${p.job}${p.grade ? ' · ' + p.grade : ''}` : 'Citoyen');
    set('pz-cash', money(p.cash)); set('pz-bank', money(p.bank)); set('pz-id', p.id ?? '—'); set('pz-hp', `${Math.round(p.health ?? 0)} %`);
    set('pz-time', `${String(p.hour ?? 0).padStart(2, '0')}:${String(p.minute ?? 0).padStart(2, '0')}`);
    set('pz-date', new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }));
    set('pz-zone', p.zone || 'Los Santos');
    set('pz-street', [p.street, p.cross].filter(Boolean).join(' / '));
    const a = root.querySelector('#pz-arrow'); if (a) a.style.transform = `rotate(${-(p.heading || 0)}deg)`;
  }
  function select(i) {
    const btns = [...root.querySelectorAll('.pz-menu .pz-btn')];
    st.sel = (i + btns.length) % btns.length;
    btns.forEach((b, k) => b.classList.toggle('sel', k === st.sel));
  }
  function act(a) {
    if (a === 'quit') return root.querySelector('#pz-modal').classList.add('on');
    if (a === 'cancel') return root.querySelector('#pz-modal').classList.remove('on');
    if (a === 'quitok') return post('quit');
    post(a);
  }
  root.addEventListener('click', (e) => { const b = e.target.closest('[data-pz]'); if (b) act(b.dataset.pz); });
  root.addEventListener('mouseover', (e) => {
    const b = e.target.closest('.pz-menu .pz-btn');
    if (b) select([...root.querySelectorAll('.pz-menu .pz-btn')].indexOf(b));
  });
  document.addEventListener('keydown', (e) => {
    if (!root.classList.contains('on')) return;
    const modal = root.querySelector('#pz-modal');
    if (e.key === 'Escape' || e.key === 'Backspace') { e.preventDefault(); if (modal.classList.contains('on')) modal.classList.remove('on'); else post('resume'); }
    else if (e.key === 'ArrowDown') select(st.sel + 1);
    else if (e.key === 'ArrowUp') select(st.sel - 1);
    else if (e.key === 'Enter') { const b = root.querySelectorAll('.pz-menu .pz-btn')[st.sel]; if (b) act(b.dataset.pz); }
    else if (e.key === 'p' || e.key === 'P') post('map');
  });
  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'pause') {
      if (m.open) { build(m); player(m.player); root.classList.add('on'); document.body.classList.add('paused'); }
      else { root.classList.remove('on'); document.body.classList.remove('paused'); clearInterval(tipTimer); root.innerHTML = ''; }
    } else if (m.action === 'pauseTick') player(m.player);
    else if (m.action === 'pauseInfo' && m.data) {
      const n = m.data.players ?? 0, el = root.querySelector('#pz-pl'), bar = root.querySelector('#pz-plbar');
      if (el) el.textContent = n;
      if (bar) bar.style.width = `${Math.min(100, (n / Math.max(1, st.max)) * 100)}%`;
    }
  });
})();
