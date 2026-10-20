-- =====================================================================
--  ELYZEA DROGUES · interactions ALT (client)
--  Branché sur le menu ALT d'elyzea_police (ALT_PROVIDERS, prefixe « drg: », cibles propres) :
--    AltTarget(entité) → titre si l'entité est un poste, un point de récolte, un PNJ ou un pot
--    AltNearby()       → cible la plus proche (2,5 m) quand rien n'est visé
--    AltOptions(ctx)   → actions selon l'état RÉEL (ingrédients en poche, maturité, eau, lampe…)
--    AltSelect(id,ctx) → exécute l'action (le serveur revérifie tout)
--  Aucun autre système de ciblage, aucune autre touche.
-- =====================================================================
local W = DrugWorld
local function set() return DrugFx.settings or {} end
local function count(item)
    local ok, n = pcall(function() return exports.elyzea_inventory:Search('count', item) end)
    return ok and tonumber(n) or 0
end
-- Libellés des objets : envoyés par le serveur (inventaire) avec les réglages
local function itemLabel(item) return (set().labels or {})[item] or item end

local function targetOf(ent)
    local t = ent and W.byEnt[ent]
    if not t then return nil end
    if t.kind == 'site' then
        local s = W.sites[t.id]
        if not s then return nil end
        return { kind = 'site', site = s, entity = ent }
    end
    local p = W.plants[t.id]
    if not p then return nil end
    return { kind = 'plant', plant = p, entity = ent }
end

local function titleOf(t)
    if t.kind == 'site' then
        local ty = t.site.type
        local d = Config.Stations[ty] or Config.Harvest[ty] or Config.NpcSites[ty]
        return d and (d.icon .. ' ' .. d.label) or 'Installation'
    end
    local p = t.plant
    if not p.v then return '🪴 Pot vide' end
    local v = (set().varieties or {})[p.v] or {}
    return ('🌿 %s · %s'):format(v.label or p.v, p.dead and 'morte' or (p.pct .. ' %'))
end

exports('AltTarget', function(ent)
    local t = targetOf(ent)
    return t and titleOf(t) or nil
end)

exports('AltNearby', function()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestD
    for ent, t in pairs(W.byEnt) do
        if DoesEntityExist(ent) then
            local d = #(pos - GetEntityCoords(ent))
            if d < 2.5 and (not bestD or d < bestD) then best, bestD = ent, d end
        end
    end
    if not best then return nil end
    local t = targetOf(best)
    return best, t and titleOf(t) or nil
end)

