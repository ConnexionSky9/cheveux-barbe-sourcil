-- =====================================================================
--  Téléphone de service (elyzea_jobphone) - pont client du métier
--  La tablette et le menu rapide existants s'ouvrent depuis le téléphone.
-- =====================================================================
local C = PoliceC or EmsC or MecaC or D8C or CLC

exports('OpenTablet', function() if C.OpenTablet then C.OpenTablet() end end)
exports('OpenMenu', function() if C.OpenF6Menu then C.OpenF6Menu() end end)
exports('UiBusy', function() return C.AnyOpen() end)
