/* =====================================================================
   ELYZEA BOÎTE DE NUIT - administration des boîtes (staff, « club_manage »)
   Créer plusieurs boîtes, placer leurs points, nommer le patron, activer,
   supprimer, retirer une enceinte, couper la musique.
   ===================================================================== */
(() => {
  const A = { data: null, sel: null, edit: null };
  const wrap = $('#admin');
  const el = () => $('#admin .modal');
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;
  const POINTS = [
    ['door', '🚪 Entrée', 'Obligatoire. Les clients y appuient sur E pour entrer (prix, bracelet, VIP, liste noire).'],
    ['inside', '🪩 Intérieur', 'Facultatif. Si placé, payer l\'entrée téléporte ici, et E ici ressort à l\'entrée.'],
    ['bar', '🍸 Bar', 'Obligatoire. Les serveurs y encaissent ; les clients y voient la carte.'],
    ['stash', '📦 Coffre', 'Coffre de la boîte (grades avec la permission « coffre »).'],
    ['manage', '💼 Bureau', 'Les employés y ouvrent la tablette.'],
  ];

  function form(s) {
    const o = (s && s.options) || {};
    return `<div class="form-grid">
      <label class="field"><span>Nom de la boîte</span><input class="input" data-af="name" maxlength="80" value="${esc(s ? s.name : '')}" placeholder="Ex : Galaxy Club"></label>
      <label class="field"><span>Adresse</span><input class="input" data-af="address" maxlength="120" value="${esc(s ? s.address : '')}"></label>
      <label class="field"><span>Métier (elyzea_core)</span><input class="input mono" data-af="job" maxlength="40" value="${esc(s ? s.job : '')}" placeholder="vide = créé depuis le nom"></label>
      <label class="field"><span>Nom du métier affiché</span><input class="input" data-af="jobLabel" maxlength="60" value="${esc(s ? s.jobLabel : '')}"></label>
      <label class="field"><span>Compte de société</span><input class="input mono" data-af="society" maxlength="40" value="${esc(s ? s.society : '')}" placeholder="vide = nom du métier"></label>
      <label class="field"><span>Début des matricules</span><input class="input mono" data-af="matPrefix" maxlength="8" value="${esc(s ? s.matPrefix : 'BN-')}"></label>
      <label class="field"><span>Icône sur la carte (sprite)</span><input class="input" type="number" data-af="blipSprite" value="${o.blipSprite || 614}"></label>
      <label class="field"><span>Couleur de l'icône</span><input class="input" type="number" data-af="blipColor" value="${o.blipColor != null ? o.blipColor : 27}"></label>
      <label class="check"><input type="checkbox" data-af="blip" ${o.blip !== false ? 'checked' : ''}> Icône sur la carte</label>
      <label class="check"><input type="checkbox" data-af="requireDuty" ${o.requireDuty !== false ? 'checked' : ''}> Service obligatoire pour servir / contrôler</label>
    </div>`;
  }

  function draw() {
    const d = A.data || { shops: [] };
    const s = d.shops.find((x) => x.id === A.sel);
    let main;
    if (A.edit === 'new') {
      main = `<h2>Nouvelle boîte de nuit</h2><p class="lead">Elle est créée <b>désactivée</b>, avec 5 grades (Serveur, Videur, DJ, Gérant, Patron), sa carte du bar et un stock de départ de 20 par boisson.</p>
        ${form(null)}<div class="actions"><button class="btn" data-ad="cancel">Annuler</button><button class="btn primary" data-ad="save">Créer</button></div>`;
    } else if (!s) {
      main = empty('Choisissez une boîte à gauche, ou créez-en une.');
    } else if (A.edit === s.id) {
      main = `<h2>Modifier · ${esc(s.name)}</h2>${form(s)}<div class="actions"><button class="btn" data-ad="cancel">Annuler</button><button class="btn primary" data-ad="save">Enregistrer</button></div>`;
    } else {
      main = `<div class="adm-hero"><div><h2>${esc(s.name)}</h2><small class="faint">${esc(s.address || '')} · métier <span class="mono">${esc(s.job)}</span> · compte <span class="mono">${esc(s.society)}</span></small></div>
          <div class="chips">${s.enabled ? '<span class="pill on">Activée</span>' : '<span class="pill off">Désactivée</span>'}${s.publicOpen ? '<span class="pill on">Ouverte au public</span>' : '<span class="pill off">Fermée au public</span>'}</div></div>
        <div class="stats"><div class="stat green"><b>${money(s.balance)}</b><span>Compte</span></div><div class="stat blue"><b>${s.employees}</b><span>Employé(s)</span></div>
          <div class="stat violet"><b>${s.speakers.length}</b><span>Enceinte(s) · ${s.tracks} titre(s)</span></div><div class="stat orange"><b>${s.fee > 0 ? money(s.fee) : 'Gratuite'}</b><span>Entrée</span></div></div>
        <div class="actions-row"><button class="btn ${s.enabled ? 'danger' : 'primary'}" data-ad="enable">${s.enabled ? 'Désactiver' : 'Activer'}</button>
          <button class="btn" data-ad="edit">Modifier</button><button class="btn" data-ad="boss">👑 Nommer le patron</button>
          ${s.music ? `<button class="btn" data-ad="musicStop">⏹ Couper la musique</button>` : ''}<button class="btn danger" data-ad="delete">Supprimer</button></div>
        <div class="card"><h2>Points</h2><p class="faint" style="font-size:.8rem;margin-bottom:.5rem">Placez-vous à l'endroit voulu (fermez ce panneau, marchez, rouvrez-le avec /clubadmin), puis « Placer ici ».</p>
          ${POINTS.map(([k, label, hint]) => { const pt = (s.points || {})[k]; return `<div class="list-row"><div class="main"><b>${label}</b><small>${pt ? `${pt.x.toFixed(1)}, ${pt.y.toFixed(1)}, ${pt.z.toFixed(1)}` : hint}</small></div>
            ${pt ? '<span class="pill on">Placé</span>' : '<span class="pill off">Non placé</span>'}<button class="btn small primary" data-pt="${k}">Placer ici</button>
            ${pt ? `<button class="btn small" data-tp="${k}">Aller</button><button class="btn small danger" data-ptdel="${k}">Retirer</button>` : ''}</div>`; }).join('')}</div>
        <div class="card"><h2>Enceintes posées par la boîte</h2>${s.speakers.map((sp) => `<div class="list-row"><span class="ico">🔊</span><div class="main"><b>${esc(sp.label)}</b><small class="mono">#${sp.id} · ${sp.x.toFixed(1)}, ${sp.y.toFixed(1)}, ${sp.z.toFixed(1)}</small></div>
            <button class="btn small" data-tpsp="${sp.id}">Aller</button><button class="btn small danger" data-spdel="${sp.id}">Retirer</button></div>`).join('') || empty('Aucune enceinte. Le patron (ou un grade autorisé) les pose depuis le F6 ou la tablette.')}
          ${s.music ? `<p class="faint" style="margin-top:.5rem">En cours : ${esc(s.music.title || '')}${s.music.paused ? ' (pause)' : ''}</p>` : ''}</div>`;
    }
    el().innerHTML = `<div class="modal-head"><div><div class="eyebrow">Staff</div><h2>Boîtes de nuit</h2></div><button class="icon-btn" data-ad="close" aria-label="Fermer">✕</button></div>
      <div class="adm-split"><div class="adm-list">${d.shops.map((x) => `<button class="pick ${x.id === A.sel ? 'on' : ''}" data-sel="${x.id}"><b>${esc(x.name)}</b>
          <small>${x.enabled ? 'Activée' : 'Désactivée'} · ${x.employees} employé(s)</small></button>`).join('') || '<p class="faint">Aucune boîte.</p>'}
        <button class="btn primary block" data-ad="new" style="margin-top:.6rem">+ Nouvelle boîte</button></div>
      <div class="adm-main">${main}</div></div>`;
  }

  async function reload() { const r = await post('admReload'); if (!r.error) { A.data = r; draw(); } return r; }
  async function run(action, data, btn) { const r = await act(adm(action, data), btn); if (r.ok) await reload(); return r; }

  wrap.addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-sel]'))) { A.sel = Number(b.dataset.sel); A.edit = null; return draw(); }
    if ((b = e.target.closest('[data-pt]'))) return run('point', { id: A.sel, key: b.dataset.pt }, b);
    if ((b = e.target.closest('[data-ptdel]'))) return run('point', { id: A.sel, key: b.dataset.ptdel, remove: true }, b);
    if ((b = e.target.closest('[data-tp]'))) return act(adm('teleport', { id: A.sel, key: b.dataset.tp }), b);
    if ((b = e.target.closest('[data-tpsp]'))) return act(adm('teleport', { id: A.sel, key: 'speaker', speaker: Number(b.dataset.tpsp) }), b);
    if ((b = e.target.closest('[data-spdel]'))) {
      if (!(await confirmBox('Retirer l\'enceinte ?', 'Elle disparaît pour tout le monde.', 'Retirer', true))) return;
      return run('speakerRemove', { id: A.sel, speaker: Number(b.dataset.spdel) }, b);
    }
    if (!(b = e.target.closest('[data-ad]'))) return;
    const a = b.dataset.ad;
    const s = (A.data.shops || []).find((x) => x.id === A.sel);
    if (a === 'close') return post('close', { ui: 'admin' });
    if (a === 'new') { A.edit = 'new'; return draw(); }
    if (a === 'edit') { A.edit = A.sel; return draw(); }
    if (a === 'cancel') { A.edit = null; return draw(); }
    if (a === 'save') {
      const v = {};
      el().querySelectorAll('[data-af]').forEach((i) => { v[i.dataset.af] = i.type === 'checkbox' ? i.checked : i.value; });
      v.blipSprite = Number(v.blipSprite); v.blipColor = Number(v.blipColor);
      if (A.edit !== 'new') v.id = A.sel;
      const r = await act(adm('shopSave', v), b);
      if (r.ok) { A.sel = r.id; A.edit = null; await reload(); }
      return;
    }
    if (!s) return;
    if (a === 'enable') return run('shopEnable', { id: s.id, enabled: !s.enabled }, b);
    if (a === 'musicStop') return run('musicStop', { id: s.id }, b);
    if (a === 'boss') {
      const v = await confirmBox('Nommer le patron', `Le joueur reçoit le plus haut grade de <b>${esc(s.name)}</b> (il est recruté s'il ne l'est pas).`, 'Nommer', false,
        '<label class="field" style="margin-top:.6rem"><span>ID serveur du joueur</span><input class="input" type="number" min="1" data-cfv="target"></label>');
      if (!v) return;
      return run('setBoss', { id: s.id, target: Number(v.target) });
    }
    if (a === 'delete') {
      const v = await confirmBox('Supprimer la boîte ?', `Les employés sont retirés du métier, les enceintes disparaissent. Les ventes et les finances sont gardées.<br>Tapez <b>${esc(s.name)}</b> pour confirmer.`, 'Supprimer', true,
        '<label class="field" style="margin-top:.6rem"><input class="input" data-cfv="confirm"></label>');
      if (!v) return;
      const r = await act(adm('shopDelete', { id: s.id, confirm: v.confirm }), b);
      if (r.ok) { A.sel = null; await reload(); }
    }
  });

  window.Admin = {
    open(d) { A.data = d; if (!A.sel && d.shops.length) A.sel = d.shops[0].id; A.edit = null; wrap.classList.remove('hidden'); draw(); },
    hide() { wrap.classList.add('hidden'); },
    isOpen: () => !wrap.classList.contains('hidden'),
  };
})();
