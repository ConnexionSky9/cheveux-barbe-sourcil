/* =====================================================================
   ELYZEA — LOADING SCREEN · MOTEUR
   ---------------------------------------------------------------------
   Pas besoin de modifier ce fichier : tout se règle dans js/config.js.
   Modules :
     1. Utilitaires (+ registre des minuteurs, nettoyé à la fermeture)
     2. Identité (logo, nom, slogan, astuces, liens)
     3. Slideshow (Ken Burns + transitions)
     4. Progression du chargement (événements FiveM + mode démo)
     5. Lecteur musical (un seul <audio>, temps réel du média)
     6. Effets (particules, grain)
     7. Intro cinématique (logo → ELYZEA → explosion « FA » → peinture)
     8. Affichage de l'interface, sortie, événements FiveM
   ===================================================================== */
(() => {
    "use strict";

    // Sécurité : si le script est chargé deux fois, on ne crée pas un second lecteur
    if (window.__elyzeaLoadscreen) return;
    window.__elyzeaLoadscreen = true;

    /* =================================================================
       1. UTILITAIRES
       ================================================================= */
    const $ = (id) => document.getElementById(id);
    const body = document.body;
    const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
    const rand = (a, b) => a + Math.random() * (b - a);
    const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
    const pad2 = (n) => String(n).padStart(2, "0");
    const has = (name) => typeof window[name] !== "undefined";

    // Blocs déclarés dans config.js (const globales) ; chacun est facultatif
    const user = {
        server:    typeof server !== "undefined" ? server : {},
        slides:    typeof slides !== "undefined" ? slides : [],
        slideshow: typeof slideshow !== "undefined" ? slideshow : {},
        music:     typeof music !== "undefined" ? music : {},
        loading:   typeof loading !== "undefined" ? loading : {},
        tips:      typeof tips !== "undefined" ? tips : {},
        links:     typeof links !== "undefined" ? links : [],
        effects:   typeof effects !== "undefined" ? effects : {},
        intro:     typeof intro !== "undefined" ? intro : {}
    };
    const userEffects = user.effects || {};

    const cfg = {
        server:    Object.assign({ name: "", subtitle: "", slogan: "", logo: "", logoSize: "", showName: true }, user.server),
        slides:    Array.isArray(user.slides) ? user.slides : [],
        slideshow: Object.assign({ interval: 7000, transition: 1800, shuffle: false, blurTransitions: true, lightSweep: true, effects: [], transitions: [] }, user.slideshow),
        music:     Object.assign({ volume: 0.35, autoplay: true, loop: true, shuffle: false, fadeIn: 2500, playlist: [] }, user.music),
        loading:   Object.assign({ title: "Chargement", smoothing: 0.05, demoDuration: 24000, showLogLines: false, stages: {} }, user.loading),
        tips:      Object.assign({ enabled: false, interval: 8000, list: [] }, user.tips),
        links:     Array.isArray(user.links) ? user.links : [],
        effects:   Object.assign({ reduced: "auto", particles: true, particleCount: 40, grain: true, grainOpacity: 0.07, vignette: true, lightLines: true, letterbox: true, logoFloat: true, fadeOutDuration: 1200 }, userEffects),
        intro:     Object.assign({
            enabled: userEffects.intro !== false, speed: Number(userEffects.introSpeed) || 1, skippable: true,
            words: "ELYZEA", tag: "FA",
            logoAt: 250, logoDuration: 700, lettersAt: 1150, letterStagger: 170, letterFlight: 900, trails: 3,
            chargeAt: 3000, explodeAt: 3350, tagHold: 1900, wipeIn: 650, wipeOut: 800, shards: 26, sprayDots: 150
        }, user.intro)
    };

    const prefersReduced = !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
    const LITE = cfg.effects.reduced === true || (cfg.effects.reduced === "auto" && prefersReduced);
    if (LITE) body.classList.add("fx-lite");

    /** Registre des minuteurs : tout est arrêté d'un coup à la fermeture. */
    const Timers = (() => {
        const t = new Set(), i = new Set(), r = new Set();
        return {
            timeout(fn, ms) { const id = setTimeout(() => { t.delete(id); fn(); }, ms); t.add(id); return id; },
            interval(fn, ms) { const id = setInterval(fn, ms); i.add(id); return id; },
            raf(fn) { const id = requestAnimationFrame((ts) => { r.delete(id); fn(ts); }); r.add(id); return id; },
            clear(id) { clearTimeout(id); clearInterval(id); t.delete(id); i.delete(id); },
            clearAll() {
                t.forEach(clearTimeout); i.forEach(clearInterval); r.forEach(cancelAnimationFrame);
                t.clear(); i.clear(); r.clear();
            }
        };
    })();
    const wait = (ms) => new Promise((res) => Timers.timeout(res, ms));

    /** Remplace le texte d'un élément avec un petit fondu. */
    function swapText(el, text, delay = 450) {
        if (!el || el.textContent === text) return;
        el.classList.add("is-swapping");
        Timers.timeout(() => {
            el.textContent = text;
            el.classList.remove("is-swapping");
        }, delay);
    }

    function shuffleArray(arr) {
        const a = arr.slice();
        for (let i = a.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [a[i], a[j]] = [a[j], a[i]];
        }
        return a;
    }

    function cssUrl(path) {
        return `url("${String(path).replace(/"/g, '\\"')}")`;
    }

    /* =================================================================
       2. IDENTITÉ
       ================================================================= */
    function setupIdentity() {
        const s = cfg.server;

        if (s.logoSize) document.documentElement.style.setProperty("--logo-size", s.logoSize);

        // Logo (interface + intro)
        const img = $("logo");
        if (s.logo) {
            img.src = s.logo;
            img.alt = s.name || "Logo";
            $("introLogoImg").src = s.logo;
            // Masque du reflet = forme du logo (chemin résolu depuis index.html)
            const shine = document.querySelector(".emblem__shine");
            const abs = cssUrl(new URL(s.logo, document.baseURI).href);
            shine.style.webkitMaskImage = abs;
            shine.style.maskImage = abs;
            img.addEventListener("error", () => {
                console.warn("[loadscreen] Logo introuvable :", s.logo);
                $("emblem").classList.add("is-off");
                $("introLogo").classList.add("is-off");
            });
        } else {
            $("emblem").classList.add("is-off");
            $("introLogo").classList.add("is-off");
        }

        // Nom lettre par lettre
        const nameEl = $("serverName");
        if (s.showName && s.name) {
            [...s.name].forEach((ch, i) => {
                const span = document.createElement("span");
                span.className = "ch";
                span.style.setProperty("--i", i);
                span.textContent = ch === " " ? " " : ch;
                nameEl.appendChild(span);
            });
            $("serverSubtitle").textContent = s.subtitle || "";
            if (!s.subtitle) document.querySelector(".identity__sub").classList.add("is-off");
        } else {
            nameEl.classList.add("is-off");
            document.querySelector(".identity__sub").classList.add("is-off");
        }

        if (s.name) document.title = `${s.name} — Chargement`;

        // Liens
        const ul = $("links");
        cfg.links.forEach((l) => {
            if (!l || !l.value) return;
            const li = document.createElement("li");
            const small = document.createElement("small");
            const strong = document.createElement("strong");
            small.textContent = l.label || "";
            strong.textContent = l.value;
            li.append(small, strong);
            ul.appendChild(li);
        });

        // Astuces
        const tipEl = $("tip");
        const tipText = $("tipText");
        const list = (cfg.tips.list || []).filter(Boolean);
        if (!cfg.tips.enabled || !list.length) {
            tipEl.classList.add("is-off");
        } else {
            let i = 0;
            tipText.textContent = list[0];
            if (list.length > 1) {
                Timers.interval(() => {
                    i = (i + 1) % list.length;
                    swapText(tipText, list[i], 600);
                }, Math.max(3000, cfg.tips.interval));
            }
        }

        $("loaderTitle").textContent = cfg.loading.title || "";
    }

    /** Effet machine à écrire sur le slogan. */
    async function typeSlogan(speed) {
        const el = $("slogan");
        const text = cfg.server.slogan || "";
        if (!text) return;
        body.classList.add("st-slogan");
        if (speed <= 0.02) { el.textContent = text; body.classList.add("st-slogan-done"); return; }
        for (let i = 1; i <= text.length; i++) {
            el.textContent = text.slice(0, i);
            const ch = text[i - 1];
            await wait((/[.,!?]/.test(ch) ? 220 : rand(28, 60)) * speed);
        }
        body.classList.add("st-slogan-done");
    }

    /* =================================================================
       3. SLIDESHOW
       ================================================================= */
    const Slideshow = (() => {
        const root = $("slideshow");
        const sweep = $("sweep");
        const timerBar = $("captionTimer");
        const sideEl = $("captionSide");
        const countEl = $("captionCount");
        const titleEl = $("captionTitle");

        const items = cfg.slides
            .map((s) => (typeof s === "string" ? { src: s } : s))
            .filter((s) => s && s.src)
            .map((s) => Object.assign({ side: "neutral", title: "" }, s));

        const order = cfg.slideshow.shuffle ? shuffleArray(items.map((_, i) => i)) : items.map((_, i) => i);
        const cache = new Map();          // src -> Promise<boolean>
        const interval = Math.max(2000, cfg.slideshow.interval);
        const transition = clamp(cfg.slideshow.transition, 300, interval - 200);

        // Mouvement de la photo pendant son affichage : [scale, x%, y%, rotation°]
        const MOTION = {
            "zoom-in":   [[1.04, 0, 0, 0], [1.16, 0, 0, 0]],
            "zoom-out":  [[1.18, 0, 0, 0], [1.05, 0, 0, 0]],
            "pan-left":  [[1.14, 2.5, 0, 0], [1.14, -2.5, 0, 0]],
            "pan-right": [[1.14, -2.5, 0, 0], [1.14, 2.5, 0, 0]],
            "pan-up":    [[1.14, 0, 2.5, 0], [1.14, 0, -2.5, 0]],
            "pan-down":  [[1.14, 0, -2.5, 0], [1.14, 0, 2.5, 0]],
            "rotate":    [[1.12, 0, 0, -1], [1.2, 0, 0, 0.8]],
            "drift":     [[1.08, -2, 1.2, 0], [1.16, 2, -1.2, 0]]
        };
        const tf = ([s, x, y, r]) => `translate3d(${x}%, ${y}%, 0) scale(${s}) rotate(${r}deg)`;

        // Entrée de la nouvelle photo
        const ENTER = {
            "fade":       [{ opacity: 0 }, { opacity: 1 }],
            "blur":       [{ opacity: 0, filter: "blur(18px) brightness(1.5)" }, { opacity: 1, filter: "blur(0px) brightness(1)" }],
            "zoom":       [{ opacity: 0, transform: "scale(1.12)" }, { opacity: 1, transform: "scale(1)" }],
            "wipe-left":  [{ opacity: 0.4, clipPath: "inset(0 0 0 100%)" }, { opacity: 1, clipPath: "inset(0 0 0 0%)" }],
            "wipe-right": [{ opacity: 0.4, clipPath: "inset(0 100% 0 0)" }, { opacity: 1, clipPath: "inset(0 0% 0 0)" }],
            "iris":       [{ opacity: 0.3, clipPath: "circle(0% at 50% 50%)" }, { opacity: 1, clipPath: "circle(75% at 50% 50%)" }]
        };
        const CLIP_TRANSITIONS = ["wipe-left", "wipe-right", "iris"];

        const effectsPool = (cfg.slideshow.effects || []).filter((e) => MOTION[e]);
        const transitionsPool = (cfg.slideshow.transitions || [])
            .filter((t) => ENTER[t])
            .filter((t) => (cfg.slideshow.blurTransitions && !LITE) || t !== "blur");
        if (!effectsPool.length) effectsPool.push(...Object.keys(MOTION));
        if (!transitionsPool.length) transitionsPool.push("fade");

        const layers = [makeLayer(), makeLayer()];
        let active = -1;      // index du calque visible
        let pos = -1;         // position dans "order"
        let shown = 0;        // nb de photos affichées
        let busy = false;
        let timer = null;
        let started = false;
        let stopped = false;
        let validCount = 0;

        function makeLayer() {
            const el = document.createElement("div");
            el.className = "slide";
            const img = document.createElement("div");
            img.className = "slide__img";
            el.appendChild(img);
            root.appendChild(el);
            return { el, img, motion: null, enter: null, exit: null };
        }

        function preload(src) {
            if (cache.has(src)) return cache.get(src);
            const p = new Promise((resolve) => {
                const im = new Image();
                im.onload = () => {
                    const done = () => resolve(true);
                    if (im.decode) im.decode().then(done, done); else done();
                };
                im.onerror = () => {
                    console.warn("[loadscreen] Image introuvable :", src);
                    resolve(false);
                };
                im.src = src;
            });
            cache.set(src, p);
            return p;
        }

        function choose(item, key, pool, n) {
            if (item[key] && (key === "effect" ? MOTION[item[key]] : ENTER[item[key]])) return item[key];
            return pool[n % pool.length];
        }

        function cancelAll(layer) {
            ["motion", "enter", "exit"].forEach((k) => {
                if (layer[k]) { layer[k].cancel(); layer[k] = null; }
            });
        }

        function updateCaption(item, displayIndex) {
            const side = ["legal", "illegal", "neutral"].includes(item.side) ? item.side : "neutral";
            body.dataset.side = side;
            const sideLabel = item.label || (side === "legal" ? "Côté légal" : side === "illegal" ? "Côté illégal" : (cfg.server.name || ""));
            swapText(sideEl, sideLabel, 350);
            swapText(titleEl, item.title || "", 450);
            countEl.textContent = `${pad2(displayIndex + 1)} / ${pad2(items.length)}`;

            if (timerBar.animate) {
                timerBar.getAnimations().forEach((a) => a.cancel());
                timerBar.animate(
                    [{ transform: "scaleX(0)" }, { transform: "scaleX(1)" }],
                    { duration: interval + transition, easing: "linear", fill: "forwards" }
                );
            }
        }

        function lightSweep() {
            if (!cfg.slideshow.lightSweep || LITE) return;
            sweep.classList.remove("is-on");
            void sweep.offsetWidth; // relance l'animation CSS
            sweep.classList.add("is-on");
        }

        async function next() {
            if (busy || stopped) return;
            busy = true;

            // Cherche la prochaine image valide
            let item = null;
            let p = pos;
            for (let tries = 0; tries < items.length; tries++) {
                p = (p + 1) % items.length;
                const candidate = items[order[p]];
                if (await preload(candidate.src)) { item = candidate; break; }
            }

            if (!item) {
                root.classList.add("is-empty");
                body.dataset.side = "neutral";
                $("caption").classList.add("is-off");
                busy = false;
                return;
            }

            pos = p;
            const first = active === -1;
            const inIdx = first ? 0 : 1 - active;
            const incoming = layers[inIdx];
            const outgoing = first ? null : layers[active];

            const effect = choose(item, "effect", effectsPool, shown);
            const trans = first ? "fade" : choose(item, "transition", transitionsPool, shown);
            const single = validCount === 1;

            cancelAll(incoming);
            incoming.img.style.backgroundImage = cssUrl(item.src);
            incoming.el.style.zIndex = "2";
            incoming.el.style.opacity = "0";
            if (outgoing) outgoing.el.style.zIndex = "1";

            // Mouvement Ken Burns (dure tout l'affichage + les deux transitions)
            const [from, to] = MOTION[effect];
            incoming.motion = incoming.img.animate(
                [{ transform: tf(from) }, { transform: tf(to) }],
                single
                    ? { duration: interval * 2, easing: "ease-in-out", iterations: Infinity, direction: "alternate" }
                    : { duration: interval + transition * 2 + 400, easing: "linear", fill: "forwards" }
            );

            // Entrée
            const dur = first ? transition * 1.4 : transition;
            incoming.enter = incoming.el.animate(ENTER[trans], {
                duration: dur,
                easing: "cubic-bezier(.65,0,.35,1)",
                fill: "forwards"
            });
            incoming.enter.onfinish = () => {
                // Fige l'état final puis libère l'animation (évite de garder un filtre/clip actif)
                incoming.el.style.opacity = "1";
                if (incoming.enter) { incoming.enter.cancel(); incoming.enter = null; }
            };

            // Sortie de l'ancienne photo
            if (outgoing) {
                const hold = CLIP_TRANSITIONS.includes(trans);
                const exitFrames = hold
                    ? [{ opacity: 1 }, { opacity: 1, offset: 0.75 }, { opacity: 0 }]
                    : [{ opacity: 1, transform: "scale(1)" }, { opacity: 0, transform: "scale(1.05)" }];
                outgoing.exit = outgoing.el.animate(exitFrames, {
                    duration: transition,
                    easing: "cubic-bezier(.65,0,.35,1)",
                    fill: "forwards"
                });
                outgoing.exit.onfinish = () => {
                    outgoing.el.style.opacity = "0";
                    cancelAll(outgoing);
                };
                lightSweep();
            }

            active = inIdx;
            updateCaption(item, pos);
            shown++;

            // Précharge la suivante pendant l'affichage
            const upcoming = items[order[(pos + 1) % items.length]];
            if (upcoming) preload(upcoming.src);

            await wait(dur);
            busy = false;

            if (!single && !stopped) {
                if (timer) Timers.clear(timer);
                timer = Timers.timeout(next, interval);
            }
        }

        /** Précharge la première photo dès le démarrage (pendant l'intro). */
        function warmup() {
            if (items.length) preload(items[order[0]].src);
        }

        async function start() {
            if (started) return;
            started = true;
            if (!items.length) {
                root.classList.add("is-empty");
                $("caption").classList.add("is-off");
                body.dataset.side = "neutral";
                return;
            }
            const results = await Promise.all(items.map((i) => preload(i.src)));
            validCount = results.filter(Boolean).length;
            next();
        }

        function stop() {
            stopped = true;
            layers.forEach(cancelAll);
        }

        return { start, warmup, stop };
    })();

    /* =================================================================
       4. PROGRESSION DU CHARGEMENT
       ================================================================= */
    const Progress = (() => {
        const fill = $("loaderFill");
        const pctEl = $("loaderPct");
        const statusEl = $("loaderStatus");
        const logEl = $("loaderLog");
        const stages = cfg.loading.stages || {};

        // Plage de pourcentage attribuée à chaque phase de chargement FiveM
        const RANGES = {
            INIT_CORE:              [2, 10,  "core"],
            INIT_BEFORE_MAP_LOADED: [10, 25, "before"],
            MAP:                    [25, 55, "data"],
            MAPLOAD:                [55, 66, "map"],
            INIT_AFTER_MAP_LOADED:  [66, 82, "after"],
            INIT_SESSION:           [82, 97, "session"]
        };
        const counts = {};
        const done = {};

        let target = 0;
        let shown = 0;
        let ceiling = 8;       // plafond actuel de l'avance automatique
        let finished = false;
        let running = false;
        let lastBump = performance.now();
        let lastFrame = performance.now();
        let lastPct = -1;

        function setStatus(key) {
            const label = stages[key];
            if (label) swapText(statusEl, label, 300);
        }

        function setTarget(v) {
            v = clamp(v, 0, finished ? 100 : 99);
            if (v > target) {
                target = v;
                lastBump = performance.now();
            }
        }

        function enter(type) {
            const r = RANGES[type];
            if (!r) return;
            ceiling = Math.max(ceiling, r[1]);
            setTarget(r[0]);
            setStatus(r[2]);
        }

        function advance(type) {
            const r = RANGES[type];
            if (!r) return;
            const c = Math.max(1, counts[type] || 1);
            const ratio = clamp((done[type] || 0) / c, 0, 1);
            setTarget(r[0] + (r[1] - r[0]) * ratio);
        }

        const handlers = {
            startInitFunctionOrder(d) {
                counts[d.type] = d.count || 1;
                done[d.type] = 0;
                enter(d.type);
            },
            initFunctionInvoking(d) {
                done[d.type] = Math.max(done[d.type] || 0, (d.idx || 0) + 1);
                advance(d.type);
            },
            endInitFunction(d) {
                if (d && d.type) { done[d.type] = counts[d.type] || 1; advance(d.type); }
            },
            startDataFileEntries(d) {
                counts.MAP = d.count || 1;
                done.MAP = 0;
                enter("MAP");
            },
            onDataFileEntry() {
                done.MAP = (done.MAP || 0) + 1;
                advance("MAP");
            },
            endDataFileEntries() {
                done.MAP = counts.MAP || 1;
                advance("MAP");
            },
            performMapLoadFunction() {
                if (!done.MAPLOAD) enter("MAPLOAD");
                done.MAPLOAD = (done.MAPLOAD || 0) + 1;
                counts.MAPLOAD = Math.max(counts.MAPLOAD || 8, done.MAPLOAD + 2);
                advance("MAPLOAD");
            },
            onLogLine(d) {
                if (cfg.loading.showLogLines && d && d.message) logEl.textContent = d.message;
            },
            loadProgress(d) {
                if (d && typeof d.loadFraction === "number") setTarget(d.loadFraction * 100);
            }
        };

        function frame(now) {
            const dt = Math.min(100, now - lastFrame);
            lastFrame = now;

            // Avance lente automatique : la barre ne semble jamais figée
            if (!finished && now - lastBump > 1200 && target < ceiling - 1) {
                target = Math.min(ceiling - 1, target + 0.35 * (dt / 1000) * 2);
            }

            const smooth = finished ? Math.max(0.12, cfg.loading.smoothing) : cfg.loading.smoothing;
            const k = 1 - Math.pow(1 - clamp(smooth, 0.005, 0.5), dt / 16.67);
            shown += (target - shown) * k;
            if (Math.abs(target - shown) < (finished ? 0.5 : 0.02)) shown = target;

            fill.style.transform = `translateX(${(shown - 100).toFixed(3)}%)`;
            const pct = Math.floor(shown);
            if (pct !== lastPct) {
                pctEl.textContent = pct;
                lastPct = pct;
            }
            // Une fois à 100 %, la boucle s'arrête (plus aucun calcul inutile)
            if (finished && shown >= 100) { running = false; return; }
            Timers.raf(frame);
        }

        function wake() {
            if (running) return;
            running = true;
            Timers.raf((t) => { lastFrame = t; frame(t); });
        }

        function finish() {
            finished = true;
            ceiling = 100;
            setTarget(100);
            setStatus("done");
            wake();
        }

        function start() {
            setStatus("start");
            wake();
        }

        /** Affiche directement la valeur finale (utilisé à la fermeture). */
        function snap() {
            shown = target;
            fill.style.transform = `translateX(${(shown - 100).toFixed(3)}%)`;
            pctEl.textContent = Math.floor(shown);
        }

        /** Simulation du chargement hors FiveM (aperçu dans un navigateur). */
        function demo() {
            const total = Math.max(6000, cfg.loading.demoDuration);
            const plan = [
                [0.02, "startInitFunctionOrder", { type: "INIT_CORE", count: 6 }],
                ...Array.from({ length: 6 }, (_, i) => [0.03 + i * 0.012, "initFunctionInvoking", { type: "INIT_CORE", idx: i }]),
                [0.12, "startInitFunctionOrder", { type: "INIT_BEFORE_MAP_LOADED", count: 10 }],
                ...Array.from({ length: 10 }, (_, i) => [0.13 + i * 0.012, "initFunctionInvoking", { type: "INIT_BEFORE_MAP_LOADED", idx: i }]),
                [0.26, "startDataFileEntries", { count: 30 }],
                ...Array.from({ length: 30 }, (_, i) => [0.27 + i * 0.008, "onDataFileEntry", {}]),
                ...Array.from({ length: 8 }, (_, i) => [0.53 + i * 0.015, "performMapLoadFunction", {}]),
                [0.66, "startInitFunctionOrder", { type: "INIT_AFTER_MAP_LOADED", count: 12 }],
                ...Array.from({ length: 12 }, (_, i) => [0.67 + i * 0.011, "initFunctionInvoking", { type: "INIT_AFTER_MAP_LOADED", idx: i }]),
                [0.82, "startInitFunctionOrder", { type: "INIT_SESSION", count: 10 }],
                ...Array.from({ length: 10 }, (_, i) => [0.83 + i * 0.014, "initFunctionInvoking", { type: "INIT_SESSION", idx: i }])
            ];
            plan.forEach(([at, name, data]) => Timers.timeout(() => handlers[name](data), at * total));
            Timers.timeout(finish, total);
        }

        function handle(name, data) {
            const h = handlers[name];
            if (h) h(data || {});
        }

        return { start, finish, demo, handle, snap };
    })();

    /* =================================================================
       5. LECTEUR MUSICAL
       ================================================================= */
    const Music = (() => {
        const audio = $("audio");
        const player = $("player");
        const titleEl = $("trackTitle");
        const artistEl = $("trackArtist");
        const labelEl = $("playerLabel");
        const curEl = $("timeCurrent");
        const totEl = $("timeTotal");
        const seekBar = $("seekBar");
        const seekFill = $("seekFill");
        const seekBuffer = $("seekBuffer");
        const volBar = $("volumeBar");
        const volFill = $("volumeFill");

        const m = cfg.music;
        const tracks = (Array.isArray(m.playlist) && m.playlist.filter((t) => t && t.file).length
            ? m.playlist.filter((t) => t && t.file)
            : (m.file ? [{ file: m.file, title: m.title, artist: m.artist, duration: m.duration }] : []));

        const order = m.shuffle ? shuffleArray(tracks.map((_, i) => i)) : tracks.map((_, i) => i);
        let pos = 0;
        let volume = clamp(Number(m.volume) || 0, 0, 1);
        let muted = false;
        let errors = 0;
        let fadeRaf = 0;
        let draggingSeek = false;
        let unlockBound = false;
        let fallbackDuration = 0;
        let empty = false;
        let stopped = false;

        try {
            const saved = localStorage.getItem("elyzea_ls_volume");
            if (saved !== null && !isNaN(parseFloat(saved))) volume = clamp(parseFloat(saved), 0, 1);
        } catch (e) { /* stockage indisponible : on ignore */ }

        const fmt = (s) => {
            if (!isFinite(s) || s < 0) s = 0;
            s = Math.floor(s);
            return `${pad2(Math.floor(s / 60))}:${pad2(s % 60)}`;
        };

        function parseDuration(d) {
            if (typeof d === "number") return d;
            if (typeof d === "string" && d.includes(":")) {
                return d.split(":").reduce((acc, v) => acc * 60 + (parseFloat(v) || 0), 0);
            }
            return parseFloat(d) || 0;
        }

        function duration() {
            return isFinite(audio.duration) && audio.duration > 0 ? audio.duration : fallbackDuration;
        }

        /** Indicateur d'état : loading | playing | paused | stopped | blocked | error */
        const STATE_LABEL = {
            loading: "Chargement…", playing: "En lecture", paused: "En pause",
            stopped: "Arrêté", blocked: "En attente d'un clic", error: "Musique indisponible"
        };
        function setState(state) {
            player.dataset.state = state;
            const n = tracks.length > 1 && state !== "error" ? ` · ${pos + 1}/${tracks.length}` : "";
            labelEl.textContent = STATE_LABEL[state] + n;
            player.classList.toggle("is-playing", state === "playing");
        }

        function setEmpty(title, detail) {
            empty = true;
            player.classList.add("is-empty");
            body.classList.remove("needs-unlock");
            setState("error");
            titleEl.textContent = title;
            artistEl.textContent = detail || "";
            totEl.textContent = "--:--";
        }

        function renderVolume() {
            volFill.style.width = `${(muted ? 0 : volume) * 100}%`;
            player.classList.toggle("is-muted", muted || volume === 0);
        }

        function applyVolume(v) {
            cancelAnimationFrame(fadeRaf);
            audio.volume = clamp(v, 0, 1);
        }

        function fadeTo(to, ms, then) {
            cancelAnimationFrame(fadeRaf);
            const from = audio.volume;
            const t0 = performance.now();
            const step = (now) => {
                const k = ms > 0 ? clamp((now - t0) / ms, 0, 1) : 1;
                audio.volume = clamp(from + (to - from) * k, 0, 1);
                if (k < 1) fadeRaf = requestAnimationFrame(step);
                else if (then) then();
            };
            fadeRaf = requestAnimationFrame(step);
        }

        function renderTime() {
            const d = duration();
            curEl.textContent = fmt(audio.currentTime);
            totEl.textContent = d ? fmt(d) : "--:--";
            seekFill.style.width = d ? `${clamp(audio.currentTime / d, 0, 1) * 100}%` : "0%";
        }

        function load(i) {
            pos = (i + tracks.length) % tracks.length;
            const t = tracks[order[pos]];
            fallbackDuration = parseDuration(t.duration);
            titleEl.textContent = t.title || t.file.split("/").pop();
            artistEl.textContent = t.artist || "";
            curEl.textContent = "00:00";
            totEl.textContent = fallbackDuration ? fmt(fallbackDuration) : "--:--";
            seekFill.style.width = "0%";
            seekBuffer.style.width = "0%";
            audio.loop = tracks.length === 1 && !!m.loop;
            setState("loading");
            audio.src = t.file;
            audio.load();
        }

        function play(withFade) {
            if (empty) return;
            stopped = false;
            if (withFade && m.fadeIn > 0) audio.volume = 0;
            const p = audio.play();
            const ok = () => {
                body.classList.remove("needs-unlock");
                if (withFade && m.fadeIn > 0) fadeTo(volume, m.fadeIn);
                else applyVolume(volume);
            };
            if (p && p.then) {
                p.then(ok).catch((err) => {
                    if (err && err.name === "NotAllowedError") requireUnlock();
                    else if (err && err.name !== "AbortError" && err.name !== "NotSupportedError") console.warn("[loadscreen] Lecture impossible :", err);
                });
            } else ok();
        }

        function pause() { audio.pause(); }

        function stop() {
            if (empty) return;
            stopped = true;
            cancelAnimationFrame(fadeRaf);
            audio.pause();
            try { audio.currentTime = 0; } catch (e) { /* média pas encore prêt */ }
            renderTime();
            setState("stopped");
        }

        function toggle() {
            if (empty) return;
            if (audio.paused) play(false); else pause();
        }

        function step(dir) {
            if (tracks.length < 2 || empty) return;
            load(pos + dir);
            play(false);
        }

        /** Autoplay refusé : on attend la première interaction de l'utilisateur. */
        function requireUnlock() {
            body.classList.add("needs-unlock");
            setState("blocked");
            if (unlockBound) return;
            unlockBound = true;
            const go = () => {
                document.removeEventListener("pointerdown", go, true);
                document.removeEventListener("keydown", go, true);
                unlockBound = false;
                if (audio.paused && !stopped) play(true);
            };
            document.addEventListener("pointerdown", go, true);
            document.addEventListener("keydown", go, true);
        }

        /** Curseur générique (progression / volume) cliquable et glissable. */
        function makeSlider(el, onMove, onCommit) {
            const ratioAt = (x) => {
                const r = el.getBoundingClientRect();
                return clamp((x - r.left) / r.width, 0, 1);
            };
            el.addEventListener("pointerdown", (e) => {
                if (e.button !== undefined && e.button !== 0) return;
                e.preventDefault();
                el.setPointerCapture && el.setPointerCapture(e.pointerId);
                el.classList.add("is-dragging");
                onMove(ratioAt(e.clientX), true);
                const move = (ev) => onMove(ratioAt(ev.clientX), true);
                const up = (ev) => {
                    el.classList.remove("is-dragging");
                    el.removeEventListener("pointermove", move);
                    el.removeEventListener("pointerup", up);
                    el.removeEventListener("pointercancel", up);
                    onCommit(ratioAt(ev.clientX));
                };
                el.addEventListener("pointermove", move);
                el.addEventListener("pointerup", up);
                el.addEventListener("pointercancel", up);
            });
            el.addEventListener("keydown", (e) => {
                if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
                e.preventDefault();
                e.stopPropagation();
                onCommit(null, e.key === "ArrowRight" ? 1 : -1);
            });
        }

        function bind() {
            audio.addEventListener("playing", () => { errors = 0; setState("playing"); });
            audio.addEventListener("play", () => setState("playing"));
            audio.addEventListener("pause", () => { if (!empty) setState(stopped ? "stopped" : "paused"); });
            audio.addEventListener("waiting", () => { if (!audio.paused) setState("loading"); });

            audio.addEventListener("loadedmetadata", renderTime);
            audio.addEventListener("durationchange", renderTime);

            audio.addEventListener("timeupdate", () => {
                if (draggingSeek) return;
                renderTime();
            });

            audio.addEventListener("progress", () => {
                const d = duration();
                if (!d || !audio.buffered.length) return;
                seekBuffer.style.width = `${clamp(audio.buffered.end(audio.buffered.length - 1) / d, 0, 1) * 100}%`;
            });

            audio.addEventListener("ended", () => {
                if (tracks.length > 1) {
                    if (!m.loop && pos === tracks.length - 1) { stopped = true; setState("stopped"); return; }
                    load(pos + 1);
                    play(false);
                } else if (!audio.loop) {
                    stopped = true;
                    setState("stopped");
                }
            });

            audio.addEventListener("error", () => {
                const t = tracks[order[pos]];
                console.warn("[loadscreen] Musique introuvable ou illisible :", t && t.file);
                errors++;
                if (errors < tracks.length) {
                    load(pos + 1);
                    play(false);
                } else {
                    setEmpty("Aucune musique lisible", "Vérifie le fichier dans assets/music/");
                }
            });

            $("btnPlay").addEventListener("click", (e) => { e.stopPropagation(); toggle(); });
            $("btnStop").addEventListener("click", (e) => { e.stopPropagation(); stop(); });
            $("btnPrev").addEventListener("click", (e) => { e.stopPropagation(); step(-1); });
            $("btnNext").addEventListener("click", (e) => { e.stopPropagation(); step(1); });
            $("unlock").addEventListener("click", (e) => { e.stopPropagation(); play(true); });

            $("btnMute").addEventListener("click", (e) => {
                e.stopPropagation();
                toggleMute();
            });

            makeSlider(seekBar,
                (r) => {
                    draggingSeek = true;
                    seekFill.style.width = `${r * 100}%`;
                    curEl.textContent = fmt(r * duration());
                },
                (r, keyDir) => {
                    draggingSeek = false;
                    const d = duration();
                    if (!d || empty) return;
                    audio.currentTime = keyDir ? clamp(audio.currentTime + keyDir * 5, 0, d) : r * d;
                    renderTime();
                }
            );

            makeSlider(volBar,
                (r) => setVolume(r),
                (r, keyDir) => setVolume(keyDir ? volume + keyDir * 0.05 : r, true)
            );

            // Raccourcis : Espace = lecture/pause, S = stop, M = muet, ← / → = ±5 s
            document.addEventListener("keydown", (e) => {
                if (e.repeat) return;
                if (e.code === "Space") { e.preventDefault(); toggle(); }
                else if (e.key === "s" || e.key === "S") stop();
                else if (e.key === "m" || e.key === "M") toggleMute();
                else if (e.key === "ArrowRight" || e.key === "ArrowLeft") {
                    const d = duration();
                    if (d && !empty) audio.currentTime = clamp(audio.currentTime + (e.key === "ArrowRight" ? 5 : -5), 0, d);
                }
            });
        }

        function setVolume(v, save) {
            volume = clamp(v, 0, 1);
            muted = volume === 0;
            audio.muted = muted;
            applyVolume(volume);
            renderVolume();
            if (save) {
                try { localStorage.setItem("elyzea_ls_volume", String(volume)); } catch (e) { /* ignore */ }
            }
        }

        function toggleMute() {
            muted = !muted;
            if (!muted && volume === 0) volume = 0.3;
            audio.muted = muted;
            if (!muted) applyVolume(volume);
            renderVolume();
        }

        let inited = false;
        function init() {
            if (inited) return;      // jamais deux initialisations du lecteur
            inited = true;
            bind();
            renderVolume();
            if (!tracks.length) {
                setEmpty("Aucune musique configurée", "Voir js/config.js");
                return;
            }
            player.classList.toggle("is-single", tracks.length < 2);
            load(0);
            applyVolume(volume);
            if (m.autoplay) play(true);
            else setState("paused");
        }

        /** Coupe le son en douceur à la fermeture du loading screen. */
        function fadeOut(ms) {
            if (empty || audio.paused) return;
            fadeTo(0, ms, () => audio.pause());
        }

        return { init, fadeOut };
    })();

    /* =================================================================
       6. EFFETS
       ================================================================= */
    let stopParticles = () => {};
    function setupEffects() {
        const e = cfg.effects;
        if (!e.vignette) $("vignette").classList.add("is-off");
        if (!e.letterbox) $("letterbox").classList.add("is-off");
        if (!e.lightLines || LITE) $("lightLines").classList.add("is-off");
        if (e.logoFloat && !LITE) body.classList.add("float");

        // Grain : petite texture de bruit générée une seule fois
        const grain = $("grain");
        if (e.grain) {
            const c = document.createElement("canvas");
            c.width = c.height = 160;
            const ctx = c.getContext("2d");
            const data = ctx.createImageData(160, 160);
            for (let i = 0; i < data.data.length; i += 4) {
                const v = Math.random() * 255;
                data.data[i] = data.data[i + 1] = data.data[i + 2] = v;
                data.data[i + 3] = 255;
            }
            ctx.putImageData(data, 0, 0);
            grain.style.backgroundImage = `url(${c.toDataURL("image/png")})`;
            grain.style.setProperty("--grain-opacity", clamp(e.grainOpacity, 0, 0.3));
        } else {
            grain.classList.add("is-off");
        }

        // Particules : braises discrètes (or / bleu / rouge)
        const canvas = $("particles");
        if (!e.particles || LITE) {
            canvas.classList.add("is-off");
            return;
        }
        const ctx = canvas.getContext("2d");
        const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
        const colors = ["236,204,140", "236,204,140", "236,204,140", "46,110,255", "255,44,66"];
        let w = 0, h = 0, alive = true;

        const resize = () => {
            w = canvas.width = Math.floor(window.innerWidth * dpr);
            h = canvas.height = Math.floor(window.innerHeight * dpr);
        };
        resize();
        window.addEventListener("resize", resize);

        const spawn = (initial) => ({
            x: Math.random() * w,
            y: initial ? Math.random() * h : h + 20 * dpr,
            r: rand(0.6, 1.9) * dpr,
            vy: rand(0.12, 0.45) * dpr,
            vx: rand(-0.12, 0.12) * dpr,
            a: rand(0.25, 0.8),
            ph: Math.random() * Math.PI * 2,
            c: colors[Math.floor(Math.random() * colors.length)]
        });
        const parts = Array.from({ length: clamp(e.particleCount | 0, 0, 150) }, () => spawn(true));

        let last = performance.now();
        const loop = (now) => {
            if (!alive) return;
            if (body.classList.contains("intro-on")) { last = now; Timers.raf(loop); return; } // caché par l'intro : on ne dessine rien
            const dt = Math.min(3, (now - last) / 16.67);
            last = now;
            ctx.clearRect(0, 0, w, h);
            ctx.globalCompositeOperation = "lighter";
            for (const p of parts) {
                p.y -= p.vy * dt;
                p.x += (p.vx + Math.sin(now * 0.0006 + p.ph) * 0.15 * dpr) * dt;
                if (p.y < -20 * dpr || p.x < -20 || p.x > w + 20) Object.assign(p, spawn(false));
                const life = clamp(p.y / h, 0, 1);
                const alpha = p.a * (0.55 + 0.45 * Math.sin(now * 0.002 + p.ph)) * life;
                ctx.fillStyle = `rgba(${p.c},${(alpha * 0.18).toFixed(3)})`;
                ctx.beginPath(); ctx.arc(p.x, p.y, p.r * 4, 0, Math.PI * 2); ctx.fill();
                ctx.fillStyle = `rgba(${p.c},${alpha.toFixed(3)})`;
                ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill();
            }
            Timers.raf(loop);
        };
        Timers.raf(loop);
        stopParticles = () => { alive = false; window.removeEventListener("resize", resize); };
    }

    /* =================================================================
       7. INTRO CINÉMATIQUE
       Logo (impact, flash, éclats, secousse) → les lettres E-L-Y-Z-E-A
       sortent du logo une par une (trajet propre + traînées) et se placent
       à côté → charge → explosion + « FA » graffiti → coup de peinture
       qui révèle l'interface. Tous les temps viennent de config.js (intro).
       ================================================================= */
    const Intro = (() => {
        const T = cfg.intro;
        const K = clamp(Number(T.speed) || 1, 0.2, 3);
        const root = $("intro");
        const shake = $("introShake");
        const lockup = $("introLockup");
        const logoBox = $("introLogo");
        const word = $("introWord");
        const ring = $("introRing");
        const splatBox = $("introSplats");
        const faBox = $("introFa");
        const flash = $("introFlash");
        const skipBtn = $("introSkip");
        const wipe = $("wipe");
        const canvas = $("introFx");

        const COLORS = ["#eccc8c", "#fff1cf", "#2e6eff", "#5d8dff", "#ff2c42", "#ff6b7d"];
        const anims = [];
        const timers = [];
        let finished = false;
        let wiping = false;
        let onReveal = () => {};
        let resolveDone = () => {};

        const at = (ms, fn) => timers.push(Timers.timeout(fn, ms * K));
        function anim(el, frames, o) {
            if (!el || !el.animate) return null;
            const a = el.animate(frames, Object.assign({ fill: "forwards", easing: "linear" }, o, {
                duration: Math.max(1, (o.duration || 300) * K), delay: (o.delay || 0) * K
            }));
            anims.push(a);
            return a;
        }

        /* ---------- Particules de l'intro (canvas, ne tourne que s'il y a des particules) ---------- */
        const FX = (() => {
            const ctx = canvas.getContext("2d");
            let w = 0, h = 0, dpr = 1, parts = [], running = false, last = 0;
            function size() {
                dpr = Math.min(window.devicePixelRatio || 1, 1.5);
                w = canvas.width = Math.floor(window.innerWidth * dpr);
                h = canvas.height = Math.floor(window.innerHeight * dpr);
            }
            size();
            window.addEventListener("resize", size);

            function emit(x, y, n, kind, spread) {
                if (LITE || n <= 0) return;
                x *= dpr; y *= dpr;
                for (let i = 0; i < n; i++) {
                    const ang = Math.random() * Math.PI * 2;
                    const sp = (kind === "shard" ? rand(5, 15) : kind === "dot" ? rand(2, spread || 22) : rand(8, 20)) * dpr;
                    parts.push({
                        kind, x, y,
                        vx: Math.cos(ang) * sp, vy: Math.sin(ang) * sp - (kind === "shard" ? 3 * dpr : 0),
                        r: (kind === "shard" ? rand(5, 16) : kind === "dot" ? rand(1, 4.2) : rand(1, 2)) * dpr,
                        rot: Math.random() * 6.28, vr: rand(-0.3, 0.3),
                        life: 0, max: kind === "shard" ? rand(700, 1100) : kind === "dot" ? rand(700, 1400) : rand(300, 600),
                        c: pick(COLORS)
                    });
                }
                if (!running) { running = true; last = performance.now(); Timers.raf(loop); }
            }

            function loop(now) {
                const dt = Math.min(48, now - last);
                last = now;
                const f = dt / 16.67;
                ctx.clearRect(0, 0, w, h);
                for (let i = parts.length - 1; i >= 0; i--) {
                    const p = parts[i];
                    p.life += dt;
                    if (p.life >= p.max) { parts[i] = parts[parts.length - 1]; parts.pop(); continue; }
                    const drag = p.kind === "dot" ? 0.93 : 0.965;
                    p.vx *= Math.pow(drag, f); p.vy = p.vy * Math.pow(drag, f) + 0.32 * dpr * f;
                    p.x += p.vx * f; p.y += p.vy * f; p.rot += p.vr * f;
                    const a = 1 - p.life / p.max;
                    ctx.globalAlpha = a;
                    ctx.fillStyle = p.c;
                    if (p.kind === "shard") {
                        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
                        ctx.beginPath(); ctx.moveTo(0, -p.r); ctx.lineTo(p.r * 0.6, p.r * 0.7); ctx.lineTo(-p.r * 0.7, p.r * 0.4); ctx.closePath(); ctx.fill();
                        ctx.restore();
                    } else if (p.kind === "dot") {
                        ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 6.283); ctx.fill();
                    } else {
                        ctx.strokeStyle = p.c; ctx.lineWidth = p.r;
                        ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * 2.2, p.y - p.vy * 2.2); ctx.stroke();
                    }
                }
                ctx.globalAlpha = 1;
                if (parts.length) Timers.raf(loop); else { running = false; ctx.clearRect(0, 0, w, h); }
            }

            function stop() { parts = []; running = false; ctx.clearRect(0, 0, w, h); window.removeEventListener("resize", size); }
            return { emit, stop };
        })();

        /* ---------- Petits effets réutilisables ---------- */
        function shakeIt(power, ms) {
            if (LITE) return;
            const p = power;
            anim(shake, [
                { transform: "translate3d(0,0,0)" },
                { transform: `translate3d(${-p}px,${p * 0.6}px,0) rotate(${-p * 0.04}deg)` },
                { transform: `translate3d(${p * 0.8}px,${-p * 0.7}px,0)` },
                { transform: `translate3d(${-p * 0.5}px,${-p * 0.4}px,0) rotate(${p * 0.03}deg)` },
                { transform: `translate3d(${p * 0.4}px,${p * 0.5}px,0)` },
                { transform: `translate3d(${-p * 0.2}px,${p * 0.1}px,0)` },
                { transform: "translate3d(0,0,0)" }
            ], { duration: ms, fill: "none" });
        }
        function flashIt(max, ms) {
            if (LITE) return;
            anim(flash, [{ opacity: max }, { opacity: 0 }], { duration: ms, easing: "cubic-bezier(.2,.7,.3,1)", fill: "none" });
        }
        function ringIt(x, y, scale, ms) {
            if (LITE) return;
            ring.style.left = `${x}px`;
            ring.style.top = `${y}px`;
            anim(ring, [
                { transform: "translate(-50%,-50%) scale(.2)", opacity: 1 },
                { transform: `translate(-50%,-50%) scale(${scale})`, opacity: 0 }
            ], { duration: ms, easing: "cubic-bezier(.1,.7,.2,1)", fill: "none" });
        }
        const centerOf = (el) => {
            const r = el.getBoundingClientRect();
            return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
        };

        /* ---------- Construction des lettres ---------- */
        function buildWord() {
            const letters = [...String(T.words || "")];
            const trails = LITE ? 0 : clamp(T.trails | 0, 0, 5);
            return letters.map((ch, i) => {
                const slot = document.createElement("span");
                slot.className = "intro__slot";
                const glyph = document.createElement("b");
                glyph.textContent = ch;
                const ghosts = [];
                for (let t = 0; t < trails; t++) {
                    const g = document.createElement("i");
                    g.textContent = ch;
                    g.style.setProperty("--trail", t);
                    g.className = i % 2 ? "is-red" : "is-blue";
                    slot.appendChild(g);
                    ghosts.push(g);
                }
                slot.appendChild(glyph);
                word.appendChild(slot);
                return { slot, glyph, ghosts, i };
            });
        }

        // Trajets : chaque lettre a sa propre courbe (point de contrôle + rotation)
        const PATHS = [
            (dx, dy) => ({ mid: [dx * 0.45, dy - 0.55 * Math.abs(dx) - 40], rot: [-35, 8] }),   // arc par le haut
            (dx, dy) => ({ mid: [dx * 0.5, dy + 0.5 * Math.abs(dx) + 30], rot: [30, -6] }),     // arc par le bas
            (dx, dy) => ({ mid: [dx * 0.2, dy - 0.8 * Math.abs(dx) - 60], rot: [-360, 0] }),    // boucle (tour complet)
            (dx, dy) => ({ mid: [dx * 0.65, dy + 0.35 * Math.abs(dx)], rot: [180, -10] }),      // vrille par le bas
            (dx, dy) => ({ mid: [dx * 0.3, dy - 0.35 * Math.abs(dx) - 90], rot: [-90, 12] }),   // saut
            (dx, dy) => ({ mid: [dx * 0.55, dy + 0.7 * Math.abs(dx) + 50], rot: [360, 0] })     // boucle inverse
        ];

        function flyLetters(letters, origin) {
            letters.forEach((L, i) => {
                const c = centerOf(L.slot);
                const dx = origin.x - c.x;
                const dy = origin.y - c.y;
                const path = PATHS[i % PATHS.length](dx, dy);
                // Coordonnées relatives à la case finale : départ (logo) → point de contrôle → dépassement → place
                const [mx, my] = path.mid;
                const frames = (fadeEnd) => [
                    { transform: `translate(${dx}px,${dy}px) scale(.1) rotate(${path.rot[0] * 0.3}deg)`, opacity: 0, offset: 0 },
                    { transform: `translate(${dx * 0.85}px,${dy * 0.85 - 10}px) scale(.55) rotate(${path.rot[0] * 0.5}deg)`, opacity: 1, offset: 0.12 },
                    { transform: `translate(${mx}px,${my}px) scale(1.35) rotate(${path.rot[0]}deg)`, opacity: 1, offset: 0.55 },
                    { transform: `translate(${-dx * 0.04}px,${-dy * 0.04 - 6}px) scale(1.1) rotate(${path.rot[1]}deg)`, opacity: 1, offset: 0.85 },
                    { transform: "translate(0,0) scale(1) rotate(0deg)", opacity: fadeEnd ? 0 : 1, offset: 1 }
                ];
                const delay = T.lettersAt + i * T.letterStagger;
                const easing = "cubic-bezier(.33,.0,.2,1)";
                L.glyph.style.opacity = "0";
                anim(L.glyph, frames(false), { duration: T.letterFlight, delay, easing });
                L.ghosts.forEach((g, t) => {
                    g.style.opacity = "0";
                    anim(g, frames(true), { duration: T.letterFlight, delay: delay + 45 * (t + 1), easing, composite: "replace" });
                });
                // Atterrissage : petit écrasement + gouttelettes
                at(delay + T.letterFlight, () => {
                    anim(L.slot, [
                        { transform: "scale(1.18,.78)" }, { transform: "scale(.94,1.08)" }, { transform: "scale(1)" }
                    ], { duration: 260, easing: "ease-out" });
                    const p = centerOf(L.slot);
                    FX.emit(p.x, p.y + L.slot.offsetHeight * 0.35, 10, "dot", 7);
                });
            });
        }

        /* ---------- Éclaboussures SVG de l'explosion ---------- */
        function splatSvg(color) {
            // Tache arrondie (courbes lissées) + doigts de projection + gouttelettes
            const n = 14, pts = [];
            for (let k = 0; k < n; k++) {
                const a = (k / n) * Math.PI * 2, r = 30 * rand(0.78, 1.12);
                pts.push([50 + Math.cos(a) * r, 50 + Math.sin(a) * r]);
            }
            const mid = (p, q) => [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];
            let d = `M${mid(pts[0], pts[1]).map((v) => v.toFixed(1)).join(" ")}`;
            for (let k = 1; k <= n; k++) {
                const p = pts[k % n], m = mid(p, pts[(k + 1) % n]);
                d += ` Q${p[0].toFixed(1)} ${p[1].toFixed(1)} ${m[0].toFixed(1)} ${m[1].toFixed(1)}`;
            }
            let extra = "";
            for (let k = 0; k < 5; k++) {
                const a = Math.random() * Math.PI * 2, r0 = 26, r1 = r0 + rand(14, 30);
                const x1 = 50 + Math.cos(a) * r1, y1 = 50 + Math.sin(a) * r1;
                extra += `<path d="M${(50 + Math.cos(a) * r0).toFixed(1)} ${(50 + Math.sin(a) * r0).toFixed(1)} L${x1.toFixed(1)} ${y1.toFixed(1)}" stroke="${color}" stroke-width="${rand(3, 6).toFixed(1)}" stroke-linecap="round"/>`;
                extra += `<circle cx="${x1.toFixed(1)}" cy="${y1.toFixed(1)}" r="${rand(3, 5.5).toFixed(1)}"/>`;
            }
            for (let k = 0; k < 9; k++) {
                const a = Math.random() * Math.PI * 2, r = rand(46, 66);
                extra += `<circle cx="${(50 + Math.cos(a) * r).toFixed(1)}" cy="${(50 + Math.sin(a) * r).toFixed(1)}" r="${rand(1.2, 3.6).toFixed(1)}"/>`;
            }
            return `<svg viewBox="-20 -20 140 140"><g fill="${color}"><path d="${d}Z"/>${extra}</g></svg>`;
        }
        function burstSplats(cx, cy) {
            if (LITE) return;
            const vmin = Math.min(window.innerWidth, window.innerHeight);
            for (let k = 0; k < 7; k++) {
                const el = document.createElement("div");
                el.className = "intro__splat";
                el.innerHTML = splatSvg(pick(["#2e6eff", "#ff2c42", "#eccc8c", "#ff2c42", "#2e6eff"]));
                const a = (k / 7) * Math.PI * 2 + rand(-0.3, 0.3);
                const dist = vmin * rand(0.28, 0.46);
                const size = vmin * rand(0.16, 0.3);
                el.style.width = el.style.height = `${size}px`;
                el.style.left = `${cx + Math.cos(a) * dist * 1.5 - size / 2}px`;
                el.style.top = `${cy + Math.sin(a) * dist - size / 2}px`;
                splatBox.appendChild(el);
                anim(el, [
                    { transform: `scale(0) rotate(${rand(-40, 40)}deg)`, opacity: 0 },
                    { transform: `scale(1.15) rotate(${rand(-20, 20)}deg)`, opacity: 0.95, offset: 0.5 },
                    { transform: "scale(1) rotate(0deg)", opacity: 0.85 }
                ], { duration: 260, delay: k * 18, easing: "cubic-bezier(.2,.9,.3,1)" });
            }
        }

        /* ---------- Séquence ---------- */
        function run() {
            if (wiping || finished) return;    // passée avant même de commencer
            const letters = buildWord();

            // Position finale mesurée, puis le logo démarre au centre de l'écran
            const lockC = centerOf(lockup);
            const logoC = centerOf(logoBox);
            const off = { x: lockC.x - logoC.x, y: lockC.y - logoC.y };
            const offT = `translate(${off.x}px,${off.y}px)`;
            logoBox.style.transform = offT;
            letters.forEach((L) => { L.glyph.style.opacity = "0"; });

            // 1. Impact du logo
            anim(logoBox, [
                { transform: `${offT} scale(3.4) rotate(-8deg)`, opacity: 0 },
                { transform: `${offT} scale(.86) rotate(1deg)`, opacity: 1, offset: 0.55 },
                { transform: `${offT} scale(1.05)`, opacity: 1, offset: 0.78 },
                { transform: `${offT} scale(1)`, opacity: 1 }
            ], { duration: T.logoDuration, delay: T.logoAt, easing: "cubic-bezier(.7,0,.3,1)" });
            at(T.logoAt + T.logoDuration * 0.55, () => {
                const c = { x: logoC.x + off.x, y: logoC.y + off.y };
                flashIt(0.75, 380);
                ringIt(c.x, c.y, 4, 800);
                shakeIt(14, 380);
                FX.emit(c.x, c.y, T.shards, "shard");
                FX.emit(c.x, c.y, 24, "spark");
            });

            // 2. Le logo glisse à sa place, les lettres sortent une par une
            anim(logoBox, [{ transform: offT }, { transform: "translate(0px,0px)" }],
                { duration: 800, delay: T.lettersAt - 120, easing: "cubic-bezier(.65,0,.35,1)" });
            flyLetters(letters, { x: logoC.x, y: logoC.y });

            // 3. Charge : tout vibre de plus en plus
            at(T.chargeAt, () => {
                if (LITE) return;
                const dur = Math.max(120, T.explodeAt - T.chargeAt);
                anim(lockup, [
                    { transform: "scale(1)" }, { transform: "scale(1.05)" }
                ], { duration: dur, easing: "cubic-bezier(.5,0,1,1)" });
                anim(shake, [
                    { transform: "translate3d(0,0,0)" }, { transform: "translate3d(-3px,2px,0)" }, { transform: "translate3d(3px,-2px,0)" },
                    { transform: "translate3d(-5px,-3px,0)" }, { transform: "translate3d(6px,3px,0)" }, { transform: "translate3d(-7px,2px,0)" },
                    { transform: "translate3d(0,0,0)" }
                ], { duration: dur, fill: "none" });
            });

            // 4. Explosion + « FA »
            at(T.explodeAt, () => {
                const c = centerOf(lockup);
                flashIt(1, 520);
                ringIt(c.x, c.y, 9, 900);
                shakeIt(26, 520);
                FX.emit(c.x, c.y, T.sprayDots, "dot", 26);
                FX.emit(c.x, c.y, Math.round(T.shards * 0.8), "shard");
                burstSplats(c.x, c.y);
                // Le logo et les lettres sont soufflés
                anim(logoBox, [{ transform: "scale(1)", opacity: 1 }, { transform: "scale(1.7)", opacity: 0 }],
                    { duration: 420, easing: "cubic-bezier(.2,.7,.3,1)" });
                letters.forEach((L) => {
                    const a = rand(-Math.PI, Math.PI);
                    const d = rand(0.35, 0.7) * window.innerWidth;
                    anim(L.slot, [
                        { transform: "translate(0,0) rotate(0deg)", opacity: 1 },
                        { transform: `translate(${Math.cos(a) * d}px,${Math.sin(a) * d * 0.6}px) rotate(${rand(-200, 200)}deg) scale(${rand(0.4, 1.6)})`, opacity: 0 }
                    ], { duration: 650, easing: "cubic-bezier(.15,.7,.3,1)" });
                });
                // Le tag claque à l'écran
                faBox.classList.add("is-on");
                anim(faBox, [
                    { transform: "translate(-50%,-50%) scale(2.9) rotate(-14deg)", opacity: 0 },
                    { transform: "translate(-50%,-50%) scale(.9) rotate(-1deg)", opacity: 1, offset: 0.6 },
                    { transform: "translate(-50%,-50%) scale(1.04) rotate(-3deg)", opacity: 1, offset: 0.82 },
                    { transform: "translate(-50%,-50%) scale(1) rotate(-2.5deg)", opacity: 1 }
                ], { duration: 520, delay: 40, easing: "cubic-bezier(.7,0,.3,1)" });
                // Respiration lente pendant l'affichage
                anim(faBox.querySelector(".fa"), [{ transform: "scale(1)" }, { transform: "scale(1.06)" }],
                    { duration: T.tagHold, delay: 560, easing: "ease-out" });
                // Coulures qui descendent
                anim(faBox.querySelector(".fa__drips"), [{ transform: "scaleY(0)" }, { transform: "scaleY(1)" }],
                    { duration: 1000, delay: 480, easing: "cubic-bezier(.3,.6,.3,1)" });
                anim(faBox.querySelector(".fa__stars"), [
                    { opacity: 0 }, { opacity: 1, offset: 0.3 }, { opacity: 0.4, offset: 0.6 }, { opacity: 1 }
                ], { duration: 1100, delay: 520 });
            });

            // 5. Transition peinture → interface
            at(T.explodeAt + T.tagHold, () => toInterface(T.wipeIn, T.wipeOut));
        }

        /** Coup de peinture : recouvre l'écran, retire l'intro, révèle l'interface. */
        function toInterface(inMs, outMs) {
            if (wiping) return;
            wiping = true;
            const bands = [...wipe.children];
            wipe.classList.add("is-on");
            bands.forEach((b, i) => anim(b, [
                { transform: "translate3d(-135%,0,0) skewX(-14deg)" },
                { transform: "translate3d(0,0,0) skewX(-14deg)" }
            ], { duration: inMs, delay: i * 70, easing: "cubic-bezier(.75,0,.3,1)" }));
            at(inMs + 70 * (bands.length - 1) + 40, () => {
                cleanupIntro();
                onReveal();
                bands.forEach((b, i) => anim(b, [
                    { transform: "translate3d(0,0,0) skewX(-14deg)" },
                    { transform: "translate3d(135%,0,0) skewX(-14deg)" }
                ], { duration: outMs, delay: 80 + i * 80, easing: "cubic-bezier(.6,0,.25,1)" }));
                at(80 + outMs + 80 * bands.length + 60, () => {
                    wipe.remove();
                    finished = true;
                    resolveDone();
                });
            });
        }

        function cleanupIntro() {
            FX.stop();
            body.classList.remove("intro-on");
            anims.forEach((a) => { if (!wipe.contains(a.effect && a.effect.target)) a.cancel(); });
            if (root.parentNode) root.remove();     // libère tout le DOM de l'intro
        }

        function skip() {
            if (finished || wiping) return;
            timers.forEach((id) => Timers.clear(id));
            timers.length = 0;
            toInterface(Math.min(T.wipeIn, 450), Math.min(T.wipeOut, 600));
        }

        /** Lance l'intro. reveal() est appelé quand l'écran est couvert par la peinture. */
        function start(reveal) {
            onReveal = reveal;
            const done = new Promise((r) => { resolveDone = r; });
            if (!T.enabled) {
                root.remove();
                wipe.remove();
                finished = true;
                reveal();
                resolveDone();
                return done;
            }
            body.classList.add("intro-on");   // le décor derrière l'intro est mis en pause
            if (T.skippable) {
                skipBtn.addEventListener("click", (e) => { e.stopPropagation(); skip(); });
                document.addEventListener("keydown", (e) => {
                    if (e.key === "Escape" || e.key === "Enter") skip();
                });
            } else {
                skipBtn.remove();
            }
            // On attend le logo (et les polices) pour mesurer correctement la mise en page
            const img = $("introLogoImg");
            const ready = Promise.all([
                img.complete ? Promise.resolve() : new Promise((r) => { img.onload = img.onerror = r; }),
                document.fonts && document.fonts.ready ? Promise.race([document.fonts.ready, wait(500)]) : Promise.resolve()
            ]);
            ready.then(() => requestAnimationFrame(run));
            return done;
        }

        /** Fermeture du loading screen pendant l'intro : on arrête tout. */
        function abort() {
            if (finished) return;
            timers.forEach((id) => Timers.clear(id));
            anims.forEach((a) => a.cancel());
            FX.stop();
            body.classList.remove("intro-on");
            if (root.parentNode) root.remove();
            if (wipe.parentNode) wipe.remove();
            finished = true;
        }

        return { start, abort };
    })();

    /* =================================================================
       8. INTERFACE, SORTIE, ÉVÉNEMENTS FIVEM
       ================================================================= */
    let revealed = false;
    async function revealInterface() {
        if (revealed) return;
        revealed = true;
        const k = LITE ? 0.4 : 1;
        body.classList.add("st-bg", "st-logo");
        Slideshow.start();
        await wait(250 * k);
        body.classList.add("st-shine", "st-name");
        await wait(350 * k);
        body.classList.add("st-ui");
        await typeSlogan(LITE ? 0.01 : 1);
        await wait(800 * k);
        body.classList.add("st-idle");
    }

    let leaving = false;
    function leave(duration) {
        if (leaving) return;
        leaving = true;
        const ms = Number(duration) || cfg.effects.fadeOutDuration || 1200;
        Progress.finish();
        body.style.setProperty("--leave-duration", `${ms}ms`);
        Timers.timeout(() => body.classList.add("is-leaving"), Math.min(500, ms / 3));
        Music.fadeOut(ms);
        // Après le fondu : on arrête toutes les animations et boucles restantes
        setTimeout(() => {
            Progress.snap();
            Intro.abort();
            Slideshow.stop();
            stopParticles();
            Timers.clearAll();
            document.getAnimations && document.getAnimations().forEach((a) => a.cancel());
        }, ms + 100);
    }

    let gotFiveMEvent = false;
    window.addEventListener("message", (e) => {
        let d = e.data;
        if (typeof d === "string") {
            try { d = JSON.parse(d); } catch (err) { return; }
        }
        if (!d || typeof d !== "object" || !d.eventName) return;
        gotFiveMEvent = true;
        if (d.eventName === "elyzea:fadeOut") leave(d.duration);
        else Progress.handle(d.eventName, d);
    });

    const inFiveM = has("invokeNative") || has("nuiHandoverData") || /CitizenFX/i.test(navigator.userAgent);

    /* ---------------- Démarrage ---------------- */
    setupIdentity();
    setupEffects();
    Progress.start();
    Music.init();
    Slideshow.warmup();

    body.classList.remove("is-booting");
    requestAnimationFrame(() => body.classList.add("is-ready"));
    Intro.start(revealInterface);

    // Hors FiveM (aperçu navigateur) : on simule un chargement complet
    Timers.timeout(() => {
        if (!inFiveM && !gotFiveMEvent) Progress.demo();
    }, 1500);

    // Accès pour les tests automatiques (lecture seule)
    window.__elyzeaLS = { lite: LITE, config: cfg };
})();
