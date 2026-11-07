-- =====================================================================
--  BANK HEIST - client : décor de la banque (d'après l'état publié par le serveur)
--  · Porte du coffre : objet de la carte, maintenu fermé, puis ouverture lente (grincement) après le
--    décryptage ou soufflée par la C4 ; refermée à la fin du braquage.
--  · Butin : un objet par point choisi par le staff (chariot plein → vide, liasses / lingots qui
--    disparaissent, coffres individuels : pas d'objet, ceux de la carte). Créés seulement à < 60 m.
--  · C4 : objet sur la porte, bips de plus en plus rapides, explosion (sans dégâts), fumée, secousse.
--  Boucle légère : 1 s hors de la banque, 250 ms dedans, chaque image seulement pendant l'animation de la porte.
-- =====================================================================
local C = BHC
local doors = {}      -- [bankId] = { obj, base, orig, cur }
local props = {}      -- [bankId] = { [i] = { obj, model } }
local charges = {}    -- [bankId] = { obj, endsAt }

local function delete(o) if o and DoesEntityExist(o) then DeleteEntity(o) end end

local function clearProps(id)
    for _, p in pairs(props[id] or {}) do delete(p.obj) end
    props[id] = nil
end

-- Modèle à afficher pour un point de butin (plein / vide), avec repli si le modèle manque dans le jeu
local function lootModel(p, full)
    local cfg = C.Cfg()
    local t = (cfg.lootTypes or {})[p.type] or {}
    local m
    if full then m = (p.model ~= '' and p.model) or t.model else m = t.empty end
    if not m or m == '' then return nil end
    if not IsModelInCdimage(joaat(m)) then
        m = full and 'hei_prop_hei_cash_trolly_01' or (t.empty and 'hei_prop_hei_cash_trolly_03') or nil
    end
    return m
end

local function placeProp(model, p)
    local hash = C.LoadModel(model)
    if not hash then return nil end
    local o = CreateObjectNoOffset(hash, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if o == 0 then return nil end
    SetEntityHeading(o, (p.h or 0.0) + 0.0)
    if not PlaceObjectOnGroundProperly(o) then SetEntityCoordsNoOffset(o, p.x + 0.0, p.y + 0.0, p.z - 0.98, false, false, false) end
    FreezeEntityPosition(o, true)
    SetEntityInvincible(o, true)
    return o
end

-- Objets du butin selon l'état de chaque point
local function syncProps(b, st)
    local list = props[b.id] or {}
    props[b.id] = list
    for i, p in ipairs(b.loot or {}) do
        local ps = (st.points or {})[i]
        local full = st.phase ~= 'cooldown' and (not ps or ps.full)
        local want = lootModel(p, full)
        local cur = list[i]
        if not cur or cur.model ~= want or (cur.obj and not DoesEntityExist(cur.obj)) then
            if cur then delete(cur.obj) end
            list[i] = { model = want, obj = want and placeProp(want, p) or nil }
        end
    end
    for i, cur in pairs(list) do if not (b.loot or {})[i] then delete(cur.obj) list[i] = nil end end
end
function C.LootProp(bankId, i) local l = props[bankId] return l and l[i] and l[i].obj end

local function headingTowards(cur, target, step)
    local d = (target - cur + 540.0) % 360.0 - 180.0
    if math.abs(d) <= step then return target, true end
    return cur + (d > 0 and step or -step), false
end

CreateThread(function()
    local lastFrame = GetGameTimer()
    while true do
        local cfg = C.Cfg()
        local sleep = 1000
        local nowT = GetGameTimer()
        local dt = math.min(0.2, (nowT - lastFrame) / 1000)
        lastFrame = nowT
        if cfg then
            local pc = GetEntityCoords(PlayerPedId())
            for _, b in ipairs(cfg.banks) do
                local st = C.Bank(b.id)
                local near = #(pc - C.Vec(b.doorPoint)) < 60.0
                if near then sleep = math.min(sleep, 250) end
                -- porte du coffre
                if near and b.door and b.door.enabled then
                    local d = doors[b.id]
                    if not d or not DoesEntityExist(d.obj) then
                        local obj = 0
                        for _, m in ipairs({ b.door.model, 'v_ilev_gb_vauldr', 'v_ilev_bk_vaultdoor', 'hei_prop_heist_sec_door' }) do
                            if obj == 0 and m and m ~= '' then obj = GetClosestObjectOfType(b.door.x + 0.0, b.door.y + 0.0, b.door.z + 0.0, 6.0, joaat(m), false, false, false) end
                        end
                        if obj ~= 0 then
                            local closed = tonumber(b.door.closedHeading) or -1
                            d = { obj = obj, base = closed >= 0 and closed or GetEntityHeading(obj), orig = GetEntityHeading(obj) }
                            FreezeEntityPosition(obj, true)
                            doors[b.id] = d
                        end
                    end
                    if d and DoesEntityExist(d.obj) then
                        local open = st.phase == 'active' and st.door == 'open'
                        local target = open and (d.base + (b.door.openOffset or -90.0)) % 360.0 or d.base
                        local cur = GetEntityHeading(d.obj)
                        if math.abs(((target - cur + 540.0) % 360.0) - 180.0) > 0.2 then
                            -- vitesse : ouverture en « openTime » secondes (soufflée par la C4 : 4 fois plus vite)
                            local speed = math.abs(b.door.openOffset or 90.0) / math.max(0.5, (cfg.door.openTime or 5)) * (d.blown and 4.0 or 1.0)
                            if not d.moving then
                                d.moving = true
                                if open and not d.blown then PlaySoundFromCoord(-1, 'vault_unlock', b.door.x + 0.0, b.door.y + 0.0, b.door.z + 0.0, 'dlc_heist_fleeca_bank_door_sounds', false, 0, false) end
                            end
                            local h = headingTowards(cur, target, speed * dt)
                            SetEntityHeading(d.obj, h)
                            sleep = 0
                        elseif d.moving then
                            d.moving, d.blown = false, open and d.blown or false
                        end
                    end
                end
                -- butin
                if near and #(b.loot or {}) > 0 then syncProps(b, st)
                elseif props[b.id] then clearProps(b.id) end
                -- charge C4 posée
                if near and st.phase == 'active' and st.door == 'c4' then
                    local c = charges[b.id]
                    if not c or not DoesEntityExist(c.obj) then
                        local hash = C.LoadModel(cfg.c4.prop)
                        if hash then
                            local p = b.doorPoint
                            local h = math.rad((p.h or 0.0) + 0.0)
                            local x, y = p.x - math.sin(h) * 0.55, p.y + math.cos(h) * 0.55
                            local o = CreateObjectNoOffset(hash, x, y, p.z + 0.15, false, false, false)
                            SetEntityHeading(o, (p.h or 0.0) + 0.0)
                            FreezeEntityPosition(o, true)
                            SetModelAsNoLongerNeeded(hash)
                            charges[b.id] = { obj = o, endsAt = c and c.endsAt or (GetGameTimer() + (cfg.c4.delay or 10) * 1000) }
                        end
                    end
                elseif charges[b.id] then
                    delete(charges[b.id].obj)
                    charges[b.id] = nil
                end
            end
        end
        Wait(sleep)
    end
end)

-- Bips de la C4 : de plus en plus rapides jusqu'à l'explosion
CreateThread(function()
    while true do
        local wait = 1000
        for _, c in pairs(charges) do
            if DoesEntityExist(c.obj) then
                local left = c.endsAt - GetGameTimer()
                PlaySoundFromEntity(-1, 'Beep_Red', c.obj, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false, 0)
                wait = math.min(wait, left > 5000 and 1000 or (left > 2000 and 450 or 180))
            end
        end
        Wait(wait)
    end
end)

-- Explosion de la porte : effet, son, fumée, secousse (aucun dégât)
RegisterNetEvent('bh:client:explode', function(e)
    if type(e) ~= 'table' then return end
    local pos = vector3(e.x + 0.0, e.y + 0.0, e.z + 0.0)
    local dist = #(GetEntityCoords(PlayerPedId()) - pos)
    if dist > 150.0 then return end
    local d = doors[e.bank]
    if d then d.blown = true end
    AddExplosion(pos.x, pos.y, pos.z, tonumber(e.type) or 2, 0.0, true, false, 1.0)
    RequestNamedPtfxAsset('core')
    local t = GetGameTimer() + 1500
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < t do Wait(0) end
    if HasNamedPtfxAssetLoaded('core') then
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord('exp_grd_grenade_smoke', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 1.6, false, false, false)
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord('ent_sht_electrical_box', pos.x, pos.y, pos.z + 0.6, 0.0, 0.0, 0.0, 1.4, false, false, false)
    end
    local shake = ((C.Cfg() or {}).c4 or {}).shake or 0.6
    if shake > 0 and dist < 40.0 then ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', shake * (1.0 - dist / 40.0) + 0.1) end
    if dist < 25.0 then C.Sfx('boom', 1.0 - dist / 30.0) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(props) do clearProps(id) end
    for _, c in pairs(charges) do delete(c.obj) end
    for _, d in pairs(doors) do if DoesEntityExist(d.obj) then SetEntityHeading(d.obj, d.orig or d.base) end end
end)
