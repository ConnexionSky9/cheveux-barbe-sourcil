-- =====================================================================
--  ELYZEA DROGUES · étapes immersives : règles pures (serveur, tests hors jeu, elyzea_labs)
--  Défi (mini-jeu) d'une étape et vérification du résultat renvoyé par le client.
-- =====================================================================
DrugSteps = {}

local COLORS = { pink = true, blue = true, yellow = true }

-- Clé de profil d'une recette : « weed_trim_whitewidow » → « weed_trim », « xtc_press_pink » → « xtc_press »
function DrugSteps.Key(id)
    id = tostring(id or '')
    if Config.Steps[id] then return id end
    local base = id:match('^(.+)_[%w%-]+$')
    while base do
        if Config.Steps[base] then return base end
        base = base:match('^(.+)_[%w%-]+$')
    end
    return nil
end

-- Profil d'un point de récolte (config/harvest.lua)
function DrugSteps.HarvestKey(siteType)
    siteType = tostring(siteType or '')
    if siteType:find('^weed_') then return 'harvest:weed' end
    local k = 'harvest:' .. siteType
    return Config.Steps[k] and k or nil
end

function DrugSteps.Enabled() return Config.Minigames and Config.Minigames.enabled ~= false end

-- Nombre d'objectifs pour X fois la recette
function DrugSteps.Count(p, times)
    local n = math.floor((p.per or 1) * math.max(1, times or 1))
    n = math.max(p.min or 1, math.min(p.cap or 50, n))
    if p.plusOne then n = n + 1 end
    return n
end

-- Défi envoyé au client. id : identifiant de la recette (pour la couleur des comprimés) · drug : thème
function DrugSteps.Challenge(key, times, drug, recipeId)
    local p = Config.Steps[key]
    if not p then return nil end
    local count = DrugSteps.Count(p, times)
    local extra = {}
    for k, v in pairs(p.extra or {}) do extra[k] = v end
    local col = tostring(recipeId or ''):match('_(%a+)$')
    if col and COLORS[col] then extra.color = col end
    if tostring(recipeId or ''):find('purplehaze$') then extra.tint = 'purple' end   -- fleur violacée pour la Purple Haze
    local factor = (Config.Minigames and Config.Minigames.limitFactor) or 1.0
    return {
        id = math.random(100000, 999999), profile = key, type = p.game, skin = p.skin, drug = drug,
        title = p.title, hint = p.hint, seed = math.random(1, 2147483646), count = count,
        maxMistakes = p.maxMistakes or 3, limit = math.floor(math.max(30, count * (p.secPer or 4) + 15) * factor), extra = extra,
    }
end

-- Vérifie le résultat : true, ou false + raison ('cancel' | 'fail' | 'invalid')
--   elapsed : secondes écoulées côté serveur depuis l'envoi du défi
function DrugSteps.Check(ch, res, elapsed)
    if type(ch) ~= 'table' then return false, 'invalid' end
    if type(res) ~= 'table' or tonumber(res.id) ~= ch.id then return false, 'invalid' end
    if res.cancelled == true then return false, 'cancel' end
    if res.ok ~= true then return false, 'fail' end
    local done, mistakes = tonumber(res.done), tonumber(res.mistakes)
    if not done or not mistakes or done ~= ch.count or mistakes < 0 or mistakes > ch.maxMistakes or mistakes % 1 ~= 0 then return false, 'invalid' end
    -- un humain ne peut pas finir plus vite que ça ; et pas après le temps maximum (+ marge réseau)
    if (elapsed or 0) < ch.count * 0.12 then return false, 'invalid' end
    if (elapsed or 0) > ch.limit + 20 then return false, 'invalid' end
    return true
end
