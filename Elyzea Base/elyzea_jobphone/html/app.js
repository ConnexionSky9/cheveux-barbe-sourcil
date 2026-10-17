/* =====================================================================
   ELYZEA - Téléphone de service des métiers (NUI)
   Hors service : seules l'identité et la prise de service sont accessibles.
   En service : annuaire, messages, appels, carte, alertes, tablette, menu.
   ===================================================================== */
(() => {
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_jobphone';
  const $ = (s) => document.querySelector(s);
  const screen = $('#screen');
  const S = { open: false, job: null, map: null, levels: {}, home: null, view: 'home', stack: [], call: null, timers: [], thread: null, mapState: null };

  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const initials = (n) => String(n || '?').split(/\s+/).map((p) => p[0] || '').join('').slice(0, 2).toUpperCase();
  const dur = (s) => { s = Math.max(0, Math.floor(s || 0)); const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60); return `${h} h ${String(m).padStart(2, '0')}`; };
  const hhmm = (t) => { const d = new Date((t || 0) * 1000); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
  const ago = (t) => { const s = Math.max(0, Math.floor(Date.now() / 1000 - (t || 0))); return s < 60 ? `${s} s` : s < 3600 ? `${Math.floor(s / 60)} min` : `${Math.floor(s / 3600)} h`; };
  const LIFE = { ok: ['En forme', 'life-ok', '#22c55e'], hurt: ['Blessé', 'life-hurt', '#f59e0b'], down: ['À terre', 'life-down', '#fb923c'], dead: ['Mort', 'life-dead', '#ef4444'] };

  async function post(name, data) {
    try {
      const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) });
      return await r.json();
    } catch (e) { return { error: 'Téléphone indisponible.' }; }
  }
  const req = (action, data) => post('req', { action, data });

  let toastT = 0;
  function toast(msg, kind) {
    const t = $('#toast');
    t.textContent = msg; t.className = `toast ${kind || ''}`;
    clearTimeout(toastT); toastT = setTimeout(() => t.classList.add('hidden'), 2600);
  }
  function result(r, okMsg) {
    if (!r) return false;
    if (r.error) { toast(r.error, 'err'); return false; }
    if (r.message || okMsg) toast(r.message || okMsg, 'ok');
    return true;
  }

  function clearTimers() { S.timers.forEach(clearInterval); S.timers = []; if (S.mapState) { cancelAnimationFrame(S.mapState.raf); S.mapState = null; } }
  function go(view, arg, push = true) {
    clearTimers();
    if (push && S.view !== view) S.stack.push([S.view, S.arg]);
    S.view = view; S.arg = arg;
    (VIEWS[view] || VIEWS.home)(arg);
  }
  function back() { const p = S.stack.pop(); if (p) go(p[0], p[1], false); else go('home', null, false); }
  function header(title, extra = '') { return `<div class="head"><button class="back" data-back>‹</button><h1>${esc(title)}</h1>${extra}</div>`; }
  function wire() { screen.querySelectorAll('[data-back]').forEach((b) => (b.onclick = back)); }

  // ------------------------------------------------------------------
  // Accueil
  // ------------------------------------------------------------------
  const APPS = [
    { id: 'service', icon: '🪪', label: 'Service', free: true },
    { id: 'directory', icon: '📇', label: 'Annuaire' },
    { id: 'threads', icon: '💬', label: 'Messages' },
    { id: 'dialer', icon: '📞', label: 'Appels' },
    { id: 'map', icon: '🗺️', label: 'Collègues' },
    { id: 'alerts', icon: '🚨', label: 'Alertes' },
    { id: 'tablet', icon: '💼', label: 'Tablette' },
    { id: 'menu', icon: '⚡', label: 'Menu rapide' },
  ];

  async function loadHome() {
    const r = await req('home');
    if (r.error) { toast(r.error, 'err'); return null; }
    S.home = r;
    if (r.job && r.job.color) setAccent(r.job.color);   // couleur de l'agence (elyzea_agences)
    $('#sb-duty').classList.toggle('on', !!r.me.duty);
    return r;
  }

  const VIEWS = {};
  VIEWS.home = async () => {
    const h = S.home || (await loadHome());
    if (!h) { screen.innerHTML = '<div class="empty">Téléphone indisponible.</div>'; return; }
    const me = h.me, on = !!me.duty;
    const lockedApp = (a) => (!a.free && !on) || (a.id === 'tablet' && !me.tablet);
    screen.innerHTML = `
      <div class="idcard">
        <div class="org">${esc(h.job.label)}${me.unit && me.unit !== h.job.label ? ' · ' + esc(me.unit) : ''}</div>
        <div class="nm">${esc(me.name)}</div>
        <div class="sub">${esc(me.grade)} · Matricule ${esc(me.matricule)}</div>
        <div class="num">📱 ${esc(me.number || '—')} · <span class="${on ? 'life-ok' : ''}">${on ? 'En service' : 'Hors service'}</span></div>
      </div>
      <div class="grid">${APPS.map((a) => `
        <div class="app ${lockedApp(a) ? 'locked' : ''}" data-app="${a.id}">
          <div class="ic">${a.icon}</div><span>${a.label}</span>
          ${lockedApp(a) ? '<i class="lock">🔒</i>' : ''}
          ${a.id === 'threads' && on && h.unread ? `<i class="badge">${h.unread}</i>` : ''}
        </div>`).join('')}
      </div>
      ${on ? '' : '<div class="offnote">Hors service : prenez votre service dans l\'application « Service » pour déverrouiller le téléphone.</div>'}`;
    screen.querySelectorAll('[data-app]').forEach((el) => (el.onclick = () => {
      const a = APPS.find((x) => x.id === el.dataset.app);
      if (a.id === 'tablet' && !me.tablet) return toast('Votre grade ne donne pas accès à la tablette.', 'err');
      if (lockedApp(a)) return toast('Disponible uniquement en service.', 'err');
      if (a.id === 'tablet' || a.id === 'menu') return req(a.id).then((r) => result(r));
      go(a.id);
    }));
  };

  // ------------------------------------------------------------------
  // Service : identité, prise / fin de service, temps
  // ------------------------------------------------------------------
  VIEWS.service = async () => {
    const h = await loadHome();
    if (!h) return back();
    const me = h.me;
    let session = me.times?.session || 0, total = me.times?.total || 0;
    screen.innerHTML = `${header('Service')}
      <div class="body">
        <div class="idcard">
          <div class="org">${esc(h.job.label)}</div>
          <div class="nm">${esc(me.name)}</div>
          <div class="sub">${esc(me.grade)} · Matricule ${esc(me.matricule)}</div>
          <div class="num">Numéro pro : ${esc(me.number || '—')}</div>
        </div>
        <button class="btn ${me.duty ? 'off' : ''}" id="dutyBtn" ${!me.duty && !me.canDuty ? 'disabled' : ''}>${me.duty ? 'Terminer mon service' : 'Prendre mon service'}</button>
        ${!me.duty && !me.canDuty ? '<div class="empty">Votre grade ne permet pas de prendre le service.</div>' : ''}
        <div class="section">Temps de service</div>
        <div class="stat"><span>Session en cours</span><b id="tSes">${dur(session)}</b></div>
        <div class="stat"><span>Total cumulé</span><b id="tTot">${dur(total)}</b></div>
      </div>`;
    wire();
    $('#dutyBtn').onclick = async () => {
      $('#dutyBtn').disabled = true;
      const r = await req('duty', { on: !me.duty });
      result(r);
      S.home = null;
      go('service', null, false);
    };
    if (me.duty) S.timers.push(setInterval(() => { session++; total++; const a = $('#tSes'), b = $('#tTot'); if (a) a.textContent = dur(session); if (b) b.textContent = dur(total); }, 1000));
  };

  // ------------------------------------------------------------------
  // Annuaire (mis à jour automatiquement par le serveur)
  // ------------------------------------------------------------------
  VIEWS.directory = async () => {
    screen.innerHTML = `${header('Annuaire')}<input class="field" id="q" placeholder="Rechercher un collègue…"><div class="body" id="dir" style="margin-top:8px"><div class="empty">Chargement…</div></div>`;
    wire(); typingWire();
    const r = await req('directory');
    if (r.error) return toast(r.error, 'err');
    const draw = () => {
      const q = ($('#q')?.value || '').toLowerCase();
      const list = r.list.filter((e) => !q || `${e.name} ${e.grade} ${e.number} ${e.matricule}`.toLowerCase().includes(q));
      const box = $('#dir'); if (!box) return;
      box.innerHTML = list.length ? list.map((e) => `
        <div class="row">
          <div class="av">${esc(initials(e.name))}</div>
          <div class="tx"><div class="t1"><i class="dot ${e.duty ? 'duty' : e.online ? 'online' : ''}"></i>${esc(e.name)}${e.me ? ' (vous)' : ''}</div>
          <div class="t2">${esc(e.grade)} · ${esc(e.number || '—')} · ${e.duty ? 'En service' : e.online ? 'Hors service' : 'Hors ligne'}</div></div>
          ${e.me ? '' : `<div class="act"><button class="ib" data-msg="${esc(e.cid)}" data-name="${esc(e.name)}" title="Message">💬</button>
          <button class="ib green" data-call="${esc(e.cid)}" ${e.duty ? '' : 'disabled'} title="Appeler">📞</button></div>`}
        </div>`).join('') : '<div class="empty">Aucun collègue.</div>';
      box.querySelectorAll('[data-msg]').forEach((b) => (b.onclick = () => go('chat', { with: b.dataset.msg, name: b.dataset.name })));
      box.querySelectorAll('[data-call]').forEach((b) => (b.onclick = () => startCall({ cid: b.dataset.call })));
    };
    $('#q').oninput = draw;
    draw();
  };

  // ------------------------------------------------------------------
  // Messages : canal de l'entreprise + conversations privées
  // ------------------------------------------------------------------
  VIEWS.threads = async () => {
    screen.innerHTML = `${header('Messages')}<div class="body" id="th"><div class="empty">Chargement…</div></div>`;
    wire();
    const r = await req('threads');
    if (r.error) return toast(r.error, 'err');
    const box = $('#th'); if (!box) return;
    box.innerHTML = r.list.map((t) => `
      <div class="row" data-with="${esc(t.key)}" data-name="${esc(t.name)}" style="cursor:pointer">
        <div class="av">${t.group ? '👥' : esc(initials(t.name))}</div>
        <div class="tx"><div class="t1">${esc(t.name)}</div><div class="t2">${esc(t.last || 'Aucun message')}</div></div>
        ${t.unread ? `<span class="unread">${t.unread}</span>` : `<span class="t2">${t.t ? hhmm(t.t) : ''}</span>`}
      </div>`).join('') + '<div class="empty">Nouvelle conversation : passez par l\'annuaire.</div>';
    box.querySelectorAll('[data-with]').forEach((el) => (el.onclick = () => go('chat', { with: el.dataset.with, name: el.dataset.name })));
  };

  VIEWS.chat = async (arg) => {
    S.thread = arg.with;
    screen.innerHTML = `${header(arg.name)}<div class="chat" id="chat"><div class="empty">Chargement…</div></div>
      <div class="compose"><input id="msg" maxlength="300" placeholder="Message…"><button class="ib green" id="send">➤</button></div>`;
    wire(); typingWire();
    const draw = async () => {
      const r = await req('messages', { with: arg.with });
      const box = $('#chat'); if (!box || S.view !== 'chat') return;
      if (r.error) return toast(r.error, 'err');
      box.innerHTML = r.list.length ? r.list.map((m) => `<div class="bubble ${m.mine ? 'mine' : ''}"><div class="who">${m.mine ? 'Vous' : esc(m.from)} · ${hhmm(m.t)}</div>${esc(m.body)}</div>`).join('')
        : '<div class="empty">Aucun message.</div>';
      box.scrollTop = box.scrollHeight;
    };
    S.redrawChat = draw;
    const send = async () => {
      const i = $('#msg'); const body = i.value.trim(); if (!body) return;
      i.value = '';
      const r = await req('send', { with: arg.with, body });
      if (result(r)) draw();
    };
    $('#send').onclick = send;
    $('#msg').onkeydown = (e) => { if (e.key === 'Enter') send(); };
    draw();
  };

  // ------------------------------------------------------------------
  // Appels (pma-voice) : numéro pro ou collègue en service
  // ------------------------------------------------------------------
  VIEWS.dialer = async () => {
    screen.innerHTML = `${header('Appels')}
      <div class="dial"><input class="field" id="num" placeholder="Numéro pro (ex. 913-0421)"><button class="ib green" id="dialBtn">📞</button></div>
      <div class="section">Collègues en service</div><div class="body" id="crew"><div class="empty">Chargement…</div></div>`;
    wire(); typingWire();
    $('#dialBtn').onclick = () => { const n = $('#num').value.trim(); if (n) startCall({ number: n }); };
    const r = await req('directory');
    const box = $('#crew'); if (!box) return;
    const list = (r.list || []).filter((e) => e.duty && !e.me);
    box.innerHTML = list.length ? list.map((e) => `
      <div class="row"><div class="av">${esc(initials(e.name))}</div>
      <div class="tx"><div class="t1">${esc(e.name)}</div><div class="t2">${esc(e.grade)} · ${esc(e.number)}</div></div>
      <button class="ib green" data-call="${esc(e.cid)}">📞</button></div>`).join('') : '<div class="empty">Aucun collègue en service.</div>';
    box.querySelectorAll('[data-call]').forEach((b) => (b.onclick = () => startCall({ cid: b.dataset.call })));
  };

  async function startCall(target) {
    const r = await req('call', target);
    if (!result(r)) return;
    S.call = r.call;
    go('call');
  }

  VIEWS.call = () => {
    const c = S.call;
    if (!c) return back();
    const st = c.state === 'incoming' ? 'Appel entrant…' : c.state === 'outgoing' ? 'Appel en cours…' : 'En communication';
    screen.innerHTML = `<div class="callscreen">
      <div class="big">${esc(initials(c.name))}</div><div class="nm">${esc(c.name)}</div><div class="st">${esc(c.number || '')}</div>
      <div class="st" id="cst">${st}</div>
      <div class="callbtns">${c.state === 'incoming' ? '<button class="ib green" id="ans">📞</button>' : ''}<button class="ib red" id="hang">✕</button></div>
    </div>`;
    if ($('#ans')) $('#ans').onclick = async () => { const r = await req('answer', { id: c.id }); result(r); };
    $('#hang').onclick = async () => { await req('hangup'); S.call = null; callbar(); back(); };
    if (c.state === 'active') {
      const t0 = Date.now();
      S.timers.push(setInterval(() => { const e = $('#cst'); if (e) e.textContent = `En communication · ${Math.floor((Date.now() - t0) / 60000)}:${String(Math.floor(((Date.now() - t0) / 1000) % 60)).padStart(2, '0')}`; }, 1000));
    }
  };

  function callbar() {
    const b = $('#callbar');
    if (S.call && S.view !== 'call') {
      b.textContent = S.call.state === 'incoming' ? `📞 Appel de ${S.call.name} — toucher pour répondre` : `📞 ${S.call.name} · ${S.call.state === 'active' ? 'en ligne' : 'appel…'}`;
      b.classList.remove('hidden');
      b.onclick = () => go('call');
    } else b.classList.add('hidden');
  }

  // ------------------------------------------------------------------
  // Carte des collègues en service + santé réelle
  // ------------------------------------------------------------------
  VIEWS.map = async () => {
    screen.innerHTML = `${header('Collègues')}<div class="map" id="mapbox"></div>
      <div class="legend"><span class="life-ok">● En forme</span><span class="life-hurt">● Blessé</span><span class="life-down">● À terre</span><span class="life-dead">● Mort</span></div>
      <div class="body" id="mlist"></div>`;
    wire();
    const M = createMap($('#mapbox'));
    const load = async () => {
      if (S.view !== 'map') return;
      const r = await req('map');
      if (r.error) return toast(r.error, 'err');
      M.set(r.list);
      const box = $('#mlist'); if (!box) return;
      box.innerHTML = r.list.map((a) => {
        const L = LIFE[a.health?.life] || LIFE.ok;
        return `<div class="row" data-x="${a.x}" data-y="${a.y}" style="cursor:pointer"><div class="av">${esc(initials(a.name))}</div>
          <div class="tx"><div class="t1">${esc(a.name)}${a.me ? ' (vous)' : ''}</div><div class="t2">${esc(a.grade)} · <span class="${L[1]}">${L[0]}</span> · ${a.health?.hp ?? '?'} %</div></div>
          ${a.me ? '' : '<button class="ib" title="GPS">📍</button>'}</div>`;
      }).join('') || '<div class="empty">Personne en service.</div>';
      box.querySelectorAll('[data-x]').forEach((el) => (el.onclick = () => { M.focus(+el.dataset.x, +el.dataset.y); if (el.querySelector('.ib')) post('waypoint', { x: el.dataset.x, y: el.dataset.y }); }));
    };
    load();
    S.timers.push(setInterval(load, Math.max(1500, S.map?.refresh || 3000)));
  };

  function createMap(box) {
    const cv = document.createElement('canvas'); box.appendChild(cv);
    const ctx = cv.getContext('2d');
    const B = S.map || { minX: -5661.2, maxX: 6694.0, minY: -4058.5, maxY: 8429.3 };
    const st = { cx: 0, cy: 1500, scale: 0.03, list: [], img: null, raf: 0 };
    S.mapState = st;
    if (B.image) { const im = new Image(); im.onload = () => (st.img = im); im.src = B.image; }
    const r = box.getBoundingClientRect(); const W = r.width, H = r.height, dpr = window.devicePixelRatio || 1;
    cv.width = W * dpr; cv.height = H * dpr; ctx.scale(dpr, dpr);
    st.scale = Math.min(W / 8800, H / 12400);
    const sx = (x) => (x - st.cx) * st.scale + W / 2, sy = (y) => -(y - st.cy) * st.scale + H / 2;
    let drag = null;
    cv.onmousedown = (e) => (drag = { x: e.clientX, y: e.clientY, cx: st.cx, cy: st.cy });
    window.addEventListener('mouseup', () => (drag = null));
    cv.onmousemove = (e) => { if (!drag) return; st.cx = drag.cx - (e.clientX - drag.x) / st.scale; st.cy = drag.cy + (e.clientY - drag.y) / st.scale; };
    cv.onwheel = (e) => { e.preventDefault(); st.scale = Math.max(0.01, Math.min(0.6, st.scale * (e.deltaY < 0 ? 1.2 : 1 / 1.2))); };
    function draw() {
      ctx.fillStyle = '#0a1a2c'; ctx.fillRect(0, 0, W, H);
      if (st.img) ctx.drawImage(st.img, sx(B.minX), sy(B.maxY), (B.maxX - B.minX) * st.scale, (B.maxY - B.minY) * st.scale);
      else {
        ctx.strokeStyle = 'rgba(255,255,255,.05)';
        for (let g = -6000; g <= 9000; g += 1000) { ctx.beginPath(); ctx.moveTo(sx(g), 0); ctx.lineTo(sx(g), H); ctx.moveTo(0, sy(g)); ctx.lineTo(W, sy(g)); ctx.stroke(); }
      }
      const pulse = (Math.sin(performance.now() / 300) + 1) / 2;
      st.list.forEach((a) => {
        const L = LIFE[a.health?.life] || LIFE.ok;
        const x = sx(a.x), y = sy(a.y);
        if (a.health?.life !== 'ok') { ctx.beginPath(); ctx.fillStyle = L[2] + '55'; ctx.arc(x, y, 7 + pulse * 6, 0, Math.PI * 2); ctx.fill(); }
        ctx.beginPath(); ctx.fillStyle = L[2]; ctx.strokeStyle = a.me ? '#fff' : '#0b1020'; ctx.lineWidth = 2;
        ctx.arc(x, y, 6, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
        ctx.fillStyle = '#fff'; ctx.font = '600 10px Segoe UI'; ctx.textAlign = 'center';
        ctx.fillText(a.me ? 'Vous' : a.name.split(' ')[0], x, y - 10);
      });
      st.raf = requestAnimationFrame(draw);
    }
    draw();
    return {
      set(list) {
        const first = !st.list.length && list.length;
        st.list = list;
        const me = list.find((a) => a.me);
        if (first && me) { st.cx = me.x; st.cy = me.y; st.scale = 0.12; }
      },
      focus(x, y) { st.cx = x; st.cy = y; st.scale = Math.max(st.scale, 0.15); },
    };
  }

  // ------------------------------------------------------------------
  // Alertes faible / moyenne / urgente (système du métier réutilisé)
  // ------------------------------------------------------------------
  VIEWS.alerts = async () => {
    const L = S.levels || {};
    screen.innerHTML = `${header('Alertes')}
      <div class="lvls">${['low', 'medium', 'high'].filter((k) => L[k]).map((k) => `<button class="lvl" data-lvl="${k}" style="background:${L[k].color}">${esc(L[k].label)}<small>${esc(L[k].text)}</small></button>`).join('')}</div>
      <div class="section">Alertes en cours</div><div class="body" id="al"><div class="empty">Chargement…</div></div>`;
    wire();
    screen.querySelectorAll('[data-lvl]').forEach((b) => (b.onclick = async () => {
      b.disabled = true;
      const r = await req('alert', { level: b.dataset.lvl });
      result(r, 'Alerte envoyée.');
      b.disabled = false;
      load();
    }));
    const load = async () => {
      if (S.view !== 'alerts') return;
      const r = await req('alerts');
      const box = $('#al'); if (!box) return;
      if (r.error) { box.innerHTML = `<div class="empty">${esc(r.error)}</div>`; return; }
      box.innerHTML = r.list.length ? r.list.map((a) => `
        <div class="row" style="border-left:3px solid ${L[a.level]?.color || '#888'}">
          <div class="tx"><div class="t1">${esc(L[a.level]?.label || a.level)} · ${esc(a.author || '?')}</div><div class="t2">${esc(a.street || '?')} · il y a ${ago(a.t)}</div></div>
          <div class="act">${a.x != null ? `<button class="ib" data-gps="${a.x},${a.y}" title="GPS">📍</button>` : ''}<button class="ib red" data-close="${a.id}" title="Clôturer">✓</button></div>
        </div>`).join('') : '<div class="empty">Aucune alerte en cours.</div>';
      box.querySelectorAll('[data-gps]').forEach((b) => (b.onclick = () => { const [x, y] = b.dataset.gps.split(','); post('waypoint', { x, y }); }));
      box.querySelectorAll('[data-close]').forEach((b) => (b.onclick = async () => { const r2 = await req('alertClose', { id: +b.dataset.close }); result(r2); load(); }));
    };
    S.reloadAlerts = load;
    load();
    S.timers.push(setInterval(load, 10000));
  };

  // ------------------------------------------------------------------
  // Saisie : le clavier passe au téléphone uniquement pendant l'écriture
  // ------------------------------------------------------------------
  function typingWire() {
    screen.querySelectorAll('input').forEach((i) => {
      i.addEventListener('focus', () => post('typing', { on: true }));
      i.addEventListener('blur', () => post('typing', { on: false }));
    });
  }

  // ------------------------------------------------------------------
  // Messages du client
  // ------------------------------------------------------------------
  function setAccent(color) {
    const c = color || '#3b82f6';
    const n = parseInt(c.slice(1), 16), r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    const mix = (k) => `rgb(${Math.round(r * k + 27 * (1 - k))},${Math.round(g * k + 34 * (1 - k))},${Math.round(b * k + 51 * (1 - k))})`;
    document.documentElement.style.setProperty('--accent', c);
    document.documentElement.style.setProperty('--accent-soft', mix(0.5));
    document.documentElement.style.setProperty('--accent-bg', mix(0.45));
  }

  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.action === 'open') {
      S.open = true; S.job = d.job; S.map = d.map; S.levels = d.levels || {}; S.home = null; S.stack = [];
      if (d.call && !S.call) S.call = d.call;
      setAccent(d.job?.color);
      $('#phone').classList.remove('hidden');
      go(S.call ? 'call' : 'home', null, false);
      callbar();
    } else if (d.action === 'close') {
      S.open = false; clearTimers();
      $('#phone').classList.add('hidden');
      if (document.activeElement) document.activeElement.blur();
    } else if (d.action === 'push') {
      if (!S.open) return;
      if (d.what === 'home') { S.home = null; if (S.view === 'home' || S.view === 'service') go(S.view, null, false); }
      else if (d.what === 'directory' && (S.view === 'directory' || S.view === 'dialer')) go(S.view, null, false);
      else if (d.what === 'alerts' && S.view === 'alerts' && S.reloadAlerts) S.reloadAlerts();
    } else if (d.action === 'message') {
      if (S.home) S.home.unread = (S.home.unread || 0) + 1;
      if (!S.open) return;
      const m = d.msg || {};
      if (S.view === 'chat' && S.thread === (m.with === 'group' ? 'group' : m.fromCid) && S.redrawChat) S.redrawChat();
      else { toast(`💬 ${m.from} : ${m.body}`); if (S.view === 'threads') go('threads', null, false); if (S.view === 'home') go('home', null, false); }
    } else if (d.action === 'call') {
      const c = d.call || {};
      if (c.state === 'ended') { if (S.call && S.call.id === c.id) { S.call = null; if (S.open && S.view === 'call') back(); toast(`Appel terminé (${c.reason || 'raccroché'}).`); } }
      else { S.call = c; if (S.open && (S.view === 'call' || c.state === 'incoming')) go('call', null, S.view !== 'call'); }
      if (S.open) callbar();
    }
  });

  $('#homebar').onclick = () => { S.stack = []; go('home', null, false); };
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') post('close');
  });
  const tick = () => { const d = new Date(); $('#clock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
  tick(); setInterval(tick, 1000);
})();
