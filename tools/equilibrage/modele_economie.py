#!/usr/bin/env python3
"""Modèle de l'économie de FanAroundTheWorld (Jetons, niveau du fan club, PASS).

    python3 tools/equilibrage/modele_economie.py            # réglages actuels du jeu
    python3 tools/equilibrage/modele_economie.py --avant    # réglages d'avant l'équilibrage du 17 nov. 2026

Trois profils de joueurs jouent une saison du PASS (1er août -> 30 mai, 303 jours).
Chaque jour joué, le profil fait un nombre fixe d'activités avec une réussite moyenne
(pas de hasard : c'est un joueur « moyen » de chaque profil). Le modèle suit les
formules du jeu (voir les fichiers cités) ; quand une règle du jeu change, mettre à
jour ce fichier et relancer. Les chiffres sont recopiés dans docs/equilibrage.md.

Ce qui n'est pas modélisé : les événements (derbys, finales), le tournoi et la Ligue
(au plus quelques centaines de Jetons par semaine), les primes de collection hors
tampons de stades, l'album, les soirs de match (ajoutés en forfait au profil passionné).
"""
import sys

AVANT = "--avant" in sys.argv

# ---------------------------------------------------------------- réglages du jeu
R = {
    # scripts/autoload/game.gd : niveau du fan club
    "xp_niveau": "progressif",           # "plat" = 200 XP par niveau ; "progressif" = voir xp_pour_niveau()
    # scripts/club/fan_club.gd
    "places": "progressif",              # "plat" = 3 + 2 par niveau ; "progressif" = voir places()
    "cotisation_h": 1.0, "bonus_membre": 0.05, "heures_caisse": 8.0,
    "buvette_h": [0, 3, 6, 10, 15, 21], "cout_buvette": [40, 100, 220, 450, 900],
    "atelier_h": [0, 1, 2, 3, 4, 6], "cout_atelier": [30, 80, 180, 380, 800],
    "prix_echarpe": lambda m: 2 + m // 3,
    "stock_echarpes": lambda niv: 6 + 6 * niv,
    # scripts/duel/fin_duel.gd + scenes/duel/duel.gd
    "duel_base": 10, "duel_perf": 20, "duel_victoire": 15,
    "facteur_mode": {"duel": 1.0, "arene": 1.0, "poussee": 1.0},
    # scripts/jeu/pass_saison.gd
    "xp_pass_duel": (50, 25, 25), "xp_pass_stade": 200, "xp_pass_prono": (30, 100),
    # scripts/jeu/missions.gd (moyennes des listes) : (Jetons, XP PASS)
    "mission_jour": (16, 62), "bonus_jour": (10, 50), "mission_semaine": (71, 287), "bonus_semaine": (50, 250),
    # petits boulots : paye ÷ 2 après 3 parties du même boulot dans la journée
    "boulot_plein": 3, "boulot_apres": 0.5,
    # billet du stade (Game.MODES_SUIVI) ; trajets : facteur sur le prix moyen du profil
    # (nouveau barème Deplacement.cout_base : +30 % sur un trajet national, x2 à l'autre bout du monde)
    "billet_stade": 20, "trajet_facteur": 1.0,
    # scripts/jeu/deplacement.gd (XP PASS = ferveur × 2) et soirs de match (buts + prime)
    "xp_pass_ferveur": 2, "xp_pass_soiree": 150,
}
if not AVANT:
    R.update({
        "cotisation_h": 0.25, "bonus_membre": 0.02,
        "buvette_h": [0, 1, 1.5, 2, 3, 4],
        "atelier_h": [0, 0.5, 0.75, 1, 1.25, 1.5], 
        "prix_echarpe": lambda m: 1 + m // 6,
        "stock_echarpes": lambda niv: 6 + 4 * niv,
        "facteur_mode": {"duel": 1.0, "arene": 1.3, "poussee": 1.6},
        "duel_perf_ambiance": 40,
        "xp_pass_duel": (12, 6, 6), "xp_pass_stade": 100, "xp_pass_prono": (15, 50), "xp_pass_ferveur": 1, "xp_pass_soiree": 75,
        "mission_jour": (16, 31), "bonus_jour": (10, 25), "mission_semaine": (71, 143), "bonus_semaine": (50, 125),
        "billet_stade": 25, "trajet_facteur": 1.4,
        "boulot_plein": 2, "boulot_apres": 0.5, "boulot_quart": 5,
    })
