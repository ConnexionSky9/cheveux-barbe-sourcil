-- =====================================================================
--  ELYZEA LABS · serveur : fabrication sur les équipements installés
--  start → barre de progression (client) → finish. Le serveur revérifie tout à la fin :
--  jeton, durée réellement écoulée, présence dans le laboratoire, distance à l'équipement,
--  droit « fabriquer », niveau, ingrédients, place dans l'inventaire.
--  Ingrédients retirés et produits donnés à la fin seulement ; l'expérience n'est
--  ajoutée qu'après une fabrication terminée et validée.
-- =====================================================================
local L = Labs
local inv = exports.elyzea_inventory
local crafts = {}    -- [src] = { token, lab, eq, recipe, times, startMs, durMs }

local function count(src, item) local ok, n = pcall(function() return inv:GetItemCount(src, item) end) return ok and tonumber(n) or 0 end
local function remove(src, item, n) local ok, r = pcall(function() return inv:RemoveItem(src, item, n) end) return ok and r == true end
local function add(src, item, n) local ok, r = pcall(function() return inv:AddItem(src, item, n) end) return ok and r == true end
local function canCarry(src, list)
    if #list == 0 then return true end
    local ok, r = pcall(function() return inv:CanCarryItems(src, list) end)
    return ok and r == true
end
local function label(item)
    local ok, d = pcall(function() return inv:Items(item) end)
    return ok and d and d.label or item
end
L.ItemLabel = label

