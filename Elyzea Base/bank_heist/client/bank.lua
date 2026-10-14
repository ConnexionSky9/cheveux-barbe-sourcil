-- =====================================================================
--  BANK HEIST - client : décor de la banque (synchronisé par l'état publié par le serveur)
--  · Porte du coffre : objet de la carte, maintenu FERMÉ (closedHeading) et figé ; tourné de « openOffset »
--    degrés quand le coffre est ouvert (piratage réussi ou C4), refermé à la fin du braquage.
--  · Chariots de billets (objets locaux) toujours visibles dans le coffre : pleins, puis vides une fois pris.
--  · Charge C4 posée : objet + bips jusqu'à l'explosion. L'explosion (sans dégâts) est créée par un
--    seul client choisi par le serveur et synchronisée pour tous par le jeu.
-- =====================================================================
local C = BHC
local doors = {}      -- [bankId] = { obj, base }
local trolleys = {}   -- [bankId] = { objets..., full = bool }
local charges = {}    -- [bankId] = objet

local function clearTrolleys(id)
    for _, o in ipairs(trolleys[id] or {}) do if DoesEntityExist(o) then DeleteEntity(o) end end
    trolleys[id] = nil
end

local function spawnTrolleys(id, def, full)
    clearTrolleys(id)
    local cfg = C.Cfg()
    local hash = C.LoadModel(full and cfg.visuals.trolleyFull or cfg.visuals.trolleyEmpty)
    if not hash then return end
    local list = { full = full }
    for _, p in ipairs(def.cash or {}) do
        -- créé à hauteur de la personne qui a placé le point, puis posé au sol (jamais sous le sol)
        local o = CreateObject(hash, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false)
        SetEntityHeading(o, (p.h or 0.0) + 0.0)
        if not PlaceObjectOnGroundProperly(o) then SetEntityCoords(o, p.x + 0.0, p.y + 0.0, p.z - 0.98, false, false, false, false) end
        SetEntityCollision(o, true, true)
        FreezeEntityPosition(o, true)
        list[#list + 1] = o
    end
    SetModelAsNoLongerNeeded(hash)
    trolleys[id] = list
end

local function headingTo(cur, target)
    local d = (target - cur + 540.0) % 360.0 - 180.0
    if math.abs(d) < 1.0 then return target end
    return cur + d * 0.15
end

CreateThread(function()
    while true do
        local cfg = C.Cfg()
        local sleep = 1000
        if cfg then
            local pc = GetEntityCoords(PlayerPedId())
            for _, b in ipairs(cfg.banks) do
                local st = C.Bank(b.id)
                local near = #(pc - C.Vec(b.vault)) < 70.0
                -- porte
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
                        -- Porte reliée au système de clés (éditeur › Portes) : hors braquage, ce sont les
                        -- détenteurs des clés qui la verrouillent ; on ne fait que la refermer après un vol.
                        local managed = st.doorLinked and not st.open and not d.animated
                        if not managed then
                            local target = st.open and (d.base + (b.door.openOffset or -90.0)) % 360.0 or d.base
                            local cur = GetEntityHeading(d.obj)
                            if st.open then d.animated = true end
                            if math.abs(((target - cur + 540.0) % 360.0) - 180.0) > 0.5 then
                                FreezeEntityPosition(d.obj, true)
                                SetEntityHeading(d.obj, headingTo(cur, target))
                                sleep = 30
                            elseif not st.open and d.animated then
                                d.animated = false   -- refermée : le système de clés reprend la main
                                if st.doorLinked then FreezeEntityPosition(d.obj, false) end
                            end
                        end
                    end
                end
                -- chariots de billets : toujours visibles dans le coffre. Pleins tant que la banque n'a pas été
                -- vidée ; vides quand les billets ont été pris et pendant le délai de surveillance.
                if near and #(b.cash or {}) > 0 then
                    local full = not (st.phase == 'cooldown' or (st.open and not st.cashLeft))
                    local t = trolleys[b.id]
                    if not t or t.full ~= full or (t[1] and not DoesEntityExist(t[1])) then spawnTrolleys(b.id, b, full) end
                elseif trolleys[b.id] then clearTrolleys(b.id) end
                -- charge C4
                if near and st.phase == 'c4' then
                    if not charges[b.id] or not DoesEntityExist(charges[b.id]) then
                        local hash = C.LoadModel(cfg.c4.prop)
                        if hash then
                            local o = CreateObject(hash, b.vault.x + 0.0, b.vault.y + 0.0, b.vault.z + 0.1, false, false, false)
                            SetEntityHeading(o, (b.vault.h or 0.0) + 0.0)
                            FreezeEntityPosition(o, true)
                            charges[b.id] = o
                            SetModelAsNoLongerNeeded(hash)
                        end
                    end
                elseif charges[b.id] then
                    if DoesEntityExist(charges[b.id]) then DeleteEntity(charges[b.id]) end
                    charges[b.id] = nil
                end
            end
        end
        Wait(sleep)
    end
end)

-- Bips de la charge (une fois par seconde)
CreateThread(function()
    while true do
        local any = false
        for _, o in pairs(charges) do
            if DoesEntityExist(o) then any = true PlaySoundFromEntity(-1, 'Beep_Red', o, 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false, 0) end
        end
        Wait(any and 1000 or 1500)
    end
end)

RegisterNetEvent('bh:client:explode', function(e)
    if type(e) ~= 'table' then return end
    -- damageScale 0 : effet et son seulement, aucune destruction ni blessure
    AddExplosion(e.x + 0.0, e.y + 0.0, e.z + 0.0, tonumber(e.type) or 2, 0.0, true, false, 1.0)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(trolleys) do clearTrolleys(id) end
    for _, o in pairs(charges) do if DoesEntityExist(o) then DeleteEntity(o) end end
    for _, d in pairs(doors) do if DoesEntityExist(d.obj) then SetEntityHeading(d.obj, d.orig or d.base) end end
end)
