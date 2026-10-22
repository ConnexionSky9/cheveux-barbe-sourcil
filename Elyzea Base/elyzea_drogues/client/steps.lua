-- =====================================================================
--  ELYZEA DROGUES · étape immersive (client) : placement → animation + objets → mini-jeu → finition → nettoyage
--  Utilisé par les postes, la récolte et les pots (client/alt.lua) et par elyzea_labs (export RunStep).
--  Quoi qu'il arrive (annulation, mort, chute, erreur, arrêt de la ressource) : curseur rendu,
--  personnage débloqué et relevé, objets temporaires supprimés.
-- =====================================================================
DrugStep = { active = nil }
local ST = DrugStep

RegisterNUICallback('mgResult', function(data, cb)
    cb({})
    local A = ST.active
    if A and type(data) == 'table' and tonumber(data.id) == A.gameId then A.result = data end
end)

local function offsets(siteType) return (((DrugFx and DrugFx.settings) or {}).sceneOffsets or {})[siteType or ''] end

local function cleanup(A)
    local ped = PlayerPedId()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'mg:stop' })
    for _, o in ipairs(A.props) do if DoesEntityExist(o) then DetachEntity(o, true, false) DeleteEntity(o) end end
    if A.netReported then TriggerServerEvent('elyzea_drogues:sceneProps', nil) end
    DrugScene.StopAnim(ped, A.played)
    if A.sat then DrugScene.StandUp(ped, A.sat)
    elseif A.frozen then FreezeEntityPosition(ped, false) end
end

-- opts : { game (défi du serveur), profile (clé de Config.Steps), entity (poste / plante), chair, siteType, duration (s) }
-- Renvoie le résultat du mini-jeu : { id, ok, done, mistakes, ms, cancelled, reason }
function ST.Run(opts)
    if ST.active then return { cancelled = true, reason = 'busy' } end
    local p = Config.Steps[opts.profile or ''] or {}
    local game = opts.game or {}
    local A = { gameId = tonumber(game.id), props = {} }
    ST.active = A
    local t0 = GetGameTimer()
    local okRun, res = pcall(function()
        local ped = PlayerPedId()
        local ent = opts.entity
        -- 1. placement
        if p.pose == 'seat' and opts.chair and DoesEntityExist(opts.chair) then
            A.sat = DrugScene.Sit(ped, opts.chair, offsets(opts.siteType))
            if not A.sat then return { id = game.id, cancelled = true, reason = 'move' } end
        elseif p.pose ~= 'here' and Config.Minigames.walkToStation ~= false and ent and DoesEntityExist(ent) then
            local pt, hd = DrugScene.ApproachPoint(ent, ped)
            if not DrugScene.WalkTo(ped, pt.x, pt.y, hd) then return { id = game.id, cancelled = true, reason = 'move' } end
        elseif ent and DoesEntityExist(ent) then
            local c = GetEntityCoords(ent)
            TaskTurnPedToFaceCoord(ped, c.x, c.y, c.z, 600)
            Wait(650)
        end
        if not A.sat then FreezeEntityPosition(ped, true) A.frozen = true end
        -- 2. animation et objets
        A.played = DrugScene.PlayAnim(ped, p.anim)
        local net = Config.Minigames.networkProps ~= false
        if p.hand then local o = DrugScene.Hand(ped, p.hand, net) if o then A.props[#A.props + 1] = o end end
        for _, spec in ipairs(p.temp or {}) do local o = DrugScene.Place(ent, spec, net) if o then A.props[#A.props + 1] = o end end
        if net and #A.props > 0 then
            local ids = {}
            for _, o in ipairs(A.props) do if NetworkGetEntityIsNetworked(o) then ids[#ids + 1] = ObjToNet(o) end end
            if #ids > 0 then TriggerServerEvent('elyzea_drogues:sceneProps', ids) A.netReported = true end
        end
        -- 3. mini-jeu
        SendNUIMessage({ action = 'mg:start', game = game })
        SetNuiFocus(true, true)
        local start = GetGameTimer()
        local limitMs = ((tonumber(game.limit) or 60) + 15) * 1000
        while not A.result do
            Wait(100)
            if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, false) then
                A.result = { id = game.id, cancelled = true, reason = 'interrupt' }
            elseif GetGameTimer() - start > limitMs then
                A.result = { id = game.id, cancelled = true, reason = 'timeout' }
            elseif A.played and A.played.dict and not IsEntityPlayingAnim(ped, A.played.dict, A.played.clip, 3) then
                TaskPlayAnim(ped, A.played.dict, A.played.clip, 3.0, 3.0, -1, A.played.flag or 1, 0, false, false, false)
            end
        end
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'mg:stop' })
        local r = A.result
        -- 4. finition : la durée de la recette (inchangée) reste le minimum demandé par le serveur
        if r.ok then
            local left = math.floor((tonumber(opts.duration) or 0) * 1000 - (GetGameTimer() - t0) + 700)
            if left > 300 then
                local done = exports.elyzea_core:ProgressBar({ duration = left, label = 'Finition…', canCancel = true, disable = { move = true, car = true, combat = true } })
                if not done then r = { id = r.id, cancelled = true, reason = 'cancel' } end
            end
        end
        return r
    end)
    cleanup(A)
    ST.active = nil
    if not okRun then
        print(('^1[elyzea_drogues] étape %s : %s^0'):format(tostring(opts.profile), tostring(res)))
        return { id = game.id, cancelled = true, reason = 'error' }
    end
    return res
