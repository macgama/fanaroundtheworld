#!/usr/bin/env python3
"""Calendrier « vitrine » pour les captures et le trailer Steam.

Écrit dans le cache du jeu (user://cache) une semaine de matchs au format du
relais macgama/fanaroundtheworld-data, bâtie sur la vraie liste de clubs
(static/teams.json du dépôt de données). Le jeu affiche ensuite ces matchs
comme s'il les avait reçus en ligne : carte bien remplie, matchs en direct.
Les noms affichés restent les noms fictifs du jeu (Fiction).

    python3 tools/steam/calendrier_vitrine.py chemin/teams.json [dossier_cache]

Matchs clés (identifiants fixes, utilisés par tools/steam/vitrine.gd) :
    vit:classique  Paris Capitale – Phocéens, en direct (2-1, 67e)
    vit:madrid     Madrid Royal – Catalans, en direct (0-0, 34e)
    vit:milan      Milano Diavoli – Interisti, dans 2 h
"""
import json
import os
import random
import sys
from datetime import datetime, timedelta, timezone

LIGUES = {
    "fr.1": "France D1", "es.1": "Espagne D1", "it.1": "Italie D1", "de.1": "Allemagne D1",
    "en.1": "Angleterre D1", "pt.1": "Portugal D1", "nl.1": "Pays-Bas D1", "be.1": "Belgique D1",
    "tr.1": "Turquie D1", "sco.1": "Écosse D1", "br.1": "Brésil D1", "ar.1": "Argentine D1",
    "us.1": "États-Unis D1", "mx.1": "Mexique D1", "jp.1": "Japon D1", "sa.1": "Arabie saoudite D1",
    "australia.1": "Australia D1", "morocco.1": "Morocco D1", "egypt.1": "Egypt D1",
    "south-africa.1": "South Africa D1", "korea-republic.1": "Korea D1",
}
NATIONS = [("af:2", "France"), ("af:772", "Ukraine"), ("af:6", "Brazil"), ("af:26", "Argentina"),
           ("af:9", "Spain"), ("af:25", "Germany"), ("af:12", "Japan"), ("af:31", "Morocco"),
           ("af:16", "Mexico"), ("af:2384", "USA"), ("af:27", "Portugal"), ("af:1118", "Netherlands")]
UCL = [("af:85", "af:157"), ("af:541", "af:50"), ("af:496", "af:529"), ("af:505", "af:211"),
       ("af:42", "af:165"), ("af:489", "af:194")]


def iso(t):
    return t.strftime("%Y-%m-%dT%H:%M:%S.000Z")


def equipe(e):
    return {"id": e["id"], "name": e.get("name", e["id"])}


def match(mid, comp, nom_comp, home, away, kickoff, maintenant, score=None, minute=None):
    ecart = (maintenant - kickoff).total_seconds() / 60.0
    if ecart < 0:
        statut, courant = "SCHEDULED", None
    elif ecart > 115:
        statut = "FINISHED"
        courant = score or {"home": random.randint(0, 3), "away": random.randint(0, 3)}
    else:
        statut = "LIVE"
        courant = score or {"home": random.randint(0, 2), "away": random.randint(0, 2)}
        minute = minute or min(90, int(ecart if ecart < 47 else ecart - 17))
        if 47 <= ecart < 62:
            statut = "HALFTIME"
    m = {
        "id": mid, "competition": {"id": comp, "name": nom_comp}, "kickoff_utc": iso(kickoff),
        "status": statut, "minute": minute if statut == "LIVE" else None, "minute_estimated": False,
        "round": None, "group": None, "venue": None, "home": home, "away": away,
        "score": {"current": courant, "halftime": None, "extratime": None, "penalties": None},
    }
    return m


