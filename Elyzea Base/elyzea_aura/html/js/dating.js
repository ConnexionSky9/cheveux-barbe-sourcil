'use strict';
/* =========================================================
   ÉTINCELLE — rencontres
   ========================================================= */
const Dating = { me: undefined, deck: [], chat: null };
const TAGS = ['Voitures', 'Musique', 'Sport', 'Fête', 'Cuisine', 'Voyage', 'Cinéma', 'Jeux vidéo', 'Plage', 'Art', 'Nature', 'Mode'];
const GENDER_LABEL = { man: 'Homme', woman: 'Femme', other: 'Autre' };

function etinFrame(opts) { frame(opts); appView.querySelector('.app').classList.add('etin'); }

Views.etincelle = async ({ tab = 'discover', matchId } = {}) => {
  if (Dating.me === undefined) {
    etinFrame({ title: t('Étincelle'), body: loading() });
    const r = await api('datingGetProfile');
    Dating.me = r.profile || null;
  }
  if (S.currentApp !== 'etincelle') return;
  if (!Dating.me) return datingEditor(true);
  if (tab === 'chat') return datingChat(matchId);
  if (tab === 'edit') return datingEditor(false);

  etinFrame({ title: t('Étincelle'),
    tabs: tabsHtml([['discover', t('Découvrir')], ['matches', t('Matchs')], ['me', t('Mon profil')]], tab, 'data-dtab'), body: loading() });
  $$('[data-dtab]', appView).forEach(b => b.onclick = () => { setParams({ tab: b.dataset.dtab }); Views.etincelle({ tab: b.dataset.dtab }); });
  if (tab === 'discover') return datingDiscover();
  if (tab === 'matches') return datingMatches();
  return datingMe();
};

