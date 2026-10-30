-- =====================================================================
--  ELYZEA CLOTHING · CHAPEAU ET LUNETTES QUI TOMBENT (client)
--  · le jeu fait tomber le chapeau / les lunettes (coup reçu, chute) : ils deviennent de vrais objets au sol
--  · G à côté de lunettes tombées : les écraser ; clic droit › Casser dans l'inventaire
--  Les objets sont créés par le serveur (server/knockoff.lua).
-- =====================================================================
local K = Config.KnockOff or {}
-- Hash comparé en 32 bits non signés (serveur et client peuvent l'écrire signé ou non)
local function u32(h) return h and (math.floor(tonumber(h) or 0) & 0xFFFFFFFF) or nil end
local GLASSES_PROP = K.props and K.props.glasses and u32(GetHashKey(K.props.glasses)) or nil

local function enabled() return K.enabled ~= false and ClothingItemsMode() end

local function loadDict(d)
    if not DoesAnimDictExist(d) then return false end
    RequestAnimDict(d)
    local t = GetGameTimer() + 1500
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(d)
end

-- ---------------------------------------------------------------------
-- Chute « normale » du jeu : quand on prend un coup (ou qu'on tombe), GTA fait tomber
-- le chapeau et les lunettes. On le repère ici et le serveur pose le VRAI objet au sol.
-- Seulement juste après un coup reçu ou une chute : un vêtement retiré autrement
-- (inventaire, tenue, boutique, autre script) n'est jamais compté comme tombé.
-- ---------------------------------------------------------------------
local CATS = { 'hats', 'glasses' }
local seen = {}             -- [rayon] = dernière pièce portée
local ignoreUntil = 0       -- changement de tenue fait par la boutique / l'inventaire
local lastHit, lastRagdoll = 0, 0
local WINDOW = K.window or 2500

local function ignore(ms) ignoreUntil = math.max(ignoreUntil, GetGameTimer() + (ms or 3000)) end
-- Nos propres changements de tenue (porter, ranger, tenue enregistrée, boutique)
AddEventHandler('elyzea_clothing:apply', function() ignore() end)
AddEventHandler('elyzea_clothing:outfitApply', function() ignore(5000) end)
AddEventHandler('elyzea_clothing:result', function() ignore() end)
exports('IgnoreFall', function(ms) ignore(ms) end)   -- pour un autre script qui retire le chapeau / les lunettes

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' and args[1] == PlayerPedId() then lastHit = GetGameTimer() end
end)

CreateThread(function()
    while true do
        Wait(200)
        local ped = PlayerPedId()
        local now = GetGameTimer()
        if IsPedRagdoll(ped) or IsPedFalling(ped) then lastRagdoll = now end
        local busy = not enabled() or ClothingShopOpen() or now < ignoreUntil or LocalPlayer.state.pvpArena
        local knocked = now - lastHit < WINDOW or now - lastRagdoll < WINDOW
        for _, cat in ipairs(CATS) do
            local p = ClothingWorn(cat)
            if p and p.drawable and p.drawable >= 0 then
                seen[cat] = p
            elseif seen[cat] then
                if knocked and not busy then
                    TriggerServerEvent('elyzea_clothing:propFell', cat, seen[cat])
                end
                seen[cat] = nil
            end
        end
    end
end)

-- Le serveur a posé l'objet au sol : on garde la tenue sans le chapeau / les lunettes
RegisterNetEvent('elyzea_clothing:fell', function(cats)
    ignore()
    SaveClothingAppearance()
    TriggerEvent('elyzea_clothing:wardrobeRefresh')
    local hat, gl = false, false
    for _, c in ipairs(cats or {}) do if c == 'hats' then hat = true elseif c == 'glasses' then gl = true end end
    ClothingNotify(hat and gl and 'Ton chapeau et tes lunettes sont tombés par terre.' or hat and 'Ton chapeau est tombé par terre.' or 'Tes lunettes sont tombées par terre.', 'inform')
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
