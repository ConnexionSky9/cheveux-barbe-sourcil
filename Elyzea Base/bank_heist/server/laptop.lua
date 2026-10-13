-- =====================================================================
--  BANK HEIST - serveur : ordinateurs de piratage
--  Chaque ordinateur a un numéro de série (métadonnée « serial ») et ses tentatives restantes sont
--  enregistrées sur le serveur (bh_laptops). Déplacer, déposer, donner l'objet, se déconnecter ou
--  redémarrer ne change rien : les tentatives suivent le numéro de série.
--  Un ordinateur sans numéro (donné par le staff) en reçoit un à sa première utilisation.
-- =====================================================================
local P = BHS
P.laptops = {}   -- cache [serial] = tentatives restantes

local function itemName() return P.S.items.laptop.name end

function P.LaptopAttempts(serial)
    if P.laptops[serial] ~= nil then return P.laptops[serial] end
    local row = MySQL.single.await('SELECT `attempts` FROM `bh_laptops` WHERE `serial` = ?', { serial })
    P.laptops[serial] = row and tonumber(row.attempts) or nil
    return P.laptops[serial]
end

function P.NewLaptopMeta(src)
    local serial = P.Uid('LP')
    local n = P.S.hack.attempts
    MySQL.insert.await('INSERT INTO `bh_laptops` (`serial`, `attempts`, `owner_cid`) VALUES (?, ?, ?)', { serial, n, src and Adapters.Perms.CitizenId(src) or nil })
    P.laptops[serial] = n
    return { serial = serial, label = ('%s (%d/%d)'):format(P.S.items.laptop.label, n, n) }
end

local function label(n)
    if n <= 0 then return ('%s (grillé)'):format(P.S.items.laptop.label) end
    return ('%s (%d/%d)'):format(P.S.items.laptop.label, n, P.S.hack.attempts)
end

-- Ordinateur utilisable du joueur : { slot, serial, attempts } ou nil, raison
function P.FindLaptop(src)
    local burned = false
    for _, s in ipairs(Adapters.Inv.Slots(src, itemName())) do
        local md = type(s.metadata) == 'table' and s.metadata or {}
        if not md.serial then
            local nm = P.NewLaptopMeta(src)
            for k, v in pairs(md) do if nm[k] == nil then nm[k] = v end end
            Adapters.Inv.SetMeta(src, s.slot, nm)
            md = nm
        end
        local n = P.LaptopAttempts(md.serial)
        if n == nil then
            -- numéro inconnu (base vidée) : on ne recrée PAS de tentatives, l'ordinateur est considéré grillé
            P.Log('anomaly', md.serial, src, 'Ordinateur au numéro inconnu : considéré grillé')
            P.laptops[md.serial] = 0
            n = 0
        end
        if n > 0 then return { slot = s.slot, serial = md.serial, attempts = n, meta = md } end
        burned = true
    end
    return nil, burned and 'burned' or 'none'
end

-- Consomme une tentative (au lancement du mini-jeu : fermer l'interface ne la rend pas)
function P.UseLaptopAttempt(src, lp, bankId)
    local n = math.max(0, (P.LaptopAttempts(lp.serial) or 0) - 1)
    P.laptops[lp.serial] = n
    MySQL.update.await('UPDATE `bh_laptops` SET `attempts` = ?, `last_bank` = ? WHERE `serial` = ?', { n, bankId, lp.serial })
    local md = BH.Copy(lp.meta)
    md.label = label(n)
    md.attempts = n
    Adapters.Inv.SetMeta(src, lp.slot, md)
    return n
end
