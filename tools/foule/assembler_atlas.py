"""Assemble les images rendues par rendre_supporters.py en un atlas par variante.

    python3 assembler_atlas.py rendu_a rendu_b rendu_c ../../assets/foule

Atlas : une ligne par (geste, calque), une colonne par image.
Calques dans l'ordre : base, peau, maillot, echarpe (case vide si absent).
Écrit aussi foule.json (gestes, lignes, cadence, pied/tête en pixels).
"""
import sys, os, json
from PIL import Image

*sources, dest = sys.argv[1:]
CALQUES = ["base", "peau", "maillot", "echarpe"]
# cadence (images/s) et boucle de chaque geste
CADENCE = {
    "repos": (4, True), "sauter": (12, True), "applaudir": (12, True), "ola": (12, False),
    "echarpe": (7, True), "depit": (6, True), "danser": (10, True),
}
info = json.load(open(os.path.join(sources[0], "gestes.json")))
W, H = info["taille"]
gestes = list(info["images"].items())
ncol = max(n for _, n in gestes)
os.makedirs(dest, exist_ok=True)

haut, bas = H, 0
meta = {"taille": [W, H], "calques": CALQUES, "gestes": {}, "variantes": []}
for k, src in enumerate(sources):
    atlas = Image.new("RGBA", (W * ncol, H * len(gestes) * len(CALQUES)), (0, 0, 0, 0))
    for g_i, (g, n) in enumerate(gestes):
        for i in range(n):
            for c_i, cal in enumerate(CALQUES):
                p = os.path.join(src, f"{g}_{i:02d}_{cal}.png")
                if not os.path.exists(p):
                    continue
                im = Image.open(p).convert("RGBA")
                atlas.paste(im, (i * W, (g_i * len(CALQUES) + c_i) * H))
                if g == "repos" and cal == "base":
                    bb = im.getchannel("A").point(lambda a: 255 if a > 60 else 0).getbbox()
                    haut, bas = min(haut, bb[1]), max(bas, bb[3])
        fps, boucle = CADENCE.get(g, (8, True))
        meta["gestes"][g] = {"ligne": g_i * len(CALQUES), "n": n, "fps": fps, "boucle": boucle}
    nom = f"supporters_{chr(ord('a') + k)}.png"
    atlas.save(os.path.join(dest, nom), optimize=True)
    meta["variantes"].append(nom)
    print(nom, atlas.size)
meta["tete"] = haut   # haut de la tête (debout, au repos), en pixels
meta["pied"] = bas    # sous les baskets
json.dump(meta, open(os.path.join(dest, "foule.json"), "w"), indent=1)
print(meta)
