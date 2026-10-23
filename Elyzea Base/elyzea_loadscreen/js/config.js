/* =====================================================================
   ELYZEA — LOADING SCREEN · CONFIGURATION
   ---------------------------------------------------------------------
   C'est le SEUL fichier à modifier pour personnaliser le loading screen.
   Les couleurs se modifient dans css/style.css (bloc :root en haut).
   ===================================================================== */

/* ---------------------------------------------------------------------
   SERVEUR
   --------------------------------------------------------------------- */
const server = {
    name: "ELYZEA",                       // Nom affiché sous le logo (l'intro utilise intro.words)
    subtitle: "Roleplay",                 // Petit texte sous le nom
    slogan: "Choisis ton camp. Écris ton histoire.", // Texte « machine à écrire » ("" pour désactiver)
    logo: "assets/logo/logo.webp",         // Chemin du logo
    logoSize: "min(32vh, 56vw)",          // Taille du logo dans l'interface (toute valeur CSS)
    showName: true                        // false = n'affiche que le logo
};

/* ---------------------------------------------------------------------
   SLIDESHOW
   Une entrée peut être :
     - une simple chaîne : "assets/images/photo1.jpg"
     - un objet détaillé :
       {
         src: "assets/images/photo1.jpg",
         title: "Texte affiché en bas à gauche",
         side: "legal" | "illegal" | "neutral", // teinte l'ambiance (bleu / rouge / or)
         effect: "zoom-in",                       // facultatif (sinon automatique)
         transition: "blur"                       // facultatif (sinon automatique)
       }
   label : facultatif, remplace « Côté légal / illégal » dans la légende.
   Effets disponibles      : zoom-in, zoom-out, pan-left, pan-right, pan-up, pan-down, rotate, drift
   Transitions disponibles : fade, blur, zoom, wipe-left, wipe-right, iris
   --------------------------------------------------------------------- */
const slides = [
    // Versions retouchées (assets/images/stylised). Les captures d'origine sont dans assets/images/originals.
    { src: "assets/images/stylised/mrpd.webp",           title: "MRPD · Poste de police",  side: "legal" },
    { src: "assets/images/stylised/scene.webp",          title: "La scène du centre-ville", side: "neutral", label: "Vie de la ville" },
    { src: "assets/images/stylised/palais_justice.webp", title: "Palais de justice",       side: "legal" },
    { src: "assets/images/stylised/moore_club.webp",     title: "Moore Club",              side: "illegal", label: "Vie nocturne" },
    { src: "assets/images/stylised/champ.webp",          title: "Plantation clandestine",  side: "illegal" }
];

const slideshow = {
    interval: 7000,        // Temps d'affichage d'une photo (ms)
    transition: 1800,      // Durée d'une transition entre deux photos (ms)
    shuffle: false,        // true = ordre aléatoire
    blurTransitions: true, // Autorise les transitions avec flou (un peu plus coûteux)
    lightSweep: true,      // Balayage lumineux à chaque changement de photo
    effects: ["zoom-in", "pan-left", "zoom-out", "pan-up", "rotate", "pan-right", "drift", "pan-down"],
    transitions: ["blur", "wipe-left", "zoom", "fade", "iris", "wipe-right"]
};

/* ---------------------------------------------------------------------
   MUSIQUE
   - Une seule musique : remplir file / title / artist.
   - Plusieurs musiques : remplir "playlist" (prioritaire sur "file").
   - duration : facultatif ("03:42" ou 222). Utilisé seulement si la
     durée ne peut pas être lue automatiquement depuis le fichier.
   --------------------------------------------------------------------- */
const music = {
    file: "assets/music/loading.mp3",
    title: "Nom de la musique",
    artist: "Nom de l'artiste",
    duration: "",
    volume: 0.35,          // 0 → 1
    autoplay: true,
    loop: true,            // Reboucle la playlist (ou la musique seule)
    shuffle: false,
    fadeIn: 2500,          // Montée progressive du volume au démarrage (ms)
    playlist: [
        // { file: "assets/music/loading.mp3", title: "Titre 1", artist: "Artiste 1" },
        // { file: "assets/music/track2.mp3",  title: "Titre 2", artist: "Artiste 2" }
    ]
};

