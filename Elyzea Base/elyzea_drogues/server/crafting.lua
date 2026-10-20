-- =====================================================================
--  ELYZEA DROGUES · moteur de fabrication et de récolte (serveur, commun à toutes les drogues)
--  Déroulé : le client demande « start » → le serveur vérifie tout et réserve le poste → le client joue
--  la barre de progression (core) → « finish » : le serveur revérifie (temps écoulé, distance, ingrédients),
--  retire les ingrédients puis donne les produits. Un seul jeton par joueur : jamais deux fois la même action.
--  Les ingrédients ne sont retirés qu'à la fin : annuler ou se déconnecter ne fait rien perdre.
-- =====================================================================
local busy = DS.playerBusy

-- Action en cours (une action abandonnée sans réponse du client expire d'elle-même)
local function isBusy(src)
    local b = busy[src]
    if b and os.time() > b.startAt + b.duration + 30 then
        busy[src] = nil
        if b.siteId then local sb = DS.stationBusy[b.siteId] if sb and sb.src == src then DS.stationBusy[b.siteId] = nil end end
        return false
    end
    return b ~= nil
end
DS.IsBusy = isBusy

local function newToken() return ('%d%06d'):format(os.time(), math.random(0, 999999)) end

local function lockStation(siteId, src, seconds)
    local b = DS.stationBusy[siteId]
    if b and b.src ~= src and b.untilT > os.time() then return false end
    DS.stationBusy[siteId] = { src = src, untilT = os.time() + seconds + 15 }
    return true
end
local function unlock(siteId, src) local b = DS.stationBusy[siteId] if b and b.src == src then DS.stationBusy[siteId] = nil end end

-- Ingrédients manquants pour X fois la recette (liste lisible) ou nil
local function missing(src, r, times)
    local out = {}
    for _, e in ipairs(r.inputs) do
        local need, have = e[2] * times, DS.Count(src, e[1])
        if have < need then out[#out + 1] = ('%s (%d/%d)'):format(DS.Label(e[1]), have, need) end
    end
    return #out > 0 and table.concat(out, ', ') or nil
end
DS.Missing = missing

-- ---------------------------------------------------------------- fabrication
Ely.callback.register('elyzea_drogues:craftStart', function(src, siteId, recipeId, times)
    if not DS.ready then return { error = 'Le système démarre, réessaie dans un instant.' } end
    if isBusy(src) then return { error = 'Tu fais déjà quelque chose.' } end
    local ok, why = DS.CanAct(src)
    if not ok then return { error = why } end
    local site = DS.sites[tonumber(siteId) or -1]
    local r = DrugRules.Recipe(DS.S, tostring(recipeId or ''))
    if not site or not r or r.station ~= site.type then return { error = 'Recette indisponible sur ce poste.' } end
    if not r.enabled then return { error = 'Cette étape est désactivée sur le serveur.' } end
    if not DS.Near(src, site) then return { error = 'Tu es trop loin du poste.' } end
    times = math.max(1, math.min(Config.MaxBatch or 5, math.floor(tonumber(times) or 1)))
    local miss = missing(src, r, times)
    if miss then return { error = 'Il te manque : ' .. miss } end
    local duration = r.duration * times
    if not lockStation(site.id, src, duration) then return { error = 'Quelqu\'un utilise déjà ce poste.' } end
    local token = newToken()
    busy[src] = { token = token, kind = 'craft', siteId = site.id, recipe = r.id, times = times, startAt = os.time(), duration = duration }
    return { ok = true, token = token, duration = duration, label = ('%s%s'):format(r.label, times > 1 and (' ×' .. times) or '') }
end)

Ely.callback.register('elyzea_drogues:craftFinish', function(src, token)
    local b = busy[src]
    if not b or b.kind ~= 'craft' or b.token ~= token then return { error = 'Action expirée.' } end
    busy[src] = nil
    unlock(b.siteId, src)
    if os.time() - b.startAt < b.duration - 1 then
        DS.Log('alerte', src, ('fabrication trop rapide (%s)'):format(b.recipe))
        return { error = 'Action interrompue.' }
    end
    local site = DS.sites[b.siteId]
    local r = DrugRules.Recipe(DS.S, b.recipe)
    if not site or not r or not r.enabled then return { error = 'Le poste ou la recette n\'existe plus.' } end
    if not DS.Near(src, site) then return { error = 'Tu t\'es trop éloigné du poste.' } end
    local miss = missing(src, r, b.times)
    if miss then return { error = 'Il te manque : ' .. miss } end
    -- produits (pertes tirées au sort par unité, côté serveur)
    local give, lost = {}, 0
    for _, e in ipairs(r.outputs) do
        local n = 0
        for _ = 1, e[2] * b.times do
            if r.loss > 0 and math.random(1, 100) <= r.loss then lost = lost + 1 else n = n + 1 end
        end
        if n > 0 then give[#give + 1] = { e[1], n } end
    end
    if not DS.CanCarry(src, give) then return { error = 'Ton inventaire est plein.' } end
    -- retrait des ingrédients (annulé si l'un d'eux échoue)
    local removed = {}
    for _, e in ipairs(r.inputs) do
        if DS.Remove(src, e[1], e[2] * b.times) then removed[#removed + 1] = { e[1], e[2] * b.times }
        else
            for _, x in ipairs(removed) do DS.Add(src, x[1], x[2]) end
            return { error = 'Ingrédients introuvables.' }
        end
    end
    local parts = {}
    for _, g in ipairs(give) do
        if DS.Add(src, g[1], g[2]) then parts[#parts + 1] = ('%d × %s'):format(g[2], DS.Label(g[1]))
        else DS.Log('erreur', src, ('ajout impossible %s x%d'):format(g[1], g[2])) end
    end
    DS.Log('fabrication', src, ('%s ×%d → %s%s'):format(r.id, b.times, table.concat(parts, ', '), lost > 0 and (' (perte ' .. lost .. ')') or ''))
    local msg = #parts > 0 and ('Obtenu : %s.'):format(table.concat(parts, ', ')) or 'Tout a été raté.'
    if lost > 0 and #parts > 0 then msg = msg .. (' (%d perdu%s)'):format(lost, lost > 1 and 's' or '') end
    return { ok = true, message = msg }
end)

-- ---------------------------------------------------------------- récolte (points placés par le staff)
Ely.callback.register('elyzea_drogues:harvestStart', function(src, siteId)
    if not DS.ready then return { error = 'Le système démarre, réessaie dans un instant.' } end
    if isBusy(src) then return { error = 'Tu fais déjà quelque chose.' } end
    local ok, why = DS.CanAct(src)
    if not ok then return { error = why } end
    local site = DS.sites[tonumber(siteId) or -1]
    local h = site and Config.Harvest[site.type]
    local set = h and DS.S.harvest[site.type]
    if not h or not set then return { error = 'Rien à récolter ici.' } end
    if not set.enabled or (DS.S.drugs[h.drug] and not DS.S.drugs[h.drug].enabled) then return { error = 'Récolte désactivée sur le serveur.' } end
    if not DS.Near(src, site) then return { error = 'Tu es trop loin.' } end
    if (DS.nodeUntil[site.id] or 0) > os.time() then return { error = 'Déjà récolté, ça repousse.' } end
    if not lockStation(site.id, src, set.duration) then return { error = 'Quelqu\'un récolte déjà ici.' } end
    local token = newToken()
    busy[src] = { token = token, kind = 'harvest', siteId = site.id, startAt = os.time(), duration = set.duration }
    return { ok = true, token = token, duration = set.duration, label = h.label }
end)

Ely.callback.register('elyzea_drogues:harvestFinish', function(src, token)
    local b = busy[src]
    if not b or b.kind ~= 'harvest' or b.token ~= token then return { error = 'Action expirée.' } end
    busy[src] = nil
    unlock(b.siteId, src)
    if os.time() - b.startAt < b.duration - 1 then return { error = 'Action interrompue.' } end
    local site = DS.sites[b.siteId]
    local h = site and Config.Harvest[site.type]
    local set = h and DS.S.harvest[site.type]
    if not h or not set or not set.enabled then return { error = 'Rien à récolter ici.' } end
    if not DS.Near(src, site) then return { error = 'Tu t\'es trop éloigné.' } end
    if (DS.nodeUntil[site.id] or 0) > os.time() then return { error = 'Déjà récolté, ça repousse.' } end
    local n = math.random(set.min, set.max)
    if not DS.CanCarry(src, { { h.item, n } }) then return { error = 'Ton inventaire est plein.' } end
    if not DS.Add(src, h.item, n) then return { error = 'Récolte impossible.' } end
    DS.nodeUntil[site.id] = os.time() + set.respawn
    TriggerClientEvent('elyzea_drogues:node', -1, site.id, set.respawn)
    DS.Log('recolte', src, ('%s #%d → %s x%d'):format(site.type, site.id, h.item, n))
    return { ok = true, message = ('Récolté : %d × %s.'):format(n, DS.Label(h.item)) }
end)

-- Annulation (barre interrompue) : rien n'a été retiré, on libère seulement le poste
RegisterNetEvent('elyzea_drogues:cancel', function(token)
    local src = source
    local b = busy[src]
    if b and b.token == token then
        busy[src] = nil
        if b.siteId then unlock(b.siteId, src) end
    end
end)
