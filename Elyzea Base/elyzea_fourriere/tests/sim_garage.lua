-- =====================================================================
--  elyzea_garage (vrai server.lua) : garages spécialisés et état « en réparation »
-- =====================================================================
local GA = loadResource('elyzea_garage', { 'elyzea_garage/config.lua', 'elyzea_garage/server.lua' })
function GetPedInVehicleSeat() return 0 end
print('\n— elyzea_garage : garages aérien / maritime')
addPlayer(1, 'CID_A', 0, 0, 0, vector3(0, 0, 0))
py_update("UPDATE player_vehicles SET state = 1 WHERE plate IN ('CAR001','MOTO01','PLANE1')")
py_update("UPDATE player_vehicles SET state = 4 WHERE plate = 'FAST01'")
py_insert("INSERT INTO elyzea_fourriere (plate, citizenid, model, vclass, destroyed, reason, status, repair_until) VALUES ('FAST01', 'CID_A', 'sultan', 'car', 1, 'destroyed', 'repair', NOW() + INTERVAL 20 MINUTE) ON DUPLICATE KEY UPDATE status = 'repair', repair_until = NOW() + INTERVAL 20 MINUTE")
local npc = { x = 0, y = 0, z = 0 }
Registry.elyzea_garage.OpenFor(1, { name = 'Aéroport', kind = 'air', spots = { { x = 30, y = 0, z = 0, h = 0 } }, npc = npc })
local d = lastSent('garage:client:open', 1).args[1]
local plates = {} for _, v in ipairs(d.list) do plates[v.plate] = v end
check(plates.PLANE1 and plates.HELI01 and not plates.CAR001 and not plates.BOAT01, 'garage aérien : seulement hélicos et avions')
check(d.kind == 'air' and d.fourriere == true, 'type du garage et fourrière active envoyés à l\'interface')
Sent = {}
fire('garage:server:takeOut', 1, 'CAR001', 'automobile')
check(lastSent('garage:client:notify', 1).args[1]:find('hélicoptères et avions') ~= nil, 'garage aérien : sortir une voiture est refusé')
check(py_single("SELECT state FROM player_vehicles WHERE plate = 'CAR001'").state == 1, 'la voiture reste au garage')
Registry.elyzea_garage.OpenFor(1, { name = 'Garage public', spots = { { x = 30, y = 0, z = 0, h = 0 } }, npc = npc })
local all = lastSent('garage:client:open', 1).args[1]
local fast for _, v in ipairs(all.list) do if v.plate == 'FAST01' then fast = v end end
check(fast and fast.status == 'repair' and fast.remain > 1100 and fast.remain <= 1200, 'garage public : véhicule « en réparation » avec le temps restant')
fire('garage:server:takeOut', 1, 'FAST01', 'automobile')
check(lastSent('garage:client:notify', 1).args[1]:find('réparation'), 'sortir un véhicule en réparation : refusé')
fire('garage:server:impound', 1, 'OLD001')
check(lastSent('garage:client:notify', 1).args[1]:find('fourrière'), 'ancien bouton « payer la fourrière » : renvoie vers le PNJ fourrière')
-- Rangement dans un garage maritime : seuls les bateaux
Registry.elyzea_garage.OpenFor(1, { name = 'Port', kind = 'sea', spots = {}, npc = npc })
local car = spawnWorld('sultan', 'CAR001', vector3(5, 0, 0))
py_update("UPDATE player_vehicles SET state = 0 WHERE plate = 'CAR001'")
fire('garage:server:store', 1, NetworkGetNetworkIdFromEntity(car), { engineHealth = 900 })
check(py_single("SELECT state FROM player_vehicles WHERE plate = 'CAR001'").state == 0 and DoesEntityExist(car), 'garage maritime : ranger une voiture est refusé')
REAL_TYPE.dinghy = 'boat'
py_update("UPDATE player_vehicles SET state = 0, vclass = NULL WHERE plate = 'BOAT01'")
local boat = spawnWorld('dinghy', 'BOAT01', vector3(6, 0, 0))
fire('garage:server:store', 1, NetworkGetNetworkIdFromEntity(boat), { engineHealth = 1000 })
local b = py_single("SELECT state, vclass FROM player_vehicles WHERE plate = 'BOAT01'")
check(b.state == 1 and b.vclass == 'boat' and not DoesEntityExist(boat), 'bateau rangé, catégorie relevée sur le véhicule')
print(('\ngarage : %d ok, %d échec(s)'):format(Oks, Fails))
return Fails
