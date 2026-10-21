-- =========================================================
--  ELYZEA ILLÉGAL - CLIENT : F5
--  F5 › <Nom du groupe> ouvre la tablette du groupe du joueur.
--  Le nom affiché vient du serveur ; à l'ouverture, le serveur
--  relit lui-même le groupe du joueur.
--  Tu as déjà ton propre menu F5 ? Mets Config.F5.enabled = false
--  et appelle exports.elyzea_illegal:OpenTablet() depuis ton menu
--  (exports.elyzea_illegal:GetGroupLabel() donne le nom à afficher).
-- =========================================================
function OpenGroupTablet()
    if not Membership.inGroup then return Notify('Tu ne fais partie d\'aucun groupe illégal.', 'error') end
    TriggerServerEvent('illegal:server:open', 'f5')
end

local f5Open = false
local function closeF5()
    if not f5Open then return end
    f5Open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'f5close' })
end

-- Panneau « Menu » : groupe (si membre) + vente de drogue (si de la drogue sur soi ou mode vente actif)
local function openF5()
    if IsTabletOpen() or IsNuiFocused() or IsPauseMenuActive() then return end
    local ok, drug = pcall(function() return Ely.callback.await('illegal:drug:status', false) end)
    drug = ok and type(drug) == 'table' and drug or nil
    local showDrug = drug and drug.enabled and (drug.on or #(drug.items or {}) > 0)
    if not Membership.inGroup and not showDrug then return end   -- rien à montrer : F5 reste libre pour le reste du serveur
    if Membership.inGroup and not showDrug and Config.F5.mode == 'direct' then return OpenGroupTablet() end
    f5Open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'f5', data = { inGroup = Membership.inGroup == true, label = Membership.label, grade = Membership.grade,
        color = Membership.color, drug = showDrug and drug or nil } })
end

RegisterNUICallback('f5drug', function(body, cb)
    cb('ok')
    closeF5()
    TriggerServerEvent('illegal:drug:toggle', body and body.on == true, body and type(body.items) == 'table' and body.items or nil)
end)

RegisterNUICallback('f5open', function(_, cb)
    cb('ok')
    closeF5()
    OpenGroupTablet()
end)
RegisterNUICallback('f5close', function(_, cb) closeF5() cb('ok') end)

if Config.F5.enabled then
    Ely.addKeybind({
        name = 'illegal_f5',
        description = 'Menu du groupe illégal',
        defaultKey = Config.F5.key,
        onReleased = function() CreateThread(openF5) end,
    })
end

exports('OpenTablet', function()
    if not Membership.inGroup then return false end
    TriggerServerEvent('illegal:server:open', 'export')
    return true
end)
exports('GetGroupLabel', function() return Membership.inGroup and Membership.label or nil end)
exports('IsInGroup', function() return Membership.inGroup == true end)