end

-- Récolte (sans mini-jeu) : se tourner vers la plante, animation adaptée + objet tenu, barre de progression.
-- opts : { scene = Config.HarvestScenes[...], entity, duration (s), label }. Renvoie true si la barre est allée au bout.
function ST.Simple(opts)
    if ST.active then return false end
    local A = { props = {}, simple = true }
    ST.active = A
    local okRun, done = pcall(function()
        local ped = PlayerPedId()
        local ent, sc = opts.entity, opts.scene or {}
        if ent and DoesEntityExist(ent) then
            local c = GetEntityCoords(ent)
            TaskTurnPedToFaceCoord(ped, c.x, c.y, c.z, 600)
            Wait(650)
        end
        FreezeEntityPosition(ped, true) A.frozen = true
        A.played = DrugScene.PlayAnim(ped, sc.anim)
        if sc.hand then local o = DrugScene.Hand(ped, sc.hand, false) if o then A.props[#A.props + 1] = o end end
        return exports.elyzea_core:ProgressBar({ duration = math.floor((tonumber(opts.duration) or 5) * 1000), label = opts.label, canCancel = true,
            disable = { move = true, car = true, combat = true } })
    end)
    cleanup(A)
    ST.active = nil
    if not okRun then print(('^1[elyzea_drogues] récolte : %s^0'):format(tostring(done))) return false end
    return done == true
end

-- Arrêt de la ressource en plein mini-jeu : on rend la main proprement
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not ST.active then return end
    cleanup(ST.active)
    ST.active = nil
end)

-- ---------------------------------------------------------------- exports (elyzea_labs)
-- RunStep : lance l'étape dans un fil de elyzea_drogues ; le résultat arrive par l'événement local
--   « elyzea_drogues:stepDone » (id, résultat). Renvoie l'id, ou false si une étape est déjà en cours.
local nextId = 0
exports('RunStep', function(opts)
    if ST.active or type(opts) ~= 'table' then return false end
    nextId = nextId + 1
    local id = nextId
    CreateThread(function() TriggerEvent('elyzea_drogues:stepDone', id, ST.Run(opts)) end)
    return id
end)
exports('StepActive', function() return ST.active ~= nil end)
-- Interrompt l'étape en cours (sortie du laboratoire, attaque…) : nettoyage normal, résultat « annulé »
exports('StopStep', function()
    local A = ST.active
    if A and not A.tuning and not A.result then A.result = { id = A.gameId, cancelled = true, reason = 'interrupt' } end
end)

