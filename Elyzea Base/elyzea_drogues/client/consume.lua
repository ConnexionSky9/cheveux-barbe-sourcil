-- =====================================================================
--  ELYZEA DROGUES · animations de prise et fumée colorée (client)
--  FX.PlayUse(objet, couleur) : animation et prop du produit (config/products.lua › UseAnims).
--  Joints et pipes : bouffées de fumée aux moments réglés (puffs), de la couleur envoyée par le serveur
--  (variété). Effet de particules « scr_ar_trail_smoke » (fumée des avions de voltige) dont la couleur
--  se règle avec SetParticleFxLoopedColour. Les joueurs proches voient la même fumée (relais serveur).
--  Prop et particules sont toujours supprimés à la fin (même en cas d'interruption).
-- =====================================================================
local FX = DrugFx
local SM = Config.Smoke

local function loadDict(d)
    if not d or not DoesAnimDictExist(d) then return false end
    RequestAnimDict(d)
    local t = GetGameTimer() + 2000
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(d)
end

local function loadPtfx()
    if HasNamedPtfxAssetLoaded(SM.asset) then return true end
    RequestNamedPtfxAsset(SM.asset)
    local t = GetGameTimer() + 1500
    while not HasNamedPtfxAssetLoaded(SM.asset) and GetGameTimer() < t do Wait(0) end
    return HasNamedPtfxAssetLoaded(SM.asset)
end

-- Une bouffée colorée à la bouche d'un personnage (arrêtée et supprimée après SM.seconds)
function FX.Puff(ped, color)
    if not ped or ped == 0 or not DoesEntityExist(ped) or not color then return end
    if not loadPtfx() then return end
    UseParticleFxAssetNextCall(SM.asset)
    local fx = StartParticleFxLoopedOnEntityBone(SM.effect, ped, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0, GetPedBoneIndex(ped, 31086), SM.scale, false, false, false)
    if not fx or fx == 0 then return end
    SetParticleFxLoopedColour(fx, (color[1] or 200) / 255.0, (color[2] or 200) / 255.0, (color[3] or 200) / 255.0, false)
    SetParticleFxLoopedAlpha(fx, 0.85)
    SetTimeout(math.floor((SM.seconds or 1.4) * 1000), function()
        StopParticleFxLooped(fx, false)
        RemoveParticleFx(fx, false)
    end)
end

-- Fumée d'un autre joueur proche (relayée par le serveur, couleur décidée par le serveur)
RegisterNetEvent('elyzea_drogues:puff', function(serverId, color)
    local pl = GetPlayerFromServerId(serverId)
    if pl == -1 then return end
    local ped = GetPlayerPed(pl)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) > (SM.syncRadius or 35.0) + 10.0 then return end
    FX.Puff(ped, color)
end)

-- Animation de prise d'un produit. Bloque le temps de l'animation (appelée dans un fil).
function FX.PlayUse(item, color)
    local prod = item and Config.Products[item]
    local u = prod and Config.UseAnims[prod.use] or nil
    local ped = PlayerPedId()
    if not u or IsPedInAnyVehicle(ped, false) then
        -- en véhicule : pas d'animation, seulement la fumée éventuelle
        if color then FX.Puff(ped, color) TriggerServerEvent('elyzea_drogues:puff') end
        Wait(1200)
        return
    end
    if not loadDict(u.dict) then
        u = Config.UseAnims[u.fallback or 'pill']
        if not u or not loadDict(u.dict) then Wait(1500) return end
    end
    local prop
    if u.prop and IsModelInCdimage(GetHashKey(u.prop.model)) then
        local hash = DrugWorld.LoadModel(u.prop.model)
        if hash then
            local c = GetEntityCoords(ped)
            prop = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false)
            SetModelAsNoLongerNeeded(hash)
            local pp, pr = u.prop.pos, u.prop.rot
            AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, u.prop.bone or 28422), pp[1], pp[2], pp[3], pr[1], pr[2], pr[3], true, true, false, true, 1, true)
        end
    end
    TaskPlayAnim(ped, u.dict, u.clip, 3.0, -3.0, u.time, u.flag or 49, 0, false, false, false)
    local start = GetGameTimer()
    local puffs = {}
    for i, t in ipairs(u.puffs or {}) do puffs[i] = t end
    while GetGameTimer() - start < u.time do
        if IsEntityDead(ped) or IsPedRagdoll(ped) or LocalPlayer.state.emsDown then break end
        local el = (GetGameTimer() - start) / 1000.0
        if color and puffs[1] and el >= puffs[1] then
            table.remove(puffs, 1)
            FX.Puff(ped, color)
            TriggerServerEvent('elyzea_drogues:puff')
        end
        Wait(50)
    end
    StopAnimTask(ped, u.dict, u.clip, 1.0)
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
end
