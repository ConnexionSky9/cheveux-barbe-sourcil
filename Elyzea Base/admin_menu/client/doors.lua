-- =========================================================
--  PORTES ET PORTAILS VERROUILLABLES
--  Les portes de la map sont verrouillées avec le système de portes
--  du jeu (DoorSystem) : aucun objet n'est supprimé ni recréé.
--  À l'approche : petit cadenas Elyzea FA posé sur la porte (aucun texte).
--  E : le serveur vérifie les clés. Clés : le cadenas s'ouvre, puis la porte
--  se déverrouille et s'entrouvre. Sans clés : le cadenas reste fermé (il tremble).
-- =========================================================
local DC = Config.Doors
local registered = {}   -- [hashPorte] = true
local doorOpen = false   -- panneau ouvert
local panelOpen = false  -- pupitre de commande ouvert
local nearPanel = nil    -- pupitre à portée (prioritaire sur les portes pour la touche E)
if type(LastInteract) ~= 'number' then LastInteract = 0 end

local function leafHash(id, i) return GetHashKey(('am_door_%d_%d'):format(id, i)) end
local openFor = {}       -- [idPorte] = GetGameTimer() : déverrouillée par moi, à entrouvrir
local OPEN_RATIO = 0.55  -- entrouverture après déverrouillage (sens choisi selon le côté du joueur)

-- Entrouvre une porte que je viens de déverrouiller (côté opposé au joueur)
local function pushOpen(d)
    local p = GetEntityCoords(PlayerPedId())
    for i, l in ipairs(d.leaves) do
        local ent = GetClosestObjectOfType(l.x, l.y, l.z, 1.5, l.model, false, false, false)
        local side = 1.0
        if ent ~= 0 then
            local f = GetEntityForwardVector(ent)
            if (p.x - l.x) * f.x + (p.y - l.y) * f.y > 0 then side = -1.0 end
        end
        DoorSystemSetOpenRatio(leafHash(d.id, i), OPEN_RATIO * side * (i == 2 and -1.0 or 1.0), false, false)
    end
end

-- Applique l'état de toutes les portes (appelé à chaque synchro)
function RefreshDoors()
    local alive = {}
    for _, d in ipairs(Editor.doors or {}) do
        for i, l in ipairs(d.leaves) do
            local h = leafHash(d.id, i)
            alive[h] = true
            if not registered[h] or not IsDoorRegisteredWithSystem(h) then
                AddDoorToSystem(h, l.model, l.x, l.y, l.z, false, false, false)
                registered[h] = true
            end
            DoorSystemSetDoorState(h, d.locked and 1 or 0, false, false)
            if d.locked then DoorSystemSetOpenRatio(h, 0.0, false, false) end
        end
        if not d.locked and openFor[d.id] then
            if GetGameTimer() - openFor[d.id] < 4000 then pushOpen(d) end
            openFor[d.id] = nil
        end
    end
    for h in pairs(registered) do
        if not alive[h] then
            if IsDoorRegisteredWithSystem(h) then RemoveDoorFromSystem(h) end
            registered[h] = nil
        end
    end
end

-- Ré-application régulière (certaines portes se réinitialisent quand la zone recharge)
CreateThread(function()
    while true do
        Wait(10000)
        if Editor.doors and #Editor.doors > 0 then RefreshDoors() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for h in pairs(registered) do
        if IsDoorRegisteredWithSystem(h) then
            DoorSystemSetDoorState(h, 0, false, false)
            RemoveDoorFromSystem(h)
        end
    end
end)

-- ---------------------------------------------------------
--  Interaction des joueurs (touche E, la même que la récolte)
--  Cadenas Elyzea FA dessiné sur la porte (textures html/img/lock_*.png), aucun texte.
-- ---------------------------------------------------------
local nearDoor = nil
local TXD = 'am_elylock'
CreateThread(function()
    local txd = CreateRuntimeTxd(TXD)
    for _, n in ipairs({ 'lock_body', 'lock_shackle', 'lock_shackle_open', 'lock_halo' }) do
        CreateRuntimeTextureFromImage(txd, n, ('html/img/%s.png'):format(n))
    end
end)

