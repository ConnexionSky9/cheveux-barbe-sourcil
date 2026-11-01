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
