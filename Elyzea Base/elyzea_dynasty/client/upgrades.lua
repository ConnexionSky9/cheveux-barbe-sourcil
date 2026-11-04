-- =====================================================================
--  ELYZEA DYNASTY 8 - client : améliorations des logements
--  · Caméras : pose avec aperçu en direct (la vue de la caméra s'affiche pendant le réglage),
--    puis visionnage en direct (plein écran, ou dans le téléphone : appli MAISON).
--      Pose libre : Z Q S D / W A S D = déplacer · Espace / Ctrl = hauteur · souris = orienter
--                   molette = angle de vue · Maj = plus vite · Entrée = valider · Retour arrière = annuler
--      Emplacements imposés par le staff : ← / → = emplacement suivant, souris = orienter (dans la plage permise)
--      Visionnage : ← / → = caméra précédente / suivante · Retour arrière = quitter
--  · Danseuse : PNJ local recréé chez chaque joueur présent, d'après l'état envoyé par le serveur
--    (un seul PNJ par danseuse, supprimé à la sortie, à la fin de la durée et à l'arrêt de la ressource).
--  · Cannabis : pots et plantes affichés en objets locaux ; « [E] Plante » près d'un pot.
--  Le serveur revérifie chaque action (droits, amélioration achetée, limites, distances).
-- =====================================================================
local C = D8C
local UP = Config.Upgrades

local function LoadModel(m)
    if type(m) == 'string' then m = joaat(m) end
    if not IsModelInCdimage(m) then return nil end
    RequestModel(m)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(m) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(m) and m or nil
end
local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end
local function Text2D(x, y, text, scale, r, g, b)
    SetTextFont(4) SetTextScale(scale or 0.4, scale or 0.4) SetTextColour(r or 255, g or 255, b or 255, 235) SetTextOutline()
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(x, y)
end
local function Clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function AngleDiff(a, b) return ((a - b + 180) % 360) - 180 end

-- =====================================================================
-- Caméras : visionnage
-- =====================================================================
local V = nil      -- { pid, name, cams, idx, cam, phone, modifier }
function C.CamBusy() return V ~= nil or C.CamPlacing ~= nil end

local function ApplyCam()
    if not V then return end
    local c = V.cams[V.idx]
    if not c then return end
    SetCamCoord(V.cam, c.x + 0.0, c.y + 0.0, c.z + 0.0)
    SetCamRot(V.cam, (c.rx or 0) + 0.0, 0.0, (c.rz or 0) + 0.0, 2)
    SetCamFov(V.cam, (c.fov or 60) + 0.0)
    SetFocusPosAndVel(c.x + 0.0, c.y + 0.0, c.z + 0.0, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
end

local function CamStop()
    if not V then return end
    V = nil
    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
end

local function CamStart(view, idx, phone)
    if V then CamStop() end
    if type(view) ~= 'table' or type(view.cams) ~= 'table' or #view.cams == 0 then return false end
    V = { pid = view.pid, name = view.name, cams = view.cams, idx = Clamp(tonumber(idx) or 1, 1, #view.cams), phone = phone == true, modifier = view.modifier }
    V.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    ApplyCam()
    SetCamActive(V.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    if V.modifier and V.modifier ~= '' then SetTimecycleModifier(V.modifier) SetTimecycleModifierStrength(0.6) end
    CreateThread(function()
        local me = V
        while V == me do
            HideHudAndRadarThisFrame()
            local c = V.cams[V.idx] or {}
            -- Incrustation discrète : nom de la caméra et heure (comme un vrai enregistreur)
            Text2D(0.035, 0.04, ('● REC  %s'):format(c.label or ''), 0.42, 255, 70, 70)
            Text2D(0.035, 0.075, ('%s · %02d:%02d'):format(V.name or '', GetClockHours(), GetClockMinutes()), 0.34)
            if not V.phone then
                DisableAllControlActions(0)
                EnableControlAction(0, 245, true) EnableControlAction(0, 249, true)   -- discussion, micro
                Text2D(0.035, 0.93, ('Caméra %d / %d   ·   ← → changer   ·   Retour arrière quitter'):format(V.idx, #V.cams), 0.34)
                if IsDisabledControlJustPressed(0, 174) then V.idx = V.idx > 1 and V.idx - 1 or #V.cams ApplyCam() end
                if IsDisabledControlJustPressed(0, 175) then V.idx = V.idx < #V.cams and V.idx + 1 or 1 ApplyCam() end
                if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 202) then CamStop() break end
            else
                -- Téléphone ouvert : le joueur ne bouge pas pendant qu'il regarde
                DisableControlAction(0, 30, true) DisableControlAction(0, 31, true)
                DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            end
            Wait(0)
        end
        if me.cam and DoesCamExist(me.cam) then DestroyCam(me.cam, false) end
    end)
    return true
end

-- Depuis le logement / un menu : vérifie les droits puis ouvre en plein écran
function C.CamOpen(pid, idx)
    local r = C.Pub('camView', { pid = pid })
    if r.error then return C.Notify(r.error, 'error') end
    CamStart(r, idx, false)
end

-- Téléphone (elyzea_aura, appli MAISON) : la vue part dans l'écran du téléphone (image du jeu en direct).
-- Les droits sont vérifiés par le serveur avant que le téléphone ne reçoive la liste des caméras.
exports('PhoneCamStart', function(view, idx) return CamStart(view, idx, true) end)
exports('PhoneCamSet', function(idx)
    if not V then return false end
    V.idx = Clamp(tonumber(idx) or 1, 1, #V.cams)
    ApplyCam()
    return true
end)
exports('PhoneCamStop', function() CamStop() return true end)
exports('CamActive', function() return V ~= nil end)

-- =====================================================================
-- Caméras : pose avec aperçu
-- =====================================================================
C.CamPlacing = nil
local function PlaceStop()
    local S = C.CamPlacing
    if not S then return end
    C.CamPlacing = nil
    RenderScriptCams(false, false, 0, true, true)
    if S.cam and DoesCamExist(S.cam) then DestroyCam(S.cam, false) end
    ClearFocus()
    FreezeEntityPosition(PlayerPedId(), false)
end

local function PlaceApply(S)
    SetCamCoord(S.cam, S.x + 0.0, S.y + 0.0, S.z + 0.0)
    SetCamRot(S.cam, S.pitch + 0.0, 0.0, S.yaw + 0.0, 2)
    SetCamFov(S.cam, S.fov + 0.0)
    SetFocusPosAndVel(S.x + 0.0, S.y + 0.0, S.z + 0.0, 0.0, 0.0, 0.0)
end

local function UseSpot(S, i)
    local sp = S.spots[i]
    if not sp then return end
    S.si = i
    S.x, S.y, S.z = sp.x, sp.y, sp.z
    S.yaw, S.pitch, S.fov = sp.rz or 0.0, sp.rx or -10.0, sp.fov or S.fov
end

function C.CamPlaceStart(pid)
    if C.CamPlacing or V then return end
    local info = C.Pub('camInfo', { pid = pid })
    if info.error then return C.Notify(info.error, 'error') end
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local S = { pid = pid, info = info, spots = info.spots, si = 1, fov = info.fov or 60.0,
        x = pc.x, y = pc.y, z = pc.z + 0.9, yaw = GetEntityHeading(ped), pitch = -10.0 }
    if S.spots then UseSpot(S, 1) end
    S.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    PlaceApply(S)
    SetCamActive(S.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    FreezeEntityPosition(ped, true)
    C.CamPlacing = S
    local enter = vector3(info.enter.x + 0.0, info.enter.y + 0.0, info.enter.z + 0.0)
    CreateThread(function()
        while C.CamPlacing == S do
            DisableAllControlActions(0)
            EnableControlAction(0, 245, true) EnableControlAction(0, 249, true)
            HideHudAndRadarThisFrame()
            local fast = IsDisabledControlPressed(0, 21) and 3.0 or 1.0
            local dt = GetFrameTime()
            -- Orientation (souris)
            S.yaw = (S.yaw - GetDisabledControlNormal(0, 1) * 6.0) % 360
            S.pitch = S.pitch - GetDisabledControlNormal(0, 2) * 5.0
            if IsDisabledControlJustPressed(0, 241) then S.fov = S.fov - 3.0 end
            if IsDisabledControlJustPressed(0, 242) then S.fov = S.fov + 3.0 end
            S.fov = Clamp(S.fov, info.fovMin or 25, info.fovMax or 90)
            if S.spots then
                local sp = S.spots[S.si]
                local dy = AngleDiff(S.yaw, sp.rz or 0)
                local yr, pr = sp.yaw_range or 45, sp.pitch_range or 20
                if dy > yr then S.yaw = ((sp.rz or 0) + yr) % 360 elseif dy < -yr then S.yaw = ((sp.rz or 0) - yr) % 360 end
                S.pitch = Clamp(S.pitch, (sp.rx or 0) - pr, (sp.rx or 0) + pr)
                if IsDisabledControlJustPressed(0, 174) then UseSpot(S, S.si > 1 and S.si - 1 or #S.spots) end
                if IsDisabledControlJustPressed(0, 175) then UseSpot(S, S.si < #S.spots and S.si + 1 or 1) end
                Help(('Emplacement %d / %d : %s~n~Souris : orienter · Molette : angle · ← → : emplacement~n~Entrée : installer · Retour arrière : annuler'):format(S.si, #S.spots, sp.label or ''))
            else
                S.pitch = Clamp(S.pitch, info.pitchMin or -70, info.pitchMax or 25)
                local rad = math.rad(S.yaw)
                local fx, fy = -math.sin(rad), math.cos(rad)
                local mv = 4.0 * fast * dt
                local nx, ny, nz = S.x, S.y, S.z
                if IsDisabledControlPressed(0, 32) then nx, ny = nx + fx * mv, ny + fy * mv end
                if IsDisabledControlPressed(0, 33) then nx, ny = nx - fx * mv, ny - fy * mv end
                if IsDisabledControlPressed(0, 34) then nx, ny = nx - fy * mv, ny + fx * mv end
                if IsDisabledControlPressed(0, 35) then nx, ny = nx + fy * mv, ny - fx * mv end
                if IsDisabledControlPressed(0, 22) then nz = nz + mv end
                if IsDisabledControlPressed(0, 36) then nz = nz - mv end
                -- Reste dans la zone permise autour de l'entrée et près du joueur
                local np = vector3(nx, ny, nz)
                if #(np - enter) <= (info.radius or 25.0) and #(np - GetEntityCoords(PlayerPedId())) <= 14.0 then S.x, S.y, S.z = nx, ny, nz end
                Help(('Caméra %d / %d · ZQSD : déplacer · Espace / Ctrl : hauteur~n~Souris : orienter · Molette : angle (%d°)~n~Entrée : installer · Retour arrière : annuler'):format((info.count or 0) + 1, info.max or 4, math.floor(S.fov)))
            end
            PlaceApply(S)
            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then
                local sp = S.spots and S.spots[S.si]
                local r = C.Pub('camPlace', { pid = S.pid, x = S.x, y = S.y, z = S.z, rx = S.pitch, rz = S.yaw, fov = S.fov, spot = sp and sp.id or nil })
                C.Show(r)
                if r.ok then PlaceStop() break end
            elseif IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 202) then
                PlaceStop()
                C.Notify('Pose de la caméra annulée.', 'inform')
                break
            end
            Wait(0)
        end
    end)
end
exports('CamPlaceStart', function(pid) CreateThread(function() C.CamPlaceStart(tonumber(pid)) end) return true end)

-- Aperçu d'un emplacement (staff, admin_menu) : 6 secondes, Retour arrière pour quitter
RegisterNetEvent('d8:client:camPreview', function(s)
    if V or C.CamPlacing then return end
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, s.x + 0.0, s.y + 0.0, s.z + 0.0)
    SetCamRot(cam, (s.rx or 0) + 0.0, 0.0, (s.rz or 0) + 0.0, 2)
    SetCamFov(cam, (s.fov or 60) + 0.0)
    SetFocusPosAndVel(s.x + 0.0, s.y + 0.0, s.z + 0.0, 0.0, 0.0, 0.0)
    RenderScriptCams(true, false, 0, true, true)
    local endAt = GetGameTimer() + 6000
    while GetGameTimer() < endAt do
        DisableAllControlActions(0)
        HideHudAndRadarThisFrame()
        Text2D(0.035, 0.04, ('Aperçu · %s'):format(s.label or ''), 0.42, 181, 123, 255)
        Text2D(0.035, 0.075, ('Rotation possible : ±%d° horizontalement, ±%d° verticalement · Retour arrière : quitter'):format(math.floor(s.yaw or 0), math.floor(s.pitch or 0)), 0.32)
        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 194) then break end
        Wait(0)
    end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    ClearFocus()
end)

-- =====================================================================
-- Danseuse privée (PNJ locaux)
-- =====================================================================
local here = nil          -- identifiant du logement où se trouve le joueur
local dancers = {}        -- [n] = { ent, model, style, clips, ci, x, y, z, h }

local function DeleteDancer(n)
    local d = dancers[n]
    if d and DoesEntityExist(d.ent) then DeleteEntity(d.ent) end
    dancers[n] = nil
end
local function ClearDancers() for n in pairs(dancers) do DeleteDancer(n) end dancers = {} end

-- Chaque style enchaîne SES lap dances en boucle (clip 1 → 2 → 3 → 1…)
local function PlayClip(d)
    local c = d.clips and d.clips[d.ci]
    if not c or not C.LoadDict(c[1]) then return end
    TaskPlayAnim(d.ent, c[1], c[2], 4.0, -4.0, -1, 0, 0.0, false, false, false)
    d.playing = GetGameTimer()
end

local function SyncDancers(list)
    local keep = {}
    for _, x in ipairs(list or {}) do
        keep[x.n] = true
        local d = dancers[x.n]
        if d and d.model ~= x.model then DeleteDancer(x.n) d = nil end
        if not d then
            local m = LoadModel(x.model)
            if m then
                local ent = CreatePed(4, m, x.x + 0.0, x.y + 0.0, x.z + 0.0, (x.h or 0) + 0.0, false, false)
                SetEntityAsMissionEntity(ent, true, true)
                SetBlockingOfNonTemporaryEvents(ent, true)
                SetEntityInvincible(ent, true)
                SetPedCanRagdoll(ent, false)
                SetPedFleeAttributes(ent, 0, false)
                FreezeEntityPosition(ent, true)
                SetModelAsNoLongerNeeded(m)
                d = { ent = ent, model = x.model }
                dancers[x.n] = d
            end
        end
        if d then
            if not d.placingHere then
                SetEntityCoordsNoOffset(d.ent, x.x + 0.0, x.y + 0.0, x.z + 0.0, false, false, false)
                SetEntityHeading(d.ent, (x.h or 0) + 0.0)
            end
            d.x, d.y, d.z, d.h, d.placing = x.x, x.y, x.z, x.h, x.placing
            if d.style ~= x.style then d.style, d.clips, d.ci = x.style, x.clips, 1 PlayClip(d) end
        end
    end
    for n in pairs(dancers) do if not keep[n] then DeleteDancer(n) end end
end

RegisterNetEvent('d8:client:dancer', function(pid, list)
    if here ~= pid then return end
    SyncDancers(list)
end)

-- Fin d'un clip : on passe au suivant du style (et on relance si le jeu l'interrompt)
CreateThread(function()
    while true do
        if next(dancers) then
            for _, d in pairs(dancers) do
                local c = d.clips and d.clips[d.ci]
                if DoesEntityExist(d.ent) and c and GetGameTimer() - (d.playing or 0) > 1500 then
                    if not IsEntityPlayingAnim(d.ent, c[1], c[2], 3) or (GetEntityAnimCurrentTime(d.ent, c[1], c[2]) or 0) > 0.97 then
                        d.ci = (d.ci % #d.clips) + 1
                        PlayClip(d)
                    end
                end
            end
            Wait(500)
        else
            Wait(3000)
        end
    end
end)

-- Placement de la danseuse (à son arrivée, ou « Déplacer ») : elle suit le point visé au sol
-- Souris = viser · Molette / Q-E = tourner · Entrée / clic gauche = valider · Retour arrière = garder sa place
local function AimGround()
    local cr = GetGameplayCamRot(2)
    local cp = GetGameplayCamCoord()
    local p, y = math.rad(cr.x), math.rad(cr.z)
    local dir = vector3(-math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p))
    local to = cp + dir * 12.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(cp.x, cp.y, cp.z, to.x, to.y, to.z, 1, PlayerPedId(), 7)
    local _, hit, pos = GetShapeTestResult(ray)
    if hit == 1 then return pos end
    return nil
end

function C.DancerPlace(pid, n)
    local d = dancers[n]
    if not d or not DoesEntityExist(d.ent) or C.dancerPlacing then return end
    C.dancerPlacing = true
    d.placingHere = true
    local h = d.h or GetEntityHeading(PlayerPedId())
    SetEntityAlpha(d.ent, 190, false)
    CreateThread(function()
        while C.dancerPlacing and DoesEntityExist(d.ent) and here == pid do
            for _, k in ipairs({ 24, 25, 44, 38, 14, 15, 16, 17, 191, 194, 177, 200 }) do DisableControlAction(0, k, true) end
            local pos = AimGround()
            if pos then SetEntityCoordsNoOffset(d.ent, pos.x, pos.y, pos.z, false, false, false) end
            if IsDisabledControlPressed(0, 44) or IsDisabledControlJustPressed(0, 15) then h = (h + (IsDisabledControlJustPressed(0, 15) and 15.0 or 2.0)) % 360 end
            if IsDisabledControlPressed(0, 38) or IsDisabledControlJustPressed(0, 14) then h = (h - (IsDisabledControlJustPressed(0, 14) and 15.0 or 2.0)) % 360 end
            SetEntityHeading(d.ent, h)
            Help('Placez la danseuse : visez le sol~n~Molette / ~INPUT_COVER~ ~INPUT_PICKUP~ : tourner~n~~INPUT_ATTACK~ / Entrée : valider · Retour arrière : garder sa place')
            if (IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 191)) and pos then
                local r = C.Pub('dancerMove', { pid = pid, n = n, x = pos.x, y = pos.y, z = pos.z, h = h })
                C.Show(r)
                if r.ok then break end
            elseif IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 177) then
                C.Pub('dancerMove', { pid = pid, n = n, x = d.x, y = d.y, z = d.z, h = d.h })
                break
            end
            Wait(0)
        end
        C.dancerPlacing = nil
        if DoesEntityExist(d.ent) then ResetEntityAlpha(d.ent) end
        d.placingHere = nil
    end)
end
RegisterNetEvent('d8:client:dancerPlace', function(pid, n)
    if here ~= pid then return end
    local t = GetGameTimer() + 4000
    while not dancers[n] and GetGameTimer() < t do Wait(100) end
    C.DancerPlace(pid, n)
end)

-- =====================================================================
-- Cannabis : pots et plantes
-- =====================================================================
local plants = { list = {}, objs = {}, canCare = false }
local function ClearPlants()
    for _, o in pairs(plants.objs) do
        if o.pot and DoesEntityExist(o.pot) then DeleteEntity(o.pot) end
        if o.plant and DoesEntityExist(o.plant) then DeleteEntity(o.plant) end
    end
    plants = { list = {}, objs = {}, canCare = false }
end

local function LoadPlants()
    if not here then return end
    local r = C.Pub('plantList', { pid = here })
    local old = plants.objs
    plants.list, plants.canCare, plants.objs = r.list or {}, r.canCare == true, {}
    local seen = {}
    for _, p in ipairs(plants.list) do
        seen[p.id] = true
        local o = old[p.id]
        if o and o.model ~= p.model then
            if o.plant and DoesEntityExist(o.plant) then DeleteEntity(o.plant) end
            o.plant, o.model = nil, nil
        end
        o = o or {}
        if not o.pot or not DoesEntityExist(o.pot) then
            local m = LoadModel(UP.cannabis.potModel)
            if m then
                o.pot = CreateObjectNoOffset(m, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false)
                SetEntityHeading(o.pot, (p.h or 0) + 0.0)
                FreezeEntityPosition(o.pot, true)
                SetModelAsNoLongerNeeded(m)
            end
        end
        if p.model and not o.plant then
            local m = LoadModel(p.model)
            if m then
                o.plant = CreateObjectNoOffset(m, p.x + 0.0, p.y + 0.0, p.z + 0.05, false, false, false)
                SetEntityHeading(o.plant, (p.h or 0) + 0.0)
                FreezeEntityPosition(o.plant, true)
                SetEntityCollision(o.plant, false, false)
                SetModelAsNoLongerNeeded(m)
                o.model = p.model
            end
        end
        plants.objs[p.id] = o
    end
    for id, o in pairs(old) do
        if not seen[id] then
            if o.pot and DoesEntityExist(o.pot) then DeleteEntity(o.pot) end
            if o.plant and DoesEntityExist(o.plant) then DeleteEntity(o.plant) end
        end
    end
    if C.PlantUiRefresh then C.PlantUiRefresh() end
end

RegisterNetEvent('d8:client:plantsRefresh', function(pid) if here == pid then LoadPlants() end end)
-- Progression affichée : relue chaque minute pendant qu'on est dans le logement
CreateThread(function()
    while true do
        Wait(60000)
        if here and #plants.list > 0 then LoadPlants() end
    end
end)

function C.NearPlant(pc)
    if not plants.canCare then return nil end
    local best, bd
    for _, p in ipairs(plants.list) do
        local d = #(pc - vector3(p.x, p.y, p.z))
        if d < 1.5 and (not bd or d < bd) then best, bd = p, d end
    end
    if not best then return nil end
    local label = not best.seed and 'Pot vide · planter une graine'
        or best.dead and 'Plante morte'
        or best.ready and ('%s · prête à récolter'):format(best.variety or 'Plante')
        or ('%s · %s %d %%'):format(best.variety or 'Plante', best.stage, math.floor(best.progress))
    return { id = best.id, label = label }
end

function C.PlantData(id)
    for _, p in ipairs(plants.list) do if p.id == id then return p end end
end

-- Poser un pot devant soi (dans le logement)
function C.PlacePot(pid)
    local ped = PlayerPedId()
    local p = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.9, 0.0)
    local ok, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 0.5, false)
    local z = ok and gz or (GetEntityCoords(ped).z - 0.98)
    C.Show(C.Pub('plantPlace', { pid = pid, x = p.x, y = p.y, z = z, h = GetEntityHeading(ped) }))
end

-- Fenêtre d'un pot (NUI) : état, arroser, engrais, récolter, vider, retirer
local plantUi = nil
function C.PlantUiClose()
    if not plantUi then return end
    plantUi = nil
    C.Focus('plant', false)
    SendNUIMessage({ action = 'plant', show = false })
end
C.ui.plant = { close = C.PlantUiClose }
function C.PlantUiRefresh()
    if not plantUi then return end
    local p = C.PlantData(plantUi)
    if not p then return C.PlantUiClose() end
    SendNUIMessage({ action = 'plant', show = true, data = p, varieties = UP.cannabis.varieties })
end
function C.OpenPlant(id)
    if not C.PlantData(id) then return end
    plantUi = id
    C.Focus('plant', true)
    C.PlantUiRefresh()
end
RegisterNUICallback('plantAct', function(body, cb)
    if not plantUi or not here then return cb({ error = 'Fermé.' }) end
    local r = C.Pub('plantAction', { pid = here, id = plantUi, action = tostring(body.action or ''), seed = body.seed })
    C.Show(r)
    if r.ok and body.action == 'remove' then C.PlantUiClose() end
    cb(r)
end)

-- Actions de l'onglet « Améliorations » de la zone de gestion
RegisterNUICallback('upAct', function(body, cb)
    local a, d = tostring(body.action or ''), type(body.data) == 'table' and body.data or {}
    local pid = tonumber(d.pid)
    if not pid then return cb({ error = 'Logement inconnu.' }) end
    local function closeManage() if C.ui.manage and C.ui.manage.close then C.ui.manage.close(true) end end
    if a == 'camView' then cb({ ok = true }) closeManage() return C.CamOpen(pid, d.idx) end
    if a == 'placePot' then cb({ ok = true }) closeManage() return C.PlacePot(pid) end
    if a == 'camPlace' then
        cb({ ok = true })
        if C.insideData then return C.Notify('Les caméras se posent à l\'extérieur : sortez, puis utilisez l\'appli MAISON du téléphone (ou /d8camera).', 'inform') end
        closeManage()
        return C.CamPlaceStart(pid)
    end
    if a == 'dancerStart' then
        local r = C.Pub('dancerStart', d)
        if r.ok then closeManage() end
        return cb(r)
    end
    if a == 'dancerPlace' then cb({ ok = true }) closeManage() return C.DancerPlace(pid, tonumber(d.n) or 1) end
    local MAP = { buy = 'upBuy', dancerStart = 'dancerStart', dancerStyle = 'dancerStyle', dancerStop = 'dancerStop', view = 'upView' }
    if not MAP[a] then return cb({ error = 'Action inconnue.' }) end
    local r = C.Pub(MAP[a], d)
    cb(r)
end)

-- /d8camera : poser une caméra autour du logement le plus proche dont on a les droits
RegisterCommand('d8camera', function()
    if C.insideData then return C.Notify('Sortez du logement pour poser une caméra.', 'error') end
    local pc = GetEntityCoords(PlayerPedId())
    local best, bd
    for _, pr in ipairs(C.props or {}) do
        if C.mine and C.mine[pr.id] and pr.enter then
            local d = #(pc - C.Vec(pr.enter))
            if not bd or d < bd then best, bd = pr, d end
        end
    end
    if not best then return C.Notify('Aucun de vos logements à proximité.', 'error') end
    C.CamPlaceStart(best.id)
end, false)

-- =====================================================================
-- Entrée / sortie du logement
-- =====================================================================
function C.UpEnter(pid)
    here = pid
    CreateThread(function()
        local r = C.Pub('dancerState', { pid = pid })
        if here == pid then SyncDancers(r.list) end
        LoadPlants()
    end)
end
function C.UpExit()
    here = nil
    ClearDancers()
    ClearPlants()
    if C.PlantUiClose then C.PlantUiClose() end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ClearDancers()
    ClearPlants()
    CamStop()
    PlaceStop()
end)
