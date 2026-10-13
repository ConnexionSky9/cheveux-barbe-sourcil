-- =====================================================================
--  ADAPTATEUR NOTIFICATIONS (serveur) : elyzea_core:Notify(src, texte, type, durée, titre)
--  type : 'success' | 'error' | 'inform' | 'warning'
-- =====================================================================
Adapters = Adapters or {}
local A = {}
Adapters.Notify = A

function A.Send(src, text, kind, duration)
    if not src or src <= 0 then return end
    local ok = pcall(function() exports.elyzea_core:Notify(src, text, kind or 'inform', duration or (JHS and JHS.S.general.notifyDuration) or 6000, 'Bijouterie') end)
    if not ok then TriggerClientEvent('chat:addMessage', src, { args = { 'Bijouterie', text } }) end
end
