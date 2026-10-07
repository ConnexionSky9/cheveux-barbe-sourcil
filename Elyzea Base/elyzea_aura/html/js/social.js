'use strict';
/* =========================================================
   BIRDY · INSTAPICK · ITOUNE
   ========================================================= */
const Accounts = {};
async function ensureAccount(app, render) {
  if (Accounts[app] === undefined) {
    const r = await api('getAccount', { app });
    Accounts[app] = r.account || null;
  }
  if (Accounts[app]) return Accounts[app];
  const ic = APP_ICONS[app];
  frame({ title: APPS[app].label, body: `<div class="onboard">${storeTile(app, 78)}
      <h2 class="onboard__title">${t('Bienvenue sur {app}', { app: APPS[app].label })}</h2>
      <p class="onboard__text">${t(STORE[app].tagline)} ${t('Choisissez comment on vous reconnaîtra.')}</p>
      <div class="form" style="width:100%">
        <input class="field" id="acc-display" maxlength="40" placeholder="${t('Nom affiché')}" value="${esc(S.profile?.name || '')}">
        <div class="handle-field"><span>@</span><input class="field" id="acc-user" maxlength="20" placeholder="${t('identifiant')}" autocomplete="off"></div>
        <p class="error-text" id="acc-err"></p>
        <button class="btn btn--block" id="acc-go" style="background:linear-gradient(135deg,${ic.c1},${ic.c2});color:#fff">${t('Créer mon compte')}</button></div></div>` });
  $('#acc-go').onclick = async () => {
    const r = await api('createAccount', { app, username: $('#acc-user').value, display: $('#acc-display').value });
    if (!r.ok) { $('#acc-err').textContent = t(r.error || 'Création impossible.'); return; }
    Accounts[app] = r.account; render();
  };
  return null;
}
const richText = (s) => esc(s).replace(/@([\w.]+)/g, '<span class="mention">@$1</span>');

function commentsSheet(postId, onAdded) {
  openSheet(t('Commentaires'), `<div class="comments" id="cm-list">${loading()}</div>
    <div class="composer" style="margin-top:12px"><input class="field" id="cm-input" maxlength="200" placeholder="${t('Ajouter un commentaire')}">
    <button class="icon-btn icon-btn--accent" id="cm-send" aria-label="${t('Publier')}">${icon('send')}</button></div>`, (sh) => {
    const load = async () => {
      const r = await api('getComments', { id: postId });
      const list = r.comments || [];
      $('#cm-list', sh).innerHTML = list.length ? list.map(c => `<div class="comment">${avatar(c.display_name, c.username)}
        <div><p><b>${esc(c.display_name)}</b> <span class="row__sub">@${esc(c.username)}, ${timeAgo(c.ts)}</span></p><p style="margin-top:2px;line-height:1.4">${richText(c.content)}</p></div></div>`).join('')
        : `<p class="row__sub" style="text-align:center;padding:24px 0">${t('Aucun commentaire pour l\'instant.')}</p>`;
    };
    const send = async () => {
      const i = $('#cm-input', sh); if (!i.value.trim()) return;
      const r = await api('addComment', { id: postId, content: i.value });
      if (r.ok) { i.value = ''; load(); onAdded?.(); }
    };
    $('#cm-send', sh).onclick = send;
    $('#cm-input', sh).onkeydown = (e) => { if (e.key === 'Enter') send(); };
    load();
  });
}
function wireLikes(root) {
  $$('[data-like]', root).forEach(b => b.onclick = async () => {
    const r = await api('likePost', { id: +b.dataset.like });
    if (!r.ok) return;
    $$(`[data-like="${b.dataset.like}"]`, root).forEach(x => {
      const n = x.querySelector('span'); n.textContent = Math.max(0, +n.textContent + (r.liked ? 1 : -1));
      x.classList.toggle('liked', r.liked); x.setAttribute('aria-pressed', r.liked);
    });
  });
}

