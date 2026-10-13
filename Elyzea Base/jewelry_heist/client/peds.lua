-- =====================================================================
--  JEWELRY HEIST - client : PNJ bijoutiers et racheteurs
--  PNJ locaux (créés par chaque joueur proche) : invincibles, figés, insensibles aux événements.
--  Le bijoutier joue les animations du braquage selon l'étape publiée par le serveur
--  (GlobalState.jhHeists) : panique -> remplissage (sac en main) -> remise.
-- =====================================================================
local C = JHC
local peds = {}      -- [clé 'shop:id' / 'buyer:id'] = { ped, kind, id, def, stage, handBag }
local blips = {}
C.PedByEntity = {}   -- [entité] = { kind, id }

local function key(kind, id) return kind .. ':' .. id end

local function removePed(k)
    local e = peds[k]
    if not e then return end
    if e.handBag and DoesEntityExist(e.handBag) then DeleteEntity(e.handBag) end
    if DoesEntityExist(e.ped) then C.PedByEntity[e.ped] = nil DeleteEntity(e.ped) end
    peds[k] = nil
end

local function spawnPed(kind, def)
    local hash = C.LoadModel(def.ped.model) or C.LoadModel('s_f_m_shop_high')
    if not hash then return nil end
    local ped = CreatePed(4, hash, def.ped.x + 0.0, def.ped.y + 0.0, def.ped.z - 1.0, def.ped.h + 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return nil end
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, def.ped.h + 0.0)
    if kind == 'buyer' then TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SMOKING', 0, true) end
    C.PedByEntity[ped] = { kind = kind, id = def.id }
    return ped
end

local function list()
    local cfg = C.Cfg()
    local out = {}
    if not cfg or not cfg.general.enabled then return out end
    for _, s in ipairs(cfg.shops or {}) do if s.enabled then out[key('shop', s.id)] = { kind = 'shop', def = s } end end
    for _, b in ipairs(cfg.buyers or {}) do if b.enabled then out[key('buyer', b.id)] = { kind = 'buyer', def = b } end end
    return out
end

function C.PedDef(kind, id)
    local cfg = C.Cfg() or {}
    for _, d in ipairs((kind == 'shop' and cfg.shops or cfg.buyers) or {}) do if d.id == id then return d end end
end
function C.PedEntity(kind, id) local e = peds[key(kind, id)] return e and e.ped end

-- Blips
local function refreshBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
    for _, w in pairs(list()) do
        local bl = w.def.blip
        if bl and bl.enabled then
            local b = AddBlipForCoord(w.def.ped.x + 0.0, w.def.ped.y + 0.0, w.def.ped.z + 0.0)
            SetBlipSprite(b, bl.sprite) SetBlipColour(b, bl.color) SetBlipScale(b, bl.scale + 0.0) SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(w.def.name) EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end

local version = 0
AddStateBagChangeHandler('jhCfg', 'global', function()
    version = version + 1
    SetTimeout(200, function()
        for k in pairs(peds) do removePed(k) end
        refreshBlips()
    end)
end)

-- Apparition / disparition selon la distance
CreateThread(function()
    while not C.Cfg() do Wait(500) end
    refreshBlips()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        local want = list()
        for k, w in pairs(want) do
            local d = #(pc - vector3(w.def.ped.x, w.def.ped.y, w.def.ped.z))
            if d < 60.0 and (not peds[k] or not DoesEntityExist(peds[k].ped)) then
                local ped = spawnPed(w.kind, w.def)
                if ped then peds[k] = { ped = ped, kind = w.kind, id = w.def.id, def = w.def } end
            elseif d > 75.0 and peds[k] then removePed(k) end
        end
        for k in pairs(peds) do if not want[k] then removePed(k) end end
        Wait(1500)
    end
end)

-- ---------------------------------------------------------------------
-- Animations du bijoutier pendant un braquage
-- ---------------------------------------------------------------------
local function attachHandBag(e)
    local cfg = C.Cfg()
    if e.handBag and DoesEntityExist(e.handBag) then return end
    local hash = C.LoadModel(cfg.bag.model)
    if not hash then return end
    local p = GetEntityCoords(e.ped)
    e.handBag = CreateObject(hash, p.x, p.y, p.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    AttachEntityToEntity(e.handBag, e.ped, GetPedBoneIndex(e.ped, 57005), 0.25, 0.0, -0.05, 0.0, 270.0, 60.0, true, true, false, true, 1, true)
end
local function dropHandBag(e)
    if e.handBag and DoesEntityExist(e.handBag) then DeleteEntity(e.handBag) end
    e.handBag = nil
end

local function applyStage(e, stage)
    local A = C.Cfg().anims
    ClearPedTasks(e.ped)
    if stage == 'panic' then C.PlayAnim(e.ped, A.panic, A.fallbackPanic)
    elseif stage == 'filling' then C.PlayAnim(e.ped, A.fill, A.fallbackFill) attachHandBag(e)
    elseif stage == 'handover' then C.PlayAnim(e.ped, A.handover, nil, 2500) attachHandBag(e)
    else dropHandBag(e) ClearPedTasksImmediately(e.ped) SetEntityHeading(e.ped, e.def.ped.h + 0.0) end
end

CreateThread(function()
    while true do
        local heists = GlobalState.jhHeists or {}
        local cfg = C.Cfg()
        for _, e in pairs(peds) do
            if e.kind == 'shop' and DoesEntityExist(e.ped) and cfg then
                local h = heists[e.id]
                local stage = h and h.stage or nil
                if stage ~= e.stage then e.stage = stage applyStage(e, stage)
                elseif stage == 'panic' or stage == 'filling' then
                    -- l'animation en boucle doit continuer ; sinon on la relance (ou le scénario de secours)
                    local a = stage == 'panic' and cfg.anims.panic or cfg.anims.fill
                    if not IsEntityPlayingAnim(e.ped, a.dict, a.name, 3) and not IsPedUsingAnyScenario(e.ped) then
                        C.PlayAnim(e.ped, a, stage == 'panic' and cfg.anims.fallbackPanic or cfg.anims.fallbackFill)
                    end
                end
            end
        end
        Wait(1000)
    end
end)

-- Texte au-dessus du bijoutier pendant le braquage
CreateThread(function()
    local endAt = {}
    AddStateBagChangeHandler('jhHeists', 'global', function(_, _, value)
        endAt = {}
        for id, h in pairs(value or {}) do
            endAt[id] = { stage = h.stage, fill = GetGameTimer() + math.floor((h.fillLeft or 0) * 1000), panic = GetGameTimer() + math.floor((h.panicLeft or 0) * 1000) }
        end
    end)
    while true do
        local sleep = 800
        local pc = GetEntityCoords(PlayerPedId())
        for id, t in pairs(endAt) do
            local e = peds[key('shop', id)]
            if e and DoesEntityExist(e.ped) then
                local p = GetEntityCoords(e.ped)
                if #(pc - p) < 15.0 then
                    sleep = 0
                    local txt
                    if t.stage == 'panic' then txt = '~r~Le bijoutier panique…'
                    elseif t.stage == 'filling' then txt = ('~y~Remplit le sac… ~w~%d s'):format(math.max(0, math.ceil((t.fill - GetGameTimer()) / 1000)))
                    else txt = '~g~Pose le sac sur le comptoir' end
                    C.Text3D(p.x, p.y, p.z + 1.05, txt)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for k in pairs(peds) do removePed(k) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
