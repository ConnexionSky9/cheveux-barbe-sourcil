'use strict';
/* =========================================================
   APPAREIL PHOTO · CAMÉRA · GALERIE
   ========================================================= */
const Cam = { mode: 'photo', selfie: false, recording: false, recorder: null, chunks: [], recStart: 0, recTimer: null, drawRaf: null, uploading: 0, lastThumb: null };

Views.camera = () => {
  if (!S.profile?.cameraEnabled) { notify({ app: 'camera', key: 'cameraOff' }); back(); return; }
  screenEl.classList.add('camera-mode');
  appView.innerHTML = `<div class="cam">
    <div class="cam__vf" id="cam-vf"></div>
    <div class="cam__flash" id="cam-flash"></div>
    <div class="cam__top">
      <button class="cam__btn" data-cam-close aria-label="${t('Fermer')}">${icon('close')}</button>
      <span class="cam__rec hidden" id="cam-rec"><i></i><span id="cam-time">0:00</span></span>
      <span class="cam__status hidden" id="cam-status">${t('Envoi…')}</span>
    </div>
    <p class="cam__hint" id="cam-hint"></p>
    <div class="cam__zoom ${Cam.selfie ? '' : 'hidden'}" id="cam-zoom">
      <button data-zoom="-1" aria-label="${t('Rapprocher')}">${icon('plus')}</button>
      <button data-zoom="1" aria-label="${t('Éloigner')}"><span style="font-size:20px;font-weight:800;line-height:1">−</span></button></div>
    <div class="cam__bottom">
      <div class="cam__modes" role="tablist">
        <button data-mode="photo" class="${Cam.mode === 'photo' ? 'active' : ''}">${t('Photo')}</button>
        <button data-mode="video" class="${Cam.mode === 'video' ? 'active' : ''}">${t('Vidéo')}</button></div>
      <div class="cam__controls">
        <button class="cam__thumb" id="cam-thumb" aria-label="${t('Galerie')}" ${Cam.lastThumb ? `style="background-image:url('${Cam.lastThumb}')"` : ''}></button>
        <button class="shutter ${Cam.mode}" id="shutter" aria-label="${t('Déclencher')}"><span></span></button>
        <button class="cam__btn cam__btn--lg" id="cam-flip" aria-label="${t('Changer de caméra')}">${icon('reset')}</button></div>
    </div></div>`;
  const canvas = GameView.start(S.profile.camera?.flipY);
  canvas.className = 'cam__canvas';
  $('#cam-vf').appendChild(canvas);
  post('cameraOn', { selfie: Cam.selfie });
  S.onLeave = stopCamera;
  updateCamMode();
  // Selfie : molette ou boutons pour rapprocher / éloigner la caméra
  $('#cam-vf').addEventListener('wheel', (e) => { if (Cam.selfie) { e.preventDefault(); post('selfieZoom', { delta: e.deltaY > 0 ? 1 : -1 }); } }, { passive: false });
  $$('[data-zoom]', appView).forEach(b => b.onclick = () => post('selfieZoom', { delta: +b.dataset.zoom }));

  $('[data-cam-close]', appView).onclick = () => back();
  $$('[data-mode]', appView).forEach(b => b.onclick = () => {
    if (Cam.recording) return;
    Cam.mode = b.dataset.mode;
    $$('[data-mode]', appView).forEach(x => x.classList.toggle('active', x === b));
    $('#shutter').className = `shutter ${Cam.mode}`;
  });
  $('#shutter').onclick = shutter;
  $('#cam-flip').onclick = async () => {
    if (Cam.recording) return;
    const r = await post('cameraFlip');
    Cam.selfie = IS_BROWSER ? !Cam.selfie : !!r.selfie;
    updateCamMode();
  };
  $('#cam-thumb').onclick = () => openApp('gallery');
};

function updateCamMode() {
  const hint = $('#cam-hint'); if (!hint) return;
  hint.textContent = Cam.selfie ? t('Selfie : clic droit maintenu pour changer d\'angle, molette pour zoomer') : t('Maintenez le clic droit pour viser');
  $('#cam-zoom')?.classList.toggle('hidden', !Cam.selfie);
}

function stopCamera() {
  if (Cam.recording) stopRecording();
  GameView.stop();
  post('cameraOff');
  screenEl.classList.remove('camera-mode');
}

function shutter() {
  if (Cam.mode === 'photo') takePhoto();
  else if (Cam.recording) stopRecording();
  else startRecording();
}

function viewfinderAspect() {
  const vf = $('#cam-vf');
  return vf ? vf.clientWidth / vf.clientHeight : 0.46;
}

async function takePhoto() {
  const src = GameView.canvas; if (!src) return;
  const fl = $('#cam-flash'); fl.classList.remove('go'); void fl.offsetWidth; fl.classList.add('go');
  Sound.shutter();
  const r = cropRect(src, viewfinderAspect());
  const scale = Math.min(1, 1440 / r.h);
  const out = document.createElement('canvas');
  out.width = Math.round(r.w * scale); out.height = Math.round(r.h * scale);
  out.getContext('2d').drawImage(src, r.sx, r.sy, r.w, r.h, 0, 0, out.width, out.height);
  setThumb(out);
  const blob = await new Promise(res => out.toBlob(res, 'image/jpeg', 0.88));
  uploadMedia('photo', blob, 0);
}

