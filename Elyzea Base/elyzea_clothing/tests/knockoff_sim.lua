-- Simulation : chapeau et lunettes qui tombent (coup reçu, comme de base), ramassables, lunettes cassables
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

print('[Chute (coup reçu) : le vrai objet au sol]')
FIRE('elyzea_clothing:propFell', 1, 'hats', HAT)
FIRE('elyzea_clothing:propFell', 1, 'glasses', GL)
check(#DROPS == 2, 'chapeau ET lunettes tombés : 2 objets au sol')
local names = {}
for _, d in ipairs(DROPS) do names[d.items[1].name] = d end
check(names.vet_chapeau and names.vet_lunettes, 'ce sont les vrais objets vet_chapeau et vet_lunettes')
check(names.vet_chapeau.items[1].metadata.drawable == 12 and names.vet_chapeau.items[1].metadata.texture == 1, 'même modèle et même coloris que le chapeau porté')
check(names.vet_lunettes.prop == 'prop_cs_sol_glasses' and names.vet_chapeau.prop == 'prop_proxy_hat_01', 'modèles 3D au sol : lunettes et chapeau')
check(math.abs(names.vet_chapeau.coords.z - (-0.95)) < 0.01, 'posés au sol, à côté de la personne')
check(sent('elyzea_clothing:fell', 1) == 2, 'la personne est prévenue (tenue sauvegardée sans eux)')
FIRE('elyzea_clothing:propFell', 1, 'hats', HAT)
check(#DROPS == 2, 'deux chutes du même accessoire de suite : une seule compte')
step()
FIRE('elyzea_clothing:propFell', 1, 'hats', { drawable = -1, texture = 0 })
check(#DROPS == 2, 'rien porté : rien ne tombe')
FIRE('elyzea_clothing:propFell', 1, 'tops', { drawable = 3, texture = 0 })
check(#DROPS == 2, 'un haut ne « tombe » pas (seulement chapeau et lunettes)')
Player(1).state.elyUniform = 'police'
FIRE('elyzea_clothing:propFell', 1, 'hats', HAT)
check(#DROPS == 2, 'tenue de service : aucun objet créé')
Player(1).state.elyUniform = nil
step()
FIRE('elyzea_clothing:propFell', 1, 'hats', HAT)
check(#DROPS == 3, 'plus tard, nouvelle chute : de nouveau un objet')

print('[Casser les lunettes]')
DROPS = {}
step()
FIRE('elyzea_clothing:propFell', 1, 'glasses', GL)
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
