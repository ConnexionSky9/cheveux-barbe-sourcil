/* =====================================================================
   ELYZEA RESTAURANT - stations de cuisine et mini-jeux
   1) Liste des produits de MES commandes que la station sait préparer.
   2) Mini-jeu : paramètres fournis par le serveur (zones, recette…), le joueur
      ne renvoie que ses réponses ; le serveur les vérifie (shared/games.lua).
   Ajouter un mini-jeu : Kitchen.register('nom', { hint, start(stage, params, api) })
   (start renvoie une fonction de nettoyage ; api.done(résultat) / api.fail(raison)),
   plus la même entrée dans shared/games.lua.
   ===================================================================== */
(() => {
  const K = { data: null, game: null, run: null, cleanup: null, timer: null, last: null };
  const GAMES = {};
  const root = () => $('#kitchen .modal');
  const emptyBox = (t) => `<div class="empty">${esc(t)}</div>`;
  const stars = (n) => '★'.repeat(n || 1) + '☆'.repeat(Math.max(0, 3 - (n || 1)));

  const ING = {
    bun_bottom: ['🍞', 'Pain (bas)'], bun_top: ['🥯', 'Pain (haut)'], patty: ['🥩', 'Steak'], cheese: ['🧀', 'Cheddar'], salad: ['🥬', 'Salade'],
    tomato: ['🍅', 'Tomate'], onion: ['🧅', 'Oignon'], bacon: ['🥓', 'Bacon'], sauce: ['🥫', 'Sauce'], pickles: ['🥒', 'Cornichons'],
    cream: ['🍦', 'Crème'], caramel: ['🍯', 'Caramel'], chocolate: ['🍫', 'Chocolat'], strawberry: ['🍓', 'Fraise'], nuts: ['🥜', 'Noisettes'],
    vanilla: ['🌼', 'Vanille'], sprinkles: ['✨', 'Vermicelles'], mint: ['🌿', 'Menthe'], biscuit: ['🍪', 'Biscuit'], honey: ['🐝', 'Miel'],
    banana: ['🍌', 'Banane'], coconut: ['🥥', 'Noix de coco'],
  };
  const ing = (k) => ING[k] || ['❔', k];

  /* ---------- Outils communs ---------- */
  // Aiguille en aller-retour sur 0-100 ; stop() rend la position
  function needle(elNeedle, speed) {
    const t0 = performance.now();
    let raf = 0, pos = 0, stopped = false;
    const tick = (t) => {
      if (stopped) return;
      const ph = ((t - t0) / 1000) * speed;
      const f = ph % 1;
      pos = (Math.floor(ph) % 2 === 0 ? f : 1 - f) * 100;
      elNeedle.style.left = `${pos}%`;
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return { stop() { stopped = true; cancelAnimationFrame(raf); return Math.round(pos * 10) / 10; }, kill() { stopped = true; cancelAnimationFrame(raf); } };
  }
  function onKey(fn) {
    const h = (e) => { if (e.code === 'Space' || e.key === ' ') { e.preventDefault(); fn(); } };
    document.addEventListener('keydown', h);
    return () => document.removeEventListener('keydown', h);
  }
  const gaugeHTML = (z) => `<div class="gauge"><div class="zone" style="left:${z.from}%;width:${z.to - z.from}%"></div><div class="needle"></div></div>`;
  const inZone = (z, v) => v >= z.from && v <= z.to;

  /* ---------- Burger : cuisson puis montage ---------- */
  GAMES.burger = {
    hint: 'Arrêtez l\'aiguille dans la zone verte (clic ou Espace), puis montez le burger dans l\'ordre de la fiche.',
    start(stage, p, api) {
      const res = { gauge: [], seq: [] };
      let n = null, off = () => {}, phase = 'cook', idx = 0;
      const cook = () => {
        const z = p.cook[idx];
        stage.innerHTML = `<div class="mg-hint">🔥 Cuisson du steak ${idx + 1} / ${p.cook.length}</div>${gaugeHTML(z)}<button class="btn primary" data-act="1">Retourner (Espace)</button>`;
        n = needle($('.needle', stage), z.speed);
      };
      const hit = () => {
        if (phase !== 'cook' || !n) return;
        const v = n.stop(); n = null;
        if (!inZone(p.cook[idx], v)) return api.fail(v > p.cook[idx].to ? 'Steak trop cuit.' : 'Steak pas assez cuit.');
        res.gauge.push(v);
        idx += 1;
        if (idx < p.cook.length) return cook();
        phase = 'build';
        build();
      };
      const build = () => {
        const s = res.seq.length;
        stage.innerHTML = `<div class="mg-hint">🍔 Montez le burger : fiche de bas en haut</div>
          <div class="recipe">${p.recipe.map((k, i) => `<span class="${i < s ? 'done' : i === s ? 'next' : ''}">${ing(k)[0]} ${esc(ing(k)[1])}</span>`).join('')}</div>
          <div class="stack-burger">${res.seq.map((k) => `<span>${ing(k)[0]}</span>`).join('')}</div>
          <div class="palette">${p.palette.map((k) => `<button class="ing" data-ing="${k}"><span class="e">${ing(k)[0]}</span>${esc(ing(k)[1])}</button>`).join('')}</div>`;
      };
      const click = (e) => {
        if (e.target.closest('[data-act]')) return hit();
        const b = e.target.closest('[data-ing]');
        if (!b || phase !== 'build') return;
        const k = b.dataset.ing;
        if (k !== p.recipe[res.seq.length]) return api.fail('Mauvais ingrédient : regardez la fiche.');
        res.seq.push(k);
        if (res.seq.length === p.recipe.length) return api.done(res);
        build();
      };
      stage.addEventListener('click', click);
      off = onKey(hit);
      cook();
      return () => { stage.removeEventListener('click', click); off(); if (n) n.kill(); };
    },
  };

  /* ---------- Pizza : garniture sur les repères puis cuisson ---------- */
  GAMES.pizza = {
    hint: 'Posez la garniture sur chaque repère (clic), puis arrêtez la cuisson dans la zone verte.',
    start(stage, p, api) {
      const res = { spots: [] };
      let n = null, off = () => {}, phase = 'top';
      stage.innerHTML = `<div class="mg-hint">🍕 Garniture : ${p.spots.length} repère(s)</div><div class="pizza">${p.spots.map((s) => `<i class="spot" style="left:${s.x}%;top:${s.y}%"></i>`).join('')}</div>`;
      const pizza = $('.pizza', stage);
      const used = new Set();
      const place = (e) => {
        if (phase !== 'top') return;
        const r = pizza.getBoundingClientRect();
        const x = Math.round(((e.clientX - r.left) / r.width) * 1000) / 10, y = Math.round(((e.clientY - r.top) / r.height) * 1000) / 10;
        const hitI = p.spots.findIndex((s, i) => !used.has(i) && (s.x - x) ** 2 + (s.y - y) ** 2 <= p.tol ** 2);
        if (hitI < 0) return api.fail('Garniture à côté du repère.');
        used.add(hitI);
        res.spots.push({ x, y });
        pizza.insertAdjacentHTML('beforeend', `<span class="top" style="left:${x}%;top:${y}%">${['🍅', '🧀', '🍄', '🫑', '🥓'][res.spots.length % 5]}</span>`);
        if (res.spots.length === p.spots.length) { phase = 'bake'; setTimeout(bake, 250); }
      };
      const bake = () => {
        stage.innerHTML = `<div class="mg-hint">🔥 Cuisson au four</div>${gaugeHTML(p.bake)}<button class="btn primary" data-act="1">Sortir du four (Espace)</button>`;
        n = needle($('.needle', stage), p.bake.speed);
      };
      const hit = () => {
        if (phase !== 'bake' || !n) return;
        const v = n.stop(); n = null;
        if (!inZone(p.bake, v)) return api.fail(v > p.bake.to ? 'Pizza brûlée.' : 'Pizza pas assez cuite.');
        res.gauge = v;
        api.done(res);
      };
      const click = (e) => { if (e.target.closest('[data-act]')) return hit(); if (e.target.closest('.pizza')) place(e); };
      stage.addEventListener('click', click);
      off = onKey(hit);
      return () => { stage.removeEventListener('click', click); off(); if (n) n.kill(); };
    },
  };

  /* ---------- Boisson : remplir jusqu'au trait ---------- */
  GAMES.drink = {
    hint: 'Maintenez « Remplir » (ou Espace) et relâchez dans la zone verte. Ne débordez pas !',
    start(stage, p, api) {
      let level = 0, filling = false, raf = 0, last = 0, ended = false;
      stage.innerHTML = `<div class="glass"><div class="band" style="bottom:${p.from}%;height:${p.to - p.from}%"></div><div class="liquid" style="height:0%"></div></div>
        <div class="actions" style="margin:0"><button class="btn" data-fill="1">Remplir (maintenir)</button><button class="btn primary" data-serve="1">Servir</button></div>`;
      const liq = $('.liquid', stage);
      const tick = (t) => {
        if (!filling || ended) return;
        level = Math.min(100, level + ((t - last) / 1000) * p.rate);
        last = t;
        liq.style.height = `${level}%`;
        if (level >= 100) { ended = true; return api.fail('Le verre a débordé.'); }
        raf = requestAnimationFrame(tick);
      };
      const startFill = () => { if (filling || ended) return; filling = true; last = performance.now(); raf = requestAnimationFrame(tick); };
      const stopFill = () => { filling = false; cancelAnimationFrame(raf); };
      const serve = () => {
        if (ended) return;
        stopFill();
        ended = true;
        const v = Math.round(level * 10) / 10;
        if (v < p.from || v > p.to) return api.fail(v > p.to ? 'Trop rempli.' : 'Pas assez rempli.');
        api.done({ level: v });
      };
      const fillBtn = $('[data-fill]', stage);
      fillBtn.addEventListener('mousedown', startFill);
      document.addEventListener('mouseup', stopFill);
      const kd = (e) => { if (e.code === 'Space') { e.preventDefault(); startFill(); } };
      const ku = (e) => { if (e.code === 'Space') { e.preventDefault(); stopFill(); } };
      document.addEventListener('keydown', kd);
      document.addEventListener('keyup', ku);
      const click = (e) => { if (e.target.closest('[data-serve]')) serve(); };
      stage.addEventListener('click', click);
      return () => { ended = true; stopFill(); document.removeEventListener('mouseup', stopFill); document.removeEventListener('keydown', kd); document.removeEventListener('keyup', ku); stage.removeEventListener('click', click); };
    },
  };

  /* ---------- Dessert : bons ingrédients (dans l'ordre en difficile) ---------- */
  GAMES.dessert = {
    hint: 'Choisissez exactement les ingrédients de la fiche, puis « Valider ».',
    start(stage, p, api) {
      const picked = [];
      const draw = () => {
        stage.innerHTML = `<div class="mg-hint">🍰 Fiche${p.ordered ? ' (dans l\'ordre)' : ''} :</div>
          <div class="recipe">${p.need.map((k) => `<span class="${picked.includes(k) ? 'done' : ''}">${ing(k)[0]} ${esc(ing(k)[1])}</span>`).join('')}</div>
          <div class="palette">${p.shown.map((k) => `<button class="ing ${picked.includes(k) ? 'on' : ''}" data-ing="${k}"><span class="e">${ing(k)[0]}</span>${esc(ing(k)[1])}</button>`).join('')}</div>
          <button class="btn primary" data-ok="1" ${picked.length !== p.need.length ? 'disabled' : ''}>Valider</button>`;
      };
      const click = (e) => {
        let b;
        if ((b = e.target.closest('[data-ing]'))) {
          const k = b.dataset.ing, i = picked.indexOf(k);
          if (i >= 0) picked.splice(i, 1); else if (picked.length < p.need.length) picked.push(k);
          return draw();
        }
        if (e.target.closest('[data-ok]')) {
          const ok = p.ordered ? p.need.every((k, i) => picked[i] === k) : p.need.every((k) => picked.includes(k));
          if (!ok) return api.fail(p.ordered ? 'Mauvais ingrédients ou mauvais ordre.' : 'Mauvais ingrédients.');
          api.done({ picked: picked.slice() });
        }
      };
      stage.addEventListener('click', click);
      draw();
      return () => stage.removeEventListener('click', click);
    },
  };

  /* ---------- Frites : sortir le panier quand elles sont dorées ---------- */
  GAMES.fries = {
    hint: 'Plongez le panier, puis sortez-le quand l\'aiguille est dans la zone dorée (clic ou Espace).',
    start(stage, p, api) {
      let raf = 0, t0 = 0, pos = 0, phase = 'wait';
      stage.innerHTML = `<div class="fryer"><div class="fry-bar"><div class="zone" style="left:${p.from}%;width:${p.to - p.from}%"></div><div class="needle" style="left:0%"></div></div></div>
        <button class="btn primary" data-act="1">Plonger le panier (Espace)</button>`;
      const nd = $('.needle', stage), btn = $('[data-act]', stage);
      const tick = (t) => {
        if (phase !== 'cook') return;
        pos = Math.min(100, ((t - t0) / p.cookMs) * 100);
        nd.style.left = `${pos}%`;
        if (pos >= 100) { phase = 'end'; return api.fail('Frites brûlées.'); }
        raf = requestAnimationFrame(tick);
      };
      const act = () => {
        if (phase === 'wait') { phase = 'cook'; t0 = performance.now(); btn.textContent = 'Sortir le panier (Espace)'; raf = requestAnimationFrame(tick); return; }
        if (phase !== 'cook') return;
        phase = 'end';
        cancelAnimationFrame(raf);
        const v = Math.round(pos * 10) / 10;
        if (v < p.from || v > p.to) return api.fail(v > p.to ? 'Frites trop cuites.' : 'Frites pas assez cuites.');
        api.done({ t: v });
      };
      const click = (e) => { if (e.target.closest('[data-act]')) act(); };
      stage.addEventListener('click', click);
      const off = onKey(act);
      return () => { phase = 'end'; cancelAnimationFrame(raf); stage.removeEventListener('click', click); off(); };
    },
  };

  /* ---------- Écrans ---------- */
  function stopGame() {
    if (K.cleanup) { try { K.cleanup(); } catch (e) { /* rien */ } }
    K.cleanup = null;
    clearInterval(K.timer); K.timer = null;
  }
  function drawPick() {
    stopGame();
    const d = K.data || {};
    root().innerHTML = `<div class="modal-head" style="display:flex;justify-content:space-between;align-items:center;margin-bottom:.8rem"><div><div class="eyebrow">Station</div><h2>${esc(d.label || 'Cuisine')}</h2></div>
        <button class="icon-btn" data-k="close" aria-label="Fermer">✕</button></div>
      ${(d.list || []).map((x, i) => `<button class="k-pick" data-pick="${i}"><img src="${esc(imgUrl(x.image))}" alt="" data-emo="🍽️"><span><b>${esc(x.label)}</b>
        <small>Commande ${esc(x.num)} · ${x.done} / ${x.qty} prêt(s) · ${esc(x.gameLabel || '')}</small></span><span class="diff" title="Difficulté">${stars(x.difficulty)}</span></button>`).join('')
        || emptyBox(d.empty || 'Rien à préparer ici.')}`;
    root().querySelectorAll('img[data-emo]').forEach((im) => im.addEventListener('error', () => { const s = document.createElement('span'); s.className = 'emo'; s.textContent = im.dataset.emo; im.replaceWith(s); }, { once: true }));
  }
  async function start(x) {
    K.last = x;
    const r = await post('cookStart', { station: K.data.station, order: x.order, line: x.line });
    if (r.error) { toast(r.error, false); return refresh(); }
    const G = GAMES[r.game];
    if (!G) { toast(`Mini-jeu « ${r.game} » absent de l'interface.`, false); return; }
    K.run = r;
    let finished = false;
    root().innerHTML = `<div class="mg-top"><div><div class="eyebrow">Commande ${esc(r.num)} · ${stars(r.difficulty)}</div><h2>${esc(r.label)}${r.units > 1 ? ` × ${r.units}` : ''}</h2></div>
        <button class="icon-btn" data-k="abort" aria-label="Abandonner">✕</button></div>
      <div class="mg-timer"><i style="width:100%"></i></div><p class="mg-hint">${esc(G.hint)}</p><div class="mg-stage"></div>`;
    const stage = $('.mg-stage', root()), bar = $('.mg-timer i', root());
    const end = Date.now() + r.duration * 1000;
    const api = {
      done: (result) => { if (finished) return; finished = true; finish({ token: r.token, result }); },
      fail: (why) => { if (finished) return; finished = true; finish({ token: r.token, fail: true }, why); },
    };
    K.timer = setInterval(() => {
      const left = end - Date.now();
      bar.style.width = `${Math.max(0, (left / (r.duration * 1000)) * 100)}%`;
      if (left <= 0) api.fail('Temps écoulé.');
    }, 100);
    K.cleanup = G.start(stage, r.params, api);
  }
  async function finish(body, localWhy) {
    stopGame();
    const r = await post('cookFinish', body);
    K.run = null;
    const ok = r.ok === true;
    const msg = r.error || (localWhy && !ok ? `Raté : ${localWhy} Rien n'est préparé, recommencez.` : r.message) || '';
    root().innerHTML = `<div class="mg-result"><div class="big">${ok ? '✅' : '❌'}</div><h2>${ok ? (r.complete ? 'Commande terminée !' : 'Réussi !') : 'Raté'}</h2><p>${esc(msg)}</p>
      <div class="actions" style="justify-content:center">${!ok && K.last ? '<button class="btn primary" data-k="retry">Recommencer</button>' : ''}
        ${!r.complete ? '<button class="btn" data-k="back">Autres produits</button>' : ''}<button class="btn" data-k="close">Fermer</button></div></div>`;
    if (ok) toast(msg, true);
  }
  async function refresh() {
    const r = await post('stationOptions', { station: K.data.station });
    if (r.error) { toast(r.error, false); return post('close', { ui: 'kitchen' }); }
    K.data = r;
    drawPick();
  }

  $('#kitchen').addEventListener('click', (e) => {
    let b;
    if ((b = e.target.closest('[data-pick]'))) return start(K.data.list[Number(b.dataset.pick)]);
    if ((b = e.target.closest('[data-k]'))) {
      const a = b.dataset.k;
      if (a === 'close') return post('close', { ui: 'kitchen' });
      if (a === 'back') return refresh();
      if (a === 'retry' && K.last) return start(K.last);
      if (a === 'abort' && K.run) return finish({ token: K.run.token, fail: true }, 'Préparation abandonnée.');
    }
  });

  window.Kitchen = {
    register(name, def) { GAMES[name] = def; },
    games: GAMES,
    open(d) { K.data = d; $('#kitchen').classList.remove('hidden'); drawPick(); },
    hide() { stopGame(); K.data = null; K.run = null; $('#kitchen').classList.add('hidden'); },
    isOpen: () => !$('#kitchen').classList.contains('hidden'),
  };
})();
