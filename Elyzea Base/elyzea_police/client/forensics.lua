-- =====================================================================
--  elyzea_police - client : police scientifique
--  · Tous les joueurs : un tir (arme à feu) ou une blessure est signalé au serveur, qui crée
--    la preuve à partir de l'arme réellement en main / du personnage blessé.
--  · Policiers en service : les preuves proches s'affichent ; ALT dessus pour examiner / prélever.
--  · Au laboratoire : ALT › réceptionner les scellés, ouvrir le laboratoire.
-- =====================================================================
local C = PoliceC
local F = Config.Forensics or {}
local Scene = {}            -- [id] = preuve visible (sans numéro de série ni ADN)
local busy = false

local function Street(c) return C.Street(c) end

-- ---------------------------------------------------------------------
-- Tirs → douilles
-- ---------------------------------------------------------------------
CreateThread(function()
    if not F.enabled or not F.casings then return end
    local lastSent = 0
    while true do
        local ped = PlayerPedId()
        if IsPedArmed(ped, 4) then
            if IsPedShooting(ped) and GetGameTimer() - lastSent > 700 then
                lastSent = GetGameTimer()
                -- La douille tombe à droite du tireur, au sol
                local c = GetOffsetFromEntityInWorldCoords(ped, 0.6 + math.random() * 0.4, 0.2 + math.random() * 0.4, 0.0)
                local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
                TriggerServerEvent('police:forensic:shot', c.x, c.y, found and groundZ + 0.02 or c.z - 0.95, Street(c))
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

-- ---------------------------------------------------------------------
-- Blessures → traces de sang
-- ---------------------------------------------------------------------
local lastBlood = 0
AddEventHandler('gameEventTriggered', function(name, args)
    if not F.enabled or not F.blood or name ~= 'CEventNetworkEntityDamage' then return end
    local ped = PlayerPedId()
    if args[1] ~= ped or GetGameTimer() - lastBlood < (F.bloodCooldown or 20) * 1000 then return end
    local weapon = args[7]
    -- Chutes, noyade, feu, gaz : pas de trace de sang exploitable
    if weapon == `WEAPON_FALL` or weapon == `WEAPON_DROWNING` or weapon == `WEAPON_DROWNING_IN_VEHICLE` or weapon == `WEAPON_FIRE` or weapon == `WEAPON_BZGAS` then return end
    lastBlood = GetGameTimer()
    local c = GetEntityCoords(ped)
    local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
    TriggerServerEvent('police:forensic:blood', c.x, c.y, found and groundZ + 0.02 or c.z - 0.95, Street(c))
end)

-- ---------------------------------------------------------------------
-- Preuves visibles (policiers en service)
-- ---------------------------------------------------------------------
RegisterNetEvent('police:forensic:nearby', function(list)
    Scene = {}
    for _, e in ipairs(list or {}) do Scene[e.id] = e end
end)
RegisterNetEvent('police:forensic:add', function(e) if C.OnDuty() then Scene[e.id] = e end end)
RegisterNetEvent('police:forensic:update', function(e) if Scene[e.id] then Scene[e.id] = e end end)
RegisterNetEvent('police:forensic:remove', function(id) Scene[id] = nil end)

CreateThread(function()
    while true do
        if F.enabled and C.cfg and C.OnDuty() then
            TriggerServerEvent('police:forensic:nearby')
            Wait(2500)
        else
            if next(Scene) then Scene = {} end
            Wait(3000)
        end
    end
end)

local function Draw3D(x, y, z, text)
    local on, sx, sy = World3dToScreen2d(x, y, z)
    if not on then return end
    SetTextScale(0.3, 0.3)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 255, 255, 220)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