/* ---------- Découvrir ---------- */
function cardHtml(p) {
  const photos = p.photos || [];
  return `<article class="dcard" data-id="${p.id}" data-photo="0">
    <div class="dcard__photo" style="background-image:url('${esc(photos[0] || '')}')"></div>
    ${photos.length > 1 ? `<div class="dcard__dots">${photos.map((_, i) => `<i class="${i === 0 ? 'on' : ''}"></i>`).join('')}</div>` : ''}
    ${p.superMe ? `<span class="dcard__super">${icon('star')}${t('Vous a envoyé un coup de cœur')}</span>` : ''}
    <div class="dcard__info">
      <h3 class="dcard__name">${esc(p.name)} <span>${p.age}</span></h3>
      ${p.bio ? `<p class="dcard__bio">${esc(p.bio)}</p>` : ''}
      ${p.tags?.length ? `<div class="dtags">${p.tags.map(tg => `<span>${esc(t(tg))}</span>`).join('')}</div>` : ''}
    </div>
    <span class="stamp stamp--like">${t('J\'aime')}</span><span class="stamp stamp--nope">${t('Non merci')}</span><span class="stamp stamp--super">${t('Coup de cœur')}</span>
  </article>`;
}
async function datingDiscover() {
  const body = $('.app__body', appView);
  if (!Dating.deck.length) {
    const r = await api('datingDiscover');
    if (S.currentApp !== 'etincelle') return;
    Dating.deck = r.profiles || [];
  }
  if (!Dating.deck.length) {
    body.innerHTML = empty(t('Plus personne pour le moment'), t('Revenez plus tard : de nouveaux profils arrivent chaque jour.'), `<button class="btn" data-edit>${t('Modifier mes critères')}</button>`);
    $('[data-edit]', appView).onclick = () => openApp('etincelle', { tab: 'edit' });
    return;
  }
  body.innerHTML = `<div class="deck" id="deck">${Dating.deck.slice(0, 3).reverse().map(cardHtml).join('')}</div>
    <div class="deck__actions">
      <button class="round round--nope" data-sw="left" aria-label="${t('Passer')}">${icon('close')}</button>
      <button class="round round--super" data-sw="up" aria-label="${t('Coup de cœur')}">${icon('star')}</button>
      <button class="round round--like" data-sw="right" aria-label="${t('J\'aime')}">${icon('heart')}</button></div>`;
  $$('[data-sw]', appView).forEach(b => b.onclick = () => swipeTop(b.dataset.sw));
  wireTopCard();
}
function topCard() { const cards = $$('.dcard', appView); return cards[cards.length - 1]; }
function wireTopCard() {
  const card = topCard(); if (!card) return;
  let sx = 0, sy = 0, dx = 0, dy = 0, dragging = false, moved = false;
  card.onpointerdown = (e) => { dragging = true; moved = false; sx = e.clientX; sy = e.clientY; card.setPointerCapture(e.pointerId); card.style.transition = 'none'; };
  card.onpointermove = (e) => {
    if (!dragging) return;
    dx = e.clientX - sx; dy = e.clientY - sy;
    if (Math.abs(dx) > 4 || Math.abs(dy) > 4) moved = true;
    card.style.transform = `translate(${dx}px, ${dy}px) rotate(${dx / 14}deg)`;
    card.querySelector('.stamp--like').style.opacity = Math.max(0, Math.min(1, dx / 90));
    card.querySelector('.stamp--nope').style.opacity = Math.max(0, Math.min(1, -dx / 90));
    card.querySelector('.stamp--super').style.opacity = Math.max(0, Math.min(1, -dy / 90 - Math.abs(dx) / 120));
  };
  card.onpointerup = (e) => {
    if (!dragging) return; dragging = false;
    card.style.transition = '';
    if (dx > 110) return swipeTop('right');
    if (dx < -110) return swipeTop('left');
    if (dy < -120) return swipeTop('up');
    card.style.transform = '';
    $$('.stamp', card).forEach(s => s.style.opacity = 0);
    if (!moved) cyclePhoto(card, e);
    dx = dy = 0;
  };
}
function cyclePhoto(card, e) {
  const p = Dating.deck.find(x => x.id == card.dataset.id); if (!p || (p.photos || []).length < 2) return;
  const rect = card.getBoundingClientRect();
  let i = +card.dataset.photo + (e.clientX - rect.left > rect.width / 2 ? 1 : -1);
  i = (i + p.photos.length) % p.photos.length;
  card.dataset.photo = i;
  card.querySelector('.dcard__photo').style.backgroundImage = `url('${p.photos[i]}')`;
  $$('.dcard__dots i', card).forEach((d, k) => d.classList.toggle('on', k === i));
}
async function swipeTop(dir) {
  const card = topCard(); if (!card || card.classList.contains('gone')) return;
  const id = +card.dataset.id;
  card.classList.add('gone', 'gone--' + dir);
  card.querySelector(`.stamp--${dir === 'right' ? 'like' : dir === 'left' ? 'nope' : 'super'}`).style.opacity = 1;
  Dating.deck = Dating.deck.filter(p => p.id !== id);
  setTimeout(() => {
    card.remove();
    const deck = $('#deck');
    if (deck && Dating.deck[2]) deck.insertAdjacentHTML('afterbegin', cardHtml(Dating.deck[2]));
    if (!Dating.deck.length) datingDiscover(); else wireTopCard();
  }, 380);
  const r = await api('datingSwipe', { id, like: dir !== 'left', super: dir === 'up' });
  if (r.ok && r.match) showMatch(r.match);
}
function showMatch(m) {
  const me = Dating.me, them = m.profile;
  const el = document.createElement('div');
  el.className = 'match';
  const sparks = Array.from({ length: 16 }, (_, i) => {
    const a = (i / 16) * Math.PI * 2, d = 120 + (i % 3) * 40;
    return `<i style="--x:${Math.round(Math.cos(a) * d)}px;--y:${Math.round(Math.sin(a) * d)}px;animation-delay:${(i % 4) * .05}s"></i>`;
  }).join('');
  el.innerHTML = `<div class="match__sparks" aria-hidden="true">${sparks}</div>
    <h2 class="match__title">${t('C\'est une étincelle !')}</h2>
    <p class="match__text">${t('Vous et {name} vous plaisez.', { name: esc(them.name) })}</p>
    <div class="match__pics"><span style="background-image:url('${esc(me.photos?.[0] || '')}')"></span><span style="background-image:url('${esc(them.photos?.[0] || '')}')"></span></div>
    <div class="form" style="width:100%"><button class="btn btn--block" data-m="chat">${icon('messages')}${t('Envoyer un message')}</button>
    <button class="link-btn" data-m="go" style="color:#fff">${t('Continuer à découvrir')}</button></div>`;
  appView.appendChild(el);
  Sound.unlock();
  el.querySelector('[data-m="chat"]').onclick = () => { el.remove(); openApp('etincelle', { tab: 'chat', matchId: m.id }); };
  el.querySelector('[data-m="go"]').onclick = () => el.remove();
}

