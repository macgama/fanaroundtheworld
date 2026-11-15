# Jouer contre un ami ou un autre joueur

Le **duel d'ambiance** et la **Poussée** se jouent contre un vrai joueur. L'Arène reste
contre l'IA pour l'instant (voir « Étapes suivantes »).

## Pour le joueur

- **Ta tribune** → **CONTRE UN JOUEUR** : ouvre un salon sur le match choisi, ton camp.
- **Carte** → **En ligne** : rejoindre un ami, trouver un adversaire, ou ouvrir un salon
  (le match est alors le prochain match du calendrier).
- Dans le salon, chacun voit le fan club et les 3 FANZZY de l'autre (avec ses skins).
  L'hôte choisit **DUEL D'AMBIANCE** ou **POUSSÉE**. L'invité soutient l'autre équipe du match.
- Après le duel : **Revanche** (retour au salon, toujours connectés) ou retour à la carte.
- Si l'adversaire s'en va pendant le duel, tu gagnes par forfait.

## Architecture (budget zéro, pas de serveur)

```
 Joueur A (hôte)                          Joueur B (invité)
 ┌───────────────────────┐   gestes       ┌───────────────────────┐
 │ duel.gd               │ <───────────── │ duel.gd               │
 │  piste de rythme      │   « pousse »   │  piste de rythme      │
 │  JaugePartagee (foi)  │ ─────────────> │  JaugePartagee        │
 │                       │  « etat » x10/s│  (prédit ses gestes)  │
 └──────────┬────────────┘                └──────────┬────────────┘
            └──────── Reseau (autoload) ─────────────┘
                 Steam (GodotSteam)  ou  ENet (réseau local / IP)
```

- **Un hôte, un invité, en pair à pair.** Aucun serveur à payer : avec Steam, la
  connexion passe par les relais de Valve (gratuits pour les jeux Steam) ; sans Steam,
  ENet en direct.
- **Chacun joue sa piste de rythme chez lui** : pas de décalage ressenti sur les notes.
  Seuls les effets sur la jauge voyagent (« pousse »), plus quelques évènements
  (tifo, ola, gros combo) pour animer la tribune d'en face.
- **L'hôte fait foi pour la jauge** (`Protocole.JaugePartagee`) : il applique ses
  gestes et ceux de l'invité dans l'ordre d'arrivée et renvoie la jauge 10 fois par
  seconde. L'invité voit ses gestes tout de suite, puis se recale en rejouant ceux que
  l'hôte n'a pas encore reçus. À la fin, la jauge de l'hôte décide.
- En ligne, la « pression » de l'IA disparaît : c'est l'autre joueur qui pousse.
  Le vrai score du match donne toujours son bonus, à chacun pour son équipe.
- Tout message reçu est vérifié (`Protocole.valide`, `Protocole.profil_propre`) :
  type connu, nombres finis, geste plafonné à ±25, nom coupé, noms de skins filtrés.

| Fichier | Rôle |
|---|---|
| `scripts/reseau/protocole.gd` | Messages, profils, jauge partagée, annonces LAN (testé sans réseau) |
| `scripts/autoload/reseau.gd` | Transport : Steam ou ENet, salons, invitations, recherche |
| `scenes/salon/` | Écran du salon |
| `scenes/duel/duel.gd` | Mode en ligne du duel d'ambiance |
| `scenes/poussee/poussee.gd` | Mode en ligne de la Poussée |

### La Poussée en ligne

- **L'hôte simule toute la partie** (unités, ballon, tribunes, Ferveur des deux camps,
  et la pile de cartes de l'invité). Pas de « lockstep » : les calculs en nombres à virgule
  et le temps de chaque image ne sont pas identiques d'un PC à l'autre, une simulation en
  double finirait par diverger.
- **L'invité envoie ses cartes** (« carte » : n° dans sa main + position) et reçoit
  20 instantanés par seconde (« instant » : temps, Ferveur, tribunes, ballon, sa main,
  zones d'effet, unités avec leur vie et des compteurs de chants et de coups pour rejouer
  les animations). Ses FANZZY glissent vers les positions reçues.
