-- =========================================================
--  MAP EXPORTÉE PAR BUILDER STUDIO - démarrage
--  Lit data.json et laisse runtime.lua créer la map autour des joueurs.
-- =========================================================
local raw = LoadResourceFile(GetCurrentResourceName(), 'data.json')
local ok, data = pcall(json.decode, raw or '')
if not ok or type(data) ~= 'table' or type(data.elements) ~= 'table' then
    print('^1[Map] data.json illisible : la map ne peut pas être chargée.^7')
    return
end

for k, v in pairs(ExportConfig) do BRuntime.cfg[k] = v end
BRuntime.texturesPath = 'textures/'
BRuntime.duiPage = 'tex.html'   -- textures par lien (https), si la map en utilise

-- En mode « ymap », les objets statiques viennent du .ymap streamé :
-- le script ne garde que ce qui doit bouger ou briller.
local function filterForYmap(elements)
    local out = {}
    for id, el in pairs(elements) do
        if el.type == 'light' or el.vehicle or el.dynamic then
            out[id] = el
        elseif el.type == 'elevator' then
            -- la cage est dans le .ymap : le script ne garde que l'interaction
            local copy = {}
            for k, v in pairs(el) do copy[k] = v end
            copy.doorsOnly = true
            out[id] = copy
        elseif el.type == 'wall' or el.type == 'partition' or el.type == 'facade' then
            -- seules les portes de ces murs sont gérées par le script
            local copy = {}
            for k, v in pairs(el) do copy[k] = v end
            copy.doorsOnly = true
            out[id] = copy
        end
    end
    return out
end

CreateThread(function()
    BRuntime.calibrate()
    for m, d in pairs(data.dims or {}) do BRuntime.dims[m] = d end
    BRuntime.measureKit()
    local p = { id = data.resource or GetCurrentResourceName(), elements = data.elements, textures = data.textures, dims = data.dims }
    if ExportConfig.Mode == 'ymap' then p.elements = filterForYmap(data.elements) end
    BRuntime.setProject(p)
    TriggerServerEvent(GetCurrentResourceName() .. ':doors')
end)
