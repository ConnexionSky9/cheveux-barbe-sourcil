/* =====================================================================
   ELYZEA JOBS · pages « Équipe » et « Patron » communes aux tablettes F6
   Utilisation dans une tablette :
     const team = await EJobs.team();            // infos + droits (affiche/masque l'onglet Patron)
     EJobs.mount(element, 'team' | 'boss', { onClose })
   Tout passe par le callback NUI « ejobs » de la ressource (client/bridge.lua),
   et le serveur revérifie chaque action.
   ===================================================================== */
(() => {
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'demo';
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
  const when = (t) => {
    if (!t) return '';
    const d = new Date(Number(t) * 1000);
    const p = (n) => String(n).padStart(2, '0');
    return `${p(d.getDate())}/${p(d.getMonth() + 1)} ${p(d.getHours())}:${p(d.getMinutes())}`;
  };

  async function call(action, data = {}) {
    if (window.EJobsDemo) return window.EJobsDemo(action, data);
    try {
      const r = await fetch(`https://${RES}/ejobs`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action, data }) });
      return await r.json();
    } catch (e) { return { error: 'Connexion au jeu impossible.' }; }
  }

  /* ---------- Notifications et confirmations ---------- */
  let toastEl = null, toastT = null;
  function toast(msg, ok = true) {
    if (!toastEl) { toastEl = document.createElement('div'); toastEl.className = 'ej-toast'; toastEl.setAttribute('role', 'status'); document.body.appendChild(toastEl); }
    toastEl.textContent = msg;
    toastEl.className = `ej-toast on ${ok ? 'ok' : 'err'}`;
    clearTimeout(toastT);
    toastT = setTimeout(() => toastEl.classList.remove('on'), 3200);
  }
  function confirmBox(title, text, danger = false, label = 'Confirmer') {
    return new Promise((resolve) => {
      const m = document.createElement('div');
      m.className = 'ej-modal';
      m.innerHTML = `<div class="ej-mbox" role="dialog" aria-modal="true"><h3>${esc(title)}</h3><p>${esc(text)}</p>
        <div class="ej-row-end"><button class="ej-btn" data-r="0">Annuler</button><button class="ej-btn ${danger ? 'danger' : 'primary'}" data-r="1">${esc(label)}</button></div></div>`;
      const done = (v) => { m.remove(); document.removeEventListener('keydown', key, true); resolve(v); };
      const key = (e) => { if (e.key === 'Escape') { e.stopImmediatePropagation(); e.preventDefault(); done(false); } };
      m.addEventListener('click', (e) => { const b = e.target.closest('[data-r]'); if (b) done(b.dataset.r === '1'); else if (e.target === m) done(false); });
      document.addEventListener('keydown', key, true);
      document.body.appendChild(m);
      m.querySelector('[data-r="1"]').focus();
    });
  }

  /* ---------- État ---------- */
  const S = { team: null, el: null, page: 'team', tab: null, gradeEdit: null, logKind: '', opts: {}, busy: false };

  async function loadTeam() {
    const t = await call('team');
    if (!t.error) {
      S.team = t;
      if (t.company && t.company.color && S.el) S.el.style.setProperty('--ej-accent', t.company.color);
    }
    return t;
  }

  async function act(action, data, okReload = true) {
    if (S.busy) return { error: 'Action en cours.' };
    S.busy = true;
    const r = await call(action, data);
    S.busy = false;
    if (r.error) { toast(r.error, false); return r; }
    if (r.message) toast(r.message, true);
    if (r.closed) { if (S.opts.onClose) S.opts.onClose(); return r; }
    if (okReload) await render(true);
    return r;
  }

  /* ---------- Page Équipe (espace employé) ---------- */
  function teamHtml(t) {
    const me = t.me;
    const duty = me.duty;
    return `
      <div class="ej-head">
        <div><div class="ej-eyebrow">${esc(t.company.label)} · Espace employé</div><h1>${esc(me.name)}</h1>
          <p class="ej-lead">${esc(me.gradeLabel)}${me.isboss ? ' · Patron' : ''} · ${money(me.payment)} par paie${me.specs.length ? ` · ${me.specs.map(esc).join(', ')}` : ''}</p></div>
        <span class="ej-pill ${duty ? 'on' : 'off'}">${duty ? 'En service' : 'Hors service'}</span>
      </div>
      <div class="ej-duty">
        <button class="ej-btn big primary" data-ej="dutyOn" ${duty ? 'disabled' : ''}>Prendre mon service</button>
        <button class="ej-btn big" data-ej="dutyOff" ${duty ? '' : 'disabled'}>Quitter mon service</button>
      </div>
      <div class="ej-stats">
        <div class="ej-stat"><b>${t.onDuty.length}</b><span>En service</span></div>
        <div class="ej-stat"><b>${t.total}</b><span>Employés</span></div>
        <div class="ej-stat"><b>${t.company.grades.length}</b><span>Grades</span></div>
      </div>
      <h2>En service maintenant</h2>
      ${t.onDuty.length ? `<div class="ej-list">${t.onDuty.map((m) => `<div class="ej-item"><div><b>${esc(m.name)}</b><small>${esc(m.gradeLabel)}</small></div><span class="ej-dot on"></span></div>`).join('')}</div>`
        : '<div class="ej-empty">Personne en service.</div>'}
      ${t.members ? `<h2>Équipe complète</h2>${membersTable(t, false)}` : ''}
      <h2>Quitter l'entreprise</h2>
      <div class="ej-card ej-row-between"><p class="ej-lead" style="margin:0">Pour rejoindre une autre entreprise, il faut d'abord démissionner de celle-ci.</p>
        <button class="ej-btn danger" data-ej="resign">Démissionner</button></div>`;
  }

  function statusTag(m) {
    if (!m.online) return '<span class="ej-tag">Hors ligne</span>';
    return m.duty ? '<span class="ej-tag on">En service</span>' : '<span class="ej-tag blue">Connecté</span>';
  }

  function membersTable(t, manage) {
    const list = t.members || [];
    if (!list.length) return '<div class="ej-empty">Aucun employé.</div>';
    const myLvl = t.me.grade;
    const specs = t.specialties || [];
    const grades = t.company.grades.filter((g) => g.level < myLvl && !g.isboss);
    return `<div class="ej-table-wrap"><table class="ej-table"><thead><tr><th>Employé</th><th>Grade</th><th>Statut</th>${manage ? '<th class="r">Gestion</th>' : ''}</tr></thead><tbody>
      ${list.map((m) => {
        const can = manage && m.cid !== t.me.cid && m.grade < myLvl;
        const specChips = m.specs.map((s) => { const d = specs.find((x) => x.id === s); return `<span class="ej-tag accent">${esc(d ? d.label : s)}</span>`; }).join('');
        let tools = '';
        if (can) {
          if (t.perms.promote && grades.length) {
            tools += `<select class="ej-input sm" data-grade-for="${esc(m.cid)}">${grades.map((g) => `<option value="${g.level}" ${g.level === m.grade ? 'selected' : ''}>${esc(g.name)}</option>`).join('')}</select>
              <button class="ej-btn sm" data-ej="setGrade" data-cid="${esc(m.cid)}">Appliquer</button>`;
            for (const s of specs) {
              const has = m.specs.includes(s.id);
              tools += `<button class="ej-btn sm ${has ? 'on' : ''}" data-ej="specialty" data-cid="${esc(m.cid)}" data-spec="${esc(s.id)}" data-on="${has ? 0 : 1}" title="${has ? 'Retirer' : 'Accorder'} : ${esc(s.label)}">${has ? '−' : '+'} ${esc(s.label)}</button>`;
            }
          }
          if (t.perms.fire) tools += `<button class="ej-btn sm danger" data-ej="fire" data-cid="${esc(m.cid)}" data-name="${esc(m.name)}">Licencier</button>`;
        }
        return `<tr><td><b>${esc(m.name)}</b>${specChips}</td><td>${esc(m.gradeLabel)}${m.isboss ? ' <span class="ej-tag amber">Patron</span>' : ''}</td><td>${statusTag(m)}</td>
          ${manage ? `<td class="r"><div class="ej-tools">${tools || '<span class="ej-muted">—</span>'}</div></td>` : ''}</tr>`;
      }).join('')}</tbody></table></div>`;
  }

  /* ---------- Page Patron ---------- */
  const TABS = [['staff', 'Employés', (p) => p.staff_view || p.recruit || p.promote || p.fire], ['grades', 'Grades', (p) => p.grades],
    ['money', 'Finances', (p) => p.finance_view], ['logs', 'Journal', (p) => p.logs]];

  async function bossHtml(t) {
    const tabs = TABS.filter((x) => x[2](t.perms));
    if (!tabs.length) return '<div class="ej-empty">Votre grade ne donne pas accès à l\'espace patron.</div>';
    if (!tabs.some((x) => x[0] === S.tab)) S.tab = tabs[0][0];
    let body = '';
    if (S.tab === 'staff') body = staffTab(t);
    else if (S.tab === 'grades') body = await gradesTab();
    else if (S.tab === 'money') body = await moneyTab(t);
    else body = await logsTab();
    return `<div class="ej-head"><div><div class="ej-eyebrow">${esc(t.company.label)} · Espace patron</div><h1>Gestion de l'entreprise</h1></div></div>
      <div class="ej-tabs" role="tablist">${tabs.map((x) => `<button role="tab" class="${x[0] === S.tab ? 'on' : ''}" data-ej="tab" data-tab="${x[0]}">${x[1]}</button>`).join('')}</div>${body}`;
  }

  function staffTab(t) {
    return `${t.perms.recruit ? `<div class="ej-card ej-recruit"><div><b>Recruter</b><p class="ej-lead" style="margin:2px 0 0">Envoie une proposition au joueur le plus proche (moins de ${Math.floor(t.recruitDistance)} m). Il rejoint l'entreprise au premier grade s'il accepte.</p></div>
        <button class="ej-btn huge primary" data-ej="recruit">RECRUTER</button></div>` : ''}
      ${t.members ? membersTable(t, true) : '<div class="ej-empty">Votre grade ne permet pas de voir l\'équipe complète.</div>'}`;
  }

  function permBoxes(d, perms, all) {
    return `<div class="ej-perms">${d.labels.map((l) => {
      const on = all || (perms && perms[l.id] === true);
      const lock = all || !d.mine[l.id];
      return `<label class="ej-check ${lock ? 'locked' : ''}" title="${lock && !all ? 'Vous n\'avez pas cet accès vous-même' : ''}"><input type="checkbox" data-perm="${esc(l.id)}" ${on ? 'checked' : ''} ${lock ? 'disabled' : ''}><span>${esc(l.label)}</span></label>`;
    }).join('')}</div>`;
  }

  async function gradesTab() {
    const d = await call('grades');
    if (d.error) return `<div class="ej-empty">${esc(d.error)}</div>`;
    S.grades = d;
    const e = S.gradeEdit;
    const editor = (g) => `
      <div class="ej-card ej-gedit" style="margin:10px 0">
        <div class="ej-grid ${g ? 'two' : 'three'}">
          <label class="ej-field">Nom du grade<input class="ej-input" id="ejgName" maxlength="30" value="${esc(g ? g.name : '')}" placeholder="Ex. : Responsable"></label>
          <label class="ej-field">Salaire par paie ($)<input class="ej-input" id="ejgPay" type="number" min="0" max="${d.maxSalary}" value="${g ? g.payment : 0}"></label>
          ${g ? '' : `<label class="ej-field">Place<select class="ej-input" id="ejgPos">${d.grades.filter((x) => x.level <= d.myLevel).map((x) => `<option value="${x.level}" ${x.level === d.myLevel ? 'selected' : ''}>Juste en dessous de « ${esc(x.name)} »</option>`).join('')}</select></label>`}
        </div>
        <h3 class="ej-sub">Accès</h3>
        ${permBoxes(d, g ? g.perms : {}, false)}
        <div class="ej-row-end" style="margin-top:12px"><button class="ej-btn" data-ej="gradeCancel">Annuler</button>
          <button class="ej-btn primary" data-ej="${g ? 'gradeSave' : 'gradeCreate'}">${g ? 'Enregistrer' : 'Créer le grade'}</button></div>
      </div>`;
    const rows = [...d.grades].reverse().map((g) => `
      <div class="ej-item"><div><b>${g.level} · ${esc(g.name)}</b>${g.isboss ? ' <span class="ej-tag amber">Patron</span>' : ''}
        <small>${money(g.payment)} par paie · ${g.members} employé(s) · ${g.perms === 'all' ? 'Tous les accès' : `${d.labels.filter((l) => g.perms[l.id]).length} / ${d.labels.length} accès`}</small></div>
        ${g.editable ? `<div class="ej-tools"><button class="ej-btn sm" data-ej="gradeEdit" data-level="${g.level}">Modifier</button>
          <button class="ej-btn sm danger" data-ej="gradeDelete" data-level="${g.level}" data-name="${esc(g.name)}" ${g.members ? 'disabled title="Des employés ont ce grade"' : ''}>Supprimer</button></div>` : ''}
      </div>${e === g.level ? editor(g) : ''}`).join('');
    return `<p class="ej-lead">Vous pouvez modifier et créer les grades en dessous du vôtre, et ne donner que des accès que vous avez vous-même. ${d.grades.length} / ${d.maxGrades} grades.</p>
      <div class="ej-row-end" style="margin-bottom:10px"><button class="ej-btn primary" data-ej="gradeNew" ${d.grades.length >= d.maxGrades ? 'disabled' : ''}>Nouveau grade</button></div>
      ${e === 'new' ? editor(null) : ''}<div class="ej-list">${rows}</div>`;
  }

  async function moneyTab(t) {
    const d = await call('finance');
    if (d.error) return `<div class="ej-empty">${esc(d.error)}</div>`;
    const canD = t.perms.deposit, canW = t.perms.withdraw;
    return `
      <div class="ej-stats">
        <div class="ej-stat big"><b>${money(d.balance)}</b><span>Compte de l'entreprise</span></div>
        <div class="ej-stat"><b class="pos">+${money(d.income)}</b><span>Entrées (7 jours)</span></div>
        <div class="ej-stat"><b class="neg">−${money(d.expense)}</b><span>Sorties (7 jours)</span></div>
      </div>
      ${canD || canW ? `<div class="ej-card"><div class="ej-grid money">
        <label class="ej-field">Montant ($)<input class="ej-input" id="ejAmount" type="number" min="1" placeholder="0"></label>
        <label class="ej-field">Depuis / vers<select class="ej-input" id="ejAccount"><option value="cash">Liquide (${money(d.cash)})</option><option value="bank">Banque (${money(d.bank)})</option></select></label>
        ${canD ? '<button class="ej-btn primary" data-ej="deposit">Déposer</button>' : ''}${canW ? '<button class="ej-btn" data-ej="withdraw">Retirer</button>' : ''}
      </div></div>` : ''}
      <div class="ej-cols">
        <div><h2>Dépôts et retraits</h2>
          ${d.journal.length ? `<div class="ej-list">${d.journal.map((l) => `<div class="ej-item"><div><b>${l.kind === 'deposit' ? 'Dépôt' : 'Retrait'} · ${esc(l.actor_name || '?')}</b><small>${when(l.t)} · ${esc(l.details || '')}</small></div>
            <span class="${l.kind === 'deposit' ? 'pos' : 'neg'} mono">${l.kind === 'deposit' ? '+' : '−'}${money(l.amount)}</span></div>`).join('')}</div>` : '<div class="ej-empty">Aucune opération.</div>'}</div>
        <div><h2>Mouvements du compte</h2>
          ${d.account.length ? `<div class="ej-list">${d.account.map((l) => `<div class="ej-item"><div><b>${esc(l.reason || 'Opération')}</b><small>${when(l.t)}</small></div>
            <span class="${l.amount >= 0 ? 'pos' : 'neg'} mono">${l.amount >= 0 ? '+' : '−'}${money(Math.abs(l.amount))}</span></div>`).join('')}</div>` : '<div class="ej-empty">Aucun mouvement.</div>'}</div>
      </div>`;
  }

  async function logsTab() {
    const d = await call('logs', { kind: S.logKind });
    if (d.error) return `<div class="ej-empty">${esc(d.error)}</div>`;
    const chips = [['', 'Tout'], ['hr', 'Équipe'], ['money', 'Argent'], ['duty', 'Service']];
    return `<div class="ej-chips">${chips.map((c) => `<button class="${S.logKind === c[0] ? 'on' : ''}" data-ej="logKind" data-kind="${c[0]}">${c[1]}</button>`).join('')}</div>
      ${d.list.length ? `<div class="ej-table-wrap"><table class="ej-table"><thead><tr><th>Date</th><th>Action</th><th>Par</th><th>Concerne</th><th>Détail</th></tr></thead><tbody>
        ${d.list.map((l) => `<tr><td class="mono">${when(l.t)}</td><td>${esc(l.label)}</td><td>${esc(l.actor_name || '—')}</td><td>${esc(l.target_name || '—')}</td>
          <td>${l.amount != null ? `<span class="mono">${money(l.amount)}</span> ` : ''}${esc(l.details || '')}</td></tr>`).join('')}</tbody></table></div>` : '<div class="ej-empty">Rien pour l\'instant.</div>'}`;
  }

  /* ---------- Rendu ---------- */
  async function render(keep) {
    if (!S.el) return;
    const top = keep ? S.el.scrollTop : 0;
    if (!keep) S.el.innerHTML = '<div class="ej-empty">Chargement…</div>';
    const t = await loadTeam();
    if (t.error) { S.el.innerHTML = `<div class="ej-empty">${esc(t.error)}</div>`; return; }
    const html = S.page === 'boss' ? await bossHtml(t) : teamHtml(t);
    S.el.innerHTML = `<div class="ej-root">${html}</div>`;
    S.el.scrollTop = top;
  }

  function gradeForm() {
    const perms = {};
    S.el.querySelectorAll('.ej-gedit [data-perm]').forEach((c) => { perms[c.dataset.perm] = c.checked; });
    return { name: S.el.querySelector('#ejgName').value.trim(), payment: Number(S.el.querySelector('#ejgPay').value), perms };
  }
  const amount = () => ({ amount: Number(S.el.querySelector('#ejAmount').value), account: S.el.querySelector('#ejAccount').value });

  const ACTS = {
    dutyOn: () => act('duty', { on: true }),
    dutyOff: () => act('duty', { on: false }),
    resign: async () => { if (await confirmBox('Démissionner', `Quitter ${S.team.company.label} ? Vous perdrez votre grade et vos accès.`, true, 'Démissionner')) act('resign'); },
    tab: (b) => { S.tab = b.dataset.tab; S.gradeEdit = null; render(); },
    recruit: () => act('recruit', {}, false),
    setGrade: (b) => { const sel = S.el.querySelector(`[data-grade-for="${CSS.escape(b.dataset.cid)}"]`); act('setGrade', { cid: b.dataset.cid, grade: Number(sel.value) }); },
    specialty: (b) => act('specialty', { cid: b.dataset.cid, spec: b.dataset.spec, on: b.dataset.on === '1' }),
    fire: async (b) => { if (await confirmBox('Licencier', `Licencier ${b.dataset.name} ? Il perdra son emploi immédiatement.`, true, 'Licencier')) act('fire', { cid: b.dataset.cid }); },
    gradeNew: () => { S.gradeEdit = 'new'; render(true); },
    gradeEdit: (b) => { S.gradeEdit = Number(b.dataset.level); render(true); },
    gradeCancel: () => { S.gradeEdit = null; render(true); },
    gradeSave: async () => { const r = await act('saveGrade', { level: S.gradeEdit, ...gradeForm() }, false); if (!r.error) { S.gradeEdit = null; render(true); } },
    gradeCreate: async () => { const r = await act('createGrade', { position: Number(S.el.querySelector('#ejgPos').value), ...gradeForm() }, false); if (!r.error) { S.gradeEdit = null; render(true); } },
    gradeDelete: async (b) => { if (await confirmBox('Supprimer le grade', `Supprimer le grade « ${b.dataset.name} » ?`, true, 'Supprimer')) act('deleteGrade', { level: Number(b.dataset.level) }); },
    deposit: async () => { const a = amount(); if (await confirmBox('Dépôt', `Déposer ${money(a.amount)} sur le compte de l'entreprise ?`)) act('deposit', a); },
    withdraw: async () => { const a = amount(); if (await confirmBox('Retrait', `Retirer ${money(a.amount)} du compte de l'entreprise ?`, true, 'Retirer')) act('withdraw', a); },
    logKind: (b) => { S.logKind = b.dataset.kind; render(true); },
  };

  function onClick(e) {
    const b = e.target.closest('[data-ej]');
    if (!b || b.disabled || !S.el || !S.el.contains(b)) return;
    const fn = ACTS[b.dataset.ej];
    if (fn) fn(b);
  }

  window.EJobs = {
    team: loadTeam,
    canBoss: () => !!(S.team && S.team.boss),
    mount(el, page = 'team', opts = {}) {
      if (S.el !== el) { if (S.el) S.el.removeEventListener('click', onClick); el.addEventListener('click', onClick); }
      S.el = el; S.page = page; S.opts = opts; S.gradeEdit = null;
      el.classList.add('ej-host');
      return render();
    },
    refresh: () => render(true),
    toast,
  };
})();
