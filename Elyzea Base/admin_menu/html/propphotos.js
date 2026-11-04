/* =========================================================
   ÉDITEUR DE MAP - IMAGES DES PROPS
   1. image enregistrée (props/<modèle>.webp, servie après un redémarrage) ;
   2. sinon le jeu la fournit : image gardée par le serveur, ou PHOTO prise tout de suite
      en jeu (studio fond vert, client/propphotos.lua) ;
   3. sinon l'image du site de référence (CATALOG.propImage) ;
   4. sinon « Voir en 3D ».
   Ici aussi : détourage des photos (fond vert → transparent, carré, webp).
   ========================================================= */
(() => {
    const mem = {};   // [modèle] = src trouvée
    const work = document.createElement('canvas');
    const outc = document.createElement('canvas');

    // Survol : appelé par l'image locale quand elle n'existe pas encore
    window.ppFallback = (img, name) => {
        if (!img || img.dataset.pp === 'done') return;
        img.dataset.pp = 'done';
        const box = img.parentElement;
        const noimg = box && box.querySelector('.cat-noimg');
        const set = (src) => { img.onerror = () => remote(); img.src = src; img.style.display = ''; if (noimg) noimg.style.display = 'none'; };
        const remote = () => {
            const tpl = window.CATALOG && CATALOG.propImage;
            if (tpl && img.dataset.remote !== '1') {
                img.dataset.remote = '1';
                img.onerror = () => { img.style.display = 'none'; if (noimg) { noimg.style.display = 'flex'; } };
                img.src = tpl.replace('{name}', name);
            } else { img.style.display = 'none'; if (noimg) noimg.style.display = 'flex'; }
        };
        if (mem[name]) return set(mem[name]);
        img.style.display = 'none';
        if (noimg) { noimg.style.display = 'flex'; noimg.innerHTML = '<span class="pp-spin"></span><small>Photo du prop en cours…</small>'; }
        // On attend que le curseur reste sur le prop avant de prendre la photo
        setTimeout(async () => {
            const pv = document.getElementById('cat-preview');
            if (!pv || pv.dataset.shown !== name) return;
            const r = await post('propThumb', { model: name });
            const still = document.getElementById('cat-preview');
            if (r && r.src) { mem[name] = r.src; if (still && still.dataset.shown === name && img.isConnected) set(r.src); return; }
            if (!img.isConnected) return;
            if (noimg) noimg.innerHTML = `<span>📦</span><small>${r && r.busy ? 'Une photo est déjà en cours…' : r && r.noCapture ? 'Pas d\'outil de capture (screencapture) :<br>utilise « Voir en 3D »' : 'Pas d\'image pour ce modèle :<br>utilise « Voir en 3D »'}</small>`;
            remote();
        }, 280);
    };

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'ppProgress') {
            const b = document.querySelector('[data-ppall]');
            if (b) b.textContent = m.finished ? `📸 Images créées (${m.done})` : `📸 ${m.done} / ${m.total}…`;
            return;
        }
        if (m.action !== 'ppProcess') return;
        const img = new Image();
        img.onload = () => {
            // Recadrage sur l'objet : on garde le carré central, on retire le fond vert
            const side = Math.round(Math.min(img.width, img.height) * 0.9);
            const sx = Math.round((img.width - side) / 2), sy = Math.round((img.height - side) / 2);
            work.width = work.height = side;
            const w = work.getContext('2d', { willReadFrequently: true });
            w.drawImage(img, sx, sy, side, side, 0, 0, side, side);
            const px = w.getImageData(0, 0, side, side), d = px.data;
            for (let i = 0; i < d.length; i += 4) {
                const r = d[i], g = d[i + 1], b = d[i + 2], mx = Math.max(r, b);
                if (g > 90 && g > mx * 1.35) d[i + 3] = 0;
                else if (g > mx) d[i + 1] = mx;
            }
            w.putImageData(px, 0, 0);
            outc.width = outc.height = m.size;
            const o = outc.getContext('2d');
            o.clearRect(0, 0, m.size, m.size);
            o.imageSmoothingQuality = 'high';
            o.drawImage(work, 0, 0, m.size, m.size);
            const url = outc.toDataURL('image/webp', m.quality);
            post('ppProcessed', { id: m.id, data: url.split(',')[1] || '' });
        };
        img.onerror = () => post('ppProcessed', { id: m.id, data: '' });
        img.src = m.data;
    });

    document.addEventListener('click', (e) => {
        const b = e.target.closest('[data-ppall]');
        if (!b) return;
        const models = [];
        (window.CATALOG && CATALOG.props || []).forEach((g) => g.items.forEach((n) => models.push(n)));
        b.textContent = '📸 Recherche des images manquantes…';
        post('propThumbAll', { models });
    });
})();