/* ---------- Matchs ---------- */
async function datingMatches() {
  const r = await api('datingMatches');
  if (S.currentApp !== 'etincelle') return;
  const list = r.matches || [];
  const fresh = list.filter(m => !m.last), talks = list.filter(m => m.last);
  const body = $('.app__body', appView);
  if (!list.length) { body.innerHTML = empty(t('Aucun match pour l\'instant'), t('Glissez à droite sur les profils qui vous plaisent. Quand c\'est réciproque, ils apparaissent ici.')); return; }
  body.innerHTML = `${fresh.length ? `<p class="section-label">${t('Nouveaux matchs')}</p>
      <div class="fresh">${fresh.map(m => `<button data-chat="${m.match_id}"><span style="background-image:url('${esc(m.photo || '')}')"></span>${esc(m.name)}</button>`).join('')}</div>` : ''}
    ${talks.length ? `<p class="section-label">${t('Messages')}</p><div class="list">${talks.map(m => `<button class="row" data-chat="${m.match_id}">
      <span class="dthumb" style="background-image:url('${esc(m.photo || '')}')"></span>
      <div class="row__main"><div class="row__title">${esc(m.name)}, ${m.age}</div><div class="row__sub">${esc(m.last)}</div></div>
      <span class="row__aside">${timeAgo(m.last_ts)}</span></button>`).join('')}</div>` : ''}`;
  $$('[data-chat]', appView).forEach(b => b.onclick = () => openApp('etincelle', { tab: 'chat', matchId: +b.dataset.chat }));
}

/* ---------- Conversation ---------- */
async function datingChat(matchId) {
  Dating.chat = matchId;
  etinFrame({ title: '', small: true, body: `<div class="thread" id="thread">${loading()}</div>`,
    action: `<button class="icon-btn" data-more aria-label="${t('Plus')}">${icon('sparkle')}</button>`,
    foot: `<div class="composer"><textarea class="field" id="dm-input" rows="1" maxlength="500" placeholder="${t('Message')}"></textarea>
      <button class="icon-btn icon-btn--accent" data-send aria-label="${t('Envoyer')}">${icon('send')}</button></div>` });
  const r = await api('datingMessages', { matchId });
  if (Dating.chat !== matchId || S.currentApp !== 'etincelle') return;
  if (!r.ok) { back(); return; }
  const p = r.profile;
  $('.app__title', appView).innerHTML = `<span style="display:flex;align-items:center;gap:10px"><span class="dthumb dthumb--sm" style="background-image:url('${esc(p.photos?.[0] || '')}')"></span>${esc(p.name)}, ${p.age}</span>`;
  const th = $('#thread'); th.innerHTML = '';
  if (!r.messages.length) th.innerHTML = `<p class="bubble-time">${t('Vous avez matché avec {name}. Lancez la conversation !', { name: esc(p.name) })}</p>`;
  let last = 0;
  r.messages.forEach(m => { appendBubble(m, last); last = m.ts; });
  const input = $('#dm-input');
  const send = async () => {
    const txt = input.value.trim(); if (!txt) return;
    input.value = ''; input.style.height = 'auto';
    const res = await api('datingSend', { matchId, message: txt });
    if (res.ok) { if ($('.bubble-time', th) && !$('.bubble', th)) th.innerHTML = ''; appendBubble(res.message); }
  };
  input.oninput = () => { input.style.height = 'auto'; input.style.height = input.scrollHeight + 'px'; };
  input.onkeydown = (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } };
  $('[data-send]', appView).onclick = send;
  $('[data-more]', appView).onclick = () => openSheet(esc(p.name), `<div class="dcard dcard--static">${cardHtml(p).replace(/^<article[^>]*>|<\/article>$/g, '')}</div>
    <button class="btn btn--danger btn--block" style="margin-top:12px" data-unmatch>${t('Annuler le match')}</button>`, (sh) => {
    $('[data-unmatch]', sh).onclick = () => confirmSheet(t('Annuler le match ?'), t('La conversation sera supprimée pour vous deux.'), t('Annuler le match'), async () => {
      await api('datingUnmatch', { matchId }); back();
    });
  });
}

