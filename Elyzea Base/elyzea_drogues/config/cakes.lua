-- =====================================================================
--  GÂTEAUX AUX CHAMPIGNONS : tailles et quantités (une seule source)
--  Utilisé par config/recipes.lua (ingrédients, durées) et config/minigames.lua (grammes à verser, cuisson)
--  — aussi chargé par elyzea_labs (qui reprend config/minigames.lua).
--  Ingrédients : 1 farine = 100 g · 1 sucre = 50 g · 1 levure = 10 g · 1 lait = 10 cL · 1 champignon séché = 10 g
--  oven = température à régler (°C) · bakeTime = secondes à tenir dans la zone pour que le gâteau soit cuit
-- =====================================================================
Config = Config or {}
Config.CakeSizes = {
    s = { label = 'petit gâteau', flour = 2, sugar = 1, yeast = 1, milk = 1, shroom = 1, prep = 10, bake = 12, oven = 180, bakeTime = 10 },
    m = { label = 'gâteau moyen', flour = 4, sugar = 2, yeast = 1, milk = 2, shroom = 3, prep = 14, bake = 16, oven = 170, bakeTime = 14 },
    l = { label = 'gros gâteau',  flour = 6, sugar = 3, yeast = 2, milk = 3, shroom = 6, prep = 18, bake = 20, oven = 160, bakeTime = 18 },
}
