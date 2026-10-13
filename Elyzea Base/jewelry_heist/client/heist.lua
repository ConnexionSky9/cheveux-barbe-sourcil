-- =====================================================================
--  JEWELRY HEIST - client : suivi du braquage pour le braqueur
--  Barre de progression calée sur les durées envoyées par le serveur (étape + secondes restantes).
--  Le client ne décide de rien : il affiche seulement l'avancement.
-- =====================================================================
local C = JHC
local mine = nil

AddStateBagChangeHandler('jhHeists', 'global', function(_, _, value)
    local me = GetPlayerServerId(PlayerId())
    local cfg = C.Cfg()
    local found = nil
    for id, h in pairs(value or {}) do if h.robber == me then found = { id = id, h = h } end end
    if not found then
        if mine then C.Progress(nil) end
        mine = nil
        return
    end
    mine = found
    if not cfg or not cfg.anims.progress then return end
    local h = found.h
    if h.stage == 'panic' then C.Progress('Le bijoutier panique : restez près de lui', h.panicLeft, '#ef4444')
    elseif h.stage == 'filling' then C.Progress('Le bijoutier remplit le sac', h.fillLeft, '#f59e0b')
    elseif h.stage == 'handover' then C.Progress('Remise du sac', h.handLeft, '#22c55e') end
end)

-- Rappel à l'écran si le braqueur s'éloigne
CreateThread(function()
    while true do
        local sleep = 1000
        if mine then
            local def = C.PedDef('shop', mine.id)
            if def then
                sleep = 0
                local d = #(GetEntityCoords(PlayerPedId()) - vector3(def.ped.x, def.ped.y, def.ped.z))
                if d > (def.robDistance or 4.0) + 2.0 then C.Help('~r~Restez près du bijoutier~w~ pendant le braquage.') end
            end
        end
        Wait(sleep)
    end
end)
