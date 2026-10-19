-- =====================================================================
--  ELYZEA FAMILLE - textes (français)
--  Historique de grossesse : titre et description RP de chaque événement (utilisés par R.texteEvenement,
--  shared/regles.lua). Pour une autre langue : copier ce fichier, traduire, et le charger à la place dans fxmanifest.lua.
-- =====================================================================
FamLocale = {
    evenements = {
        decouverte_test   = { 'Grossesse découverte', 'Découverte grâce à un test de grossesse.' },
        decouverte_examen = { 'Grossesse découverte', 'Découverte lors d\'un examen médical.' },
        test_positif      = { 'Test de grossesse', 'Résultat : positif.' },
        test_negatif      = { 'Test de grossesse', 'Résultat : négatif.' },
        examen            = { 'Examen médical', 'Grossesse confirmée par un EMS%s.' },   -- %s = « , jour N » ou rien
        examen_jour       = ', jour %s',
        t2                = { 'Deuxième trimestre', 'Entrée dans le deuxième trimestre.' },
        t3                = { 'Troisième trimestre', 'Entrée dans le troisième trimestre.' },
        terme             = { 'Terme atteint', 'Le terme est atteint : le travail peut commencer.' },
        travail           = { 'Début du travail', 'Le travail a commencé, accompagné par un EMS.' },
        naissance         = { 'Naissance', 'Naissance d\'un bébé.', 'Naissance de jumeaux.', 'Naissance de triplés.' },
        fin_test          = { 'Fin (test)', 'Grossesse de test terminée par l\'administration.' },
        fin               = { 'Fin de grossesse', 'La grossesse a pris fin.' },
        evenement         = 'Événement médical',
    },
}
