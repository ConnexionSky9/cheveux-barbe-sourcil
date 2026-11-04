-- =========================================================
--  ÉDITEUR DE MAP - MODE ÉDITION (permission « editor_props »)
--  · Caméra libre (le personnage reste sur place), interface avec TOUS les props du jeu
--    (html/allprops.txt, ~21 000 modèles) + le catalogue classé.
--  · Survol d'un prop dans la liste : image + aperçu 3D qui tourne devant la caméra.
--  · Clic sur un prop : il suit la souris ; clic dans le monde : il est posé (enregistré comme
--    un prop de l'éditeur : persistant, visible par tous). On peut en poser plusieurs à la suite.
--  · Rotation libre : molette = cap (Z) · flèches ↑ ↓ = tangage (X) · flèches ← → = roulis (Y)
--    · R = remise à zéro · curseurs dans l'interface pour un réglage précis.
--  · Clic sur un prop déjà posé avec l'éditeur : déplacer, dupliquer ou supprimer.
--  Touches : Z Q S D voler · Espace / Ctrl monter / descendre · Maj plus vite · clic droit maintenu = regarder
--            G = coller aux surfaces oui / non · Pg.Préc / Pg.Suiv = distance (sans collage) · Suppr = supprimer
-- =========================================================
local M = nil

local function Clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function Fwd(p, y) p, y = math.rad(p), math.rad(y) return vector3(-math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p)) end
local function Cross(a, b) return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
local function Norm(v) local l = #v if l < 1e-6 then return v end return v / l end
local function Wrap(v) v = (v + 180.0) % 360.0 - 180.0 return v end

function IsEditMode() return M ~= nil end

