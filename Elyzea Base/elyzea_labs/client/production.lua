-- =====================================================================
--  ELYZEA LABS · client : équipements posés (objets locaux) et fabrication
--  E près d'un équipement → recettes (ingrédients, ce que tu as) → barre de progression
--  du core (animation) → le serveur revérifie tout et donne le produit.
-- =====================================================================
local C = LabC
local shown = {}   -- { { id, type, ent, x, y, z, label, decor } }
local crafting = nil

local function drogues() return GetResourceState('elyzea_drogues') == 'started' end

function C.ClearEquipment()
    for _, e in ipairs(shown) do
        if DoesEntityExist(e.ent) then DeleteEntity(e.ent) end
        for _, o in ipairs(e.decor or {}) do if DoesEntityExist(o) then DeleteEntity(o) end end
    end
    shown = {}
end

local gen = 0
function C.SpawnEquipment(list)
    C.ClearEquipment()
    gen = gen + 1
    local mine = gen   -- une nouvelle liste arrivée pendant un chargement remplace celle-ci
    for _, e in ipairs(list or {}) do
        local model = C.EquipModel(e.type)
        local h = model and C.LoadModel(model)
        if gen ~= mine then return end
        if h then
            local obj = CreateObjectNoOffset(h, e.x + 0.0, e.y + 0.0, e.z + 0.0, false, false, false)
            SetEntityRotation(obj, (e.rx or 0) + 0.0, (e.ry or 0) + 0.0, (e.rz or 0) + 0.0, 2, true)
            FreezeEntityPosition(obj, true)
            SetEntityInvincible(obj, true)
            SetModelAsNoLongerNeeded(h)
            local entry = { id = e.id, type = e.type, ent = obj, x = e.x, y = e.y, z = e.z, label = (Config.Equipment[e.type] or { label = e.type }).label }
            shown[#shown + 1] = entry
            -- décor (accessoires posés sur / à côté de l'équipement), fourni par elyzea_drogues
            local dk = Config.LabDecor and Config.LabDecor[e.type]
            if dk and drogues() then
                local ok, res = pcall(function() return exports.elyzea_drogues:SpawnDecor(obj, dk) end)
                entry.decor = ok and type(res) == 'table' and res.props or {}
                entry.chair = ok and type(res) == 'table' and res.chair or nil
                if gen ~= mine then for _, o in ipairs(entry.decor) do if DoesEntityExist(o) then DeleteEntity(o) end end return end
            end
        end
    end
end
function C.Shown() return shown end

RegisterNetEvent('elyzea_labs:equipment', function(list)
    if C.inside then C.inside.equipment = list C.SpawnEquipment(list) end
end)

function C.NearEquipment(pc)
    local best, bd
    for _, e in ipairs(shown) do
        if DoesEntityExist(e.ent) then
            local d = #(pc - GetEntityCoords(e.ent))
            if d < 2.2 and (not bd or d < bd) then best, bd = e, d end
        end
    end
    return best
end

function C.OpenCraft(e)
    local r = C.Pub('equipMenu', { lab = C.inside.id, id = e.id })
    if r.error then return C.Notify(r.error, 'error') end
    C.Open('craft', r)
end

function C.CraftAbort()
    if crafting then
        crafting = nil
        C.Pub('craftCancel')
        if drogues() then pcall(function() exports.elyzea_drogues:StopStep() end) end
    end
end
RegisterNetEvent('elyzea_labs:craftCancel', function() crafting = nil end)

-- Fin d'une étape immersive lancée par ce laboratoire
local stepWaits = {}
AddEventHandler('elyzea_drogues:stepDone', function(id, res)
    local token = stepWaits[id]
    if not token then return end
    stepWaits[id] = nil
    if crafting ~= token then return end
    crafting = nil
    if res and res.ok then C.Show(C.Pub('craftFinish', { token = token, result = res })) return end
    C.Pub('craftCancel')
    if res and (res.reason == 'mistakes' or res.reason == 'time') then C.Notify('Raté ! Rien n\'est perdu : tes ingrédients sont intacts, recommence.', 'error')
    else C.Notify('Fabrication annulée.', 'inform') end
end)

RegisterNUICallback('craft', function(body, cb)
    cb({})
    if not C.inside or crafting then return end
    local r = C.Pub('craftStart', { lab = C.inside.id, id = tonumber(body.id), recipe = tostring(body.recipe or ''), times = tonumber(body.times) or 1 })
    if r.error then return C.Notify(r.error, 'error') end
    C.Close()
    crafting = r.token
    if r.game and drogues() then
        -- mini-jeu + scène (elyzea_drogues), résultat revérifié par le serveur
        local ent, chair
        for _, e in ipairs(shown) do if e.id == tonumber(body.id) then ent, chair = e.ent, e.chair end end
        local id = exports.elyzea_drogues:RunStep({ game = r.game, profile = r.game.profile, entity = ent, chair = chair, siteType = nil, duration = r.duration / 1000 })
        if not id then crafting = nil C.Pub('craftCancel') return C.Notify('Termine d\'abord ce que tu fais.', 'error') end
        stepWaits[id] = r.token
        return
    end
    CreateThread(function()
        local anim = r.anim or {}
        local ok = exports.elyzea_core:ProgressBar({ duration = r.duration, label = r.label, canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = anim.scenario and { scenario = anim.scenario } or (anim.dict and { dict = anim.dict, clip = anim.clip, flag = anim.flag or 1 }) or nil })
        ClearPedTasks(PlayerPedId())
        local token = crafting
        crafting = nil
        if not token then return end
        if ok then C.Show(C.Pub('craftFinish', { token = token })) else C.Pub('craftCancel') C.Notify('Fabrication annulée.', 'inform') end
    end)
end)