local function missing(src, r, times)
    local out = {}
    for _, e in ipairs(r.inputs) do
        local need, have = e[2] * times, count(src, e[1])
        if have < need then out[#out + 1] = ('%d × %s'):format(need - have, label(e[1])) end
    end
    return #out > 0 and table.concat(out, ', ') or nil
end

local function release(src)
    local c = crafts[src]
    if not c then return end
    crafts[src] = nil
    if L.equipBusy[c.eq] == src then L.equipBusy[c.eq] = nil end
end
function L.CancelCraftOf(src) release(src) end
function L.CancelCraftsIn(labId)
    for src, c in pairs(crafts) do
        if c.lab == labId then release(src) TriggerClientEvent('elyzea_labs:craftCancel', src) end
    end
end

-- Recettes d'un équipement (avec ce qui manque) : menu E sur l'équipement
L.pub.equipMenu = function(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab or not L.InsideLab(src, lab.id) then return { error = 'Tu dois être dans le laboratoire.' } end
    local e = lab.equipment[tonumber(d.id) or -1]
    if not e or not e.placed then return { error = 'Équipement introuvable.' } end
    local def = Config.Equipment[e.type]
    local need = LabRules.EquipmentLevel(e.type)
    local out = { id = e.id, type = e.type, label = def.label, locked = lab.level < need, needLevel = need, canCraft = L.Can(src, lab, 'craft'),
        busy = L.equipBusy[e.id] ~= nil and L.equipBusy[e.id] ~= src, maxBatch = Config.MaxBatch, recipes = {} }
    for _, x in ipairs(LabRules.RecipesFor(e.type)) do
        local r = x.r
        local inputs, outputs = {}, {}
        local maxTimes = Config.MaxBatch
        for _, i in ipairs(r.inputs) do
            local have = count(src, i[1])
            inputs[#inputs + 1] = { item = i[1], label = label(i[1]), count = i[2], have = have }
            maxTimes = math.min(maxTimes, math.floor(have / i[2]))
        end
        for _, o in ipairs(r.outputs) do outputs[#outputs + 1] = { item = o[1], label = label(o[1]), count = o[2] } end
        out.recipes[#out.recipes + 1] = { id = x.id, label = r.label, duration = r.duration, xp = r.xp or 0, inputs = inputs, outputs = outputs, max = maxTimes }
    end
    return out
end

L.pub.craftStart = function(src, d)
    if crafts[src] then return { error = 'Tu fabriques déjà quelque chose.' } end
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab or not L.InsideLab(src, lab.id) then return { error = 'Tu dois être dans le laboratoire.' } end
    if not L.Can(src, lab, 'craft') then return { error = 'Tu n\'as pas le droit de fabriquer ici.' } end
    local e = lab.equipment[tonumber(d.id) or -1]
    if not e or not e.placed then return { error = 'Équipement introuvable.' } end
    local rid = tostring(d.recipe or '')
    local r = Config.Recipes[rid]
    if not r or r.enabled == false or r.equipment ~= e.type then return { error = 'Recette inconnue pour cet équipement.' } end
    local need = LabRules.EquipmentLevel(e.type)
    if lab.level < need then return { error = ('Équipement verrouillé : niveau %d requis.'):format(need) } end
    if L.Dist(src, e) > 3.0 then return { error = 'Rapproche-toi de l\'équipement.' } end
    if L.equipBusy[e.id] and L.equipBusy[e.id] ~= src then return { error = 'Quelqu\'un utilise déjà cet équipement.' } end
    local times = math.max(1, math.min(Config.MaxBatch, math.floor(tonumber(d.times) or 1)))
    local miss = missing(src, r, times)
    if miss then return { error = 'Il te manque : ' .. miss } end
    local token = ('%d-%d-%d'):format(src, GetGameTimer(), math.random(100000, 999999))
    local dur = math.floor(r.duration * times * 1000)
    crafts[src] = { token = token, lab = lab.id, eq = e.id, recipe = rid, times = times, startMs = GetGameTimer(), durMs = dur }
    L.equipBusy[e.id] = src
    return { ok = true, token = token, duration = dur, label = ('%s%s'):format(r.label, times > 1 and (' ×' .. times) or ''),
        anim = Config.Equipment[e.type].anim }
end

L.pub.craftCancel = function(src) release(src) return { ok = true } end

L.pub.craftFinish = function(src, d)
    local c = crafts[src]
    if not c or c.token ~= d.token then return { error = 'Fabrication expirée.' } end
    release(src)
    if GetGameTimer() - c.startMs < c.durMs - 1500 then
        L.Log(c.lab, 'alerte', L.Name(src), ('fabrication trop rapide (%s)'):format(c.recipe))
        return { error = 'Fabrication interrompue.' }
    end
    local lab = L.list[c.lab]
    if not lab or not L.InsideLab(src, lab.id) then return { error = 'Tu as quitté le laboratoire.' } end
    if not L.Can(src, lab, 'craft') then return { error = 'Tu n\'as plus le droit de fabriquer ici.' } end
    local e = lab.equipment[c.eq]
    local r = Config.Recipes[c.recipe]
    if not e or not e.placed or not r or r.enabled == false then return { error = 'L\'équipement ou la recette n\'existe plus.' } end
    if lab.level < LabRules.EquipmentLevel(e.type) then return { error = 'Équipement verrouillé.' } end
    if L.Dist(src, e) > 3.5 then return { error = 'Tu t\'es éloigné de l\'équipement.' } end
    local miss = missing(src, r, c.times)
    if miss then return { error = 'Il te manque : ' .. miss } end
    local give = {}
    for _, o in ipairs(r.outputs) do give[#give + 1] = { o[1], o[2] * c.times } end
    if not canCarry(src, give) then return { error = 'Ton inventaire est plein.' } end
    local removed = {}
    for _, i in ipairs(r.inputs) do
        if remove(src, i[1], i[2] * c.times) then removed[#removed + 1] = { i[1], i[2] * c.times }
        else
            for _, x in ipairs(removed) do add(src, x[1], x[2]) end
            return { error = 'Ingrédients introuvables.' }
        end
    end
    local parts, gave = {}, 0
    for _, g in ipairs(give) do
        if add(src, g[1], g[2]) then parts[#parts + 1] = ('%d × %s'):format(g[2], label(g[1])) gave = gave + 1
        else L.Log(lab.id, 'erreur', L.Name(src), ('ajout impossible %s x%d'):format(g[1], g[2])) end
    end
    if gave == 0 then
        for _, x in ipairs(removed) do add(src, x[1], x[2]) end
        return { error = 'Production impossible : ingrédients rendus.' }
    end
    -- Expérience du laboratoire (sur son identifiant, jamais sur le groupe)
    local xp = math.floor((r.xp or 0) * c.times)
    if xp > 0 then
        lab.xp = lab.xp + xp
        MySQL.update('UPDATE `labs` SET `xp` = `xp` + ? WHERE `id` = ?', { xp, lab.id })
    end
    L.Log(lab.id, 'fabrication', L.Name(src), ('%s ×%d → %s (+%d xp)'):format(c.recipe, c.times, table.concat(parts, ', '), xp))
    return { ok = true, xp = xp, labXp = lab.xp, message = ('Obtenu : %s.%s'):format(table.concat(parts, ', '), xp > 0 and (' Laboratoire : +%d XP.'):format(xp) or '') }
end