/* ---------- Birdy ---------- */
Views.birdy = async ({ tab = 'feed' } = {}) => {
  frame({ title: 'Birdy', body: loading() });
  const acc = await ensureAccount('birdy', () => Views.birdy({ tab }));
  if (!acc || S.currentApp !== 'birdy') return;
  frame({ title: 'Birdy', tabs: tabsHtml([['feed', t('Pour vous')], ['me', t('Mon profil')]], tab, 'data-btab'),
    action: `<button class="icon-btn icon-btn--accent" data-new aria-label="${t('Nouveau gazouillis')}">${icon('plus')}</button>`, body: loading() });
  $$('[data-btab]', appView).forEach(b => b.onclick = () => { setParams({ tab: b.dataset.btab }); Views.birdy({ tab: b.dataset.btab }); });
  $('[data-new]', appView).onclick = () => openSheet(t('Nouveau gazouillis'), `<div class="form">
    <textarea class="field" id="b-text" rows="4" maxlength="280" placeholder="${t('Quoi de neuf à Los Santos ?')}"></textarea>
    <p class="counter" id="b-count">0 / 280</p>
    <input class="field" id="b-img" placeholder="${t('Lien d\'une image (facultatif)')}">
    <p class="error-text" id="b-err"></p>
    <button class="btn btn--block" id="b-go">${t('Publier')}</button></div>`, (sh) => {
    const ta = $('#b-text', sh);
    ta.oninput = () => { $('#b-count', sh).textContent = `${ta.value.length} / 280`; };
    $('#b-go', sh).onclick = async () => {
      const r = await api('createPost', { app: 'birdy', content: ta.value, image: $('#b-img', sh).value });
      if (!r.ok) { $('#b-err', sh).textContent = t(r.error || 'Publication impossible.'); return; }
      closeSheet(); Views.birdy({ tab });
    };
  });
  const res = await api('getFeed', { app: 'birdy', username: tab === 'me' ? acc.username : undefined });
  if (S.currentApp !== 'birdy') return;
  const posts = res.posts || [];
  const head = tab === 'me' ? `<div class="profile-head">${avatar(acc.display_name, acc.username, 'avatar--lg')}
      <div><h2 class="profile-head__name">${esc(acc.display_name)}</h2><p class="row__sub">@${esc(acc.username)}</p>
      <div class="stats"><span><b>${posts.filter(p => !p.repost_of).length}</b> ${t('gazouillis')}</span></div></div></div>` : '';
  $('.app__body', appView).innerHTML = head + (posts.length ? posts.map(p => {
    const rp = !!p.repost_of;
    const name = rp ? p.o_display : p.display_name, user = rp ? p.o_username : p.username;
    const text = rp ? p.o_content : p.content, img = rp ? p.o_image : p.image;
    const target = p.repost_of || p.id;
    return `<article class="post">
      ${rp ? `<p class="post__repost">${icon('repost')}${p.mine ? t('Vous avez re-gazouillé') : t('{name} a re-gazouillé', { name: esc(p.display_name) })}</p>` : ''}
      <div class="post__head">${avatar(name, user)}<div style="min-width:0"><div class="post__name">${esc(name)} <span class="post__time">@${esc(user)}, ${timeAgo(p.ts)}</span></div></div></div>
      ${text ? `<p class="post__text">${richText(text)}</p>` : ''}
      ${img ? `<img class="post__img" src="${esc(img)}" alt="" loading="lazy" onerror="this.remove()">` : ''}
      <div class="post__actions">
        <button data-comment="${target}" aria-label="${t('Commenter')}">${icon('comment')}<span>${p.comments}</span></button>
        <button data-repost="${target}" aria-label="${t('Re-gazouiller')}">${icon('repost')}<span>${p.reposts}</span></button>
        <button class="${p.liked ? 'liked' : ''}" data-like="${target}" aria-pressed="${p.liked}" aria-label="${t('J\'aime')}">${icon('heart')}<span>${p.likes}</span></button>
        ${p.mine && !rp ? `<button data-del="${p.id}" aria-label="${t('Supprimer')}" style="margin-left:auto">${icon('trash')}</button>` : ''}</div></article>`;
  }).join('') : empty(tab === 'me' ? t('Rien pour l\'instant') : t('Le fil est calme'), tab === 'me' ? t('Vos gazouillis apparaîtront ici.') : t('Soyez la première voix de la ville aujourd\'hui.')));
  wireLikes(appView);
  $$('[data-comment]', appView).forEach(b => b.onclick = () => commentsSheet(+b.dataset.comment, () => {
    $$(`[data-comment="${b.dataset.comment}"] span`, appView).forEach(x => x.textContent = +x.textContent + 1);
  }));
  $$('[data-repost]', appView).forEach(b => b.onclick = async () => { const r = await api('repost', { id: +b.dataset.repost }); if (r.ok) Views.birdy({ tab }); });
  $$('[data-del]', appView).forEach(b => b.onclick = () => confirmSheet(t('Supprimer ce gazouillis ?'), t('Il disparaîtra du fil pour tout le monde.'), t('Supprimer'), async () => {
    await api('deletePost', { id: +b.dataset.del }); Views.birdy({ tab });
  }));
};

