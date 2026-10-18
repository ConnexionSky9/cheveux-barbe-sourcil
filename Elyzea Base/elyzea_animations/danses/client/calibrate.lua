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
