-- =====================================================================
--  BANK HEIST - client : PNJ (employés de banque, marchands) et blips
--  PNJ locaux, invincibles et figés. L'employé réagit selon l'état publié par le serveur :
--  braquage lancé -> mains levées ; menacé -> mains levées puis à genoux ; fin -> reprend sa place.
-- =====================================================================
local C = BHC
local peds = {}          -- [clé] = { ped, kind, id, def, mode }
local blips = {}
C.PedByEntity = {}

local function remove(k)
    local e = peds[k]
    if e and DoesEntityExist(e.ped) then C.PedByEntity[e.ped] = nil DeleteEntity(e.ped) end
    peds[k] = nil
end

local function spawn(kind, id, def)
    local hash = C.LoadModel(def.model) or C.LoadModel('a_m_y_business_03')
    if not hash then return nil end
    local ped = CreatePed(4, hash, def.x + 0.0, def.y + 0.0, def.z - 1.0, (def.h or 0.0) + 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return nil end
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    C.PedByEntity[ped] = { kind = kind, id = id }
    return ped
end

local function wanted()
    local cfg, out = C.Cfg(), {}
    if not cfg or not cfg.general.enabled then return out end
    for _, b in ipairs(cfg.banks) do if b.enabled then out['bank:' .. b.id] = { kind = 'clerk', id = b.id, def = b.clerk } end end
    for _, m in ipairs(cfg.merchants) do if m.enabled then out['merchant:' .. m.id] = { kind = 'merchant', id = m.id, def = m.ped, scenario = m.scenario } end end
    return out
end

local function refreshBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
    local cfg = C.Cfg()
    if not cfg then return end
    local function add(p, bl, name)
        if not bl or not bl.enabled then return end
        local b = AddBlipForCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
        SetBlipSprite(b, bl.sprite) SetBlipColour(b, bl.color) SetBlipScale(b, bl.scale + 0.0) SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(name) EndTextCommandSetBlipName(b)
        blips[#blips + 1] = b
    end
    for _, b in ipairs(cfg.banks) do if b.enabled then add(b.start, b.blip, b.name) end end
    for _, m in ipairs(cfg.merchants) do if m.enabled then add(m.ped, m.blip, m.name) end end
end

function C.PedEntityOf(bankId) local e = peds['bank:' .. bankId] return e and e.ped end

AddStateBagChangeHandler('bhCfg', 'global', function()
    SetTimeout(200, function() for k in pairs(peds) do remove(k) end refreshBlips() end)
end)

CreateThread(function()
    while not C.Cfg() do Wait(500) end
    refreshBlips()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        local want = wanted()
        for k, w in pairs(want) do
            local d = #(pc - C.Vec(w.def))
            if d < 70.0 and (not peds[k] or not DoesEntityExist(peds[k].ped)) then
                local ped = spawn(w.kind, w.id, w.def)
                if ped then
                    peds[k] = { ped = ped, kind = w.kind, id = w.id, def = w.def }
                    if w.scenario and w.scenario ~= '' then TaskStartScenarioInPlace(ped, w.scenario, 0, true) end
                end
            elseif d > 85.0 and peds[k] then remove(k) end
        end
        for k in pairs(peds) do if not want[k] then remove(k) end end
        Wait(1500)
    end
end)

-- Réactions de l'employé
CreateThread(function()
    while true do
        local cfg = C.Cfg()
        for _, e in pairs(peds) do
            if e.kind == 'clerk' and cfg and DoesEntityExist(e.ped) then
                local st = C.Bank(e.id)
                local active = st.phase and st.phase ~= 'available' and st.phase ~= 'cooldown'
                local mode = not active and 'idle' or (st.threatened and (st.threatLeft > 0 and 'panic' or 'kneel') or 'panic')
                if st.threatened and st.threatLeft > 0 and e.mode ~= 'panic' then mode = 'panic' end
                if mode ~= e.mode then
                    e.mode = mode
                    ClearPedTasksImmediately(e.ped)
                    if mode == 'panic' then C.PlayAnim(e.ped, cfg.visuals.threatPanic)
                    elseif mode == 'kneel' then if not C.PlayAnim(e.ped, cfg.visuals.threatKneel) then TaskStartScenarioInPlace(e.ped, 'CODE_HUMAN_COWER', 0, true) end
                    else SetEntityHeading(e.ped, (e.def.h or 0.0) + 0.0) end
                elseif mode ~= 'idle' then
                    local a = mode == 'panic' and cfg.visuals.threatPanic or cfg.visuals.threatKneel
                    if not IsEntityPlayingAnim(e.ped, a.dict, a.name, 3) and not IsPedUsingAnyScenario(e.ped) then C.PlayAnim(e.ped, a) end
                end
            end
        end
        Wait(800)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for k in pairs(peds) do remove(k) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
