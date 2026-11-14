"""Génère les données de la carte du monde.

  data/carte/pays.json   : pays (nom français, capitale, continent), compétition -> pays/continent
  data/carte/formes.json : contour de chaque pays (simplifié), pour dessiner et cliquer

Usage :
  python3 tools/prepare_pays.py <dossier data de countryinfo> <competitions.json du dépôt de données> <countries-50m.json de world-atlas>

Sources : paquet Python countryinfo (capitales, continents) et world-atlas
(Natural Earth 1:50m, domaine public).
"""
import json, os, sys

src, cfg_path, atlas_path = sys.argv[1], sys.argv[2], sys.argv[3]
pays = {}
alias = {}


def continent(j):
    r, sr = j.get("region", ""), j.get("subregion", "")
    if r == "Americas":
        return "South America" if "South America" in (sr, j.get("intermediateregion")) else "North America"
    return r if r in ("Europe", "Africa", "Asia", "Oceania") else "World"


for f in sorted(os.listdir(src)):
    try:
        j = json.load(open(os.path.join(src, f), encoding="utf-8"))
    except Exception:
        continue
    ll = j.get("capital_latlng") or j.get("latlng")
    if ll and isinstance(ll[0], list):
        ll = ll[0]
    if not ll or len(ll) < 2 or not all(isinstance(v, (int, float)) for v in ll[:2]):
        continue
    key = j["name"].lower()
    nom = (j.get("translations") or {}).get("fr") or j["name"]
    pays[key] = {"nom": nom, "lat": round(ll[0], 2), "lon": round(ll[1], 2), "continent": continent(j)}
    for a in [f[:-5].lower()] + [a.lower() for a in j.get("altSpellings", [])]:
        alias.setdefault(a, key)

# Nations du football absentes du paquet (ou regroupées) : capitales à la main.
extra = {
    "england": ("Angleterre", 51.51, -0.13), "scotland": ("Écosse", 55.95, -3.19),
    "wales": ("Pays de Galles", 51.48, -3.18), "northern ireland": ("Irlande du Nord", 54.6, -5.93),
    "kosovo": ("Kosovo", 42.66, 21.17), "curacao": ("Curaçao", 12.11, -68.93),
    "chinese taipei": ("Taipei chinois", 25.03, 121.57),
}
for k, (nom, lat, lon) in extra.items():
    pays[k] = {"nom": nom, "lat": lat, "lon": lon, "continent": "North America" if k == "curacao" else ("Asia" if k == "chinese taipei" else "Europe")}
alias.update({"bosnia": "bosnia and herzegovina", "congo dr": "democratic republic of the congo", "macedonia": "republic of macedonia",
              "usa": "united states", "congo": "republic of the congo", "south korea": "south korea", "ivory coast": "ivory coast"})
alias = {a: k for a, k in alias.items() if a != k and k in pays}
for a, k in list(alias.items()):
    if a in pays:
        del alias[a]

regions = {
    "Europe": {"lat": 50.0, "lon": 10.0}, "South America": {"lat": -15.0, "lon": -60.0},
    "North America": {"lat": 25.0, "lon": -95.0}, "Africa": {"lat": 5.0, "lon": 20.0},
    "Asia": {"lat": 30.0, "lon": 95.0}, "Oceania": {"lat": -25.0, "lon": 140.0}, "World": {"lat": 20.0, "lon": 0.0},
}
cfg = json.load(open(cfg_path, encoding="utf-8"))
comps = {}
for c in cfg["competitions"]:
    area = c["area"].replace("-", " ").lower()
    if c["area"] in regions:
        name = c["name"].lower()
        r = c["area"]
        for mot, reg in [("ofc", "Oceania"), ("oceania", "Oceania"), ("afc", "Asia"), ("asia", "Asia"), ("caf", "Africa"),
                         ("africa", "Africa"), ("concacaf", "North America"), ("caribbean", "North America"),
                         ("conmebol", "South America"), ("south america", "South America"), ("uefa", "Europe"), ("euro", "Europe")]:
            if r == "World" and mot in name:
                r = reg
                break
        comps[c["id"]] = {"region": r, "type": c.get("type", "")}
    else:
        key = area if area in pays else alias.get(area)
        if not key:
            print("pays introuvable :", c["area"], file=sys.stderr)
            continue
        comps[c["id"]] = {"pays": key, "type": c.get("type", "")}

