/* =====================================================================
   ELYZEA BOÎTE DE NUIT - son des enceintes et platine DJ
   · Son : un lecteur YouTube invisible par boîte entendue (2 au plus). Le jeu
     envoie la vidéo, le moment du titre (heure commune) et le volume selon la
     distance. La page signale la durée du titre et les vidéos refusées.
   · Platine : playlist, lecture, volume, portée, enceintes (même panneau dans
     la tablette › Musique et à la platine, touche E près d'une enceinte).
   ===================================================================== */
(() => {
  /* ------------------------------------------------------------------ */
  /* Son                                                                 */
  /* ------------------------------------------------------------------ */
  const AU = { api: false, loading: false, players: {}, last: [] };
  const box = document.createElement('div');
  box.id = 'audioBox';
  box.setAttribute('aria-hidden', 'true');
  document.body.appendChild(box);

  function ensureApi() {
    if (AU.api || AU.loading || !IN_GAME) return;
    AU.loading = true;
    const sc = document.createElement('script');
    sc.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(sc);
  }
  window.onYouTubeIframeAPIReady = () => { AU.api = true; apply(AU.last); };

  function destroy(k) {
    const a = AU.players[k];
    if (!a) return;
    try { a.p.destroy(); } catch (e) { /* lecteur déjà fermé */ }
    const el = document.getElementById(`au-${k}`); if (el) el.remove();
    delete AU.players[k];
  }
  function sync(a) {
    const c = a.want;
    if (!a.ready || !c) return;
    try {
      const v = Math.round(Math.max(0, Math.min(1, c.vol)) * 100);
      if (v <= 0) a.p.mute(); else { a.p.unMute(); a.p.setVolume(v); }
      const cur = a.p.getCurrentTime ? a.p.getCurrentTime() : 0;
      const st = a.p.getPlayerState ? a.p.getPlayerState() : -1;
      if (Math.abs(cur - c.at) > 2.5) a.p.seekTo(Math.max(0, c.at), true);
      if (c.paused) { if (st !== 2) a.p.pauseVideo(); } else if (st !== 1 && st !== 3) a.p.playVideo();
      const d = a.p.getDuration ? a.p.getDuration() : 0;
      // Durée du titre : envoyée au serveur, puis renvoyée toutes les 30 s (si un envoi s'est perdu)
      if (d > 0 && (a.reported !== a.track || Date.now() - a.reportedAt > 30000)) {
        a.reported = a.track; a.reportedAt = Date.now();
        post('musicReport', { shop: c.shop, track: c.track, duration: Math.floor(d) });
      }
    } catch (e) { /* lecteur pas encore prêt */ }
  }
  function apply(list) {
    AU.last = list || [];
    if (!AU.api) { if (AU.last.length) ensureApi(); return; }
    const keep = new Set(AU.last.map((c) => String(c.shop)));
    Object.keys(AU.players).forEach((k) => { if (!keep.has(k)) destroy(k); });
    AU.last.forEach((c) => {
      const k = String(c.shop);
      let a = AU.players[k];
      if (!a) {
        const el = document.createElement('div'); el.id = `au-${k}`; box.appendChild(el);
        a = AU.players[k] = { ready: false, yt: c.yt, track: c.track, want: c, reported: null, reportedAt: 0, p: null };
        a.p = new YT.Player(el.id, {
          width: '200', height: '113', videoId: c.yt,
          playerVars: { autoplay: 1, controls: 0, disablekb: 1, fs: 0, iv_load_policy: 3, rel: 0, playsinline: 1, start: Math.floor(c.at || 0), origin: location.origin },
          events: {
            onReady: () => { a.ready = true; sync(a); },
            onError: (e) => post('musicReport', { shop: a.want.shop, track: a.track, error: e.data }),
            onStateChange: () => sync(a),
          },
        });
      } else if (a.yt !== c.yt || a.track !== c.track) {
        a.yt = c.yt; a.track = c.track;
        if (a.ready) { try { a.p.loadVideoById({ videoId: c.yt, startSeconds: Math.floor(c.at || 0) }); } catch (e) { /* rien */ } }
      }
      a.want = c;
      sync(a);
    });
  }
  window.ClubAudio = { apply, players: AU.players };

  /* ------------------------------------------------------------------ */
  /* Platine DJ                                                          */
  /* ------------------------------------------------------------------ */
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;
  const mm = (s) => { s = Math.max(0, Math.floor(Number(s) || 0)); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; };
  let timer = null;

  function render(el, d) {
    const st = d.state || {}, cur = (d.tracks || []).find((t) => t.id === st.track);
    const ok = d.canMusic && d.near;
    const off = d.now - Date.now() / 1000;
    const pos = () => (st.paused ? (st.pausedAt || 0) : Math.max(0, Date.now() / 1000 + off - (st.startAt || 0)));
    const dis = ok ? '' : 'disabled';
    el.innerHTML = `
      <div class="dj-now ${st.playing ? 'on' : ''}">
        <div class="dj-disc ${st.playing && !st.paused ? 'spin' : ''}">🪩</div>
        <div class="dj-meta"><small>${st.playing ? (st.paused ? 'En pause' : 'En lecture') : 'Arrêté'}</small><b>${esc(cur ? cur.title : 'Aucun titre')}</b>
          <div class="dj-bar"><i id="djProg" style="width:0%"></i></div><span class="mono faint" id="djTime"></span></div>
      </div>
      ${!d.canMusic ? '<div class="warn-box">Votre grade n\'a pas la permission « Utiliser les enceintes ». Le patron la donne dans Direction › Permissions.</div>'
        : !d.near ? `<div class="warn-box">Approchez-vous des enceintes de la boîte pour piloter la musique${d.speakers.length ? '' : ' (aucune enceinte posée)'}. La playlist se modifie d'ici.</div>` : ''}
      <div class="dj-ctrl">
        <button class="btn" data-dj="prev" ${dis} title="Titre précédent">⏮</button>
        ${st.playing && !st.paused ? `<button class="btn primary big" data-dj="pause" ${dis}>⏸ Pause</button>` : `<button class="btn primary big" data-dj="play" ${dis}>▶ Lecture</button>`}
        <button class="btn" data-dj="next" ${dis} title="Titre suivant">⏭</button>
        <button class="btn danger" data-dj="stop" ${dis} title="Couper">⏹</button>
        <button class="btn ${st.shuffle ? 'on' : ''}" data-dj="shuffle" ${dis} title="Aléatoire">🔀 ${st.shuffle ? 'Aléatoire' : 'Dans l\'ordre'}</button>
        <button class="btn ${st.loop ? 'on' : ''}" data-dj="loop" ${dis} title="Recommencer à la fin">🔁 ${st.loop ? 'En boucle' : 'Une fois'}</button>
      </div>
      <div class="dj-sliders">
        <label class="field"><span>Volume des enceintes : <b id="djVolV">${st.volume}</b> %</span><input type="range" min="0" max="100" value="${st.volume}" data-djs="volume" ${dis}></label>
        <label class="field"><span>Portée du son : <b id="djRangeV">${Math.round(st.range)}</b> m</span><input type="range" min="${d.minRange}" max="${d.maxRange}" value="${Math.round(st.range)}" data-djs="range" ${dis}></label>
      </div>
      <div class="cols"><div>
        <div class="card"><h2>Playlist <span class="faint" style="font-size:.8rem">${d.tracks.length} / ${d.maxTracks}</span></h2>
          ${d.canMusic ? `<textarea class="input" id="djUrls" rows="2" placeholder="Collez un ou plusieurs liens YouTube (un par ligne)"></textarea>
            <div class="actions-row"><button class="btn primary small" data-dj="add">+ Ajouter</button>${d.tracks.length ? '<button class="btn small danger" data-dj="clear">Vider la playlist</button>' : ''}</div>` : ''}
          <div class="dj-list">${d.tracks.map((t, i) => `<div class="list-row ${t.id === st.track ? 'cur' : ''}"><span class="mono faint">${i + 1}</span>
            <div class="main"><b>${esc(t.title)}</b><small class="mono">${t.duration ? mm(t.duration) : 'durée inconnue'}${t.broken ? ' · <span style="color:#fca5a5">refusée par YouTube (sautée)</span>' : ''}</small></div>
            ${d.canMusic ? `<button class="btn small" data-djt="play" data-id="${t.id}" ${dis} title="Lire">▶</button><button class="btn small" data-djt="up" data-id="${t.id}" title="Monter">↑</button>
              <button class="btn small" data-djt="down" data-id="${t.id}" title="Descendre">↓</button><button class="btn small danger" data-djt="del" data-id="${t.id}" title="Retirer">✕</button>` : ''}</div>`).join('') || empty('Playlist vide : collez des liens YouTube.')}</div></div>
      </div><div>
        <div class="card"><h2>Enceintes de la boîte <span class="faint" style="font-size:.8rem">${d.speakers.length} / ${d.maxSpeakers}</span></h2>
          ${d.speakers.map((s) => `<div class="list-row"><span class="ico">🔊</span><div class="main"><b>${esc(s.label)}</b><small class="mono">#${s.id} · ${s.x.toFixed(1)}, ${s.y.toFixed(1)}, ${s.z.toFixed(1)}</small></div>
            ${d.canSpeakers ? `<button class="btn small danger" data-djsp="${s.id}">Retirer</button>` : ''}</div>`).join('') || empty('Aucune enceinte : la musique ne s\'entend nulle part.')}
          ${d.canSpeakers ? `<div class="stack" style="margin-top:.7rem"><label class="field"><span>Modèle</span><select class="input" id="djModel">${d.models.map((m) => `<option value="${esc(m.model)}">${esc(m.label)}</option>`).join('')}</select></label>
            <button class="btn primary" data-dj="place" ${d.speakers.length >= d.maxSpeakers ? 'disabled' : ''}>🔊 Poser une enceinte</button>
            <p class="faint" style="font-size:.76rem">L'enceinte suit votre regard : clic gauche ou Entrée pour la poser, A / E pour la tourner, Retour pour annuler. Seule votre boîte peut l'utiliser.</p></div>`
            : '<p class="faint" style="font-size:.78rem;margin-top:.5rem">Poser des enceintes demande la permission « Poser et retirer les enceintes ».</p>'}
        </div>
      </div></div>`;
    clearInterval(timer);
    const tick = () => {
      const p = $('#djProg', el), tm = $('#djTime', el);
      if (!p || !tm) return clearInterval(timer);
      const now = st.playing ? pos() : 0, total = cur ? cur.duration : 0;
      p.style.width = total ? `${Math.min(100, now / total * 100)}%` : '0%';
      tm.textContent = st.playing ? `${mm(now)}${total ? ` / ${mm(total)}` : ''}` : '';
    };
    tick();
    timer = setInterval(tick, 1000);
  }

  const DJ = { el: null, data: null };
  async function run(action, data, btn) {
    const r = await act(req(action, data || {}), btn);
    if (r && r.tracks) { DJ.data = r; render(DJ.el, r); } else if (r && r.ok) { const v = await req('music'); if (!v.error) { DJ.data = v; render(DJ.el, v); } }
    return r;
  }
  function wire(el) {
    el.addEventListener('click', async (e) => {
      let b;
      if ((b = e.target.closest('[data-dj]'))) {
        const a = b.dataset.dj, st = DJ.data.state;
        if (a === 'play') return run('musicPlay', {}, b);
        if (a === 'pause') return run('musicPause', {}, b);
        if (a === 'next') return run('musicNext', { dir: 1 }, b);
        if (a === 'prev') return run('musicNext', { dir: -1 }, b);
        if (a === 'stop') return run('musicStop', {}, b);
        if (a === 'shuffle') return run('musicSet', { shuffle: !st.shuffle }, b);
        if (a === 'loop') return run('musicSet', { loop: !st.loop }, b);
        if (a === 'add') {
          const urls = (($('#djUrls', el) || {}).value || '').split(/\s+/).map((x) => x.trim()).filter(Boolean);
          if (!urls.length) return toast('Collez au moins un lien YouTube.', false);
          return run('musicAdd', { urls: urls.slice(0, 50) }, b);
        }
        if (a === 'clear') { if (!(await confirmBox('Vider la playlist ?', 'Tous les titres sont retirés et la musique s\'arrête.', 'Vider', true))) return; return run('musicClear', {}, b); }
        if (a === 'place') return post('placeSpeaker', { model: ($('#djModel', el) || {}).value || '' });
      }
      if ((b = e.target.closest('[data-djt]'))) {
        const id = Number(b.dataset.id), a = b.dataset.djt;
        if (a === 'play') return run('musicPlay', { track: id }, b);
        if (a === 'up' || a === 'down') return run('musicMove', { track: id, dir: a === 'up' ? -1 : 1 }, b);
        if (a === 'del') return run('musicRemove', { track: id }, b);
      }
      if ((b = e.target.closest('[data-djsp]'))) {
        if (!(await confirmBox('Retirer l\'enceinte ?', 'Elle disparaît pour tout le monde.', 'Retirer', true))) return;
        return run('speakerRemove', { id: Number(b.dataset.djsp) }, b);
      }
    });
    el.addEventListener('input', (e) => {
      const t = e.target;
      if (t.dataset.djs === 'volume') { const v = $('#djVolV', el); if (v) v.textContent = t.value; }
      if (t.dataset.djs === 'range') { const v = $('#djRangeV', el); if (v) v.textContent = t.value; }
    });
    el.addEventListener('change', (e) => {
      const t = e.target;
      if (t.dataset.djs) run('musicSet', { [t.dataset.djs]: Number(t.value) });
    });
  }

  // Panneau autonome (platine) et page de la tablette
  const modal = $('#dj');
  const inner = $('#djBody');
  wire(inner);
  window.Dj = {
    mount(el, d, inTablet) {
      if (inTablet) { DJ.el = el; DJ.data = d; wire(el); render(el, d); return; }
      DJ.el = inner; DJ.data = d; render(inner, d);
    },
    open(d) { modal.classList.remove('hidden'); this.mount(inner, d, false); },
    hide() { modal.classList.add('hidden'); clearInterval(timer); },
    isOpen: () => !modal.classList.contains('hidden'),
  };
  $('#djClose').addEventListener('click', () => post('close', { ui: 'dj' }));
})();