local function LoadModel(model)
    local h = GetHashKey(model)
    if not IsModelInCdimage(h) or not IsModelValid(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(h) and h or nil
end
local function DelEnt(e) if e and DoesEntityExist(e) then DeleteEntity(e) end end
local function Ghost(model, alpha)
    local h = LoadModel(model)
    if not h or not M then return nil end
    local o = CreateObjectNoOffset(h, M.pos.x, M.pos.y, M.pos.z - 30.0, false, false, false)
    SetEntityCollision(o, false, false)
    FreezeEntityPosition(o, true)
    SetEntityAlpha(o, alpha or 200, false)
    SetModelAsNoLongerNeeded(h)
    return o
end

local function Ui(msg) msg.action = 'emode' SendNUIMessage(msg) end
local function State()
    if not M then return end
    Ui({ state = true, snap = M.snap, model = M.model, moving = M.moveId ~= nil, rx = M.rx, ry = M.ry, rz = M.rz,
        sel = M.sel and { id = M.sel.id, model = M.sel.model, kind = M.sel.kind } or nil, folder = M.folder, count = M.count })
end

local function CursorRay()
    local cx, cy = GetNuiCursorPosition()
    local w, h = GetActiveScreenResolution()
    local nx, ny = (cx / w) * 2.0 - 1.0, 1.0 - (cy / h) * 2.0
    local f = Fwd(M.pitch, M.yaw)
    local r = Norm(Cross(f, vector3(0.0, 0.0, 1.0)))
    local u = Cross(r, f)
    local t = math.tan(math.rad(M.fov) / 2.0)
    return Norm(f + r * (nx * t * (w / h)) + u * (ny * t))
end
local function Raycast(dir, ignore, flags)
    local to = M.pos + dir * 300.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(M.pos.x, M.pos.y, M.pos.z, to.x, to.y, to.z, flags or (1 + 16), ignore or 0, 7)
    local _, hit, at, _, ent = GetShapeTestResult(ray)
    return hit == 1, at, ent
end

local function ClearHand()
    if not M then return end
    DelEnt(M.ghost) M.ghost = nil
    if M.hidden and DoesEntityExist(M.hidden) then SetEntityVisible(M.hidden, true, false) end
    M.hidden, M.model, M.moveId = nil, nil, nil
end
local function ClearPreview() if M then DelEnt(M.preview) M.preview, M.previewModel = nil, nil end end

local function Close()
    if not M then return end
    ClearHand() ClearPreview()
    RenderScriptCams(false, true, 300, true, true)
    if M.cam and DoesCamExist(M.cam) then DestroyCam(M.cam, false) end
    ClearFocus()
    FreezeEntityPosition(PlayerPedId(), false)
    M = nil
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    Ui({ show = false })
end
CloseEditMode = Close

function OpenEditMode(folder)
    if M then return end
    if CancelStaffModes then CancelStaffModes() end
    local ped = PlayerPedId()
    local cp, cr = GetGameplayCamCoord(), GetGameplayCamRot(2)
    M = { pos = cp, yaw = cr.z, pitch = Clamp(cr.x, -89.0, 89.0), fov = 60.0, snap = true, rx = 0.0, ry = 0.0, rz = GetEntityHeading(ped),
        dist = 5.0, folder = tonumber(folder) or nil, count = 0, origin = GetEntityCoords(ped) }
    FreezeEntityPosition(ped, true)
    M.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(M.cam, M.pos.x, M.pos.y, M.pos.z)
    SetCamRot(M.cam, M.pitch, 0.0, M.yaw, 2)
    SetCamFov(M.cam, M.fov)
    RenderScriptCams(true, true, 300, true, true)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    local folders = {}
    for _, f in ipairs(Editor.propFolders or {}) do folders[#folders + 1] = { id = f.id, name = f.name } end
    Ui({ show = true, folders = folders, folder = M.folder })
    State()
    local looking = false
    CreateThread(function()
        while M do
            HideHudAndRadarThisFrame()
            DisableAllControlActions(0)
            EnableControlAction(0, 245, true) EnableControlAction(0, 249, true)
            local dt = GetFrameTime()
            local wantLook = IsDisabledControlPressed(0, 25)
            if wantLook ~= looking then looking = wantLook SetNuiFocus(true, not looking) end
            if looking then
                M.yaw = (M.yaw - GetDisabledControlNormal(0, 1) * 8.0) % 360
                M.pitch = Clamp(M.pitch - GetDisabledControlNormal(0, 2) * 8.0, -89.0, 89.0)
            end
            if not M.typing then
                local f, r = Fwd(M.pitch, M.yaw), vector3(math.cos(math.rad(M.yaw)), math.sin(math.rad(M.yaw)), 0.0)
                local fast = IsDisabledControlPressed(0, 21)
                local sp = 8.0 * dt * (fast and 4.0 or 1.0)
                local mv = vector3(0.0, 0.0, 0.0)
                if IsDisabledControlPressed(0, 32) then mv = mv + f end
                if IsDisabledControlPressed(0, 33) then mv = mv - f end
                if IsDisabledControlPressed(0, 34) then mv = mv - r end
                if IsDisabledControlPressed(0, 35) then mv = mv + r end
                if IsDisabledControlPressed(0, 22) then mv = mv + vector3(0.0, 0.0, 1.0) end
                if IsDisabledControlPressed(0, 36) then mv = mv - vector3(0.0, 0.0, 1.0) end
                M.pos = M.pos + mv * sp
                if IsDisabledControlJustPressed(0, 47) then M.snap = not M.snap State() end
                if IsDisabledControlPressed(0, 10) then M.dist = Clamp(M.dist + 4.0 * dt, 1.0, 60.0) end
                if IsDisabledControlPressed(0, 11) then M.dist = Clamp(M.dist - 4.0 * dt, 1.0, 60.0) end
                if IsDisabledControlJustPressed(0, 178) and M.sel and not M.model then EditModeDelete() end
                -- Rotation libre de l'objet en main
                if M.ghost then
                    local rs = 60.0 * dt * (fast and 0.25 or 1.0)
                    local changed = false
                    if IsDisabledControlPressed(0, 172) then M.rx = Wrap(M.rx + rs) changed = true end
                    if IsDisabledControlPressed(0, 173) then M.rx = Wrap(M.rx - rs) changed = true end
                    if IsDisabledControlPressed(0, 174) then M.ry = Wrap(M.ry - rs) changed = true end
                    if IsDisabledControlPressed(0, 175) then M.ry = Wrap(M.ry + rs) changed = true end
                    if IsDisabledControlJustPressed(0, 45) then M.rx, M.ry = 0.0, 0.0 changed = true end
                    if changed and GetGameTimer() - (M.lastState or 0) > 120 then M.lastState = GetGameTimer() State() end
                end
            end
            local step = IsDisabledControlPressed(0, 21) and 1.0 or 15.0
            if IsDisabledControlJustPressed(0, 241) then M.rz = (M.rz + step) % 360 State() end
            if IsDisabledControlJustPressed(0, 242) then M.rz = (M.rz - step) % 360 State() end
            SetCamCoord(M.cam, M.pos.x, M.pos.y, M.pos.z)
            SetCamRot(M.cam, M.pitch, 0.0, M.yaw, 2)
            SetFocusPosAndVel(M.pos.x, M.pos.y, M.pos.z, 0.0, 0.0, 0.0)
            -- Objet en main : suit la souris
            if M.ghost and DoesEntityExist(M.ghost) and not looking then
                local dir = CursorRay()
                local p
                if M.snap then
                    local hit, at = Raycast(dir, M.ghost)
                    if hit then
                        local mn = GetModelDimensions(GetEntityModel(M.ghost))
                        p = vector3(at.x, at.y, at.z - mn.z)
                    end
                end
                p = p or (M.pos + dir * M.dist)
                M.at = p
                SetEntityCoordsNoOffset(M.ghost, p.x, p.y, p.z, false, false, false)
                SetEntityRotation(M.ghost, M.rx, M.ry, M.rz, 2, true)
            end
            -- Aperçu 3D (survol dans la liste) : il tourne devant la caméra, à une distance adaptée à sa taille
            if M.preview and DoesEntityExist(M.preview) then
                local mn, mx = GetModelDimensions(GetEntityModel(M.preview))
                local rad = math.max(0.4, #(mx - mn) / 2)
                local c = (mn + mx) / 2
                local p = M.pos + Fwd(M.pitch, M.yaw) * (rad * 2.6 + 0.6)
                SetEntityCoordsNoOffset(M.preview, p.x - c.x, p.y - c.y, p.z - c.z, false, false, false)
                SetEntityRotation(M.preview, 0.0, 0.0, (GetGameTimer() / 20.0) % 360, 2, true)
            end
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 202) then
                if M.ghost then ClearHand() State() else Close() end
            end
            Wait(0)
        end
    end)
end

-- Clic dans le monde : poser l'objet en main, ou sélectionner un prop posé avec l'éditeur
function EditModeClick()
    if not M then return end
    if M.ghost and M.at then
        local d = { id = M.moveId, model = M.model, x = M.at.x, y = M.at.y, z = M.at.z, h = M.rz % 360, rx = M.rx, ry = M.ry, folder = M.folder }
        TriggerServerEvent('adminmenu:action', 'editor_save_prop', d)
        local keep, wasMove = M.model, M.moveId ~= nil
        if not wasMove then M.count = M.count + 1 end
        if wasMove then M.hidden = nil end   -- la mise à jour du serveur recrée le prop à sa nouvelle place
        ClearHand()
        if not wasMove then EditModePick(keep) end   -- on garde le même objet en main pour en poser d'autres
        State()
        return
    end
    local hit, _, ent = Raycast(CursorRay(), 0, 1 + 16)
    M.sel = nil
    if hit and ent and ent ~= 0 then
        local info = EditorLookup and EditorLookup(ent)
        if info then M.sel = { id = info.id, model = info.model, kind = info.kind, info = info, ent = ent } end
    end
    if not M.sel and hit then Notify('Ce n\'est pas un objet posé avec l\'éditeur.', 'info') end
    State()
end

function EditModePick(model)
    if not M or not model or model == '' then return end
    ClearHand() ClearPreview()
    M.model, M.sel = model, nil
    M.ghost = Ghost(model, 200)
    if not M.ghost then M.model = nil Notify(('Le modèle « %s » n\'existe pas ou ne se charge pas.'):format(model), 'error') end
    State()
end

function EditModeMoveSel(dup)
    if not M or not M.sel then return end
    local s = M.sel
    if s.kind ~= 'prop' then return Notify('Dans ce mode, seuls les props se déplacent (le reste : onglet Éditeur).', 'error') end
    ClearHand() ClearPreview()
    M.model = s.model
    if DoesEntityExist(s.ent) then
        local r = GetEntityRotation(s.ent, 2)
        M.rx, M.ry, M.rz = r.x, r.y, r.z % 360
        if not dup then SetEntityVisible(s.ent, false, false) M.hidden = s.ent end
    end
    if not dup then M.moveId = s.id end
    M.ghost = Ghost(s.model, 200)
    M.sel = nil
    State()
end

function EditModeDelete()
    if not M or not M.sel then return end
    if EditorDelete then EditorDelete(M.sel.info) end
    M.sel = nil
    State()
end

function EditModePreview(model)
    if not M then return end
    if model == M.previewModel then return end
    ClearPreview()
    if not model or M.ghost then return end
    M.previewModel = model
    local o = Ghost(model, 255)
    -- La souris est peut-être déjà sur un autre objet pendant le chargement
    if not M or M.previewModel ~= model or M.ghost then DelEnt(o) return end
    M.preview = o
end

RegisterNUICallback('emode', function(body, cb)
    cb({})
    if not M then return end
    local a = tostring(body.a or '')
    if a == 'click' then EditModeClick()
    elseif a == 'pick' then EditModePick(tostring(body.model or ''):lower():gsub('[^%w_%-]', ''))
    elseif a == 'preview' then EditModePreview(body.model and tostring(body.model):lower():gsub('[^%w_%-]', '') or nil)
    elseif a == 'snap' then M.snap = body.on == true State()
    elseif a == 'move' then EditModeMoveSel(false)
    elseif a == 'dup' then EditModeMoveSel(true)
    elseif a == 'delete' then EditModeDelete()
    elseif a == 'rot' then
        M.rx = Wrap(tonumber(body.rx) or M.rx) M.ry = Wrap(tonumber(body.ry) or M.ry) M.rz = (tonumber(body.rz) or M.rz) % 360
    elseif a == 'rotReset' then M.rx, M.ry = 0.0, 0.0 State()
    elseif a == 'folder' then M.folder = tonumber(body.id) or nil State()
    elseif a == 'drop' then ClearHand() State()
    elseif a == 'typing' then M.typing = body.on == true SetNuiFocusKeepInput(not M.typing)
    elseif a == 'close' then Close() end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and M then Close() end end)