# ---- contours des pays (world-atlas, Natural Earth 1:50m)
atlas = json.load(open(atlas_path, encoding="utf-8"))
sc, tr = atlas["transform"]["scale"], atlas["transform"]["translate"]
arcs = []
for a in atlas["arcs"]:
    x = y = 0
    pts = []
    for dx, dy in a:
        x += dx
        y += dy
        pts.append((x * sc[0] + tr[0], y * sc[1] + tr[1]))
    arcs.append(pts)


def anneau(r):
    out = []
    for i in r:
        p = arcs[i] if i >= 0 else arcs[~i][::-1]
        out.extend(p if not out else p[1:])
    return out


def simplifier(pts, tol):
    if len(pts) < 5:
        return pts
    # Douglas-Peucker itératif
    garde = [False] * len(pts)
    garde[0] = garde[-1] = True
    # Anneau fermé : on coupe d'abord au point le plus éloigné du départ.
    loin = max(range(len(pts)), key=lambda i: (pts[i][0] - pts[0][0]) ** 2 + (pts[i][1] - pts[0][1]) ** 2)
    garde[loin] = True
    pile = [(0, loin), (loin, len(pts) - 1)]
    while pile:
        a, b = pile.pop()
        (x1, y1), (x2, y2) = pts[a], pts[b]
        dmax, imax = 0.0, -1
        dx, dy = x2 - x1, y2 - y1
        n = (dx * dx + dy * dy) ** 0.5 or 1e-9
        for i in range(a + 1, b):
            d = abs(dy * pts[i][0] - dx * pts[i][1] + x2 * y1 - y2 * x1) / n
            if d > dmax:
                dmax, imax = d, i
        if dmax > tol and imax > 0:
            garde[imax] = True
            pile += [(a, imax), (imax, b)]
    return [p for p, k in zip(pts, garde) if k]


noms_atlas = {"s. sudan": "south sudan", "solomon is.": "solomon islands", "eq. guinea": "equatorial guinea",
              "dominican rep.": "dominican republic", "faeroe is.": "faroe islands", "dem. rep. congo": "democratic republic of the congo",
              "congo": "republic of the congo", "macao": "macau", "central african rep.": "central african republic",
              "bosnia and herz.": "bosnia and herzegovina", "antigua and barb.": "antigua and barbuda",
              "st. kitts and nevis": "saint kitts and nevis", "st. vin. and gren.": "saint vincent and the grenadines",
              "são tomé and principe": "são tomé and príncipe", "n. cyprus": "cyprus", "somaliland": "somalia",
              "w. sahara": "western sahara", "falkland is.": "falkland islands", "cayman is.": "cayman islands"}
formes = {}
for g in atlas["objects"]["countries"]["geometries"]:
    n = g.get("properties", {}).get("name", "").lower()
    k = noms_atlas.get(n, n)
    k = k if k in pays else alias.get(k, "")
    if not k or g.get("type") not in ("Polygon", "MultiPolygon"):
        continue
    polys = g["arcs"] if g["type"] == "MultiPolygon" else [g["arcs"]]
    for poly in polys:
        r = anneau(poly[0])
        # Anneau qui traverse la ligne de changement de date (Russie, Fidji…) :
        # on le déplie vers l'est pour ne pas tracer une bande à travers le monde.
        if any(abs(r[i][0] - r[i - 1][0]) > 180 for i in range(1, len(r))):
            r = [(x + 360 if x < 0 else x, y) for x, y in r]
        r = simplifier(r, 0.06)
        if len(r) >= 4 and max(p[1] for p in r) > -60:
            formes.setdefault(k, []).append([round(c, 2) for p in r[:-1] for c in p])
# Les nations britanniques partagent la forme du Royaume-Uni.
for k in ("england", "scotland", "wales", "northern ireland"):
    pays[k]["forme"] = "united kingdom"
json.dump({"source": "Natural Earth 1:50m (domaine public), via world-atlas", "pays": formes},
          open("data/carte/formes.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(len(formes), "pays dessinés,", sum(len(v) for v in formes.values()), "polygones")

out = {"source": "countryinfo (capitales) + compléments manuels", "pays": pays, "alias": alias,
       "regions": regions, "competitions": comps}
json.dump(out, open("data/carte/pays.json", "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(len(pays), "pays,", len(comps), "compétitions")