-- Décor d'un équipement de laboratoire : renvoie la liste des objets créés (à supprimer par l'appelant)
exports('SpawnDecor', function(entity, decorKey)
    local d = Config.Decor[decorKey or '']
    local out = {}
    if not d or not entity or not DoesEntityExist(entity) then return out end
    for _, spec in ipairs(d.props or {}) do local o = DrugScene.Place(entity, spec, false) if o then out[#out + 1] = o end end
    if d.seat then local c = DrugScene.PlaceChair(entity) if c then out[#out + 1] = c end end
    return out
end)

-- ---------------------------------------------------------------- vérification des modèles et animations (F8)
RegisterCommand('drogues_verif', function()
    local missM, missA, nM, nA = {}, {}, 0, 0
    local seen = {}
    local function model(m) if seen[m] then return end seen[m] = true nM = nM + 1 if not IsModelInCdimage(GetHashKey(m)) then missM[#missM + 1] = m end end
    for _, list in pairs(Config.SceneModels) do for _, m in ipairs(list) do model(m) end end
    for _, st in pairs(Config.Stations) do for _, m in ipairs(st.models or {}) do model(m) end end
    for _, h in pairs(Config.Harvest) do for _, m in ipairs(h.models or {}) do model(m) end end
    local seenA = {}
    for _, a in pairs(Config.SceneAnims) do
        local s = a
        while s do
            if s.dict and not seenA[s.dict] then seenA[s.dict] = true nA = nA + 1 if not DoesAnimDictExist(s.dict) then missA[#missA + 1] = s.dict end end
            s = s.fb
        end
    end
    -- un profil sans aucun modèle disponible dans sa liste reste jouable (l'objet est simplement absent)
    print(('^2[elyzea_drogues] Vérification : %d modèle(s), %d dictionnaire(s) d\'animation.^0'):format(nM, nA))
    if #missM > 0 then print('^3Modèles absents (ignorés, un autre candidat est utilisé s\'il existe) :^0 ' .. table.concat(missM, ', ')) end
    if #missA > 0 then print('^3Animations absentes (le repli est joué) :^0 ' .. table.concat(missA, ', ')) end
    if #missM == 0 and #missA == 0 then print('^2Tout est présent dans le jeu.^0') end
    DrugFx.notify(('Vérification : %d modèle(s) et %d animation(s) absents — détail en F8.'):format(#missM, #missA), (#missM + #missA) > 0 and 'inform' or 'success')
end, false)

-- ---------------------------------------------------------------- réglage de l'assise (staff « drugs_manage »)
-- /drogues_assise près d'un poste avec chaise : le personnage s'assoit, les flèches le déplacent,
-- Page haut / bas la hauteur, Q / E la rotation, Entrée enregistre (pour tous les postes de ce type), Retour annule.
RegisterCommand('drogues_assise', function()
    if ST.active then return end
    if not Ely.callback.await('elyzea_drogues:canTune', false) then return DrugFx.notify('Réservé au staff (gestion des drogues).', 'error') end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local best, bd
    for id, s in pairs(DrugWorld.sites) do
        local c = DrugWorld.Chair(id)
        if c then local d = #(pos - GetEntityCoords(c)) if d < 4.0 and (not bd or d < bd) then best, bd = s, d end end
    end
    if not best then return DrugFx.notify('Approche-toi d\'un poste avec une chaise (table de manucure).', 'error') end
    local chair = DrugWorld.Chair(best.id)
    local cur = offsets(best.type) or {}
    local off = { x = cur.x or 0.0, y = cur.y or 0.0, z = cur.z or 0.0, h = cur.h or 0.0 }
    local p = Config.Steps.weed_trim or {}
    ST.active = { props = {}, tuning = true }
    local sat = DrugScene.Sit(ped, chair, off)
    if not sat then ST.active = nil return end
    local played = DrugScene.PlayAnim(ped, p.anim)
    local function apply()
        local seat = GetOffsetFromEntityInWorldCoords(chair, off.x, off.y + 0.05, 0.0)
        SetEntityCoordsNoOffset(ped, seat.x, seat.y, sat.z + off.z, false, false, false)
        SetEntityHeading(ped, sat.heading + off.h)
    end
    local save = false
    while true do
        Wait(0)
        local step = IsControlPressed(0, 21) and 0.05 or 0.01   -- Maj : plus rapide
        local changed = false
        if IsControlJustPressed(0, 172) then off.y = off.y + step changed = true end
        if IsControlJustPressed(0, 173) then off.y = off.y - step changed = true end
        if IsControlJustPressed(0, 174) then off.x = off.x - step changed = true end
        if IsControlJustPressed(0, 175) then off.x = off.x + step changed = true end
        if IsControlJustPressed(0, 10) then off.z = off.z + step changed = true end
        if IsControlJustPressed(0, 11) then off.z = off.z - step changed = true end
        if IsControlJustPressed(0, 44) then off.h = off.h - 2.0 changed = true end
        if IsControlJustPressed(0, 38) then off.h = off.h + 2.0 changed = true end
        if changed then apply() end
        exports.elyzea_core:ShowTextUI(('Assise : X %.2f · Y %.2f · Z %.2f · rot %.0f° — Flèches, Page ↑/↓, Q/E · Entrée enregistrer · Retour annuler'):format(off.x, off.y, off.z, off.h))
        if IsControlJustPressed(0, 191) then save = true break end
        if IsControlJustPressed(0, 194) or IsEntityDead(ped) then break end
    end
    exports.elyzea_core:HideTextUI()
    DrugScene.StopAnim(ped, played)
    DrugScene.StandUp(ped, sat)
    ST.active = nil
    if save then
        local r = Ely.callback.await('elyzea_drogues:saveSeat', false, best.type, off) or {}
        DrugFx.notify(r.ok and 'Assise enregistrée pour ce type de poste.' or (r.error or 'Le serveur ne répond pas.'), r.ok and 'success' or 'error')
    end
end, false)
