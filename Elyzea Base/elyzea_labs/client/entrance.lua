-- =====================================================================
--  ELYZEA LABS · client : entrées extérieures, code, intérieur, cercles
--  Extérieur : marqueur à l'entrée, E → menu (entrer, code, acheter, attaquer).
--  Intérieur : ROUGE sortie · BLEU gestion des équipements (éditeur) · ORANGE coffre.
--  Les équipements posés sont des objets locaux recréés à chaque entrée (client/production.lua).
-- =====================================================================
local C = LabC
local COL = { entrance = { 168, 85, 247 }, exit = { 239, 68, 68 }, manage = { 59, 130, 246 }, stash = { 249, 115, 22 } }

RegisterNetEvent('elyzea_labs:labs', function(list)
    C.labs = {}
    for _, l in ipairs(list or {}) do C.labs[l.id] = l end
end)

-- Intérieur : décor (« entity sets ») de l'intérieur du jeu
local function applyInterior(it)
    local id = GetInteriorAtCoords(it.check.x + 0.0, it.check.y + 0.0, it.check.z + 0.0)
    if id == 0 then return end
    PinInteriorInMemory(id)
    for _, set in ipairs(it.entitySets or {}) do
        if not IsInteriorEntitySetActive(id, set) then ActivateInteriorEntitySet(id, set) end
    end
    RefreshInterior(id)
end

local function openEntrance(lab)
    local r = C.Pub('entrance', { lab = lab.id })
    if r.error then return C.Notify(r.error, 'error') end
    C.Open('entrance', r)
end

RegisterNUICallback('entranceAction', function(body, cb)
    local lab = tonumber(body.lab)
    local act = tostring(body.action or '')
    if act == 'enter' then
        local r = C.Pub('enter', { lab = lab, code = body.code })
        cb(r)
        if r.ok then C.Close() elseif r.error and not r.needCode then C.Notify(r.error, 'error') end
    elseif act == 'buy' then
        local r = C.Pub('buy', { lab = lab })
        cb(r)
        if r.ok then C.Close() C.Notify(r.message, 'success') elseif r.error then C.Notify(r.error, 'error') end
    elseif act == 'raid' then
        local r = C.Pub('raidStart', { lab = lab })
        cb(r)
        C.Show(r)
        if r.ok then C.Close() end
    else cb({}) end
end)

RegisterNetEvent('elyzea_labs:enter', function(d)
    C.Close()
    C.Fade(true)
    C.inside = d
    applyInterior(d.interior)
    C.Teleport(d.interior.spawn)
    if C.SpawnEquipment then C.SpawnEquipment(d.equipment or {}) end
    C.Fade(false)
    C.Notify(('Laboratoire · %s%s'):format(d.name, d.staff and ' (staff)' or ''), 'inform')
end)

RegisterNetEvent('elyzea_labs:rights', function(d)
    if not C.inside or C.inside.id ~= d.id then return end
    C.inside.rights, C.inside.role, C.inside.level, C.inside.interior = d.rights, d.role, d.level, d.interior
    if C.ui == 'tablet' and C.RefreshTablet then C.RefreshTablet() end
end)

RegisterNetEvent('elyzea_labs:exit', function(p, reason)
    if C.EditorCancel then C.EditorCancel() end
    if C.CraftAbort then C.CraftAbort() end
    C.Close()
    C.Fade(true)
    if C.ClearEquipment then C.ClearEquipment() end
    C.inside = nil
    if p then C.Teleport({ x = p.x, y = p.y, z = p.z, h = p.h }) end
    C.Fade(false)
    if reason then C.Notify(reason, 'inform') end
end)

-- Test d'intérieur (staff)
local testing = nil
RegisterNetEvent('elyzea_labs:test', function(it)
    testing = { back = GetEntityCoords(PlayerPedId()), it = it }
    C.Fade(true) applyInterior(it) C.Teleport(it.spawn) C.Fade(false)
end)
RegisterNetEvent('elyzea_labs:testEnd', function()
    if not testing then return end
    local b = testing.back
    testing = nil
    C.Fade(true) C.Teleport({ x = b.x, y = b.y, z = b.z }) C.Fade(false)
end)

-- Boucle : entrées dehors, cercles dedans
CreateThread(function()
    while true do
        local sleep = 800
        local ped = PlayerPedId()
        local pc = GetEntityCoords(ped)
        if C.inside and not C.ui and not (C.Editing and C.Editing()) then
            sleep = 0
            local it = C.inside.interior
            local rights = C.inside.rights or {}
            local prompt, action
            local function circle(p, color, label, fn, allowed)
                if not p then return end
                C.Circle(p, color, 1.0)
                if allowed ~= false and #(pc - C.Vec(p)) <= Config.InteractDistance then prompt, action = '~INPUT_CONTEXT~ ' .. label, fn end
            end
            circle(it.spawn, COL.exit, 'Sortir du laboratoire', function() C.Show(C.Pub('exit')) end)
            circle(it.manage, COL.manage, 'Gestion des équipements', function() if C.OpenEditorMenu then C.OpenEditorMenu() end end, rights.equipment == true)
            circle(it.stash, COL.stash, 'Coffre du laboratoire', function() C.Show(C.Pub('stash', { lab = C.inside.id })) end, rights.stash == true)
            if not prompt and C.NearEquipment then
                local e = C.NearEquipment(pc)
                if e then prompt, action = ('~INPUT_CONTEXT~ Utiliser : %s'):format(e.label), function() C.OpenCraft(e) end end
            end
            if prompt then
                C.Help(prompt)
                if IsControlJustPressed(0, Config.InteractKey) then action() end
            end
        elseif not C.inside and not C.ui then
            for id, l in pairs(C.labs) do
                local d = #(pc - vector3(l.x, l.y, l.z))
                if d < 25.0 and not l.disabled then
                    sleep = 0
                    DrawMarker(1, l.x, l.y, l.z - 1.0, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.6, COL.entrance[1], COL.entrance[2], COL.entrance[3], l.raid and 200 or 120, false, false, 2, false, nil, nil, false)
                    if d <= Config.InteractDistance then
                        C.Help(('~INPUT_CONTEXT~ %s%s'):format(l.name, l.raid and ' (attaque en cours)' or ''))
                        if IsControlJustPressed(0, Config.InteractKey) and not IsPedInAnyVehicle(ped, false) then openEntrance(l) end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    C.Close()
    if C.ClearEquipment then C.ClearEquipment() end
    if IsScreenFadedOut() then DoScreenFadeIn(0) end
end)
