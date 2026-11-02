-- =========================================================
--  ELYZEA CHANGE - réglages
--  Le bureau de change est un PNJ de l'éditeur de map (admin_menu › PNJ › rôle « Bureau de change ») :
--  nom et taux se règlent sur chaque PNJ. Les valeurs ci-dessous servent par défaut.
-- =========================================================
Config = {}

Config.Item       = 'pesos'      -- objet d'inventaire des pesos (elyzea_inventory/shared/items.lua)
Config.Account    = 'cash'       -- argent échangé : liquide uniquement
Config.Default = {
    name    = 'Bureau de change',
    toPesos = 100,               -- pesos reçus pour 100 $
    toCash  = 100,               -- $ rendus pour 100 pesos
}
Config.MinAmount   = 1           -- minimum par opération (en $ ou en pesos)
Config.MaxAmount   = 1000000     -- maximum par opération
Config.MaxDistance = 5.0         -- distance max avec le guichetier (mètres)

-- =========================================================
--  PAIEMENT DES COMMERCES : dollars ou pesos, commerce par commerce
--  Currency      : 'money' (dollars : liquide / banque) ou 'pesos' (objet pesos ci-dessus)
--  ForceCurrency : true  = SEULE cette monnaie est acceptée (le joueur ne peut pas choisir)
--                  false = monnaie proposée par défaut, le joueur peut payer avec l'autre
--  Un PNJ peut aussi avoir sa propre monnaie (éditeur de map › PNJ › « Monnaie ») :
--  elle s'applique sauf si son commerce ci-dessous a ForceCurrency = true.
--  PesosRate : prix en pesos = prix en $ × PesosRate (arrondi au-dessus).
-- =========================================================
Config.Payment = {
    Enabled = true,
    DefaultCurrency = 'money',
    PesosCurrency = 'pesos',       -- nom de l'objet pesos (même que Config.Item)
    PesosRate = 1.0,

    Businesses = {
        -- Fourrières (ressource elyzea_fourriere)
        FourriereVoiture = { Currency = 'money', ForceCurrency = false },
        FourriereAvion   = { Currency = 'money', ForceCurrency = false },
        FourriereBateau  = { Currency = 'money', ForceCurrency = false },
        -- PNJ commerçants de l'éditeur de map (admin_menu)
        Tatoueur   = { Currency = 'money', ForceCurrency = false },
        Coiffeur   = { Currency = 'money', ForceCurrency = false },
        Superette  = { Currency = 'money', ForceCurrency = false },
        Armurerie  = { Currency = 'money', ForceCurrency = false },
        BoutiquePNJ = { Currency = 'money', ForceCurrency = false },   -- PNJ « Boutique » (achat d'objets)
        GaragePNJ  = { Currency = 'money', ForceCurrency = false },    -- PNJ « Garage » (location de véhicules)
        -- Boutiques de vêtements (ressource elyzea_clothing)
        Vetements  = { Currency = 'money', ForceCurrency = false },
    },
}
