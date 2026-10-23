-- =====================================================================
--  ELYZEA PRESSE - client : le journal (tout le monde)
--  /journal (ou un présentoir) : articles publiés de toutes les rédactions, archives,
--  petites annonces en cours. Le staff (presse_manage) peut retirer un contenu.
-- =====================================================================
local C = PresseC

function C.OpenReader(opts)
    if C.IsOpen('reader') or C.IsDown() or IsPauseMenuActive() then return end
    local r = C.Pub('news', { job = opts and opts.job or nil })
    if r.error then return C.Notify(r.error, 'error') end
    C.Focus('reader', true)
    SendNUIMessage({ action = 'reader', show = true, data = r, job = opts and opts.job or '' })
end
C.ui.reader = { close = function() C.Focus('reader', false) SendNUIMessage({ action = 'reader', show = false }) end }

if Config.Reader.command and Config.Reader.command ~= '' then
    RegisterCommand(Config.Reader.command, function() C.OpenReader() end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Reader.command, 'Lire le journal (articles publiés, petites annonces)')
end
