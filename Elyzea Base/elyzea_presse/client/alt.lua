-- =====================================================================
--  ELYZEA PRESSE - client : interactions ALT sur une personne
--  Le menu ALT appartient à elyzea_police (pour tout le monde) : il demande au
--  journaliste ses options par l'export AltOptions(ctx) et lui passe le choix par
--  AltSelect(id, ctx). Le serveur revérifie tout (service, grade, distance).
-- =====================================================================
local C = PresseC

function C.AltOptions(ctx)
    if type(ctx) ~= 'table' or ctx.kind ~= 'player' or not C.IsPresse() or C.IsDown() then return {} end
    if not C.OnDuty() then return { { id = 'none', label = 'Presse : prenez votre service (F6)', icon = 'press', disabled = true } } end
    local out = {}
    if C.interview then
        out[#out + 1] = { id = 'ivEnd', label = 'Terminer l\'interview', icon = 'anim_stop', desc = C.interview.subject }
        if C.interview.role == 'journalist' then out[#out + 1] = { id = 'ivNotes', label = 'Notes de l\'interview', icon = 'record' } end
    elseif C.Can('interview') then
        out[#out + 1] = { id = 'interview', label = 'Proposer une interview', icon = 'mic', desc = 'La personne accepte ou refuse' }
    end
    if C.Can('ads') then out[#out + 1] = { id = 'ad', label = 'Proposer une annonce payante', icon = 'fine' } end
    return out
end

function C.AltSelect(id, ctx)
    local sid = ctx and tonumber(ctx.sid)
    if id == 'ivEnd' then return C.LeaveInterview() end
    if id == 'ivNotes' then return C.OpenNotes() end
    if not sid then return end
    if id == 'interview' then
        C.Focus('ivAsk', true)
        SendNUIMessage({ action = 'ivAsk', show = true, target = sid, name = GetPlayerName(GetPlayerFromServerId(sid)) or ('ID ' .. sid) })
    elseif id == 'ad' then
        local r = C.Req('adPrepare')
        if r.error then return C.Notify(r.error, 'error') end
        r.target = sid
        C.Focus('adForm', true)
        SendNUIMessage({ action = 'adForm', show = true, data = r })
    end
end

C.ui.ivAsk = { close = function() C.Focus('ivAsk', false) SendNUIMessage({ action = 'ivAsk', show = false }) end }
C.ui.adForm = { close = function() C.Focus('adForm', false) SendNUIMessage({ action = 'adForm', show = false }) end }
RegisterNUICallback('ivAsk', function(body, cb)
    local r = C.Req('interviewRequest', { target = body.target, subject = body.subject })
    if r.ok then C.ui.ivAsk.close() C.Notify(r.message, 'success') end
    cb(r)
end)
RegisterNUICallback('adSend', function(body, cb)
    local r = C.Req('adOffer', { target = body.target, tier = body.tier, text = body.text })
    if r.ok then C.ui.adForm.close() C.Notify(r.message, 'success') end
    cb(r)
end)

exports('AltOptions', function(ctx)
    local ok, list = pcall(C.AltOptions, ctx)
    return ok and list or {}
end)
exports('AltSelect', function(id, ctx)
    CreateThread(function()
        local ok, err = pcall(C.AltSelect, id, ctx)
        if not ok then print(('^1[PRESSE] ALT %s : %s^0'):format(tostring(id), tostring(err))) end
    end)
    return true
end)
