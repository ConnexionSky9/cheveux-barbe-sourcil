-- ELYZEA FA — Inventaire : consommation (nourriture, boissons…) et armes (client)

local ANIMS = {
    eating   = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger_fp' },
    drinking = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
}
local PROPS = {
    burger = { model = `prop_cs_burger_01`, pos = vec3(0.02, 0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) },
}

local function notify(text, kind)
    if GetResourceState('elyzea_core') == 'started' then exports.elyzea_core:Notify(text, kind or 'inform') end
end

local busy = false
RegisterNetEvent('elyzea_inv:consume', function(d)
    if busy then return TriggerServerEvent('elyzea_inv:consumed', d.token, false) end
    busy = true
    pcall(function() exports.elyzea_inventory:closeInventory() end)
    local anim = type(d.anim) == 'string' and ANIMS[d.anim] or d.anim
    local prop = type(d.prop) == 'string' and PROPS[d.prop] or d.prop
    if anim and anim.clip and not anim.flag then anim.flag = 49 end
    local ok = exports.elyzea_core:ProgressBar({
        duration = d.usetime or 2500,
        label = ('Utilisation : %s'):format(d.label or d.name),
        canCancel = d.cancel ~= false,
        disable = d.disable or { car = false, combat = true },
        anim = anim,
        prop = prop,
    })
    TriggerServerEvent('elyzea_inv:consumed', d.token, ok == true)
    busy = false
    if ok and d.notification then notify(d.notification, 'success') end
    if ok and d.export then
        local res, fn = tostring(d.export):match('^([^.]+)%.(.+)$')
        if res and GetResourceState(res) == 'started' then
            pcall(function() exports[res][fn](exports[res], { name = d.name, label = d.label }, { slot = d.slot, name = d.name }) end)
        end
    end
end)

-- ───────── Armes ─────────

local current = nil   -- { slot, name, hash, throwable }

local function reportAmmo()
    if not current or current.throwable then return end
    local ped = PlayerPedId()
    local ammo = GetAmmoInPedWeapon(ped, current.hash)
    TriggerServerEvent('elyzea_inv:weapon:ammo', current.slot, ammo)
end

local function holsterAnim()
    if not Config.Weapons.holsterAnim or IsPedInAnyVehicle(PlayerPedId(), false) then return end
    local dict = 'reaction@intimidation@1h'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 1000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(PlayerPedId(), dict, 'intro', 8.0, 2.0, 900, 48, 0, false, false, false)
        Wait(700)
    end
end

local function removeCurrent()
    if not current then return end
    local ped = PlayerPedId()
    SetPedAmmo(ped, current.hash, 0)
    RemoveWeaponFromPed(ped, current.hash)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    current = nil
end

RegisterNetEvent('elyzea_inv:weapon:equip', function(d)
    if current then reportAmmo() removeCurrent() end
    local ped = PlayerPedId()
    local hash = joaat(d.name)
    pcall(function() exports.elyzea_inventory:closeInventory() end)
    holsterAnim()
    GiveWeaponToPed(ped, hash, 0, false, true)
    SetPedAmmo(ped, hash, math.floor(tonumber(d.ammo) or 0))
    if d.tint then SetPedWeaponTintIndex(ped, hash, d.tint) end
    for _, comp in ipairs(type(d.components) == 'table' and d.components or {}) do
        pcall(function() GiveWeaponComponentToPed(ped, hash, joaat(comp)) end)
    end
    SetCurrentPedWeapon(ped, hash, true)
    current = { slot = d.slot, name = d.name, hash = hash, throwable = d.throwable }
end)

RegisterNetEvent('elyzea_inv:weapon:holster', function()
    if not current then return end
    reportAmmo()
    holsterAnim()
    removeCurrent()
end)

RegisterNetEvent('elyzea_inv:weapon:disarm', function()
    removeCurrent()
    RemoveAllPedWeapons(PlayerPedId(), true)
end)

RegisterNetEvent('elyzea_inv:weapon:slot', function(slot)
    if current then current.slot = slot end
end)

RegisterNetEvent('elyzea_inv:weapon:reloaded', function(slot, ammo)
    if not current or current.slot ~= slot then return end
    local ped = PlayerPedId()
    SetPedAmmo(ped, current.hash, math.floor(tonumber(ammo) or 0))
    MakePedReload(ped)
end)

exports('getCurrentWeapon', function() return current end)

-- Range l'arme en main (utilisé par d'autres ressources : essai d'arme, prison…)
exports('disarm', function()
    if current then reportAmmo() end
    removeCurrent()
    TriggerServerEvent('elyzea_inv:weapon:cleared')
end)

-- Suivi des munitions et rechargement
CreateThread(function()
    local lastAmmo, lastReport = -1, 0
    while true do
        if current then
            local ped = PlayerPedId()
            if GetSelectedPedWeapon(ped) ~= current.hash then
                -- L'arme a été changée par la roue des armes : on remet celle de l'inventaire
                if HasPedGotWeapon(ped, current.hash, false) then
                    SetCurrentPedWeapon(ped, current.hash, true)
                else
                    reportAmmo()
                    current = nil
                end
            else
                local ammo = GetAmmoInPedWeapon(ped, current.hash)
                if current.throwable then
                    if ammo == 0 then
                        TriggerServerEvent('elyzea_inv:weapon:ammo', current.slot, 0)
                        current = nil
                    end
                elseif ammo ~= lastAmmo then
                    lastAmmo = ammo
                    if GetGameTimer() - lastReport > 1500 or ammo == 0 then
                        lastReport = GetGameTimer()
                        TriggerServerEvent('elyzea_inv:weapon:ammo', current.slot, ammo)
                    end
                end
            end
            Wait(250)
        else
            lastAmmo = -1
            Wait(750)
        end
    end
end)

-- Touche R avec une arme vide : recharge depuis l'inventaire
RegisterCommand('elyzea_reload', function()
    if not current or current.throwable then return end
    local ped = PlayerPedId()
    local total = GetAmmoInPedWeapon(ped, current.hash)
    local _, clip = GetAmmoInClip(ped, current.hash)
    if total - (clip or 0) <= 0 then TriggerServerEvent('elyzea_inv:weapon:reload') end
end, false)
RegisterKeyMapping('elyzea_reload', 'Recharger l\'arme depuis l\'inventaire', 'keyboard', 'R')

-- Pas d'armes sans l'inventaire : TAB et la roue des armes ne donnent rien d'autre
CreateThread(function()
    while true do
        Wait(0)
        if current or IsPedArmed(PlayerPedId(), 6) then
            DisableControlAction(0, 37, true)   -- roue des armes
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then removeCurrent() end
end)
