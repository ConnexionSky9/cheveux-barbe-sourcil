-- =====================================================================
--  ELYZEA DYNASTY 8 - client : MODE ÉDITEUR de décoration (dans son logement uniquement)
--  · Caméra libre qui vole dans le logement (le personnage reste sur place).
--  · Interface : tous les objets autorisés ; survoler un objet = aperçu 3D devant la caméra ;
--    cliquer = l'objet suit la souris ; clic dans la pièce = poser.
--  · « Coller au sol / aux surfaces » activé : l'objet se pose sur ce que vise la souris ;
--    désactivé : il flotte à la distance choisie (Pg.Préc / Pg.Suiv).
--  · Cliquer sur un objet déjà posé : le déplacer, le tourner ou le retirer.
--  Touches : Z Q S D / W A S D voler · Espace / Ctrl monter / descendre · Maj plus vite
--            clic droit maintenu = regarder · molette = tourner l'objet · G = coller au sol oui / non
--            Suppr = retirer l'objet sélectionné · Échap = annuler / quitter
--  Le serveur revérifie tout (droit de gestion, objet autorisé, limite, distance au logement).
-- =====================================================================
local C = D8C
local E = nil

local function LoadModel(m)
    local h = type(m) == 'string' and joaat(m) or m
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 4000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(h) and h or nil
end
local function Clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function Fwd(p, y) p, y = math.rad(p), math.rad(y) return vector3(-math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p)) end
local function Cross(a, b) return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
local function Norm(v) local l = #v if l < 1e-6 then return v end return v / l end

function C.EditorActive() return E ~= nil end

local function DelEnt(e) if e and DoesEntityExist(e) then DeleteEntity(e) end end
local function Ghost(model, alpha)
    local h = LoadModel(model)
    if not h then return nil end
    local o = CreateObjectNoOffset(h, E.pos.x, E.pos.y, E.pos.z, false, false, false)
    SetEntityCollision(o, false, false)
    FreezeEntityPosition(o, true)
    SetEntityAlpha(o, alpha or 190, false)
    SetModelAsNoLongerNeeded(h)
    return o
end

local function Ui(msg) msg.action = 'hedit' SendNUIMessage(msg) end
local function State()
    Ui({ state = true, snap = E.snap, model = E.model, moving = E.moveId ~= nil, sel = E.sel and { id = E.sel.id, model = E.sel.model } or nil,
        placed = E.data.placed, limit = E.data.limit, valid = E.valid ~= false })
end

-- Rayon de la souris dans la pièce (souris → monde, selon la caméra)
local function CursorRay()
    local cx, cy = GetNuiCursorPosition()
    local w, h = GetActiveScreenResolution()
    local nx, ny = (cx / w) * 2.0 - 1.0, 1.0 - (cy / h) * 2.0
    local f = Fwd(E.pitch, E.yaw)
    local r = Norm(Cross(f, vector3(0.0, 0.0, 1.0)))
    local u = Cross(r, f)
    local t = math.tan(math.rad(E.fov) / 2.0)
    return Norm(f + r * (nx * t * (w / h)) + u * (ny * t))
end
local function Raycast(dir, ignore)
    local to = E.pos + dir * 25.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(E.pos.x, E.pos.y, E.pos.z, to.x, to.y, to.z, 1 + 16, ignore or 0, 7)
    local _, hit, at, _, ent = GetShapeTestResult(ray)
    return hit == 1, at, ent
end

local function ClearHand()
    DelEnt(E.ghost) E.ghost = nil
    if E.hidden and DoesEntityExist(E.hidden) then SetEntityVisible(E.hidden, true, false) end
    E.hidden, E.model, E.moveId = nil, nil, nil
end
local function ClearPreview() DelEnt(E.preview) E.preview, E.previewModel = nil, nil end

local function Close()
    if not E then return end
    ClearHand() ClearPreview()
    RenderScriptCams(false, true, 300, true, true)
    if E.cam and DoesCamExist(E.cam) then DestroyCam(E.cam, false) end
    ClearFocus()
    FreezeEntityPosition(PlayerPedId(), false)
    E = nil
    C.Focus('hedit', false)
    SetNuiFocusKeepInput(false)
    Ui({ show = false })
end
C.ui.hedit = { close = Close }