/* ---------- InstaPick ---------- */
Views.instapick = async ({ tab = 'feed' } = {}) => {
  frame({ title: 'InstaPick', body: loading() });
  const acc = await ensureAccount('instapick', () => Views.instapick({ tab }));
  if (!acc || S.currentApp !== 'instapick') return;
  frame({ title: 'InstaPick', tabs: tabsHtml([['feed', t('Fil')], ['me', t('Mon profil')]], tab, 'data-itab'),
    action: `<button class="icon-btn icon-btn--accent" data-new aria-label="${t('Nouvelle publication')}">${icon('plus')}</button>`, body: loading() });
  $$('[data-itab]', appView).forEach(b => b.onclick = () => { setParams({ tab: b.dataset.itab }); Views.instapick({ tab: b.dataset.itab }); });
  $('[data-new]', appView).onclick = () => instaComposer();
  const res = await api('getFeed', { app: 'instapick', username: tab === 'me' ? acc.username : undefined });
  if (S.currentApp !== 'instapick') return;
  const posts = res.posts || [];
  const body = $('.app__body', appView);
  const newBtn = `<button class="btn" data-new2>${t('Publier une photo')}</button>`;
  if (tab === 'me') {
    const likes = posts.reduce((a, p) => a + p.likes, 0);
    body.innerHTML = `<div class="profile-head">${avatar(acc.display_name, acc.username, 'avatar--lg')}
      <div><h2 class="profile-head__name">${esc(acc.display_name)}</h2><p class="row__sub">@${esc(acc.username)}</p>
      <div class="stats"><span><b>${posts.length}</b> ${t('publications')}</span><span><b>${likes}</b> ${t('j\'aime')}</span></div></div></div>
      ${posts.length ? `<div class="gallery">${posts.map(p => `<button data-open-post="${p.id}" style="background-image:url('${esc(p.image)}')" aria-label="${t('Publication')}"></button>`).join('')}</div>`
        : empty(t('Votre profil est vide'), t('Publiez une photo de votre galerie pour commencer.'), newBtn)}`;
    $$('[data-open-post]', appView).forEach(b => b.onclick = () => openSheet('', instaCard(posts.find(x => x.id == b.dataset.openPost)), wireInsta));
  } else {
    body.innerHTML = posts.length ? posts.map(instaCard).join('') : empty(t('Aucune photo'), t('Soyez le premier à partager un instant de la ville.'), newBtn);
    wireInsta(appView);
  }
  $('[data-new2]', appView)?.addEventListener('click', () => instaComposer());
};
function instaCard(p) {
  return `<article class="insta">
    <div class="post__head" style="padding:12px 14px">${avatar(p.display_name, p.username)}
      <div style="flex:1"><div class="post__name">${esc(p.username)}</div><div class="post__time">${timeAgo(p.ts)}</div></div>
      ${p.mine ? `<button class="icon-btn" data-del="${p.id}" aria-label="${t('Supprimer')}">${icon('trash')}</button>` : ''}</div>
    <div class="insta__photo" data-dbl="${p.id}"><img src="${esc(p.image)}" alt="" loading="lazy"><span class="insta__burst">${icon('heart')}</span></div>
    <div class="post__actions" style="padding:10px 14px 0">
      <button class="${p.liked ? 'liked' : ''}" data-like="${p.id}" aria-pressed="${p.liked}" aria-label="${t('J\'aime')}">${icon('heart')}<span>${p.likes}</span></button>
      <button data-comment="${p.id}" aria-label="${t('Commenter')}">${icon('comment')}<span>${p.comments}</span></button></div>
    ${p.content ? `<p class="insta__caption"><b>${esc(p.username)}</b> ${richText(p.content)}</p>` : '<div style="height:12px"></div>'}</article>`;
}
function wireInsta(root) {
  wireLikes(root);
  $$('[data-dbl]', root).forEach(el => el.ondblclick = () => {
    const burst = el.querySelector('.insta__burst');
    burst.classList.remove('pop'); void burst.offsetWidth; burst.classList.add('pop');
    const btn = $(`[data-like="${el.dataset.dbl}"]`, root);
    if (btn && !btn.classList.contains('liked')) btn.click();
  });
  $$('[data-comment]', root).forEach(b => b.onclick = () => commentsSheet(+b.dataset.comment, () => { const x = b.querySelector('span'); x.textContent = +x.textContent + 1; }));
  $$('[data-del]', root).forEach(b => b.onclick = () => confirmSheet(t('Supprimer cette photo ?'), t('Elle sera retirée d\'InstaPick avec ses commentaires.'), t('Supprimer'), async () => {
    await api('deletePost', { id: +b.dataset.del }); Views.instapick({ tab: S.stack[S.stack.length - 1]?.params?.tab || 'feed' });
  }));
}
async function instaComposer(prefill = '') {
  const g = await api('getGallery');
  const photos = (g.photos || []).filter(p => (p.type || 'photo') === 'photo');
  openSheet(t('Nouvelle publication'), `<div class="form">
    ${photos.length ? `<div class="picker">${photos.slice(0, 12).map(p => `<button data-pick="${esc(p.url)}" class="${p.url === prefill ? 'picked' : ''}" style="background-image:url('${esc(p.url)}')" aria-label="${t('Choisir cette photo')}"></button>`).join('')}</div>`
      : `<p class="sheet__text" style="margin:0 6px">${t('Votre galerie est vide : prenez une photo ou collez un lien ci-dessous.')}</p>`}
    <input class="field" id="i-url" placeholder="${t('Ou collez le lien d\'une image')}" value="${esc(prefill)}">
    <textarea class="field" id="i-caption" rows="2" maxlength="280" placeholder="${t('Écrire une légende')}"></textarea>
    <p class="error-text" id="i-err"></p>
    <button class="btn btn--block" id="i-go">${t('Partager')}</button></div>`, (sh) => {
    $$('[data-pick]', sh).forEach(b => b.onclick = () => { $('#i-url', sh).value = b.dataset.pick; $$('[data-pick]', sh).forEach(x => x.classList.toggle('picked', x === b)); });
    $('#i-go', sh).onclick = async () => {
      const r = await api('createPost', { app: 'instapick', image: $('#i-url', sh).value.trim(), content: $('#i-caption', sh).value });
      if (!r.ok) { $('#i-err', sh).textContent = t(r.error || 'Publication impossible.'); return; }
      closeSheet(); if (S.currentApp === 'instapick') Views.instapick({ tab: 'feed' });
    };
  });
}

