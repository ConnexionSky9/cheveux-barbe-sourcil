-- =====================================================================
--  ELYZEA CLOTHING · CHAPEAU ET LUNETTES QUI TOMBENT (client)
--  · ALT sur une personne › Pousser (menu ALT d'elyzea_police, préfixe « clo: »)
--  · coup de poing / arme de mêlée reçu d'un joueur : la personne frappée le signale
--  · G à côté de lunettes tombées : les écraser
--  Tout est décidé par le serveur (server/knockoff.lua) : chance, distance, objets créés.
-- =====================================================================
local K = Config.KnockOff or {}
local GROUP_MELEE = `GROUP_MELEE`
local UNARMED = `WEAPON_UNARMED`
-- Hash comparé en 32 bits non signés (serveur et client peuvent l'écrire signé ou non)
local function u32(h) return h and (math.floor(tonumber(h) or 0) & 0xFFFFFFFF) or nil end
local GLASSES_PROP = K.props and K.props.glasses and u32(GetHashKey(K.props.glasses)) or nil

local function enabled() return K.enabled ~= false and ClothingItemsMode() end
local function wornNow() return { hats = ClothingWorn('hats'), glasses = ClothingWorn('glasses') } end

local function loadDict(d)
    if not DoesAnimDictExist(d) then return false end
    RequestAnimDict(d)
    local t = GetGameTimer() + 1500
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(d)
end

-- ---------------------------------------------------------------------
-- Menu ALT (elyzea_police) : « Pousser » sur une personne
-- ---------------------------------------------------------------------
exports('AltOptions', function(ctx)
    local out = {}
    if K.enabled == false or type(ctx) ~= 'table' or ctx.kind ~= 'player' or not ctx.sid then return out end
    local busy = ctx.inVehicle and 'La personne est dans un véhicule' or (IsPedInAnyVehicle(PlayerPedId(), false) and 'Tu es dans un véhicule') or nil
    out[1] = { id = 'push', label = 'Pousser', icon = 'push', disabled = busy ~= nil,
        desc = busy or 'Son chapeau et ses lunettes peuvent tomber' }
    return out
end)

exports('AltSelect', function(id, ctx)
    if id ~= 'push' or type(ctx) ~= 'table' or not ctx.sid then return true end
    TriggerServerEvent('elyzea_clothing:push', ctx.sid)
    return true
end)

-- Le pousseur : petit geste de poussée
RegisterNetEvent('elyzea_clothing:pushDone', function()
    local ped = PlayerPedId()
    if loadDict('reaction@shove') then
        TaskPlayAnim(ped, 'reaction@shove', 'shove_var_a', 8.0, -8.0, 900, 48, 0, false, false, false)
    end
end)

-- La personne poussée : elle part en arrière, puis envoie ce qu'elle porte
RegisterNetEvent('elyzea_clothing:pushed', function(by)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
    local byPed = GetPlayerPed(GetPlayerFromServerId(by))
    local dir = GetEntityForwardVector(ped) * -1.0
    if byPed and byPed ~= 0 and DoesEntityExist(byPed) then
        local v = GetEntityCoords(ped) - GetEntityCoords(byPed)
        local n = math.sqrt(v.x * v.x + v.y * v.y)
        if n > 0.01 then dir = vector3(v.x / n, v.y / n, 0.0) end
    end
    SetPedToRagdoll(ped, 1200, 1800, 0, false, false, false)
    ApplyForceToEntity(ped, 1, dir.x * 4.0, dir.y * 4.0, 0.8, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    if enabled() then TriggerServerEvent('elyzea_clothing:knock', 'push', by, wornNow()) end
end)

-- ---------------------------------------------------------------------
-- Coups reçus d'un joueur (poing ou arme de mêlée)
-- ---------------------------------------------------------------------
local lastSent = 0
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or not enabled() then return end
    local me = PlayerPedId()
    local victim, attacker, weapon = args[1], args[2], args[7]
    if victim ~= me or not attacker or attacker == me or not DoesEntityExist(attacker) or not IsPedAPlayer(attacker) then return end
    if LocalPlayer.state.pvpArena then return end   -- arène PvP : rien ne tombe
    if weapon ~= UNARMED and GetWeapontypeGroup(weapon) ~= GROUP_MELEE then return end
    if IsPedInAnyVehicle(me, false) or GetGameTimer() - lastSent < 1000 then return end
    lastSent = GetGameTimer()
    local by = GetPlayerServerId(NetworkGetPlayerIndexFromPed(attacker))
    if by and by > 0 then TriggerServerEvent('elyzea_clothing:knock', 'hit', by, wornNow()) end
end)

-- ---------------------------------------------------------------------
-- Lunettes tombées au sol : G pour les écraser
-- (les tas au sol viennent d'elyzea_inventory ; on repère ceux qui ont le modèle « lunettes »)
-- ---------------------------------------------------------------------
local glassesDrops = {}
RegisterNetEvent('elyzea_inv:drops', function(list)
    glassesDrops = {}
    if not GLASSES_PROP then return end
    for _, d in ipairs(list or {}) do
        if d.prop and u32(d.prop) == GLASSES_PROP then glassesDrops[#glassesDrops + 1] = d.coords end
    end
end)

local breaking = false
CreateThread(function()
    while true do
        local sleep = 700
        if #glassesDrops > 0 and enabled() and not breaking then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            for _, c in ipairs(glassesDrops) do
                local d = #(pos - c)
                if d < 6.0 then sleep = 0 end
                if d < (K.breakDistance or 1.6) and not IsPedInAnyVehicle(ped, false) then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('~INPUT_DETONATE~ Écraser les lunettes · ramasser : inventaire, « Au sol »')
                    EndTextCommandDisplayHelp(0, false, false, -1)
                    if IsControlJustPressed(0, K.breakKey or 47) then
                        breaking = true
                        if loadDict('pickup_object') then
                            TaskPlayAnim(ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 900, 0, 0, false, false, false)
                        end
                        Wait(700)
                        TriggerServerEvent('elyzea_clothing:breakGround')
                        SetTimeout(800, function() breaking = false end)
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

-- Bruit de verre brisé (lunettes au sol ou dans l'inventaire)
RegisterNetEvent('elyzea_clothing:brokeGlasses', function()
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
end)

-- Inventaire : clic droit › Casser (lunettes)
exports('BreakSlot', function(slot)
    local n = type(slot) == 'table' and slot.slot or tonumber(slot)
    if n then TriggerServerEvent('elyzea_clothing:breakSlot', n) end
end)