function C.EditorOpen(pid)
    if E then return end
    local r = C.Pub('decoEditor', { pid = pid })
    if r.error then return C.Notify(r.error, 'error') end
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    E = { pid = pid, data = r, pos = pc + vector3(0.0, 0.0, 0.9), yaw = GetEntityHeading(ped), pitch = -15.0, fov = 60.0, snap = true, rot = 0.0, dist = 3.0,
        anchor = r.anchor and vector3(r.anchor.x, r.anchor.y, r.anchor.z) or pc }
    FreezeEntityPosition(ped, true)
    E.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(E.cam, E.pos.x, E.pos.y, E.pos.z)
    SetCamRot(E.cam, E.pitch, 0.0, E.yaw, 2)
    SetCamFov(E.cam, E.fov)
    RenderScriptCams(true, true, 300, true, true)
    C.Focus('hedit', true, true)
    Ui({ show = true, data = r })
    State()
    local looking = false
    CreateThread(function()
        while E do
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            EnableControlAction(0, 245, true) EnableControlAction(0, 249, true)
            local dt = GetFrameTime()
            -- Regarder : clic droit maintenu (le curseur disparaît)
            local wantLook = IsDisabledControlPressed(0, 25)
            if wantLook ~= looking then looking = wantLook SetNuiFocus(true, not looking) end
            if looking then
                E.yaw = (E.yaw - GetDisabledControlNormal(0, 1) * 8.0) % 360
                E.pitch = Clamp(E.pitch - GetDisabledControlNormal(0, 2) * 8.0, -89.0, 89.0)
            end
            -- Voler (sauf pendant la saisie dans la recherche)
            if not E.typing then
                local f, r = Fwd(E.pitch, E.yaw), vector3(math.cos(math.rad(E.yaw)), math.sin(math.rad(E.yaw)), 0.0)
                local sp = (E.data.speed or 3.0) * dt * (IsDisabledControlPressed(0, 21) and 3.0 or 1.0)
                local mv = vector3(0.0, 0.0, 0.0)
                if IsDisabledControlPressed(0, 32) then mv = mv + f end
                if IsDisabledControlPressed(0, 33) then mv = mv - f end
                if IsDisabledControlPressed(0, 34) then mv = mv - r end
                if IsDisabledControlPressed(0, 35) then mv = mv + r end
                if IsDisabledControlPressed(0, 22) then mv = mv + vector3(0.0, 0.0, 1.0) end
                if IsDisabledControlPressed(0, 36) then mv = mv - vector3(0.0, 0.0, 1.0) end
                local np = E.pos + mv * sp
                if #(np - E.anchor) <= (E.data.radius or 30.0) - 1.0 then E.pos = np end
                if IsDisabledControlJustPressed(0, 47) then E.snap = not E.snap State() end
                if IsDisabledControlPressed(0, 10) then E.dist = Clamp(E.dist + 2.0 * dt, 0.8, 12.0) end
                if IsDisabledControlPressed(0, 11) then E.dist = Clamp(E.dist - 2.0 * dt, 0.8, 12.0) end
                if IsDisabledControlJustPressed(0, 178) and E.sel and not E.model then C.EditorDelete() end
            end
            if IsDisabledControlJustPressed(0, 241) then E.rot = (E.rot + (E.data.step or 15.0)) % 360 end
            if IsDisabledControlJustPressed(0, 242) then E.rot = (E.rot - (E.data.step or 15.0)) % 360 end
            SetCamCoord(E.cam, E.pos.x, E.pos.y, E.pos.z)
            SetCamRot(E.cam, E.pitch, 0.0, E.yaw, 2)
            SetFocusPosAndVel(E.pos.x, E.pos.y, E.pos.z, 0.0, 0.0, 0.0)
            -- Objet en main : suit la souris
            if E.ghost and DoesEntityExist(E.ghost) and not looking then
                local dir = CursorRay()
                local p
                if E.snap then
                    local hit, at = Raycast(dir, E.ghost)
                    if hit then
                        local mn = GetModelDimensions(GetEntityModel(E.ghost))
                        p = vector3(at.x, at.y, at.z - mn.z)
                    end
                end
                p = p or (E.pos + dir * E.dist)
                E.at = p
                SetEntityCoordsNoOffset(E.ghost, p.x, p.y, p.z, false, false, false)
                SetEntityRotation(E.ghost, 0.0, 0.0, E.rot, 2, true)
                local valid = #(p - E.anchor) <= (E.data.radius or 30.0)
                if valid ~= E.valid then E.valid = valid SetEntityAlpha(E.ghost, valid and 190 or 90, false) State() end
            end
            -- Aperçu (survol d'un objet dans la liste) : il tourne devant la caméra
            if E.preview and DoesEntityExist(E.preview) then
                local p = E.pos + Fwd(E.pitch, E.yaw) * 2.6 - vector3(0.0, 0.0, 0.4)
                SetEntityCoordsNoOffset(E.preview, p.x, p.y, p.z, false, false, false)
                SetEntityRotation(E.preview, 0.0, 0.0, (GetGameTimer() / 20.0) % 360, 2, true)
            end
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 202) then
                if E.ghost then ClearHand() State() else Close() end
            end
            Wait(0)
        end
    end)