else:
    R.update({"xp_niveau": "plat", "places": "plat", "duel_perf_ambiance": 40})


def xp_pour_niveau(n):
    """XP à gagner pour passer du niveau n au niveau n+1."""
    if R["xp_niveau"] == "plat":
        return 200
    return 200 if n <= 5 else 200 + 100 * (n - 5)


def niveau(xp):
    n = 1
    while xp >= xp_pour_niveau(n):
        xp -= xp_pour_niveau(n)
        n += 1
    return n


def places(n):
    if R["places"] == "plat":
        return 3 + 2 * (n - 1)
    return 3 + 2 * (min(n, 5) - 1) + max(0, n - 5)


MEMBRES_MAX = 18  # « Légende du virage »


# ---------------------------------------------------------------- joueurs moyens
PERF, VICTOIRE, EQUIPE_GAGNE = 0.5, 0.55, 0.2
DUEL_XP = 40 + 30 + 40 * VICTOIRE  # XP du fan club d'un duel moyen
BOULOT_JETONS, BOULOT_XP = 28, 30  # moyenne réelle buvette/ramasseur/speaker/tifo/écharpes
GAIN_LIEU = {"stade": 1.5, "ecran": 1.2, "pub": 1.0, "maison": 0.6}
BILLET = {"stade": 20, "ecran": 8, "pub": 4, "maison": 0}

PROFILS = {
    # jours joués par semaine, duels [(lieu, mode, nb duels sur le même match)], boulots, récoltes, pronos, stades/semaine
    "occasionnel (20 min)": dict(jours=5, duels=[("maison", "duel", 1), ("pub", "duel", 1), ("pub", "poussee", 1), ("maison", "arene", 1)],
                                  boulots=2, recoltes=1, pronos=2, stades_semaine=1, trajet=12, missions=2, semaine=2),
    "régulier (1 h)": dict(jours=6, duels=[("stade", "duel", 2), ("pub", "duel", 1), ("pub", "arene", 1), ("ecran", "poussee", 1),
                                         ("maison", "duel", 2), ("maison", "arene", 1), ("pub", "poussee", 1), ("ecran", "duel", 1)],
                            boulots=5, recoltes=2, pronos=4, stades_semaine=4, trajet=20, missions=3, semaine=3),
    "passionné (3 h)": dict(jours=7, duels=[("stade", "duel", 3), ("stade", "poussee", 3), ("ecran", "duel", 2), ("pub", "arene", 2),
                                          ("pub", "duel", 2), ("pub", "poussee", 2), ("maison", "duel", 3), ("maison", "arene", 3),
                                          ("ecran", "arene", 2), ("maison", "poussee", 3), ("pub", "duel", 3), ("ecran", "duel", 2)],
                             boulots=15, recoltes=4, pronos=8, stades_semaine=10, trajet=40, missions=3, semaine=3, soiree=40),
}
REJEU = [1.0, 0.5, 0.25]


def jetons_duel(lieu, mode, rang):
    perf_j = R["duel_perf_ambiance"] if mode == "duel" else R["duel_perf"]
    base = R["duel_base"] + perf_j * PERF + R["duel_victoire"] * VICTOIRE
    base *= GAIN_LIEU[lieu] * (1 + 0.3 * EQUIPE_GAGNE) * R["facteur_mode"][mode]
    return base * (REJEU[rang] if rang < len(REJEU) else 0)


def xp_pass_duel(rang):
    a, b, c = R["xp_pass_duel"]
    return (a + b * PERF + c * VICTOIRE) * (REJEU[rang] if rang < len(REJEU) else 0)