-- ---------------------------------------------------------------- options
local function inputsText(r, times)
    local parts = {}
    for _, e in ipairs(r.inputs) do parts[#parts + 1] = ('%d× %s'):format(e[2] * (times or 1), itemLabel(e[1])) end
    return table.concat(parts, ' + ')
end
local function maxTimes(r)
    local m = Config.MaxBatch or 5
    for _, e in ipairs(r.inputs) do m = math.min(m, math.floor(count(e[1]) / e[2])) end
    return m
end

local function stationOptions(s)
    local out = {}
    local list = {}
    for id, r in pairs(set().recipes or {}) do if r.station == s.type and r.enabled then list[#list + 1] = { id = id, r = r } end end
    table.sort(list, function(a, b) if a.r.step ~= b.r.step then return a.r.step < b.r.step end return a.r.label < b.r.label end)
    if #list == 0 then return { { id = 'none', label = 'Aucune recette active', icon = 'search', disabled = true } } end
    for _, e in ipairs(list) do
        local r = e.r
        local n = maxTimes(r)
        out[#out + 1] = { id = ('craft:%s:1'):format(e.id), label = ('Étape %d · %s'):format(r.step, r.label), icon = 'repair',
            desc = n >= 1 and ('%s · %d s'):format(inputsText(r, 1), r.duration) or ('Il faut : %s'):format(inputsText(r, 1)), disabled = n < 1 }
        if n >= 2 then
            out[#out + 1] = { id = ('craft:%s:%d'):format(e.id, n), label = ('%s ×%d'):format(r.label, n), icon = 'repair',
                desc = ('%s · %d s'):format(inputsText(r, n), r.duration * n) }
        end
    end
    return out
end

local function harvestOptions(s)
    local h, hs = Config.Harvest[s.type], (set().harvest or {})[s.type] or {}
    if hs.enabled == false then return { { id = 'none', label = 'Récolte désactivée', icon = 'search', disabled = true } } end
    local hidden = (W.nodeHidden[s.id] or 0) - GetGameTimer()
    if hidden > 0 then return { { id = 'none', label = ('Ça repousse (%d s)'):format(math.ceil(hidden / 1000)), icon = 'search', disabled = true } } end
    return { { id = 'harvest', label = ('Récolter : %s'):format(itemLabel(h.item)), icon = 'search', desc = ('%d à %d · %d s'):format(hs.min or h.min, hs.max or h.max, hs.duration or h.duration) } }
end

local function buyerOptions()
    local out = {}
    local prices = set().prices or {}
    local list = {}
    for item, price in pairs(prices) do
        local n = count(item)
        if n > 0 then list[#list + 1] = { item = item, price = price, n = n } end
    end
    table.sort(list, function(a, b) return a.price > b.price end)
    for _, e in ipairs(list) do
        out[#out + 1] = { id = 'sell:' .. e.item, label = ('Vendre : %s'):format(itemLabel(e.item)), icon = 'sell', desc = ('%d $ l\'unité · tu en as %d'):format(e.price, e.n) }
    end
    if #out == 0 then out[1] = { id = 'none', label = 'Rien à lui vendre', icon = 'sell', disabled = true } end
    return out
end

local function isPoliceOnDuty()
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData() end)
    local job = ok and pd and pd.job or {}
    local name = tostring(job.name or ''):lower()
    return job.onduty == true and (job.type == 'leo' or name:find('police') or name:find('sheriff') or name:find('lspd') or name:find('bcso')) ~= nil
end
local function myCid()
    local ok, pd = pcall(function() return exports.elyzea_core:GetPlayerData() end)
    return ok and pd and pd.citizenid or nil
end

local function plantOptions(p)
    local out = { { id = 'pot:info', label = 'Consulter', icon = 'search', desc = p.v and 'Variété, croissance, eau, lampe, état' or 'Pot vide' } }
    local mine = p.o == myCid()
    local cs = set().culture or {}
    if not p.v then
        if mine or not Config.Culture.ownerOnlyPlant then
            local any = false
            local ids = {}
            for id in pairs(Config.Varieties) do ids[#ids + 1] = id end
            table.sort(ids, function(a, b) return Config.Varieties[a].order < Config.Varieties[b].order end)
            for _, id in ipairs(ids) do
                local v = Config.Varieties[id]
                if count(v.seed) > 0 then
                    any = true
                    out[#out + 1] = { id = 'pot:plant:' .. id, label = ('Planter : %s'):format(((set().varieties or {})[id] or {}).label or id), icon = 'search', desc = itemLabel(v.seed) }
                end
            end
            if not any then out[#out + 1] = { id = 'none', label = 'Planter une graine', icon = 'search', disabled = true, desc = 'Tu n\'as aucune graine' } end
        end
    elseif p.dead then
        out[#out + 1] = { id = 'pot:clear', label = 'Retirer la plante morte', icon = 'clean' }
    else
        if p.pct >= 100 then out[#out + 1] = { id = 'pot:harvest', label = 'Récolter', icon = 'search', desc = 'La plante est mature' } end
        if p.water < (cs.waterNeedBelow or 60) then
            local can, water = count('watering_can') > 0, count('water') > 0
            out[#out + 1] = { id = 'pot:water', label = ('Arroser (eau : %d %%)'):format(p.water), icon = 'clean', disabled = not (can and water),
                desc = not can and 'Il te faut un arrosoir' or (not water and 'Il te faut une bouteille d\'eau' or nil) }
        end
        if not p.fert and count('fertilizer') > 0 then out[#out + 1] = { id = 'pot:fertilize', label = 'Ajouter de l\'engrais', icon = 'repair' } end
    end
    if mine or not Config.Culture.ownerOnlyPlant then
        if not p.lamp then
            if p.v and not p.dead then
                out[#out + 1] = { id = 'pot:lamp_on', label = 'Installer la lampe', icon = 'repair', disabled = count('grow_lamp') < 1,
                    desc = count('grow_lamp') < 1 and 'Il te faut une lampe de culture' or 'La plante pousse beaucoup plus vite' }
            end
        else
            out[#out + 1] = { id = 'pot:lamp_off', label = 'Retirer la lampe', icon = 'repair' }
        end
    end
    if mine and (not p.v or p.dead) then out[#out + 1] = { id = 'pot:pickup', label = 'Reprendre le pot', icon = 'bag' } end
    if p.v and cs.policeCanDestroy and isPoliceOnDuty() then out[#out + 1] = { id = 'pot:destroy', label = 'Détruire la plante (saisie)', icon = 'impound' } end
    return out
end

exports('AltOptions', function(ctx)
    local t = targetOf(ctx and ctx.entity)
    if not t then return {} end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return { { id = 'none', label = 'Descends du véhicule', icon = 'out', disabled = true } } end
    if t.kind == 'plant' then return plantOptions(t.plant) end
    local ty = t.site.type
    if Config.Stations[ty] then return stationOptions(t.site) end
    if Config.Harvest[ty] then return harvestOptions(t.site) end
    if ty == 'buyer' then return buyerOptions() end
    if ty == 'supplier' then return { { id = 'shop', label = 'Acheter du matériel', icon = 'buy' } } end
    return {}
end)

-- ---------------------------------------------------------------- actions
local busy = false
local function face(x, y, z)
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, x, y, z, 600)
    Wait(600)
end
local function progress(seconds, text, anim)
    local ok, done = pcall(function()
        return exports.elyzea_core:ProgressBar({ duration = math.floor(seconds * 1000), label = text, canCancel = true,
            disable = { move = true, car = true, combat = true }, anim = anim })
    end)
    return ok and done == true
end
local function run(startName, finishName, args, anim, at)
    if busy then return end
    busy = true
    local r = Ely.callback.await(startName, false, table.unpack(args)) or {}
    if not r.ok then busy = false return DrugFx.notify(r.error or 'Le serveur ne répond pas.', 'error') end
    if at then face(at.x, at.y, at.z) end
    if not progress(r.duration, r.label, anim) then
        TriggerServerEvent('elyzea_drogues:cancel', r.token)
        busy = false
        return DrugFx.notify('Action annulée.', 'inform')
    end
    local f = Ely.callback.await(finishName, false, r.token) or {}
    busy = false
    DrugFx.notify(f.message or f.error or 'Le serveur ne répond pas.', f.ok and 'success' or 'error')
end

local function select(id, t)
    if not t then return end
    if t.kind == 'site' then
        local s = t.site
        local rid, n = id:match('^craft:([%w_]+):(%d+)$')
        if rid then return run('elyzea_drogues:craftStart', 'elyzea_drogues:craftFinish', { s.id, rid, tonumber(n) }, (Config.Stations[s.type] or {}).anim, s) end
        if id == 'harvest' then return run('elyzea_drogues:harvestStart', 'elyzea_drogues:harvestFinish', { s.id }, (Config.Harvest[s.type] or {}).anim, s) end
        local item = id:match('^sell:([%w_%-]+)$')
        if item then
            local r = Ely.callback.await('elyzea_drogues:sell', false, s.id, item) or {}
            return DrugFx.notify(r.message or r.error or 'Le serveur ne répond pas.', r.ok and 'success' or 'error')
        end
        if id == 'shop' then
            local r = Ely.callback.await('elyzea_drogues:shopOpen', false, s.id) or {}
            if not r.ok then DrugFx.notify(r.error or 'Boutique indisponible.', 'error') end
        end
        return
    end
    local p = t.plant
    local act, arg = id:match('^pot:([%w_]+):?([%w_]*)$')
    if not act then return end
    if act == 'info' then return DrugPlantInfo(p.id) end
    local anims = { harvest = Config.StationAnims.kneel, plant = Config.StationAnims.kneel, pickup = Config.StationAnims.kneel, clear = Config.StationAnims.kneel,
        destroy = Config.StationAnims.kneel, water = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' }, fertilize = Config.StationAnims.kneel,
        lamp_on = Config.StationAnims.bench, lamp_off = Config.StationAnims.bench }
    run('elyzea_drogues:potStart', 'elyzea_drogues:potFinish', { p.id, act, arg ~= '' and arg or nil }, anims[act], p)
end

exports('AltSelect', function(id, ctx)
    local t = targetOf(ctx and ctx.entity)
    CreateThread(function()
        local ok, err = pcall(select, tostring(id or ''), t)
        if not ok then print(('^1[elyzea_drogues] ALT %s : %s^0'):format(tostring(id), tostring(err))) busy = false end
    end)
    return true
end)

-- ---------------------------------------------------------------- fiche de suivi d'une plante (NUI, sans focus)
local infoOpen = nil
function DrugPlantInfo(id)
    local r = Ely.callback.await('elyzea_drogues:potInfo', false, id) or {}
    if not r.ok then return DrugFx.notify(r.error or 'Le serveur ne répond pas.', 'error') end
    SendNUIMessage({ action = 'plant', info = r.info })
    infoOpen = { id = id, untilT = GetGameTimer() + 12000 }
    CreateThread(function()
        while infoOpen and infoOpen.id == id do
            local p = W.plants[id]
            if not p or GetGameTimer() > infoOpen.untilT or #(GetEntityCoords(PlayerPedId()) - vector3(p.x, p.y, p.z)) > 6.0 then break end
            Wait(250)
        end
        if infoOpen and infoOpen.id == id then infoOpen = nil SendNUIMessage({ action = 'plant', info = false }) end
    end)
end
