-- =====================================================================
--  elyzea_police - serveur : retrait du PPA (menu ALT)
--  Le PPA se passe auprès des EMS (elyzea_papiers) ; la police peut seulement le retirer.
-- =====================================================================
local P = Police

CreateThread(function()
    Wait(1000)
    pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `police_ppa` (
            `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL, `name` VARCHAR(100) NOT NULL,
            `kind` VARCHAR(20) NOT NULL DEFAULT 'civil',
            `status` VARCHAR(20) NOT NULL,
            `officer` VARCHAR(100) NOT NULL, `officer_cid` VARCHAR(50) NULL,
            `details` VARCHAR(255) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX (`citizenid`)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    end)
end)

-- Retrait du PPA (menu ALT) : permis désactivé et documents PPA retirés
RegisterNetEvent('police:server:ppaRevoke', function(target)
    local src = source
    target = tonumber(target)
    if not P.Can(src, 'ppa_revoke') then return P.Notify(src, 'Votre grade ne permet pas de retirer un PPA.', 'error') end
    if not target or not P.GetPlayer(target) or target == src then return end
    if P.Dist(src, target) > 4.0 then return P.Notify(src, 'La personne est trop loin.', 'error') end
    local p = P.GetPlayer(target)
    local lic = p.PlayerData.metadata.licences or {}
    if not lic.weapon and not lic.weapon_fdo then
        local hasItem = false
        if GetResourceState('elyzea_inventory') == 'started' then
            for _, item in ipairs({ 'ppa', 'ppa_fdo' }) do
                local ok, n = pcall(function() return exports.elyzea_inventory:Search(target, 'count', item) end)
                if ok and (tonumber(n) or 0) > 0 then hasItem = true end
            end
        end
        if not hasItem then return P.Notify(src, 'Cette personne n\'a pas de PPA.', 'error') end
    end
    P.SetLicense(src, p.PlayerData.citizenid, 'weapon', false)
    P.SetLicense(src, p.PlayerData.citizenid, 'weapon_fdo', false)
    local removed = 0
    if GetResourceState('elyzea_inventory') == 'started' then
        for _, item in ipairs({ 'ppa', 'ppa_fdo' }) do
            local ok, n = pcall(function() return exports.elyzea_inventory:Search(target, 'count', item) end)
            n = ok and tonumber(n) or 0
            if n > 0 and exports.elyzea_inventory:RemoveItem(target, item, n) then removed = removed + n end
        end
    end
    local ci = p.PlayerData.charinfo or {}
    local name = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
    MySQL.insert('INSERT INTO `police_ppa` (`citizenid`, `name`, `kind`, `status`, `officer`, `officer_cid`, `details`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { p.PlayerData.citizenid, name, 'civil', 'revoked', P.Name(src), P.Cid(src), ('%d document(s) retiré(s)'):format(removed) })
    P.Notify(src, ('PPA de %s retiré.'):format(name), 'success')
    P.Notify(target, 'Votre permis de port d\'arme vous a été retiré par la police.', 'error')
    P.Log(src, 'PPA retiré', name)
end)

