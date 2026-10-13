/* =====================================================================
   BANK HEIST - mini-jeux de piratage (affichage seulement)
   Les énigmes viennent du serveur et les réponses y sont vérifiées.
   Chaque jeu : Games.<nom>(élément, données, api) avec
     api.submit(réponse)  -> envoie la réponse finale au serveur
     api.guess(chiffres)  -> (jeu « code ») essai vérifié par le serveur
   ===================================================================== */
(() => {
  const SYM = ['◆', '▲', '●', '■', '✚', '★', '⬢', '✖', '◐'];
  const h = (s) => { const d = document.createElement('div'); d.innerHTML = s.trim(); return d.firstChild; };

  // 1. Séquence de symboles : mémoriser puis reproduire
  function sequence(el, d, api) {
    const answer = [];
    el.innerHTML = `<h2>Séquence de symboles</h2><p class="rule">Mémorisez la séquence, puis reproduisez-la dans le même ordre.</p>
      <div class="row" id="sq"></div><div class="grid3" id="pad"></div><div class="row"><button class="tbtn" id="del">EFFACER</button></div>`;
    const sq = el.querySelector('#sq'); const pad = el.querySelector('#pad');
    sq.innerHTML = d.seq.map((v) => `<div class="chip">${SYM[v - 1]}</div>`).join('');
    pad.innerHTML = SYM.map((s, i) => `<div class="sym" data-v="${i + 1}">${s}</div>`).join('');
    let locked = true;
    pad.style.opacity = '.3';
    setTimeout(() => { sq.innerHTML = '<span class="rule">À vous.</span>'; pad.style.opacity = '1'; locked = false; }, d.show);
    const redraw = () => { sq.innerHTML = answer.map((v) => `<div class="chip">${SYM[v - 1]}</div>`).join('') + `<span class="rule">${answer.length}/${d.seq.length}</span>`; };
    pad.addEventListener('click', (e) => {
      const n = e.target.closest('[data-v]'); if (!n || locked) return;
      n.classList.add('lit'); setTimeout(() => n.classList.remove('lit'), 140);
      answer.push(Number(n.dataset.v)); redraw();
      if (answer.length >= d.seq.length) { locked = true; api.submit({ seq: answer }); }
    });
    el.querySelector('#del').onclick = () => { if (!locked && answer.length) { answer.pop(); redraw(); } };
  }

  // 2. Connexion de circuits : relier les nœuds par valeur croissante
  function circuit(el, d, api) {
    const order = [];
    el.innerHTML = `<h2>Connexion de circuits</h2><p class="rule">Reliez les nœuds dans l'ordre CROISSANT de leur valeur.${d.hideAfter ? ' Les valeurs vont s\'effacer : mémorisez-les.' : ''}</p>
      <div class="board"><svg></svg></div><div class="row"><button class="tbtn" id="rst">RECOMMENCER</button></div>`;
    const board = el.querySelector('.board'); const svg = el.querySelector('svg');
    const pos = (n) => ({ x: 50 + n.x * 100, y: 40 + n.y * 83 });
    d.nodes.forEach((n) => {
      const p = pos(n);
      const nd = h(`<div class="node" data-id="${n.id}" style="left:${p.x}px;top:${p.y}px">${n.label}</div>`);
      board.appendChild(nd);
    });
    if (d.hideAfter) setTimeout(() => board.querySelectorAll('.node').forEach((x) => { if (!x.classList.contains('done')) x.textContent = '?'; }), d.hideAfter);
    const draw = () => {
      svg.innerHTML = order.slice(1).map((id, i) => {
        const a = pos(d.nodes[order[i] - 1]); const b = pos(d.nodes[id - 1]);
        return `<line x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" stroke="#39ff8c" stroke-width="3" stroke-dasharray="6 4"/>`;
      }).join('');
    };
    board.addEventListener('click', (e) => {
      const n = e.target.closest('[data-id]'); if (!n || n.classList.contains('done')) return;
      n.classList.add('done'); n.textContent = d.nodes[Number(n.dataset.id) - 1].label;
      order.push(Number(n.dataset.id)); draw();
      if (order.length === d.nodes.length) api.submit({ order });
    });
    el.querySelector('#rst').onclick = () => {
      order.length = 0; draw();
      board.querySelectorAll('.node').forEach((x) => { x.classList.remove('done'); x.textContent = d.hideAfter ? '?' : d.nodes[Number(x.dataset.id) - 1].label; });
    };
  }

  // 3. Déchiffrement de code : chiffres tous différents ; indices du serveur
  function code(el, d, api) {
    el.innerHTML = `<h2>Déchiffrement de code</h2><p class="rule">Code de ${d.length} chiffres tous différents. ● = bon chiffre bien placé · ○ = bon chiffre mal placé. ${d.guesses} essais.</p>
      <div class="digits">${Array.from({ length: d.length }, (_, i) => `<input class="digit" maxlength="1" data-i="${i}">`).join('')}</div>
      <button class="tbtn" id="try">ESSAYER</button><div class="hist" id="hist"></div>`;
    const inputs = [...el.querySelectorAll('.digit')]; const hist = el.querySelector('#hist');
    inputs[0].focus();
    inputs.forEach((inp, i) => inp.addEventListener('input', () => { inp.value = inp.value.replace(/[^0-9]/g, ''); if (inp.value && inputs[i + 1]) inputs[i + 1].focus(); }));
    inputs.forEach((inp, i) => inp.addEventListener('keydown', (e) => { if (e.key === 'Backspace' && !inp.value && inputs[i - 1]) inputs[i - 1].focus(); if (e.key === 'Enter') el.querySelector('#try').click(); }));
    let busy = false;
    el.querySelector('#try').onclick = async () => {
      const g = inputs.map((x) => x.value);
      if (busy || g.some((v) => v === '')) return;
      busy = true;
      const r = await api.guess(g.map(Number));
      busy = false;
      if (r.error) return;
      hist.insertAdjacentHTML('afterbegin', `<div><span>${g.join(' ')}</span><span>${'●'.repeat(r.exact)}${'○'.repeat(r.near || 0)}${r.left !== undefined ? ` · ${r.left} essai(s)` : ''}</span></div>`);
      inputs.forEach((x) => { x.value = ''; }); inputs[0].focus();
    };
  }

  // 4. Synchronisation : arrêter chaque curseur dans la zone (ESPACE ou bouton)
  function sync(el, d, api) {
    el.innerHTML = `<h2>Synchronisation</h2><p class="rule">Arrêtez chaque curseur dans la zone verte (ESPACE ou STOP).</p>
      <div class="sync">${d.bars.map((b, i) => `<div class="track ${i ? 'off' : ''}" data-i="${i}"><div class="zone" style="left:${b.from * 100}%;width:${(b.to - b.from) * 100}%"></div><div class="cur"></div></div>`).join('')}</div>
      <button class="tbtn" id="stop">STOP</button>`;
    const tracks = [...el.querySelectorAll('.track')]; const times = [];
    let i = 0; let start = performance.now(); let raf;
    const tri = (t, s) => { const x = (t * s) % 2; return x <= 1 ? x : 2 - x; };
    const tick = (now) => {
      if (i >= d.bars.length) return;
      const t = (now - start) / 1000;
      tracks[i].querySelector('.cur').style.left = `${tri(t, d.bars[i].speed) * 100}%`;
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    const stop = () => {
      if (i >= d.bars.length) return;
      const ms = performance.now() - start; times.push(Math.round(ms));
      const b = d.bars[i]; const p = tri(ms / 1000, b.speed);
      tracks[i].querySelector('.cur').style.left = `${p * 100}%`;
      if (p >= b.from && p <= b.to) tracks[i].classList.add('ok');
      i += 1;
      if (i < d.bars.length) { tracks[i].classList.remove('off'); start = performance.now(); }
      else { cancelAnimationFrame(raf); document.removeEventListener('keydown', key); api.submit({ times }); }
    };
    const key = (e) => { if (e.code === 'Space') { e.preventDefault(); stop(); } };
    document.addEventListener('keydown', key);
    el.querySelector('#stop').onclick = stop;
    el._cleanup = () => { cancelAnimationFrame(raf); document.removeEventListener('keydown', key); };
  }

  // 5. Décryptage de données : trouver le terme suivant de chaque suite
  function logic(el, d, api) {
    el.innerHTML = `<h2>Décryptage de données</h2><p class="rule">Trouvez le nombre suivant de chaque suite.</p>
      ${d.rows.map((r, i) => `<div class="seqrow">${r.map((v) => `<span>${v}</span>`).join('')}<span>→</span><input data-i="${i}" inputmode="numeric"></div>`).join('')}
      <button class="tbtn" id="ok">VALIDER</button>`;
    const inputs = [...el.querySelectorAll('input')]; inputs[0].focus();
    inputs.forEach((x) => x.addEventListener('input', () => { x.value = x.value.replace(/[^0-9-]/g, ''); }));
    inputs.forEach((x, i) => x.addEventListener('keydown', (e) => { if (e.key === 'Enter') { if (inputs[i + 1]) inputs[i + 1].focus(); else el.querySelector('#ok').click(); } }));
    el.querySelector('#ok').onclick = () => {
      if (inputs.some((x) => x.value === '')) return;
      api.submit({ answers: inputs.map((x) => Number(x.value)) });
    };
  }

  window.Games = { sequence, circuit, code, sync, logic };
})();
