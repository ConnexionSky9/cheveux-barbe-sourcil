-- =====================================================================
--  ELYZEA LASERGAME - ATOUTS ET ARMES MURALES (client, mode Zombie)
--  * Machines d'atouts : modèle posé sur la carte + halo lumineux de la couleur de l'atout,
--    achat (touche d'interaction), animation de boisson, effet réel (vitesse, recharge…).
--  * Armes murales : arme exposée au mur (modèle GTA réel), prix, achat (touche d'interaction).
--  Les effets « serveur » (vie max, dégâts, acide, réanimation, régénération, protection)
--  sont appliqués par le serveur ; les effets « client » (vitesse, recharge) ici.
-- =====================================================================
C.Perks = { owned = {}, machines = {}, wallbuys = {}, props = {} }

local function hex2rgb(h)
    h = tostring(h or '#B57BFF'):gsub('#', '')
    return tonumber(h:sub(1, 2), 16) or 180, tonumber(h:sub(3, 4), 16) or 120, tonumber(h:sub(5, 6), 16) or 255
end

local function wallbuyInfo(wb)
    local o = ((C.public or {}).wallbuys or {})[wb.id] or {}
    local wid = (o.weapon and LGU.Weapon(o.weapon)) and o.weapon or wb.weapon
    return LGU.Weapon(wid), tonumber(o.price) or wb.price
end

function C.Perks.Init()
    C.Perks.Clear()
    for _, m in ipairs((Map.data and Map.data.perks) or {}) do
        local x, y, z = Map.World(m.x, m.y, m.z or 1.0)
        local def = LG.Zombie.perks[m.perk]
        if def then
            local r, g, b = hex2rgb(def.color)
            C.Perks.machines[#C.Perks.machines + 1] = { id = m.id, perk = m.perk, p = vector3(x, y, z), c = { r, g, b }, def = def }
        end
    end
    for _, wb in ipairs((Map.data and Map.data.wallbuys) or {}) do
        local x, y, z = Map.World(wb.x, wb.y, wb.z or 1.3)
        local w = wallbuyInfo(wb)
        local entry = { id = wb.id, p = vector3(x, y, z), def = wb, h = (Map.anchor.h or 0) + (wb.h or 0) }
        -- modèle de l'arme exposé au mur (objet local)
        if w then
            local hash = GetHashKey(w.model)
            RequestWeaponAsset(hash, 31, 0)
            local t = GetGameTimer() + 3000
            while not HasWeaponAssetLoaded(hash) and GetGameTimer() < t do Wait(0) end
            if HasWeaponAssetLoaded(hash) then
                local obj = CreateWeaponObject(hash, 0, x, y, z, true, 1.0, 0)
                if obj and obj ~= 0 then
                    SetEntityHeading(obj, entry.h + 90.0)
                    SetEntityCoordsNoOffset(obj, x, y, z, false, false, false)
                    FreezeEntityPosition(obj, true)
                    SetEntityCollision(obj, false, false)
                    C.Perks.props[#C.Perks.props + 1] = obj
                end
            end
        end
        C.Perks.wallbuys[#C.Perks.wallbuys + 1] = entry
    end
    -- halos lumineux et marqueurs (seulement à proximité)
    CreateThread(function()
        while C.inGame and C.mode == 'zombie' do
            local pos = GetEntityCoords(PlayerPedId())
            local near = false
            for _, m in ipairs(C.Perks.machines) do
                local d = #(pos - m.p)
                if d < 35.0 then
                    near = true
                    DrawLightWithRange(m.p.x, m.p.y, m.p.z + 1.2, m.c[1], m.c[2], m.c[3], 5.0, 3.0)
                    DrawMarker(1, m.p.x, m.p.y, m.p.z - 0.95, 0, 0, 0, 0, 0, 0, 1.4, 1.4, 0.15, m.c[1], m.c[2], m.c[3], 120, false, false, 2, false, nil, nil, false)
                end
            end
            for _, wb in ipairs(C.Perks.wallbuys) do
                if #(pos - wb.p) < 25.0 then
                    near = true
                    DrawLightWithRange(wb.p.x, wb.p.y, wb.p.z, 170, 90, 255, 2.5, 2.5)
                end
            end
            Wait(near and 0 or 500)
        end
    end)
end

function C.Perks.Clear()
    for _, o in ipairs(C.Perks.props) do if DoesEntityExist(o) then DeleteEntity(o) end end
    C.Perks.props, C.Perks.machines, C.Perks.wallbuys = {}, {}, {}
end

-- Effets côté client
local function applyEffects()
    local pid = PlayerId()
    local speed = C.Perks.owned.speed and (LG.Zombie.perks.speed.runMultiplier or 1.2) or 1.0
    SetRunSprintMultiplierForPlayer(pid, math.min(1.49, speed))
    SetPedMoveRateOverride(PlayerPedId(), speed)
    Weapons.reloadMult = C.Perks.owned.fastreload and (LG.Zombie.perks.fastreload.reloadMultiplier or 0.5) or 1.0
    Weapons.Hud()
end

function C.Perks.Reset()
    C.Perks.owned = {}
    applyEffects()
    C.UI('zbPerks', { perks = {} })
end

local function drinkAnimation()
    local ped = PlayerPedId()
    if not C.LoadDict('mp_player_intdrink') then return end
    local h = C.LoadModel('prop_ld_flow_bottle')
    local bottle
    if h then
        bottle = CreateObject(h, 0.0, 0.0, 0.0, false, false, false)
        AttachEntityToEntity(bottle, ped, GetPedBoneIndex(ped, 18905), 0.12, 0.008, 0.03, 240.0, -60.0, 0.0, true, true, false, true, 1, true)
    end
    TaskPlayAnim(ped, 'mp_player_intdrink', 'loop_bottle', 8.0, -8.0, 1800, 49, 0.0, false, false, false)
    SetTimeout(1900, function() if bottle and DoesEntityExist(bottle) then DeleteEntity(bottle) end end)
end

RegisterNetEvent('elyzea_lasergame:zbPerks', function(d)
    if not C.inGame then return end
    C.Perks.owned = {}
    for _, id in ipairs(d.perks or {}) do C.Perks.owned[id] = true end
    applyEffects()
    C.UI('zbPerks', d)
    if d.bought then
        drinkAnimation()
        C.Sound('perk', 1.0)
        if C.settings.effects then AnimpostfxPlay('SuccessNeutral', 800, false) end
    end
end)

-- Invites d'achat (atouts puis armes murales)
C.Interactions[#C.Interactions + 1] = function(pos)
    if not C.inGame or C.mode ~= 'zombie' or not C.alive then return nil end
    local best, bestD
    for _, m in ipairs(C.Perks.machines) do
        local d = #(pos - m.p)
        if d <= 2.2 and (not bestD or d < bestD) then best, bestD = m, d end
    end
    if best then
        local def = best.def
        local owned = C.Perks.owned[best.perk]
        return { dist = bestD, title = def.label, label = owned and 'Déjà possédé' or def.desc, price = not owned and def.price or nil,
            money = C.Zc.money >= def.price,
            action = function()
                if owned then return end
                local ok, err = RPC.Call('zb:perk', best.id)
                if not ok and err then C.Notify(err, 'error') C.Sound('deny', 0.8) end
            end }
    end
    for _, wb in ipairs(C.Perks.wallbuys) do
        local d = #(pos - wb.p)
        if d <= 2.2 and (not bestD or d < bestD) then best, bestD = wb, d end
    end
    if best then
        local w, p = wallbuyInfo(best.def)
        if not w then return nil end
        local owned = false
        for _, id in ipairs(Weapons.slots or {}) do if id == w.id then owned = true end end
        return { dist = bestD, title = w.label, label = owned and 'Déjà possédée' or 'Acheter l\'arme', price = not owned and p or nil,
            money = C.Zc.money >= p,
            action = function()
                if owned then return end
                local ok, err = RPC.Call('zb:wallbuy', best.id)
                if not ok and err then C.Notify(err, 'error') C.Sound('deny', 0.8) end
            end }
    end
end
