# PASS saisonnier

Bouton **PASS** en bas de la carte et du fan club (il passe au jaune avec le nombre
de récompenses à récupérer). Logique : `scripts/jeu/pass_saison.gd`, écran :
`scenes/pass/`, paliers : `data/pass/saison-2026-27.json`, tests : `tests/test_pass.gd`
et `tests/test_pass_jeu.tscn`. Design validé : doc « PASS saisonnier FanAroundTheWorld »
(15 nov. 2026).

## Règles

- Une saison suit la vraie saison de foot : **1er août → dernier week-end de mai**
  (Saison 1 = 2026-27, fin le 30 mai 2027), en **4 chapitres de 25 paliers** :
  Frissons (Halloween), Âge de glace (préhistorique), Fin du monde (apocalyptique),
  Les finales (doré).
- **100 paliers de 1 000 XP**. Le palier 1 est acquis dès le départ.
- **Piste gratuite** (52 récompenses) : 8 recrues FANZZY jouables (paliers 1, 25, 37, 50,
  63, 75, 87, 100), des Jetons (200 à 500), 2 skins par chapitre, une écharpe ou un drapeau,
  une émote et un décor par chapitre.
- **Piste Premium** (100 récompenses, une par palier) : uniquement de l'apparence. Skins
  (dont une « tribune complète » de 5 skins aux paliers 25, 50, 75 et 99), écharpes, drapeaux,
  motifs de tifo, décors du local, émotes, sons de tribune, couverture de carnet, titres.
  Palier 1 : skin doré de la première recrue ; palier 100 : le légendaire doré et le titre
  « Tour du monde 2026-27 ». **Jamais** de FANZZY jouable, de geste, de Jetons ni de bonus.
- **Prix : 7,99 €**, DLC Steam payé en euros. Pas de monnaie virtuelle, pas de paliers ni
  de boost d'XP à acheter. Acheté en cours de saison, il débloque tout de suite les
  récompenses Premium des paliers déjà atteints.
- **Paliers bonus** après le 100 : +100 Jetons tous les 1 000 XP.
- **Rattrapage** : un joueur en retard sur le rythme de la saison (palier attendu à la date,
  calculé sur toute la saison) gagne **double XP sur ses missions**.
- **Intersaison** (juin-juillet) : l'XP est mise de côté pour la saison suivante, jusqu'à
  10 paliers. Au 1er août, nouvelle saison : Premium et récompenses remis à zéro, les skins,
  recrues, objets et titres gagnés restent pour toujours.
- Les recrues du PASS sont dans `assets/fanzzy/fanzzy.json` avec un champ `pass` (palier) :
  elles ne sont jouables (tribune, fan club, Poussée…) qu'une fois récupérées.
- Un skin du PASS se choisit dans **FANZZY** (flèches de skin), comme les évolutions.

## D'où vient l'XP de PASS

| Source | XP | Remarque |
|---|---|---|
| Missions du jour / semaine | 50-75 / 200-300 | ×2 pendant le rattrapage (voir `docs/missions.md`) |
| Duel (ambiance, Arène, Poussée) | 50 + 25 selon la perf. + 25 si victoire | même match rejoué le même jour : 100 %, 50 %, 25 %, puis 0 |
| Premier tampon d'un stade | 200 | |
| Pronostic juste | 30, ou 100 pour le score exact | |
| Événement (derby, finale…) | prime du premier duel | voir `docs/evenements.md` |

Valeurs de départ, à régler en test : constantes en tête de `PassSaison`.

## Ce qui reste à faire

- **Achat réel** : créer le DLC « PASS Premium » dans Steamworks puis mettre son App ID
  dans `Game.DLC_PASS_PREMIUM` (le jeu ouvre alors la page du DLC et détecte l'achat).
  En attendant, le bouton explique que l'achat se fera sur Steam. Pour tester le Premium :
  `-- --premium` (et `--xp-pass=N` pour se placer à un palier).
- **Objets d'apparence** (écharpes, drapeaux, tifos, décors, émotes, sons, couvertures,
  titres) : gagnés et sauvegardés (`Game.etat_pass.objets` / `titres`), mais pas encore
  affichés ailleurs que dans le PASS.
- **Thème doré** : fabriqué en teintant l'image de base (`tools/pass/generer_pass.py`),
  à remplacer par de vrais dessins.
- **Palier 100** : « La Mosaïque de Séville » tient la place du légendaire « Carnet plein »
  (CP1, Le Gardien du Feu) tant qu'il n'a pas de visuels.

## Refaire une saison

`python3 tools/pass/generer_pass.py <dossier fanzzy exporté de TheBestFan>` écrit les paliers,
ajoute les recrues au catalogue et fabrique les images des skins (corps 440 px, buste 160 px).
Une nouvelle saison = un nouveau fichier `data/pass/saison-<aaaa-aa>.json` ; sans fichier,
l'écran affiche « saison en préparation » et l'XP est gardée.
