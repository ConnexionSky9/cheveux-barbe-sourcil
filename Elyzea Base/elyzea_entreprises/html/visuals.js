/* =========================================================
   ELYZEA · Visuels des produits (borne, préparation, suivi)
   Burgers dessinés couche par couche (assemblés en direct),
   boissons (gobelet, verre, milkshake, café), image de l'objet sinon.
   ========================================================= */
const Viz = (() => {
    let uid = 0;
    const W = 240;

    // Chaque couche : hauteur et dessin (y = haut de la couche)
    const L = {
        pain_bas: { h: 24, d: (y, h, id) => `<rect x="26" y="${y}" width="188" height="${h}" rx="11" fill="url(#bunB${id})"/>
            <rect x="30" y="${y}" width="180" height="5" rx="2.5" fill="#f2c27a" opacity=".55"/>` },
        pain_milieu: { h: 14, d: (y, h, id) => `<rect x="28" y="${y}" width="184" height="${h}" rx="7" fill="url(#bunB${id})"/>` },
        pain_haut: { h: 60, d: (y, h, id) => `<path d="M22 ${y + h - 6} Q22 ${y + 2} 120 ${y} Q218 ${y + 2} 218 ${y + h - 6} Q218 ${y + h} 210 ${y + h} L30 ${y + h} Q22 ${y + h} 22 ${y + h - 6} Z" fill="url(#bunT${id})"/>
            <path d="M40 ${y + 20} Q80 ${y + 6} 120 ${y + 5}" stroke="#ffe3ad" stroke-width="5" stroke-linecap="round" fill="none" opacity=".5"/>
            ${[[70, 18, -20], [98, 12, 10], [128, 11, -8], [156, 16, 25], [84, 30, 40], [116, 26, -30], [146, 29, 15], [178, 30, -15], [60, 36, 5]]
                .map(([x, dy, r]) => `<ellipse cx="${x}" cy="${y + dy}" rx="4.5" ry="2.3" fill="#fff6dc" transform="rotate(${r} ${x} ${y + dy})"/>`).join('')}` },
        steak: { h: 22, d: (y, h) => `<rect x="18" y="${y}" width="204" height="${h}" rx="11" fill="#5b2f1b"/>
            <path d="M34 ${y + 7} h40 M90 ${y + 12} h50 M156 ${y + 7} h44 M48 ${y + 16} h28" stroke="#3a1c0f" stroke-width="3" stroke-linecap="round"/>
            <rect x="24" y="${y + 1}" width="192" height="4" rx="2" fill="#7c4428"/>` },
        poulet: { h: 24, d: (y, h) => `<rect x="16" y="${y}" width="208" height="${h}" rx="12" fill="#d48e2c"/>
            ${[30, 52, 74, 96, 118, 140, 162, 184, 206].map((x, i) => `<circle cx="${x}" cy="${y + 4 + (i % 2) * 3}" r="7" fill="#e8ab48"/>`).join('')}
            ${[44, 88, 132, 176].map((x) => `<circle cx="${x}" cy="${y + 15}" r="3" fill="#b8741f"/>`).join('')}` },
        galette: { h: 20, d: (y, h) => `<rect x="20" y="${y}" width="200" height="${h}" rx="10" fill="#7a8a37"/>
            ${[40, 70, 100, 130, 160, 190].map((x, i) => `<circle cx="${x}" cy="${y + 7 + (i % 3) * 3}" r="3.5" fill="${i % 2 ? '#e0a03a' : '#a9bc52'}"/>`).join('')}` },
        cheddar: { h: 7, d: (y) => `<path d="M20 ${y} H220 V${y + 7} H198 L190 ${y + 20} L182 ${y + 7} H120 L112 ${y + 17} L104 ${y + 7} H58 L50 ${y + 22} L42 ${y + 7} H20 Z" fill="#f6b51e"/>` },
        salade: { h: 11, d: (y) => { let p = `M14 ${y + 6}`; for (let x = 14; x < 226; x += 16) p += ` q8 -10 16 0`; return `<path d="${p} V${y + 11} H14 Z" fill="#5cb83a" stroke="#3d8f26" stroke-width="1.5"/>`; } },
        tomate: { h: 9, d: (y, h) => [[22, 66], [88, 66], [154, 66]].map(([x, w]) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="4.5" fill="#d93a2f"/>
            <rect x="${x + 8}" y="${y + 2}" width="${w - 16}" height="3" rx="1.5" fill="#f2786c"/>`).join('') },
        oignon: { h: 6, d: (y, h) => [[24, 60], [92, 58], [158, 60]].map(([x, w]) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="3" fill="#f4e4f0" stroke="#b56aa1" stroke-width="1.5"/>`).join('') },
        bacon: { h: 9, d: (y) => { let p = `M18 ${y + 5}`; for (let x = 18; x < 222; x += 34) p += ` q8.5 -7 17 0 t17 0`; return `<path d="${p}" stroke="#a63f2a" stroke-width="8" fill="none" stroke-linecap="round"/><path d="${p}" stroke="#eba08b" stroke-width="2" fill="none"/>`; } },
        cornichon: { h: 6, d: (y) => [40, 80, 120, 160, 200].map((x) => `<ellipse cx="${x}" cy="${y + 3}" rx="15" ry="3.5" fill="#6d8f2a" stroke="#4b6a17"/>`).join('') },
        sauce: { h: 5, d: (y) => `<path d="M24 ${y + 2} H216 V${y + 4} H170 Q166 ${y + 12} 162 ${y + 4} H86 Q82 ${y + 10} 78 ${y + 4} H24 Z" fill="#f3e2a2"/>` },
        ketchup: { h: 5, d: (y) => `<path d="M26 ${y + 2} H214 V${y + 4} H140 Q136 ${y + 12} 132 ${y + 4} H60 Q56 ${y + 10} 52 ${y + 4} H26 Z" fill="#c8261f"/>` },
    };
    const LABELS = { pain_bas: 'Pain (dessous)', pain_milieu: 'Pain (milieu)', pain_haut: 'Pain (dessus)', steak: 'Steak', poulet: 'Poulet pané',
        galette: 'Galette de légumes', cheddar: 'Cheddar', salade: 'Salade', tomate: 'Tomate', oignon: 'Oignons', bacon: 'Bacon',
        cornichon: 'Cornichons', sauce: 'Sauce', ketchup: 'Ketchup' };

    function burger(layers, opts = {}) {
        const list = (layers || []).filter((l) => L[l]);
        if (!list.length) return '';
        const id = ++uid;
        const total = list.reduce((s, l) => s + L[l].h - 2, 0) + 2;
        const H = Math.max(total + 26, 120);
        let cursor = H - 12;
        const parts = list.map((l, i) => {
            const h = L[l].h;
            const y = cursor - h;
            cursor = y + 2;
            return `<g class="ly ${opts.hidden ? '' : 'on'}" data-i="${i}">${L[l].d(y, h, id)}</g>`;
        });
        return `<svg class="viz-svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMax meet">
            <defs><linearGradient id="bunT${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f0a94e"/><stop offset=".7" stop-color="#d0832f"/><stop offset="1" stop-color="#b56b22"/></linearGradient>
                <linearGradient id="bunB${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e09a45"/><stop offset="1" stop-color="#b06a25"/></linearGradient></defs>
            <ellipse cx="120" cy="${H - 8}" rx="100" ry="7" fill="rgba(0,0,0,.35)"/>${parts.join('')}</svg>`;
    }

    function drink(visual, color, opts = {}) {
        const col = /^#[0-9a-f]{6}$/i.test(color || '') ? color : '#4a2416';
        const hid = opts.hidden ? '' : 'on';
        const shadow = '<ellipse cx="120" cy="226" rx="62" ry="7" fill="rgba(0,0,0,.35)"/>';
        if (visual === 'verre' || visual === 'milkshake') {
            const shake = visual === 'milkshake';
            return `<svg class="viz-svg drink ${hid}" viewBox="0 0 240 240">${shadow}
                <rect x="132" y="${shake ? 18 : 30}" width="9" height="${shake ? 90 : 90}" rx="4" fill="#e0433b" transform="rotate(12 136 70)"/>
                <path d="M74 ${shake ? 70 : 62} L166 ${shake ? 70 : 62} L156 222 L84 222 Z" fill="rgba(255,255,255,.14)" stroke="rgba(255,255,255,.55)" stroke-width="3"/>
                <g class="liq"><path d="M80 ${shake ? 86 : 96} L160 ${shake ? 86 : 96} L154 216 L86 216 Z" fill="${col}"/>
                ${shake ? '' : '<rect x="94" y="104" width="22" height="20" rx="4" fill="rgba(255,255,255,.55)" transform="rotate(-12 105 114)"/><rect x="122" y="118" width="20" height="18" rx="4" fill="rgba(255,255,255,.45)" transform="rotate(10 132 127)"/>'}</g>
                ${shake ? `<g class="top"><circle cx="96" cy="70" r="18" fill="#fff6f0"/><circle cx="120" cy="58" r="22" fill="#fffaf5"/><circle cx="144" cy="70" r="18" fill="#fff6f0"/><circle cx="122" cy="36" r="9" fill="#d9262c"/><path d="M122 28 q6 -12 14 -14" stroke="#4b6a17" stroke-width="3" fill="none"/></g>`
                    : `<g class="top"><circle cx="160" cy="64" r="16" fill="#f3dc4c" stroke="#fff3a8" stroke-width="3"/><path d="M160 50 V78 M146 64 H174 M150 54 L170 74 M170 54 L150 74" stroke="#fff3a8" stroke-width="2"/></g>`}
                <path d="M82 70 L90 210" stroke="rgba(255,255,255,.35)" stroke-width="5" stroke-linecap="round"/></svg>`;
        }
        if (visual === 'cafe') {
            return `<svg class="viz-svg drink ${hid}" viewBox="0 0 240 240">${shadow}
                <g class="top"><path d="M100 40 q-10 -14 0 -26 M122 44 q-10 -16 0 -30 M144 40 q-10 -14 0 -26" stroke="rgba(255,255,255,.6)" stroke-width="5" fill="none" stroke-linecap="round"/></g>
                <path d="M80 72 L160 72 L150 222 L90 222 Z" fill="#fbf7f0"/>
                <g class="liq"><path d="M84 116 L156 116 L152 176 L88 176 Z" fill="${col}"/><text x="120" y="154" text-anchor="middle" font-family="Georgia,serif" font-weight="700" font-size="22" fill="#f6e2ae">BS</text></g>
                <rect x="74" y="58" width="92" height="16" rx="7" fill="#e9e3d8"/><rect x="92" y="50" width="56" height="10" rx="5" fill="#d8d1c4"/></svg>`;
        }
        // gobelet Burger Shot
        return `<svg class="viz-svg drink ${hid}" viewBox="0 0 240 240">${shadow}
            <rect x="128" y="14" width="10" height="70" rx="4" fill="#e0433b" transform="rotate(14 133 50)"/>
            <path d="M74 70 L166 70 L154 222 L86 222 Z" fill="#fbf7f0"/>
            <g class="liq"><path d="M78 112 L162 112 L157 176 L83 176 Z" fill="${col}"/>
                <text x="120" y="152" text-anchor="middle" font-family="Georgia,serif" font-weight="700" font-size="24" fill="#fff">BS</text></g>
            <path d="M85 196 L155 196 L154 206 L86 206 Z" fill="#e0433b"/>
            <rect x="66" y="58" width="108" height="16" rx="7" fill="#e9e3d8"/><path d="M80 58 Q120 40 160 58 Z" fill="#f4efe6"/></svg>`;
    }

    const img = (item) => `nui://elyzea_inventory/html/img/${encodeURIComponent(item || '')}.png`;

    // Visuel d'un produit : burger dessiné, boisson dessinée ou image de l'objet
    function product(p, opts = {}) {
        if (p.layers && p.layers.length) return `<div class="viz burger">${burger(p.layers, opts)}</div>`;
        if (p.visual) return `<div class="viz">${drink(p.visual, p.color, opts)}</div>`;
        return `<div class="viz pic ${opts.hidden ? '' : 'on'}"><img src="${img(p.item)}" alt="" onerror="this.style.visibility='hidden'"></div>`;
    }

    // Assemble en direct pendant « duration » ms (couche par couche, ou remplissage)
    function play(root, duration) {
        if (!root) return;
        const layers = root.querySelectorAll('.ly');
        if (layers.length) {
            const step = Math.max(120, (duration * 0.9) / layers.length);
            layers.forEach((g, i) => setTimeout(() => g.classList.add('on'), i * step));
            return;
        }
        const el = root.querySelector('.drink, .pic');
        if (el) { el.style.setProperty('--dur', `${Math.max(400, duration * 0.85)}ms`); requestAnimationFrame(() => el.classList.add('on')); }
    }
    function finish(root) {
        if (!root) return;
        root.querySelectorAll('.ly').forEach((g) => g.classList.add('on'));
        root.querySelectorAll('.drink, .pic').forEach((g) => g.classList.add('on'));
    }

    return { burger, drink, product, play, finish, img, LAYERS: Object.keys(L), LABELS };
})();
window.Viz = Viz;
