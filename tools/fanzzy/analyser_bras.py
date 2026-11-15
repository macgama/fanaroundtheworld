#!/usr/bin/env python3
"""Repère les bras levés des FANZZY pour les animer sans découpage.

Pour chaque dossier d'expressions <id>/<evolution>/<skin>/ (export TheBestFan),
lit `neutre`, `cligne` et les poses bras levés (`joie`, `pousse`) et écrit
`bras.json` à côté :

    {"joie": {"cx": 231, "demi": 52, "epaule": 330,
              "g": {"poing": [120, 110], "long": 220},
              "d": {"poing": [345, 105], "long": 225}},
     "pousse": {...}}

Coordonnées en pixels de l'image d'origine (560 x 960). `cx` / `demi` : centre
et demi-largeur de la tête dans la pose ; `epaule` : ligne des épaules ;
`g` / `d` : bras levé à gauche / à droite de l'image (absent si rien n'est
levé de ce côté), avec la position du poing et la longueur au-dessus de
l'épaule. FanzzyAnime plie l'image autour des épaules avec ces repères.

Méthode (silhouette seule, pas d'IA) :
1. les yeux viennent du calque `cligne` (yeux fermés de la pose neutre) ;
2. la tête est retrouvée dans la pose par comparaison d'images avec la pose
   neutre (elle peut monter quand le FANZZY saute) ;
3. on retire une bande verticale de la largeur de la tête, et tout ce qui est
   sous les épaules : ce qui reste et monte au-dessus des yeux, ce sont les bras.

Utilisation :
    python3 tools/fanzzy/analyser_bras.py assets/fanzzy/demo
    python3 tools/fanzzy/analyser_bras.py /chemin/vers/etats --jobs 8
Dépendances : numpy, scipy, pillow.
"""
import argparse
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image
from scipy import ndimage

F = 4  # facteur de réduction pour l'analyse
POSES = ("joie", "pousse")


def _charger(chemin):
    for ext in (".webp", ".png"):
        if os.path.exists(chemin + ext):
            return Image.open(chemin + ext).convert("RGBA")
    return None


