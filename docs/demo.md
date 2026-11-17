# Démo Steam (Steam Next Fest)

La démo est **le même jeu**, exporté avec l'étiquette `demo`. Tout ce qui la
concerne est dans `scripts/jeu/demo.gd` (classe `Demo`).

## Ce qu'il y a dans la démo

| Ouvert | Fermé (fenêtre « Dans le jeu complet » + liste de souhaits) |
|---|---|
| Tutoriel complet (fan club, équipes, prono, voyage, premier duel) | Duels en ligne (salon) |
| Duel d'ambiance, Arène, Poussée contre l'ordinateur | Classement en ligne |
| Carte : compétitions mondiales + Europe | Les 5 autres continents |
| Petits boulots : buvette, speaker | Ramasseur, peintre de tifo, stand d'écharpes |
| Fan club, pronos, missions, équipes favorites, collection, soirs de match (buts en direct) | PASS saisonnier, tournoi, Ligue des tribunes, créateur de chants |
| Progression jusqu'au **niveau 6** (≈ 1 h à 1 h 30) | XP au-delà du niveau 6 |

Au niveau 6, la carte affiche une fois l'écran « Fin de la démo » (liste de
souhaits). Le joueur peut continuer à jouer, sans gagner d'XP.

Autres différences :
- sauvegarde à part : `user://demo_sauvegarde.json` et `user://demo_tutoriel.json`
  (la démo n'écrase jamais une partie du jeu complet) ;
- rien n'est envoyé au classement en ligne ;
- pas de succès Steam ;
- accueil : ruban « DÉMO » et bouton « Ajouter à ma liste de souhaits ».

Réglages (en haut de `demo.gd`) : `NIVEAU_MAX`, `CONTINENTS_OUVERTS`,
`BOULOTS_OUVERTS`, `ECRANS_FERMES`, et les deux App ID Steam à remplir :
- `APP_ID_JEU` : l'App ID du jeu complet (le bouton liste de souhaits ouvre sa page ;
  tant qu'il vaut 0, il ouvre une recherche Steam) ;
- `APP_ID_DEMO` : l'App ID de la démo (tant qu'il vaut 0, la démo utilise 480 pour les essais).

## Essayer la démo sans l'exporter

```
godot --path . -- --demo
```

Tests : `godot --headless --path . res://tests/test_demo.tscn -- --hors-ligne`
(et `test_ecrans.tscn -- --hors-ligne --demo` pour passer tous les écrans en démo).

## Exporter

Les préréglages sont dans `export_presets.cfg` (suivi dans git) :
- **Windows Démo** → `build/demo/windows/FanAroundTheWorld-Demo.exe`
- **Linux Démo** → `build/demo/linux/FanAroundTheWorld-Demo.x86_64` (Steam Deck)
- **Windows** et **Linux** : le jeu complet.

Il faut les modèles d'export Godot 4.7 (Éditeur > Gérer les modèles d'export).
En ligne de commande :

```
godot --headless --path . --export-release "Windows Démo" build/demo/windows/FanAroundTheWorld-Demo.exe
```

Le `.pck` est intégré à l'exe. `libgodotsteam` et `steam_api64.dll` sont copiés
à côté automatiquement. Envoyer tout le dossier `build/demo/windows/` à Steam.
L'icône de l'exe n'est pas modifiée (`application/modify_resources=false`) : il
faudrait rcedit sous Windows ; à faire depuis le PC de Gaël si on veut l'icône.

## Calendrier Steam Next Fest (pages officielles Steamworks)

**Cible : Next Fest de février 2027** (choix de Gaël, 17 nov. 2026).

Un jeu ne participe **qu'une seule fois** au Next Fest. Conditions : compte
Steamworks en règle, **page Steam publiée et publique**, démo jouable au début
du festival, sortie du jeu après le festival.

| | Février 2027 | Juin 2027 |
|---|---|---|
| Festival | 22 fév. – 1er mars (19 h, heure de Paris) | 14 – 21 juin (19 h, heure de Paris) |
| Inscription (depuis la page du jeu) | 10 janvier | 25 avril |
| Démo + page envoyées en revue (pour l'avant-première presse) | 18 janvier | 10 mai |
| Tout envoyé en revue (dernier délai) | 1er février | 24 mai |
| Avant-première presse | 11 février | 3 juin |

## Steamworks : créer la démo (quand le jeu a son App ID)

1. Payer le Steam Direct (100 $) et créer l'app du jeu (décision de Gaël).
2. Publier la page « Bientôt disponible » (revue Valve de quelques jours).
3. Dans l'app du jeu : **Toutes les fiches associées > Créer une démo**. Steam donne un App ID de démo.
4. Mettre les deux App ID dans `demo.gd` (`APP_ID_JEU`, `APP_ID_DEMO`), exporter « Windows Démo » et « Linux Démo ».
5. Envoyer les builds (SteamPipe, dépôt de la démo), régler les options de lancement
   (`FanAroundTheWorld-Demo.exe`), remplir la page de la démo (ou l'afficher sur la page du jeu).
6. Envoyer la build et la page de la démo en revue.
7. S'inscrire au Next Fest depuis la page du jeu (pas celle de la démo).
8. Sortir la démo avant le début du festival (Valve conseille au moins 30 min avant).
