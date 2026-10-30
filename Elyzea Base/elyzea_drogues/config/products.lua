-- =====================================================================
--  CONSOMMATION : objet → effet (Config.Drugs), animation, force, fumée
--  use : animation de prise (client/consume.lua) · mult : durée × X · power : force × X (facultatif)
--  smoke = 'variety:<id>' : fumée de la couleur de la variété · smoke = { r, g, b } : couleur fixe
-- =====================================================================
Config.Products = {}
local P = Config.Products
for id, v in pairs(Config.Varieties) do
    P[v.joint] = { drug = 'weed', use = 'joint', mult = 1.0, smoke = 'variety:' .. id, variety = id }
    P[v.pouch] = { drug = 'weed', use = 'joint', mult = 1.3, smoke = 'variety:' .. id, variety = id }
end
-- anciens objets du serveur (toujours consommables)
for _, it in ipairs({ 'weed_ak47', 'weed_amnesia', 'weed_og-kush', 'weed_skunk' }) do P[it] = { drug = 'weed', use = 'joint', mult = 1.0, smoke = 'variety:classic' } end
P['weed_white-widow'] = { drug = 'weed', use = 'joint', mult = 1.0, smoke = 'variety:whitewidow', variety = 'whitewidow' }
P['weed_purple-haze'] = { drug = 'weed', use = 'joint', mult = 1.0, smoke = 'variety:purplehaze', variety = 'purplehaze' }

P.cocaine       = { drug = 'cocaine',   use = 'snort',   mult = 1.0 }
P.cokebaggy     = { drug = 'cocaine',   use = 'snort',   mult = 1.0 }
P.coke_premium  = { drug = 'cocaine',   use = 'snort',   mult = 1.5 }
P.crack_baggy   = { drug = 'crack',     use = 'pipe',    mult = 1.0, smoke = { 235, 235, 235 } }
P.meth          = { drug = 'meth',      use = 'pipe',    mult = 1.0, smoke = { 210, 230, 255 } }
P.xtcbaggy      = { drug = 'ecstasy',   use = 'pill',    mult = 1.0 }
P.xtc_pink      = { drug = 'ecstasy',   use = 'pill',    mult = 1.0 }
P.xtc_blue      = { drug = 'ecstasy',   use = 'pill',    mult = 1.3 }
P.xtc_yellow    = { drug = 'ecstasy',   use = 'pill',    mult = 0.8 }
P.oxy           = { drug = 'opiates',   use = 'pill',    mult = 1.0 }
P.opi_syringe   = { drug = 'opiates',   use = 'syringe', mult = 1.6 }
P.ketamine      = { drug = 'ketamine',  use = 'snort',   mult = 1.0 }
P.magic_mushroom= { drug = 'mushrooms', use = 'eat',     mult = 0.8 }
P.dried_mushroom= { drug = 'mushrooms', use = 'eat',     mult = 1.0 }
P.shroom_bag    = { drug = 'mushrooms', use = 'eat',     mult = 1.4 }
-- Gâteaux : mult = durée × X · power = force × X (plus de créatures, plus vite, image plus déformée)
P.shroom_cake_s = { drug = 'mushrooms', use = 'eat',     mult = 0.7, power = 0.7 }
P.shroom_cake_m = { drug = 'mushrooms', use = 'eat',     mult = 1.4, power = 1.1 }
P.shroom_cake_l = { drug = 'mushrooms', use = 'eat',     mult = 2.2, power = 1.6 }

-- Animations de prise (props filtrés par IsModelInCdimage : un modèle absent est ignoré)
--   puffs : secondes où la fumée sort (joint / pipe)
Config.UseAnims = {
    joint   = { dict = 'amb@world_human_aa_smoke@male@idle_a', clip = 'idle_c', flag = 49, time = 9000,
                prop = { model = 'p_cs_joint_01', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 } }, puffs = { 2.5, 5.5, 8.2 } },
    pipe    = { dict = 'switch@trevor@trev_smoking_meth', clip = 'trev_smoking_meth_loop', flag = 49, time = 6000,
                prop = { model = 'prop_cs_crackpipe', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 } }, puffs = { 3.0, 5.2 } },
    snort   = { dict = 'move_p_m_two_idles@generic', clip = 'fidget_sniff_fingers', flag = 49, time = 3500 },
    pill    = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49, time = 2500 },
    eat     = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', flag = 49, time = 3000 },
    syringe = { dict = 'rcmpaparazzo1ig_4', clip = 'miranda_shooting_up', flag = 49, time = 5000,
                prop = { model = 'prop_syringe_01', bone = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 } },
                fallback = 'pill' },
}

-- Fumée colorée : particule de traînée de fumée des avions de voltige (scr_ar_planes), dont la
-- couleur se règle (SetParticleFxLoopedColour). Visible des joueurs proches (rayon ci-dessous).
Config.Smoke = { asset = 'scr_ar_planes', effect = 'scr_ar_trail_smoke', scale = 0.18, seconds = 1.4, syncRadius = 35.0 }
