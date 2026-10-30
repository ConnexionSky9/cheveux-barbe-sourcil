-- Simulation : chapeau et lunettes qui tombent (pousser / coup), ramassables, lunettes cassables
-- (lancée par run_knockoff_sim.py, après les imitations de hidden_sim.lua)
local fails = 0
local function check(c, l) if c then print('  ok   ' .. l) else fails = fails + 1 print('  ÉCHEC ' .. l) end end
_G.print = function(...) io.write(table.concat({ ... }, ' '), '\n') end
function GetResourceKvpString() return nil end
json = json or { decode = function() return {} end, encode = function() return '{}' end }
function SetResourceKvp() end
POS, VEH = {}, {}
local ST = {}
function Player(src)
    ST[src] = ST[src] or setmetatable({}, { __index = { set = function(self, k, v) rawset(self, k, v) end } })
    return { state = ST[src] }
end
function GetEntityCoords(p) return POS[p] or vector3(0, 0, 0) end
function GetVehiclePedIsIn(p) return VEH[p] or 0 end
ROLL = 1
local realRandom = math.random
math.random = function(a, b) if b then return realRandom(a, b) end return ROLL end

-- Inventaire imité : tas au sol + inventaire du joueur 1 (lunettes en case 3)
DROPS, SLOTS = {}, {}
local inv = {
    Items = function(_, name) return { name = name } end,
    CreateDrop = function(_, c, items, prop) DROPS[#DROPS + 1] = { coords = c, items = items, prop = prop } return #DROPS end,
    GetNearbyDropItems = function(_, src, name)
        local out = {}
        for id, d in ipairs(DROPS) do
            local p = POS[src] or vector3(0, 0, 0)
            if math.sqrt((d.coords.x - p.x) ^ 2 + (d.coords.y - p.y) ^ 2) < 3.5 then
                for i, it in ipairs(d.items) do if it.name == name then out[#out + 1] = { drop = id, index = i, name = it.name, metadata = it.metadata } end end
            end
        end
        return out
    end,
    SetDropItemMetadata = function(_, id, i, md) DROPS[id].items[i].metadata = md return true end,
    GetSlot = function(_, src, slot) return SLOTS[slot] end,
    SetMetadata = function(_, src, slot, md) SLOTS[slot].metadata = md return true end,
    RemoveItem = function() return true end, AddItem = function() return true end, CanCarryItem = function() return true end,
}
local prev = exports
exports = setmetatable({}, { __call = function() end, __index = function(_, k) if k == 'elyzea_inventory' then return inv end return prev[k] end })
Config.Items.enabled = true
local function sent(ev, target) local n = 0 for _, s in ipairs(SENT) do if s.ev == ev and (not target or s.target == target) then n = n + 1 end end return n end
local function step(ms) NOW = NOW + (ms or 10000) end
local HAT, GL = { drawable = 12, texture = 1 }, { drawable = 5, texture = 0 }
POS[1], POS[2], POS[3] = vector3(0, 0, 0), vector3(1, 0, 0), vector3(30, 0, 0)

print('[Pousser]')
FIRE('elyzea_clothing:push', 2, 1)
check(sent('elyzea_clothing:pushed', 1) == 1, 'le joueur 2 pousse le joueur 1 (à 1 m) : il part en arrière')
FIRE('elyzea_clothing:knock', 1, 'push', 2, { hats = HAT, glasses = GL })
check(#DROPS == 2, 'chapeau ET lunettes tombés : 2 objets au sol')
local names = {}
for _, d in ipairs(DROPS) do names[d.items[1].name] = d end
check(names.vet_chapeau and names.vet_lunettes, 'ce sont les vrais objets vet_chapeau et vet_lunettes')
check(names.vet_chapeau.items[1].metadata.drawable == 12 and names.vet_chapeau.items[1].metadata.texture == 1, 'même modèle et même coloris que le chapeau porté')
check(names.vet_lunettes.prop == 'prop_cs_sol_glasses' and names.vet_chapeau.prop == 'prop_proxy_hat_01', 'modèles 3D au sol : lunettes et chapeau')
check(math.abs(names.vet_chapeau.coords.z - (-0.95)) < 0.01, 'posés au sol, à côté de la personne')
check(sent('elyzea_clothing:apply', 1) == 2, 'ils disparaissent de la tête de la personne')
step()
FIRE('elyzea_clothing:knock', 1, 'push', 2, { hats = HAT, glasses = GL })
check(#DROPS == 2, 'poussée « inventée » sans vraie poussée récente : rien ne tombe')
step(1000)
FIRE('elyzea_clothing:push', 3, 1)
check(sent('elyzea_clothing:pushed', 1) == 1, 'trop loin (30 m) : impossible de pousser')

print('[Coups de poing]')
DROPS = {}
step()
ROLL = 99
FIRE('elyzea_clothing:knock', 1, 'hit', 2, { hats = HAT, glasses = GL })
check(#DROPS == 0, 'coup sans chance (99 > 35 %) : rien ne tombe')
step()
ROLL = 10
FIRE('elyzea_clothing:knock', 1, 'hit', 2, { hats = HAT, glasses = { drawable = -1, texture = 0 } })
check(#DROPS == 1 and DROPS[1].items[1].name == 'vet_chapeau', 'coup réussi, pas de lunettes portées : seul le chapeau tombe')
FIRE('elyzea_clothing:knock', 1, 'hit', 2, { hats = HAT, glasses = GL })
check(#DROPS == 1, 'deux coups de suite : pas de deuxième chute tout de suite')
step()
FIRE('elyzea_clothing:knock', 1, 'hit', 3, { hats = HAT, glasses = GL })
check(#DROPS == 1, 'coup « à distance » (frappeur à 30 m) : refusé')
step()
Player(1).state.elyUniform = 'police'
FIRE('elyzea_clothing:knock', 1, 'hit', 2, { hats = HAT, glasses = GL })
check(#DROPS == 1, 'tenue de service : rien ne tombe (pas d\'objet créé)')
Player(1).state.elyUniform = nil
step()
VEH[1] = 55
FIRE('elyzea_clothing:knock', 1, 'hit', 2, { hats = HAT, glasses = GL })
check(#DROPS == 1, 'dans un véhicule : rien ne tombe')
VEH[1] = nil

print('[Casser les lunettes]')
DROPS = {}
step()
ROLL = 1
FIRE('elyzea_clothing:knock', 1, 'hit', 2, { glasses = GL })
POS[3] = vector3(0.5, 0, 0)
FIRE('elyzea_clothing:breakGround', 3)
local md = DROPS[1].items[1].metadata
check(md.broken == true and md.label == 'Lunettes cassées', 'un autre joueur écrase les lunettes au sol : « Lunettes cassées »')
local before = sent('elyzea_clothing:brokeGlasses')
FIRE('elyzea_clothing:breakGround', 3)
check(sent('elyzea_clothing:brokeGlasses') == before, 'déjà cassées : rien de plus')
SLOTS[3] = { slot = 3, name = 'vet_lunettes', metadata = md }
FIRE('elyzea_clothing:equip', 1, 3, {})
local last = SENT[#SENT]
check(last.ev == 'elyzea_clothing:notify' and tostring(last.args[1]):find('cassées'), 'porter des lunettes cassées : refusé')
SLOTS[4] = { slot = 4, name = 'vet_lunettes', metadata = { cat = 'glasses', drawable = 7, texture = 0, label = 'Ray' } }
FIRE('elyzea_clothing:breakSlot', 1, 4)
check(SLOTS[4].metadata.broken == true, 'casser ses lunettes depuis l\'inventaire (clic droit › Casser)')
SLOTS[5] = { slot = 5, name = 'vet_chapeau', metadata = { cat = 'hats' } }
FIRE('elyzea_clothing:breakSlot', 1, 5)
check(not SLOTS[5].metadata.broken, 'un chapeau ne se « casse » pas')

print(('Résultat : %d échec(s)'):format(fails))
return fails