def boulots_jetons(n):
    """n parties réparties sur les 5 boulots, chacun : plein tarif, puis ÷2 (puis ÷4 après)."""
    total = 0.0
    for i in range(n):
        rang = i // 5  # parties du même boulot ce jour-là (0, 1, 2…)
        if rang < R["boulot_plein"]:
            f = 1.0
        elif rang < R.get("boulot_quart", 99):
            f = R["boulot_apres"]
        else:
            f = 0.25
        total += BOULOT_JETONS * f
    return total


def simuler(nom, p, jours=303):
    jetons, xp, xp_pass = 150, 0, 0
    buv = atel = 0
    stock = 0.0
    sources = {}
    depenses = {"billets+trajets": 0, "local": 0}
    jour_max_local = None
    jours_niveau = {}
    jour_pass_100 = None
    paliers = {}

    def gagner(cle, n):
        nonlocal jetons
        jetons += n
        sources[cle] = sources.get(cle, 0) + n

    for d in range(jours):
        joue = (d % 7) < p["jours"]
        n = niveau(xp)
        membres = min(places(n), MEMBRES_MAX)
        # caisse du club : recettes continues, plafonnées entre deux récoltes (même hors ligne)
        rec = max(1, p["recoltes"]) if joue else 0
        if joue:
            heures = min(24.0 / rec, R["heures_caisse"])
            cot = membres * R["cotisation_h"] * (1 + R["bonus_membre"] * (membres - 1))
            apres = 3.0 * (2 if p["recoltes"] >= 2 else 1)  # buvette x2 trois heures après un duel
            taille = 1 + R["bonus_membre"] * (membres - 1)
            gagner("fan club", rec * cot * heures + R["buvette_h"][buv] * taille * min(rec * heures + apres, 24.0))
            stock_max = R["stock_echarpes"](atel)
            prod = R["atelier_h"][atel] * 24.0
            vendues = min(prod, stock_max * rec)
            gagner("fan club", vendues * R["prix_echarpe"](membres))
        if joue:
            for lieu, mode, nb in p["duels"]:
                if lieu != "stade":
                    depenses["billets+trajets"] += BILLET[lieu]
                    jetons -= BILLET[lieu]
                for rang in range(nb):
                    gagner("duels", jetons_duel(lieu, mode, rang))
                    xp += DUEL_XP
                    xp_pass += xp_pass_duel(rang)
            # stades : billet + trajet, prime de ferveur, x1,1 sur les duels du jour (forfait)
            st = p["stades_semaine"] / p["jours"]
            cout = st * (R["billet_stade"] + p["trajet"] * R["trajet_facteur"])
            depenses["billets+trajets"] += cout
            jetons -= cout
            gagner("déplacements", st * 14)
            xp += st * 30
            xp_pass += st * (50 * R["xp_pass_ferveur"] + R["xp_pass_stade"] * 0.7)  # 70 % de stades nouveaux
            # boulots
            gagner("petits boulots", boulots_jetons(p["boulots"]))
            xp += p["boulots"] * BOULOT_XP
            # pronostics : 45 % de bons résultats, 10 % de scores exacts, 40 % de premiers buts
            gagner("pronostics", p["pronos"] * (0.45 * 10 + 0.10 * 30 + 0.40 * 10) * 1.15)
            bon, exact = R["xp_pass_prono"]
            xp_pass += p["pronos"] * (0.45 * bon + 0.10 * exact)
            # missions du jour
            mj, mxp = R["mission_jour"]
            gagner("missions", p["missions"] * mj + (R["bonus_jour"][0] if p["missions"] == 3 else 0))
            xp_pass_m = p["missions"] * mxp + (R["bonus_jour"][1] if p["missions"] == 3 else 0)
            if p.get("soiree"):
                gagner("soirs de match", p["soiree"])
                xp_pass += R["xp_pass_soiree"]
        else:
            xp_pass_m = 0
        if d % 7 == 6:  # missions de la semaine (versées même si oubliées)
            ms, msxp = R["mission_semaine"]
            gagner("missions", p["semaine"] * ms + (R["bonus_semaine"][0] if p["semaine"] == 3 else 0))
            xp_pass_m += p["semaine"] * msxp + (R["bonus_semaine"][1] if p["semaine"] == 3 else 0)
        # rattrapage : XP des missions x2 quand on est en retard sur le rythme
        attendu = min(100, -(-100 * (d + 1) // jours))
        if 1 + xp_pass // 1000 < attendu:
            xp_pass_m *= 2
        xp_pass += xp_pass_m
        # Jetons du PASS (piste gratuite, data/pass/saison-2026-27.json) : ~8 000 sur 100 paliers
        pal = min(100, 1 + int(xp_pass) // 1000)
        for q in range(paliers.get("dernier", 1) + 1, pal + 1):
            if q % 4 in (1, 3) and q > 4:
                gagner("PASS", 8000 / 46)
        paliers["dernier"] = pal
        if pal >= 100 and jour_pass_100 is None:
            jour_pass_100 = d + 1
        # le joueur améliore son local dès qu'il garde 150 Jetons de côté
        while True:
            options = []
            if buv < 5:
                options.append(("b", R["cout_buvette"][buv]))
            if atel < 5:
                options.append(("a", R["cout_atelier"][atel]))
            if not options:
                break
            t, c = min(options, key=lambda o: o[1])
            if jetons - c < 150:
                break
            jetons -= c
            depenses["local"] += c
            if t == "b":
                buv += 1
            else:
                atel += 1
        if buv == 5 and atel == 5 and jour_max_local is None:
            jour_max_local = d + 1
        nv = niveau(xp)
        for cible in (6, 10, 13, 25):
            if nv >= cible and cible not in jours_niveau:
                jours_niveau[cible] = d + 1
        if d + 1 in (7, 30, 90):
            paliers[d + 1] = pal
    semaines = jours / 7
    gains = sum(sources.values())
    print(f"\n### {nom}")
    print(f"- Jetons gagnés par jour joué : {gains / (semaines * p['jours']):.0f}"
          f" (dont fan club {sources.get('fan club', 0) / gains * 100:.0f} %, duels {sources.get('duels', 0) / gains * 100:.0f} %,"
          f" boulots {sources.get('petits boulots', 0) / gains * 100:.0f} %)")
    print(f"- Dépenses billets + trajets par jour joué : {depenses['billets+trajets'] / (semaines * p['jours']):.0f}")
    print(f"- Réserve en fin de saison : {jetons:.0f} Jetons ; local au maximum : jour {jour_max_local}")
    print(f"- Niveau du fan club : 6 au jour {jours_niveau.get(6)}, 10 au jour {jours_niveau.get(10)},"
          f" 13 au jour {jours_niveau.get(13)}, 25 au jour {jours_niveau.get(25)} ; niveau final {niveau(xp)}")
    print(f"- PASS : palier {paliers.get(7)} après 1 semaine, {paliers.get(30)} après 1 mois, {paliers.get(90)} après 3 mois ;"
          f" palier 100 au jour {jour_pass_100} ({f'palier {pal} en fin de saison' if jour_pass_100 is None else f'{jour_pass_100 / jours * 100:.0f} % de la saison'})")
    print("- Détail des Jetons gagnés sur la saison : " + ", ".join(f"{k} {v:.0f}" for k, v in sorted(sources.items(), key=lambda kv: -kv[1])))


print("Réglages d'AVANT l'équilibrage" if AVANT else "Réglages actuels")
for nom, p in PROFILS.items():
    simuler(nom, p)

# Jetons par minute de jeu, joueur moyen, au pub, 1er duel du match (billet déduit)
print("\n### Jetons par minute (joueur moyen, pub, billet de 4 déduit)")
for mode, duree in (("duel", 90 + 40), ("arene", 110 + 40), ("poussee", 150 + 40)):
    print(f"- {mode} : {(jetons_duel('pub', mode, 0) - 4) / duree * 60:.1f} / min ({duree} s menus compris)")
print(f"- petit boulot : {BOULOT_JETONS / 90 * 60:.1f} / min plein tarif, {BOULOT_JETONS * R['boulot_apres'] / 90 * 60:.1f} / min ensuite (90 s menus compris)")