-- Animation en cours par porte : { kind = 'unlock' | 'lock' | 'deny', t0 }
local lockFx = {}
RegisterNetEvent('adminmenu:door:lockfx', function(id, kind)
    id = tonumber(id)
    if not id or (kind ~= 'unlock' and kind ~= 'lock' and kind ~= 'deny') then return end
    lockFx[id] = { kind = kind, t0 = GetGameTimer() }
    if kind == 'unlock' then
        openFor[id] = GetGameTimer() + 800
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    elseif kind == 'lock' then
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    else
        PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
end)

-- Centre visuel de la porte (milieu du ou des battants, d'après la forme du modèle)
local centerCache = {}   -- [idPorte] = { at, pos }
local function doorCenter(d)
    local c = centerCache[d.id]
    if c and GetGameTimer() - c.at < 1500 then return c.pos end
    local sx, sy, sz, n = 0.0, 0.0, 0.0, 0
    for _, l in ipairs(d.leaves) do
        local ent = GetClosestObjectOfType(l.x, l.y, l.z, 1.5, l.model, false, false, false)
        local w
        if ent ~= 0 and DoesEntityExist(ent) then
            local mn, mx = GetModelDimensions(l.model)
            w = GetOffsetFromEntityInWorldCoords(ent, (mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
        else
            w = vector3(l.x, l.y, l.z + 1.0)
        end
        sx, sy, sz, n = sx + w.x, sy + w.y, sz + w.z, n + 1
    end
    local pos = vector3(sx / n, sy / n, sz / n)
    centerCache[d.id] = { at = GetGameTimer(), pos = pos }
    return pos
end

local function easeOut(t) t = math.min(1.0, math.max(0.0, t)) return 1 - (1 - t) ^ 3 end

-- Dessine le cadenas. fade : 0..1 (apparition selon la distance)
local function drawLock(d, fade)
    local w = doorCenter(d)
    local on, sx, sy = GetScreenCoordFromWorldCoord(w.x, w.y, w.z)
    if not on then return end
    local dist = #(GetGameplayCamCoord() - w)
    local h = math.min(0.07, math.max(0.032, 0.11 / math.max(dist, 0.5)))   -- taille à l'écran
    local ar = GetAspectRatio(false)
    local wd = h / ar
    local fx = lockFx[d.id]
    local now = GetGameTimer()
    local t = fx and (now - fx.t0) or 1e9
    local locked = d.locked
    local open = not locked                       -- anse ouverte ?
    local lift = 0.0                              -- montée de l'anse (fraction de la hauteur)
    local shake = 0.0
    local halo = { 155, 92, 255 }                 -- violet Elyzea
    local haloA = 70
    local pop = 1.0
    if fx and fx.kind == 'unlock' and t < 1200 then
        if t < 260 then lift = 0.12 * easeOut(t / 260) open = false              -- l'anse monte
        else open = true end                                                    -- puis bascule ouverte
        halo, haloA = { 62, 230, 176 }, math.floor(150 * (1 - math.min(1, t / 1200)) + 60)
        pop = 1.0 + 0.12 * math.sin(math.min(1, t / 400) * math.pi)
    elseif fx and fx.kind == 'lock' and t < 900 then
        if t < 220 then open = true else open = false lift = 0.12 * (1 - easeOut((t - 220) / 200)) end
        haloA = math.floor(150 * (1 - math.min(1, t / 900)) + 60)
        pop = 1.0 + 0.08 * math.sin(math.min(1, t / 360) * math.pi)
    elseif fx and fx.kind == 'deny' and t < 650 then
        open = false
        shake = math.sin(t / 22) * 0.006 * (1 - t / 650)
        halo, haloA = { 255, 77, 109 }, math.floor(170 * (1 - t / 650) + 50)
    elseif fx then
        lockFx[d.id] = nil
        fx = nil
    end
    local a = math.floor(255 * fade * (open and not fx and 0.55 or 1.0))   -- porte ouverte : cadenas plus discret
    if a <= 0 then return end
    h, wd = h * pop, wd * pop
    local x = sx + shake
    DrawSprite(TXD, 'lock_halo', x, sy + h * 0.08, wd * 1.9, h * 1.9, 0.0, halo[1], halo[2], halo[3], math.floor(haloA * fade))
    DrawSprite(TXD, open and 'lock_shackle_open' or 'lock_shackle', x, sy - h * lift, wd, h, 0.0, 255, 255, 255, a)
    DrawSprite(TXD, 'lock_body', x, sy, wd, h, 0.0, 255, 255, 255, a)
end

CreateThread(function()
    local seen = {}   -- [idPorte] = GetGameTimer() d'apparition (fondu)
    while true do
        -- Chaque porte a sa propre distance d'ouverture (sinon celle de la config)
        local found, bestRatio = nil, 1.0
        local doors = Editor.doors or {}
        if #doors > 0 and not doorOpen and not panelOpen and not nearPanel and not IsNoclipActive() and not (NearTeleport and NearTeleport()) then
            local p = GetEntityCoords(PlayerPedId())
            for _, d in ipairs(doors) do
                local reach = d.distance or DC.interactDistance
                for _, l in ipairs(d.leaves) do
                    local dx, dy, dz = l.x - p.x, l.y - p.y, l.z - p.z
                    local ratio = math.sqrt(dx * dx + dy * dy + dz * dz) / reach
                    if ratio <= bestRatio then bestRatio, found = ratio, d end
                end
            end
        end
        nearDoor = found
        -- l'animation se termine même si le joueur s'éloigne un peu
        local anim = nil
        if not found then for id in pairs(lockFx) do for _, d in ipairs(doors) do if d.id == id then anim = d end end end end
        local show = found or anim
        Wait(show and 0 or 400)
        if show and not IsPauseMenuActive() then
            if not seen[show.id] then seen = { [show.id] = GetGameTimer() } end
            drawLock(show, math.min(1.0, (GetGameTimer() - seen[show.id]) / 180))
        elseif not show then
            seen = {}
        end
    end
end)

local lastHandled = 0
CreateThread(function()
    while true do
        Wait(50)
        if nearPanel and LastInteract > lastHandled then
            lastHandled = LastInteract
            TriggerServerEvent('adminmenu:doorpanel:open', nearPanel.id)
        elseif nearDoor and LastInteract > lastHandled then
            lastHandled = LastInteract
            -- E : ouverture/fermeture directe pour les détenteurs des clés.
            -- Les visiteurs reçoivent uniquement le pavé de code si un code existe.
            TriggerServerEvent('adminmenu:door:interact', nearDoor.id)
        elseif LastInteract > lastHandled then
            lastHandled = LastInteract
        end
    end
end)

-- Les détenteurs des clés peuvent gérer le code invité sans utiliser E.
-- Utilisation : se placer près de la porte puis taper /codeporte.
RegisterCommand('codeporte', function()
    if nearDoor then
        TriggerServerEvent('adminmenu:door:managecode', nearDoor.id)
    else
        Notify('Approche-toi d’une porte pour gérer son code.', 'error')
    end
end, false)

RegisterNetEvent('adminmenu:door:panel', function(data)
    doorOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'door', data = data })
end)
RegisterNUICallback('door_close', function(_, cb) doorOpen = false SetNuiFocus(false, false) cb('ok') end)
RegisterNUICallback('door_toggle', function(b, cb) cb('ok') TriggerServerEvent('adminmenu:door:toggle', b.id, b.code) end)
RegisterNUICallback('door_setcode', function(b, cb) cb('ok') TriggerServerEvent('adminmenu:door:setcode', b.id, b.code) end)

-- ---------------------------------------------------------
--  STAFF : choisir une porte (ou les deux battants d'une porte double)
-- ---------------------------------------------------------
local picking = nil
function IsDoorPick() return picking ~= nil end

local function aimObject()
    local rot = GetGameplayCamRot(2)
    local zr, xr = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(xr))
    local from = GetGameplayCamCoord()
    local to = from + vector3(-math.sin(zr) * n, math.cos(zr) * n, math.sin(xr)) * 30.0
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 16, PlayerPedId(), 7)
    local _, hit, _, _, ent = GetShapeTestResult(ray)
    if hit == 1 and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 3 and not NetworkGetEntityIsNetworked(ent) then
        return ent
    end
    return 0
