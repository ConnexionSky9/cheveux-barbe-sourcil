--[[
    ELYZEA CORE — corrections de la carte du jeu (IPL)
    Bijouterie Vangelico (Rockford Hills) : sans ces IPL, l'intérieur n'est pas chargé
    (porte « transparente », on voit la rue à travers). On charge l'intérieur normal
    et on retire les versions « façade factice » et « en travaux ».
    Rejoué régulièrement : une autre ressource de carte peut retirer ces IPL après nous.
]]
local IPL_ON = { 'post_hiest_unload' }
local IPL_OFF = { 'jewel2fake', 'bh1_16_refurb' }

local function Apply()
    for _, ipl in ipairs(IPL_OFF) do if IsIplActive(ipl) then RemoveIpl(ipl) end end
    for _, ipl in ipairs(IPL_ON) do if not IsIplActive(ipl) then RequestIpl(ipl) end end
end

CreateThread(function()
    Wait(2000)
    Apply()
    while true do
        Wait(30000)
        Apply()
    end
end)