/* ---------- Itoune ---------- */
// Moteur audio intégré : lecteur YouTube officiel (invisible) ou lecteur audio pour les liens directs.
// Il joue ma musique ('me') et celles des joueurs proches ('r' + id), dont le jeu règle le volume.
const AudioEngine = (() => {
  const players = {};
  let apiPromise = null;
  const host = () => $('#yt-host');
  const ytId = (url) => (String(url).match(/(?:youtu\.be\/|[?&]v=|\/shorts\/|\/embed\/|\/live\/)([\w-]{11})/) || [])[1];

  function loadApi() {
    if (window.YT && window.YT.Player) return Promise.resolve();
    if (apiPromise) return apiPromise;
    apiPromise = new Promise((res, rej) => {
      const prev = window.onYouTubeIframeAPIReady;
      window.onYouTubeIframeAPIReady = () => { prev?.(); res(); };
      const sc = document.createElement('script');
      sc.src = 'https://www.youtube.com/iframe_api';
      sc.onerror = () => { apiPromise = null; rej(new Error('yt')); };
      document.head.appendChild(sc);
      setTimeout(() => { if (!(window.YT && window.YT.Player)) { apiPromise = null; rej(new Error('timeout')); } }, 15000);
    });
    return apiPromise;
  }

  function stop(id) {
    const p = players[id]; if (!p) return;
    delete players[id];
    try {
      if (p.type === 'yt') { p.obj.destroy?.(); p.el?.remove(); }
      else { p.obj.pause(); p.obj.removeAttribute('src'); p.obj.load(); }
    } catch (e) { /* déjà détruit */ }
  }

  async function play(id, { url, time = 0, volume = 1, onEnd, onError }) {
    stop(id);
    const vid = ytId(url);
    if (vid) {
      try { await loadApi(); } catch (e) { onError?.('api'); return false; }
      const el = document.createElement('div');
      el.id = 'yt-' + String(id).replace(/\W/g, '') + '-' + Date.now();
      host().appendChild(el);
      return new Promise((res) => {
        const entry = { type: 'yt', obj: null, el: null, ready: false, volume, queued: null };
        players[id] = entry;
        entry.obj = new YT.Player(el.id, {
          width: 320, height: 180, videoId: vid,
          playerVars: { autoplay: 1, controls: 0, disablekb: 1, playsinline: 1, rel: 0, fs: 0, iv_load_policy: 3, origin: location.origin, start: Math.max(0, Math.floor(time)) },
          events: {
            onReady: (e) => {
              if (players[id] !== entry) { e.target.destroy(); return res(false); }
              entry.ready = true;
              entry.el = document.getElementById(el.id);
              e.target.unMute(); e.target.setVolume(Math.round(entry.volume * 100)); e.target.playVideo();
              if (entry.queued) { entry.queued(); entry.queued = null; }
              res(true);
            },
            onStateChange: (e) => { if (e.data === 0) onEnd?.(); },
            onError: (e) => { onError?.(e.data); res(false); },
          },
        });
      });
    }
    const audio = new Audio(url);
    audio.volume = Math.max(0, Math.min(1, volume));
    audio.onended = () => onEnd?.();
    players[id] = { type: 'audio', obj: audio, ready: true, volume };
    try {
      await audio.play();
      if (time > 0) audio.currentTime = time;
      return true;
    } catch (e) { onError?.('audio'); return false; }
  }

  const when = (id, fn) => { const p = players[id]; if (!p) return; if (p.ready) fn(p); else p.queued = () => fn(p); };
  return {
    play, stop,
    has: (id) => !!players[id],
    setVolume(id, v) {
      const p = players[id]; if (!p) return;
      p.volume = Math.max(0, Math.min(1, v));
      if (p.type === 'yt') { if (p.ready) p.obj.setVolume(Math.round(p.volume * 100)); }
      else p.obj.volume = p.volume;
    },
    pause: (id) => when(id, p => p.type === 'yt' ? p.obj.pauseVideo() : p.obj.pause()),
    resume: (id) => when(id, p => p.type === 'yt' ? p.obj.playVideo() : p.obj.play()),
    seek: (id, s) => when(id, p => p.type === 'yt' ? p.obj.seekTo(s, true) : (p.obj.currentTime = s)),
    time(id) { const p = players[id]; if (!p || !p.ready) return 0; return (p.type === 'yt' ? p.obj.getCurrentTime?.() : p.obj.currentTime) || 0; },
    duration(id) { const p = players[id]; if (!p || !p.ready) return 0; return (p.type === 'yt' ? p.obj.getDuration?.() : p.obj.duration) || 0; },
  };
})();

