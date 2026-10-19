-- =========================================================
--  ELYZEA ANIMAUX - CLIENT : ajustement du harnais par race (/harnais_reglage)
--  Staff (« animaux_manage », revérifié par le serveur). Sors un chien, équipe-lui
--  un harnais, tape /harnais_reglage près de lui :
--    ← →  choisir le réglage    ↑ ↓  modifier (Maj : plus vite)
--    E    changer la posture (debout, assis, couché, marche)
--    Entrée  enregistrer pour tous les joueurs (ce modèle de chien)
--    Retour  annuler          /harnais_reglage defaut : revenir aux valeurs mesurées
--  Le harnais est redessiné en direct : vérifie chaque posture, de face et de profil.
-- =========================================================
local PARAMS = {
    { key = 'width', label = 'Largeur du poitrail', step = 0.02 },
    { key = 'height', label = 'Hauteur du poitrail', step = 0.02 },
    { key = 'pad', label = 'Marge au-dessus du pelage (m)', step = 0.002 },
    { key = 'girth', label = 'Sangle de poitrail : recul derrière les épaules', step = 0.05 },
    { key = 'neckAt', label = 'Encolure : position sur le cou', step = 0.03 },
    { key = 'neck', label = 'Encolure : taille', step = 0.03 },
    { key = 'neckTilt', label = 'Encolure : inclinaison', step = 0.05 },
    { key = 'belly', label = 'Sangle ventrale : position', step = 0.03 },
    { key = 'lift', label = 'Hauteur de l\'ensemble (m)', step = 0.004 },
}
local POSES = { { 'follow', 'debout / marche' }, { 'stay', 'debout immobile' }, { 'sit', 'assis' }, { 'lie', 'couché' } }

C.FitEdit = nil

local function stop(save)
    local e = C.FitEdit
    if not e then return end
    C.FitEdit = nil
    if save then TriggerServerEvent('elyzea_animaux:server:saveFit', e.model, e.fit)
    else C.Notify('Ajustement annulé.', 'inform') end
end

RegisterCommand('harnais_reglage', function(_, args)
    if C.FitEdit then return stop(false) end
    local id = C.NearestMine(6.0)
    local m = id and C.Mine[id]
    if not m or not DoesEntityExist(m.ped) then return C.Notify('Sors ton chien et approche-toi de lui.', 'error') end
    local model = C.ModelName(m.ped)
    if not model then return C.Notify('Modèle inconnu.', 'error') end
    if args[1] == 'defaut' then return TriggerServerEvent('elyzea_animaux:server:saveFit', model, nil) end
    if not HarnessGeom.Frame(C.BonesOf(m.ped), nil) then
        return C.Notify(('Squelette de %s non reconnu : /harnais_os pour voir les os trouvés.'):format(model), 'error')
    end
    local fit = HarnessGeom.Fit(C.HarnessFitFor(m.ped))
    C.FitEdit = { ped = m.ped, id = id, model = model, fit = fit, sel = 1, pose = 1 }
    if not (m.gear and m.gear.harness) then C.Notify('Astuce : équipe-lui un harnais pour voir toutes les sangles (sinon seul le collier apparaît avec la laisse).', 'inform') end
    CreateThread(function()
        while C.FitEdit do
            local e = C.FitEdit
            if not DoesEntityExist(e.ped) then stop(false) break end
            for _, c in ipairs({ 172, 173, 174, 175, 38, 191, 194, 177, 200 }) do DisableControlAction(0, c, true) end
            local p = PARAMS[e.sel]
            local fast = IsControlPressed(0, 21) and 5 or 1
            if IsDisabledControlJustPressed(0, 174) then e.sel = (e.sel - 2) % #PARAMS + 1 end
            if IsDisabledControlJustPressed(0, 175) then e.sel = e.sel % #PARAMS + 1 end
            if IsDisabledControlJustPressed(0, 172) then e.fit[p.key] = e.fit[p.key] + p.step * fast end
            if IsDisabledControlJustPressed(0, 173) then e.fit[p.key] = e.fit[p.key] - p.step * fast end
            if IsDisabledControlJustPressed(0, 38) then
                e.pose = e.pose % #POSES + 1
                CreateThread(function() C.Command(e.id, POSES[e.pose][1]) end)
            end
            if IsDisabledControlJustPressed(0, 191) then stop(true) break end
            if IsDisabledControlJustPressed(0, 194) or IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then stop(false) break end
            -- C.HarnessFitFor() renvoie e.fit tant que l'édition est ouverte : le harnais est redessiné en direct
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(('Harnais · %s~n~%s : ~y~%.3f~s~ (%d/%d)~n~Posture : %s~n~~INPUT_CELLPHONE_LEFT~ ~INPUT_CELLPHONE_RIGHT~ réglage · ~INPUT_CELLPHONE_UP~ ~INPUT_CELLPHONE_DOWN~ valeur · ~INPUT_CONTEXT~ posture · ~INPUT_FRONTEND_ACCEPT~ enregistrer · ~INPUT_FRONTEND_RDOWN~ annuler')
                :format(e.model, p.label, e.fit[p.key], e.sel, #PARAMS, POSES[e.pose][2]))
            EndTextCommandDisplayHelp(0, false, false, -1)
            Wait(0)
        end
    end)
end, false)
