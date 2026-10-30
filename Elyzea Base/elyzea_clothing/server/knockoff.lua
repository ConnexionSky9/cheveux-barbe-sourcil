-- =====================================================================
--  ELYZEA CLOTHING · CHAPEAU ET LUNETTES QUI TOMBENT (serveur)
--  Pousser (ALT) ou frapper au corps à corps : le chapeau et les lunettes portés
--  peuvent tomber au sol en vrais objets d'inventaire (vet_chapeau / vet_lunettes).
--  N'importe qui peut les ramasser (inventaire › « Au sol ») ; les lunettes peuvent être écrasées.
-- =====================================================================
local K = Config.KnockOff or {}
local INV = 'elyzea_inventory'
local CATS = { 'hats', 'glasses' }
local GLASSES = Config.Items.names.glasses
local inv = function() return exports[INV] end
local function notify(src, msg, kind) TriggerClientEvent('elyzea_clothing:notify', src, msg, kind or 'error') end

local lastKnock, lastPush, lastHit = {}, {}, {}
local function now() return GetGameTimer() end
local function coords(src) local ped = GetPlayerPed(src) return ped ~= 0 and GetEntityCoords(ped) or nil end
local function inVehicle(src) local ped = GetPlayerPed(src) return ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0 end
local function on() return K.enabled ~= false and Items.enabled() end

-- Lunettes cassées : mêmes objet et modèle, marquées « cassées » (impossibles à porter)
function Items.breakMeta(md)
    md = md or {}
    md.broken = true
    md.custom = nil
    md.label = 'Lunettes cassées'
    md.description = 'Verres brisés : elles ne peuvent plus être portées.'
    return md
end

-- Fait tomber ce qui doit tomber. reason = 'push' | 'hit'. worn = { hats = pièce, glasses = pièce } lu sur le personnage.
local function knock(src, reason, worn)
    if not on() or not GetPlayerName(src) or Items.inUniform(src) or inVehicle(src) then return 0 end
    if lastKnock[src] and now() - lastKnock[src] < (K.victimCooldown or 4000) then return 0 end
    local sex = Items.sexOf(src)
    local c = coords(src)
    if not sex or not c then return 0 end
    local chances = (reason == 'push' and K.push) or K.hit or {}
    worn = type(worn) == 'table' and worn or {}
    local names = Items.wornNames(src)
    local fell = 0
    for i, cat in ipairs(CATS) do
        local p = Items.cleanPiece(worn[cat])
        if not Items.isNaked(sex, cat, p.drawable) and math.random(100) <= (tonumber(chances[cat]) or 0) then
            local w = names[cat]
            local wp = w and (w.piece or (w.d and { drawable = w.d, texture = w.t }))
            local custom = wp and Items.same(Items.cleanPiece(wp), p) and w.label or nil
            local md = Items.metadata(sex, cat, p, custom)
            -- Un peu devant / à côté de la personne, au sol
            local a = math.rad(math.random(0, 359))
            local r = 0.5 + i * 0.25
            local id = inv():CreateDrop({ x = c.x + math.cos(a) * r, y = c.y + math.sin(a) * r, z = c.z - 0.95 },
                { { name = Config.Items.names[cat], count = 1, metadata = md } }, (K.props or {})[cat])
            if id then
                fell = fell + 1
                names[cat] = nil
                local n = Config.Naked[sex][cat] or { -1, 0 }
                TriggerClientEvent('elyzea_clothing:apply', src, cat, { drawable = n[1], texture = n[2] }, nil, true)
            end
        end
    end
    if fell > 0 then
        lastKnock[src] = now()
        Items.saveWornNames(src, names)
        notify(src, fell > 1 and 'Ton chapeau et tes lunettes sont tombés par terre.' or 'Un accessoire est tombé par terre.', 'inform')
    end
    return fell
end
Items.knock = knock

-- Pousser (menu ALT) : vérifié ici, puis la personne poussée tombe et renvoie ce qu'elle porte
RegisterNetEvent('elyzea_clothing:push', function(target)
    local src = source
    target = tonumber(target)
    if K.enabled == false or not target or target == src or not GetPlayerName(target) then return end
    if lastPush[src] and now() - lastPush[src] < (K.pushCooldown or 6000) then return notify(src, 'Doucement…') end
    local a, b = coords(src), coords(target)
    if not a or not b or #(a - b) > (K.pushDistance or 1.8) + 0.6 then return notify(src, 'Trop loin pour pousser.') end
    if inVehicle(src) or inVehicle(target) then return end
    lastPush[src] = now()
    TriggerClientEvent('elyzea_clothing:pushed', target, src)
    TriggerClientEvent('elyzea_clothing:pushDone', src, target)
end)

-- La personne poussée / frappée envoie ce qu'elle porte (comme pour retirer un vêtement soi-même)
RegisterNetEvent('elyzea_clothing:knock', function(reason, by, worn)
    local src = source
    reason = reason == 'push' and 'push' or 'hit'
    by = tonumber(by)
    if not by or by == src or not GetPlayerName(by) then return end
    if reason == 'push' then
        -- une poussée récente de ce joueur est obligatoire
        if not lastPush[by] or now() - lastPush[by] > 4000 then return end
    else
        if lastHit[src] and now() - lastHit[src] < 800 then return end
        lastHit[src] = now()
        local a, b = coords(src), coords(by)
        if not a or not b or #(a - b) > 4.0 then return end   -- corps à corps seulement
    end
    knock(src, reason, worn)
end)

-- Écraser des lunettes tombées au sol (G à côté)
RegisterNetEvent('elyzea_clothing:breakGround', function()
    local src = source
    if not on() then return end
    local ok, list = pcall(function() return inv():GetNearbyDropItems(src, GLASSES) end)
    if not ok or type(list) ~= 'table' then return end
    for _, e in ipairs(list) do
        if not (e.metadata and e.metadata.broken) then
            if inv():SetDropItemMetadata(e.drop, e.index, Items.breakMeta(e.metadata)) then
                TriggerClientEvent('elyzea_clothing:brokeGlasses', src)
                return notify(src, 'Lunettes écrasées.', 'success')
            end
        end
    end
    notify(src, 'Pas de lunettes intactes à tes pieds.')
end)

-- Casser des lunettes de son inventaire (clic droit › Casser)
RegisterNetEvent('elyzea_clothing:breakSlot', function(slot)
    local src = source
    if not on() then return end
    local item = inv():GetSlot(src, tonumber(slot) or -1)
    if not item or item.name ~= GLASSES then return end
    local md = item.metadata or {}
    if md.broken then return notify(src, 'Elles sont déjà cassées.') end
    inv():SetMetadata(src, item.slot, Items.breakMeta(md))
    TriggerClientEvent('elyzea_clothing:brokeGlasses', src)
    notify(src, 'Lunettes cassées.', 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastKnock[src], lastPush[src], lastHit[src] = nil, nil, nil
end)