const YT_ERRORS = {
  2: 'Lien YouTube invalide',
  5: 'Cette vidéo ne peut pas être lue ici',
  100: 'Vidéo YouTube introuvable ou privée',
  101: 'Cette vidéo ne peut pas être lue en dehors de YouTube',
  150: 'Cette vidéo ne peut pas être lue en dehors de YouTube',
  153: 'YouTube a refusé la lecture. Réessayez ou choisissez une autre vidéo.',
  api: 'Impossible de joindre YouTube. Vérifiez votre connexion.',
  audio: 'Ce lien ne contient pas un fichier audio lisible.',
};

const Music = {
  queue: [], index: -1, playing: false, started: false,
  volume: .6, speaker: true, time: 0, dur: 0, poll: null, volTimer: null, playToken: 0,
  get track() { return this.queue[this.index]; },
  broadcast(action, data = {}) { if (this.speaker) post('musicBroadcast', Object.assign({ action }, data)); },
  async play(i, startAt = 0) {
    if (i !== undefined) this.index = i;
    const tr = this.track; if (!tr) return;
    const token = ++this.playToken;
    this.playing = true; this.started = true; this.time = startAt; this.dur = 0;
    this.sync();
    const ok = await AudioEngine.play('me', {
      url: tr.url, time: startAt, volume: this.volume,
      onEnd: () => { if (token === this.playToken) this.next(); },
      onError: (code) => {
        if (token !== this.playToken) return;
        this.playing = false; this.started = false; this.sync();
        this.broadcast('stop');
        notify({ app: 'itoune', title: t('Lecture impossible'), text: t(YT_ERRORS[code] || 'Réessayez dans un instant.') });
      },
    });
    if (!ok || token !== this.playToken) return;
    this.broadcast('play', { url: tr.url, time: startAt, volume: this.volume });
    this.startPoll();
  },
  pause() { AudioEngine.pause('me'); this.playing = false; this.broadcast('pause', { time: this.time }); this.sync(); },
  resume() { AudioEngine.resume('me'); this.playing = true; this.broadcast('resume', { time: this.time }); this.sync(); },
  toggle() {
    if (this.playing) this.pause();
    else if (this.track && this.started && AudioEngine.has('me')) this.resume();
    else if (this.queue.length) this.play(this.index >= 0 ? this.index : 0);
  },
  next() { if (this.queue.length) this.play((this.index + 1) % this.queue.length); else this.stop(); },
  prev() {
    if (this.time > 4) { this.seek(0); return; }
    if (this.queue.length) this.play((this.index - 1 + this.queue.length) % this.queue.length);
  },
  seek(sec) { this.time = sec; AudioEngine.seek('me', sec); this.broadcast('seek', { time: sec }); },
  setVolume(v) {
    this.volume = v;
    AudioEngine.setVolume('me', v);
    clearTimeout(this.volTimer);
    this.volTimer = setTimeout(() => this.broadcast('volume', { volume: v }), 300);
  },
  setSpeaker(on) {
    if (on === this.speaker) return;
    if (!on) this.broadcast('stop');
    this.speaker = on;
    if (on && this.started && this.track) {
      post('musicBroadcast', { action: 'play', url: this.track.url, time: this.time, volume: this.volume });
      if (!this.playing) setTimeout(() => this.broadcast('pause', { time: this.time }), 400);
    }
    this.sync();
  },
  stop() {
    this.broadcast('stop');
    AudioEngine.stop('me');
    this.playToken++;
    this.playing = false; this.started = false; this.index = -1; this.time = 0; this.dur = 0;
    clearInterval(this.poll); this.sync();
  },
  startPoll() {
    clearInterval(this.poll);
    this.poll = setInterval(() => {
      if (!this.started) return;
      this.time = AudioEngine.time('me'); this.dur = AudioEngine.duration('me');
      updateProgress();
    }, 500);
  },
  sync() { if (S.currentApp === 'itoune') renderPlayer(); if (this.playing) showMusicIsland(); else hideMusicIsland(); },
};

