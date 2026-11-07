/* =====================================================================
   ELYZEA DYNASTY 8 - interface : immeuble (liste des appartements)
   Entrer (mon appartement / accès donné), saisir le code (pavé), sonner, entrée staff.
   Les droits viennent du serveur ; l'interface n'envoie que des choix.
   ===================================================================== */
(() => {
  const B = { d: null, q: '', pad: null, busy: false, bellAt: {} };
  const root = () => $('#building');
  const initials = (s) => {
    const m = String(s || '').match(/(\d+[a-z]?)\s*$/i);
    if (m) return m[1].toUpperCase();
    return String(s || '?').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase();
  };
  const mark = (size, anim = true) => (window.Ely ? Ely.mark({ size, anim, live: true }) : '');

  function card(a, i) {
    const mine = a.role === 'holder', tenant = a.role === 'tenant';
    const chips = [];
    if (mine) chips.push('<span class="chip me">★ Mon appartement</span>');
    else if (tenant) chips.push('<span class="chip ten">Locataire</span>');
    if (!mine && !tenant) {
      if (a.occupied) chips.push(`<span class="chip busy"><i></i>${esc(a.statusLabel || 'Occupé')}</span>`);
      else chips.push(`<span class="chip free"><i></i>${esc(a.statusLabel || 'Disponible')}</span>`);
    }
    if (a.granted) chips.push('<span class="chip key">🔑 Accès donné</span>');
    if (a.visit) chips.push('<span class="chip key">Visite en cours</span>');
    if (!a.occupied && (a.salePrice || a.rentPrice)) {
      chips.push(`<span class="chip">${[a.salePrice ? `Vente ${money(a.salePrice)}` : '', a.rentPrice ? `Location ${money(a.rentPrice)} / jour` : ''].filter(Boolean).join(' · ')}</span>`);
    }
    const acts = [];
    if (a.canEnter) acts.push(`<button class="bbtn ${mine || tenant ? 'ok' : 'go'}" data-bd="enter" data-pid="${a.id}">🚪 Entrer</button>`);
    if (!a.canEnter && a.hasCode) acts.push(`<button class="bbtn" data-bd="pad" data-pid="${a.id}">🔢 Code</button>`);
    if (!a.canEnter && a.occupied) acts.push(`<button class="bbtn" data-bd="bell" data-pid="${a.id}"><i>🔔</i> Sonner</button>`);
    if (!a.canEnter && B.d.staff) acts.push(`<button class="bbtn" data-bd="staff" data-pid="${a.id}" title="Entrée staff">🛠️</button>`);
    if (!acts.length && !a.occupied) acts.push('<span class="chip">Contactez Dynasty 8</span>');
    return `<div class="apt ${mine || tenant ? 'mine' : ''}" style="animation-delay:${Math.min(i, 12) * 0.035}s" data-apt="${a.id}">
      <div class="door">${esc(initials(a.name))}</div>
      <div style="min-width:0"><div class="nm">${esc(a.name)}</div><div class="meta">${chips.join('')}</div></div>
      <div class="acts">${acts.join('')}</div></div>`;
  }

  function list() {
    const q = B.q.trim().toLowerCase();
    const apts = (B.d.apts || []).filter((a) => !q || a.name.toLowerCase().includes(q));
    // Mes appartements en premier
    apts.sort((x, y) => (y.role ? 1 : 0) - (x.role ? 1 : 0));
    const el = $('.bd-list', root());
    el.innerHTML = apts.map(card).join('') || `<div class="bd-empty">${(B.d.apts || []).length ? 'Aucun appartement ne correspond.' : 'Aucun appartement dans cet immeuble.'}</div>`;
  }

  function render() {
    const d = B.d;
    const apts = d.apts || [];
    const occ = apts.filter((a) => a.occupied).length;
    root().innerHTML = `<div class="bd">
      <button class="bd-x" data-bd="close" aria-label="Fermer">✕</button>
      <div class="bd-head"><div class="arc"></div><div class="moon"></div><div class="sky">${window.Ely ? Ely.skyline({ w: 760, h: 120, seed: 4 + (d.id || 0), lit: 0.3, palm: false }) : ''}</div>
        <div class="mk">${mark(64)}</div><div class="tt"><small>Résidence · Dynasty 8</small><h1>${esc(d.name)}</h1>${d.address ? `<p>${esc(d.address)}</p>` : ''}</div></div>
      <div class="bd-bar"><label class="bd-search"><span>🔍</span><input id="bdq" placeholder="Rechercher un appartement" value="${esc(B.q)}" maxlength="40"></label>
        <div class="bd-count"><b><i style="background:#9B5CFF"></i>${apts.length} appart.</b><b><i style="background:#FF4D6D"></i>${occ} occupé(s)</b><b><i style="background:#3EE6B0"></i>${apts.length - occ} libre(s)</b></div></div>
      <div class="bd-list"></div>
      <div class="bd-foot">Vous êtes propriétaire ou locataire : entrée directe. Sinon, saisissez le code ou sonnez : le résident vous ouvre.</div></div>`;
    list();
  }

  function open(d) {
    B.d = d; B.q = ''; B.pad = null; B.busy = false;
    root().classList.remove('hidden');
    render();
  }
  function hide() {
    const bd = $('.bd', root());
    if (bd && !root().classList.contains('hidden')) {
      bd.classList.add('out');
      setTimeout(() => { if (!B.d) { root().classList.add('hidden'); root().innerHTML = ''; } }, 220);
    } else { root().classList.add('hidden'); root().innerHTML = ''; }
    B.d = null; B.pad = null;
  }
  const close = () => post('close', { ui: 'building' });

  // Pavé numérique du code
  function padRender(err) {
    const p = B.pad, a = (B.d.apts || []).find((x) => x.id === p.pid) || {};
    let w = $('.pad-wrap', root());
    if (!w) { $('.bd', root()).insertAdjacentHTML('beforeend', '<div class="pad-wrap"></div>'); w = $('.pad-wrap', root()); }
    const n = Math.max(4, p.code.length);
    w.innerHTML = `<div class="pad ${err ? 'shake' : ''}"><small>Code d'entrée</small><h3>${esc(a.name || '')}</h3>
      <div class="dots ${p.state || ''}">${Array.from({ length: n }, (_, i) => `<i class="${i < p.code.length ? 'on' : ''}"></i>`).join('')}</div>
      <div class="keys">${[1, 2, 3, 4, 5, 6, 7, 8, 9].map((k) => `<button data-key="${k}">${k}</button>`).join('')}
        <button class="del" data-key="del">⌫</button><button data-key="0">0</button><button class="val" data-key="ok">OK</button></div>
      <div class="err">${esc(err || '')}</div><button class="cancel" data-key="cancel">Annuler</button></div>`;
  }
  async function padKey(k) {
    const p = B.pad; if (!p || p.busy) return;
    if (k === 'cancel') { B.pad = null; const w = $('.pad-wrap', root()); if (w) w.remove(); return; }
    if (k === 'del') { p.code = p.code.slice(0, -1); p.state = ''; return padRender(); }
    if (k === 'ok') {
      if (p.code.length < 4) return padRender('Le code fait au moins 4 chiffres.');
      p.busy = true;
      const r = await post('building', { do_: 'code', pid: p.pid, code: p.code });
      p.busy = false;
      if (!B.pad) return;
      if (r && r.ok) { p.state = 'ok'; padRender(); return; }
      p.state = 'ko'; padRender((r && r.error) || 'Code incorrect.');
      setTimeout(() => { if (B.pad === p) { p.code = ''; p.state = ''; padRender((r && r.error) || 'Code incorrect.'); } }, 650);
      return;
    }
    if (/^\d$/.test(k) && p.code.length < 8) { p.code += k; p.state = ''; padRender(); }
  }

  root().addEventListener('input', (e) => { if (e.target.id === 'bdq') { B.q = e.target.value; list(); } });
  root().addEventListener('click', async (e) => {
    const key = e.target.closest('[data-key]');
    if (key) return padKey(key.dataset.key);
    const b = e.target.closest('[data-bd]');
    if (!b || !B.d || B.busy) return;
    const a = b.dataset.bd, pid = Number(b.dataset.pid);
    if (a === 'close') return close();
    if (a === 'pad') { B.pad = { pid, code: '' }; return padRender(); }
    if (a === 'bell') {
      const last = B.bellAt[pid] || 0, cd = (B.d.bellCooldown || 20) * 1000;
      if (Date.now() - last < cd) return toast(`Patientez ${Math.ceil((cd - (Date.now() - last)) / 1000)} s avant de sonner à nouveau.`, false);
    }
    B.busy = true; b.classList.add('wait');
    const r = await post('building', { do_: a, pid });
    B.busy = false; b.classList.remove('wait');
    if (r && r.error) return toast(r.error, false);
    if (a === 'bell') { B.bellAt[pid] = Date.now(); b.classList.add('ring'); setTimeout(() => b.classList.remove('ring'), 1900); if (r.message) toast(r.message, true); }
  });

  document.addEventListener('keydown', (e) => {
    if (!B.d) return;
    if (B.pad) {
      if (/^\d$/.test(e.key)) { e.preventDefault(); return padKey(e.key); }
      if (e.key === 'Backspace') { e.preventDefault(); return padKey('del'); }
      if (e.key === 'Enter') { e.preventDefault(); return padKey('ok'); }
      if (e.key === 'Escape') { e.preventDefault(); e.stopImmediatePropagation(); return padKey('cancel'); }
      return;
    }
    if (e.key === 'Escape') { e.preventDefault(); e.stopImmediatePropagation(); close(); }
  }, true);

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'building') { if (m.show) open(m.data || {}); else hide(); }
    else if (m.action === 'closeAll' && B.d) hide();
  });
  window.Building = { open, hide };
})();
