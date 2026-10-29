-- =====================================================================
--  Lecture des liens YouTube : renvoie l'identifiant de la vidéo (11 caractères) et le départ (s)
--  Formats : youtube.com/watch?v=…, youtu.be/…, /embed/…, /shorts/…, /live/…, m. / music., identifiant seul.
--  Rien d'autre n'est accepté (pas d'autre site, pas de page web quelconque sur les écrans).
-- =====================================================================
YT = {}

local function validId(id) return type(id) == 'string' and #id == 11 and id:match('^[%w_%-]+$') ~= nil end

-- « 90 », « 90s », « 1m30s », « 1h2m3s » → secondes
function YT.ParseTime(t)
    if not t or t == '' then return 0 end
    t = tostring(t)
    if t:match('^%d+$') then return math.min(tonumber(t), 86400) end
    local h = tonumber(t:match('(%d+)h')) or 0
    local m = tonumber(t:match('(%d+)m')) or 0
    local s = tonumber(t:match('(%d+)s')) or 0
    if h == 0 and m == 0 and s == 0 then return 0 end
    return math.min(h * 3600 + m * 60 + s, 86400)
end

local HOSTS = { ['youtube.com'] = true, ['www.youtube.com'] = true, ['m.youtube.com'] = true, ['music.youtube.com'] = true,
    ['youtu.be'] = true, ['www.youtu.be'] = true, ['youtube-nocookie.com'] = true, ['www.youtube-nocookie.com'] = true }

function YT.Parse(url)
    if type(url) ~= 'string' then return nil end
    url = url:gsub('^%s+', ''):gsub('%s+$', '')
    if #url == 0 or #url > 300 then return nil end
    if validId(url) then return url, 0 end
    local u = url:gsub('^https?://', '')
    local host, path = u:match('^([^/%?#]+)(.*)$')
    if not host or not HOSTS[host:lower()] then return nil end
    host = host:lower()
    local query = path:match('%?([^#]*)') or ''
    local params = {}
    for k, v in query:gmatch('([^&=]+)=([^&]*)') do params[k] = v end
    local id
    if host:find('youtu%.be$') then
        id = path:match('^/([%w_%-]+)')
    else
        id = params.v or path:match('^/embed/([%w_%-]+)') or path:match('^/shorts/([%w_%-]+)') or path:match('^/live/([%w_%-]+)') or path:match('^/v/([%w_%-]+)')
    end
    if not validId(id) then return nil end
    return id, YT.ParseTime(params.t or params.start)
end

return YT