// Musique diffusée par les autres joueurs : le jeu envoie les ordres et le volume selon la distance
const RemoteMusic = {
  handle({ id, action, data }) {
    const key = 'r' + id;
    if (action === 'play') AudioEngine.play(key, { url: data.url, time: data.time || 0, volume: 0 });
    else if (action === 'pause') AudioEngine.pause(key);
    else if (action === 'resume') { AudioEngine.seek(key, data.time || 0); AudioEngine.resume(key); }
    else if (action === 'seek') AudioEngine.seek(key, data.time || 0);
    else if (action === 'stop') AudioEngine.stop(key);
  },
  volumes({ list }) { (list || []).forEach(u => AudioEngine.setVolume('r' + u.id, u.v)); },
};

const SOURCE_LABEL = { youtube: 'YouTube', spotify: 'Spotify', direct: 'Lien audio' };
const discStyle = (tr) => tr ? `--d1:${avColor(tr.title)};--d2:${avColor(tr.artist + tr.title + 'x')}` : '';
const artwork = (tr, cls = '') => tr && tr.thumb
  ? `<div class="art ${cls} ${Music.playing && Music.track === tr ? 'live' : ''}" style="background-image:url('${esc(tr.thumb)}')"></div>`
  : `<div class="disc ${cls === 'art--sm' ? 'disc--sm' : ''} ${Music.playing && Music.track === tr && cls !== 'art--sm' ? 'spin' : ''}" style="${discStyle(tr)}"><span></span></div>`;

