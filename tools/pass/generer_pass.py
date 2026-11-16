#!/usr/bin/env python3
"""Prépare le PASS d'une saison : paliers, recrues FANZZY et images des skins.

    python3 tools/pass/generer_pass.py <dossier fanzzy exporté de TheBestFan>

Le dossier source contient `catalogue-fanzzy.json`, `vignettes/` (<id>.webp et
<id>-buste.webp) et `etats/<id>/<e1|e2|e3>/<thème>/` (neutre.webp, portrait.webp).

Écrit :
- data/pass/saison-2026-27.json         les 100 paliers (gratuit + Premium)
- assets/fanzzy/fanzzy.json             + les recrues du PASS (champ « pass » = palier)
- assets/fanzzy/sprites/<skin>.webp     + <skin>-buste.webp pour chaque nouveau skin

Les skins des chapitres 1 à 3 viennent des thèmes déjà dessinés (Halloween,
préhistorique, apocalyptique). Le thème doré du chapitre 4 n'existe pas encore :
il est fabriqué ici en teintant l'image de base (à remplacer par de vrais
dessins le jour où ils existent).
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageOps

RACINE = Path(__file__).resolve().parents[2]
SPRITES = RACINE / "assets/fanzzy/sprites"
CATALOGUE = RACINE / "assets/fanzzy/fanzzy.json"
SORTIE = RACINE / "data/pass/saison-2026-27.json"

HAUTEUR = 440
BUSTE = 160

# Recrues de la piste gratuite : palier -> id dans le catalogue de TheBestFan.
# Palier 100 : en attendant les dessins du légendaire « Carnet plein » (CP1),
# un légendaire déjà dessiné tient sa place.
RECRUES = {1: "VP8", 25: "GD16", 37: "VP6", 50: "GD11", 63: "VP20", 75: "VP12", 87: "VP31", 100: "GD15"}

CHAPITRES = [
    {"theme": "halloween", "nom": "Frissons", "theme_nom": "Halloween"},
    {"theme": "prehistorique", "nom": "Âge de glace", "theme_nom": "Préhistorique"},
    {"theme": "apocalyptique", "nom": "Fin du monde", "theme_nom": "Apocalyptique"},
    {"theme": "dore", "nom": "Les finales", "theme_nom": "Doré"},
]

# Objets d'apparence (pas encore visibles ailleurs que dans le PASS et la collection).
OBJETS = {
    "halloween": {
        "gratuit": {"accessoire": "Écharpe Feu follet", "emote": "Émote Citrouille qui rit", "decor": "Lampions orange"},
        "echarpe": ["Écharpe Citrouille", "Écharpe Toile d'araignée", "Écharpe Chauve-souris"],
        "drapeau": ["Drapeau Fantôme", "Drapeau Lune rousse"],
        "tifo": ["Tifo Château hanté", "Tifo Chaudron"],
        "decor": ["Guirlande de citrouilles", "Bougies du local", "Brouillard de virage", "Toiles au plafond"],
        "emote": ["Émote Bouh !", "Émote Danse du squelette", "Émote Balai volant", "Émote Frisson"],
        "son": ["Orgue de minuit", "Cloche du beffroi"],
        "couverture": ["Couverture de carnet Grimoire"],
        "titre": ["Titre « Revenant du virage »"],
    },
    "prehistorique": {
        "gratuit": {"accessoire": "Drapeau Empreinte de main", "emote": "Émote Dino", "decor": "Peaux de bête au mur"},
        "echarpe": ["Écharpe en peau de bête", "Écharpe Silex", "Écharpe Mammouth"],
        "drapeau": ["Drapeau Peinture rupestre", "Drapeau Feu de camp"],
        "tifo": ["Tifo Fresque de la grotte", "Tifo Mammouth géant"],
        "decor": ["Feu de camp du local", "Grotte du fan club", "Os de dinosaure", "Stalactites"],
        "emote": ["Émote Massue", "Émote Danse du feu", "Émote Ouga ouga", "Émote Silex"],
        "son": ["Tambour de pierre", "Corne de mammouth"],
        "couverture": ["Couverture de carnet Pierre gravée"],
        "titre": ["Titre « Ancêtre des tribunes »"],
    },
    "apocalyptique": {
        "gratuit": {"accessoire": "Écharpe Fil de fer", "emote": "Émote Radio grésille", "decor": "Barils lumineux"},
        "echarpe": ["Écharpe Rouille", "Écharpe Néon", "Écharpe Boulons"],
        "drapeau": ["Drapeau Radar", "Drapeau Dernier refuge"],
        "tifo": ["Tifo Ville en ruines", "Tifo Soleil rouge"],
        "decor": ["Néons du local", "Tôles et boulons", "Bunker du fan club", "Antenne de fortune"],
        "emote": ["Émote Survivant", "Émote Bidon tambour", "Émote Masque à gaz", "Émote Signal"],
        "son": ["Sirène lointaine", "Bidon de ferraille"],
        "couverture": ["Couverture de carnet Blindée"],
        "titre": ["Titre « Dernier debout »"],
    },
    "dore": {
        "gratuit": {"accessoire": "Drapeau Étoile dorée", "emote": "Émote Médaille", "decor": "Ruban de finale"},
        "echarpe": ["Écharpe Dorée", "Écharpe Coupe aux grandes oreilles", "Écharpe Étoile"],
        "drapeau": ["Drapeau Doré", "Drapeau Finale"],
        "tifo": ["Tifo Trophée géant", "Tifo Pluie d'or"],
        "decor": ["Vitrine à trophées", "Confettis dorés", "Tapis rouge", "Lustre du local"],
        "emote": ["Émote Soulever la coupe", "Émote Tour d'honneur", "Émote Champion", "Émote Bisou au trophée"],
        "son": ["Fanfare de finale", "Feu d'artifice"],
        "couverture": ["Couverture de carnet Dorée"],
        "titre": ["Titre « Finaliste »"],
    },
}


def _ids_base():
    cat = json.loads(CATALOGUE.read_text())
    return cat, [z for z in cat["fanzzy"] if "pass" not in z]


def _redim(im: Image.Image, hauteur: int) -> Image.Image:
    l = max(1, round(im.width * hauteur / im.height))
    return im.resize((l, hauteur), Image.LANCZOS)


def _enregistrer(im: Image.Image, nom: str) -> None:
    im.save(SPRITES / f"{nom}.webp", "WEBP", quality=88, method=6)


def _skin_theme(src: Path, fz: str, evo: str, theme: str, skin: str) -> bool:
    d = src / "etats" / fz / evo / theme
    if not (d / "neutre.webp").exists() or not (d / "portrait.webp").exists():
        return False
    corps = Image.open(d / "neutre.webp").convert("RGBA")
    corps = corps.crop(corps.getchannel("A").getbbox())
    _enregistrer(_redim(corps, HAUTEUR), skin)
    _enregistrer(Image.open(d / "portrait.webp").convert("RGBA").resize((BUSTE, BUSTE), Image.LANCZOS), skin + "-buste")
    return True


def _dorer(im: Image.Image) -> Image.Image:
    """Version « or massif » : niveaux de gris passés dans un dégradé doré."""
    a = im.getchannel("A")
    gris = ImageOps.autocontrast(ImageOps.grayscale(im.convert("RGB")), cutoff=1)
    dore = ImageOps.colorize(gris, black="#4a2c00", mid="#e0a526", white="#fff6c8", midpoint=110)
    dore = Image.blend(dore, im.convert("RGB"), 0.18).convert("RGBA")
    dore.putalpha(a)
    return dore


def _skin_dore(skin_base: str, skin: str) -> None:
    for suffixe in ("", "-buste"):
        im = Image.open(SPRITES / f"{skin_base}{suffixe}.webp").convert("RGBA")
        _enregistrer(_dorer(im), skin + suffixe)


def _recrue(src: Path, cat_src: dict, fid: str, palier: int) -> dict:
    by = {z["id"]: z for z in cat_src["fanzzy"]}
    z = by[fid]
    skins = []
    cur = fid
    while cur:
        skins.append({"id": cur, "nom": by[cur]["nom"]})
        for suffixe in ("", "-buste"):
            im = Image.open(src / "vignettes" / f"{cur}{suffixe}.webp").convert("RGBA")
            _enregistrer(_redim(im, HAUTEUR) if suffixe == "" else im.resize((BUSTE, BUSTE), Image.LANCZOS), cur + suffixe)
        cur = by[cur].get("evo")
    return {
        "id": fid, "nom": z["nom"], "famille": z["type"], "serie": z["set"], "rarete": z["rar"],
        "histoire": z.get("histoire", ""), "mods": z.get("mods", {}), "cri": z.get("cri", {}),
        "skins": skins, "pass": palier,
    }


def main(src: Path) -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    cat_src = json.loads((src / "catalogue-fanzzy.json").read_text())
    cat, base = _ids_base()

    # 1) Recrues du PASS dans le catalogue du jeu.
    recrues = {p: _recrue(src, cat_src, fid, p) for p, fid in RECRUES.items()}
    cat["fanzzy"] = base + [recrues[p] for p in sorted(recrues)]
    for s in cat_src["series"]:
        if s["id"] in {r["serie"] for r in recrues.values()} and s["id"] not in cat["series"]:
            cat["series"][s["id"]] = {"nom": s["nom"].title().replace("Vip", "VIP"), "ligne": s["ligne"], "couleur": s["c1"]}
    CATALOGUE.write_text(json.dumps(cat, ensure_ascii=False, indent="\t") + "\n")

    # 2) Skins par chapitre : toutes les évolutions des FANZZY de départ, dans un ordre mélangé.
    candidats = []  # (fanzzy, évolution, id du skin de base, nom)
    for rang in range(3):
        for z in base:
            if rang < len(z["skins"]):
                candidats.append((z["id"], "e%d" % (rang + 1), z["skins"][rang]["id"], z["skins"][rang]["nom"]))

    def skins_du_chapitre(ch: dict, n: int, decalage: int) -> list:
        res = []
        i = decalage
        essais = 0
        while len(res) < n and essais < len(candidats) * 2:
            fz, evo, sid, nom = candidats[i % len(candidats)]
            i += 7  # saute d'un FANZZY à l'autre (7 et 54 sont premiers entre eux)
            essais += 1
            skin = f"{sid}_{ch['theme']}"
            if any(r["skin"] == skin for r in res):
                continue
            if ch["theme"] == "dore":
                _skin_dore(sid, skin)
            elif not _skin_theme(src, fz, evo, ch["theme"], skin):
                continue
            res.append({"type": "skin", "fanzzy": fz, "skin": skin, "nom": f"{nom} · {ch['theme_nom']}"})
        assert len(res) == n, f"pas assez de skins {ch['theme']}"
        return res

    paliers = []
    for c, ch in enumerate(CHAPITRES):
        debut = 25 * c + 1
        skins = skins_du_chapitre(ch, 12, c * 5)
        gratuits_skins, premium_skins = skins[:2], skins[2:]
        ob = OBJETS[ch["theme"]]

        def objet(type_, k):
            liste = ob[type_]
            return {"type": type_, "nom": liste[k % len(liste)]}

        # Piste gratuite : paliers impairs + le dernier du chapitre.
        libres = [p for p in range(debut, debut + 25) if p % 2 == 1 or p % 25 == 0]
        recrues_ch = [p for p in libres if p in RECRUES]
        autres = [p for p in libres if p not in RECRUES]
        jetons = [200, 250, 300, 350, 400, 500]
        file_g = [
            {"type": "jetons", "n": jetons[0]}, gratuits_skins[0], {"type": "jetons", "n": jetons[1]},
            {"type": "echarpe" if c % 2 == 0 else "drapeau", "nom": ob["gratuit"]["accessoire"]}, {"type": "jetons", "n": jetons[2]}, {"type": "emote", "nom": ob["gratuit"]["emote"]},
            {"type": "jetons", "n": jetons[3]}, gratuits_skins[1], {"type": "jetons", "n": jetons[4]},
            {"type": "decor", "nom": ob["gratuit"]["decor"]}, {"type": "jetons", "n": jetons[5]},
        ]
        file_g = file_g[: len(autres)]
        gratuit = {}
        for p in recrues_ch:
            r = recrues[p]
            gratuit[p] = {"type": "recrue", "fanzzy": r["id"], "nom": r["nom"], "rarete": r["rarete"]}
        for p, rec in zip(autres, file_g):
            gratuit[p] = rec

        # Piste Premium : une récompense à chaque palier.
        fin = debut + 24
        bundle = {"type": "tribune", "nom": f"Tribune complète {ch['theme_nom']}", "skins": premium_skins[:5]}
        singles = premium_skins[5:]
        file_p = [
            objet("echarpe", 0), singles[0], objet("emote", 0), objet("drapeau", 0), singles[1], objet("decor", 0),
            objet("son", 0), singles[2], objet("tifo", 0), objet("emote", 1), singles[3], objet("echarpe", 1),
            objet("decor", 1), objet("couverture", 0), singles[4], objet("drapeau", 1), objet("emote", 2),
            objet("tifo", 1), objet("son", 1), objet("decor", 2), objet("titre", 0), objet("echarpe", 2),
            objet("emote", 3), objet("decor", 3),
        ]
        premium = {}
        p = debut
        if c == 0:
            r = recrues[1]
            dore = r["skins"][0]["id"] + "_dore"
            _skin_dore(r["skins"][0]["id"], dore)
            premium[p] = {"type": "skin", "fanzzy": r["id"], "skin": dore, "nom": f"{r['nom']} · Doré"}
            p += 1
        for rec in file_p:
            if p >= fin:
                break
            premium[p] = rec
            p += 1
        premium[fin] = bundle
        if c == 3:
            r = recrues[100]
            dore = r["skins"][0]["id"] + "_dore"
            _skin_dore(r["skins"][0]["id"], dore)
            premium[100] = {"type": "tribune", "nom": f"{r['nom']} doré + titre « Tour du monde 2026-27 »",
                            "skins": [{"type": "skin", "fanzzy": r["id"], "skin": dore, "nom": f"{r['nom']} · Doré"}],
                            "titre": "Tour du monde 2026-27"}
            # Les skins de la tribune dorée passent en simples récompenses plus tôt dans le chapitre.
            premium[99] = bundle
        for q in range(debut, fin + 1):
            paliers.append({"palier": q, "gratuit": gratuit.get(q), "premium": premium.get(q)})

    data = {
        "saison": "2026-27",
        "numero": 1,
        "titre": "Tour du monde",
        "debut": "2026-08-01",
        "fin": "2027-05-30",
        "xp_par_palier": 1000,
        "prix": "7,99 €",
        "chapitres": [{"nom": ch["nom"], "theme": ch["theme"], "theme_nom": ch["theme_nom"], "premier": 25 * i + 1} for i, ch in enumerate(CHAPITRES)],
        "paliers": paliers,
    }
    SORTIE.parent.mkdir(parents=True, exist_ok=True)
    SORTIE.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
    nb_g = sum(1 for p in paliers if p["gratuit"])
    nb_p = sum(1 for p in paliers if p["premium"])
    print(f"{len(paliers)} paliers · {nb_g} récompenses gratuites · {nb_p} Premium · {len(recrues)} recrues")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "/mnt/project-files/fanzzy"))
