-- =====================================================================
--  ELYZEA LABS · serveur : coffre du laboratoire (elyzea_inventory)
--  Identifiant « lab_<id> » : lié au laboratoire, pas au groupe → il reste après une capture.
--  elyzea_inventory garde le contenu en base, gère le poids, les emplacements et les
--  déplacements d'objets côté serveur (jusqu'à 500 emplacements).
--  Accès revérifié par l'inventaire à chaque ouverture : dans CE laboratoire + droit « coffre ».
-- =====================================================================
local L = Labs
local inv = exports.elyzea_inventory

function L.StashId(lab) return 'lab_' .. lab.id end
function L.RegisterStash(lab)
    local slots = math.max(1, math.min(500, Config.Stash.slots))
    pcall(function() inv:RegisterStash(L.StashId(lab), ('Laboratoire · %s'):format(lab.name), slots, math.floor(Config.Stash.weight * 1000)) end)
end

local function setup()
    for _, lab in pairs(L.list) do L.RegisterStash(lab) end
    pcall(function()
        inv:RegisterStashAccess('lab_', function(src, stashId)
            local id = tonumber(tostring(stashId):match('^lab_(%d+)$'))
            local lab = id and L.list[id]
            return lab ~= nil and L.InsideLab(src, lab.id) and L.Can(src, lab, 'stash')
        end)
    end)
end
table.insert(L.onReady, setup)
-- elyzea_inventory redémarré : on réenregistre les coffres et le contrôle d'accès
AddEventHandler('onResourceStart', function(res)
    if res == 'elyzea_inventory' and L.ready then SetTimeout(1500, setup) end
end)

-- fromTablet : ouverture depuis la tablette (dans le laboratoire, sans être au cercle orange)
L.pub.stash = function(src, d)
    local lab = L.list[tonumber(d.lab) or -1]
    if not lab or not L.InsideLab(src, lab.id) then return { error = 'Tu dois être dans le laboratoire.' } end
    if not L.Can(src, lab, 'stash') then return { error = 'Tu n\'as pas accès au coffre.' } end
    if not d.fromTablet then
        local it = L.Interior(lab.interior)
        if L.Dist(src, it.stash) > Config.InteractDistance + 1.5 then return { error = 'Rapproche-toi du coffre.' } end
    end
    L.RegisterStash(lab)
    local ok, r = pcall(function() return inv:OpenInventory(src, 'stash', L.StashId(lab)) end)
    if not ok or r == false then return { error = 'Ouverture du coffre impossible.' } end
    return { ok = true }
end