CreateThread(function()
    while true do
        local sleep = 800
        if next(Scene) then
            local pos = GetEntityCoords(PlayerPedId())
            local range = F.visibleDistance or 25.0
            for _, e in pairs(Scene) do
                local d = #(pos - vector3(e.x, e.y, e.z))
                if d <= range then
                    sleep = 0
                    if e.type == 'casing' then
                        DrawMarker(1, e.x, e.y, e.z - 0.02, 0, 0, 0, 0, 0, 0, 0.06, 0.06, 0.03, 214, 170, 60, 230, false, false, 2, false, nil, nil, false)
                    else
                        DrawMarker(23, e.x, e.y, e.z + 0.01, 0, 0, 0, 0, 0, 0, 0.35, 0.35, 0.1, 140, 10, 10, 200, false, false, 2, false, nil, nil, false)
                    end
                    if d <= 3.0 then
                        Draw3D(e.x, e.y, e.z + 0.25, ('%s%s'):format(e.label, (e.count or 1) > 1 and (' ×' .. e.count) or ''))
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------------
-- ALT : examiner, prélever, laboratoire
-- ---------------------------------------------------------------------
local function NearestEvidence(ctx)
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, e in pairs(Scene) do
        local p = vector3(e.x, e.y, e.z)
        local dMe = #(me - p)
        if dMe <= (F.collectDistance or 2.5) + 0.5 then
            local d = ctx.coords and #(vector3(ctx.coords.x, ctx.coords.y, ctx.coords.z) - p) or dMe
            if (ctx.coords == nil or d <= 1.2 or dMe <= 1.6) and (not bestD or d < bestD) then best, bestD = e, d end
        end
    end
    return best
end

local function NearLab()
    local me = GetEntityCoords(PlayerPedId())
    for _, pt in ipairs(C.cfg and C.cfg.points and C.cfg.points.lab or {}) do
        if #(me - vector3(pt.x, pt.y, pt.z)) <= (F.labDistance or 12.0) then return true end
    end
    return false
end

local function Ago(t)
    local m = math.floor((GetCloudTimeAsInt() - (t or 0)) / 60)
    if m < 1 then return 'il y a moins d\'une minute' end
    if m < 60 then return ('il y a %d min'):format(m) end
    return ('il y a %d h'):format(math.floor(m / 60))
end

local function BagCount()
    local ok, n = pcall(function() return exports.elyzea_inventory:Search('count', 'empty_evidence_bag') end)
    return ok and tonumber(n) or 0
end

local function Options(ctx)
    if not F.enabled or not C.cfg or C.cuffed or not C.OnDuty() then return {} end
    local out = {}
    if ctx.kind ~= 'player' and ctx.kind ~= 'vehicle' then
        local e = NearestEvidence(ctx)
        if e then
            out[#out + 1] = { id = 'examine:' .. e.id, label = ('Examiner : %s'):format(e.label), group = 'Police scientifique', order = 40 }
            if C.Can('sci_collect') then
                local bags = BagCount()
                out[#out + 1] = { id = 'collect:' .. e.id, label = 'Prélever (sachet de preuve)', desc = bags > 0 and ('%d sachet(s) vide(s)'):format(bags) or 'Aucun sachet de preuve vide',
                    disabled = bags < 1 or busy, group = 'Police scientifique', order = 41 }
            end
        end
    end
    if NearLab() and ctx.kind ~= 'player' then
        if C.Can('sci_lab') or C.Can('sci_collect') then
            out[#out + 1] = { id = 'receive', label = 'Réceptionner mes scellés', desc = 'Sachets de preuve de votre inventaire', group = 'Laboratoire', order = 45 }
        end
        if C.Can('sci_view', true) then out[#out + 1] = { id = 'openLab', label = 'Ouvrir le laboratoire', group = 'Laboratoire', order = 46 } end
    end
    return out
end

local function Collect(id)
    local e = Scene[id]
    if not e or busy then return end
    busy = true
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, e.x, e.y, e.z, 600)
    Wait(600)
    -- Accroupi, gants : prélèvement interruptible (X)
    local okBar, done = pcall(function()
        return exports.elyzea_core:ProgressBar({ duration = F.collectTime or 4000, label = 'Prélèvement de la preuve… (X pour annuler)', canCancel = true,
            anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 1 },
            disable = { move = true, car = true, combat = true } })
    end)
    if not okBar then done = true Wait(F.collectTime or 4000) end
    busy = false
    if not done then return C.Notify('Prélèvement annulé.', 'error') end
    if not Scene[id] then return C.Notify('Cette preuve n\'est plus sur la scène.', 'error') end
    TriggerServerEvent('police:forensic:collect', id)
end

local function Select(id)
    local kind, evId = id:match('^(%a+):(%d+)$')
    evId = tonumber(evId)
    if kind == 'examine' and Scene[evId] then
        local e = Scene[evId]
        if e.type == 'casing' then
            C.Notify(('Douille de calibre %s%s · déposée %s.'):format(e.calibre or '?', (e.count or 1) > 1 and (' (×' .. e.count .. ')') or '', Ago(e.t)), 'inform')
        else
            C.Notify(('Trace de sang%s · %s. À prélever pour une analyse ADN.'):format((e.count or 1) > 1 and (' (×' .. e.count .. ')') or '', Ago(e.t)), 'inform')
        end
    elseif kind == 'collect' then
        Collect(evId)
    elseif id == 'receive' then
        TriggerServerEvent('police:forensic:receive')
    elseif id == 'openLab' then
        TriggerEvent('police:client:openTabletPage', 'sci')
    end
end

local function Register()
    if GetResourceState('elyzea_jobs') ~= 'started' then return end
    exports.elyzea_jobs:AltRegister('police_forensics', Options, Select)
end
CreateThread(function() Wait(1200) Register() end)
AddEventHandler('onClientResourceStart', function(res) if res == 'elyzea_jobs' then Wait(600) Register() end end)
