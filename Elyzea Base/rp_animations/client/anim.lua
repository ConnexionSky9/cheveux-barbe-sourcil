-- =====================================================================
--  rp_animations : lecture des clips et vérification des fichiers (client)
-- =====================================================================
RPA = RPA or {}
local A = { avail = {}, missing = {}, checked = false }
RPA.Anim = A

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

-- Vérifie tous les clips d'une fiche (role = 'A', 'B' ou nil pour les deux)
function A.CheckEntry(e, role)
    if not Catalog.IsPlayable(e) then return false, 'statut ' .. tostring(e.status) end
    for i, st in ipairs(e.steps) do
        for _, r in ipairs(role and { role } or { 'A', 'B' }) do
            local clip = st[r]
            if clip then
                local ok, why = A.ClipOk(clip)
                if not ok then return false, ('étape %d, rôle %s : %s'):format(i, r, why) end
            elseif r == 'A' or e.type == 'duo' then
                return false, ('étape %d : rôle %s sans clip'):format(i, r)
            end
        end
    end
    return true
end

-- Vérification complète en arrière-plan (au premier affichage du menu, ou /rpanim_check)
local running = false
function A.CheckAll(onDone)
    if running then return end
    running = true
    CreateThread(function()
        local missing, loaded = {}, {}
        for _, e in ipairs(Catalog.List) do
            if Catalog.IsPlayable(e) then
                local ok, why = A.CheckEntry(e)
                A.avail[e.id] = ok
                if not ok then missing[#missing + 1] = { id = e.id, n = e.n, label = e.label, why = why } end
                for _, st in ipairs(e.steps) do
                    if st.A then loaded[st.A.d] = true end
                    if st.B then loaded[st.B.d] = true end
                end
                Wait(0)
            end
        end
        -- Libère la mémoire : les dictionnaires seront rechargés au moment de jouer
        for d in pairs(loaded) do
            if not (RPA.InUseDict and RPA.InUseDict(d)) then RemoveAnimDict(d) end
        end
        A.missing, A.checked, running = missing, true, false
        if onDone then onDone(missing) end
    end)
end

function A.Flags(e)
    local flag = e.loop and 1 or 0
    if e.move then flag = flag + 48 end   -- haut du corps + le joueur peut marcher
    return flag
end

function A.Play(ped, clip, e, blendIn)
    if not A.LoadDict(clip.d) then return false end
    TaskPlayAnim(ped, clip.d, clip.c, blendIn or 2.0, -2.0, -1, A.Flags(e), 0.0, false, false, false)
    return true
end

function A.IsPlaying(ped, clip)
    return clip ~= nil and IsEntityPlayingAnim(ped, clip.d, clip.c, 3)
end

function A.StopOn(ped, clip)
    if clip then StopAnimTask(ped, clip.d, clip.c, 2.0) end
    ClearPedSecondaryTask(ped)
end

RegisterCommand('rpanim_check', function()
    print('[rp_animations] vérification des fichiers en cours…')
    A.CheckAll(function(missing)
        local total = 0
        for _, e in ipairs(Catalog.List) do if Catalog.IsPlayable(e) then total = total + 1 end end
        print(('[rp_animations] %d / %d animations jouables trouvées'):format(total - #missing, total))
        for _, m in ipairs(missing) do print(('  #%d %s (%s) : %s'):format(m.n, m.label, m.id, m.why)) end
        if RPA.Menu then RPA.Menu.PushAvail() end
    end)
end, false)