def main():
    random.seed(2026)
    teams = json.load(open(sys.argv[1], encoding="utf-8"))["competitions"]
    cache = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser(
        "~/.local/share/godot/app_userdata/FanAroundTheWorld/cache")
    os.makedirs(cache, exist_ok=True)
    maintenant = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    aujourdhui = maintenant.replace(hour=0, minute=0)
    matchs = []
    vus = set()

    def ajouter(m):
        matchs.append(m)
        vus.add(m["id"])

    # Les matchs vedettes, toujours au même moment par rapport à maintenant.
    ajouter(match("vit:classique", "fr.1", LIGUES["fr.1"], {"id": "af:85", "name": "af:85"}, {"id": "af:81", "name": "af:81"},
                  maintenant - timedelta(minutes=84), maintenant, {"home": 2, "away": 1}, 67))
    ajouter(match("vit:madrid", "es.1", LIGUES["es.1"], {"id": "af:541", "name": "af:541"}, {"id": "af:529", "name": "af:529"},
                  maintenant - timedelta(minutes=34), maintenant, {"home": 0, "away": 0}, 34))
    ajouter(match("vit:milan", "it.1", LIGUES["it.1"], {"id": "af:489", "name": "af:489"}, {"id": "af:505", "name": "af:505"},
                  maintenant + timedelta(hours=2), maintenant))
    deja = {"af:85", "af:81", "af:541", "af:529", "af:489", "af:505"}

    # Une journée de championnat ce week-end (hier et aujourd'hui) et la suivante (dans 6-7 jours).
    n = 0
    for comp, nom in LIGUES.items():
        clubs = [equipe(e) for e in teams.get(comp, [])]
        if len(clubs) < 4:
            continue
        for journee, base_jour in ((0, -1), (1, 6)):
            random.shuffle(clubs)
            limite = 10 if comp in ("fr.1", "es.1", "it.1", "de.1", "en.1") else 5
            for i in range(0, min(len(clubs) - 1, limite * 2), 2):
                h, a = clubs[i], clubs[i + 1]
                if journee == 0 and (h["id"] in deja or a["id"] in deja):
                    continue
                jour = base_jour + random.choice([0, 0, 1])
                heure = random.choice([13, 15, 17, 19]) if journee == 0 else random.choice([13, 15, 17, 19, 20])
                ko = aujourdhui + timedelta(days=jour, hours=heure, minutes=random.choice([0, 0, 30]))
                if journee == 0 and ko > maintenant - timedelta(minutes=10) and ko < maintenant + timedelta(hours=1):
                    ko = maintenant - timedelta(hours=random.choice([3, 4, 5]))
                n += 1
                ajouter(match("vit:%d" % n, comp, nom, h, a, ko, maintenant))

    # Ligue des champions mardi et mercredi, matchs amicaux de sélections.
    for i, (h, a) in enumerate(UCL):
        ko = aujourdhui + timedelta(days=2 + i % 2, hours=20)
        ajouter(match("vit:ucl%d" % i, "ucl", "Ligue des champions UEFA", {"id": h, "name": h}, {"id": a, "name": a}, ko, maintenant))
    for i in range(0, len(NATIONS), 2):
        (hi, hn), (ai, an) = NATIONS[i], NATIONS[i + 1]
        ko = aujourdhui + timedelta(days=4, hours=18 + i % 3)
        ajouter(match("vit:nat%d" % i, "friendlies", "Matchs amicaux internationaux", {"id": hi, "name": hn}, {"id": ai, "name": an}, ko, maintenant))

    # Fichiers du cache, un par jour (comme le relais).
    for nom in os.listdir(cache):
        if nom.startswith("jour-") or nom in ("index.json", "live.json"):
            os.remove(os.path.join(cache, nom))
    par_jour = {}
    for m in matchs:
        par_jour.setdefault(m["kickoff_utc"][:10], []).append(m)
    jours = []
    for jour, liste in sorted(par_jour.items()):
        json.dump({"day": jour, "matches": liste}, open(os.path.join(cache, "jour-%s.json" % jour), "w", encoding="utf-8"), ensure_ascii=False)
        jours.append({"day": jour, "path": "days/%s.json" % jour})
    json.dump({"attribution": "Données : API-Football (api-sports.io)", "days": jours},
              open(os.path.join(cache, "index.json"), "w", encoding="utf-8"), ensure_ascii=False)
    live = [m for m in matchs if m["status"] in ("LIVE", "HALFTIME")]
    json.dump({"updated_utc": iso(maintenant), "matches": live}, open(os.path.join(cache, "live.json"), "w", encoding="utf-8"), ensure_ascii=False)
    json.dump({"competitions": teams}, open(os.path.join(cache, "teams.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print("%d matchs (%d en direct) sur %d jours -> %s" % (len(matchs), len(live), len(jours), cache))


if __name__ == "__main__":
    main()