end

-- Clic dans la pièce : poser l'objet en main, ou sélectionner un objet déjà posé
function C.EditorClick()
    if not E then return end
    if E.ghost and E.at then
        if E.valid == false then return C.Notify('Trop loin : l\'objet doit rester dans le logement.', 'error') end
        local d = { pid = E.pid, model = E.model, id = E.moveId, x = E.at.x, y = E.at.y, z = E.at.z, rx = 0.0, ry = 0.0, rz = E.rot }
        local r = C.Pub(E.moveId and 'decoMove' or 'decoPlace', d)
        C.Show(r)
        if r.ok then
            if not E.moveId then E.data.placed = (E.data.placed or 0) + 1 end
            local keep = E.model
            local wasMove = E.moveId ~= nil
            ClearHand()
            -- on garde le même objet en main pour en poser plusieurs (sauf après un déplacement)
            if not wasMove and E.data.placed < E.data.limit then C.EditorPick(keep) end
        end
        State()
        return
    end
    local hit, _, ent = Raycast(CursorRay(), 0)
    E.sel = nil
    if hit and ent and ent ~= 0 then
        for _, o in ipairs(C.DecoShown and C.DecoShown() or {}) do
            if o.ent == ent then E.sel = { id = o.id, model = o.model, ent = o.ent } end
        end
    end
    State()
end

function C.EditorPick(model)
    if not E or not model then return end
    ClearHand() ClearPreview()
    if (E.data.placed or 0) >= (E.data.limit or 0) then return C.Notify('Limite d\'objets atteinte.', 'error') end
    E.model = model
    E.sel = nil
    E.ghost = Ghost(model, 190)
    if not E.ghost then E.model = nil C.Notify('Modèle introuvable.', 'error') end
    State()
end

function C.EditorMoveSel()
    if not E or not E.sel then return end
    local s = E.sel
    ClearHand() ClearPreview()
    E.model, E.moveId = s.model, s.id
    if DoesEntityExist(s.ent) then
        E.rot = GetEntityRotation(s.ent, 2).z
        SetEntityVisible(s.ent, false, false)
        E.hidden = s.ent
    end
    E.ghost = Ghost(s.model, 190)
    E.sel = nil
    State()
end

function C.EditorDelete()
    if not E or not E.sel then return end
    local r = C.Pub('decoDelete', { pid = E.pid, id = E.sel.id })
    C.Show(r)
    if r.ok then E.data.placed = math.max(0, (E.data.placed or 1) - 1) E.sel = nil end
    State()
end

function C.EditorPreview(model)
    if not E then return end
    if model == E.previewModel then return end
    ClearPreview()
    if model and not E.ghost then
        E.previewModel = model
        E.preview = Ghost(model, 235)
    end
end

-- Appels de l'interface
RegisterNUICallback('he', function(body, cb)
    cb({})
    if not E then return end
    local a = tostring(body.a or '')
    if a == 'click' then C.EditorClick()
    elseif a == 'pick' then C.EditorPick(tostring(body.model or ''))
    elseif a == 'preview' then C.EditorPreview(body.model and tostring(body.model) or nil)
    elseif a == 'snap' then E.snap = body.on == true State()
    elseif a == 'move' then C.EditorMoveSel()
    elseif a == 'delete' then C.EditorDelete()
    elseif a == 'rotate' then E.rot = (E.rot + (tonumber(body.deg) or 15)) % 360
    elseif a == 'drop' then ClearHand() State()
    elseif a == 'typing' then E.typing = body.on == true SetNuiFocusKeepInput(not E.typing)
    elseif a == 'close' then Close() end
end)

-- Depuis la zone de gestion (bouton « Mode éditeur ») ou /decorer dans son logement
RegisterNUICallback('heOpen', function(_, cb)
    cb({})
    local i = C.insideData
    if not i then return end
    if C.ui.manage and C.ui.manage.close then C.ui.manage.close(true) end
    C.EditorOpen(i.pid)
end)
RegisterCommand('decorer', function()
    local i = C.insideData
    if not i or i.area ~= 'home' then return C.Notify('Entrez dans votre logement pour le décorer.', 'error') end
    C.EditorOpen(i.pid)
end, false)

RegisterNetEvent('d8:client:exit', function() if E then Close() end end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and E then Close() end end)