function setThumb(canvas) {
  const th = document.createElement('canvas');
  th.width = 120; th.height = Math.round(120 * canvas.height / canvas.width);
  th.getContext('2d').drawImage(canvas, 0, 0, th.width, th.height);
  Cam.lastThumb = th.toDataURL('image/jpeg', .7);
  const el = $('#cam-thumb'); if (el) el.style.backgroundImage = `url('${Cam.lastThumb}')`;
}

function startRecording() {
  const src = GameView.canvas; if (!src || typeof MediaRecorder === 'undefined') {
    notify({ app: 'camera', title: t('Vidéo indisponible'), text: t('Votre jeu ne permet pas l\'enregistrement vidéo.') }); return;
  }
  const r = cropRect(src, viewfinderAspect());
  const scale = Math.min(1, 1080 / r.h);
  const out = document.createElement('canvas');
  out.width = Math.round(r.w * scale) & ~1; out.height = Math.round(r.h * scale) & ~1;
  const ctx = out.getContext('2d');
  const draw = () => { ctx.drawImage(src, r.sx, r.sy, r.w, r.h, 0, 0, out.width, out.height); Cam.drawRaf = requestAnimationFrame(draw); };
  draw();
  const mime = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'].find(m => MediaRecorder.isTypeSupported?.(m)) || 'video/webm';
  Cam.chunks = [];
  Cam.recorder = new MediaRecorder(out.captureStream(30), { mimeType: mime, videoBitsPerSecond: S.profile.camera?.bitrate || 1500000 });
  Cam.recorder.ondataavailable = (e) => { if (e.data && e.data.size) Cam.chunks.push(e.data); };
  Cam.recorder.onstop = () => {
    cancelAnimationFrame(Cam.drawRaf);
    const secs = Math.round((Date.now() - Cam.recStart) / 1000);
    const blob = new Blob(Cam.chunks, { type: 'video/webm' });
    setThumb(out);
    if (blob.size > 0) uploadMedia('video', blob, secs);
  };
  Cam.recorder.start(250);
  Cam.recording = true; Cam.recStart = Date.now();
  Sound.recStart();
  $('#shutter')?.classList.add('rec');
  $('#cam-rec')?.classList.remove('hidden');
  const max = S.profile.camera?.maxVideo || 20;
  Cam.recTimer = setInterval(() => {
    const s = Math.floor((Date.now() - Cam.recStart) / 1000);
    const el = $('#cam-time'); if (el) el.textContent = `${duration(s)} / ${duration(max)}`;
    if (s >= max) stopRecording();
  }, 250);
}

function stopRecording() {
  if (!Cam.recording) return;
  Cam.recording = false;
  clearInterval(Cam.recTimer);
  try { Cam.recorder.stop(); } catch (e) { /* déjà arrêté */ }
  Sound.recStop();
  $('#shutter')?.classList.remove('rec');
  $('#cam-rec')?.classList.add('hidden');
}

function blobToBase64(blob) {
  return new Promise((res, rej) => {
    const fr = new FileReader();
    fr.onload = () => res(String(fr.result).split(',')[1]);
    fr.onerror = rej;
    fr.readAsDataURL(blob);
  });
}
function jsonPath(obj, path) {
  return String(path || '').split('.').reduce((cur, k) => (cur == null ? cur : cur[/^\d+$/.test(k) ? (+k - 1) : k]), obj);
}

async function uploadMedia(kind, blob, secs) {
  Cam.uploading++;
  $('#cam-status')?.classList.remove('hidden');
  const cfg = S.profile.camera || {};
  let res;
  try {
    if (IS_BROWSER) {
      res = Mock.saveMedia(kind, URL.createObjectURL(blob), secs);
    } else if (cfg.method === 'presigned') {
      // 1. le serveur demande un lien d'envoi à usage unique ; 2. le téléphone envoie le fichier directement
      const link = await api('mediaUploadUrl', { type: kind });
      if (!link.ok) res = link;
      else {
        const fd = new FormData();
        fd.append('file', blob, `elyzea_${Date.now()}.${kind === 'video' ? 'webm' : 'jpg'}`);
        const r = await fetch(link.url, { method: 'POST', body: fd });
        let body = {}; try { body = await r.json(); } catch (e) { /* réponse vide */ }
        const url = body.url || body.data?.url;
        res = url ? await api('saveMedia', { url, type: kind, duration: secs })
          : { ok: false, error: r.status === 413 ? 'Fichier trop lourd' : 'L\'hébergeur a refusé le fichier' };
        if (!url) console.log('[elyzea_aura] Réponse de l\'hébergeur :', r.status, JSON.stringify(body));
      }
    } else if (cfg.method === 'client' && cfg.direct) {
      const d = cfg.direct, fd = new FormData();
      fd.append(kind === 'video' ? d.videoField : d.imageField, blob, `elyzea_${Date.now()}.${kind === 'video' ? 'webm' : 'jpg'}`);
      const r = await fetch(kind === 'video' ? d.videoUrl : d.imageUrl, { method: 'POST', headers: d.headers || {}, body: fd });
      const url = jsonPath(await r.json(), d.path);
      res = url ? await api('saveMedia', { url, type: kind, duration: secs }) : { ok: false };
    } else {
      res = await post('uploadMedia', { kind, mime: blob.type, data: await blobToBase64(blob), duration: secs });
    }
  } catch (e) { res = { ok: false }; }
  Cam.uploading--;
  if (!Cam.uploading) $('#cam-status')?.classList.add('hidden');
  notify(res && res.ok
    ? { app: 'gallery', title: kind === 'video' ? t('Vidéo enregistrée') : t('Photo enregistrée'), text: t('Disponible dans la galerie.') }
    : { app: 'camera', title: t('Échec de l\'envoi'), text: t(res?.error || 'Vérifiez la configuration de l\'appareil photo.') });
  if (res?.ok && S.currentApp === 'gallery') Views.gallery();
}

