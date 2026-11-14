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

## Organisation des dossiers

| Dossier | Contenu |
| --- | --- |
| `scenes/` | Scènes Godot (`.tscn`) et leurs scripts, un sous-dossier par écran (`main/`, plus tard `carte/`, `club/`, `duel/`…) |
| `scripts/autoload/` | Scripts globaux chargés au démarrage (`Game` : état du jeu) |
| `assets/fanzzy/` | Les FANZZY (skins cosmétiques), importés depuis thebestfan.online |
| `assets/stades/` | Images des stades et des tribunes |
| `assets/ui/` | Boutons, cadres, icônes de l'interface |
| `assets/fonts/` | Polices (libres de droits uniquement) |
| `assets/audio/` | Chants (`chants/`) et bruitages (`sfx/`) |
| `data/` | Données JSON : clubs fictifs, calendriers réels, saisons du PASS |
| `mods/` | Format des mods Steam Workshop (noms et couleurs de clubs) |
| `docs/` | Game design et maquettes |
| `tests/` | Tests automatiques (à venir) |

## Règles du projet

- **Pas de nom ni de logo officiel** : les clubs ont des noms fictifs, la communauté peut les renommer via des mods.
- **FANZZY purement cosmétiques** : aucun effet sur les duels ni sur les matchs.
- **Budget zéro** : uniquement des outils et des ressources gratuits ou libres de droits.
- Le texte du jeu est en français d'abord.
