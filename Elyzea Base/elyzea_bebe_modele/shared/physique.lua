-- =====================================================================
--  ELYZEA BÉBÉ - physique de la poussette (V6) : fonctions pures, sans FiveM (testées : tests/test_physique.lua)
--
--  Pourquoi une physique « par script » : un corps rigide GTA pour un objet ajouté demande des collisions
--  intégrées, des réglages de masse et de frottement impossibles à ajuster sans le jeu, et un objet rigide
--  glisse au lieu de rouler. Ici, la poussette roule comme un chariot à quatre roues :
--   · le châssis s'appuie sur le sol sous ses quatre roues (tangage, roulis, hauteur) ;
--   · elle n'avance que dans l'axe de ses roues ; la pente la fait accélérer (g · sin θ),
--     la résistance au roulement la freine (Crr · g · cos θ) ; frein serré = immobile (jusqu'à une pente limite) ;
--   · les roues avant pivotantes la font tourner peu à peu vers le bas de la pente ;
--   · un obstacle l'arrête (petit rebond) ; un choc rapide, une pente de côté trop forte ou une chute la renversent.
--  Le monde est fourni par deux fonctions : sol(x, y, zRef) -> z (ou nil) et obstacle(x, y, z, dx, dy, dist) -> true/false.
-- =====================================================================
Physique = {}
local F = Physique
local G = 9.81

F.defaut = {
    empattement = 0.58,      -- m entre essieux (avant y = 0,31, arrière y = -0,27)
    voie = 0.54,             -- m entre roues gauche et droite
    yAvant = 0.31, yArriere = -0.27, xRoue = 0.27,
    rayonAr = 0.14, rayonAv = 0.10,
    crr = 0.035,             -- résistance au roulement (roues gonflées sur bitume ≈ 0,02-0,05)
    seuilDepart = 0.045,     -- frottement de départ : pente minimale (tan) pour qu'une poussette arrêtée se mette à rouler
    vMax = 7.0,              -- m/s : vitesse maximale (sécurité)
    penteFrein = 0.42,       -- tan (≈ 23°) : au-delà, même frein serré, elle glisse
    roulisMax = math.rad(32),-- inclinaison de côté au-delà de laquelle elle se renverse
    vChoc = 2.6,             -- m/s : choc contre un obstacle au-delà duquel elle se renverse
    rebond = 0.15,
    chuteMax = 0.45,         -- m : marche / trottoir plus haut sous une roue = chute (renversement si en mouvement)
    pivot = 0.9,             -- rad/s par (m/s · pente latérale) : roues avant pivotantes vers le bas de la pente
    arret = 0.05,            -- m/s : en dessous, et pente insuffisante : arrêtée
}

local function avant(cap)
    local r = math.rad(cap)
    return -math.sin(r), math.cos(r)        -- comme GetEntityForwardVector (cap 0 = +Y)
end

-- Points de contact (repère monde) des quatre roues, au sol
function F.roues(st, P)
    local fx, fy = avant(st.cap)
    local rx, ry = fy, -fx                   -- vers la droite
    local function pt(y, x) return st.x + fx * y + rx * x, st.y + fy * y + ry * x end
    return {
        avg = { pt(P.yAvant, -P.xRoue) }, avd = { pt(P.yAvant, P.xRoue) },
        arg = { pt(P.yArriere, -P.xRoue) }, ard = { pt(P.yArriere, P.xRoue) },
    }
end

-- Assise sur le terrain : hauteur (z de l'origine = sol), tangage (nez vers le haut > 0), roulis, pentes
function F.assise(st, P, sol)
    local R = F.roues(st, P)
    local z = {}
    for k, p in pairs(R) do z[k] = sol(p[1], p[2], st.z) end
    for _, k in ipairs({ 'avg', 'avd', 'arg', 'ard' }) do if not z[k] then return nil end end
    local zAv, zAr = (z.avg + z.avd) / 2, (z.arg + z.ard) / 2
    local zG, zD = (z.avg + z.arg) / 2, (z.avd + z.ard) / 2
    local L = P.yAvant - P.yArriere
    return {
        z = (zAv + zAr) / 2,
        penteAvant = (zAv - zAr) / L,                 -- tan : > 0 = l'avant est plus haut
        penteCote = (zD - zG) / (2 * P.xRoue),         -- tan : > 0 = le côté droit est plus haut
        ecart = math.max(z.avg, z.avd, z.arg, z.ard) - math.min(z.avg, z.avd, z.arg, z.ard),
        z4 = z,
    }
end

-- Un pas de simulation. st = { x, y, z, cap, v, frein, renversee, angleRoues }. Renvoie st modifié et un événement
-- éventuel : 'arret' (immobile, à rapporter au serveur), 'obstacle', 'renversee', 'hors_sol'.
function F.pas(st, dt, P, sol, obstacle)
    P = P or F.defaut
    if st.renversee then return st, 'renversee' end
    local a = F.assise(st, P, sol)
    if not a then return st, 'hors_sol' end
    if a.ecart > P.chuteMax then
        -- une roue au-dessus du vide (marche, trottoir) : en mouvement elle bascule ; à l'arrêt elle reste
        if math.abs(st.v) > 0.6 then st.renversee = true return st, 'renversee' end
    end
    local ct = 1 / math.sqrt(1 + a.penteAvant * a.penteAvant)
    local sinT = a.penteAvant * ct
    if math.abs(math.atan(a.penteCote)) > P.roulisMax then st.renversee = true return st, 'renversee' end

    if st.frein and math.abs(a.penteAvant) <= P.penteFrein then
        st.v = 0.0
    else
        local acc = -G * sinT                                   -- l'avant plus haut : elle recule (vers le bas)
        if math.abs(st.v) < P.arret and math.abs(a.penteAvant) <= P.seuilDepart then
            st.v = 0.0                                          -- trop peu de pente pour décoller
        else
            local frot = P.crr * G * ct
            if st.frein then frot = frot + 0.25 * G * ct end    -- frein dépassé : glisse en freinant
            local v = st.v + acc * dt
            local s = v ~= 0 and (v > 0 and 1 or -1) or (acc > 0 and 1 or (acc < 0 and -1 or 0))
            local vf = v - s * frot * dt
            if s ~= 0 and (vf > 0 and 1 or (vf < 0 and -1 or 0)) ~= s then vf = 0.0 end   -- le frottement ne fait pas repartir en arrière
            st.v = math.max(-P.vMax, math.min(P.vMax, vf))
        end
    end
    if st.v ~= 0 then
        -- roues avant pivotantes : tourne peu à peu vers le bas de la pente latérale (en avançant comme en reculant)
        st.cap = (st.cap + math.deg(P.pivot * a.penteCote * st.v * dt)) % 360.0
        local fx, fy = avant(st.cap)
        local d = st.v * dt
        local sens = d > 0 and 1 or -1
        if obstacle and obstacle(st.x, st.y, a.z, fx * sens, fy * sens, math.abs(d) + 0.45) then
            if math.abs(st.v) >= P.vChoc then st.renversee = true return st, 'renversee' end
            st.v = -st.v * P.rebond
            return st, 'obstacle'
        end
        st.x, st.y = st.x + fx * d, st.y + fy * d
        st.angleRoues = (st.angleRoues or 0.0) + math.deg(d / P.rayonAr)
        local a2 = F.assise(st, P, sol)
        if a2 then st.z, st.tangage, st.roulis = a2.z, math.deg(math.atan(a2.penteAvant)), -math.deg(math.atan(a2.penteCote)) end
        return st, nil
    end
    st.z, st.tangage, st.roulis = a.z, math.deg(math.atan(a.penteAvant)), -math.deg(math.atan(a.penteCote))
    return st, 'arret'
end

-- Simulation complète jusqu'à l'arrêt (tests, et contrôle de vraisemblance côté serveur). Renvoie l'état et la trace.
function F.simuler(st, P, sol, obstacle, dureeMax, dt)
    dt = dt or (1 / 30)
    local t, trace, ev = 0, {}, nil
    local immobile = 0
    while t < (dureeMax or 60) do
        st, ev = F.pas(st, dt, P, sol, obstacle)
        t = t + dt
        if ev == 'renversee' or ev == 'hors_sol' then break end
        if ev == 'arret' then immobile = immobile + dt else immobile = 0 end
        if immobile >= 0.5 then break end
        if #trace < 4000 then trace[#trace + 1] = { t = t, x = st.x, y = st.y, z = st.z, v = st.v } end
    end
    return st, ev, t, trace
end

return Physique
