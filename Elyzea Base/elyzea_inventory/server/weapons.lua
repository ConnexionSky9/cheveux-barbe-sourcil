--[[
    ELYZEA FA — Inventaire : armes
    - Utiliser une arme (clic droit, double-clic, touches 1 à 5) la sort ou la range.
    - Les munitions sont stockées dans l'arme (metadata.ammo) et rechargées depuis
      l'inventaire (utiliser une boîte de munitions ou touche R quand l'arme est vide).
    - Si l'arme quitte l'inventaire (dépôt, coffre, fouille…), elle est retirée des mains.
]]

local Equipped = {}   -- [src] = { slot, name, serial }

local function serialOf(it) return it and it.metadata and it.metadata.serial end

local function disarm(src)
    Equipped[src] = nil
    TriggerClientEvent('elyzea_inv:weapon:disarm', src)
end

-- Appelée après chaque synchronisation : l'arme en main est-elle toujours là ?
function CheckEquippedWeapon(src)
    local e = Equipped[src]
    if not e then return end
    local inv = Inv[src]
    local it = inv and inv.slots[e.slot]
    if it and it.name == e.name and serialOf(it) == e.serial then return end
    -- L'arme a peut-être changé d'emplacement
    if inv then
        for i = 1, inv.size do
            local x = inv.slots[i]
            if x and x.name == e.name and serialOf(x) == e.serial and e.serial ~= nil then
                e.slot = i
                TriggerClientEvent('elyzea_inv:weapon:slot', src, i)
                return
            end
        end
    end
    disarm(src)
end

function MovedWeaponSlot(src, from, to)
    local e = Equipped[src]
    if not e then return end
    if e.slot == from then e.slot = to elseif e.slot == to then e.slot = from end
    TriggerClientEvent('elyzea_inv:weapon:slot', src, e.slot)
end

function UseWeapon(src, slot, item, def)
    local e = Equipped[src]
    if e and e.slot == slot then
        TriggerClientEvent('elyzea_inv:weapon:holster', src)
        Equipped[src] = nil
        return true
    end
    local meta = item.metadata or {}
    if def.throwable then
        Equipped[src] = { slot = slot, name = item.name, throwable = true }
        TriggerClientEvent('elyzea_inv:weapon:equip', src, { slot = slot, name = item.name, ammo = 1, throwable = true, label = def.label })
        return true
    end
    Equipped[src] = { slot = slot, name = item.name, serial = meta.serial }
    TriggerClientEvent('elyzea_inv:weapon:equip', src, {
        slot = slot, name = item.name, label = def.label, ammo = tonumber(meta.ammo) or 0,
        ammoname = def.ammoname, components = meta.components, tint = meta.tint,
    })
    return true
end

-- Le client signale les munitions restantes (tir, rangement)
RegisterNetEvent('elyzea_inv:weapon:ammo', function(slot, ammo)
    local src = source
    local e = Equipped[src]
    slot, ammo = tonumber(slot), math.floor(tonumber(ammo) or -1)
    if not e or e.slot ~= slot or ammo < 0 then return end
    local inv = Inv[src]
    local it = inv and inv.slots[slot]
    if not it or it.name ~= e.name then return end
    if e.throwable then
        if ammo == 0 then
            RemoveItemFrom(inv, it.name, 1, nil, slot)
            Equipped[src] = nil
            Sync(src)
        end
        return
    end
    it.metadata = it.metadata or {}
    local cur = tonumber(it.metadata.ammo) or 0
    if ammo < cur then        -- les munitions ne peuvent que diminuer côté client
        it.metadata.ammo = ammo
        inv.dirty = true
    end
end)

-- Recharge l'arme en main avec les munitions de l'inventaire
local function reload(src, preferSlot)
    local e = Equipped[src]
    local inv = Inv[src]
    if not e or not inv or e.throwable then return false, 'no_weapon' end
    local w = inv.slots[e.slot]
    local def = w and Items[w.name]
    if not def or not def.ammoname then return false, 'no_weapon' end
    w.metadata = w.metadata or {}
    local cur = tonumber(w.metadata.ammo) or 0
    local need = Config.Weapons.maxLoadedAmmo - cur
    if need <= 0 then return false end
    local available = 0
    for i = 1, inv.size do
        local it = inv.slots[i]
        if it and it.name == def.ammoname then available = available + it.count end
    end
    if available <= 0 then return false, 'no_ammo' end
    local load = math.min(need, available)
    RemoveItemFrom(inv, def.ammoname, load, nil, preferSlot and inv.slots[preferSlot] and inv.slots[preferSlot].count >= load and preferSlot or nil)
    w.metadata.ammo = cur + load
    inv.dirty = true
    TriggerClientEvent('elyzea_inv:weapon:reloaded', src, e.slot, w.metadata.ammo)
    Sync(src)
    return true
end

RegisterNetEvent('elyzea_inv:weapon:reload', function()
    local src = source
    local ok, err = reload(src)
    if not ok and err then Sync(src, { type = 'error', text = Config.Messages[err] or err }) end
end)

function UseAmmo(src, slot, item, def)
    local e = Equipped[src]
    if not e then return false, 'no_weapon' end
    local w = Inv[src].slots[e.slot]
    local wd = w and Items[w.name]
    if not wd or wd.ammoname ~= item.name then return false, 'no_weapon' end
    return reload(src, slot)
end

RegisterNetEvent('elyzea_inv:weapon:cleared', function() Equipped[source] = nil end)
AddEventHandler('playerDropped', function() Equipped[source] = nil end)
AddEventHandler('elyzea:server:playerUnloaded', function(src) Equipped[tonumber(src) or -1] = nil end)

exports('GetCurrentWeapon', function(src)
    local e = Equipped[tonumber(src) or -1]
    if not e then return nil end
    local it = Inv[src] and Inv[src].slots[e.slot]
    return it and { name = it.name, slot = e.slot, metadata = it.metadata } or nil
end)
exports('Disarm', function(src) disarm(tonumber(src)) end)
