/* =====================================================================
   GO FAST - Logique NUI
   Reçoit les messages de client/*.lua (SendNUIMessage) et renvoie
   les actions du menu via les NUI callbacks (close, startMission, abandon).
   Aucune donnée de récompense n'est décidée ici : tout vient du serveur.
   ===================================================================== */
(function () {
    'use strict';

    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'gofast';
    const $ = (id) => document.getElementById(id);

    const state = {
        hud: null,              // dernières données HUD fusionnées
        endAt: 0,               // timestamp de fin (ms) calculé à partir de timeLeft
        totalTime: 0,
        hudVisible: true,
        awayEndAt: 0,
        menu: null,
        cooldownEndAt: 0,
        currency: '$',
        summaryTimer: null,
    };

    // ------------------------------------------------------------------
    // Utilitaires
    // ------------------------------------------------------------------
    function post(endpoint, body) {
        return fetch(`https://${RESOURCE}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).catch(() => null);
    }

    function formatMoney(amount, currency) {
        const value = Math.floor(Number(amount) || 0);
        const digits = Math.abs(value).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
        return `${value < 0 ? '-' : ''}${digits} ${currency || state.currency}`;
    }

    function formatClock(seconds) {
        seconds = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(seconds / 60);
        const rest = seconds % 60;
        return `${String(minutes).padStart(2, '0')}:${String(rest).padStart(2, '0')}`;
    }

    function formatDuration(seconds) {
        seconds = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(seconds / 60);
        const rest = seconds % 60;
        return minutes > 0 ? `${minutes} min ${String(rest).padStart(2, '0')} s` : `${rest} s`;
    }

    // Une table Lua vide peut arriver en objet {} : on la traite toujours comme une liste
    function toArr(value) {
        if (Array.isArray(value)) return value;
        if (value && typeof value === 'object') return Object.values(value);
        return [];
    }

    function el(tag, className, text) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (text !== undefined && text !== null) node.textContent = text;
        return node;
    }

    function renderChevrons(container, risk) {
        container.textContent = '';
        const level = Math.max(1, Math.min(5, Number(risk) || 1));
        container.className = `chevrons r${level}`;
        for (let i = 1; i <= 5; i += 1) {
            container.appendChild(el('span', i <= level ? 'chevron on' : 'chevron'));
        }
    }

    function healthClass(percent) {
        if (percent < 35) return 'bar-fill health low';
        if (percent < 70) return 'bar-fill health mid';
        return 'bar-fill health';
    }

    // ------------------------------------------------------------------
    // HUD
    // ------------------------------------------------------------------
    function applyHudVisibility() {
        $('hud').classList.toggle('faded', !state.hudVisible);
        $('objective').classList.toggle('faded', !state.hudVisible);
    }

    // ------------------------------------------------------------------
    // ENCADRÉ D'OBJECTIFS
    // ------------------------------------------------------------------
    const OBJ_POSITIONS = ['left', 'right', 'bottom'];

    function objectiveSetup(data) {
        const panel = $('objective');
        const position = OBJ_POSITIONS.includes(data && data.position) ? data.position : 'left';
        OBJ_POSITIONS.forEach((p) => panel.classList.remove(`pos-${p}`));
        panel.classList.add(`pos-${position}`);
    }

    function showObjective(data) {
        if (!data) return;
        const panel = $('objective');
        $('obj-title').textContent = data.title || 'Go Fast';
        $('obj-mission').textContent = data.mission ? `${data.mission}${data.rare ? ' · rare' : ''}` : '';
        panel.classList.toggle('rare', !!data.rare);

        const now = $('obj-now');
        now.className = `obj-now tone-${data.tone || 'normal'}`;
        $('obj-text').textContent = data.objective || '';
        $('obj-hint').textContent = data.hint || '';
        $('obj-hint').classList.toggle('hidden', !data.hint);

        const steps = $('obj-steps');
        steps.textContent = '';
        toArr(data.steps).forEach((step) => steps.appendChild(el('li', step.state || 'todo', step.label)));

        const alerts = $('obj-alerts');
        alerts.textContent = '';
        toArr(data.alerts).forEach((alert) => alerts.appendChild(el('li', alert.tone || 'info', alert.text)));

        if (panel.classList.contains('hidden')) {
            panel.classList.remove('hidden');
            applyHudVisibility();
        }
    }

    function hideObjective() {
        $('objective').classList.add('hidden');
    }

    function renderLane(data) {
        const total = Math.max(1, Number(data.totalSteps) || 1);
        const step = Number(data.step) || 0;
        const nodes = $('lane-nodes');
        nodes.textContent = '';

        for (let i = 0; i <= total; i += 1) {
            const node = el('span', 'lane-node');
            if (i === 0) node.classList.add('start');
            if (data.phase === 'transit' && i < step) node.classList.add('done');
            if ((data.phase === 'pickup' && i === 0) || (data.phase === 'transit' && i === step)) node.classList.add('current');
            node.style.left = `${(i / total) * 100}%`;
            nodes.appendChild(node);
        }

        // La voiture se place entre l'étape précédente et l'étape en cours
        const progress = data.phase === 'pickup' ? 0 : (step - 0.5) / total;
        const width = nodes.clientWidth || 300;
        $('lane-car').style.left = `${10 + Math.max(0, Math.min(1, progress)) * width}px`;
    }

    function renderTimer() {
        if (!state.hud) return;
        const remaining = Math.max(0, (state.endAt - Date.now()) / 1000);
        const timer = $('hud-time');
        timer.textContent = formatClock(remaining);

        const ratio = state.totalTime > 0 ? remaining / state.totalTime : 0;
        const low = state.hud.phase === 'transit' && remaining <= 30;
        timer.classList.toggle('low', low);
        const bar = $('hud-time-bar');
        bar.style.width = `${Math.max(0, Math.min(1, ratio)) * 100}%`;
        bar.classList.toggle('low', ratio < 0.2);

        if (state.awayEndAt > 0) {
            $('hud-away-time').textContent = `${Math.max(0, Math.ceil((state.awayEndAt - Date.now()) / 1000))} s`;
        }
    }

    function renderVehicle(vehicle) {
        if (!vehicle) return;
        const stateLabel = $('hud-vehicle-state');

        if (vehicle.unknown) {
            stateLabel.textContent = 'Hors de vue';
            return;
        }

        const body = Number(vehicle.body) || 0;
        const engine = Number(vehicle.engine) || 0;
        $('hud-body').style.width = `${body}%`;
        $('hud-body').className = healthClass(body);
        $('hud-body-value').textContent = `${body}%`;
        $('hud-engine').style.width = `${engine}%`;
        $('hud-engine').className = healthClass(engine);
        $('hud-engine-value').textContent = `${engine}%`;
        $('hud-speed').textContent = `${vehicle.speed || 0} ${vehicle.unit || 'km/h'}`;

        if (vehicle.locked) stateLabel.textContent = 'Verrouillé';
        else if (vehicle.inside) stateLabel.textContent = 'Au volant';
        else stateLabel.textContent = 'Véhicule laissé';

        $('hud').classList.toggle('moving', !vehicle.locked && vehicle.inside && vehicle.speed > 5);
    }

    function renderHud(data) {
        const hud = state.hud;
        if (!hud) return;

        if (data.mission !== undefined) $('hud-mission').textContent = hud.mission || '-';
        if (data.rare !== undefined) {
            $('hud-rare').classList.toggle('hidden', !hud.rare);
            $('hud').classList.toggle('rare', !!hud.rare);
        }
        if (data.phaseLabel !== undefined) $('hud-phase').textContent = hud.phaseLabel || '-';
        if (data.destination !== undefined) $('hud-destination').textContent = hud.destination || '-';
        if (data.distance !== undefined) $('hud-distance').textContent = hud.distance || '-';

        if (data.step !== undefined || data.totalSteps !== undefined || data.phase !== undefined) {
            $('hud-step').textContent = hud.phase === 'pickup'
                ? `${hud.totalSteps} livraison${hud.totalSteps > 1 ? 's' : ''} prévue${hud.totalSteps > 1 ? 's' : ''}`
                : `Étape ${hud.step} sur ${hud.totalSteps}`;
            renderLane(hud);
        }

        if (data.reward !== undefined) $('hud-reward').textContent = formatMoney(hud.reward, hud.currency);
        if (data.risk !== undefined) renderChevrons($('hud-risk'), hud.risk);
        if (data.riskLabel !== undefined) $('hud-risk-label').textContent = hud.riskLabel || '-';
        if (data.vehicleLabel !== undefined) $('hud-vehicle').textContent = hud.vehicleLabel || '-';
        if (data.plate !== undefined) $('hud-plate').textContent = hud.plate || '-';
        if (data.vehicle !== undefined) renderVehicle(hud.vehicle);

        if (data.totalTime !== undefined) state.totalTime = Number(hud.totalTime) || 0;
        if (data.timeLeft !== undefined) {
            const newEnd = Date.now() + (Number(data.timeLeft) || 0) * 1000;
            // Resynchronise seulement si l'écart dépasse 1,5 s (évite les sauts d'affichage)
            if (Math.abs(newEnd - state.endAt) > 1500) state.endAt = newEnd;
        }
        renderTimer();
    }

    function showHud(data) {
        hideSummary();
        state.hud = Object.assign({}, data);
        state.currency = data.currency || state.currency;
        state.endAt = Date.now() + (Number(data.timeLeft) || 0) * 1000;
        state.totalTime = Number(data.totalTime) || 0;
        state.awayEndAt = 0;
        if (data.visible !== undefined) state.hudVisible = !!data.visible;

        $('hud-away').classList.add('hidden');
        $('hud-body').style.width = '100%';
        $('hud-engine').style.width = '100%';
        $('hud-body-value').textContent = '-';
        $('hud-engine-value').textContent = '-';
        $('hud-vehicle-state').textContent = 'Verrouillé';
        $('hud-speed').textContent = '-';
        $('hud').classList.remove('hidden', 'moving');
        applyHudVisibility();

        renderHud(Object.assign({ mission: 1, rare: 1, phaseLabel: 1, destination: 1, distance: 1, step: 1, reward: 1,
            risk: 1, riskLabel: 1, vehicleLabel: 1, plate: 1, totalTime: 1 }, data));
    }

    function updateHud(data) {
        if (!state.hud || !data) return;
        if (data.vehicle) data.vehicle = Object.assign({}, data.vehicle);
        Object.assign(state.hud, data);
        renderHud(data);
    }

    function hideHud() {
        state.hud = null;
        state.awayEndAt = 0;
        $('hud').classList.add('hidden');
        $('hud-away').classList.add('hidden');
    }

    function setAway(data) {
        const remaining = data ? data.remaining : false;
        if (remaining === false || remaining === null || remaining === undefined) {
            state.awayEndAt = 0;
            $('hud-away').classList.add('hidden');
            return;
        }
        state.awayEndAt = Date.now() + Number(remaining) * 1000;
        $('hud-away').classList.remove('hidden');
        renderTimer();
    }

    // ------------------------------------------------------------------
    // MENU
    // ------------------------------------------------------------------
    function setQuote(node, line, author) {
        node.textContent = '';
        if (!line) {
            node.classList.add('hidden');
            return;
        }
        node.appendChild(document.createTextNode(`« ${line} »`));
        if (author) node.appendChild(el('cite', null, author));
        node.classList.remove('hidden');
    }

    function cooldownRemaining() {
        return Math.max(0, Math.ceil((state.cooldownEndAt - Date.now()) / 1000));
    }

    function renderCooldown() {
        const remaining = cooldownRemaining();
        const node = $('menu-cooldown');
        if (state.menu && state.menu.activeMission) {
            node.textContent = 'Go Fast en cours';
            node.classList.add('blocked');
        } else if (remaining > 0) {
            node.textContent = `Dans ${formatDuration(remaining)}`;
            node.classList.add('blocked');
        } else {
            node.textContent = 'Disponible';
            node.classList.remove('blocked');
        }
        return remaining;
    }

    function tierFact(label, value) {
        const span = el('span', null, `${label} `);
        span.appendChild(el('strong', null, value));
        return span;
    }

    function renderTiers() {
        const data = state.menu;
        const list = $('menu-tiers');
        list.textContent = '';
        const blockedByCooldown = cooldownRemaining() > 0;

        data.tiers = toArr(data.tiers);
        if (data.tiers.length === 0) {
            list.appendChild(el('p', 'sub', 'Aucun contrat pour le moment.'));
            return;
        }

        data.tiers.forEach((tier) => {
            const card = el('article', `tier risk-${tier.risk}${tier.locked ? ' locked' : ''}`);

            const head = el('div', 'tier-head');
            head.appendChild(el('span', 'tier-name', tier.label));
            const chevrons = el('span');
            renderChevrons(chevrons, tier.risk);
            head.appendChild(chevrons);
            head.appendChild(el('span', 'sub', tier.riskLabel));
            card.appendChild(head);

            card.appendChild(el('p', 'tier-desc', tier.description || ''));

            const facts = el('div', 'tier-facts');
            const drops = tier.dropsMin === tier.dropsMax ? `${tier.dropsMin}` : `${tier.dropsMin} à ${tier.dropsMax}`;
            facts.appendChild(tierFact('Livraisons', drops));
            facts.appendChild(tierFact('Alerte police', `${tier.policeChance} %`));
            facts.appendChild(tierFact('Chance rare', `${tier.rareChance} %`));
            if (data.xpEnabled) facts.appendChild(tierFact('XP', `+${tier.xp}`));
            facts.appendChild(tierFact('Niveau', `${tier.minLevel}`));
            card.appendChild(facts);

            const side = el('div', 'tier-side');
            const reward = el('div', 'tier-reward', `${formatMoney(tier.rewardMin, data.currency)} - ${formatMoney(tier.rewardMax, data.currency)}`);
            reward.appendChild(el('small', null, 'Base, avant bonus'));
            side.appendChild(reward);

            let reason = null;
            if (tier.locked) reason = `Niveau ${tier.minLevel} requis`;
            else if (!tier.copsOk) reason = 'Pas assez de policiers en ville';

            if (reason) side.appendChild(el('span', 'tier-lock', reason));

            const button = el('button', 'btn btn-primary', 'Accepter le contrat');
            button.type = 'button';
            button.disabled = !!reason || blockedByCooldown || !!data.activeMission;
            button.addEventListener('click', () => {
                if (button.disabled) return;
                button.disabled = true;
                post('startMission', { tierId: tier.id });
            });
            side.appendChild(button);
            card.appendChild(side);

            list.appendChild(card);
        });
    }

    function openMenu(data) {
        state.menu = data;
        state.currency = data.currency || state.currency;
        state.cooldownEndAt = Date.now() + (Number(data.cooldown) || 0) * 1000;

        $('menu-giver').textContent = data.giverLabel || 'Contact';
        $('menu-subtitle').textContent = data.giverSubtitle || '';
        setQuote($('menu-quote'), data.contactLine, null);
        $('menu-missions').textContent = data.missions || 0;

        const levelCard = $('menu-level');
        levelCard.classList.toggle('hidden', !data.xpEnabled);
        if (data.xpEnabled && data.level) {
            const level = data.level;
            $('menu-level-number').textContent = level.level;
            $('menu-level-xp').textContent = `${level.xp} XP`;
            if (level.nextLevelXp) {
                const span = level.nextLevelXp - level.currentLevelXp;
                const ratio = span > 0 ? (level.xp - level.currentLevelXp) / span : 1;
                $('menu-level-bar').style.width = `${Math.max(0, Math.min(1, ratio)) * 100}%`;
                $('menu-level-next').textContent = `${level.nextLevelXp - level.xp} XP avant le niveau ${level.level + 1}`;
            } else {
                $('menu-level-bar').style.width = '100%';
                $('menu-level-next').textContent = 'Niveau maximum atteint';
            }
        }

        $('btn-abandon').classList.toggle('hidden', !data.activeMission);
        renderCooldown();
        renderTiers();
        $('menu').classList.remove('hidden');
    }

    function closeMenu() {
        state.menu = null;
        $('menu').classList.add('hidden');
    }

    // ------------------------------------------------------------------
    // BILAN
    // ------------------------------------------------------------------
    function hideSummary() {
        if (state.summaryTimer) clearTimeout(state.summaryTimer);
        state.summaryTimer = null;
        $('summary').classList.add('hidden');
    }

    function summaryLine(label, value, kind) {
        const line = el('div', 'summary-line');
        line.appendChild(el('span', null, label));
        line.appendChild(el('span', kind || null, value));
        return line;
    }

    function showSummary(data) {
        hideSummary();
        const success = data.result === 'success';
        const currency = data.currency || state.currency;
        const panel = $('summary');
        panel.classList.toggle('fail', !success);

        $('summary-title').textContent = success ? 'Contrat rempli' : 'Contrat perdu';
        $('summary-mission').textContent = data.mission ? `${data.mission}${data.rare ? ' (rare)' : ''}` : '';
        $('summary-amount').textContent = success ? formatMoney(data.reward, currency) : 'Aucun paiement';

        const reason = $('summary-reason');
        reason.textContent = data.reason || '';
        reason.classList.toggle('hidden', success || !data.reason);

        setQuote($('summary-quote'), data.contactLine, data.contactLabel);

        const lines = $('summary-lines');
        lines.textContent = '';
        const b = data.breakdown;
        if (success && b) {
            lines.appendChild(summaryLine('Paiement de base', formatMoney(b.base, currency)));
            if (b.levelBonus > 0) lines.appendChild(summaryLine('Bonus de niveau', `+${formatMoney(b.levelBonus, currency)}`, 'plus'));
            if (b.fastBonus > 0) lines.appendChild(summaryLine('Bonus rapidité', `+${formatMoney(b.fastBonus, currency)}`, 'plus'));
            if (b.checkpointBonus > 0) lines.appendChild(summaryLine('Points de passage', `+${formatMoney(b.checkpointBonus, currency)}`, 'plus'));
            if (b.damagePenalty > 0) lines.appendChild(summaryLine('Pénalité de dégâts', `-${formatMoney(b.damagePenalty, currency)}`, 'minus'));
            lines.appendChild(summaryLine('État du véhicule', `${b.health} %`));
            lines.appendChild(summaryLine('Temps de trajet', formatDuration(b.elapsed)));
        }

        const extra = $('summary-extra');
        extra.textContent = '';
        if (success && data.xp > 0) extra.appendChild(el('span', 'chip', `+${data.xp} XP`));
        if (!success && data.xpLoss > 0) extra.appendChild(el('span', 'chip bad', `-${data.xpLoss} XP`));
        if (data.levelUp) extra.appendChild(el('span', 'chip', `Niveau ${data.levelUp} atteint`));
        toArr(data.items).forEach((item) => extra.appendChild(el('span', 'chip', `${item.count}x ${item.label}`)));

        panel.classList.remove('hidden');
        state.summaryTimer = setTimeout(hideSummary, success ? 8000 : 6000);
    }

    // ------------------------------------------------------------------
    // NOTIFICATIONS
    // ------------------------------------------------------------------
    function notify(data) {
        if (!data || !data.message) return;
        const container = $('toasts');
        const toast = el('div', `toast ${data.type || 'info'}`, data.message);
        container.appendChild(toast);
        while (container.children.length > 5) container.removeChild(container.firstChild);

        setTimeout(() => {
            toast.classList.add('leaving');
            setTimeout(() => toast.remove(), 260);
        }, Number(data.duration) || 6000);
    }

    // ------------------------------------------------------------------
    // MESSAGES LUA -> NUI
    // ------------------------------------------------------------------
    const handlers = {
        showHud,
        updateHud,
        hideHud,
        setHudVisible: (data) => { state.hudVisible = !!(data && data.visible); applyHudVisibility(); },
        openMenu,
        closeMenu,
        notify,
        away: setAway,
        summary: showSummary,
        objective: showObjective,
        objectiveSetup,
        hideObjective,
    };

    window.addEventListener('message', (event) => {
        const message = event.data;
        if (!message || typeof message.action !== 'string') return;
        const handler = handlers[message.action];
        if (handler) handler(message.data || {});
    });

    // ------------------------------------------------------------------
    // ENTRÉES UTILISATEUR
    // ------------------------------------------------------------------
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && state.menu) post('close');
    });

    $('btn-close').addEventListener('click', () => post('close'));
    $('btn-abandon').addEventListener('click', () => post('abandon'));

    // Une seule horloge locale : timer, compte à rebours "éloigné", cooldown du menu
    setInterval(() => {
        if (state.hud) renderTimer();
        if (state.menu) {
            const before = state.menu.cooldownWasActive;
            const remaining = renderCooldown();
            state.menu.cooldownWasActive = remaining > 0;
            if (before && remaining === 0) renderTiers();
        }
    }, 250);
}());