def _reduire(im):
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape
    h, w = h // F * F, w // F * F
    return a[:h, :w].reshape(h // F, F, w // F, F, 4).mean(axis=(1, 3))


def _largeur(A, y, x):
    """Largeur de la tranche opaque de la ligne y qui contient x."""
    h, w = A.shape
    y, x = int(np.clip(y, 0, h - 1)), int(np.clip(x, 0, w - 1))
    if not A[y, x]:
        return 0
    l = r = x
    while l > 0 and A[y, l - 1]:
        l -= 1
    while r < w - 1 and A[y, r + 1]:
        r += 1
    return r - l + 1


def _yeux(cligne, neutre_a):
    """Centre et écart des yeux (en pixels réduits)."""
    if cligne is not None and cligne.getbbox():
        b = cligne.getbbox()
        return (b[0] + b[2]) / 2 / F, (b[1] + b[3]) / 2 / F, max((b[2] - b[0]) / F, 4.0)
    ys, xs = np.nonzero(neutre_a > 0.5)
    haut = ys.min()
    hh = ys.max() - haut
    return xs[ys < haut + hh * 0.1].mean(), haut + hh * 0.1, hh * 0.06


def _suivre_tete(n, p, ex, ey, ecart):
    """Décalage (dx, dy) de la tête entre la pose neutre et la pose p."""
    h, w, _ = n.shape
    r = int(max(ecart * 1.1, 6))
    x0, x1, y0, y1 = int(ex - r), int(ex + r), int(ey - r), int(ey + r * 0.8)
    x0, y0 = max(x0, 0), max(y0, 0)
    modele = n[y0:y1, x0:x1]
    m = modele[:, :, 3] > 128
    if m.sum() < 10:
        return 0, 0
    meilleur = (1e18, 0, 0)
    for dy in range(-int(h * 0.2), int(h * 0.08) + 1):
        for dx in range(-int(w * 0.12), int(w * 0.12) + 1):
            if y0 + dy < 0 or y1 + dy > h or x0 + dx < 0 or x1 + dx > w:
                continue
            q = p[y0 + dy:y1 + dy, x0 + dx:x1 + dx]
            d = ((q - modele) ** 2).sum(axis=2)[m].mean() + 30 * (dx * dx + dy * dy)
            if d < meilleur[0]:
                meilleur = (d, dx, dy)
    return meilleur[1], meilleur[2]


def analyser_dossier(dossier):
    neutre = _charger(os.path.join(dossier, "neutre"))
    if neutre is None:
        return None
    n = _reduire(neutre)
    An = n[:, :, 3] > 128
    ex0, ey0, ecart = _yeux(_charger(os.path.join(dossier, "cligne")), n[:, :, 3] / 255)
    tete = _largeur(An, ey0, ex0)
    demi = min(max(tete * 0.5, ecart * 0.6), ecart * 1.1) + 1
    # épaules : là où la silhouette neutre s'élargit nettement sous la tête
    epaule0 = None
    for y in range(int(ey0) + 1, An.shape[0]):
        if _largeur(An, y, ex0) > 1.7 * max(tete, ecart * 1.2):
            epaule0 = y
            break
    if epaule0 is None:
        epaule0 = ey0 + ecart * 1.2
    epaule0 = min(epaule0, ey0 + 1.9 * demi)

    res = {}
    for pose in POSES:
        im = _charger(os.path.join(dossier, pose))
        if im is None:
            continue
        p = _reduire(im)
        dx, dy = _suivre_tete(n, p, ex0, ey0, ecart)
        ex, ey, epaule = ex0 + dx, ey0 + dy, int(epaule0 + dy)
        A = p[:, :, 3] > 128
        h, w = A.shape
        zone = A.copy()
        zone[epaule + 1:, :] = False
        bx0, bx1 = int(ex - demi), int(ex + demi) + 1
        zone[:, max(bx0, 0):bx1] = False
        yy, xx = np.mgrid[0:h, 0:w]
        zone &= ~(((xx - ex) / (demi * 1.2)) ** 2 + ((yy - (ey - 0.35 * demi)) / (demi * 1.7)) ** 2 < 1)
        lab, nb = ndimage.label(zone)
        entree = {"cx": round(float(ex * F), 1), "demi": round(float(demi * F), 1), "epaule": round(float(epaule * F + F / 2), 1)}
        for cote in ("g", "d"):
            meilleur = None
            for k in range(1, nb + 1):
                m = lab == k
                ys, xs = np.nonzero(m)
                # un bras part des épaules et monte au-dessus des yeux
                if ys.max() < ey + 0.4 * ecart or ys.min() > ey:
                    continue
                if (cote == "g") != (xs.mean() < ex):
                    continue
                if meilleur is None or m.sum() > meilleur[1]:
                    meilleur = (k, m.sum())
            if meilleur is None or meilleur[1] < ecart * ecart * 0.5 or meilleur[1] > 0.2 * A.sum():
                continue
            ys, xs = np.nonzero(lab == meilleur[0])
            haut = ys.min()
            poing = (xs[ys <= haut + 2].mean(), haut + 2)
            entree[cote] = {
                "poing": [round(float(poing[0] * F), 1), round(float(poing[1] * F), 1)],
                "long": round(float((epaule - haut) * F), 1),
            }
        if "g" in entree or "d" in entree:
            res[pose] = entree
    return res


def _traiter(dossier):
    try:
        r = analyser_dossier(dossier)
    except Exception as e:  # une image abîmée ne doit pas arrêter le lot
        return dossier, None, str(e)
    if r is None:
        return dossier, None, "pas de neutre"
    with open(os.path.join(dossier, "bras.json"), "w") as f:
        json.dump(r, f, separators=(",", ":"))
    return dossier, r, None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("racine", help="dossier contenant <id>/<evolution>/<skin>/")
    ap.add_argument("--jobs", type=int, default=os.cpu_count())
    args = ap.parse_args()
    dossiers = sorted({r for r, _, fichiers in os.walk(args.racine)
                       if any(f.startswith("neutre.") for f in fichiers)})
    stats = {"dossiers": 0, "joie_2": 0, "joie_1": 0, "pousse": 0, "erreurs": 0}
    with ProcessPoolExecutor(args.jobs) as ex:
        for i, (d, r, err) in enumerate(ex.map(_traiter, dossiers, chunksize=4)):
            stats["dossiers"] += 1
            if err:
                stats["erreurs"] += 1
                print(f"{d} : {err}", file=sys.stderr)
                continue
            j = r.get("joie", {})
            nb = ("g" in j) + ("d" in j)
            stats["joie_2"] += nb == 2
            stats["joie_1"] += nb == 1
            stats["pousse"] += "pousse" in r
            if i % 200 == 0:
                print(f"{i}/{len(dossiers)}", file=sys.stderr)
    print(json.dumps(stats))


if __name__ == "__main__":
    main()
