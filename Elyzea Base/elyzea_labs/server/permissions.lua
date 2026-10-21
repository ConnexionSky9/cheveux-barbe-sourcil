-- =====================================================================
--  ELYZEA LABS · serveur : droits
--  · Chef du groupe propriétaire (grade « boss ») : tout.
--  · Autres membres : droits de leur grade réglés par le chef (lab.perms[gradeId]),
--    sinon Config.DefaultGradePerms.
--  · Personne entrée avec le code : aucun droit de gestion (simple présence).
--  · Staff entré par le menu admin : tout (contrôle, test).
-- =====================================================================
local L = Labs
local KEYS = {}
for _, p in ipairs(Config.Perms) do KEYS[#KEYS + 1] = p.key end
L.PermKeys = KEYS

local function all(v) local t = {} for _, k in ipairs(KEYS) do t[k] = v end return t end

function L.GradePerms(lab, gradeId)
    local p = lab.perms[tostring(gradeId)]
    local out = {}
    for _, k in ipairs(KEYS) do
        if type(p) == 'table' and p[k] ~= nil then out[k] = p[k] == true else out[k] = Config.DefaultGradePerms[k] == true end
    end
    return out
end

-- role : 'boss' | 'member' | 'staff' | nil · rights : { enter, craft, ... } · g : groupe du joueur
function L.Rights(src, lab)
    local inside = L.inside[src]
    if inside and inside.lab == lab.id and inside.via == 'admin' then return 'staff', all(true), nil end
    local g = L.PlayerGroup(src)
    if not g or not lab.owner or g.id ~= lab.owner then return nil, all(false), g end
    if g.boss then return 'boss', all(true), g end
    return 'member', L.GradePerms(lab, g.gradeId), g
end

function L.Can(src, lab, perm)
    local _, r = L.Rights(src, lab)
    return r[perm] == true
end

-- Le joueur est-il dans CE laboratoire (instance et intérieur) ?
function L.InsideLab(src, labId)
    local i = L.inside[src]
    if not i or i.lab ~= labId then return false end
    local lab = L.list[labId]
    return lab ~= nil and GetPlayerRoutingBucket(src) == L.Bucket(lab)
end

-- Nettoie une matrice de droits envoyée par la tablette : seuls les grades du groupe propriétaire
function L.CleanPerms(lab, input)
    local g = L.GroupInfo(lab.owner)
    if not g or type(input) ~= 'table' then return nil end
    local out = {}
    for _, gr in ipairs(g.grades) do
        if not gr.boss then
            local p = input[tostring(gr.id)] or input[gr.id]
            if type(p) == 'table' then
                local row = {}
                for _, k in ipairs(KEYS) do row[k] = p[k] == true end
                out[tostring(gr.id)] = row
            end
        end
    end
    return out
end
