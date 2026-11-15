"""Prépare un skin FANZZY pour la 3D : masque, découpage en parties, épaisseur,
textures avant/arrière. Sortie : <sortie>/<ID>.npz + <ID>-avant.png + <ID>-dos.png

Usage : python preparer.py pose.task sortie/ image1.png image2.png ...
(python avec mediapipe, scipy, pillow ; voir reperes.py)
"""
import sys, os, json
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi
from reperes import detecteur, reperes

TETE, TORSE, JAMBE_G, JAMBE_D, BRAS_G, BRAS_D = 1, 2, 3, 4, 5, 6


def dist_segment(px, py, a, b):
    ax, ay = a; bx, by = b
    vx, vy = bx - ax, by - ay
    t = np.clip(((px - ax) * vx + (py - ay) * vy) / max(vx * vx + vy * vy, 1e-6), 0, 1)
    return np.hypot(px - ax - t * vx, py - ay - t * vy), t


def nettoyer_masque(rgba):
    a = rgba[..., 3]
    m = a > 200
    # contour « autocollant » des skins B/C : halo semi-transparent + liseré opaque
    semi = ((a > 8) & (a < 200)).sum()
    perimetre = (m ^ ndi.binary_erosion(m)).sum()
    halo = semi / max(perimetre, 1)
    if halo > 2.0:
        m = ndi.binary_erosion(m, iterations=int(round(1.6 * halo)))
    m = ndi.binary_opening(m, iterations=2)
    lab, n = ndi.label(m)
    if n > 1:  # garde les gros morceaux (accessoires détachés compris)
        tailles = ndi.sum(m, lab, range(1, n + 1))
        garder = [i + 1 for i, t in enumerate(tailles) if t > 0.02 * tailles.max()]
        m = np.isin(lab, garder)
    return ndi.binary_fill_holes(m), halo


def decouper(m, r):
    """Étiquette chaque pixel opaque : tête, torse, jambes, bras."""
    h, w = m.shape
    py, px = np.mgrid[0:h, 0:w].astype(np.float32)
    P = lambda n: np.array(r[n][:2])
    eg, ed = P("epaule.L"), P("epaule.R")  # L = gauche du personnage = droite de l'image
    hg, hd = P("hanche.L"), P("hanche.R")
    mil_ep, mil_h = (eg + ed) / 2, (hg + hd) / 2
    largeur_ep = np.linalg.norm(eg - ed)
    nez = P("nez")
    cou_y = nez[1] + 0.55 * (mil_ep[1] - nez[1])
    demi_tete = 1.0 * abs(P("oreille.L")[0] - P("oreille.R")[0])
    cout = {}
    # torse : segment cou → bassin, rayon = demi-largeur d'épaules
    d, _ = dist_segment(px, py, (mil_ep[0], cou_y), mil_h)
    cout[TORSE] = d / (0.55 * largeur_ep)
    for cote, lab in (("L", BRAS_G), ("R", BRAS_D)):
        e, c, p = P("epaule." + cote), P("coude." + cote), P("poignet." + cote)
        main = p + (p - c) * 0.45
        lb = np.linalg.norm(c - e)
        rb = 0.22 * lb
        d = np.minimum(dist_segment(px, py, e + (c - e) * 0.15, c)[0], dist_segment(px, py, c, main)[0])
        cout[lab] = d / rb
    for cote, lab in (("L", JAMBE_G), ("R", JAMBE_D)):
        hh, g, ch, pi = P("hanche." + cote), P("genou." + cote), P("cheville." + cote), P("pied." + cote)
        lj = np.linalg.norm(g - hh)
        d = np.minimum.reduce([dist_segment(px, py, hh, g)[0], dist_segment(px, py, g, ch)[0],
                               dist_segment(px, py, ch, pi)[0]])
        c = d / (0.30 * lj)
        c[py < hh[1]] += 3  # au-dessus des hanches : torse
        cout[lab] = c
    cles = list(cout)
    pile = np.stack([cout[k] for k in cles])
    lab = np.array(cles)[pile.argmin(0)]
    zone_tete = (py < cou_y) & (np.abs(px - nez[0]) < demi_tete)
    lab[zone_tete] = TETE
    lab[(py < cou_y) & ~zone_tete & np.isin(lab, [JAMBE_G, JAMBE_D])] = TORSE
    lab[~m] = 0
    # nettoyage : chaque partie garde son plus gros morceau, le reste va au voisin
    for k in cles + [TETE]:
        l, n = ndi.label(lab == k)
        if n > 1:
            t = ndi.sum(lab == k, l, range(1, n + 1))
            for i in range(n):
                if i + 1 != t.argmax() + 1:
                    lab[l == i + 1] = 0
    vide = m & (lab == 0)
    if vide.any():
        _, (iy, ix) = ndi.distance_transform_edt(lab == 0, return_indices=True)
        lab[vide] = lab[iy[vide], ix[vide]]
    infos = {"cou_y": float(cou_y), "largeur_epaules": float(largeur_ep)}
    return lab, infos


