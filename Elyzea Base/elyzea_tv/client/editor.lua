-- =====================================================================
--  ELYZEA TV - placement d'un écran par le staff (lancé depuis le menu admin › Écrans / TV)
--  Vise un mur / une façade : l'écran s'y colle, tourné vers toi. Réglages au clavier, aperçu en direct.
--  ENTRÉE enregistre (jeton donné par l'action admin, revérifié par le serveur), RETOUR annule.
-- =====================================================================
local C = Config
local X = C.Custom

local function camRay(dist)
    local p = GetFinalRenderedCamCoord()
    local r = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(r.x), math.rad(r.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local to = p + dir * dist
    local h = StartExpensiveSynchronousShapeTestLosProbe(p.x, p.y, p.z, to.x, to.y, to.z, 1 | 16, PlayerPedId(), 7)
    local _, hit, endPos, normal = GetShapeTestResult(h)
    return (hit == 1 or hit == true) and endPos or nil, normal, p, dir
end

local function hud(d, name, ratio)
    SendNUIMessage({ action = 'editor', open = true, name = name, w = d.w, h = d.hgt, ratio = ratio, heading = d.h })
end

RegisterNetEvent('elyzea_tv:client:editor', function(token, id, data, name)
    if TVC.editing then return end
    data = type(data) == 'table' and data or {}
    local d = { x = data.x, y = data.y, z = data.z, h = data.h or 0.0, w = data.w or X.defaultW, hgt = data.hgt or X.defaultH }
    local ratio = d.w / d.hgt
    local follow = d.x == nil            -- nouvel écran : il suit le regard jusqu'au premier clic
    TVC.editing = { id = id }
    CreateThread(function()
        local saved = false
        hud(d, name, ratio)
        while true do
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 14, true) DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true) DisableControlAction(0, 17, true) DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true) DisableControlAction(0, 51, true) DisableControlAction(0, 10, true) DisableControlAction(0, 11, true)
            DisableControlAction(0, 172, true) DisableControlAction(0, 173, true) DisableControlAction(0, 174, true) DisableControlAction(0, 175, true)
            DisableControlAction(0, 191, true) DisableControlAction(0, 177, true) DisableControlAction(0, 200, true)
            local fine = IsDisabledControlPressed(0, 21)            -- MAJ : pas fin
            local changed = false
            -- clic gauche (ou suivi du regard pour un nouvel écran) : coller l'écran à l'endroit visé, tourné vers moi
            if follow or IsDisabledControlJustPressed(0, 24) then
                local hit, normal, from = camRay(120.0)
                if hit then
                    local n = normal and #(normal) > 0.1 and normal or (from - hit)
                    local hdg = math.deg(math.atan(-n.x, n.y))
                    d.x, d.y, d.z, d.h = hit.x + (n.x or 0) * 0.03, hit.y + (n.y or 0) * 0.03, hit.z, hdg
                    changed = true
                end
                if IsDisabledControlJustPressed(0, 24) then follow = false end
            end
            if d.x then
                -- molette : taille (garde le format) ; MAJ : plus fin
                local k = fine and 0.02 or 0.08
                if IsDisabledControlJustPressed(0, 15) then d.w = math.min(X.maxW, d.w * (1 + k)) d.hgt = d.w / ratio changed = true end
                if IsDisabledControlJustPressed(0, 14) then d.w = math.max(X.minW, d.w / (1 + k)) d.hgt = d.w / ratio changed = true end
                d.hgt = math.max(X.minH, math.min(X.maxH, d.hgt))
                local step = fine and 0.01 or 0.05
                local fx, fy = -math.sin(math.rad(d.h)), math.cos(math.rad(d.h))
                local rx, ry = math.cos(math.rad(d.h)), math.sin(math.rad(d.h))
                if IsDisabledControlPressed(0, 44) then d.h = d.h + (fine and 0.2 or 1.0) changed = true end
                if IsDisabledControlPressed(0, 51) then d.h = d.h - (fine and 0.2 or 1.0) changed = true end
                if IsDisabledControlPressed(0, 10) then d.z = d.z + step changed = true end
                if IsDisabledControlPressed(0, 11) then d.z = d.z - step changed = true end
                if IsDisabledControlPressed(0, 172) then d.x, d.y = d.x + fx * step, d.y + fy * step changed = true end
                if IsDisabledControlPressed(0, 173) then d.x, d.y = d.x - fx * step, d.y - fy * step changed = true end
                if IsDisabledControlPressed(0, 174) then d.x, d.y = d.x + rx * step, d.y + ry * step changed = true end
                if IsDisabledControlPressed(0, 175) then d.x, d.y = d.x - rx * step, d.y - ry * step changed = true end
                -- aperçu : l'écran (vidéo en cours s'il y en a une, sinon éteint) + un cadre
                local e = id and TVC.Duis['s' .. id]
                TVC.DrawScreen(d, e and IsDuiAvailable(e.dui) and e.tex or nil, 230)
                local h = math.rad(d.h)
                local rxx, ryy = math.cos(h) * d.w / 2, math.sin(h) * d.w / 2
                local a, b = vector3(d.x + rxx, d.y + ryy, d.z + d.hgt / 2), vector3(d.x - rxx, d.y - ryy, d.z + d.hgt / 2)
                local c2, d2 = vector3(d.x - rxx, d.y - ryy, d.z - d.hgt / 2), vector3(d.x + rxx, d.y + ryy, d.z - d.hgt / 2)
                DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, 0, 229, 255, 255) DrawLine(b.x, b.y, b.z, c2.x, c2.y, c2.z, 0, 229, 255, 255)
                DrawLine(c2.x, c2.y, c2.z, d2.x, d2.y, d2.z, 0, 229, 255, 255) DrawLine(d2.x, d2.y, d2.z, a.x, a.y, a.z, 0, 229, 255, 255)
                if IsDisabledControlJustPressed(0, 191) then
                    local p = GetEntityCoords(PlayerPedId())
                    TriggerServerEvent('elyzea_tv:server:editorSave', token, { x = d.x, y = d.y, z = d.z, h = d.h, w = d.w, hgt = d.hgt,
                        remote = { x = p.x, y = p.y, z = p.z - 1.0 } }, name)
                    saved = true
                    break
                end
            end
            if changed then hud(d, name, ratio) end
            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then break end
            Wait(0)
        end
        TVC.editing = nil
        SendNUIMessage({ action = 'editor', open = false })
        if not saved then TVC.Notify('Placement de l\'écran annulé.', 'inform') end
    end)
end)
