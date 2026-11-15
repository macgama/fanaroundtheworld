# Jouer contre un ami ou un autre joueur

Prototype v0.4 : le **duel d'ambiance** se joue contre un vrai joueur. Arène et Poussée
restent contre l'IA pour l'instant (voir « Étapes suivantes »).

## Pour le joueur

- **Ta tribune** → **CONTRE UN JOUEUR** : ouvre un salon sur le match choisi, ton camp.
- **Carte** → **En ligne** : rejoindre un ami, trouver un adversaire, ou ouvrir un salon
  (le match est alors le prochain match du calendrier).
- Dans le salon, chacun voit le fan club et les 3 FANZZY de l'autre (avec ses skins).
  L'hôte appuie sur **LANCER LE DUEL**. L'invité soutient l'autre équipe du match.
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

### Les deux transports

| | Réseau local (ENet) | Steam (GodotSteam) |
|---|---|---|
| Disponible | toujours | si l'extension GodotSteam est installée et que Steam tourne |
| Défier un ami | « Créer un salon », l'ami clique sur ton salon (trouvé tout seul sur le même réseau) ou tape ton adresse IP | « Défier un ami Steam » ouvre la fenêtre d'invitation Steam ; l'ami accepte depuis Steam |
| Autres joueurs | « Trouver une partie » : salons du réseau local | « Trouver un adversaire » : rejoint un salon public libre dans le monde, sinon en ouvre un |
| Ports | 24680 (jeu), 24681 (annonces) | aucun port à ouvrir |

Par Internet sans Steam, l'hôte doit ouvrir le port 24680 de sa box : c'est réservé aux
tests. Pour les vrais joueurs, Steam s'occupe de tout.

### Brancher Steam (à faire, rien à payer pour tester)

Le code Steam est écrit mais **pas encore testé** : il faut l'extension et un PC avec Steam.

1. Dans Godot : AssetLib → **GodotSteam GDExtension** (version 4.x pour Godot 4.5),
   installer. Il faut la classe `SteamMultiplayerPeer` (incluse dans les versions
   récentes de GodotSteam, sinon l'extension « GodotSteam MultiplayerPeer »).
2. Lancer avec Steam ouvert. Tant que le jeu n'a pas son App ID (100 $ de frais Steam
   Direct, pas encore payés), `Reseau.APP_ID_STEAM = 480` : l'appli de test de Valve
   (« Spacewar »). Les salons sont filtrés par `jeu = fanaroundtheworld` et la version.
3. Tester à deux comptes Steam sur deux PC : « Défier un ami Steam » puis invitation.
4. Le jour où le jeu a son App ID : changer `APP_ID_STEAM`, rien d'autre.

## Tester sans Steam

Deux fenêtres sur le même PC (ou deux PC du même réseau) :

    godot --path . -- --scene=salon --salon=hote --auto
    godot --path . -- --scene=salon --salon=127.0.0.1 --auto

`--auto` : la tribune joue toute seule et l'hôte lance le duel dès que l'invité arrive.
`--quitter` : écrit le résultat et ferme à la fin du duel.
Tests sans réseau : `godot --headless --path . --script tests/test_reseau.gd`.

Vérifié : un duel complet entre deux jeux (jauges finales +82,6 / −82,6, identiques),
et l'invité qui coupe en plein duel (l'hôte gagne par forfait). Les deux jeux d'un
même PC partagent la même sauvegarde : normal pour un test.

## Limites connues

- Les récompenses restent calculées chez chaque joueur (sauvegarde locale) : un
  tricheur peut modifier son propre jeu. Pas grave tant qu'il n'y a pas de classement ;
  pour un classement en ligne, il faudra un arbitre (l'hôte ou un petit serveur).
- Pas de classement, d'historique ni de liste d'amis dans le jeu (Steam fournit la liste d'amis).
- Une seule partie à la fois, 1 contre 1.

## Étapes suivantes proposées

1. Installer GodotSteam et tester avec l'App ID 480 sur deux PC.
2. **Poussée en ligne** : la simulation se prête au « lockstep » (on n'échange que les
   cartes posées, avec leur instant) ; il faudra rendre ses tirages aléatoires communs.
3. **Arène en ligne** : l'hôte simule, l'invité envoie ses commandes et reçoit des
   instantanés (plus de travail, à faire après Poussée).
4. Classement par saison et récompenses de duel en ligne, une fois le PASS en place.
