# Version Android (test)

Premier portage pour essayer le jeu sur téléphone. Pas sur le Play Store : l'APK
s'installe à la main.

## Installer l'APK sur un téléphone

1. Sur le téléphone, ouvrir
   <https://github.com/macgama/fanaroundtheworld/releases/download/android-test/FanAroundTheWorld.apk>
   (toujours la dernière version construite depuis `main`).
2. Android demande d'autoriser l'installation depuis le navigateur (« sources
   inconnues ») : accepter pour ce navigateur.
3. Ouvrir le fichier téléchargé, puis **Installer**. Play Protect peut prévenir
   que l'appli est inconnue : « Installer quand même ».

Une nouvelle version s'installe par-dessus l'ancienne (même clé, numéro de
version qui augmente) : la sauvegarde est gardée.

Android 7 ou plus récent, en paysage. Processeurs ARM 32 et 64 bits.

## Ce qui change sur téléphone

Tout est dans l'autoload `Mobile` (`scripts/autoload/mobile.gd`) :

- **Steam est coupé** : l'extension GodotSteam n'est pas dans l'APK et
  `Plateforme` ne l'ouvre pas. Succès gardés dans la sauvegarde, pas de Steam
  Cloud, en ligne en réseau local (ou adresse IP) seulement, PASS Premium pas
  achetable (pas encore de paiement mobile).
- **Interface agrandie** sur les écrans de menus (jusqu'à ×1,25 sur un téléphone
  20:9 ; un écran 16:9 reste à ×1 pour ne pas déborder). Les écrans de jeu
  (duel, arène, poussée, petits boulots, voyage, tribune) gardent leur échelle.
  Textes de moins de 18 px agrandis (`Ui.taille_mini`). Panneaux trop hauts :
  ils défilent au doigt (`Ui.defilement`).
- **Bouton retour d'Android** = touche Échap (pause, fermer une fenêtre).
- **Bouton pause** (II) en haut à gauche en duel, arène et poussée.
- **Arène au doigt** (`scripts/ui/commandes_tactiles.gd`) : joystick à gauche,
  boutons à droite. *Tir* vise tout seul l'adversaire le plus proche (maintenir
  pour le tir chargé quand il est débloqué), *Super*, *Roulade*, *Changer* ;
  toucher le terrain tire à cet endroit. Plusieurs doigts à la fois.
- Les autres modes se jouaient déjà à la souris : un doigt fait pareil.
- Créateur de chants : pendant l'écoute, toucher l'écran = taper le rythme.
- Option « Plein écran » cachée (toujours plein écran).

Pour essayer sur PC : `godot --path . -- --mobile` (fenêtre en 20:9 pour voir
l'agrandissement, par exemple `--resolution 2400x1080`).

## Construire l'APK

Automatique sur GitHub (`.github/workflows/android.yml`) : à chaque pull request
(APK dans les *Artifacts* du run) et à chaque push sur `main` (APK publié dans la
pré-version `android-test`). Godot 4.7, export sans Gradle.

À la main : préréglage d'export dans `tools/android/export_presets.cfg` (à copier
en `export_presets.cfg`, qui n'est pas suivi par git), SDK Android et JDK 17 dans
les réglages de l'éditeur, puis :

```
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=tools/android/test.keystore \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=fanaroundtheworld \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=fanaroundtheworld \
godot --headless --path . --export-release "Android" build/android/FanAroundTheWorld.apk
```

La clé `tools/android/test.keystore` sert **seulement aux versions de test** (elle
est publique). Pour le Play Store : nouvelle clé gardée en secret GitHub, et un
AAB (Gradle) au lieu de l'APK.

## Tests

- `tests/test_tactile.gd` : joystick, boutons, plusieurs doigts.
- `tests/test_petit_ecran.tscn` : chaque écran tient sur un téléphone
  (`xvfb-run -a godot --path . --resolution 2400x1080 res://tests/test_petit_ecran.tscn -- --hors-ligne --mobile`,
  puis la même chose en `1920x1080`).

## Reste à faire

- Essayer sur de vrais téléphones (performances, taille des textes, encoche).
- Aides à l'écran qui parlent encore de touches du clavier (« ESPACE », « clic droit »…).
- Icône d'appli dédiée (aujourd'hui l'icône du projet).
- Sauvegarde dans le cloud et succès hors Steam (Google Play Jeux), paiement du PASS.