- **Terrain retourné chez l'invité** : chacun se voit à gauche et attaque vers la droite
  (`Protocole.miroir_x`). L'hôte vérifie la carte (dans la main, dans la bonne moitié,
  assez de Ferveur) avant de la poser.
- Une carte de l'invité met un aller-retour réseau à apparaître (souvent moins de 0,1 s) :
  normal pour un jeu de cartes.

### Les deux transports

| | Réseau local (ENet) | Steam (GodotSteam) |
|---|---|---|
| Disponible | toujours | si l'extension GodotSteam est installée et que Steam tourne |
| Défier un ami | « Créer un salon », l'ami clique sur ton salon (trouvé tout seul sur le même réseau) ou tape ton adresse IP | « Défier un ami Steam » ouvre la fenêtre d'invitation Steam ; l'ami accepte depuis Steam |
| Autres joueurs | « Trouver une partie » : salons du réseau local | « Trouver un adversaire » : rejoint un salon public libre dans le monde, sinon en ouvre un |
| Ports | 24680 (jeu), 24681 (annonces) | aucun port à ouvrir |

Par Internet sans Steam, l'hôte doit ouvrir le port 24680 de sa box : c'est réservé aux
tests. Pour les vrais joueurs, Steam s'occupe de tout.

### Steam (GodotSteam)

L'extension **GodotSteam GDExtension 4.24** (Steamworks SDK 1.65, licence MIT, projet
hébergé sur Codeberg) est dans `addons/godotsteam/` : Windows 64 bits, Linux 64 bits et
macOS. `SteamMultiplayerPeer` en fait partie. Elle se charge ; le jeu passe tout seul en
réseau local si Steam n'est pas lancé.

1. Lancer avec Steam ouvert (test : `godot --path . -- --scene=salon --salon=steam --journal`).
2. `steam_appid.txt` contient 480. Tant que le jeu n'a pas son App ID (100 $ de frais Steam
   Direct, pas encore payés), `Reseau.APP_ID_STEAM = 480` : l'appli de test de Valve
   (« Spacewar »). Les salons sont filtrés par `jeu = fanaroundtheworld` et la version.
3. Tester à deux comptes Steam sur deux PC : « Défier un ami Steam » puis invitation.
4. Le jour où le jeu a son App ID : changer `APP_ID_STEAM`, rien d'autre.

## Tester sans Steam

Deux fenêtres sur le même PC (ou deux PC du même réseau) :

    godot --path . -- --scene=salon --salon=hote --auto
    godot --path . -- --scene=salon --salon=127.0.0.1 --auto

`--auto` : la tribune joue toute seule et l'hôte lance le duel dès que l'invité arrive.
`--jeu=poussee` (côté hôte) : lance la Poussée au lieu du duel d'ambiance.
`--quitter` : écrit le résultat et ferme à la fin du duel.
Tests sans réseau : `godot --headless --path . --script tests/test_reseau.gd`.

Vérifié : un duel complet entre deux jeux (jauges finales identiques, ±100),
une Poussée complète (fin du temps, tribunes 1200/1020 des deux côtés, 33 cartes de l'invité
posées chez l'hôte),
et l'invité qui coupe en plein duel (l'hôte gagne par forfait). Les deux jeux d'un
même PC partagent la même sauvegarde : normal pour un test.

## Limites connues

- Les récompenses restent calculées chez chaque joueur (sauvegarde locale) : un
  tricheur peut modifier son propre jeu. Pas grave tant qu'il n'y a pas de classement ;
  pour un classement en ligne, il faudra un arbitre (l'hôte ou un petit serveur).
- Pas de classement, d'historique ni de liste d'amis dans le jeu (Steam fournit la liste d'amis).
- Une seule partie à la fois, 1 contre 1.

## Étapes suivantes proposées

1. Tester Steam avec l'App ID 480 sur deux PC (deux comptes Steam).
2. **Arène en ligne** : même principe que la Poussée (l'hôte simule), mais l'invité bouge
   en continu : il faudra prédire son propre FANZZY pour que ça reste réactif.
3. Classement par saison et récompenses de duel en ligne, une fois le PASS en place.
