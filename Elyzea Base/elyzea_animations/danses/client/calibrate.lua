-- =====================================================================
--  Danses : calibrage des positions en jeu (staff)
--  Pendant une danse en duo, dans le rôle du partenaire (celui qui est venu se placer) : /danse_calib
--    flèches        avancer / reculer (y), gauche / droite (x)
--    Page ↑ / ↓     monter / descendre (z)
--    molette        tourner (h)          Maj : réglage fin
--    Entrée         enregistrer (permission vérifiée par le serveur)
--    Retour arrière annuler
--  Le serveur garde la valeur pour tout le monde ; elle s'affiche aussi en F8 pour le catalogue.
-- =====================================================================
local P = Danse.Pos
Danse.Calibrating = false

local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

RegisterCommand('danse_calib', function()
    local c = Danse.Current()
    local say = Danse.UI.Notify or print
    if not c or c.kind ~= 'duo' or c.state ~= 'playing' then return say('Lance d\'abord une danse à deux', 'err') end
    if c.slot ~= 1 then return say('Le calibrage se fait dans le rôle du partenaire (celui qui vient se placer)', 'err') end
    if Danse.Calibrating then return end
    Danse.Calibrating = true
    local step = c.step
    local start = P.Offset(c.e, step, Danse.Tuning.offsets[c.e.id])
    local off = { x = start.x, y = start.y, z = start.z, h = start.h, bone = start.bone }
    CreateThread(function()
        while Danse.Calibrating and Danse.Current() == c do
            local fine = IsControlPressed(0, 21) and 0.2 or 1.0
            local d, r = 0.01 * fine, 5.0 * fine
            local changed = false
            for _, k in ipairs({ 172, 173, 174, 175, 10, 11, 14, 15, 191, 194, 177 }) do DisableControlAction(0, k, true) end
            if IsDisabledControlPressed(0, 172) then off.y = off.y + d changed = true end
            if IsDisabledControlPressed(0, 173) then off.y = off.y - d changed = true end
            if IsDisabledControlPressed(0, 175) then off.x = off.x + d changed = true end
            if IsDisabledControlPressed(0, 174) then off.x = off.x - d changed = true end
            if IsDisabledControlPressed(0, 10) then off.z = off.z + d changed = true end
            if IsDisabledControlPressed(0, 11) then off.z = off.z - d changed = true end
            if IsDisabledControlJustPressed(0, 14) then off.h = (off.h + r) % 360.0 changed = true end
            if IsDisabledControlJustPressed(0, 15) then off.h = (off.h - r) % 360.0 changed = true end
            if changed then Danse.Reattach(off) end
            help(('Calibrage étape %d  x %.2f  y %.2f  z %.2f  h %.0f~n~Flèches, Page ↑↓, molette, Maj = fin~n~Entrée : enregistrer  Retour : annuler')
                :format(step, off.x, off.y, off.z, off.h))
            if IsDisabledControlJustPressed(0, 191) then
                TriggerServerEvent('elyzea_danse:sv:saveOffset', c.e.id, step, off)
                print(('[Elyzea danses] %s étape %d : off = { x = %.3f, y = %.3f, z = %.3f, h = %.1f }'):format(c.e.id, step, off.x, off.y, off.z, off.h))
                break
            end
            if IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 177) then
                Danse.Reattach(start)
                break
            end
            Wait(0)
        end
        Danse.Calibrating = false
    end)
end, false)

-- /danse_mesure : pendant une danse à deux, mesure EN JEU l'orientation réelle des deux corps (os des épaules),
-- la distance entre les poitrines et les têtes, et l'attache. À copier pour le support.
local function torso(ped)
    local l = GetPedBoneCoords(ped, 45509, 0.0, 0.0, 0.0)   -- épaule gauche
    local r = GetPedBoneCoords(ped, 40269, 0.0, 0.0, 0.0)   -- épaule droite
    local fx, fy = -(r.y - l.y), r.x - l.x                  -- avant du torse
    return math.deg(math.atan(-fx, fy))
end

RegisterCommand('danse_mesure', function()
    local c = Danse.Current()
    local say = Danse.UI.Notify or print
    if not c or c.kind ~= 'duo' or c.state ~= 'playing' or not c.other then return say('Lance d\'abord une danse à deux', 'err') end
    local me, other = PlayerPedId(), c.other
    local angle = ((torso(other) - torso(me) + 540.0) % 360.0) - 180.0
    local chest = #(GetPedBoneCoords(me, 24818, 0.0, 0.0, 0.0) - GetPedBoneCoords(other, 24818, 0.0, 0.0, 0.0))
    local head = #(GetPedBoneCoords(me, 31086, 0.0, 0.0, 0.0) - GetPedBoneCoords(other, 31086, 0.0, 0.0, 0.0))
    local attached = IsEntityAttached(c.slot == 1 and me or other)
    local verdict = (math.abs(math.abs(angle) - 180.0) <= 35.0) and 'FACE À FACE' or ((math.abs(angle) <= 35.0) and 'MÊME DIRECTION' or 'DE BIAIS')
    local line = ('%s : angle entre les torses %.0f° (%s) ; poitrines %.2f m ; têtes %.2f m ; partenaire attaché : %s ; mon rôle : %s')
        :format(c.e.id, angle, verdict, chest, head, attached and 'oui' or 'NON', c.slot == 0 and 'meneur' or 'partenaire')
    print('[Elyzea danses] ' .. line)
    say(line, verdict == 'FACE À FACE' and 'ok' or 'err')
end, false)
