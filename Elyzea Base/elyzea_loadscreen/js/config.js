/* =====================================================================
   ELYZEA FA — LOADING SCREEN v3 « NÉON » · CONFIGURATION
   ---------------------------------------------------------------------
   Le SEUL fichier à modifier pour personnaliser le loading screen.
   Couleurs : css/style.css (bloc :root tout en haut).
   ===================================================================== */

/* ---------------------------------------------------------------------
   SERVEUR
   --------------------------------------------------------------------- */
const server = {
    name: "ELYZEA FA",
    tagline: "Roleplay · Los Santos",
    slogan: "Choisis ton camp. Écris ton histoire."
};

/* ---------------------------------------------------------------------
   VIDÉO DU LOGO (intro puis logo en haut de l'écran)
   quality :
     "auto" : 4K 120 i/s si l'écran fait au moins 2560 px de large, sinon 1080p 60 i/s
     "4k"   : toujours 4K 120 i/s       "1080" : toujours 1080p 60 i/s
   --------------------------------------------------------------------- */
const video = {
    quality: "auto",
    src4k: "assets/video/logo_4k120.webm",
    src1080: "assets/video/logo_1080p60.webm",
    poster: "assets/video/logo_final.webp",   // dernière image (si la vidéo ne peut pas être lue)
    introScale: 1,          // taille du logo pendant l'intro (1 = plein écran)
    headerScale: 0.52,      // taille du logo une fois l'interface affichée
    headerY: "-25vh",       // position verticale du logo dans l'interface
    skippable: true,        // bouton « Passer » + Échap / Entrée / Espace
    // Moments forts de la vidéo (secondes) : effets synchronisés
    beats: {
        reveal: 0.9,        // le « E » apparaît : éclair
        sparks: 1.95,       // gerbe d'étincelles : explosion de particules
        city: 3.0,          // la ville apparaît : onde de choc
        title: 4.05,        // « ELYZEA FA » : reflet chromatique
        settle: 7.2         // le logo monte et l'interface arrive
    }
};

/* ---------------------------------------------------------------------
   PHOTOS DE FOND (retouchées, teintées violet automatiquement)
   side : "legal" | "illegal" | "neutral" ; label : remplace « Côté légal / illégal »
   --------------------------------------------------------------------- */
const slides = [
    { src: "assets/images/stylised/mrpd.webp",           title: "MRPD · Poste de police",  side: "legal" },
    { src: "assets/images/stylised/scene.webp",          title: "La scène du centre-ville", side: "neutral", label: "Vie de la ville" },
    { src: "assets/images/stylised/palais_justice.webp", title: "Palais de justice",       side: "legal" },
    { src: "assets/images/stylised/moore_club.webp",     title: "Moore Club",              side: "illegal", label: "Vie nocturne" },
    { src: "assets/images/stylised/champ.webp",          title: "Plantation clandestine",  side: "illegal" }
];
const slideshow = {
    interval: 8000,         // temps par photo (ms)
    transition: 2200,       // fondu entre deux photos (ms)
    shuffle: false
};

/* ---------------------------------------------------------------------
   MUSIQUE (lecteur en bas à droite)
   --------------------------------------------------------------------- */
const music = {
    playlist: [
        { file: "assets/music/loading.mp3", title: "Nom de la musique", artist: "Nom de l'artiste" }
    ],
    volume: 0.35,           // 0 → 1
    autoplay: true,
    shuffle: false,
    fadeIn: 2500            // montée du volume (ms)
};

/* ---------------------------------------------------------------------
   CHARGEMENT (progression RÉELLE de FiveM)
   --------------------------------------------------------------------- */
const loading = {
    smoothing: 0.06,        // vitesse de rattrapage de la barre (0.01 lent → 0.2 rapide)
    demoDuration: 26000,    // durée de la simulation dans un navigateur (aperçu)
    stages: {
        start:   "Connexion au serveur",
        core:    "Initialisation du jeu",
        before:  "Préparation des ressources",
        data:    "Chargement des données",
        map:     "Chargement de la carte",
        after:   "Mise en place du monde",
        session: "Synchronisation de la session",
        done:    "Bienvenue sur Elyzea FA"
    }
};

/* ---------------------------------------------------------------------
   ASTUCES & LIENS
   --------------------------------------------------------------------- */
const tips = {
    interval: 7000,
    list: [
        "Lis le règlement sur le Discord avant ta première session.",
        "Le métagaming et le powergaming sont sanctionnés.",
        "Les services publics recrutent : LSPD, BCSO, EMS.",
        "Côté illégal, chaque action a ses conséquences. Joue-les.",
        "Ton téléphone (appli Services) liste toutes les entreprises ouvertes.",
        "Un souci en jeu ? Ouvre un ticket sur le Discord."
    ]
};
const links = [
    { label: "Discord", value: "discord.gg/elyzea" }
];

/* ---------------------------------------------------------------------
   EFFETS (tout est dessiné à la résolution native de l'écran, à la
   fréquence de l'écran : 60, 120, 144 Hz…)
   --------------------------------------------------------------------- */
const effects = {
    reduced: "auto",        // "auto" (réglage système), true (effets réduits) ou false
    particles: 140,         // particules lumineuses (0 = aucune)
    grid: true,             // sol néon en perspective
    lightBeams: true,       // faisceaux lumineux derrière le logo
    shootingLines: true,    // traits lumineux qui traversent l'écran
    grain: 0.05,            // grain cinéma (0 = aucun)
    parallax: true,         // l'image bouge légèrement avec la souris
    fadeOutDuration: 1200   // fondu de sortie (= client.lua)
};