function updateProgress() {
  const bar = $('#mu-progress'); if (!bar) return;
  if (Music.dur > 0 && document.activeElement !== bar) bar.value = Math.min(1000, (Music.time / Music.dur) * 1000);
  const c = $('#mu-cur'), d = $('#mu-dur');
  if (c) c.textContent = duration(Math.floor(Music.time));
  if (d) d.textContent = Music.dur ? duration(Math.floor(Music.dur)) : '--:--';
}
function renderPlayer() {
  const el = $('#mu-player'); if (!el) return;
  const tr = Music.track, it = S.profile?.itoune || {};
  el.innerHTML = `${artwork(tr)}
    <div class="np__text"><p class="np__title">${tr ? esc(tr.title) : t('Rien en lecture')}</p>
      <p class="row__sub">${tr ? esc(tr.artist) : t('Collez un lien YouTube ci-dessus')}</p>
      ${tr ? `<span class="src-badge src-${tr.source || 'direct'}">${t(SOURCE_LABEL[tr.source] || 'Lien audio')}</span>` : ''}</div>
    <input type="range" class="range" id="mu-progress" min="0" max="1000" value="0" aria-label="${t('Position dans le morceau')}" ${tr ? '' : 'disabled'}>
    <div class="np__times"><span id="mu-cur">0:00</span><span id="mu-dur">--:--</span></div>
    <div class="np__controls">
      <button class="icon-btn" data-mu="prev" aria-label="${t('Précédent')}">${icon('prev')}</button>
      <button class="play-btn" data-mu="toggle" aria-label="${Music.playing ? t('Pause') : t('Lecture')}">${icon(Music.playing ? 'pause' : 'play')}</button>
      <button class="icon-btn" data-mu="next" aria-label="${t('Suivant')}">${icon('next')}</button></div>
    <div class="np__volume">${icon('speaker')}<input type="range" class="range" id="mu-vol" min="0" max="100" value="${Math.round(Music.volume * 100)}" aria-label="${t('Volume')}"></div>
    <button class="np__speaker ${Music.speaker ? 'on' : ''}" id="mu-speaker" role="switch" aria-checked="${Music.speaker}">
      <span class="chip-ic" style="--c:${Music.speaker ? 'var(--ok)' : '#8A90A8'}">${icon('drop')}</span>
      <span class="row__main"><span class="row__title">${t('Haut-parleur')}</span>
      <span class="row__sub row__sub--wrap">${Music.speaker ? t('Les personnes autour de vous entendent la musique (jusqu\'à {d} m)', { d: Math.round(it.distance || 12) }) : t('Vous seul entendez la musique')}</span></span>
      <span class="toggle ${Music.speaker ? 'on' : ''}"></span></button>`;
  $$('[data-mu]', el).forEach(b => b.onclick = () => Music[b.dataset.mu]());
  $('#mu-progress').onchange = (e) => { if (Music.dur) Music.seek(e.target.value / 1000 * Music.dur); };
  $('#mu-vol').oninput = (e) => Music.setVolume(e.target.value / 100);
  $('#mu-speaker').onclick = () => Music.setSpeaker(!Music.speaker);
  updateProgress();
  $$('[data-track]', appView).forEach(r => r.classList.toggle('playing', +r.dataset.track === Music.index));
}
Views.itoune = async () => {
  frame({ title: 'Itoune', body: `
    <div class="link-add"><input class="field" id="it-link" placeholder="${t('Collez un lien YouTube, Spotify ou audio')}">
      <button class="icon-btn icon-btn--accent" id="it-add" aria-label="${t('Ajouter')}">${icon('plus')}</button></div>
    <p class="error-text" id="it-err"></p>
    <section class="np" id="mu-player"></section>
    <p class="section-label">${t('Bibliothèque')}</p><div id="mu-list">${loading()}</div>` });
  renderPlayer();
  const add = async () => {
    const input = $('#it-link'), btn = $('#it-add');
    const link = input.value.trim(); if (!link) return;
    btn.disabled = true; $('#it-err').textContent = t('Recherche du morceau…');
    const r = await api('addTrack', { link });
    btn.disabled = false;
    if (!r.ok) { $('#it-err').textContent = t(r.error || 'Ajout impossible.'); return; }
    $('#it-err').textContent = ''; input.value = ''; input.blur();
    await loadTracks();
    const idx = Music.queue.findIndex(x => x.id === r.track.id);
    if (idx >= 0) Music.play(idx);
  };
  $('#it-add').onclick = add;
  $('#it-link').onkeydown = (e) => { if (e.key === 'Enter') add(); };
  await loadTracks();
  if (Music.started) Music.startPoll();
};
async function loadTracks() {
  const res = await api('getTracks');
  if (S.currentApp !== 'itoune') return;
  const tracks = res.tracks || [];
  const playingId = Music.track?.id;
  Music.queue = tracks;
  Music.index = tracks.findIndex(x => x.id === playingId);
  if (playingId && Music.index === -1) Music.stop();
  $('#mu-list').innerHTML = tracks.length ? `<div class="list">${tracks.map((tr, i) => `<div class="row track" data-track="${i}" role="button" tabindex="0">
      ${artwork(tr, 'art--sm')}
      <div class="row__main"><div class="row__title">${esc(tr.title)}</div><div class="row__sub">${esc(tr.artist)}, ${t(SOURCE_LABEL[tr.source] || 'Lien audio')}</div></div>
      <button class="icon-btn icon-btn--ghost" data-deltrack="${tr.id}" aria-label="${t('Retirer')}">${icon('trash')}</button></div>`).join('')}</div>`
    : empty(t('Bibliothèque vide'), t('Collez un lien YouTube ou Spotify ci-dessus pour lancer la musique.'));
  $$('[data-track]', appView).forEach(r => r.onclick = () => Music.play(+r.dataset.track));
  $$('[data-deltrack]', appView).forEach(b => b.onclick = (e) => {
    e.stopPropagation();
    confirmSheet(t('Retirer ce morceau ?'), t('Il sera supprimé de votre bibliothèque.'), t('Retirer'), async () => {
      if (Music.track?.id === +b.dataset.deltrack) Music.stop();
      await api('deleteTrack', { id: +b.dataset.deltrack }); loadTracks();
    });
  });
  renderPlayer();
}
function showMusicIsland() {
  if (S.call || island.classList.contains('expanded')) return;
  island.classList.add('compact', 'music');
  $('.island__content', island).innerHTML = `<span class="eq" aria-hidden="true"><i></i><i></i><i></i><i></i></span><span class="island__music">${esc(Music.track?.title || '')}</span>${Music.speaker ? `<span style="width:15px;color:var(--ok);flex:none">${icon('drop')}</span>` : ''}`;
  island.onclick = () => openApp('itoune');
}
function hideMusicIsland() {
  if (!island.classList.contains('music')) return;
  island.classList.remove('compact', 'music');
  island.onclick = null;
  $('.island__content', island).innerHTML = '';
}
