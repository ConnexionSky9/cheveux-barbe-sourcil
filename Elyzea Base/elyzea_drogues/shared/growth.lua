-- =====================================================================
--  ELYZEA DROGUES · croissance des plantes (calcul pur, serveur et tests)
--  Une plante garde : variété, progression (secondes de croissance effective), eau (%), santé (%),
--  lampe, engrais, date du dernier calcul. Advance() rattrape le temps écoulé d'un coup, même après
--  des heures de déconnexion ou un redémarrage : pas de boucle par plante.
--   · avec de l'eau : la plante pousse (vitesse × lampe × engrais) ;
--   · sans eau : elle ne pousse plus et perd de la santé ; à 0 elle meurt.
-- =====================================================================
Growth = {}

local function cfgOf(S, variety)
    local c, v = S.culture, S.varieties[variety]
    return c, v
end

function Growth.Total(S, variety)
    local _, v = cfgOf(S, variety)
    return math.max(60, (v and v.growMinutes or 60) * 60)
end

function Growth.Rate(S, p)
    local c = S.culture
    return (p.lamp and c.lampFactor or c.noLampFactor) * (p.fert and c.fertilizerBoost or 1.0)
end

-- Rattrape le temps écoulé jusqu'à now. Modifie p et le renvoie.
function Growth.Advance(p, now, S)
    if not p.variety or p.dead then p.lastAt = now return p end
    local dt = now - (p.lastAt or now)
    if dt <= 0 then return p end
    local c = S.culture
    local decay = (c.waterDecayPerHour or 0) / 3600
    local wet = decay > 0 and math.min(dt, (p.water or 0) / decay) or dt
    if (p.water or 0) <= 0 then wet = 0 end
    local dry = dt - wet
    local total = Growth.Total(S, p.variety)
    p.progress = math.min(total, (p.progress or 0) + wet * Growth.Rate(S, p))
    p.water = math.max(0, (p.water or 0) - decay * dt)
    if dry > 0 then
        local loss = (c.healthLossPerHourDry or 0) / 3600
        local before = p.health or 100
        local hp = before - loss * dry
        if hp <= 0 then
            p.health, p.dead = 0, true
            p.deadAt = math.min(now, math.floor((p.lastAt or now) + wet + before / loss))
        else
            p.health = hp
        end
    end
    p.lastAt = now
    return p
end

function Growth.Pct(S, p)
    if not p.variety then return 0 end
    return math.floor((p.progress or 0) / Growth.Total(S, p.variety) * 100 + 0.0001)
end

function Growth.Mature(S, p) return p.variety ~= nil and not p.dead and Growth.Pct(S, p) >= 100 end

-- Étape visible (index dans Config.Culture.stages)
function Growth.Stage(p, pct)
    local idx = 1
    for i, st in ipairs(Config.Culture.stages) do if pct >= st.pct then idx = i end end
    return idx
end

-- Temps restant estimé (s) si la plante reste arrosée, avec la lampe et l'engrais actuels
function Growth.TimeLeft(S, p)
    if not p.variety or p.dead then return nil end
    local rate = Growth.Rate(S, p)
    if rate <= 0 then return nil end
    return math.max(0, math.ceil((Growth.Total(S, p.variety) - (p.progress or 0)) / rate))
end

-- État général lisible
function Growth.Condition(S, p)
    if p.dead then return 'morte' end
    if (p.water or 0) <= 0 then return 'assoiffée' end
    if (p.health or 100) < 50 then return 'abîmée' end
    if (p.water or 0) < S.culture.waterNeedBelow then return 'a besoin d\'eau' end
    return 'en bonne santé'
end
