-- Appels à l'API de la boutique (HTTP, jeton secret côté serveur uniquement).
Api = {}

local BASE = (GetConvar('shop_api_url', '')):gsub('/+$', '')
local TOKEN = GetConvar('shop_api_token', '')
local NAME = GetConvar('sv_projectName', 'fivem'):sub(1, 60)

function Api.ready() return BASE ~= '' and #TOKEN >= 32 end

--- Appel synchrone (dans un thread) : renvoie status, données décodées
function Api.call(method, path, body)
    if not Api.ready() then return 0, { error = 'API non configurée (shop_api_url / shop_api_token)' } end
    local p = promise.new()
    PerformHttpRequest(BASE .. '/api/game' .. path, function(status, text)
        local ok, data = pcall(json.decode, text or '')
        p:resolve({ status = status, data = ok and data or nil })
    end, method, body and json.encode(body) or '', {
        ['Content-Type'] = 'application/json',
        ['Accept'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. TOKEN,
        ['X-Server-Name'] = NAME,
    })
    local r = Citizen.Await(p)
    return r.status, r.data
end

function Api.ok(status) return status and status >= 200 and status < 300 end
