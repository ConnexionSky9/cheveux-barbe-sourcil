-- =====================================================================
--  ELYZEA EMS - client : actions médicales, escorte, ambulance, ALT
--  Le menu ALT appartient à elyzea_police (pour tout le monde). Il demande à
--  l'EMS ses options par l'export AltOptions(ctx) et lui passe le choix par
--  AltSelect(id, ctx). Sans elyzea_police, les mêmes actions restent dans F6.
-- =====================================================================
local C = EmsC
local DI = Config.Distances
local ANIMS = {
    heal      = { 'amb@medic@standing@tendtodead@idle_a', 'idle_a', 1 },
    stabilize = { 'amb@medic@standing@tendtodead@idle_a', 'idle_a', 1 },
    revive    = { 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', 1 },
    splint    = { 'amb@medic@standing@kneel@idle_a', 'idle_a', 1 },
    treat     = { 'mp_common', 'givetake1_a', 1 },
}
local LABELS = { heal = 'Soins en cours', stabilize = 'Stabilisation', revive = 'Massage cardiaque', splint = 'Pose de l\'attelle', treat = 'Traitement' }

local function Me() return GetPlayerServerId(PlayerId()) end
local function PedOf(sid) local _, ped = C.PlayerFromServerId(sid) return ped end
local function IsDownSid(sid) return Player(sid).state.emsDown == true end

-- ---------------------------------------------------------------------
-- Actes
-- ---------------------------------------------------------------------
local busy = false
function C.MedAct(kind, sid)
    if busy then return end
    local ped = PedOf(sid)
    if not ped then return C.Notify('Patient introuvable.', 'error') end
    local r = C.Req('medStart', { kind = kind, target = sid })
    if r.error then return C.Notify(r.error, 'error') end
    busy = true
    TaskTurnPedToFaceEntity(PlayerPedId(), ped, 800)
    Wait(600)
    local ok = C.Progress(LABELS[kind] or r.label, r.duration, ANIMS[kind], ped)
    busy = false
    if ok then C.Do('medFinish', { kind = kind, target = sid })
    else C.Req('medCancel') C.Notify('Acte interrompu.', 'error') end
end

function C.Examine(sid)
    local r = C.Req('examine', { target = sid })
    if r.error then return C.Notify(r.error, 'error') end
    C.Focus('exam', true)
    SendNUIMessage({ action = 'exam', show = true, exam = r.exam, perms = (C.State() or {}).perms })
end
C.ui.exam = { close = function() C.Focus('exam', false) SendNUIMessage({ action = 'exam', show = false }) end }

-- ---------------------------------------------------------------------
-- Facture et PPA (fenêtres avec récapitulatif, montant recalculé par le serveur)
-- ---------------------------------------------------------------------
function C.OpenBill(sid)
    local r = C.Req('billPreview', { target = sid })
    if r.error then return C.Notify(r.error, 'error') end
    C.Focus('bill', true)
    SendNUIMessage({ action = 'bill', show = true, bill = r.bill })
end
C.ui.bill = { close = function() C.Focus('bill', false) SendNUIMessage({ action = 'bill', show = false }) end }

RegisterNUICallback('billPreview', function(body, cb) cb(C.Req('billPreview', { target = body.target, extras = body.extras })) end)
RegisterNUICallback('billSend', function(body, cb)
    local r = C.Req('billSend', { target = body.target, extras = body.extras, expected = body.expected })
    if r.ok then C.Notify(r.message, 'success') C.ui.bill.close() end
    cb(r)
end)

function C.OpenPpa(sid, kind)
    local r = C.Req('ppaPreview', { target = sid, kind = kind })
    if r.error then return C.Notify(r.error, 'error') end
    C.Focus('ppa', true)
    SendNUIMessage({ action = 'ppa', show = true, recap = r.recap })
end
C.ui.ppa = { close = function() C.Focus('ppa', false) SendNUIMessage({ action = 'ppa', show = false }) end }

RegisterNUICallback('ppaDeliver', function(body, cb)
    local r = C.Req('ppaDeliver', { target = body.target, kind = body.kind, expected = body.expected })
    if r.ok then C.Notify(r.message, 'success') C.ui.ppa.close() end
    cb(r)
end)

-- Boutons de la fenêtre d'examen
RegisterNUICallback('examAction', function(body, cb)
    cb({})
    local sid = tonumber(body.target)
    if not sid then return end
    C.ui.exam.close()
    CreateThread(function()
        local a = body.act
        if a == 'revive' and Proc('cpr') then a = 'cpr' end
        if a == 'splint' and Proc('cast') then a = 'procs' end
        if a == 'heal' or a == 'stabilize' or a == 'revive' or a == 'splint' or a == 'treat' then C.MedAct(a, sid)
        elseif a == 'procs' then C.ProcMenu(sid)
        elseif a == 'cpr' or a == 'hemostasis' then C.ProcMenu(sid, a)
        elseif a == 'bill' then C.OpenBill(sid)
        elseif a == 'report' then C.OpenTablet({ page = 'reportNew', src = sid }) end
    end)
end)

-- ---------------------------------------------------------------------
-- Escorte / port
-- ---------------------------------------------------------------------
local escortedBy, escorting = nil, nil
local CARRY = { patient = { 'nm', 'firemans_carry', 33 }, ems = { 'missfinale_c2mcs_1', 'fin_c2_mcs_1_camman', 49 } }

RegisterNetEvent('ems:client:escort', function(ems, downed)
    local ped = PlayerPedId()
    if not ems then
        escortedBy = nil
        DetachEntity(ped, true, false)
        StopAnimTask(ped, CARRY.patient[1], CARRY.patient[2], 1.0)
        return
    end
    escortedBy = ems
    CreateThread(function()
        while escortedBy == ems do
            local p = PlayerPedId()
            local emsPed = PedOf(ems)
            if not emsPed or not DoesEntityExist(emsPed) then TriggerServerEvent('ems:server:escortBreak') break end
            if not IsEntityAttachedToEntity(p, emsPed) then
                if downed then
                    AttachEntityToEntity(p, emsPed, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 180.0, false, false, false, false, 2, false)
                else
                    AttachEntityToEntity(p, emsPed, 11816, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                end
            end
            if downed and not IsEntityPlayingAnim(p, CARRY.patient[1], CARRY.patient[2], 3) and C.LoadDict(CARRY.patient[1]) then
                TaskPlayAnim(p, CARRY.patient[1], CARRY.patient[2], 8.0, -8.0, -1, CARRY.patient[3], 0, false, false, false)
            end
            Wait(250)
        end
    end)
end)

RegisterNetEvent('ems:client:escorting', function(patient, downed)
    local ped = PlayerPedId()
    escorting = patient
    if not patient then StopAnimTask(ped, CARRY.ems[1], CARRY.ems[2], 1.0) return end
    if not downed then return end
    CreateThread(function()
        while escorting == patient do
            local p = PlayerPedId()
            if not IsEntityPlayingAnim(p, CARRY.ems[1], CARRY.ems[2], 3) and C.LoadDict(CARRY.ems[1]) then
                TaskPlayAnim(p, CARRY.ems[1], CARRY.ems[2], 8.0, -8.0, -1, CARRY.ems[3], 0, false, false, false)
            end
            Wait(500)
        end
    end)
end)

-- ---------------------------------------------------------------------
-- Ambulance : le patient est installé à l'arrière (places libres)
-- ---------------------------------------------------------------------
RegisterNetEvent('ems:client:putIn', function(net)
    local veh = NetToVeh(net)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    ClearPedTasksImmediately(ped)
    local max = GetVehicleMaxNumberOfPassengers(veh)
    local order = {}
    for s = max - 1, 1, -1 do order[#order + 1] = s end
    order[#order + 1] = 0
    for _, s in ipairs(order) do
        if IsVehicleSeatFree(veh, s) then SetPedIntoVehicle(ped, veh, s) return end
    end
    C.Notify('Aucune place libre dans le véhicule.', 'error')
end)

RegisterNetEvent('ems:client:takeOut', function(downed)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return end
    if downed then
        local c = GetOffsetFromEntityInWorldCoords(veh, -2.0, -1.5, 0.0)
        SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
    else
        TaskLeaveVehicle(ped, veh, 16)
    end
end)

local function PutIn(sid)
    local veh = C.ClosestVehicle(GetEntityCoords(PlayerPedId()), DI.vehicle)
    if not veh then return C.Notify('Aucun véhicule à proximité.', 'error') end
    C.Do('putIn', { target = sid, net = VehToNet(veh) })
end

-- ---------------------------------------------------------------------
-- ALT : options et choix (appelés par elyzea_police/client/alt.lua)
-- ---------------------------------------------------------------------
local function NameOf(sid) return ('Personne · ID %d'):format(sid) end
-- Actes en mini-jeux actifs (publiés par le serveur : server/procedures.lua)
local function Proc(act) local g = GlobalState.emsProcs return type(g) == 'table' and g[act] == true end
local function AnyProc() local g = GlobalState.emsProcs if type(g) ~= 'table' then return false end for _, on in pairs(g) do if on then return true end end return false end

function C.AltOptions(ctx)
    local out = {}
    if type(ctx) ~= 'table' or not C.OnDuty() or C.IsDown() then return out end
    if ctx.kind == 'player' and ctx.sid then
        local sid = ctx.sid
        local down = IsDownSid(sid)
        local mine = Player(sid).state.emsEscortedBy == Me()
        if C.Can('medical') then out[#out + 1] = { id = 'examine', label = 'Examiner / état de santé', icon = 'examine' } end
        -- accès rapide d'urgence (sans passer par la liste des actes)
        local st = Player(sid).state.emsProc
        if st and st.act == 'hemostasis' and st.ems ~= Me() and C.Can('stabilize') then
            out[#out + 1] = { id = 'assist', label = 'Aider à la compression', icon = 'stabilize', desc = 'Hémorragie critique' }
        elseif Proc('hemostasis') and C.Can('stabilize') and not ctx.inVehicle then
            out[#out + 1] = { id = 'hemostasis', label = 'Contrôler l\'hémorragie', icon = 'stabilize' }
        end
        if down then
            if C.Can('stabilize') then out[#out + 1] = { id = 'stabilize', label = 'Stabiliser', icon = 'stabilize' } end
            if C.Can('revive') then
                if Proc('cpr') then out[#out + 1] = { id = 'cpr', label = 'Massage cardiaque (réanimation)', icon = 'revive' }
                else out[#out + 1] = { id = 'revive', label = 'Réanimer', icon = 'revive' } end
            end
        elseif C.Can('heal') then
            out[#out + 1] = { id = 'heal', label = 'Soigner', icon = 'heal' }
            if not Proc('cast') then out[#out + 1] = { id = 'splint', label = 'Poser une attelle (jambe)', icon = 'heal' } end
            out[#out + 1] = { id = 'treat', label = 'Donner un traitement (rhume, MST…)', icon = 'heal' }
        end
        if C.Can('medical') and AnyProc() and not ctx.inVehicle then
            out[#out + 1] = { id = 'procs', label = 'Actes et examens…', icon = 'examine', desc = 'Prise de sang, imagerie, attelle, vaccin…' }
        end
        if Config.Stretcher and Config.Stretcher.enabled and C.StretcherPlayerOptions then
            C.StretcherPlayerOptions(sid, ctx, out)         -- brancard (client/stretcher.lua)
        elseif C.Can('escort') and not ctx.inVehicle then
            out[#out + 1] = { id = 'escort', label = mine and 'Lâcher le patient' or (down and 'Porter le patient' or 'Accompagner le patient'), icon = 'escort' }
        end
        if C.Can('vehicle') then
            if ctx.inVehicle then out[#out + 1] = { id = 'takeOut', label = 'Sortir du véhicule', icon = 'out' }
            else
                local veh = C.ClosestVehicle(GetEntityCoords(PlayerPedId()), DI.vehicle)
                out[#out + 1] = { id = 'putIn', label = 'Installer dans le véhicule', icon = 'in', disabled = not veh, desc = not veh and 'Aucun véhicule à proximité' or nil }
            end
        end
        if C.Can('lab_sample') and not ctx.inVehicle and not Proc('blood') then out[#out + 1] = { id = 'lab_sample', label = 'Prélèvement sanguin (laboratoire)', icon = 'blood' } end
        if C.Can('reports_write') then out[#out + 1] = { id = 'report', label = 'Compte rendu d\'intervention', icon = 'record' } end
        if C.Can('billing') then out[#out + 1] = { id = 'bill', label = 'Facturer les soins', icon = 'fine' } end
        if C.Can('ppa_civil') and not down then out[#out + 1] = { id = 'ppa_civil', label = 'Délivrer un PPA civil', icon = 'ppa' } end
        if C.Can('ppa_fdo') and not down then out[#out + 1] = { id = 'ppa_fdo', label = 'Délivrer un PPA force de l\'ordre', icon = 'ppa' } end
    elseif ctx.kind == 'vehicle' and ctx.entity and C.Can('vehicle') then
        local veh = ctx.entity
        for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
            local ped = GetPedInVehicleSeat(veh, seat)
            if ped ~= 0 and IsPedAPlayer(ped) and ped ~= PlayerPedId() then
                local sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
                out[#out + 1] = { id = 'takeOut:' .. sid, label = ('Sortir %s'):format(NameOf(sid)), icon = 'out', desc = IsDownSid(sid) and 'Inconscient' or nil }
            end
        end
        if escorting then out[#out + 1] = { id = 'putIn:' .. escorting, label = 'Installer le patient dans ce véhicule', icon = 'in' } end
        if C.StretcherVehicleOptions then C.StretcherVehicleOptions(veh, out) end
    elseif ctx.kind == 'ext' and ctx.entity and C.StretcherExtOptions then
        C.StretcherExtOptions(ctx.entity, out)              -- le brancard visé
    end
    return out
end

function C.AltSelect(id, ctx)
    id = tostring(id or '')
    -- brancard : actions de client/stretcher.lua (et « accompagner » quand le brancard est activé)
    if C.StretcherSelect then
        if id == 'escort' and Config.Stretcher and Config.Stretcher.enabled and ctx and ctx.sid then
            id = Player(ctx.sid).state.emsOnStretcher and 'st_offp' or 'st_lay'
        end
        if C.StretcherSelect(id, ctx) then return end
    end
    local kind, sid = id:match('^(%a+):(%d+)$')
    if kind == 'takeOut' then return C.Do('takeOut', { target = tonumber(sid) }) end
    if kind == 'putIn' then
        local veh = ctx and ctx.entity
        if veh and DoesEntityExist(veh) then return C.Do('putIn', { target = tonumber(sid), net = VehToNet(veh) }) end
        return PutIn(tonumber(sid))
    end
    local t = ctx and ctx.sid
    if not t then return end
    -- actes simples remplacés par les mini-jeux quand ils sont actifs (F6, examen)
    if id == 'revive' and Proc('cpr') then id = 'cpr' end
    if id == 'splint' and Proc('cast') then id = 'procs' end
    if id == 'examine' then C.Examine(t)
    elseif id == 'heal' or id == 'stabilize' or id == 'revive' or id == 'splint' or id == 'treat' then C.MedAct(id, t)
    elseif id == 'escort' then C.Do('escort', { target = t })
    elseif id == 'putIn' then PutIn(t)
    elseif id == 'takeOut' then C.Do('takeOut', { target = t })
    elseif id == 'lab_sample' then C.LabSample(t)
    elseif id == 'procs' then C.ProcMenu(t)
    elseif id == 'cpr' or id == 'hemostasis' then C.ProcMenu(t, id)
    elseif id == 'assist' then C.ProcAssist(t)
    elseif id == 'report' then C.OpenTablet({ page = 'reportNew', src = t })
    elseif id == 'bill' then C.OpenBill(t)
    elseif id == 'ppa_civil' then C.OpenPpa(t, 'civil')
    elseif id == 'ppa_fdo' then C.OpenPpa(t, 'fdo') end
end

-- Prélèvement sanguin : courte animation puis enregistrement par le serveur (qui revérifie tout)
local sampling = false
function C.LabSample(t)
    if sampling then return end
    sampling = true
    local ped = PlayerPedId()
    local dict = 'mini@repair'
    if C.LoadDict(dict) then TaskPlayAnim(ped, dict, 'fixing_a_ped', 3.0, -3.0, -1, 49, 0, false, false, false) end
    C.Notify('Prélèvement sanguin en cours…', 'inform')
    local endT = GetGameTimer() + ((Config.Lab and Config.Lab.sampleTime) or 6000)
    local cancelled = false
    while GetGameTimer() < endT do
        Wait(100)
        if IsPedRagdoll(ped) or IsEntityDead(ped) or C.IsDown() then cancelled = true break end
    end
    StopAnimTask(ped, dict, 'fixing_a_ped', 1.0)
    sampling = false
    if cancelled then return C.Notify('Prélèvement interrompu.', 'error') end
    C.Do('labSample', { target = t })
end

exports('AltOptions', function(ctx)
    local ok, list = pcall(C.AltOptions, ctx)
    return ok and list or {}
end)
exports('AltSelect', function(id, ctx)
    CreateThread(function()
        local ok, err = pcall(C.AltSelect, id, ctx)
        if not ok then print(('^1[EMS] ALT %s : %s^0'):format(tostring(id), tostring(err))) end
    end)
    return true
end)
exports('IsDown', function() return C.IsDown() end)

-- Patient le plus proche (menu F6 › Actions médicales, sans le menu ALT)
function C.NearestPlayer(radius)
    local me = PlayerPedId()
    local pc = GetEntityCoords(me)
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local d = #(GetEntityCoords(GetPlayerPed(pid)) - pc)
            if d <= (radius or DI.interact) and (not bestD or d < bestD) then best, bestD = GetPlayerServerId(pid), d end
        end
    end
    return best, bestD
end
