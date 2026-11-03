-- =====================================================================
--  ELYZEA LASERGAME - PNJ D'ACCÈS ET TOUCHE D'INTERACTION
--  * PNJ : configuration (config.lua) + PNJ posés en jeu (/lgadmin › PNJ), créés localement
--    seulement à moins de Config.NpcLoadDistance m, supprimés au-delà (aucun coût au loin).
--  * Touche d'interaction unique (E par défaut, modifiable dans Paramètres › Raccourcis › FiveM) :
--    PNJ hors partie ; portes, armes murales, atouts et réanimation en partie Zombie.
--  * Aucune boucle par image au repos : vérification de distance toutes les 250 à 1500 ms.
-- =====================================================================
local npcs = {}        -- [id] = { def, ped, blip }
C.Interactions = {}    -- fournisseurs : fn() -> { label, price, key, action, hold } ou nil (le plus proche gagne)
local prompt = nil

local function deletePed(n)
    if n.ped and DoesEntityExist(n.ped) then DeleteEntity(n.ped) end
    n.ped = nil
end

local function spawnPed(n)
    local d = n.def
    local h = C.LoadModel(d.model or 's_m_y_ammucity_01')
    if not h then return end
    local ped = CreatePed(4, h, d.x, d.y, d.z, d.h or 0.0, false, true)
    SetModelAsNoLongerNeeded(h)
    SetEntityHeading(ped, d.h or 0.0)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedDiesWhenInjured(ped, false)
    if d.anim and d.anim.dict and C.LoadDict(d.anim.dict) then
        TaskPlayAnim(ped, d.anim.dict, d.anim.name, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    elseif d.scenario then
        TaskStartScenarioInPlace(ped, d.scenario, 0, true)
    end
    n.ped = ped
end

local function syncNpcs(list)
    local keep = {}
    for _, d in ipairs(list or {}) do
        keep[d.id] = true
        local n = npcs[d.id]
        if n and (n.def.x ~= d.x or n.def.y ~= d.y or n.def.model ~= d.model) then
            deletePed(n)
            if n.blip then RemoveBlip(n.blip) end
            n = nil
        end
        if not n then
            n = { def = d }
            npcs[d.id] = n
            local b = d.blip
            if b and b.enabled then
                n.blip = AddBlipForCoord(d.x, d.y, d.z)
                SetBlipSprite(n.blip, b.sprite or 432)
                SetBlipColour(n.blip, b.color or 27)
                SetBlipScale(n.blip, b.scale or 0.85)
                SetBlipAsShortRange(n.blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(b.label or 'LaserGame')
                EndTextCommandSetBlipName(n.blip)
            end
        end
    end
    for id, n in pairs(npcs) do
        if not keep[id] then
            deletePed(n)
            if n.blip then RemoveBlip(n.blip) end
            npcs[id] = nil
        end
    end
end

local lastNpcVersion
C.OnPublicChanged = function(pub)
    if pub.v ~= lastNpcVersion then
        lastNpcVersion = pub.v
        syncNpcs(pub.npcs)
    end
    if C.OnPublicChangedExtra then C.OnPublicChangedExtra(pub) end
end

-- PNJ : apparition / disparition selon la distance
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local closest = math.huge
        for _, n in pairs(npcs) do
            local d = #(pos - vector3(n.def.x, n.def.y, n.def.z))
            closest = math.min(closest, d)
            if d < Config.NpcLoadDistance and not n.ped and not C.inGame then spawnPed(n)
            elseif (d > Config.NpcLoadDistance + 10.0 or C.inGame) and n.ped then deletePed(n) end
        end
        Wait(closest < 80.0 and 1000 or 2500)
    end
end)

-- Interaction avec un PNJ (fournisseur)
C.Interactions[#C.Interactions + 1] = function(pos)
    if C.inGame or C.uiOpen then return nil end
    for _, n in pairs(npcs) do
        local d = #(pos - vector3(n.def.x, n.def.y, n.def.z))
        if d <= (n.def.distance or 2.2) + 0.3 then
            return { dist = d, label = n.def.text or 'Ouvrir le LaserGame', title = n.def.label or 'LaserGame', action = function() C.OpenUI('home') end }
        end
    end
end

-- ---------------------------------------------------------------- invite d'interaction
local function showPrompt(p)
    local key = GetControlInstructionalButton(0, GetHashKey('+lg_interact') | 0x80000000, true) or 'E'
    key = key:gsub('^t_', ''):gsub('^b_', '')
    C.UI('prompt', { key = key ~= '' and key or 'E', label = p.label, title = p.title, price = p.price, money = p.money, hold = p.hold })
end

CreateThread(function()
    while true do
        local wait = 600
        local pos = GetEntityCoords(PlayerPedId())
        local best
        for _, f in ipairs(C.Interactions) do
            local r = f(pos)
            if r and (not best or r.dist < best.dist) then best = r end
        end
        if best then
            wait = 200
            local sig = (best.label or '') .. (best.price or '') .. tostring(best.money or '')
            if not prompt or prompt.sig ~= sig then showPrompt(best) end
            best.sig = sig
            prompt = best
        elseif prompt then
            prompt = nil
            C.UI('prompt', false)
        end
        Wait(wait)
    end
end)

RegisterCommand('+lg_interact', function()
    if not prompt or C.uiOpen then return end
    if prompt.hold and prompt.onPress then prompt.onPress() return end
    if prompt.action then prompt.action() end
end, false)
RegisterCommand('-lg_interact', function()
    if prompt and prompt.hold and prompt.onRelease then prompt.onRelease() end
    if C.OnInteractRelease then C.OnInteractRelease() end
end, false)
RegisterKeyMapping('+lg_interact', 'LaserGame : interagir', 'keyboard', Config.InteractKey or 'E')

function C.ClearPrompt() prompt = nil C.UI('prompt', false) end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, n in pairs(npcs) do deletePed(n) if n.blip then RemoveBlip(n.blip) end end
end)
