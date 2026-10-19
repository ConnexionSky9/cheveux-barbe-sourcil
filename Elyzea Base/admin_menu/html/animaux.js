/* =========================================================
   GESTION DES ANIMAUX (ressource elyzea_animaux)
   Permissions : « animaux_manage » (vendeurs, catalogue, réglages, ferme, diagnostic)
                 « animaux_owned » (animaux possédés des joueurs).
   Brouillons puis « Enregistrer » ; elyzea_animaux revalide chaque valeur.
   ========================================================= */
(() => {
    TABS.push({
        id: 'animaux', group: 5, label: 'Gestion des animaux', ico: '🐾',
        sub: 'Vendeurs PNJ, prix et pelages, harnais et laisses, besoins, ferme, animaux possédés, diagnostic.',
        show: () => (has('animaux_manage') || has('animaux_owned')) && !!(D && D.animaux),
    });

    const A = { sub: null, vendor: null, species: null, spDraft: null, settings: null, farm: null, enc: null, q: '' };
    const send = (name, data = {}) => action('animaux', { name, data });
    const arr = (x) => (Array.isArray(x) ? x : []);
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
    const date = (t) => (t ? new Date(t * 1000).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
    const copy = (o) => JSON.parse(JSON.stringify(o));
    const tog = (on, attr, title, sub) => `<div class="tile toggle-tile ${on ? 'on' : ''}" ${attr}><div><strong>${title}</strong><span>${sub || ''}</span></div><div class="switch"></div></div>`;
    const num = (label, attr, val, extra = '') => `<div class="field"><label>${label}</label><input class="input" type="number" ${attr} value="${esc(val ?? '')}" ${extra}></div>`;
    const STATUS = { stored: 'Rangé', out: 'Sorti', injured: 'Blessé' };

    const SUBS = () => {
        const d = D.animaux, out = [];
        if (d.canManage) out.push(['vendors', '🧑‍💼 Vendeurs'], ['catalog', '💲 Prix et pelages'], ['settings', '🦮 Équipements et comportements'], ['farm', '🐄 Ferme']);
        if (d.canOwned) out.push(['pets', '📋 Animaux possédés']);
        if (d.canManage) out.push(['diag', '🩺 Diagnostic']);
        return out;
    };

    /* ---------- Vendeurs ---------- */
    function vendorForm() {
        const d = D.animaux, v = A.vendor;
        const sp = arr(d.species);
        const checks = sp.map((s) => {
            const on = arr(v.catalog).includes(s.id);
            const price = v.prices && v.prices[s.id] !== undefined ? v.prices[s.id] : '';
            return `<tr><td><label style="display:flex;gap:8px;align-items:center;margin:0"><input type="checkbox" data-anvc="${s.id}" ${on ? 'checked' : ''}> ${esc(s.label)}</label></td>
                <td class="muted">${esc(s.cat)}${s.exotic ? ' · exotique' : ''}${s.farm ? ' · ferme' : ''}</td><td class="muted">${money(s.price)}</td>
                <td><input class="input" type="number" min="0" placeholder="prix de l'espèce" data-anvp="${s.id}" value="${esc(price)}" style="max-width:160px"></td></tr>`;
        }).join('');
        const opt = (list, cur) => list.map((m) => `<option value="${esc(m)}" ${m === cur ? 'selected' : ''}>${esc(m || 'Aucun (immobile)')}</option>`).join('');
        return `<div class="section"><h2>${v.id ? `Modifier « ${esc(v.label)} »` : 'Nouveau vendeur'}</h2>
            <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;max-width:1150px">
                <div class="field"><label>Nom</label><input class="input" data-anv="label" value="${esc(v.label)}"></div>
                <div class="field"><label>Modèle du PNJ</label><select class="input" data-anv="model">${opt(arr(d.models), v.model)}</select></div>
                <div class="field"><label>Scénario d'attente</label><select class="input" data-anv="scenario">${opt(arr(d.scenarios), v.scenario)}</select></div>
                ${num('Distance d\'interaction (m)', 'data-anvn="distance"', v.distance, 'min="1" max="10" step="0.5"')}
                ${num('X', 'data-anvn="x"', v.x, 'step="0.01"')}${num('Y', 'data-anvn="y"', v.y, 'step="0.01"')}${num('Z', 'data-anvn="z"', v.z, 'step="0.01"')}${num('Orientation (°)', 'data-anvn="h"', v.h, 'step="1"')}
                ${num('Icône de carte (sprite)', 'data-anvb="sprite"', v.blip.sprite, 'min="1"')}${num('Couleur de l\'icône', 'data-anvb="color"', v.blip.color, 'min="0" max="85"')}
            </div>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(250px,1fr));margin:12px 0">
                ${tog(v.enabled, 'data-anvt="enabled"', v.enabled ? 'Vendeur actif' : 'Vendeur désactivé', 'Désactivé : PNJ et icône retirés.')}
                ${tog(v.blip.enabled, 'data-anvt="blip"', 'Icône sur la carte', '')}
                ${tog(v.accessories, 'data-anvt="accessories"', 'Vend des accessoires', 'Harnais, laisses, croquettes, trousses…')}
                ${tog(v.vet, 'data-anvt="vet"', 'Vétérinaire', 'Soins payants au comptoir.')}
            </div>
            <p class="hint">La hauteur est recalée au sol en jeu. « Placer ici » (liste) prend ta position et ton orientation.</p>
            <h2 style="margin-top:12px">Catalogue de ce vendeur</h2>
            <table class="loot wide"><tr><th>Espèce</th><th>Type</th><th>Prix de l'espèce</th><th>Prix chez ce vendeur (vide = prix de l'espèce)</th></tr>${checks}</table>
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-ana="vendorSave">💾 Enregistrer</button><button class="btn" data-ana="vendorCancel">Annuler</button></div></div>`;
    }

    function viewVendors() {
        const d = D.animaux;
        if (A.vendor) return vendorForm();
        const rows = arr(d.vendors).map((v) => `<tr>
            <td><strong>${esc(v.label)}</strong><br><span class="muted">${esc(v.id)}</span></td>
            <td>${v.enabled ? '<span style="color:var(--ok)">Actif</span>' : '<span class="muted">Désactivé</span>'}</td>
            <td class="muted">${v.x.toFixed(1)}, ${v.y.toFixed(1)}, ${v.z.toFixed(1)} · ${Math.round(v.h)}°</td>
            <td>${esc(v.model)}<br><span class="muted">${esc(v.scenario || 'immobile')}</span></td>
            <td>${arr(v.catalog).length} espèce(s)${v.accessories ? ' · accessoires' : ''}${v.vet ? ' · vétérinaire' : ''}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-ana="vendorEdit" data-id="${esc(v.id)}">Modifier</button>
                <button class="btn" data-ana="vendorHere" data-id="${esc(v.id)}">Placer ici</button>
                <button class="btn" data-ana="goto" data-x="${v.x}" data-y="${v.y}" data-z="${v.z}">Y aller</button>
                <button class="btn" data-ana="vendorToggle" data-id="${esc(v.id)}">${v.enabled ? 'Désactiver' : 'Activer'}</button>
                <button class="btn danger" data-ana="vendorDelete" data-id="${esc(v.id)}" data-label="${esc(v.label)}">Supprimer</button></td></tr>`).join('');
        return `<div class="section"><h2>Points de vente</h2>
            <p class="hint">Les joueurs achètent auprès de ces PNJ (touche <span class="keycap">E</span>). Aucun ne dépend de Cayo Perico. Les changements s'appliquent tout de suite, sans redémarrage, et sont enregistrés en base.</p>
            <div class="btn-row" style="margin-bottom:10px"><button class="btn primary" data-ana="vendorNew">➕ Nouveau vendeur à ma position</button>
                <button class="btn danger" data-ana="resetVendors">Restaurer les vendeurs par défaut</button></div>
            <table class="loot wide"><tr><th>Vendeur</th><th>État</th><th>Position</th><th>PNJ</th><th>Catalogue</th><th style="width:460px"></th></tr>
                ${rows || '<tr><td colspan="6" class="muted">Aucun vendeur.</td></tr>'}</table></div>`;
    }

    /* ---------- Prix et pelages ---------- */
    function speciesForm(s) {
        const dr = A.spDraft;
        const vars = s.variants.map((v) => {
            const o = dr.variants[v.id] || {};
            const enabled = o.enabled !== undefined ? o.enabled : v.enabled;
            const badge = v.usable ? '<span style="color:var(--ok)">disponible</span>'
                : v.addon ? '<span class="muted">pack de textures non détecté</span>' : '<span style="color:var(--danger)">introuvable au scan</span>';
            return `<tr><td><input class="input" data-anvl="${esc(v.id)}" value="${esc(o.label !== undefined ? o.label : v.label)}"></td>
                <td class="muted">${esc(v.model)} · c${v.c} d${v.d} t${v.t}${v.custom ? ' · ajouté' : ''}</td><td>${badge}</td>
                <td><input class="input" type="number" min="0" data-anvx="${esc(v.id)}" value="${esc(o.extra !== undefined ? o.extra : v.extra)}" style="max-width:120px"></td>
                <td><input type="checkbox" data-anve="${esc(v.id)}" ${enabled ? 'checked' : ''}></td>
                <td style="white-space:nowrap"><button class="btn" data-ana="preview" data-v="${esc(v.id)}">Aperçu</button>
                    ${v.custom ? `<button class="btn danger" data-ana="removeVariant" data-v="${esc(v.id)}">Retirer</button>` : ''}</td></tr>`;
        }).join('');
        const found = arr(s.found).map((f) => `<tr><td>${esc(f.model)} · modèle ${f.d}, texture ${f.t}</td>
            <td><button class="btn" data-ana="addVariant" data-m="${esc(f.model)}" data-d="${f.d}" data-t="${f.t}">Ajouter au catalogue</button></td></tr>`).join('');
        return `<div class="section"><h2>${esc(s.label)} <span class="muted" style="font-size:13px">${esc(s.profileLabel)} · ${esc(s.model)}</span></h2>
            <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;max-width:800px">
                ${num(`Prix (défaut ${money(s.basePrice)})`, 'data-ansn="price"', dr.price, 'min="0"')}
                ${num(`Frais supplémentaires (défaut ${money(s.baseFees)})`, 'data-ansn="fees"', dr.fees, 'min="0"')}
            </div>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(250px,1fr));margin:12px 0">${tog(dr.enabled, 'data-anst', dr.enabled ? 'En vente' : 'Retiré de la vente', 'Les animaux déjà possédés restent.')}</div>
            <h2>Pelages</h2>
            <table class="loot wide"><tr><th>Libellé affiché aux joueurs</th><th>Texture réelle</th><th>État</th><th>Supplément ($)</th><th>Proposé</th><th></th></tr>${vars}</table>
            <p class="hint">Seuls les pelages « disponibles » (texture vérifiée par le scan, ou du jeu de base) apparaissent en boutique ; le client du joueur revérifie avant d'afficher.
                « Aperçu » fait apparaître l'animal devant toi 20 s : vérifie que le libellé correspond.</p>
            ${found ? `<h2 style="margin-top:12px">Textures trouvées par le scan, pas encore proposées</h2><table class="loot wide">${found}</table>` : ''}
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-ana="speciesSave">💾 Enregistrer</button><button class="btn" data-ana="speciesCancel">Fermer</button></div></div>`;
    }

    function viewCatalog() {
        const d = D.animaux;
        const s = arr(d.species).find((x) => x.id === A.species);
        if (s) {
            if (!A.spDraft) A.spDraft = { enabled: s.enabled, price: s.price, fees: s.fees, variants: {} };
            return speciesForm(s);
        }
        const rows = arr(d.species).map((x) => {
            const usable = x.variants.filter((v) => v.usable && v.enabled).length;
            return `<tr><td><strong>${esc(x.label)}</strong><br><span class="muted">${esc(x.model)}</span></td><td>${esc(x.cat)}${x.exotic ? ' · exotique' : ''}</td>
                <td>${money(x.price)}${x.price !== x.basePrice ? ' <span class="muted">(modifié)</span>' : ''}</td><td>${x.fees ? money(x.fees) : '—'}</td>
                <td>${usable} / ${x.variants.length}</td><td>${x.enabled ? 'En vente' : '<span class="muted">Retiré</span>'}</td>
                <td style="text-align:right"><button class="btn" data-ana="speciesEdit" data-id="${esc(x.id)}">Prix et pelages</button></td></tr>`;
        }).join('');
        return `<div class="section"><h2>Espèces</h2>
            <p class="hint">Le prix facturé = prix chez le vendeur (ou de l'espèce) + supplément du pelage + frais. Il est recalculé par le serveur à chaque achat.
                Les vendeurs choisissent leurs espèces dans l'onglet Vendeurs. Espèces sans modèle dans GTA V (mouton, chèvre) : voir Diagnostic.</p>
            <div class="btn-row" style="margin-bottom:10px"><button class="btn danger" data-ana="resetSpecies">Prix et pelages par défaut</button></div>
            <table class="loot wide"><tr><th>Espèce</th><th>Type</th><th>Prix</th><th>Frais</th><th>Pelages proposés</th><th>Vente</th><th></th></tr>${rows}</table></div>`;
    }

    /* ---------- Réglages ---------- */
    const getK = (o, k) => k.split('.').reduce((a, p) => (a ? a[p] : undefined), o);
    const setK = (o, k, v) => { const [a, b] = k.split('.'); o[a] = o[a] || {}; o[a][b] = v; };
    function viewSettings() {
        const d = D.animaux;
        if (!A.settings) A.settings = copy(d.settings);
        const s = A.settings;
        const sections = arr(d.sections).map((sec) => {
            const fields = arr(d.schema).filter((f) => f.key.startsWith(sec.id + '.'));
            const bools = fields.filter((f) => f.type === 'bool').map((f) => tog(getK(s, f.key), `data-anb="${f.key}"`, esc(f.label), esc(f.help))).join('');
            const nums = fields.filter((f) => f.type !== 'bool').map((f) => {
                const def = getK(d.defaults, f.key);
                const v = getK(s, f.key);
                const input = f.type === 'str'
                    ? `<input class="input" data-anstr="${f.key}" value="${esc(v)}" maxlength="${f.max || 40}">`
                    : `<input class="input" type="number" data-ann="${f.key}" min="${f.min}" max="${f.max}" step="${f.step || 1}" value="${esc(v)}">`;
                return `<div class="field"><label>${esc(f.label)}${f.unit ? ` (${esc(f.unit)})` : ''}</label>${input}
                    <p class="hint" style="margin:4px 0 0">${esc(f.help)} ${f.type !== 'str' ? `<span class="muted">(${f.min} à ${f.max})</span>` : ''}${JSON.stringify(v) !== JSON.stringify(def) ? ` <span class="muted">défaut : ${esc(def)}</span>` : ''}</p></div>`;
            }).join('');
            return `<div class="section"><h2>${esc(sec.label)}</h2>
                ${bools ? `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin-bottom:12px">${bools}</div>` : ''}
                ${nums ? `<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px;max-width:1150px">${nums}</div>` : ''}</div>`;
        }).join('');
        const acc = arr(d.accessoryKinds).map((k) => {
            const a = s.accessories[k.id] || { enabled: false, price: 0 };
            return `<tr><td>${esc(k.label)}</td><td><input type="checkbox" data-anae="${k.id}" ${a.enabled ? 'checked' : ''}></td>
                <td><input class="input" type="number" min="0" data-anap="${k.id}" value="${esc(a.price)}" style="max-width:140px"></td></tr>`;
        }).join('');
        const styles = arr(d.styles).map((x) => esc(x.label)).join(', ');
        const colors = arr(d.colors).map((c) => `<i title="${esc(c.label)}" style="display:inline-block;width:14px;height:14px;border-radius:3px;background:rgb(${c.rgb.join(',')});margin-right:4px;border:1px solid #0006"></i>`).join('');
        const bar = `<div class="section"><div class="btn-row"><button class="btn primary" data-ana="settingsSave">💾 Enregistrer</button>
            <button class="btn" data-ana="settingsCancel">Annuler les modifications</button><button class="btn danger" data-ana="settingsReset">Valeurs par défaut</button>
            <span class="muted" style="align-self:center">Appliqué tout de suite (aucun redémarrage).</span></div></div>`;
        return `${bar}${sections}
            <div class="section"><h2>Accessoires vendus</h2><table class="loot"><tr><th>Article</th><th>En vente</th><th>Prix ($)</th></tr>${acc}</table>
                <p class="hint">Harnais : ${styles} · couleurs ${colors}. Ils sont dessinés sur le chien (visibles par tous). Les styles et couleurs se changent dans config.lua (redémarrage de la ressource).</p></div>
            <div class="section"><h2>Commandes par espèce</h2><table class="loot wide"><tr><th>Profil</th><th>Ordres</th><th>Harnais</th><th>Laisse</th><th>Véhicule</th></tr>
                ${Object.values(d.profiles || {}).map((p) => `<tr><td>${esc(p.label)}</td><td class="muted">Suivre, Attendre, Revenir, Promenade, Caresser${p.commands.length ? ', ' + p.commands.map(esc).join(', ') : ''}</td>
                    <td>${p.harness ? '✔' : '—'}</td><td>${p.leash ? '✔' : '—'}</td><td>${p.vehicle ? '✔' : '—'}</td></tr>`).join('')}</table>
                <p class="hint">Les profils (animations par espèce) sont dans config.lua : un changement demande un <b>redémarrage de la ressource</b>. Une commande sans animation sur un modèle est signalée au Diagnostic.</p></div>${bar}`;
    }

    /* ---------- Ferme ---------- */
    function encForm() {
        const d = D.animaux, e = A.enc;
        const rows = arr(d.species).map((s) => num(esc(s.label) + (s.farm ? '' : ' <span class="muted">(non fermier)</span>'), `data-anfa="${s.id}"`, (e.animals || {})[s.id] || 0, 'min="0" max="12"')).join('');
        const state = arr((d.farm.rows || {})[e.id]).map((r) => `<tr><td>#${r.slot}</td><td>${esc(r.species)} · ${esc(r.variant)}</td><td>${r.hunger} %</td><td>${r.health} %</td></tr>`).join('');
        return `<div class="section"><h2>${e.id ? `Enclos « ${esc(e.label)} »` : 'Nouvel enclos'}</h2>
            <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;max-width:1150px">
                <div class="field"><label>Nom</label><input class="input" data-anf="label" value="${esc(e.label)}"></div>
                ${num('Rayon (m)', 'data-anfn="radius"', e.radius, 'min="3" max="60" step="0.5"')}
                ${num('X', 'data-anfn="x"', e.x, 'step="0.01"')}${num('Y', 'data-anfn="y"', e.y, 'step="0.01"')}${num('Z', 'data-anfn="z"', e.z, 'step="0.01"')}
            </div>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(250px,1fr));margin:12px 0">${tog(e.enabled !== false, 'data-anft', e.enabled !== false ? 'Enclos actif' : 'Enclos désactivé', '')}</div>
            <h2>Animaux (20 au total maximum)</h2><div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px;max-width:1150px">${rows}</div>
            ${state ? `<h2 style="margin-top:12px">État enregistré</h2><table class="loot"><tr><th>Place</th><th>Animal</th><th>Faim</th><th>Santé</th></tr>${state}</table>` : ''}
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-ana="encSave">💾 Enregistrer</button><button class="btn" data-ana="encCancel">Annuler</button></div></div>`;
    }

    function viewFarm() {
        const d = D.animaux;
        if (A.enc) return encForm();
        if (!A.farm) A.farm = copy(d.farm.settings);
        const f = A.farm;
        const encs = arr(d.farm.settings.enclosures).map((e) => `<tr><td><strong>${esc(e.label)}</strong><br><span class="muted">${esc(e.id)}</span></td>
            <td class="muted">${e.x.toFixed(1)}, ${e.y.toFixed(1)}, ${e.z.toFixed(1)} · ${e.radius} m</td>
            <td>${Object.entries(e.animals || {}).map(([k, n]) => `${n} × ${esc(k)}`).join(', ') || '<span class="muted">vide</span>'}</td>
            <td>${(d.farm.live || {})[e.id] ? `${d.farm.live[e.id]} présent(s)` : '<span class="muted">personne autour</span>'}${e.enabled === false ? ' · désactivé' : ''}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-ana="encEdit" data-id="${esc(e.id)}">Modifier</button>
                <button class="btn" data-ana="encHere" data-id="${esc(e.id)}">Centre ici</button>
                <button class="btn" data-ana="goto" data-x="${e.x}" data-y="${e.y}" data-z="${e.z}">Y aller</button>
                <button class="btn danger" data-ana="encDelete" data-id="${esc(e.id)}" data-label="${esc(e.label)}">Supprimer</button></td></tr>`).join('');
        return `<div class="section"><h2>🐄 Ferme</h2>
            <p class="hint">Les animaux d'enclos appartiennent à la ferme (jamais à un joueur). Ils apparaissent quand quelqu'un approche et sont les mêmes pour tous.
                ALT sur un animal : observer, nourrir (Aliment pour bétail), soigner (Trousse vétérinaire), récolter (œufs, lait). Aucun mapping requis : place les enclos où tu veux.
                Pour vendre des animaux de ferme aux joueurs, active le vendeur « Vente d'animaux de ferme » (onglet Vendeurs) : c'est séparé des enclos.</p>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr));margin-bottom:12px">
                ${tog(f.enabled, 'data-anfs="enabled"', f.enabled ? 'Ferme active' : 'Ferme fermée', 'Fermée : les animaux d\'enclos disparaissent.')}
                ${tog(f.produce.enabled, 'data-anfs="produce.enabled"', 'Récolte (œufs, lait)', 'Seulement si l\'animal est nourri et en bonne santé.')}</div>
            <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px;max-width:1150px">
                ${num('Apparition à moins de (m)', 'data-anfsn="activation"', f.activation, 'min="40" max="500"')}
                ${num('Faim perdue / 10 min', 'data-anfsn="hungerRate"', f.hungerRate, 'min="0" max="50" step="0.5"')}
                ${num('Faim rendue par un aliment', 'data-anfsn="feedValue"', f.feedValue, 'min="1" max="100"')}
                ${num('Santé rendue par une trousse', 'data-anfsn="careValue"', f.careValue, 'min="1" max="100"')}
                ${num('Délai entre deux récoltes (min)', 'data-anfsn="produce.cooldown"', f.produce.cooldown, 'min="1" max="1440"')}
                ${num('Faim minimale pour récolter', 'data-anfsn="produce.minHunger"', f.produce.minHunger, 'min="0" max="100"')}
                ${num('Santé minimale pour récolter', 'data-anfsn="produce.minHealth"', f.produce.minHealth, 'min="0" max="100"')}</div>
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-ana="farmSave">💾 Enregistrer</button><button class="btn" data-ana="farmCancel">Annuler</button>
                <button class="btn danger" data-ana="resetFarm">Ferme par défaut</button></div></div>
            <div class="section"><h2>Enclos</h2><div class="btn-row" style="margin-bottom:10px"><button class="btn primary" data-ana="encNew">➕ Nouvel enclos à ma position</button></div>
                <table class="loot wide"><tr><th>Enclos</th><th>Centre</th><th>Animaux</th><th>En ce moment</th><th style="width:400px"></th></tr>${encs || '<tr><td colspan="5" class="muted">Aucun enclos.</td></tr>'}</table></div>`;
    }

    /* ---------- Animaux possédés ---------- */
    function viewPets() {
        const d = D.animaux;
        const rows = arr(d.pets).map((p) => `<tr ${p.incoherent ? 'style="background:#e0433b22"' : ''}>
            <td>#${p.id}<br><span class="muted">${esc(p.chip)}</span></td><td><strong>${esc(p.name)}</strong><br><span class="muted">${esc(p.speciesLabel)} · ${esc(p.variantLabel)}</span></td>
            <td>${p.owner ? esc(p.owner) : '<span class="muted">hors ligne</span>'}<br><span class="muted">${esc(p.cid)}</span></td>
            <td>${STATUS[p.status] || esc(p.status)}${p.out ? ' · dans le monde' : ''}${p.incoherent ? '<br><b style="color:var(--danger)">état incohérent</b>' : ''}</td>
            <td class="muted">faim ${p.hunger} · soif ${p.thirst} · santé ${p.health}</td><td class="muted">${date(p.acquired)}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-ana="petStore" data-id="${p.id}">Ranger</button>
                <button class="btn" data-ana="petFix" data-id="${p.id}">Corriger</button>
                <button class="btn danger" data-ana="petRemove" data-id="${p.id}">Retirer</button></td></tr>`).join('');
        const live = arr(d.live).map((p) => `<tr ${(!p.exists || p.copies > 1) ? 'style="background:#e0433b22"' : ''}>
            <td>#${p.id} <strong>${esc(p.name)}</strong> <span class="muted">${esc(p.species)}</span></td><td>${esc(p.owner)} <span class="muted">(ID ${p.src})</span></td>
            <td>${p.exists ? (p.dist !== null && p.dist !== undefined ? `${p.dist} m du propriétaire` : 'présent') : '<b style="color:var(--danger)">entité introuvable</b>'}${p.copies > 1 ? ` · <b style="color:var(--danger)">${p.copies} copies</b>` : ''}</td>
            <td class="muted">${p.leash ? 'en laisse' : ''}${p.harness ? ` ${esc(p.harness)}` : ''}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-ana="gotoPet" data-id="${p.id}">Y aller</button><button class="btn" data-ana="petStore" data-id="${p.id}">Ranger</button></td></tr>`).join('');
        const orphans = arr(d.orphans).map((o) => `<tr><td>Animal #${o.id} « ${esc(o.name || '?')} » · entité ${o.netId}</td>
            <td style="text-align:right"><button class="btn danger" data-ana="deleteOrphan" data-net="${o.netId}">Supprimer l'entité</button></td></tr>`).join('');
        return `<div class="section"><h2>Animaux sortis en ce moment (${arr(d.live).length})</h2>
                <table class="loot wide"><tr><th>Animal</th><th>Propriétaire</th><th>Monde</th><th>Équipement</th><th></th></tr>${live || '<tr><td colspan="5" class="muted">Aucun animal sorti.</td></tr>'}</table>
                ${orphans ? `<h2 style="margin-top:12px">⚠️ Entités en double ou orphelines</h2><table class="loot wide">${orphans}</table>` : ''}</div>
            <div class="section"><h2>Registre des animaux</h2>
                <div class="btn-row" style="margin-bottom:10px"><input class="input" data-anq placeholder="Puce, n°, nom de l'animal, citizenid, prénom ou nom du propriétaire…" value="${esc(A.q)}" style="max-width:460px">
                    <button class="btn primary" data-ana="search">Rechercher</button></div>
                ${d.pets ? `<table class="loot wide"><tr><th>N° / puce</th><th>Animal</th><th>Propriétaire</th><th>Statut</th><th>Besoins</th><th>Acquis le</th><th style="width:270px"></th></tr>
                    ${rows || '<tr><td colspan="7" class="muted">Aucun résultat.</td></tr>'}</table>` : '<p class="hint">Lance une recherche (vide = les 100 derniers).</p>'}
                <p class="hint">« Ranger » : renvoie l'animal dans son stockage. « Corriger » : statut et besoins. « Retirer » : l'animal n'appartient plus au joueur (confirmation par le numéro de puce, rien d'autre n'est effacé).
                    Ligne rouge : état en base différent de la réalité (corrige-la).</p></div>`;
    }

    /* ---------- Diagnostic ---------- */
    function viewDiag() {
        const g = D.animaux.diag || {};
        const i = g.info || {};
        const errs = arr(g.errors).map((e) => `<li>${esc(e)}</li>`).join('');
        const saves = arr(g.saveErrors).map((e) => `<li>${date(e.at)} · ${esc(e.what)} : ${esc(e.err)}</li>`).join('');
        const issues = arr(g.issues).map((e) => `<tr><td>${esc(e.kind)}</td><td>${esc(e.what)}</td><td>${e.count}</td><td class="muted">${date(e.last)}</td></tr>`).join('');
        const scan = arr(g.scan).map((s) => `<tr><td>${esc(s.model)}</td><td>${s.exists ? '<span style="color:var(--ok)">présent</span>' : '<b style="color:var(--danger)">introuvable</b>'}</td>
            <td>${s.exists ? `${s.drawables} modèle(s) · ${s.textures} texture(s) (modèle 0)` : '—'}</td><td class="muted">${esc(s.by)} · ${date(s.at)}</td></tr>`).join('');
        const missing = arr(g.missingSpecies).map((m) => `<li><b>${esc(m.label)}</b> : ${esc(m.reason)} (modèle addon nécessaire)</li>`).join('');
        const s = D.animaux.settings || {};
        return `<div class="stats">
                <div class="stat"><b>${D.animaux.ready ? 'Prêt' : 'Démarrage'}</b><span>Ressource</span></div>
                <div class="stat"><b>${g.total || 0}</b><span>Animaux enregistrés</span></div>
                <div class="stat"><b>${i.out || 0}</b><span>Sortis</span></div>
                <div class="stat"><b>${i.vendorsOn || 0}</b><span>Vendeurs actifs</span></div>
                <div class="stat"><b>${i.farmActive || 0}</b><span>Enclos animés</span></div></div>
            <div class="section"><h2>Erreurs de configuration</h2>${errs ? `<ul class="hint" style="line-height:1.7">${errs}</ul>` : '<p class="hint" style="color:var(--ok)">Aucune.</p>'}</div>
            <div class="section"><h2>Modèles et textures (scan)</h2>
                <p class="hint">Le scan crée chaque modèle sur ton jeu pour compter ses textures réelles. À relancer après l'ajout d'un pack de textures ou de modèles.</p>
                <div class="btn-row" style="margin-bottom:10px"><button class="btn primary" data-ana="scan">🔍 Lancer le scan</button></div>
                ${scan ? `<table class="loot wide"><tr><th>Modèle</th><th>Présent</th><th>Contenu</th><th>Scanné par</th></tr>${scan}</table>` : '<p class="hint">Aucun scan enregistré : les pelages « addon » restent cachés.</p>'}
                ${missing ? `<h2 style="margin-top:12px">Espèces demandées sans modèle dans le jeu</h2><ul class="hint" style="line-height:1.7">${missing}</ul>` : ''}</div>
            <div class="section"><h2>Problèmes constatés en jeu</h2>
                ${issues ? `<table class="loot wide"><tr><th>Type</th><th>Détail</th><th>Fois</th><th>Dernière</th></tr>${issues}</table>` : '<p class="hint" style="color:var(--ok)">Aucun.</p>'}
                ${saves ? `<h2 style="margin-top:12px">Erreurs de sauvegarde</h2><ul class="hint">${saves}</ul>` : ''}
                <div class="btn-row" style="margin-top:10px"><button class="btn" data-ana="clearIssues">Vider</button></div></div>
            <div class="section"><h2>Paramètres effectivement chargés</h2>
                <p class="hint">Possédés max ${s.general && s.general.maxOwned} · sortis max ${s.general && s.general.maxOut} · besoins ${s.needs && s.needs.enabled ? `toutes les ${s.needs.interval} min` : 'coupés'}
                    · harnais ${s.harness && s.harness.enabled ? 'oui' : 'non'} · laisse ${s.leash && s.leash.enabled ? `${s.leash.length} m` : 'non'} · exotiques ${s.exotic && s.exotic.enabled ? `max ${s.exotic.maxOwned}` : 'fermés'}</p>
                <p class="hint">Commandes : <code>/animaux_diag</code> (console ou staff), <code>/animaux_scan</code> (staff, en jeu), touche <span class="keycap">${esc(D.animaux.keyMenu || 'F7')}</span> / <code>/animaux</code> (joueurs).</p></div>`;
    }

    VIEWS.animaux = () => {
        const d = D.animaux;
        if (!d.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_animaux')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        if (d.denied) return '<div class="protect">⛔ <span>Permission refusée par elyzea_animaux.</span></div>';
        const subs = SUBS();
        if (!subs.find((s) => s[0] === A.sub)) A.sub = subs[0] ? subs[0][0] : null;
        const nav = `<div class="btn-row" style="margin-bottom:14px">${subs.map(([id, l]) => `<button class="btn ${id === A.sub ? 'primary' : ''}" data-ans="${id}">${l}</button>`).join('')}</div>`;
        const body = { vendors: viewVendors, catalog: viewCatalog, settings: viewSettings, farm: viewFarm, pets: viewPets, diag: viewDiag }[A.sub];
        return nav + (body ? body() : '');
    };

    /* ---------- Saisie ---------- */
    const on = () => isOpen && tab === 'animaux' && D && D.animaux;
    document.addEventListener('input', (ev) => {
        if (!on()) return;
        const t = ev.target, ds = t.dataset;
        if (ds.anv !== undefined && A.vendor) A.vendor[ds.anv] = t.value;
        if (ds.anvn !== undefined && A.vendor) A.vendor[ds.anvn] = Number(t.value);
        if (ds.anvb !== undefined && A.vendor) A.vendor.blip[ds.anvb] = Number(t.value);
        if (ds.anvp !== undefined && A.vendor) { if (t.value === '') delete A.vendor.prices[ds.anvp]; else A.vendor.prices[ds.anvp] = Number(t.value); }
        if (ds.ansn !== undefined && A.spDraft) A.spDraft[ds.ansn] = t.value === '' ? null : Number(t.value);
        if (ds.anvl !== undefined && A.spDraft) (A.spDraft.variants[ds.anvl] = A.spDraft.variants[ds.anvl] || {}).label = t.value;
        if (ds.anvx !== undefined && A.spDraft) (A.spDraft.variants[ds.anvx] = A.spDraft.variants[ds.anvx] || {}).extra = Number(t.value) || 0;
        if (ds.ann !== undefined && A.settings) setK(A.settings, ds.ann, t.value === '' ? null : Number(t.value));
        if (ds.anstr !== undefined && A.settings) setK(A.settings, ds.anstr, t.value.trim());
        if (ds.anap !== undefined && A.settings) A.settings.accessories[ds.anap].price = Number(t.value) || 0;
        if (ds.anf !== undefined && A.enc) A.enc[ds.anf] = t.value;
        if (ds.anfn !== undefined && A.enc) A.enc[ds.anfn] = Number(t.value);
        if (ds.anfa !== undefined && A.enc) A.enc.animals[ds.anfa] = Number(t.value) || 0;
        if (ds.anfsn !== undefined && A.farm) { const [a, b] = ds.anfsn.split('.'); if (b) A.farm[a][b] = Number(t.value); else A.farm[a] = Number(t.value); }
        if (ds.anq !== undefined) A.q = t.value;
    });
    document.addEventListener('change', (ev) => {
        if (!on()) return;
        const t = ev.target, ds = t.dataset;
        if (ds.anvc !== undefined && A.vendor) {
            const set = new Set(arr(A.vendor.catalog));
            if (t.checked) set.add(ds.anvc); else set.delete(ds.anvc);
            A.vendor.catalog = [...set];
        }
        if (ds.anve !== undefined && A.spDraft) (A.spDraft.variants[ds.anve] = A.spDraft.variants[ds.anve] || {}).enabled = t.checked;
        if (ds.anae !== undefined && A.settings) A.settings.accessories[ds.anae].enabled = t.checked;
        if (ds.anv !== undefined && A.vendor) A.vendor[ds.anv] = t.value;
    });
    document.addEventListener('keydown', (ev) => {
        if (!on() || ev.key !== 'Enter' || ev.target.dataset.anq === undefined) return;
        send('searchPets', { q: A.q });
    });

    document.addEventListener('click', async (ev) => {
        if (!on()) return;
        const d = D.animaux;
        let n;
        if ((n = ev.target.closest('[data-ans]'))) { A.sub = n.dataset.ans; A.vendor = A.enc = null; A.species = null; A.spDraft = null; return render(); }
        if ((n = ev.target.closest('[data-anvt]')) && A.vendor) {
            const k = n.dataset.anvt;
            if (k === 'blip') A.vendor.blip.enabled = !A.vendor.blip.enabled; else A.vendor[k] = !A.vendor[k];
            return render();
        }
        if ((n = ev.target.closest('[data-anst]')) && A.spDraft) { A.spDraft.enabled = !A.spDraft.enabled; return render(); }
        if ((n = ev.target.closest('[data-anb]')) && A.settings) { setK(A.settings, n.dataset.anb, !getK(A.settings, n.dataset.anb)); return render(); }
        if ((n = ev.target.closest('[data-anft]')) && A.enc) { A.enc.enabled = A.enc.enabled === false; return render(); }
        if ((n = ev.target.closest('[data-anfs]')) && A.farm) {
            const [a, b] = n.dataset.anfs.split('.');
            if (b) A.farm[a][b] = !A.farm[a][b]; else A.farm[a] = !A.farm[a];
            return render();
        }
        if (!(n = ev.target.closest('[data-ana]'))) return;
        const id = n.dataset.id;
        switch (n.dataset.ana) {
            // vendeurs
            case 'vendorNew': A.vendor = { id: '', label: 'Nouveau vendeur', enabled: true, model: arr(d.models)[0], scenario: arr(d.scenarios)[0], distance: 2.5,
                catalog: [], prices: {}, accessories: true, vet: false, blip: { enabled: true, sprite: 463, color: 5 } }; return render();
            case 'vendorEdit': A.vendor = copy(arr(d.vendors).find((v) => v.id === id)); if (Array.isArray(A.vendor.prices)) A.vendor.prices = {}; return render();
            case 'vendorCancel': A.vendor = null; return render();
            case 'vendorSave': {
                const v = copy(A.vendor);
                if (!v.id) { delete v.x; delete v.y; delete v.z; delete v.h; }
                send('vendorSave', { vendor: v }); A.vendor = null; return;
            }
            case 'vendorHere': return send('vendorHere', { id });
            case 'vendorToggle': { const v = copy(arr(d.vendors).find((x) => x.id === id)); v.enabled = !v.enabled; if (Array.isArray(v.prices)) v.prices = {}; return send('vendorSave', { vendor: v }); }
            case 'vendorDelete': if (await confirmBox(`Supprimer « ${n.dataset.label} » ?`, 'Le PNJ disparaît. Les animaux déjà achetés chez lui sont conservés.')) send('vendorDelete', { id }); return;
            case 'resetVendors': if (await confirmBox('Vendeurs par défaut ?', 'Tous les vendeurs reviennent à ceux de config.lua (positions, catalogues, prix par vendeur). Aucun animal possédé n\'est touché.')) send('resetVendors'); return;
            case 'goto': send('gotoPoint', { x: Number(n.dataset.x), y: Number(n.dataset.y), z: Number(n.dataset.z) }); post('close'); return;
            // catalogue
            case 'speciesEdit': A.species = id; A.spDraft = null; return render();
            case 'speciesCancel': A.species = null; A.spDraft = null; return render();
            case 'speciesSave': {
                const s = arr(d.species).find((x) => x.id === A.species);
                const variants = {};
                s.variants.forEach((v) => { const o = A.spDraft.variants[v.id] || {}; variants[v.id] = { enabled: o.enabled !== undefined ? o.enabled : v.enabled, label: o.label !== undefined ? o.label : v.label, extra: o.extra !== undefined ? o.extra : v.extra }; });
                send('saveSpecies', { species: A.species, values: { enabled: A.spDraft.enabled, price: A.spDraft.price, fees: A.spDraft.fees, variants } });
                A.spDraft = null; return;
            }
            case 'preview': send('preview', { species: A.species, variant: n.dataset.v }); return;
            case 'addVariant': {
                const r = await formModal('Nouveau pelage', [{ name: 'label', label: 'Libellé (vérifie avec l\'aperçu)', value: `Robe ${Number(n.dataset.t) + 1}` }], 'Ajouter');
                if (r) send('addVariant', { species: A.species, model: n.dataset.m, c: 0, d: Number(n.dataset.d), t: Number(n.dataset.t), label: r.label });
                return;
            }
            case 'removeVariant': if (await confirmBox('Retirer ce pelage ?', 'Refusé si des joueurs possèdent un animal avec ce pelage.')) send('removeVariant', { species: A.species, variant: n.dataset.v }); return;
            case 'resetSpecies': if (await confirmBox('Prix et pelages par défaut ?', 'Prix, frais, activation et libellés reviennent à config.lua ; les pelages ajoutés sont retirés. Les animaux possédés ne changent pas.')) send('resetSpecies'); return;
            // réglages
            case 'settingsSave': send('saveSettings', { values: A.settings }); A.settings = null; return;
            case 'settingsCancel': A.settings = null; return render();
            case 'settingsReset': if (await confirmBox('Valeurs par défaut ?', 'Équipements, besoins, limites et prix des accessoires reviennent à config.lua. Vendeurs, espèces, ferme et animaux possédés ne changent pas.')) { A.settings = null; send('resetSettings'); } return;
            // ferme
            case 'farmSave': send('saveFarm', { values: A.farm }); A.farm = null; return;
            case 'farmCancel': A.farm = null; return render();
            case 'resetFarm': if (await confirmBox('Ferme par défaut ?', 'Réglages et enclos reviennent à config.lua.')) { A.farm = null; send('resetFarm'); } return;
            case 'encNew': A.enc = { id: '', label: 'Nouvel enclos', radius: 10, animals: {}, enabled: true }; return render();
            case 'encEdit': A.enc = copy(arr(d.farm.settings.enclosures).find((e) => e.id === id)); if (Array.isArray(A.enc.animals)) A.enc.animals = {}; return render();
            case 'encCancel': A.enc = null; return render();
            case 'encSave': { const e = copy(A.enc); if (!e.id) { delete e.x; delete e.y; delete e.z; } send('enclosureSave', { enclosure: e }); A.enc = null; return; }
            case 'encHere': return send('enclosureHere', { id });
            case 'encDelete': if (await confirmBox(`Supprimer « ${n.dataset.label} » ?`, 'Ses animaux disparaissent avec leur état enregistré.')) send('enclosureDelete', { id }); return;
            // animaux possédés
            case 'search': return send('searchPets', { q: A.q });
            case 'petStore': return send('petStore', { id: Number(id) });
            case 'gotoPet': send('gotoPet', { id: Number(id) }); post('close'); return;
            case 'deleteOrphan': if (await confirmBox('Supprimer cette entité ?', 'Copie d\'animal qui n\'est rattachée à aucune sortie valide.')) send('deleteOrphan', { netId: Number(n.dataset.net) }); return;
            case 'petFix': {
                const p = arr(d.pets).find((x) => x.id === Number(id));
                if (!p) return;
                const r = await formModal(`Corriger ${p.name}`, [
                    { name: 'status', label: 'Statut', type: 'select', value: p.status === 'injured' ? 'injured' : 'stored', options: [{ value: 'stored', label: 'Rangé (disponible)' }, { value: 'injured', label: 'Blessé (indisponible)' }] },
                    { name: 'health', label: 'Santé (0-100)', type: 'number', value: p.health },
                    { name: 'hunger', label: 'Faim (0-100)', type: 'number', value: p.hunger },
                    { name: 'thirst', label: 'Soif (0-100)', type: 'number', value: p.thirst }], 'Corriger');
                if (r) send('petFix', { id: p.id, status: r.status, health: Number(r.health), hunger: Number(r.hunger), thirst: Number(r.thirst) });
                return;
            }
            case 'petRemove': {
                const p = arr(d.pets).find((x) => x.id === Number(id));
                if (!p) return;
                const r = await formModal(`Retirer ${p.name} à son propriétaire ?`, [{ name: 'chip', label: `Tape le numéro de puce pour confirmer : ${p.chip}`, placeholder: p.chip }], 'Retirer définitivement', true);
                if (r) send('petRemove', { id: p.id, confirm: (r.chip || '').trim().toUpperCase() });
                return;
            }
            // diagnostic
            case 'scan': send('scan'); post('close'); return;
            case 'clearIssues': return send('clearIssues');
        }
    });
})();