end

function DoorPickKey(id)
    if not picking then return false end
    if id == 'confirm' then
        local e = picking.aim
        if e and e ~= 0 then
            for _, l in ipairs(picking.leaves) do
                if l.ent == e then return true, Notify('Ce battant est déjà sélectionné.', 'info') end
            end
            if #picking.leaves >= 2 then return true, Notify('2 battants maximum (porte double).', 'error') end
            local c = GetEntityCoords(e)
            picking.leaves[#picking.leaves + 1] = { ent = e, model = GetEntityModel(e), x = c.x, y = c.y, z = c.z }
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        else
            Notify('Vise une porte ou un portail.', 'error')
        end
    elseif id == 'cancel' then
        if #picking.leaves > 0 then table.remove(picking.leaves) else picking = nil end
    elseif id == 'finish' then
        if #picking.leaves == 0 then return true, Notify('Sélectionne au moins une porte avec Valider.', 'error') end
        local leaves = {}
        for _, l in ipairs(picking.leaves) do leaves[#leaves + 1] = { model = l.model, x = l.x, y = l.y, z = l.z } end
        TriggerServerEvent('adminmenu:action', 'editor_add_door', { leaves = leaves, name = picking.name })
        picking = nil
    end
    return true
end

local function pickLoop()
    while picking do
        Wait(0)
        local p = picking
        if not p then break end
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DrawRect(0.5, 0.5, 0.0025, 0.0045, 255, 255, 255, 200)
        p.aim = aimObject()
        if p.aim ~= 0 then
            local c = GetEntityCoords(p.aim)
            DrawMarker(2, c.x, c.y, c.z + 1.4, 0, 0, 0, 180.0, 0, 0, 0.35, 0.35, 0.35, 217, 181, 106, 220, true, false, 2, true, nil, nil, false)
        end
        for i, l in ipairs(p.leaves) do
            DrawMarker(1, l.x, l.y, l.z - 1.2, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 0.6, 79, 179, 169, 200, false, false, 2, false, nil, nil, false)
            DrawText3D(vector3(l.x, l.y, l.z + 1.2), ('~g~Battant %d'):format(i), 0.32)
        end
        ShowKeysHud('doorpick', 'Choisir une porte', {
            { keys = { EK('confirm') }, label = 'Sélectionner la porte visée' },
            { keys = { EK('finish') }, label = 'Terminer (porte verrouillée)' },
            { keys = { EK('cancel') }, label = #p.leaves > 0 and 'Retirer le dernier battant' or 'Annuler' },
        }, ('%d battant(s) sélectionné(s) · 2 pour une porte double'):format(#p.leaves))
    end
    if HudOwner == 'doorpick' then HideKeysHud() end
end

function StartDoorPick(name)
    if picking then return end
    picking = { leaves = {}, name = name }
    Notify('Vise une porte ou un portail et appuie sur Valider. Pour une porte double, sélectionne les 2 battants.', 'info')
    CreateThread(function()
        local ok, err = pcall(pickLoop)
        if not ok then
            print(('^1[AdminMenu] Erreur sélection de porte : %s^7'):format(tostring(err)))
            picking = nil
            HideKeysHud()
        end
    end)
end
function CancelDoorPick() picking = nil end

-- =========================================================
--  PUPITRES DE COMMANDE (ex. PC des cellules de la LSPD)
--  E dans la zone : liste des portes du pupitre, ouvrir / fermer à distance.
--  L'aide n'est affichée qu'aux métiers autorisés et au staff ; le serveur revérifie tout.
-- =========================================================
local CATS = {}
for _, c in ipairs(DC.jobCategories or {}) do CATS[c.key] = true end

local function myCoreJob()
    local ok, name = pcall(function()
        local pd = exports.elyzea_core:GetPlayerData()
        return pd and pd.job and pd.job.name
    end)
    return ok and name or nil
end

local function panelAllowed(p)
    if HasPerm and HasPerm('editor_doors') and CanUseEditor and CanUseEditor() then return true end
    if not p.jobs or #p.jobs == 0 then return false end
    local st, job = LocalPlayer.state, myCoreJob()
    for _, k in ipairs(p.jobs) do
        if CATS[k] and type(st[k]) == 'table' then return true end
        if job == k then return true end
        for c in pairs(CATS) do
            local s = st[c]
            if type(s) == 'table' and s.job == k then return true end
        end
    end
    return false
end

CreateThread(function()
    local KEY = ('~INPUT_%X~'):format((GetHashKey('+harvest_plant') | 0x80000000) & 0xFFFFFFFF)
    local allowedCache, allowedAt = {}, 0
    while true do
        local found = nil
        local panels = Editor.doorPanels or {}
        if #panels > 0 and not panelOpen and not doorOpen and not IsNoclipActive() then
            local p = GetEntityCoords(PlayerPedId())
            if GetGameTimer() - allowedAt > 2000 then allowedCache, allowedAt = {}, GetGameTimer() end
            local best
            for _, q in ipairs(panels) do
                local d = #(p - vector3(q.x, q.y, q.z))
                if d <= (q.radius or DC.panelRadius or 1.5) and (not best or d < best) then
                    if allowedCache[q.id] == nil then allowedCache[q.id] = panelAllowed(q) end
                    if allowedCache[q.id] then best, found = d, q end
                end
            end
        end
        nearPanel = found
        Wait(found and 0 or 500)
        if found then
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(('%s %s : commande des portes'):format(KEY, found.name))
            EndTextCommandDisplayHelp(0, false, false, -1)
        end
    end
end)

RegisterNetEvent('adminmenu:doorpanel:show', function(data)
    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'doorpanel', data = data })
end)
RegisterNUICallback('doorpanel_close', function(_, cb) panelOpen = false SetNuiFocus(false, false) cb('ok') end)
RegisterNUICallback('doorpanel_set', function(b, cb)
    cb('ok')
    local locked = nil
    if b.locked == true or b.locked == false then locked = b.locked end
    TriggerServerEvent('adminmenu:doorpanel:set', tonumber(b.id), tonumber(b.door), locked)
end)
RegisterNUICallback('doorpanel_all', function(b, cb) cb('ok') TriggerServerEvent('adminmenu:doorpanel:all', tonumber(b.id), b.locked == true) end)

-- S'éloigner du pupitre referme l'interface
CreateThread(function()
    while true do
        Wait(1000)
        if panelOpen and not nearPanel then
            local still = false
            local pc = GetEntityCoords(PlayerPedId())
            for _, q in ipairs(Editor.doorPanels or {}) do
                if #(pc - vector3(q.x, q.y, q.z)) <= (q.radius or DC.panelRadius or 1.5) + 1.5 then still = true break end
            end
            if not still then
                panelOpen = false
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'doorpanel_hide' })
            end
        end
    end
end)
