-- Client des sacs de shopping (client/bags.lua) : objets tenus en main, menu ALT, demandes envoyées au serveur
local fails, passes = 0, 0
local function check(c, l) if c then passes = passes + 1 io.write('  ok   ', l, '\n') else fails = fails + 1 io.write('  ÉCHEC ', l, '\n') end end
setmetatable(_G, { __index = function(_, k) if type(k) == 'string' and k:match('^%u') then return function() end end end })
local threads, NOW = {}, 0
function GetGameTimer() return NOW end
function CreateThread(fn) local co = coroutine.create(fn) assert(coroutine.resume(co)) if coroutine.status(co) ~= 'dead' then threads[#threads + 1] = co end end
function Wait() if coroutine.isyieldable() then coroutine.yield() end end
function SetTimeout(_, fn) CreateThread(fn) end
local function tick(n) for _ = 1, n or 1 do NOW = NOW + 500 local cur = threads threads = {} for _, co in ipairs(cur) do assert(coroutine.resume(co)) if coroutine.status(co) ~= 'dead' then threads[#threads + 1] = co end end end end
function GetHashKey(s) local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end return h end
local ME = 100
local W = { items = {}, objects = {}, nextObj = 1000, anim = nil, veh = false, weapon = GetHashKey('WEAPON_UNARMED'), server = {}, nui = {} }
LocalPlayer = { state = {} }
function PlayerPedId() return ME end
function GetResourceState() return 'started' end
function GetCurrentResourceName() return 'elyzea_clothing' end
function IsModelInCdimage() return true end
function HasModelLoaded() return true end
function DoesAnimDictExist() return true end
function HasAnimDictLoaded() return true end
function GetEntityCoords() return { x = 0, y = 0, z = 0 } end
function CreateObject(h) W.nextObj = W.nextObj + 1 W.objects[W.nextObj] = { model = h } return W.nextObj end
function AttachEntityToEntity(o, ped, bone) W.objects[o].bone = bone end
function GetPedBoneIndex(_, b) return b end
function DoesEntityExist(e) return e == ME or W.objects[e] ~= nil or e == 555 end
function DeleteEntity(e) W.objects[e] = nil end
function IsPedInAnyVehicle() return W.veh end
function GetSelectedPedWeapon() return W.weapon end
function IsEntityDead() return false end
function IsEntityPlayingAnim(_, d, a) return W.anim == d .. '/' .. a end
function TaskPlayAnim(_, d, a) W.anim = d .. '/' .. a end
function StopAnimTask() W.anim = nil end
function GetIsTaskActive() return false end
function TriggerServerEvent(n, ...) W.server[#W.server + 1] = { n = n, args = { ... } } end
function SendNUIMessage(m) W.nui[#W.nui + 1] = m end
function NetworkGetEntityIsNetworked() return true end
function NetworkGetNetworkIdFromEntity() return 77 end
function GetVehicleClass() return 1 end
local cmds, ev = {}, {}
function RegisterCommand(n, f) cmds[n] = f end
function RegisterNetEvent(n, f) if f then ev[n] = f end end
function AddEventHandler(n, f) ev[n] = f end
function RegisterNUICallback() end
exports = setmetatable({ elyzea_inventory = { GetPlayerItems = function() return W.items end } }, { __call = function() end,
    __index = function(_, k) if k == 'elyzea_clothing' then return { IsOpen = function() return false end } end end })
assert(load(READ('config.lua'), '@config.lua'))()
assert(load(READ('client/bags.lua'):gsub('`([^`]+)`', 'GetHashKey("%1")'), '@client/bags.lua'))()
local function props() local n, list = 0, {} for o, d in pairs(W.objects) do n = n + 1 list[#list + 1] = d end return n, list end
local function giveBag(slot, color, id) W.items[slot] = { name = 'sac_shopping_' .. color, label = 'Sac', count = 1, metadata = { bag = id, label = 'Sac ' .. color, count = 2 } } end

giveBag(1, 'rose', 'B1')
ev['elyzea_clothing:bagsChanged']() tick(3)
local n, list = props()
check(n == 1 and list[1].bone == Config.Bags.hold.right.bone and list[1].model == GetHashKey(Config.Bags.colors.rose.model), '1 sac : tenu dans la main droite (modèle du sac rose)')
check(W.anim == Config.Bags.hold.anim.dict .. '/' .. Config.Bags.hold.anim.name, 'animation « sac à la main »')
giveBag(2, 'bleu', 'B2')
ev['elyzea_clothing:bagsChanged']() tick(3)
n, list = props()
local bones = {} for _, d in ipairs(list) do bones[d.bone] = true end
check(n == 2 and bones[Config.Bags.hold.right.bone] and bones[Config.Bags.hold.left.bone], '2 sacs : un dans chaque main')
giveBag(3, 'jaune', 'B3') giveBag(4, 'multi', 'B4')
ev['elyzea_clothing:bagsChanged']() tick(3)
n, list = props()
local bunch = false for _, d in ipairs(list) do if d.model == GetHashKey(Config.Bags.hold.bunch.model) then bunch = true end end
check(n == 2 and bunch, '4 sacs : un paquet de sacs à droite + un sac à gauche (pas d\'empilement)')
W.veh = true tick(2)
check(props() == 0, 'en véhicule : sacs cachés')
W.veh = false W.weapon = 123 tick(2)
check(props() == 0, 'arme en main : sacs cachés')
W.weapon = GetHashKey('WEAPON_UNARMED') tick(2)
check(props() == 2, 'de retour : sacs réapparus')

-- ALT
local o = ClothingBags.altOptions({ kind = 'vehicle', entity = 555 })
local stores = 0 for _, x in ipairs(o) do if x.id:match('^store:') then stores = stores + 1 end end
check(stores == 4 and o[#o].id == 'take', 'ALT sur un véhicule : « Ranger un sac » pour chaque sac + « Récupérer un sac »')
o = ClothingBags.altOptions({ kind = 'player', sid = 7 })
check(#o == 4 and o[1].id == 'gift:B1' and o[1].label:find('Offrir'), 'ALT sur une personne : « Offrir un sac de shopping » pour chaque sac')
check(ClothingBags.altOptions({ kind = 'player', sid = 7, inVehicle = true })[1].disabled, 'personne en véhicule : grisé')
ClothingBags.altSelect('store:B2', { kind = 'vehicle', entity = 555 })
local last = W.server[#W.server]
check(last.n == 'elyzea_clothing:bagStore' and last.args[1] == 'B2' and last.args[2] == 77 and last.args[3] == 1, 'ranger : demande au serveur (sac, véhicule, catégorie)')
ClothingBags.altSelect('take', { kind = 'vehicle', entity = 555 })
check(W.server[#W.server].n == 'elyzea_clothing:bagTrunkList', 'récupérer : le serveur envoie la liste du coffre')
ClothingBags.altSelect('gift:B3', { kind = 'player', sid = 7 })
last = W.server[#W.server]
check(last.n == 'elyzea_clothing:bagGift' and last.args[1] == 'B3' and last.args[2] == 7, 'offrir : demande au serveur (sac, joueur)')
-- Cadeau reçu : touches
ev['elyzea_clothing:bagGiftAsk']({ from = 'Perso 3', count = 2, timeout = 20 })
check(W.nui[#W.nui].action == 'bagGiftAsk', 'cadeau reçu : bandeau affiché')
cmds.elyzea_sac_accepter()
last = W.server[#W.server]
check(last.n == 'elyzea_clothing:bagGiftAnswer' and last.args[1] == true, 'touche d\'acceptation : réponse envoyée')
local before = #W.server
cmds.elyzea_sac_accepter()
check(#W.server == before, 'sans cadeau en attente : la touche ne fait rien (pas de conflit)')
W.items = {}
ev['elyzea_clothing:bagsChanged']() tick(3)
check(props() == 0 and W.anim == nil, 'plus de sacs : objets retirés, bras relâché')
ev['onResourceStop']('elyzea_clothing')
io.write(('\n%d ok, %d échec(s)\n'):format(passes, fails))
return fails
