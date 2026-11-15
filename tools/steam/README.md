# Captures et trailer pour la page Steam

Tout est filmé dans le vrai jeu, sans retouche des écrans.

## 1. Calendrier vitrine

```
python3 tools/steam/calendrier_vitrine.py ../fanaroundtheworld-data/static/teams.json
```

Écrit dans `user://cache` une semaine de matchs au format du relais (vraie liste
de clubs, affiches tirées au hasard, 12 matchs en direct). Le jeu affiche les noms
fictifs habituels. À refaire juste avant chaque prise (les directs sont calés sur l'heure).
Avec le vrai relais en ligne, on peut s'en passer.

## 2. Captures (1920×1080)

```
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \
    res://tools/steam/vitrine.tscn -- --hors-ligne --auto --sortie=/chemin/captures
```

`vitrine.gd` prépare une partie avancée (club niveau 7, 16 stades, album entamé),
passe sur chaque écran et enregistre une ou plusieurs images. La sauvegarde du
joueur est remise en place à la fin. `--seule=nom` pour une seule capture.

## 3. Plans du trailer (Movie Maker)

Créer d'abord un `override.cfg` à la racine (ne pas le committer) :

```
[editor]
movie_writer/mjpeg_quality=0.95

[display]
window/size/window_width_override=1920
window/size/window_height_override=1080
```

Puis un lancement par plan (`titre carte voyage tribune duel arene poussee buvette club album carnet`) :

```
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \
    --write-movie plans/duel.avi --fixed-fps 30 res://tools/steam/trailer.tscn \
    -- --hors-ligne --auto --plan=duel > plans/duel.log
```

## 4. Montage

```
python3 tools/steam/monter_trailer.py plans/ sortie/ fr en
```

Il faut ffmpeg, Pillow et les polices du jeu en .ttf dans `plans/polices/`
(conversion : `fontTools`, `TTFont(woff2).flavor = None`). Les plans, textes
FR/EN et durées sont en tête du script. Son : son du jeu + « The Final Turn » (Gaël),
normalisé à −14 LUFS. Sortie H.264 1080p30 + AAC 320 k.
