-- =====================================================================
--  ADAPTATEUR NOTIFICATIONS (serveur) : elyzea_core:Notify(src, texte, type, durée, titre)
-- =====================================================================
Adapters = Adapters or {}
Adapters.Notify = {}
function Adapters.Notify.Send(src, text, kind)
    if not src or src <= 0 then return end
    local ok = pcall(function() exports.elyzea_core:Notify(src, text, kind or 'inform', 6000, 'Banque') end)
    if not ok then TriggerClientEvent('chat:addMessage', src, { args = { 'Banque', text } }) end
end
