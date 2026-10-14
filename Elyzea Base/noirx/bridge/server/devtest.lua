--[[
    NOIR X — Magasin de test en mémoire (provider 'devtest')
    Simule un inventaire et un compte en banque pour les joueurs ayant l'ACE 'noirx.devtest',
    afin de tester toutes les applications avant de relier le vrai inventaire/la vraie économie.
    Rien n'est persistant ; tout est remis à zéro au redémarrage de la ressource.
    NE JAMAIS UTILISER EN PRODUCTION.
]]

DevStore = { players = {} }

function DevStore.Allowed(src)
    return IsPlayerAceAllowed(src, 'noirx.devtest')
end

local function bag(src)
    local key = Identity.GetCharacterId(src) or tostring(src)
    local p = DevStore.players[key]
    if not p then
        p = {
            items = { [Config.Item.name] = 1, [Config.Money.dirtyItem] = Config.DevTest.startDirty },
            money = Config.DevTest.startClean,
        }
        DevStore.players[key] = p
    end
    return p
end

function DevStore.Count(src, item)
    if not DevStore.Allowed(src) then return 0 end
    return bag(src).items[item] or 0
end

function DevStore.Add(src, item, count)
    if not DevStore.Allowed(src) then return false end
    local b = bag(src)
    b.items[item] = (b.items[item] or 0) + count
    return true
end

function DevStore.Remove(src, item, count)
    if not DevStore.Allowed(src) then return false end
    local b = bag(src)
    if (b.items[item] or 0) < count then return false end
    b.items[item] = b.items[item] - count
    return true
end

function DevStore.GetMoney(src)
    if not DevStore.Allowed(src) then return 0 end
    return bag(src).money
end

function DevStore.AddMoney(src, amount)
    if not DevStore.Allowed(src) then return false end
    local b = bag(src)
    b.money = b.money + amount
    return true
end

function DevStore.RemoveMoney(src, amount)
    if not DevStore.Allowed(src) then return false end
    local b = bag(src)
    if b.money < amount then return false end
    b.money = b.money - amount
    return true
end
