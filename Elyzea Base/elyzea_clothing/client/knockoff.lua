-- =====================================================================
--  ELYZEA CLOTHING · CHAPEAU ET LUNETTES QUI TOMBENT (client)
--  · le jeu fait tomber le chapeau / les lunettes (coup reçu, chute) : ils deviennent de vrais objets au sol
--  · ALT sur le chapeau / les lunettes au sol : Ramasser (tout le monde), Casser les lunettes
--  · clic droit › Casser sur des lunettes de l'inventaire
--  Les objets sont créés par le serveur (server/knockoff.lua).
-- =====================================================================
local K = Config.KnockOff or {}
-- Hash comparé en 32 bits non signés (serveur et client peuvent l'écrire signé ou non)
local function u32(h) return h and (math.floor(tonumber(h) or 0) & 0xFFFFFFFF) or nil end

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
-- ALT sur le chapeau / les lunettes au sol (menu ALT d'elyzea_police, préfixe « clo: ») :
-- Ramasser (tout le monde : le propriétaire ou un voleur) · Casser les lunettes
-- Les objets au sol sont ceux d'elyzea_inventory : on reconnaît les nôtres à leur modèle 3D.
-- ---------------------------------------------------------------------
local INV = 'elyzea_inventory'
local MODEL_CAT = {}
for cat, m in pairs(K.props or {}) do MODEL_CAT[u32(GetHashKey(m))] = cat end
local TITLE = { hats = 'Chapeau tombé au sol', glasses = 'Lunettes tombées au sol' }

-- Objet au sol à nous : rayon (hats / glasses) et n° du tas, sinon nil
local function fallen(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetResourceState(INV) ~= 'started' then return nil end
    local ok, id, prop = pcall(function() return exports[INV]:DropOfEntity(ent) end)
    local cat = ok and id and prop and MODEL_CAT[u32(prop)]
    if not cat then return nil end
    return cat, id
end

exports('AltTarget', function(ent)
    local cat = fallen(ent)
    return cat and TITLE[cat] or nil
end)

exports('AltNearby', function()
    if GetResourceState(INV) ~= 'started' then return nil end
    local ok, list = pcall(function() return exports[INV]:DropEntities() end)
    if not ok or type(list) ~= 'table' then return nil end
    local me = GetEntityCoords(PlayerPedId())
    local best, bd, bcat
    for _, e in ipairs(list) do
        local cat = e.prop and MODEL_CAT[u32(e.prop)]
        if cat and DoesEntityExist(e.entity) then
            local d = #(GetEntityCoords(e.entity) - me)
            if d < (K.altDistance or 2.0) and (not bd or d < bd) then best, bd, bcat = e.entity, d, cat end
        end
    end
    if not best then return nil end
    return best, TITLE[bcat]
end)

exports('AltOptions', function(ctx)
    local cat = fallen(ctx and ctx.entity)
    if not cat or not enabled() then return {} end
    local out = { { id = 'take', label = 'Ramasser', icon = 'bag', desc = 'Va dans ton inventaire' } }
    if cat == 'glasses' then
        out[#out + 1] = { id = 'break', label = 'Casser les lunettes', icon = 'break', desc = 'Elles ne pourront plus être portées' }
    end
    return out
end)

local busyAct = false
exports('AltSelect', function(id, ctx)
    local cat, dropId = fallen(ctx and ctx.entity)
    if not cat or busyAct then return true end
    busyAct = true
    CreateThread(function()
        local ped = PlayerPedId()
        if loadDict('pickup_object') then TaskPlayAnim(ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 900, 0, 0, false, false, false) end
        Wait(600)
        if id == 'take' then TriggerServerEvent('elyzea_clothing:groundTake', dropId)
        elseif id == 'break' then TriggerServerEvent('elyzea_clothing:breakGround', dropId) end
        Wait(400)
        busyAct = false
    end)
    return true
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
