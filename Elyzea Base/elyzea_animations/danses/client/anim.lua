-- =====================================================================
--  Danses : lecture des clips et vérification des fichiers (client)
-- =====================================================================
Danse = Danse or {}
local A = { avail = {} }
Danse.Anim = A

function A.LoadDict(d, timeout)
    if not d or not DoesAnimDictExist(d) then return false end
    if HasAnimDictLoaded(d) then return true end
    RequestAnimDict(d)
    local t = GetGameTimer() + (timeout or 3000)
    while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(d)
end

-- Le clip existe vraiment : dictionnaire présent ET clip de durée non nulle
function A.ClipOk(clip)
    if not clip or not A.LoadDict(clip.d) then return false, 'dictionnaire absent : ' .. tostring(clip and clip.d) end
    if GetAnimDuration(clip.d, clip.c) <= 0.0 then return false, ('clip absent : %s / %s'):format(clip.d, clip.c) end
    return true
end

-- Vérifie les clips d'une danse pour un rôle ('A', 'B') ou pour les deux (nil)
function A.CheckEntry(e, role)
    if not DanseCatalog.IsPlayable(e) then return false, 'danse indisponible' end
    for i, st in ipairs(e.steps) do
        for _, r in ipairs(role and { role } or (e.type == 'duo' and { 'A', 'B' } or { 'A' })) do
            local ok, why = A.ClipOk(st[r])
            if not ok then return false, ('étape %d, rôle %s : %s'):format(i, r, why) end
        end
    end
    return true
end

-- Vérifie toutes les danses (arrière-plan) : sert à masquer celles dont les fichiers manquent
function A.CheckAll(onDone)
    CreateThread(function()
        local missing = {}
        for _, e in ipairs(DanseCatalog.List) do
            local ok, why = A.CheckEntry(e)
            A.avail[e.id] = ok
            if not ok then missing[#missing + 1] = { id = e.id, label = e.label, why = why } end
            Wait(0)
        end
        A.missing = missing
        if onDone then onDone(missing) end
    end)
end

-- Drapeaux de lecture : boucle (1) ou une fois (0), haut du corps seulement si le joueur peut marcher
function A.Play(ped, clip, loop, blendIn)
    if not A.LoadDict(clip.d) then return false end
    TaskPlayAnim(ped, clip.d, clip.c, blendIn or 2.0, -2.0, -1, loop and 1 or 0, 0.0, false, false, false)
    return true
end

function A.IsPlaying(ped, clip)
    return clip ~= nil and IsEntityPlayingAnim(ped, clip.d, clip.c, 3)
end

function A.StopOn(ped, clip)
    if clip then StopAnimTask(ped, clip.d, clip.c, 2.0) end
    ClearPedSecondaryTask(ped)
end
