-- =====================================================================
--  ELYZEA LASERGAME - JOURNAUX
--  Catégories : admin, money, pvp, security, error.
--  Sorties : console, table lg_logs, webhook Discord facultatif (convar elyzea_lasergame_webhook).
-- =====================================================================
Logs = {}

local COLORS = { admin = 0x9B5CFF, money = 0x3EE6B0, pvp = 0xFF2D46, security = 0xFFB547, error = 0xFF4D6D }
local LABELS = { admin = 'Staff', money = 'Argent', pvp = 'PVP', security = 'Sécurité', error = 'Erreur' }
local queue, sending = {}, false

local function webhook() return GetConvar('elyzea_lasergame_webhook', '') end

local function pump()
    if sending then return end
    sending = true
    CreateThread(function()
        while #queue > 0 do
            local item = table.remove(queue, 1)
            local url = webhook()
            if url ~= '' then
                PerformHttpRequest(url, function() end, 'POST', json.encode({
                    username = 'ElyzeaFA LaserGame',
                    embeds = { {
                        title = ('[%s] %s'):format(LABELS[item.cat] or item.cat, item.msg:sub(1, 200)),
                        description = item.data and ('```json\n%s\n```'):format(json.encode(item.data):sub(1, 1800)) or nil,
                        color = COLORS[item.cat] or 0x9B5CFF,
                        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                    } },
                }), { ['Content-Type'] = 'application/json' })
            end
            Wait(1200)   -- limite de Discord : pas plus d'un message par seconde environ
        end
        sending = false
    end)
end

-- cat : catégorie · msg : texte · data : table (facultatif) · src : joueur concerné (facultatif)
function Logs.Add(cat, msg, data, src)
    msg = tostring(msg or '')
    local cid, name
    if src and src > 0 then
        local id = Bridge.Identity(src)
        cid, name = id and id.cid or nil, id and id.name or GetPlayerName(src)
    end
    if Config.Logs.console then
        print(('^5[LaserGame:%s]^0 %s%s'):format(cat, name and (name .. ' : ') or '', msg))
    end
    if Config.Logs.database and DB and DB.ready then
        -- jamais de nil dans un tableau de paramètres (il serait transmis comme un objet et la requête échouerait)
        MySQL.insert('INSERT INTO `lg_logs` (`category`, `citizenid`, `name`, `message`, `data`) VALUES (?, NULLIF(?, \'\'), NULLIF(?, \'\'), ?, NULLIF(?, \'\'))',
            { cat, cid or '', name and name:sub(1, 80) or '', msg:sub(1, 255), data and json.encode(data) or '' })
    end
    if Config.Logs.discord and webhook() ~= '' then
        queue[#queue + 1] = { cat = cat, msg = (name and (name .. ' : ') or '') .. msg, data = data }
        if #queue > 200 then table.remove(queue, 1) end
        pump()
    end
end

function Logs.Error(msg, data) Logs.Add('error', msg, data) end
function Logs.Debug(msg) if Config.Debug then print('^3[LaserGame:debug]^0 ' .. tostring(msg)) end end
