/* =====================================================================
   ELYZEA — LOADING SCREEN · MOTEUR
   ---------------------------------------------------------------------
   Pas besoin de modifier ce fichier : tout se règle dans js/config.js.
   Modules :
     1. Utilitaires
     2. Identité (logo, nom, slogan, astuces, liens)
     3. Slideshow (Ken Burns + transitions)
     4. Progression du chargement (événements FiveM + mode démo)
     5. Lecteur musical
     6. Effets (particules, grain)
     7. Séquence d'intro / sortie
   ===================================================================== */
(() => {
    "use strict";

    /* =================================================================
       1. UTILITAIRES
       ================================================================= */
    const $ = (id) => document.getElementById(id);
    const body = document.body;
    const wait = (ms) => new Promise((r) => setTimeout(r, ms));
    const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
    const rand = (a, b) => a + Math.random() * (b - a);
    const pad2 = (n) => String(n).padStart(2, "0");

    const cfg = {
        server:    Object.assign({ name: "", subtitle: "", slogan: "", logo: "", logoSize: "", showName: true }, typeof server !== "undefined" ? server : {}),
        slides:    typeof slides !== "undefined" && Array.isArray(slides) ? slides : [],
        slideshow: Object.assign({ interval: 7000, transition: 1800, shuffle: false, blurTransitions: true, lightSweep: true, effects: [], transitions: [] }, typeof slideshow !== "undefined" ? slideshow : {}),
        music:     Object.assign({ volume: 0.35, autoplay: true, loop: true, shuffle: false, fadeIn: 2500, playlist: [] }, typeof music !== "undefined" ? music : {}),
        loading:   Object.assign({ title: "Chargement", smoothing: 0.05, demoDuration: 24000, showLogLines: false, stages: {} }, typeof loading !== "undefined" ? loading : {}),
        tips:      Object.assign({ enabled: false, interval: 8000, list: [] }, typeof tips !== "undefined" ? tips : {}),
        links:     typeof links !== "undefined" && Array.isArray(links) ? links : [],
        effects:   Object.assign({ intro: true, introSpeed: 1, particles: true, particleCount: 40, grain: true, grainOpacity: 0.07, vignette: true, lightLines: true, letterbox: true, logoFloat: true, fadeOutDuration: 1200 }, typeof effects !== "undefined" ? effects : {})
    };

    const reducedMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    /** Remplace le texte d'un élément avec un petit fondu. */
    function swapText(el, text, delay = 450) {
        if (!el || el.textContent === text) return;
        el.classList.add("is-swapping");
        setTimeout(() => {
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

        // Logo
        const img = $("logo");
        if (s.logo) {
            img.src = s.logo;
            img.alt = s.name || "Logo";
            // Masque du reflet = forme du logo (chemin résolu depuis index.html)
            const shine = document.querySelector(".emblem__shine");
            const abs = cssUrl(new URL(s.logo, document.baseURI).href);
            shine.style.webkitMaskImage = abs;
            shine.style.maskImage = abs;
            img.addEventListener("error", () => {
                console.warn("[loadscreen] Logo introuvable :", s.logo);
                $("emblem").classList.add("is-off");
            });
        } else {
            $("emblem").classList.add("is-off");
        }

        // Nom lettre par lettre
        const nameEl = $("serverName");
        if (s.showName && s.name) {
            [...s.name].forEach((ch, i) => {
                const span = document.createElement("span");
                span.className = "ch";
                span.style.setProperty("--i", i);
                span.textContent = ch === " " ? "\u00A0" : ch;
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
                setInterval(() => {
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
            "zoom-in":   [[1.04, 0, 0, 0], [1.2, 0, 0, 0]],
            "zoom-out":  [[1.22, 0, 0, 0], [1.05, 0, 0, 0]],
            "pan-left":  [[1.16, 3, 0, 0], [1.16, -3, 0, 0]],
            "pan-right": [[1.16, -3, 0, 0], [1.16, 3, 0, 0]],
            "pan-up":    [[1.16, 0, 3, 0], [1.16, 0, -3, 0]],
            "pan-down":  [[1.16, 0, -3, 0], [1.16, 0, 3, 0]],
            "rotate":    [[1.14, 0, 0, -1.2], [1.24, 0, 0, 1]],
            "drift":     [[1.1, -2, 1.5, 0], [1.2, 2, -1.5, 0]]
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
            .filter((t) => cfg.slideshow.blurTransitions || t !== "blur");
        if (!effectsPool.length) effectsPool.push(...Object.keys(MOTION));
        if (!transitionsPool.length) transitionsPool.push("fade");

        const layers = [makeLayer(), makeLayer()];
        let active = -1;      // index du calque visible
        let pos = -1;         // position dans "order"
        let shown = 0;        // nb de photos affichées
        let busy = false;
        let timer = null;
        let started = false;
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

        function pick(item, key, pool, n) {
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
            const sideLabel = side === "legal" ? "Côté légal" : side === "illegal" ? "Côté illégal" : (cfg.server.name || "");
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
            if (!cfg.slideshow.lightSweep || reducedMotion) return;
            sweep.classList.remove("is-on");
            void sweep.offsetWidth; // relance l'animation CSS
            sweep.classList.add("is-on");
        }

        async function next() {
            if (busy) return;
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

            const effect = pick(item, "effect", effectsPool, shown);
            const trans = first ? "fade" : pick(item, "transition", transitionsPool, shown);
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

            if (!single) {
                clearTimeout(timer);
                timer = setTimeout(next, interval);
            }
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

        return { start };
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
            if (Math.abs(target - shown) < 0.02) shown = target;

            fill.style.transform = `translateX(${(shown - 100).toFixed(3)}%)`;
            const pct = Math.floor(shown);
            if (pct !== lastPct) {
                pctEl.textContent = pct;
                lastPct = pct;
            }
            requestAnimationFrame(frame);
        }

        function finish() {
            finished = true;
            ceiling = 100;
            setTarget(100);
            setStatus("done");
        }

        function start() {
            setStatus("start");
            requestAnimationFrame((t) => { lastFrame = t; frame(t); });
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
            plan.forEach(([at, name, data]) => setTimeout(() => handlers[name](data), at * total));
            setTimeout(finish, total);
        }

        function handle(name, data) {
            const h = handlers[name];
            if (h) h(data || {});
        }

        return { start, finish, demo, handle };
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

        function setEmpty(title, detail) {
            empty = true;
            player.classList.add("is-empty");
            player.classList.remove("is-playing");
            body.classList.remove("needs-unlock");
            labelEl.textContent = "Musique";
            titleEl.textContent = title;
            artistEl.textContent = detail || "";
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

        function load(i) {
            pos = (i + tracks.length) % tracks.length;
            const t = tracks[order[pos]];
            fallbackDuration = parseDuration(t.duration);
            titleEl.textContent = t.title || t.file.split("/").pop();
            artistEl.textContent = t.artist || "";
            labelEl.textContent = tracks.length > 1 ? `En lecture · ${pos + 1}/${tracks.length}` : "En lecture";
            curEl.textContent = "00:00";
            totEl.textContent = fmt(fallbackDuration);
            seekFill.style.width = "0%";
            seekBuffer.style.width = "0%";
            audio.loop = tracks.length === 1 && !!m.loop;
            audio.src = t.file;
            audio.load();
        }

        function play(withFade) {
            if (empty) return;
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
            if (unlockBound) return;
            unlockBound = true;
            const go = () => {
                document.removeEventListener("pointerdown", go, true);
                document.removeEventListener("keydown", go, true);
                unlockBound = false;
                if (audio.paused) play(true);
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
            audio.addEventListener("play", () => player.classList.add("is-playing"));
            audio.addEventListener("pause", () => player.classList.remove("is-playing"));
            audio.addEventListener("playing", () => { errors = 0; });

            const showTotal = () => { totEl.textContent = fmt(duration()); };
            audio.addEventListener("loadedmetadata", showTotal);
            audio.addEventListener("durationchange", showTotal);

            audio.addEventListener("timeupdate", () => {
                if (draggingSeek) return;
                const d = duration();
                curEl.textContent = fmt(audio.currentTime);
                seekFill.style.width = d ? `${clamp(audio.currentTime / d, 0, 1) * 100}%` : "0%";
            });

            audio.addEventListener("progress", () => {
                const d = duration();
                if (!d || !audio.buffered.length) return;
                seekBuffer.style.width = `${clamp(audio.buffered.end(audio.buffered.length - 1) / d, 0, 1) * 100}%`;
            });

            audio.addEventListener("ended", () => {
                if (tracks.length > 1) {
                    if (!m.loop && pos === tracks.length - 1) return;
                    load(pos + 1);
                    play(false);
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
                    setEmpty("Aucune musique trouvée", "Ajoute ton fichier dans assets/music/");
                }
            });

            $("btnPlay").addEventListener("click", (e) => { e.stopPropagation(); toggle(); });
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
                }
            );

            makeSlider(volBar,
                (r) => setVolume(r),
                (r, keyDir) => setVolume(keyDir ? volume + keyDir * 0.05 : r, true)
            );

            // Raccourcis clavier : Espace = lecture/pause, M = muet, ← / → = ±5 s
            document.addEventListener("keydown", (e) => {
                if (e.repeat) return;
                if (e.code === "Space") { e.preventDefault(); toggle(); }
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

        function init() {
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
    function setupEffects() {
        const e = cfg.effects;
        if (!e.vignette) $("vignette").classList.add("is-off");
        if (!e.letterbox) $("letterbox").classList.add("is-off");
        if (!e.lightLines || reducedMotion) $("lightLines").classList.add("is-off");
        if (e.logoFloat && !reducedMotion) body.classList.add("float");

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
        if (!e.particles || reducedMotion) {
            canvas.classList.add("is-off");
            return;
        }
        const ctx = canvas.getContext("2d");
        const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
        const colors = ["233,211,161", "233,211,161", "233,211,161", "79,140,255", "255,45,67"];
        let w = 0, h = 0;

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
            requestAnimationFrame(loop);
        };
        requestAnimationFrame(loop);
    }

    /* =================================================================
       7. INTRO / SORTIE / ÉVÉNEMENTS FIVEM
       ================================================================= */
    async function intro() {
        const k = cfg.effects.intro && !reducedMotion ? clamp(Number(cfg.effects.introSpeed) || 1, 0.2, 3) : 0;

        body.classList.remove("is-booting");
        requestAnimationFrame(() => body.classList.add("is-ready"));

        if (k) {
            await wait(500 * k);
            body.classList.add("st-flare");
            await wait(650 * k);
        }
        body.classList.add("st-logo");
        await wait(1300 * k);
        body.classList.add("st-shine", "st-name");
        await wait(900 * k);
        const sloganDone = typeSlogan(k || 0.01);
        await wait(500 * k);
        body.classList.add("st-bg");
        Slideshow.start();
        await wait(900 * k);
        body.classList.add("st-ui");
        await sloganDone;
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
        setTimeout(() => body.classList.add("is-leaving"), Math.min(500, ms / 3));
        Music.fadeOut(ms);
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

    const inFiveM = typeof window.invokeNative !== "undefined"
        || typeof window.nuiHandoverData !== "undefined"
        || /CitizenFX/i.test(navigator.userAgent);

    /* ---------------- Démarrage ---------------- */
    setupIdentity();
    setupEffects();
    Progress.start();
    Music.init();
    intro();

    // Hors FiveM (aperçu navigateur) : on simule un chargement complet
    setTimeout(() => {
        if (!inFiveM && !gotFiveMEvent) Progress.demo();
    }, 1500);
})();
