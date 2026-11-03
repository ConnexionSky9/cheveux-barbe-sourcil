-- =====================================================================
--  ELYZEA LASERGAME - STAFF (client)
--  /lgadmin ouvre l'onglet staff de l'interface (le serveur revérifie la permission à chaque action).
--  Aperçu d'une carte : construite autour de l'ancre pour le staff seul (objets locaux), 3 minutes.
-- =====================================================================
RegisterNetEvent('elyzea_lasergame:openAdmin', function()
    if C.uiOpen then C.UI('tab', 'admin') return end
    C.OpenUI('admin', true)
end)

RegisterNetEvent('elyzea_lasergame:adminTeleport', function(p)
    if C.inGame then return end
    C.CloseUI()
    C.Fade(true, 300)
    C.PlaceAt(p, p.h)
    C.Fade(false, 400)
end)

local previewing = false
RegisterNetEvent('elyzea_lasergame:adminPreview', function(info)
    if C.inGame or previewing then return C.Notify('Aperçu impossible pour le moment.', 'error') end
    previewing = true
    C.CloseUI()
    C.Notify('Aperçu de la carte pendant 3 minutes (visible par toi seul).', 'info')
    CreateThread(function()
        Map.Build(info)
        if #Map.missing > 0 then C.Notify(('%d modèle(s) absent(s) : voir la console F8.'):format(#Map.missing), 'error') end
        local stop = GetGameTimer() + 180000
        while GetGameTimer() < stop and not C.inGame do
            local cam = GetFinalRenderedCamCoord()
            for _, l in ipairs(Map.lights) do
                if #(cam - l.p) < 70.0 then DrawLightWithRange(l.p.x, l.p.y, l.p.z, l.c[1], l.c[2], l.c[3], l.r, l.i) end
            end
            -- contour de la zone et points d'apparition
            local pts = Map.zone and Map.zone.points or {}
            local z = (Map.anchor and Map.anchor.z or 0) + 0.3
            for i = 1, #pts do
                local a, b = pts[i], pts[(i % #pts) + 1]
                DrawLine(a.x, a.y, z, b.x, b.y, z, 170, 90, 255, 255)
                DrawLine(a.x, a.y, z + 3.0, b.x, b.y, z + 3.0, 170, 90, 255, 160)
            end
            for team, list in pairs((Map.data and Map.data.spawns) or {}) do
                for _, s in ipairs(list) do
                    local x, y, sz = Map.World(s.x, s.y, s.z or 0)
                    local r, g, b = C.TeamColor(team)
                    DrawMarker(2, x, y, sz + 1.0, 0, 0, 0, 0, 180.0, 0, 0.6, 0.6, 0.6, r, g, b, 200, false, true, 2, false, nil, nil, false)
                end
            end
            Wait(0)
        end
        if not C.inGame then Map.Unload() end
        previewing = false
        C.Notify('Fin de l\'aperçu.', 'info')
    end)
end)