def epaisseur(m, silhouette, facteur=1.0, lissage=3.0):
    """Gonfle une partie : section ronde côté extérieur (distance au vide),
    pleine épaisseur là où la partie touche une autre partie (pas de fente)."""
    d = ndi.distance_transform_edt(silhouette)
    R = ndi.maximum_filter(ndi.distance_transform_edt(m), size=31)
    R = ndi.gaussian_filter(R, 6)
    d = np.minimum(d, R)
    z = np.sqrt(np.clip(2 * R * d - d * d, 0, None)) * facteur
    z = ndi.gaussian_filter(z * m, lissage) / np.maximum(ndi.gaussian_filter(m * 1.0, lissage), 0.3)
    return (z * m).astype(np.float32)


def etendre_couleurs(rgb, m, n=12):
    """Prolonge les couleurs hors de la silhouette (évite les bords clairs)."""
    _, (iy, ix) = ndi.distance_transform_edt(~m, return_indices=True)
    out = rgb[iy, ix]
    return out


def texture_dos(rgb, m, lab):
    dos = rgb.astype(np.float32).copy()
    flou = np.stack([ndi.median_filter(rgb[..., i], size=9) for i in range(3)], -1).astype(np.float32)
    flou = np.stack([ndi.gaussian_filter(flou[..., i], 3) for i in range(3)], -1)
    dos = flou
    # arrière de la tête : couleur du sommet (cheveux, chapeau, crâne) tirée vers le bas
    tete = lab == TETE
    ys, xs = np.nonzero(tete)
    if len(ys):
        for x in range(xs.min(), xs.max() + 1):
            col = np.nonzero(tete[:, x])[0]
            if len(col) < 3:
                continue
            haut = col[0]
            ech = rgb[haut + 2: haut + 12, x].reshape(-1, 3)
            if len(ech) == 0:
                continue
            c = np.median(ech, 0)
            dos[col, x] = c
        for i in range(3):
            canal = ndi.gaussian_filter(dos[..., i] * tete, 9) / np.maximum(ndi.gaussian_filter(tete * 1.0, 9), 1e-3)
            dos[..., i] = np.where(tete, canal, dos[..., i])
    # légèrement plus sombre : le dos est dans l'ombre des projecteurs
    return np.clip(dos * 0.9, 0, 255).astype(np.uint8)


def preparer(det, chemin, sortie):
    ident = os.path.splitext(os.path.basename(chemin))[0]
    im = Image.open(chemin).convert("RGBA")
    rgba = np.asarray(im)
    m, halo = nettoyer_masque(rgba)
    r = reperes(det, chemin)
    if r is None:
        print(ident, ": aucun corps détecté")
        return None
    lab, infos = decouper(m, r)
    # chaque partie déborde un peu sur ses voisines : pas de fente entre bras et buste
    deborde = lambda x: ndi.binary_dilation(x, iterations=7) & m
    corps = deborde(np.isin(lab, [TETE, TORSE, JAMBE_G, JAMBE_D]))
    m_bg, m_bd = deborde(lab == BRAS_G), deborde(lab == BRAS_D)
    z_corps = epaisseur(corps, m, 0.9)
    z_bg = epaisseur(m_bg, m, 0.95, 1.5)
    z_bd = epaisseur(m_bd, m, 0.95, 1.5)
    rgb = etendre_couleurs(rgba[..., :3], m)
    Image.fromarray(rgb).save(os.path.join(sortie, ident + "-avant.png"))
    Image.fromarray(texture_dos(rgb, m, lab)).save(os.path.join(sortie, ident + "-dos.png"))
    np.savez_compressed(os.path.join(sortie, ident + ".npz"), lab=lab.astype(np.uint8), m_corps=corps, m_bras_g=m_bg, m_bras_d=m_bd,
                        z_corps=z_corps, z_bras_g=z_bg, z_bras_d=z_bd)
    infos.update({"id": ident, "taille": list(m.shape), "halo": round(float(halo), 2),
                  "reperes": {k: v[:2] for k, v in r.items()}})
    with open(os.path.join(sortie, ident + ".json"), "w", encoding="utf8") as f:
        json.dump(infos, f, indent=1)
    # contrôle visuel du découpage
    pal = np.array([[255, 255, 255], [240, 200, 60], [60, 130, 230], [40, 170, 90], [30, 110, 60],
                    [220, 70, 60], [150, 40, 30]], np.uint8)
    ctrl = (0.5 * rgba[..., :3] + 0.5 * pal[lab]).astype(np.uint8)
    Image.fromarray(ctrl).save(os.path.join(sortie, ident + "-decoupe.png"))
    print(ident, "ok, halo", round(float(halo), 2))
    return infos


if __name__ == "__main__":
    det = detecteur(sys.argv[1])
    os.makedirs(sys.argv[2], exist_ok=True)
    for c in sys.argv[3:]:
        preparer(det, c, sys.argv[2])
