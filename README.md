# FanAroundTheWorld

Jeu PC (Steam) en 2D, fait avec **Godot 4**. Tu diriges un fan club de football,
tu voyages vers les vrais matchs du calendrier, tu collectionnes les stades et
tu affrontes les autres tribunes dans des **duels d'ambiance**.

Le concept complet est dans [docs/GDD.md](docs/GDD.md).

## Lancer le projet

1. Installer [Godot 4.5](https://godotengine.org/download) (version standard, pas besoin de .NET).
2. Ouvrir Godot, cliquer sur **Importer** et choisir le fichier `project.godot` de ce dossier.
3. Appuyer sur **F5** pour lancer le jeu.

Le projet utilise le moteur de rendu *Compatibilité* pour tourner sur les petits PC
et, plus tard, sur mobile.

## Le prototype jouable (v0.3)

1. **Écran titre** : clique sur **JOUER**. La première fois, **crée ton fan club** :
   nom, deux couleurs, écusson. Tes 3 FANZZY de tribune sont les membres fondateurs.
2. **Carte du monde** : les vrais matchs de la semaine (de la veille à J+7), relus
   toutes les 30 min, et le live relu chaque minute. Clique sur un continent, puis sur
   un pays. À gauche, la liste des matchs (filtre par jour ou « Direct »). Molette pour
   zoomer, glisser pour déplacer.
3. Choisis un match : à droite, choisis ton camp et **où suivre le match** (stade,
   écran géant, pub, maison), puis **C'EST PARTI !**
   Dans la même fiche, **Ton pronostic** : un score et l'équipe qui marque en premier,
   gratuit et modifiable jusqu'au coup d'envoi. Le bouton **Pronos** liste tes
   pronostics et ta série (voir `docs/pronostics.md`).
4. Au stade : le car du fan club voyage jusqu'au stade, qui est **tamponné**.
5. **Ta tribune** : choisis tes 3 FANZZY (Chant, Tifo, Ola) et leurs skins.
6. **Duel d'ambiance** (90 s) :
   - **ESPACE** (ou clic sur *Chant*) quand la note bleue arrive dans le cercle ;
   - **T** quand le tifo est chargé ;
   - **O** quand l'ola est prête, puis les **flèches** dans l'ordre ;
   - touches de test : **B** simule un but pour ton équipe, **N** un but adverse.

**Le fan club** (bouton *Fan Club* en bas de la carte) :

- **Recruter** des FANZZY : gratuit, mais le nombre de places dépend du niveau du club
  (3 au niveau 1, puis +2 par niveau).
- **Cotisations** : chaque membre verse 1 Jeton par heure.
- **Buvette** : à ouvrir puis améliorer avec des Jetons ; elle rapporte double pendant
  3 h après chaque duel.
- **Atelier d'écharpes** : tricote des écharpes à vendre, leur prix monte avec la taille du club.
- **Bonus de taille** : +5 % sur les recettes par membre. La caisse garde 8 h de recettes,
  il faut passer **récolter**.

Sans internet, le jeu garde la dernière semaine téléchargée. La toute première fois
sans réseau, il affiche 16 matchs d'exemple. La partie est sauvegardée dans
`user://sauvegarde.json` (sous Windows : `%APPDATA%\Godot\app_userdata\FanAroundTheWorld`).
Supprime ce fichier pour recommencer à zéro.

## Organisation des dossiers

| Dossier | Contenu |
| --- | --- |
| `scenes/` | Scènes Godot (`.tscn`) et leurs scripts, un sous-dossier par écran (`main/`, `carte/`, `voyage/`, `tribune/`, `duel/`, `pronostics/`, `club/`) |
| `scripts/autoload/` | Scripts globaux chargés au démarrage (`Game` : état du jeu et sauvegarde, `Donnees` : vrais matchs) |
| `scripts/donnees/` | Noms fictifs (`fiction.gd`), placement sur la carte (`geo.gd`), fiche d'un match |
| `scripts/jeu/` | Règles du jeu sans écran (pronostics) |
| `scripts/club/` | Règles du fan club (`fan_club.gd` : membres, cotisations, buvette, écharpes) |
| `scripts/carte/` | La carte du monde dessinée |
| `scripts/ui/` | Style commun de l'interface (couleurs, boutons, icônes) |
| `assets/fanzzy/` | Les FANZZY (personnages jouables, avec leurs skins cosmétiques), importés depuis thebestfan.online |
| `assets/stades/` | Images des stades et des tribunes |
| `assets/ui/` | Boutons, cadres, icônes de l'interface |
| `assets/fonts/` | Polices (libres de droits uniquement) |
| `assets/audio/` | Chants (`chants/`) et bruitages (`sfx/`) |
| `data/` | Données JSON : carte (`carte/`), noms fictifs des clubs (`clubs/`), matchs d'exemple hors ligne (`exemple/`) |
| `tools/` | Scripts de préparation des données (carte du monde, repérage des bras des FANZZY) |
| `mods/` | Format des mods Steam Workshop (noms et couleurs de clubs) |
| `docs/` | Game design et maquettes |
| `tests/` | Tests automatiques (`godot --headless --path . --script tests/test_logique.gd`, `tests/test_pronostics.gd`, `tests/test_club.gd`, et le parcours complet : `godot --headless --path . res://tests/test_pronostics_jeu.tscn -- --hors-ligne`) |

## Règles du projet

- **Pas de nom ni de logo officiel** : les clubs ont des noms fictifs, la communauté peut les renommer via des mods.
- **FANZZY** : leur famille donne leur geste en duel ; leurs **skins sont purement cosmétiques**.
- **Budget zéro** : uniquement des outils et des ressources gratuits ou libres de droits.
- Le texte du jeu est en français d'abord.

## Crédits

- Carte du monde : Natural Earth (domaine public), via world-atlas. Capitales : paquet countryinfo.
- Polices : Lilita One et Nunito (SIL Open Font License, voir `assets/fonts/`).
- Données de match : voir le champ `attribution` affiché sur l'écran titre.
