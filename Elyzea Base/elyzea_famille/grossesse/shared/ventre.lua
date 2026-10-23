-- =====================================================================
--  ELYZEA FAMILLE - ventre de grossesse : règles (fonctions pures, testées hors du jeu : tests/test_ventre.lua)
-- =====================================================================
VentreRegles = {}
local V = VentreRegles

-- Pièce voulue pour une étape, ou nil (pas de ventre).
-- cfg = réglages publiés (GlobalState.famVentre) ; haut = { drawable, col, li } porté au composant 11 ; femme = true/false
function V.cible(cfg, etape, haut, femme)
    if type(cfg) ~= 'table' or not cfg.actif or not etape then return nil end
    local e = cfg.etapes and cfg.etapes['e' .. tostring(etape)]
    if type(e) ~= 'table' or (tonumber(e.li) or -1) < 0 then return nil end
    local mode = cfg.compatibilite or 'toujours'
    if mode == 'sansHaut' then
        local nu = cfg.hautNu and (femme and cfg.hautNu.f or cfg.hautNu.h) or 15
        if haut and haut.drawable ~= nu then return nil end
    elseif mode == 'liste' then
        local ok = false
        for _, h in ipairs(cfg.hautsCompatibles or {}) do
            if haut and ((h.col and h.col == haut.col and tonumber(h.li) == haut.li) or (not h.col and tonumber(h.drawable) == haut.drawable)) then ok = true break end
        end
        if not ok then return nil end
    end
    return { composant = tonumber(cfg.composant) or 3, collection = cfg.collection or '', li = math.floor(tonumber(e.li)),
        texture = math.max(0, math.floor(tonumber(e.texture) or 0)) }
end

-- Même pièce ? (pour savoir si le ventre posé doit être changé)
function V.meme(a, b)
    if not a or not b then return a == b end
    return a.composant == b.composant and a.collection == b.collection and a.li == b.li and a.texture == b.texture
end

-- Faut-il reprendre la pièce d'origine ? L'emplacement ne montre plus le ventre posé : quelqu'un a changé
-- le vêtement (boutique, objet vêtement, uniforme…) ; la nouvelle pièce devient la pièce d'origine.
function V.change(courant, pose)
    return courant.drawable ~= pose.drawable or courant.texture ~= pose.texture
end

return VentreRegles
