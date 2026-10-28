-- =====================================================================
--  Valeurs par défaut des réglages ajoutés par les mises à jour.
--  Si ton config.lua est plus ancien et n'a pas ces blocs, ils sont pris d'ici. Sinon, ton config.lua gagne.
-- =====================================================================
Config.Pole = Config.Pole or {
    enabled = true,
    model = 'prop_strip_pole_01',
    collision = true,
    interactDistance = 1.8,       -- distance pour [E] Danser
    maxDistance = 2.5,            -- le serveur refuse / arrête la danse au-delà (m)
    -- point d'origine des animations par rapport au pied de la barre (repère de la barre, m)
    -- à régler barre par barre dans le menu admin si la danseuse n'est pas collée à la barre
    sceneOffset = vector3(0.0, 0.0, 0.0),
    sceneSpeed = 1.0,
    enter = { dict = 'mini@strip_club@pole_dance@pole_enter', clip = 'pd_enter' },
    exit  = { dict = 'mini@strip_club@pole_dance@pole_exit',  clip = 'pd_exit' },
    -- touches 1, 2, 3 (contrôles 157, 158, 160)
    dances = {
        { key = 157, label = 'Routine 1', icon = '🌀', desc = 'Tours autour de la barre', dict = 'mini@strip_club@pole_dance@pole_dance1', clip = 'pd_dance_01' },
        { key = 158, label = 'Routine 2', icon = '⬆️', desc = 'Montées et descentes', dict = 'mini@strip_club@pole_dance@pole_dance2', clip = 'pd_dance_02' },
        { key = 160, label = 'Routine 3', icon = '✨', desc = 'Figures', dict = 'mini@strip_club@pole_dance@pole_dance3', clip = 'pd_dance_03' },
    },
    -- touche 4 (164) : danse sensuelle debout devant la barre (danse privée du club), 3 parties enchaînées
    private = { key = 164, label = 'Danse sensuelle', icon = '💋', desc = 'Debout, devant la barre', distance = 0.9, parts = {
        { dict = 'mini@strip_club@private_dance@part1', clip = 'priv_dance_p1' },
        { dict = 'mini@strip_club@private_dance@part2', clip = 'priv_dance_p2' },
        { dict = 'mini@strip_club@private_dance@part3', clip = 'priv_dance_p3' },
    } },
    autoKey = 165,                -- touche 5 : enchaînement automatique des routines
    cursorKey = 74,               -- H : afficher / cacher le curseur de l'interface (caméra libre quand il est caché)
    stopKeys = { 177, 38 },       -- RETOUR ARRIÈRE ou E : descendre de la barre
    -- pourboires : les spectateurs proches jettent des billets à la danseuse (argent liquide)
    tips = { enabled = true, amount = 100, cooldown = 3, maxDistance = 5.0,
        anim = { dict = 'mini@strip_club@leaning@toss', clip = 'toss', flag = 48, duration = 2.0 },
        note = 'prop_anim_cash_note', notes = 4 },
}

-- ---------------------------------------------------------------- sons des jeux (chocs, roulement, frappe)
-- Sons générés par l'interface du jeu (pas de fichier à télécharger) : volume selon la distance,
-- gauche / droite selon la caméra. Tous les joueurs proches les entendent pendant le rejeu des coups.
Config.Sounds = Config.Sounds or { enabled = true, volume = 0.8, range = 30.0 }
