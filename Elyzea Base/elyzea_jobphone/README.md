# elyzea_jobphone — Téléphone de service des métiers

Téléphone professionnel commun à **LSPD, SAMS, Mécano, Dynasty 8 et Concession**.
Il remplace F6 comme interface principale ; l'ancien menu F6 reste accessible
depuis l'application **Menu rapide**.

## Installation
1. Copier `elyzea_jobphone` dans les ressources.
2. Dans `server.cfg`, **après** les métiers et pma-voice :
   ```
   ensure elyzea_police
   ensure elyzea_ems
   ensure elyzea_meca
   ensure elyzea_dynasty
   ensure elyzea_concess
   ensure elyzea_jobphone
   ```
3. Les tables sont créées automatiquement au démarrage (`sql/install.sql` si besoin).
4. `refresh` puis redémarrer le serveur (les fxmanifest des métiers ont changé).

## Ce que les métiers ont reçu
Dans chacun des 5 métiers :
- `server/phone.lua` : pont **en lecture** (`exports.<métier>:PhoneBridge`) qui
  passe par les actions existantes du métier (mêmes contrôles de grade / service).
  Il prévient le téléphone à chaque `PushState` (recrutement, licenciement,
  grade, service, changement de métier) → annuaire à jour automatiquement.
- `client/phone.lua` : exports `OpenTablet`, `OpenMenu`, `UiBusy`.
- `client/f6.lua` : F6 sort le téléphone si `elyzea_jobphone` est démarré
  (`Config.ReplaceF6 = false` pour revenir à l'ancien F6 ; téléphone via `/telpro`).

## Applications
| Appli | Hors service | En service |
|---|---|---|
| Service (identité, numéro, prise / fin de service, temps session + total) | ✅ | ✅ |
| Annuaire (toute l'entreprise, en ligne / en service / hors ligne, numéros pro) | 🔒 | ✅ |
| Messages (canal de l'entreprise + privés, non lus, historique en base) | 🔒 | ✅ |
| Appels (pma-voice, par numéro pro ou annuaire, collègues en service) | 🔒 | ✅ |
| Collègues (carte + santé réelle : en forme / blessé / à terre / mort) | 🔒 | ✅ |
| Alertes faible / moyenne / urgente | 🔒 | ✅ |
| Tablette (grisée si le grade n'a pas la permission « tablet ») | 🔒 | ✅ |
| Menu rapide (ancien F6) | 🔒 | ✅ |

- **Alertes** : police = alerte agent existante, EMS = soutien existant ;
  mécano / Dynasty 8 / concession = alertes du téléphone (blip + itinéraire).
- **Tablette** : la direction choisit les grades autorisés comme avant
  (tablette › Grades › permission « Tablette ») ; refus côté serveur.
- **Animation** : le personnage tient le téléphone (haut du corps) et peut
  marcher / courir ; le clavier ne passe au téléphone que pendant la saisie.
- Numéro pro unique par employé et par métier (`911-` police, `912-` EMS,
  `913-` mécano, `914-` Dynasty 8, `915-` concession), conservé en base.

## Base de données
`jobphone_numbers`, `jobphone_messages`, `jobphone_reads`.

## Limites connues
- Non testé en jeu : uniquement tests serveur hors jeu (59 vérifications) et
  aperçus de l'interface.
- La carte utilise l'image satellite de l'EMS (`Config.Map.image`) ; sans elle,
  fond quadrillé.
- Un appel du téléphone de service et un appel du téléphone perso (elyzea_aura)
  utilisent tous deux le canal d'appel pma-voice : pas les deux en même temps.