/* ---------------------------------------------------------------------
   CHARGEMENT
   --------------------------------------------------------------------- */
const loading = {
    title: "Chargement du serveur",
    smoothing: 0.05,       // Vitesse de rattrapage de la barre (0.01 lent → 0.2 rapide)
    demoDuration: 24000,   // Durée de la simulation hors FiveM (aperçu navigateur)
    showLogLines: false,   // Affiche les lignes techniques de FiveM sous la barre
    stages: {
        start:   "Connexion au serveur",
        core:    "Initialisation du jeu",
        before:  "Préparation des ressources",
        data:    "Chargement des données",
        map:     "Chargement de la carte",
        after:   "Mise en place du monde",
        session: "Synchronisation de la session",
        done:    "Bienvenue sur Elyzea"
    }
};

/* ---------------------------------------------------------------------
   ASTUCES (haut gauche) & LIENS (haut droite)
   --------------------------------------------------------------------- */
const tips = {
    enabled: true,
    interval: 8000,
    list: [
        "Lis le règlement sur le Discord avant ta première session.",
        "Le métagaming et le powergaming sont sanctionnés.",
        "Les services publics recrutent : LSPD, BCSO, EMS, pompiers.",
        "Côté illégal, chaque action a ses conséquences. Joue-les.",
        "Un souci en jeu ? Ouvre un ticket sur le Discord."
    ]
};

const links = [
    { label: "Discord", value: "discord.gg/elyzea" }
    // { label: "Site", value: "elyzea.fr" }
];

/* ---------------------------------------------------------------------
   INTRO CINÉMATIQUE — tous les temps sont en millisecondes (vitesse 1)
   Séquence : logo (impact) → lettres E-L-Y-Z-E-A → explosion « FA » → transition
   --------------------------------------------------------------------- */
const intro = {
    enabled: true,          // false = pas d'intro, l'interface apparaît directement
    speed: 1,               // 1 = normal, 0.7 = plus rapide, 1.3 = plus lent
    skippable: true,        // bouton « Passer » + touche Échap / Entrée
    words: "ELYZEA",        // lettres qui sortent du logo (une par une)
    tag: "FA",              // texte graffiti de l'explosion (dessiné en SVG dans index.html)

    logoAt: 250,            // impact du logo
    logoDuration: 700,
    lettersAt: 1150,        // première lettre qui sort du logo
    letterStagger: 170,     // écart entre deux lettres
    letterFlight: 900,      // durée du trajet d'une lettre
    trails: 3,              // traînées par lettre (0 = aucune)
    chargeAt: 3000,         // tremblement avant l'explosion
    explodeAt: 3350,        // explosion + « FA »
    tagHold: 1900,          // durée d'affichage du « FA »
    wipeIn: 650,            // la peinture recouvre l'écran
    wipeOut: 800,           // la peinture se retire et révèle l'interface

    shards: 26,             // éclats autour du logo à l'impact
    sprayDots: 150          // gouttelettes de peinture à l'explosion
};

/* ---------------------------------------------------------------------
   EFFETS VISUELS
   --------------------------------------------------------------------- */
const effects = {
    // Effets réduits : "auto" (suit le réglage « réduire les animations » du système),
    // true (toujours réduits : pas d'éclats, de traînées, de particules ni de flou) ou false.
    reduced: "auto",
    particles: true,       // Braises lumineuses discrètes
    particleCount: 40,
    grain: true,           // Grain cinématique
    grainOpacity: 0.07,
    vignette: true,
    lightLines: true,      // Lignes lumineuses obliques
    letterbox: true,       // Bandes cinéma haut / bas
    logoFloat: true,       // Léger flottement du logo
    fadeOutDuration: 1200  // Fondu de sortie (doit correspondre à client.lua)
};
