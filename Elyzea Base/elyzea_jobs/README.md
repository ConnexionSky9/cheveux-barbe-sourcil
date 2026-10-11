# elyzea_jobs : socle commun des métiers principaux

Gère les grades, les accès, le recrutement, les finances, le service et le menu **ALT** de :

| Métier (`job`) | Nom affiché | Ressource du métier |
|---|---|---|
| `police` | LSPD | `elyzea_police` |
| `ambulance` | EMS | `elyzea_ems` |
| `burgershot` | Burger Shot | `elyzea_entreprises` |
| `nightclub` | Bahamas | `elyzea_entreprises` |
| `cardealer` | AutoExotics | `elyzea_concess` |

## Installation
1. Dossier `elyzea_jobs` dans `resources`.
2. `server.cfg` : `ensure elyzea_jobs` **juste après** `ensure elyzea_inventory` (avant les ressources des métiers).
3. Supprimer `elyzea_patron` (dossier et ligne `ensure elyzea_patron`) : remplacé par l'onglet Patron des tablettes.
4. Les tables sont créées toutes seules au démarrage (rien à importer) :
   - `elyzea_jobs` (grades et accès de chaque métier), `elyzea_jobs_logs` (journal RH, service, finances), `elyzea_jobs_specialties` (spécialités, ex. police scientifique) ;
   - police : `police_ppa`, `police_evidence`, `police_evidence_log`, `police_cases`, `police_case_notes`, `police_analyses`, `police_reports`, `police_dna` ;
   - inventaire : `elyzea_weapons` (registre des armes : n° de série, propriétaire, gravure, statut), `elyzea_weapons_history`.
5. **Premier démarrage** : les grades sont repris du métier existant ; les accès des grades sont mis aux valeurs par défaut
   de `config.lua` (le patron les ajuste ensuite dans la tablette › Patron › Grades et accès).

## Règles (toutes vérifiées par le serveur)
- **Un seul métier principal** par personnage : un employé d'un de ces 5 métiers ne peut pas être recruté ailleurs ; il doit démissionner (tablette › Équipe).
- **Recruter** : le patron clique sur RECRUTER ; la personne la plus proche (≤ `Config.Recruit.distance` m) reçoit la demande
  (**Y** accepter / **L** refuser, expire après `timeout` s). Refusée si elle est déjà employée, partie, trop loin, ou si le patron spamme (`cooldown`).
- **Grades** : on ne modifie que les grades **en dessous du sien**, jamais soi-même ; on ne peut pas donner un accès qu'on n'a pas.
  Le grade patron (👑) a tous les accès. Le dernier patron ne peut pas démissionner.
- **Finances** : dépôt / retrait avec motif (montant max `Config.Finance.maxAmount`), une opération à la fois par joueur, annulée si l'argent ne peut pas être déplacé.
  Historique : auteur, date, motif.
- **Service** : prise / fin de service dans l'onglet Équipe (ou au point de service du métier).

## Accès par métier
Liste et grade minimum par défaut dans `config.lua` › `Config.Companies[job].perms` (`min = -1` : patron seulement, `99` : patron seulement et non délégable par défaut).
Accès communs : voir l'équipe, recruter, promouvoir, renvoyer, grades et accès, voir / déposer / retirer l'argent, journaux.

## Menu ALT
Maintenir **ALT** (Paramètres › Raccourcis › FiveM › « Interactions ») : curseur, la cible s'entoure ; clic : actions possibles.
Seuls les employés des 5 métiers ont ce curseur (ALT reste libre pour le bûcheron et les civils).
Chaque ressource ajoute ses actions :

```lua
exports.elyzea_jobs:AltRegister('mon_metier', function(ctx)      -- ctx.kind = 'player' | 'vehicle' | 'ped' | 'object' | 'world'
    return { { id = 'facture', label = 'Facturer', desc = '...', disabled = false, group = 'Mon métier', order = 10 } }
end, function(id, ctx) --[[ action choisie : ctx.serverId, ctx.entity, ctx.coords ]] end)
```
Le client ne décide rien : chaque action est revérifiée par le serveur de la ressource.

## Pour une ressource de métier
- `exports.elyzea_jobs:Manages(job)`, `Can(src, perm)`, `OnDuty(src, job)`, `HasSpecialty(src, spec)`, `AddLog(job, kind, actor, target, amount, details)`.
- `Seed(job, { label, type, grades })` : définition proposée à la première installation ; `StaffSetGrades(job, label, { {name, payment, isboss} })` : grades modifiés par le staff.
- Service : `AddEventHandler('elyzea_jobs:setDuty', function(src, job, state) ... end)`.
- Tablette : `client_script '@elyzea_jobs/client/bridge.lua'` dans le fxmanifest, puis dans la page :
  `nui://elyzea_jobs/html/ejobs.css`, `nui://elyzea_jobs/html/ejobs.js`, `await EJobs.team()`, `EJobs.mount(element, 'team' | 'boss', { onClose })`.
- Droits côté client : `LocalPlayer.state.ejobs = { job, grade, perms }` (affichage seulement).
