-- =========================================================
--  ELYZEA ANIMAUX - CLIENT : menu ALT (fourni par elyzea_police)
--  ALT maintenu, clic sur un animal :
--   · le sien : ordres de son espèce, nourrir, abreuver, harnais, laisse, ranger ;
--   · celui d'un autre : son nom et son espèce, le caresser ;
--   · un animal de ferme : observer, nourrir, soigner, récolter.
--  Sans elyzea_police, tout reste accessible par F7 (Mes animaux).
-- =========================================================
local function count(name)
    local ok, n = pcall(function() return exports.elyzea_inventory:Search('count', name) end)
    return ok and tonumber(n) or 0
end
local function slots(name)
    local ok, list = pcall(function() return exports.elyzea_inventory:Search('slots', name) end)
    return ok and type(list) == 'table' and list or {}
end

local function otherPet(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not NetworkGetEntityIsNetworked(ent) then return nil end
    local info = C.Active[tostring(NetworkGetNetworkIdFromEntity(ent))]
    return info
end

local function farmOf(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not NetworkGetEntityIsNetworked(ent) then return nil end
    local netId = NetworkGetNetworkIdFromEntity(ent)
    local info = C.FarmEnts[tostring(netId)]
    return info and netId or nil, info
end

local function speciesLabel(sid) return Config.Species[sid] and Config.Species[sid].label or 'Animal' end

local function target(ent)
    local id, m = C.IsMine(ent)
    if id then return { kind = 'mine', id = id, m = m, title = ('🐾 %s (%s)'):format(m.data.name, speciesLabel(m.data.species)) } end
    local o = otherPet(ent)
    if o then return { kind = 'other', info = o, ent = ent, title = ('🐾 %s · %s'):format(o.name or '?', speciesLabel(o.species)) } end
    local netId, f = farmOf(ent)
    if netId then return { kind = 'farm', netId = netId, info = f, title = ('🐄 %s de la ferme'):format(speciesLabel(f.species)) } end
end

local function options(t)
    local out = {}
    if not t then return out end
    if t.kind == 'mine' then
        local m = t.m
        local prof = Config.Profiles[m.species.profile] or {}
        if IsEntityAttached(m.ped) then
            out[#out + 1] = { id = 'none', label = ('%s est dans le véhicule'):format(m.data.name), disabled = true }
            return out
        end
        for _, c in ipairs(C.CommandList(m.id)) do out[#out + 1] = { id = 'cmd:' .. c.id, label = c.label, icon = 'paw' } end
        out[#out + 1] = { id = 'care:food', label = 'Donner des croquettes', disabled = count(Config.Items.food) < 1, desc = ('Faim %d %%'):format(math.floor((m.needs or {}).hunger or 0)) }
        out[#out + 1] = { id = 'care:treat', label = 'Donner une friandise', disabled = count(Config.Items.treat) < 1 }
        out[#out + 1] = { id = 'care:water', label = 'Donner à boire', disabled = count(Config.Items.water) < 1, desc = ('Soif %d %%'):format(math.floor((m.needs or {}).thirst or 0)) }
        if (m.needs or {}).health and m.needs.health < 100 then
            out[#out + 1] = { id = 'care:medkit', label = 'Soigner', disabled = count(Config.Items.medkit) < 1, desc = ('Santé %d %%'):format(math.floor(m.needs.health)) }
        end
        if prof.harness then
            if m.gear and m.gear.harness then out[#out + 1] = { id = 'unharness', label = 'Retirer le harnais' } end
            for _, it in ipairs(slots(Config.Items.harness)) do
                out[#out + 1] = { id = 'harness:' .. it.slot, label = ('Équiper : %s'):format((it.metadata and it.metadata.label) or 'Harnais') }
            end
        end
        if prof.leash then
            out[#out + 1] = { id = 'leash', label = m.leash and 'Détacher la laisse' or 'Attacher la laisse',
                disabled = not m.leash and count(Config.Items.leash) < 1, desc = (not m.leash and count(Config.Items.leash) < 1) and 'Il te faut une laisse' or nil }
        end
        out[#out + 1] = { id = 'sheet', label = 'Fiche de l\'animal' }
        out[#out + 1] = { id = 'store', label = 'Ranger (rentre à la maison)' }
    elseif t.kind == 'other' then
        out[#out + 1] = { id = 'otherInfo', label = 'Regarder la médaille', desc = speciesLabel(t.info.species) }
        out[#out + 1] = { id = 'otherPet', label = 'Caresser' }
    elseif t.kind == 'farm' then
        out[#out + 1] = { id = 'farm:observe', label = 'Observer l\'animal' }
        out[#out + 1] = { id = 'farm:feed', label = 'Nourrir', disabled = count(Config.Items.feed) < 1, desc = count(Config.Items.feed) < 1 and 'Il te faut de l\'aliment pour bétail' or nil }
        out[#out + 1] = { id = 'farm:care', label = 'Soigner', disabled = count(Config.Items.medkit) < 1 }
        local pr = Config.FarmProduce[t.info.species]
        if pr then out[#out + 1] = { id = 'farm:produce', label = pr.label } end
    end
    return out
end

local function select(id, t)
    if not t then return end
    if t.kind == 'mine' then
        local m = t.m
        local cmd = id:match('^cmd:(.+)$')
        if cmd then return C.Command(m.id, cmd) end
        local care = id:match('^care:(.+)$')
        if care then return C.Care(m.id, care) end
        local slot = id:match('^harness:(%d+)$')
        if slot then return C.Harness(m.id, tonumber(slot)) end
        if id == 'unharness' then return C.Harness(m.id, nil) end
        if id == 'leash' then return C.ToggleLeash(m.id) end
        if id == 'store' then return C.StorePet(m.id) end
        if id == 'sheet' then
            local d = C.MyPets()
            if d then d.focus = m.id C.OpenUI('pets', d) end
        end
    elseif t.kind == 'other' then
        if id == 'otherInfo' then
            C.Notify(('La médaille indique : « %s » (%s).'):format(t.info.name or '?', speciesLabel(t.info.species)), 'inform')
        elseif id == 'otherPet' then
            local me = PlayerPedId()
            if #(GetEntityCoords(me) - GetEntityCoords(t.ent)) > 2.5 then return C.Notify('Approche-toi.', 'error') end
            TaskTurnPedToFaceEntity(me, t.ent, 800)
            Wait(800)
            if C.LoadDict('amb@medic@standing@tendtodead@base') then TaskPlayAnim(me, 'amb@medic@standing@tendtodead@base', 'base', 3.0, 3.0, 3500, 1, 0.0, false, false, false) end
            Wait(3500)
            ClearPedTasks(me)
        end
    elseif t.kind == 'farm' then
        local a = id:match('^farm:(.+)$')
        if a then C.FarmAct(t.netId, a) end
    end
end

local function nearest()
    local id = C.NearestMine(3.0)
    if id then return C.Mine[id].ped end
    local f = C.FarmNearest()
    if f then return NetToPed(f) end
end

exports('AltTarget', function(ent) local t = target(ent) return t and t.title or nil end)
exports('AltNearby', function()
    local ent = nearest()
    local t = ent and target(ent)
    if not t then return nil end
    return ent, t.title
end)
exports('AltOptions', function(ctx) return options(target(ctx and ctx.entity) or target(nearest())) end)
exports('AltSelect', function(id, ctx)
    local t = target(ctx and ctx.entity) or target(nearest())
    CreateThread(function() select(id, t) end)
end)
