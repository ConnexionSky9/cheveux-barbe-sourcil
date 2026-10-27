-- =====================================================================
--  ELYZEA LOISIRS - client : animations et objets tenus en main
--  Chaque dictionnaire est chargé et vérifié avant usage ; une animation absente ne bloque jamais
--  la partie (le coup est joué quand même). Clear() rend toujours la main au joueur.
-- =====================================================================
CL.Anim = {}
local A = CL.Anim
local held = {}        -- [ped] = objet tenu (local)
local mine = { dicts = {} }

function A.Load(dict)
    if not dict or not DoesAnimDictExist(dict) then CL.Dbg('animation absente', dict) return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 4000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    if HasAnimDictLoaded(dict) then mine.dicts[dict] = true return true end
    return false
end

-- Joue une animation définie dans la config : { dict, clip, flag }
function A.Play(ped, a, blend, duration)
    if not ped or not a or not A.Load(a.dict) then return false end
    TaskPlayAnim(ped, a.dict, a.clip, blend or 4.0, -4.0, duration or -1, a.flag or 0, 0.0, false, false, false)
    return true
end
function A.PlayClip(ped, dict, clip, flag, blend, duration)
    return A.Play(ped, { dict = dict, clip = clip, flag = flag }, blend, duration)
end
function A.Stop(ped, a) if ped and a then StopAnimTask(ped, a.dict, a.clip, 2.0) end end

-- Objet attaché à une main (bone = os du personnage)
function A.Hold(ped, model, h)
    A.Drop(ped)
    if not ped then return nil end
    local c = GetEntityCoords(ped)
    local o = CL.Object(model, c.x, c.y, c.z - 5.0, false)
    if not o then return nil end
    FreezeEntityPosition(o, false)
    AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, h.bone), h.pos.x, h.pos.y, h.pos.z, h.rot.x, h.rot.y, h.rot.z, true, true, false, false, 2, true)
    held[ped] = o
    return o
end
function A.Held(ped) return held[ped] end
function A.Drop(ped)
    local o = ped and held[ped]
    if o then CL.Delete(o) held[ped] = nil end
end

-- Bloque les actions qui gêneraient un coup (tir, saut, course, armes)
function A.LockControls()
    DisableControlAction(0, 21, true)   -- sprint
    DisableControlAction(0, 22, true)   -- saut / espace
    DisableControlAction(0, 24, true)   -- attaque
    DisableControlAction(0, 25, true)   -- viser
    DisableControlAction(0, 37, true)   -- roue des armes
    DisableControlAction(0, 44, true)   -- couverture (Q)
    DisableControlAction(0, 140, true) DisableControlAction(0, 141, true) DisableControlAction(0, 142, true)
    DisableControlAction(0, 23, true)   -- entrer dans un véhicule
    DisableControlAction(0, 14, true) DisableControlAction(0, 15, true) DisableControlAction(0, 16, true) DisableControlAction(0, 17, true)
end

-- Remet le joueur dans un état normal : plus d'animation, plus d'objet, mouvements libres
function A.Clear()
    local ped = PlayerPedId()
    A.Drop(ped)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    if CL.Cam and CL.Cam.Stop then CL.Cam.Stop() end
end

-- Objets tenus par d'autres joueurs (affichés chez moi) : nettoyés quand ils ne jouent plus
function A.DropAllOthers()
    for ped, o in pairs(held) do
        if ped ~= PlayerPedId() then CL.Delete(o) held[ped] = nil end
    end
end

-- ---------------------------------------------------------------- caméra de jeu (facultative, touche C)
CL.Cam = {}
local cam
function CL.Cam.Set(from, to, fov)
    if not cam then
        cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', from.x, from.y, from.z, 0.0, 0.0, 0.0, fov or 50.0, false, 2)
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 400, true, false)
    end
    SetCamCoord(cam, from.x, from.y, from.z)
    PointCamAtCoord(cam, to.x, to.y, to.z)
    if fov then SetCamFov(cam, fov) end
end
function CL.Cam.Active() return cam ~= nil end
function CL.Cam.Stop()
    if cam then
        RenderScriptCams(false, true, 400, true, false)
        DestroyCam(cam, false)
        cam = nil
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    CL.Cam.Stop()
    for ped, o in pairs(held) do if DoesEntityExist(o) then DeleteEntity(o) end end
    for d in pairs(mine.dicts) do RemoveAnimDict(d) end
end)
