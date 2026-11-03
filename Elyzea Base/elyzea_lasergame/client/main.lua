-- =====================================================================
--  ELYZEA LASERGAME - CLIENT : état, utilitaires, adaptateur de framework, réglages publics
-- =====================================================================
C = {
    inGame = false,     -- dans une partie lancée (instance)
    uid = nil, mode = nil, role = nil, team = nil,
    alive = false,      -- PVP : vivant dans la manche · Zombie : debout (ni à terre ni mort)
    uiOpen = false,
    settings = { volume = 0.7, effects = true, hudScale = 1.0 },
    serverId = GetPlayerServerId(PlayerId()),
}

-- ---------------------------------------------------------------- NUI
function C.UI(action, data)
    SendNUIMessage({ action = action, data = data })
end

function C.Notify(msg, kind)
    C.UI('toast', { text = tostring(msg), kind = kind or 'info' })
end
RegisterNetEvent('elyzea_lasergame:notify', function(msg, kind) C.Notify(msg, kind) end)

-- Son joué par l'interface (fichiers html/sounds/*.ogg), volume selon la distance si pos est donnée
function C.Sound(name, volume, pos)
    local v = (volume or 1.0) * (C.settings.volume or 0.7)
    if pos then
        local d = #(GetEntityCoords(PlayerPedId()) - vector3(pos.x, pos.y, pos.z))
        if d > 70.0 then return end
        v = v * math.max(0.05, 1.0 - d / 70.0)
    end
    if v <= 0.01 then return end
    C.UI('sound', { name = name, volume = v })
end

-- ---------------------------------------------------------------- chargement
function C.LoadModel(model, timeout)
    local h = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(h) do
        if GetGameTimer() > t then return nil end
        Wait(0)
    end
    return h
end

function C.LoadDict(dict, timeout)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + (timeout or 3000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(0)
    end
    return true
end

function C.LoadPtfx(asset)
    RequestNamedPtfxAsset(asset)
    local t = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(asset) do
        if GetGameTimer() > t then return false end
        Wait(0)
    end
    return true
end

function C.Fade(out, ms)
    if out then DoScreenFadeOut(ms or 300) else DoScreenFadeIn(ms or 400) end
    local t = GetGameTimer() + 2000
    while (out and not IsScreenFadedOut()) or (not out and not IsScreenFadedIn()) do
        if GetGameTimer() > t then break end
        Wait(10)
    end
end

-- Hauteur du sol à (x, y) près de la hauteur attendue z (nil si introuvable)
function C.GroundZ(x, y, z)
    for _, off in ipairs({ 3.0, 15.0, 40.0 }) do
        local ok, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + off, false)
        if ok and math.abs(gz - z) < off + 5.0 then return gz end
    end
    return nil
end

-- Place le joueur sur un point (le sol est recherché autour de la hauteur prévue)
function C.PlaceAt(p, h)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(p.x, p.y, p.z)
    SetEntityCoordsNoOffset(ped, p.x, p.y, p.z + 1.0, false, false, false)
    if h then SetEntityHeading(ped, h + 0.0) end
    local t = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(0) end
    local gz = C.GroundZ(p.x, p.y, p.z + 1.0)
    if gz then SetEntityCoordsNoOffset(ped, p.x, p.y, gz + 0.05, false, false, false) end
end

function C.Resurrect(p, h)
    local ped = PlayerPedId()
    local c = p or GetEntityCoords(ped)
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, h or GetEntityHeading(ped), true, false)
        ped = PlayerPedId()
    end
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    return ped
end

-- Fantôme : invisible, sans collision, invulnérable (spectateur, éliminé)
function C.SetGhost(on)
    local ped = PlayerPedId()
    SetEntityVisible(ped, not on, false)
    SetEntityCollision(ped, not on, not on)
    FreezeEntityPosition(ped, on)
    SetEntityInvincible(ped, true)
    if NetworkSetEntityInvisibleToNetwork then NetworkSetEntityInvisibleToNetwork(ped, on) end
    if on then SetEntityAlpha(ped, 0, false) else ResetEntityAlpha(ped) end
end

-- ---------------------------------------------------------------- apparence (vêtements) : sauvegarde / restauration
function C.CaptureLook()
    local ped = PlayerPedId()
    local look = { model = GetEntityModel(ped), comps = {}, props = {} }
    for i = 0, 11 do look.comps[tostring(i)] = { GetPedDrawableVariation(ped, i), GetPedTextureVariation(ped, i), GetPedPaletteVariation(ped, i) } end
    for _, i in ipairs({ 0, 1, 2, 6, 7 }) do look.props[tostring(i)] = { GetPedPropIndex(ped, i), GetPedPropTextureIndex(ped, i) } end
    return look
end

function C.SendLook()
    if C.inGame then return end   -- l'apparence RP d'origine ne doit jamais être remplacée par la tenue LaserGame
    TriggerServerEvent('elyzea_lasergame:look', C.CaptureLook())
end

function C.ApplyLook(look)
    if type(look) ~= 'table' then return end
    local ped = PlayerPedId()
    if look.model and GetEntityModel(ped) ~= look.model then return end   -- jamais de changement de modèle ici
    for i = 0, 11 do
        local c = look.comps and look.comps[tostring(i)]
        if c then SetPedComponentVariation(ped, i, c[1], c[2], c[3] or 0) end
    end
    for _, i in ipairs({ 0, 1, 2, 6, 7 }) do
        local p = look.props and look.props[tostring(i)]
        if p then
            if p[1] == -1 then ClearPedProp(ped, i) else SetPedPropIndex(ped, i, p[1], p[2], true) end
        end
    end
