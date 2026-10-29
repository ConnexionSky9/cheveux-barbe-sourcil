/* ELYZEA TV - télécommande et bandeau de placement (staff) */
const $ = (s) => document.querySelector(s);
const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'elyzea_tv';
const post = (name, data = {}) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
    .then((r) => r.json()).catch(() => ({}));
const R = { open: false, state: null, volTimer: null };

// même contrôle que le serveur, pour prévenir tout de suite (le serveur reste seul juge)
function youtubeId(url) {
    url = String(url || '').trim();
    if (/^[\w-]{11}$/.test(url)) return url;
    const m = url.match(/^(?:https?:\/\/)?(?:www\.|m\.|music\.)?(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/|live\/|v\/)|youtu\.be\/)([\w-]{11})/i);
    return m ? m[1] : null;
}
const fmt = (s) => { s = Math.max(0, Math.floor(s || 0)); const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60;
    return (h ? `${h}:${String(m).padStart(2, '0')}` : `${m}`) + `:${String(x).padStart(2, '0')}`; };

function renderRemote(m) {
    const box = $('#remote');
    if (!m.open) { R.open = false; box.classList.add('hidden'); return; }
    const first = !R.open;
    R.open = true; R.state = m.state;
    $('#rName').textContent = m.name || 'Télévision';
    const st = m.state;
    $('#rNow').innerHTML = st
        ? `${st.paused ? '⏸ En pause' : '<span class="live">▶ En lecture</span>'} · vidéo <b>${st.id.replace(/[^\w-]/g, '')}</b> · ${fmt(st.position)}<br>Lancée par ${String(st.by || '').replace(/[<>&"']/g, '')}`
        : 'Écran éteint. Colle un lien YouTube puis « Lire ».';
    $('#rPause').textContent = st && st.paused ? '▶ Reprendre' : '⏸ Pause';
    $('#rPause').dataset.r = st && st.paused ? 'resume' : 'pause';
    document.querySelectorAll('[data-r="seek"],#rPause,[data-r="stop"]').forEach((b) => { b.disabled = !st; });
    if (st && !R.volTimer) { $('#rVol').value = st.volume; $('#rVolV').textContent = st.volume; }
    box.classList.remove('hidden');
    if (first) { $('#rErr').classList.add('hidden'); setTimeout(() => $('#rUrl').focus(), 50); }
}
function play() {
    const url = $('#rUrl').value;
    if (!youtubeId(url)) { const e = $('#rErr'); e.textContent = 'Ce n\'est pas un lien YouTube valide.'; e.classList.remove('hidden'); return; }
    $('#rErr').classList.add('hidden');
    post('remote', { cmd: 'play', url });
}
document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-r]');
    if (!b || b.disabled) return;
    const cmd = b.dataset.r;
    if (cmd === 'play') return play();
    if (cmd === 'seek') return post('remote', { cmd, by: Number(b.dataset.by) });
    post('remote', { cmd });
});
$('#rUrl').addEventListener('keydown', (e) => { if (e.key === 'Enter') play(); });
$('#rVol').addEventListener('input', (e) => {
    $('#rVolV').textContent = e.target.value;
    clearTimeout(R.volTimer);
    R.volTimer = setTimeout(() => { R.volTimer = null; post('remote', { cmd: 'volume', v: Number(e.target.value) }); }, 250);
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && R.open) post('remote', { cmd: 'close' }); });

function renderEditor(m) {
    const bar = $('#editor');
    if (!m.open) { bar.classList.add('hidden'); return; }
    $('#eName').textContent = m.name || 'Écran';
    $('#eSize').textContent = `· ${Number(m.w).toFixed(2)} × ${Number(m.h).toFixed(2)} m · orientation ${Math.round(((m.heading % 360) + 360) % 360)}°`;
    bar.classList.remove('hidden');
}

window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    if (m.action === 'remote') renderRemote(m);
    else if (m.action === 'editor') renderEditor(m);
});
