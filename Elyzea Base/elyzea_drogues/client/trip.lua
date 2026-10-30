-- =====================================================================
--  ELYZEA DROGUES · hallucinations des champignons (client)
--  Les créatures (singes, clowns, extraterrestres, Bigfoot…) sont des PNJ LOCAUX
--  (CreatePed non réseau) : seul le joueur défoncé les voit, les autres joueurs ne voient rien.
--  Elles courent vers lui et le « frappent » : il tombe (chute sans perte de vie).
--  Elles ne combattent jamais vraiment (aucune arme, aucune tâche de combat) : aucun dégât.
-- =====================================================================
local FX = DrugFx
local creatures = {}      -- { ped, kind, hitAt, dieAt }
local tripping = false

local function setting(k)
    local t = FX.settings and FX.settings.trip or {}
    return tonumber(t[k]) or Config.Trip[k]
end

local function enabledModels()
    local list = {}
    local on = FX.settings and FX.settings.creatures or {}
    for _, c in ipairs(Config.Trip.creatures) do
        if on[c.model] ~= false and IsModelInCdimage(GetHashKey(c.model)) then list[#list + 1] = c end
    end
    return list
end

local function poof(pos)
    local asset = 'scr_rcbarry2'
    RequestNamedPtfxAsset(asset)
    local t = GetGameTimer() + 1000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < t do Wait(0) end
    if HasNamedPtfxAssetLoaded(asset) then
        UseParticleFxAssetNextCall(asset)
        StartParticleFxNonLoopedAtCoord('scr_clown_appears', pos.x, pos.y, pos.z - 0.5, 0.0, 0.0, 0.0, 1.0, false, false, false)
    end
end

local function remove(c, withFx)
    if c.ped and DoesEntityExist(c.ped) then
        if withFx then poof(GetEntityCoords(c.ped)) end
        DeleteEntity(c.ped)
    end
    c.ped = nil
end

local function spawnOne()
    local list = enabledModels()
    if #list == 0 then return end
    local def = list[math.random(1, #list)]
    local hash = GetHashKey(def.model)
    RequestModel(hash)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(hash) then return end
    local me = PlayerPedId()
    local p = GetEntityCoords(me)
    -- quelque part autour du joueur, au sol
    local pos
    for _ = 1, 8 do
        local a = math.random() * math.pi * 2
        local d = math.random(10, 18) + 0.0
        local x, y = p.x + math.cos(a) * d, p.y + math.sin(a) * d
        local ok, gz = GetGroundZFor_3dCoord(x, y, p.z + 5.0, false)
        if ok and math.abs(gz - p.z) < 6.0 then pos = vector3(x, y, gz) break end
    end
    if not pos then SetModelAsNoLongerNeeded(hash) return end
    -- false, false : PNJ local, jamais envoyé aux autres joueurs
    local ped = CreatePed(def.kind == 'animal' and 28 or 4, hash, pos.x, pos.y, pos.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, false)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedKeepTask(ped, true)
    RemoveAllPedWeapons(ped, true)
    SetEntityNoCollisionEntity(ped, me, false)
    SetPedMoveRateOverride(ped, 1.15)
    poof(pos)
    TaskGoToEntity(ped, me, -1, 1.0, 3.0, 1073741824, 0)
    creatures[#creatures + 1] = { ped = ped, kind = def.kind, hitAt = 0, dieAt = GetGameTimer() + setting('lifetime') * 1000, chaseAt = GetGameTimer() + 2000 }
end

-- Coup porté par une créature : petite animation (humains), puis le joueur tombe sans se blesser
local HIT = { dict = 'melee@unarmed@streamed_variations', clip = 'plyr_takedown_front_slap' }
local function hit(c)
    local me = PlayerPedId()
    if c.kind == 'human' then
        if not HasAnimDictLoaded(HIT.dict) then RequestAnimDict(HIT.dict) end
        TaskTurnPedToFaceEntity(c.ped, me, 300)
        if HasAnimDictLoaded(HIT.dict) then TaskPlayAnim(c.ped, HIT.dict, HIT.clip, 8.0, -8.0, 900, 0, 0, false, false, false) end
        Wait(350)
    end
    PlayPain(me, 6, 0, 0)
    FX.Fall(setting('fallTime') * 1000)
    if c.ped and DoesEntityExist(c.ped) then
        SetTimeout(1200, function() if c.ped and DoesEntityExist(c.ped) then TaskGoToEntity(c.ped, PlayerPedId(), -1, 1.0, 3.0, 1073741824, 0) end end)
    end
end

function FX.TripStop()
    tripping = false
    for _, c in ipairs(creatures) do remove(c, true) end
    creatures = {}
end

function FX.TripStart()
    if tripping then return end
    tripping = true
    RequestAnimDict(HIT.dict)
    CreateThread(function()
        local nextSpawn = GetGameTimer() + 3000
        while tripping do
            local now = GetGameTimer()
            local e = FX.active.mushrooms
            if not e or e.endT <= now then break end
            local me = PlayerPedId()
            if IsEntityDead(me) then break end
            local myPos = GetEntityCoords(me)
            -- apparitions (pas dans un véhicule ni pendant les 10 dernières secondes)
            local alive = 0
            for _, c in ipairs(creatures) do if c.ped then alive = alive + 1 end end
            -- Force de la prise (ex. gros gâteau) : plus de créatures, qui arrivent plus vite
            local int = e.int or 1.0
            local maxC = math.max(1, math.floor(setting('maxCreatures') * int + 0.5))
            if now >= nextSpawn and alive < maxC and e.endT - now > 10000 and not IsPedInAnyVehicle(me, false) then
                nextSpawn = now + math.floor(setting('spawnEvery') * 1000 / int)
                spawnOne()
            end
            for i = #creatures, 1, -1 do
                local c = creatures[i]
                if not c.ped or not DoesEntityExist(c.ped) or now >= c.dieAt or e.endT - now < 3000 then
                    remove(c, true)
                    table.remove(creatures, i)
                else
                    SetEntityNoCollisionEntity(c.ped, me, false)
                    local d = #(GetEntityCoords(c.ped) - myPos)
                    if d > 60.0 then
                        remove(c, false) table.remove(creatures, i)
                    elseif d < 1.6 and now >= c.hitAt and not IsPedRagdoll(me) and not IsPedInAnyVehicle(me, false) then
                        c.hitAt = now + setting('hitCooldown') * 1000
                        hit(c)
                    elseif now >= c.chaseAt then
                        c.chaseAt = now + 2000
                        TaskGoToEntity(c.ped, me, -1, 1.0, 3.0, 1073741824, 0)
                    end
                end
            end
            Wait(100)
        end
        FX.TripStop()
    end)
end