/* ---------- Mon profil ---------- */
function datingMe() {
  const me = Dating.me;
  $('.app__body', appView).innerHTML = `<div class="dcard dcard--static">${cardHtml(me).replace(/^<article[^>]*>|<\/article>$/g, '')}</div>
    <div class="list" style="margin-top:12px">
      <button class="row" id="d-visible"><span class="chip-ic" style="--c:#FF4D6D">${icon('heart')}</span>
        <span class="row__main"><span class="row__title row__title--light">${t('Profil visible')}</span><span class="row__sub row__sub--wrap">${t('Désactivez pour faire une pause sans perdre vos matchs.')}</span></span>
        <span class="toggle ${me.active ? 'on' : ''}"></span></button></div>
    <button class="btn btn--block" style="margin-top:12px" id="d-edit">${icon('edit')}${t('Modifier mon profil')}</button>`;
  $('#d-edit').onclick = () => openApp('etincelle', { tab: 'edit' });
  $('#d-visible').onclick = async (e) => {
    me.active = !me.active;
    e.currentTarget.querySelector('.toggle').classList.toggle('on', me.active);
    await api('datingToggle', { active: me.active });
  };
}

/* ---------- Création / modification du profil ---------- */
function datingEditor(first) {
  const me = Dating.me || { name: (S.profile?.name || '').split(' ')[0], age: '', gender: '', interest: '', bio: '', photos: [], tags: [] };
  const draft = { ...me, photos: [...(me.photos || [])], tags: [...(me.tags || [])] };
  const max = S.profile?.dating?.maxPhotos || 4, minAge = S.profile?.dating?.minAge || 18;
  const seg = (key, opts) => `<div class="seg" data-seg="${key}">${opts.map(([v, l]) => `<button class="${draft[key] === v ? 'active' : ''}" data-v="${v}">${l}</button>`).join('')}</div>`;
  etinFrame({ title: first ? t('Étincelle') : t('Mon profil'), small: !first, body: `
    ${first ? `<div class="onboard" style="padding-top:0">${storeTile('etincelle', 72)}<h2 class="onboard__title">${t('Créez votre profil')}</h2>
      <p class="onboard__text">${t('Vos photos et quelques mots suffisent. Votre numéro n\'est jamais partagé.')}</p></div>` : ''}
    <p class="section-label">${t('Photos')}</p>
    <div class="dphotos" id="d-photos"></div>
    <p class="section-label">${t('À propos de vous')}</p>
    <div class="form">
      <div class="grid-2"><input class="field" id="d-name" maxlength="30" placeholder="${t('Prénom')}" value="${esc(draft.name)}">
        <input class="field" id="d-age" type="number" min="${minAge}" max="99" placeholder="${t('Âge')}" value="${esc(draft.age)}"></div>
      <textarea class="field" id="d-bio" rows="3" maxlength="300" placeholder="${t('Quelques mots sur vous')}">${esc(draft.bio)}</textarea></div>
    <p class="section-label">${t('Je suis')}</p>${seg('gender', [['man', t('Homme')], ['woman', t('Femme')], ['other', t('Autre')]])}
    <p class="section-label">${t('Je cherche')}</p>${seg('interest', [['men', t('Des hommes')], ['women', t('Des femmes')], ['all', t('Tout le monde')]])}
    <p class="section-label">${t('Centres d\'intérêt (6 max.)')}</p>
    <div class="dtags dtags--pick">${TAGS.map(tg => `<button data-tag="${tg}" class="${draft.tags.includes(tg) ? 'on' : ''}">${t(tg)}</button>`).join('')}</div>
    <p class="error-text" id="d-err" style="margin-top:12px"></p>
    <button class="btn btn--block" id="d-save">${first ? t('Créer mon profil') : t('Enregistrer')}</button>
    <p class="row__sub row__sub--wrap" style="text-align:center;margin-top:10px">${t('Réservé aux personnages majeurs ({n} ans et plus).', { n: minAge })}</p>` });
  const drawPhotos = () => {
    $('#d-photos').innerHTML = Array.from({ length: max }, (_, i) => draft.photos[i]
      ? `<button class="dphoto" data-rm="${i}" style="background-image:url('${esc(draft.photos[i])}')" aria-label="${t('Retirer')}"><span>${icon('close')}</span></button>`
      : `<button class="dphoto dphoto--add" data-add aria-label="${t('Ajouter une photo')}">${icon('plus')}</button>`).join('');
    $$('[data-rm]', appView).forEach(b => b.onclick = () => { draft.photos.splice(+b.dataset.rm, 1); drawPhotos(); });
    $$('[data-add]', appView).forEach(b => b.onclick = pickPhoto);
  };
  const pickPhoto = async () => {
    const g = await api('getGallery');
    const photos = (g.photos || []).filter(p => (p.type || 'photo') === 'photo');
    openSheet(t('Ajouter une photo'), `${photos.length ? `<div class="picker">${photos.slice(0, 16).map(p => `<button data-pick="${esc(p.url)}" style="background-image:url('${esc(p.url)}')"></button>`).join('')}</div>`
        : `<p class="sheet__text">${t('Votre galerie est vide : prenez une photo ou collez un lien ci-dessous.')}</p>`}
      <div class="form" style="margin-top:10px"><input class="field" id="pp-url" placeholder="${t('Ou collez le lien d\'une image')}">
      <button class="btn btn--block" id="pp-go">${t('Ajouter')}</button>
      ${S.profile?.cameraEnabled ? `<button class="btn btn--ghost btn--block" id="pp-cam">${icon('camera')}${t('Ouvrir l\'appareil photo')}</button>` : ''}</div>`, (sh) => {
      const addUrl = (u) => { if (/^https:\/\//.test(u) && draft.photos.length < max) { draft.photos.push(u); drawPhotos(); } closeSheet(); };
      $$('[data-pick]', sh).forEach(b => b.onclick = () => addUrl(b.dataset.pick));
      $('#pp-go', sh).onclick = () => addUrl($('#pp-url', sh).value.trim());
      $('#pp-cam', sh)?.addEventListener('click', () => { closeSheet(true); openApp('camera'); });
    });
  };
  drawPhotos();
  $$('[data-seg]', appView).forEach(sg => $$('button', sg).forEach(b => b.onclick = () => {
    draft[sg.dataset.seg] = b.dataset.v;
    $$('button', sg).forEach(x => x.classList.toggle('active', x === b));
  }));
  $$('[data-tag]', appView).forEach(b => b.onclick = () => {
    const tg = b.dataset.tag, i = draft.tags.indexOf(tg);
    if (i >= 0) draft.tags.splice(i, 1); else if (draft.tags.length < 6) draft.tags.push(tg);
    b.classList.toggle('on', draft.tags.includes(tg));
  });
  $('#d-save').onclick = async () => {
    draft.name = $('#d-name').value.trim(); draft.age = +$('#d-age').value; draft.bio = $('#d-bio').value.trim();
    const r = await api('datingSaveProfile', draft);
    if (!r.ok) { $('#d-err').textContent = t(r.error || 'Enregistrement impossible.'); return; }
    Dating.me = Object.assign({ active: true }, Dating.me, draft);
    Dating.deck = [];
    if (first) { S.stack = [{ id: 'etincelle', params: { tab: 'discover' } }]; Views.etincelle({ tab: 'discover' }); }
    else back();
  };
}