/* ---------- Galerie (photos + vidéos) ---------- */
Views.gallery = async ({ filter = 'all' } = {}) => {
  frame({ title: t('Galerie'),
    action: S.profile?.cameraEnabled ? `<button class="icon-btn icon-btn--accent" data-cam aria-label="${t('Prendre une photo')}">${icon('camera')}</button>` : '',
    tabs: tabsHtml([['all', t('Tout')], ['photo', t('Photos')], ['video', t('Vidéos')]], filter, 'data-gf'), body: loading() });
  $('[data-cam]', appView)?.addEventListener('click', () => openApp('camera'));
  $$('[data-gf]', appView).forEach(b => b.onclick = () => { setParams({ filter: b.dataset.gf }); Views.gallery({ filter: b.dataset.gf }); });
  const res = await api('getGallery');
  if (S.currentApp !== 'gallery') return;
  const items = (res.photos || []).filter(p => filter === 'all' || (p.type || 'photo') === filter);
  $('.app__body', appView).innerHTML = items.length
    ? `<div class="gallery">${items.map(p => p.type === 'video'
        ? `<button class="gal-video" data-item="${p.id}" aria-label="${t('Vidéo')}"><video src="${esc(p.url)}" muted preload="metadata" playsinline></video>
            <span class="gal-play">${icon('play')}</span>${p.duration ? `<span class="gal-dur">${duration(p.duration)}</span>` : ''}</button>`
        : `<button data-item="${p.id}" style="background-image:url('${esc(p.url)}')" aria-label="${t('Photo')}"></button>`).join('')}</div>`
    : empty(filter === 'video' ? t('Aucune vidéo') : t('Aucune photo'), t('Ce que vous filmez ou photographiez avec l\'appareil photo arrive ici.'),
        S.profile?.cameraEnabled ? `<button class="btn" data-cam2>${icon('camera')}${t('Ouvrir l\'appareil photo')}</button>` : '');
  $('[data-cam2]', appView)?.addEventListener('click', () => openApp('camera'));
  $$('[data-item]', appView).forEach(b => b.onclick = () => openMedia(items.find(x => x.id == b.dataset.item), filter));
};
function openMedia(p, filter) {
  const video = p.type === 'video';
  openSheet('', `${video ? `<video src="${esc(p.url)}" controls autoplay playsinline style="width:100%;border-radius:22px;display:block;background:#000"></video>`
      : `<img src="${esc(p.url)}" alt="" style="width:100%;border-radius:22px;display:block">`}
    <p class="row__sub" style="margin:10px 6px 0">${timeAgo(p.ts)}${video && p.duration ? `, ${duration(p.duration)}` : ''}</p>
    <div class="form" style="margin-top:12px">
      ${video ? '' : `<button class="btn btn--block" data-insta>${t('Publier sur InstaPick')}</button>`}
      <div class="grid-2">
        ${video ? `<button class="btn btn--ghost" data-copy>${icon('copy')}${t('Copier le lien')}</button>` : `<button class="btn btn--ghost" data-wall>${t('Fond d\'écran')}</button>`}
        <button class="btn btn--danger" data-del>${t('Supprimer')}</button></div></div>`, (sh) => {
    sh.querySelector('[data-insta]')?.addEventListener('click', () => {
      closeSheet(true);
      if (!isInstalled('instapick')) { openApp('store', { detail: 'instapick' }); return; }
      instaComposer(p.url);
    });
    sh.querySelector('[data-wall]')?.addEventListener('click', () => { closeSheet(); saveSettings({ wallpaper: p.url }); notify({ app: 'settings', title: t('Fond d\'écran appliqué'), text: '' }); });
    sh.querySelector('[data-copy]')?.addEventListener('click', () => { copyText(p.url); notify({ app: 'gallery', title: t('Lien copié'), text: '' }); });
    sh.querySelector('[data-del]').onclick = () => confirmSheet(video ? t('Supprimer cette vidéo ?') : t('Supprimer cette photo ?'), t('Cette action est définitive.'), t('Supprimer'), async () => {
      await api('deletePhoto', { id: p.id }); Views.gallery({ filter });
    });
  });
}
