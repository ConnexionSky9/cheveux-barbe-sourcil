-- =========================================================
--  RÉAPPARITION (permission « manage_respawn »)
--  Quand un joueur réapparaît après sa mort (sans avoir été réanimé),
--  il est placé sur un lit / point choisi par le staff et se réveille
--  avec une animation. Fonctionne avec n'importe quel script de mort :
--  c'est le joueur qui signale sa réapparition (voir client/respawn.lua).
-- =========================================================
local AM = AdminMenu
local R = Storage.load('respawn', {})
R.enabled = R.enabled ~= false
R.mode = R.mode or 'nearest'      -- nearest (le plus proche de la mort), fixed (toujours le même), random
R.points = R.points or {}
R.effects = R.effects ~= false     -- flou, tremblement, démarche hésitante
R.nextId = R.nextId or 1

local TYPES = { bed = true, ground = true, stand = true }
local function save() Storage.save('respawn', R) end
local function findPoint(id) id = tonumber(id) for i, p in ipairs(R.points) do if p.id == id then return p, i end end end
local function str(v, max) return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, max or 40) end

local last = {}
RegisterNetEvent('adminmenu:respawned', function(deathPos)
    local src = source
    if not R.enabled or #R.points == 0 then return end
    if last[src] and os.time() - last[src] < 20 then return end   -- une seule fois par réapparition
    last[src] = os.time()
    local from = type(deathPos) == 'table' and vector3(tonumber(deathPos.x) or 0, tonumber(deathPos.y) or 0, tonumber(deathPos.z) or 0)
        or GetEntityCoords(GetPlayerPed(src))
    local pick
    if R.mode == 'fixed' then
        pick = findPoint(R.fixed) or R.points[1]
    elseif R.mode == 'random' then
        pick = R.points[math.random(#R.points)]
    else
        local best
        for _, p in ipairs(R.points) do
            local d = #(from - vector3(p.x, p.y, p.z))
            if not best or d < best then pick, best = p, d end
        end
    end
    TriggerClientEvent('adminmenu:wakeAt', src, pick, R.effects)
end)
AddEventHandler('playerDropped', function() last[source] = nil end)

local A = AM.Actions
local function act(fn)
    return { perm = 'manage_respawn', fn = function(src, d)
        local msg, kind = fn(src, d)
        if msg then AM.notify(src, msg, kind or 'success') end
    end }
end

A.respawn_settings = act(function(src, d)
    R.enabled = d.enabled == true
    R.mode = (d.mode == 'fixed' or d.mode == 'random') and d.mode or 'nearest'
    R.fixed = tonumber(d.fixed) or R.fixed
    R.effects = d.effects == true
    save()
    AM.addLog(src, 'Réapparition : réglages', ('%s · %s'):format(R.enabled and 'activée' or 'désactivée', R.mode))
    return 'Réglages de réapparition enregistrés.'
end)

A.respawn_add = act(function(src, d)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local label = str(d.label)
    local p = { id = R.nextId, label = label ~= '' and label or ('Lit %d'):format(#R.points + 1), type = TYPES[d.type] and d.type or 'bed',
        x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped), dz = 0.0 }
    R.nextId = R.nextId + 1
    R.points[#R.points + 1] = p
    if not R.fixed then R.fixed = p.id end
    save()
    AM.addLog(src, 'Réapparition : point ajouté', p.label)
    return ('« %s » ajouté à ta position.'):format(p.label)
end)

A.respawn_update = act(function(src, d)
    local p = findPoint(d.id)
    if not p then return 'Point introuvable.', 'error' end
    if d.label ~= nil and str(d.label) ~= '' then p.label = str(d.label) end
    if d.type ~= nil and TYPES[d.type] then p.type = d.type end
    if d.dz ~= nil then p.dz = math.max(-1.5, math.min(1.5, tonumber(d.dz) or 0)) end
    if d.dh ~= nil then p.h = ((p.h or 0) + (tonumber(d.dh) or 0)) % 360 end
    if d.here then
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        p.x, p.y, p.z, p.h = c.x, c.y, c.z, GetEntityHeading(ped)
    end
    save()
    return d.quiet and nil or ('« %s » enregistré.'):format(p.label)
end)

A.respawn_delete = act(function(src, d)
    local p, i = findPoint(d.id)
    if not p then return end
    table.remove(R.points, i)
    if R.fixed == p.id then R.fixed = R.points[1] and R.points[1].id or nil end
    save()
    AM.addLog(src, 'Réapparition : point supprimé', p.label)
    return ('« %s » supprimé.'):format(p.label)
end)

-- Essayer un point sur soi (réveil complet)
A.respawn_test = { perm = 'manage_respawn', noRefresh = true, fn = function(src, d)
    local p = findPoint(d.id)
    if p then TriggerClientEvent('adminmenu:wakeAt', src, p, R.effects) end
end }

table.insert(AM.DataHooks, function(src, data)
    if AM.hasPerm(src, 'manage_respawn') then
        data.respawn = { enabled = R.enabled, mode = R.mode, fixed = R.fixed, effects = R.effects, points = R.points }
    end
end)