end

-- Tenue LaserGame (gilet coloré par équipe)
function C.ApplyOutfit(team)
    if not Config.Outfits.enabled then return end
    local ped = PlayerPedId()
    local female = GetEntityModel(ped) == GetHashKey('mp_f_freemode_01')
    local set = (female and Config.Outfits.female or Config.Outfits.male)[team or 'Z']
    if not set then return end
    for comp, v in pairs(set) do SetPedComponentVariation(ped, comp, v[1], v[2], 0) end
end

-- ---------------------------------------------------------------- adaptateur de framework (client)
local function started(res) return GetResourceState(res) == 'started' end

-- Avant d'entrer : inventaire RP fermé, arme RP en main rangée (l'inventaire n'est JAMAIS modifié)
function C.PrepareEnter()
    local ped = PlayerPedId()
    if started('elyzea_inventory') then
        pcall(function() exports.elyzea_inventory:closeInventory() end)
        pcall(function() exports.elyzea_inventory:disarm() end)
    end
    if started('ox_inventory') then pcall(function() TriggerEvent('ox_inventory:disarm', true) end) end
    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) Wait(1200) end
    C.rpWeapons = {}
    -- ESX : les armes RP sont des armes GTA (loadout) → mémorisées pour être rendues à l'identique
    if started('es_extended') then
        for _, w in ipairs(LG.RpWeaponHashes or {}) do
            if HasPedGotWeapon(ped, w, false) then C.rpWeapons[#C.rpWeapons + 1] = { hash = w, ammo = GetAmmoInPedWeapon(ped, w) } end
        end
    end
    RemoveAllPedWeapons(ped, true)
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
end

-- Après la sortie : armes LaserGame retirées, armes RP rendues selon le framework
function C.RestoreWeapons()
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    if started('es_extended') then
        -- ESX remet lui-même le loadout du joueur (source de vérité côté serveur)
        TriggerEvent('esx:restoreLoadout')
        for _, w in ipairs(C.rpWeapons or {}) do
            if not HasPedGotWeapon(ped, w.hash, false) then GiveWeaponToPed(ped, w.hash, w.ammo or 0, false, false) end
        end
    end
    -- elyzea_inventory / qb-inventory / ox_inventory : les armes sont des objets d'inventaire, le joueur
    -- les ressort normalement (rien n'a été retiré de l'inventaire)
    C.rpWeapons = nil
end

-- ---------------------------------------------------------------- réglages publics (staff) : armes, cartes, PNJ
LG.RpWeaponHashes = {}
for _, name in ipairs({ 'WEAPON_PISTOL', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL', 'WEAPON_PISTOL50', 'WEAPON_HEAVYPISTOL', 'WEAPON_REVOLVER',
    'WEAPON_SNSPISTOL', 'WEAPON_VINTAGEPISTOL', 'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_ASSAULTSMG', 'WEAPON_MINISMG', 'WEAPON_ASSAULTRIFLE',
    'WEAPON_CARBINERIFLE', 'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE', 'WEAPON_BULLPUPRIFLE', 'WEAPON_COMPACTRIFLE', 'WEAPON_PUMPSHOTGUN',
    'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_MARKSMANRIFLE', 'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_KNIFE',
    'WEAPON_BAT', 'WEAPON_MACHETE', 'WEAPON_NIGHTSTICK', 'WEAPON_FLASHLIGHT', 'WEAPON_STUNGUN', 'WEAPON_KNUCKLE', 'WEAPON_SWITCHBLADE' }) do
    LG.RpWeaponHashes[#LG.RpWeaponHashes + 1] = GetHashKey(name)
end

local baseWeapons = LGU.Copy(LG.Weapons)
function C.ApplyPublic(pub)
    if type(pub) ~= 'table' then return end
    C.public = pub
    for i, w in ipairs(baseWeapons) do
        local nw = LGU.Copy(w)
        for k, v in pairs((pub.weapons or {})[w.id] or {}) do nw[k] = v end
        LG.Weapons[i] = nw
    end
    LGU.ResetWeaponIndex()
    for id, p in pairs(pub.perks or {}) do
        if LG.Zombie.perks[id] then LG.Zombie.perks[id].price = p.price LG.Zombie.perks[id].disabled = p.disabled end
    end
    if C.OnPublicChanged then C.OnPublicChanged(pub) end
end

AddStateBagChangeHandler('lgPublic', 'global', function(_, _, value) C.ApplyPublic(value) end)
CreateThread(function()
    while not GlobalState.lgPublic do Wait(500) end
    C.ApplyPublic(GlobalState.lgPublic)
end)

-- ---------------------------------------------------------------- utilitaires vectoriels
function C.RotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

function C.TeamColor(team)
    local t = Config.Teams[team or '']
    if t then return t.color[1], t.color[2], t.color[3] end
    return 170, 90, 255   -- violet ElyzeaFA (Zombie / neutre)
end

-- ---------------------------------------------------------------- nettoyage
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if C.inGame then
        DoScreenFadeIn(0)
        C.SetGhost(false)
        SetEntityInvincible(PlayerPedId(), false)
        FreezeEntityPosition(PlayerPedId(), false)
    end
end)
