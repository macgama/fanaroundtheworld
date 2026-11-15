# Pronostics sur les vrais matchs

## Le principe : rien à miser

Le joueur pronostique un vrai match **gratuitement**. Un bon pronostic rapporte des
Jetons, un mauvais ne coûte rien. Il n'y a ni mise ni cote.

C'est voulu, pour que le jeu ne soit pas classé « jeu d'argent » ni marqué PEGI
« jeu de hasard simulé » :

- aucun Jeton n'est misé ni perdu ;
- les Jetons ne s'achètent pas (ni en boutique, ni dans le PASS) et ne se revendent pas ;
- les récompenses sont fixes : elles ne dépendent pas d'une cote ni du nombre de joueurs.

**À garder pour la suite :** ne jamais vendre de Jetons, ne jamais en mettre dans le PASS,
ne jamais ajouter de mise. Si un de ces points change, il faut refaire l'analyse légale.

## Ce qu'on pronostique

| Pronostic | Récompense |
|---|---|
| Bon résultat (victoire, nul, défaite) | +10 Jetons |
| Score exact (en plus du résultat) | +30 Jetons |
| Équipe qui marque en premier (ou « aucun but ») | +10 Jetons |

- Le premier but découle parfois du score : 0-0 donne « aucun but », 2-0 donne
  « domicile ». Le joueur ne le choisit que si les deux équipes marquent.
- On parle d'**équipe** qui marque en premier, jamais du joueur : les buteurs sont des
  personnes réelles et leur nom n'apparaît pas dans le jeu.
- Score retenu : fin du match, prolongation comprise, sans les tirs au but.
- Modifiable ou retirable jusqu'au coup d'envoi, plus après.
- 12 pronostics en attente au maximum, pour éviter de cocher les 300 matchs d'un week-end.

## La série

Chaque bon résultat d'affilée ajoute +25 % aux gains suivants, jusqu'à ×2. Un mauvais
résultat remet la série à zéro (rien d'autre). Un match annulé ou reporté ne compte pas.

## Résolution

`Game.resoudre_pronostics()` tourne à chaque mise à jour des données (`Donnees.mis_a_jour`) :

- match `FINISHED` avec un score : résolu, Jetons crédités, signal `Game.pronostics_resolus` ;
- `CANCELLED` ou `POSTPONED` : pronostic annulé ;
- match disparu des données ou `UNKNOWN` plus de 3 jours après le coup d'envoi : annulé.

**Premier but.** Si une seule équipe a marqué, la réponse est évidente. Si les deux ont
marqué, le jeu prend `first_goal` publié par le relais (voir le dépôt de données). Sinon,
il se sert de ce qu'il a vu en direct (passage de 0-0 à 1-0 ou 0-1). Si personne ne sait,
cette partie ne rapporte rien mais ne casse pas la série.

## Fichiers

- `scripts/jeu/pronostics.gd` : les règles, sans écran (testées par `tests/test_pronostics.gd`).
- `scripts/jeu/prono_texte.gd` : textes d'affichage.
- `scripts/autoload/game.gd` : pronostics en cours, historique, série, sauvegarde.
- `scenes/carte/carte.gd` : bloc « Ton pronostic » dans la fiche du match, annonce des résultats.
- `scenes/pronostics/` : écran « Mes pronos ».
