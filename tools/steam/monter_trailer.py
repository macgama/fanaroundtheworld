#!/usr/bin/env python3
"""Monte le trailer Steam à partir des plans filmés par tools/steam/trailer.gd.

    python3 tools/steam/monter_trailer.py dossier_plans dossier_sortie [fr|en]...

Il faut ffmpeg et Pillow, et les polices du jeu en .ttf (converties depuis
assets/fonts/*.woff2 avec fontTools) dans dossier_plans/polices/.
Chaque plan <nom>.avi a son journal <nom>.log qui donne « DEBUT_PLAN <image> ».
Son : le son du jeu enregistré avec les plans + « The Final Turn » (Gaël).
Sortie : trailer-<langue>.mp4 en 1920×1080, 30 i/s, H.264 + AAC (format Steam).
"""
import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MUSIQUE = os.path.join(RACINE, "assets/audio/musique/the_final_turn_boucle.ogg")
FPS = 30
W, H = 1920, 1080
FONDU = 0.25  # fondu blanc entre deux plans

NUIT = (20, 17, 46)
JAUNE = (255, 210, 63)
ROSE = (255, 61, 127)
BLANC = (255, 255, 255)

# (plan, début dans le plan en s, durée en s, titre, sous-titre) ; textes par langue
MONTAGE = [
    ("titre", 0.0, 3.4, "accroche"),
    ("carte", 0.3, 9.0, "carte"),
    ("voyage", 0.4, 4.6, "voyage"),
    ("tribune", 0.5, 2.4, "tribune"),
    ("duel", 6.0, 8.0, "duel"),
    ("duel", 27.5, 5.5, None),
    ("arene", 12.0, 7.0, "arene"),
    ("poussee", 30.0, 6.5, "poussee"),
    ("buvette", 5.0, 5.0, "buvette"),
    ("club", 0.5, 2.2, "club"),
    ("carnet", 0.5, 1.8, None),
    ("album", 0.5, 2.2, None),
    ("titre", 1.4, 3.6, "fin"),
]

TEXTES = {
    "fr": {
        "accroche": ("LE JEU DES SUPPORTERS", "Ton fan club suit les vrais matchs du monde entier"),
        "carte": ("LES VRAIS MATCHS DE LA SEMAINE", "Calendrier et scores en direct, partout dans le monde"),
        "voyage": ("VOYAGE JUSQU'AU STADE", "et tamponne ton carnet de voyage"),
        "tribune": ("CHOISIS TA TRIBUNE", "Chant, Tifo, Ola : trois FANZZY à toi"),
        "duel": ("GAGNE LE DUEL D'AMBIANCE", "Chante en rythme, déploie le tifo, lance l'ola"),
        "arene": ("L'ARÈNE : 3 CONTRE 3", "Ballons de confettis et mégaphone à tenir"),
        "poussee": ("LA POUSSÉE", "Pose tes supporters et prends la tribune d'en face"),
        "buvette": ("PETITS BOULOTS À LA BUVETTE", "Gagne des Jetons pour tes voyages"),
        "club": ("MONTE TON FAN CLUB", "Recrute, collectionne les stades et les FANZZY"),
        "fin": ("BIENTÔT SUR STEAM", "Ajoute-le à ta liste de souhaits !"),
        "avertissement": "Images du jeu en développement · noms de clubs fictifs",
    },
    "en": {
        "accroche": ("THE FOOTBALL FAN GAME", "Your fan club follows real matches worldwide"),
        "carte": ("THIS WEEK'S REAL MATCHES", "Live fixtures and scores from around the world"),
        "voyage": ("TRAVEL TO THE STADIUM", "and stamp your travel book"),
        "tribune": ("PICK YOUR CREW", "Chant, Tifo, Wave: three FANZZY of your own"),
        "duel": ("WIN THE ATMOSPHERE DUEL", "Chant on the beat, raise the tifo, start the wave"),
        "arene": ("THE ARENA: 3 VS 3", "Confetti balloons and a megaphone to hold"),
        "poussee": ("THE PUSH", "Deploy your fans and take the opposing stand"),
        "buvette": ("SIDE JOBS AT THE SNACK BAR", "Earn Tokens for your trips"),
        "club": ("BUILD YOUR FAN CLUB", "Recruit, collect stadiums and FANZZY"),
        "fin": ("COMING SOON ON STEAM", "Add it to your wishlist!"),
        "avertissement": "Work-in-progress footage · fictional club names",
    },
}


def debut_plan(dossier, plan):
    log = open(os.path.join(dossier, plan + ".log"), encoding="utf-8", errors="ignore").read()
    m = re.search(r"DEBUT_PLAN (\d+)", log)
    return int(m.group(1)) / FPS if m else 0.0


def police(dossier, nom, taille):
    return ImageFont.truetype(os.path.join(dossier, "polices", nom + ".ttf"), taille)


def lignes(d, texte, f, largeur):
    out, ligne = [], ""
    for mot in texte.split():
        essai = (ligne + " " + mot).strip()
        if ligne and d.textbbox((0, 0), essai, font=f)[2] > largeur:
            out.append(ligne)
            ligne = mot
        else:
            ligne = essai
    return out + [ligne]


def panneau_titre(dossier, titre, sous_titre, chemin):
    """Accroche et carte de fin : un panneau posé sur le menu de l'écran titre."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = 1222, 138, 1838, 700
    d.rounded_rectangle((x0 + 12, y0 + 16, x1 + 12, y1 + 16), 38, fill=(0, 0, 0, 120))
    d.rounded_rectangle((x0, y0, x1, y1), 38, fill=NUIT + (255,), outline=BLANC, width=8)
    f_t = police(dossier, "LilitaOne", 92)
    f_s = police(dossier, "Nunito-ExtraBold", 40)
    lt = lignes(d, titre, f_t, x1 - x0 - 70)
    ls = lignes(d, sous_titre, f_s, x1 - x0 - 110)
    h = len(lt) * 100 + 30 + len(ls) * 52
    y = (y0 + y1) // 2 - h // 2
    for l in lt:
        tw = d.textbbox((0, 0), l, font=f_t)[2]
        d.text(((x0 + x1 - tw) // 2, y), l, font=f_t, fill=JAUNE, stroke_width=6, stroke_fill=(0, 0, 0))
        y += 100
    y += 30
    sw = max(d.textbbox((0, 0), l, font=f_s)[2] for l in ls)
    d.rounded_rectangle(((x0 + x1 - sw) // 2 - 26, y - 12, (x0 + x1 + sw) // 2 + 26, y + len(ls) * 52 + 8), 16, fill=ROSE)
    for l in ls:
        lw = d.textbbox((0, 0), l, font=f_s)[2]
        d.text(((x0 + x1 - lw) // 2, y), l, font=f_s, fill=BLANC)
        y += 52
    img.save(chemin)


def bandeau(dossier, titre, sous_titre, chemin, grand=False):
    """Bandeau penché façon jeu : panneau nuit au contour épais, titre jaune, ruban rose."""
    if grand:
        return panneau_titre(dossier, titre, sous_titre, chemin)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f_titre = police(dossier, "LilitaOne", 104 if grand else 84)
    f_sous = police(dossier, "Nunito-ExtraBold", 40 if grand else 34)
    d = ImageDraw.Draw(img)
    tw = d.textbbox((0, 0), titre, font=f_titre)[2]
    sw = d.textbbox((0, 0), sous_titre, font=f_sous)[2]
    larg = max(tw, sw) + 120
    haut = (f_titre.size + f_sous.size + 110)
    calque = Image.new("RGBA", (larg + 40, haut + 40), (0, 0, 0, 0))
    c = ImageDraw.Draw(calque)
    c.rounded_rectangle((26, 30, larg + 26, haut + 30), 34, fill=(0, 0, 0, 110))  # ombre
    c.rounded_rectangle((14, 14, larg + 14, haut + 14), 34, fill=NUIT + (240,), outline=BLANC, width=7)
    x = 14 + (larg - tw) // 2
    c.text((x, 34), titre, font=f_titre, fill=JAUNE, stroke_width=6, stroke_fill=NUIT)
    ruban_y = 34 + f_titre.size + 18
    c.rounded_rectangle((14 + (larg - sw) // 2 - 22, ruban_y - 6, 14 + (larg + sw) // 2 + 22, ruban_y + f_sous.size + 14), 14, fill=ROSE)
    c.text((14 + (larg - sw) // 2, ruban_y), sous_titre, font=f_sous, fill=BLANC)
    calque = calque.rotate(2.5, resample=Image.BICUBIC, expand=True)
    if grand:  # carte de fin / accroche : à la place du menu de l'écran titre
        pos = (min(1530 - calque.width // 2, W - calque.width - 30), 410 - calque.height // 2)
    else:
        pos = ((W - calque.width) // 2, H - calque.height - 150)
    img.alpha_composite(calque, pos)
    img.save(chemin)


def avertissement(dossier, texte, chemin):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(H - 70, H):
        d.line((0, y, W, y), fill=NUIT + (int(235 * (y - (H - 70)) / 70),))
    d.rectangle((0, H - 46, W, H), fill=NUIT + (235,))
    f = police(dossier, "Nunito-ExtraBold", 24)
    d.text((26, H - 40), texte, font=f, fill=(255, 255, 255, 200))
    img.save(chemin)


def lancer(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(r.stderr[-3000:])


def monter(plans, sortie, langue):
    tmp = os.path.join(sortie, "tmp-" + langue)
    os.makedirs(tmp, exist_ok=True)
    t = TEXTES[langue]
    morceaux = []
    for i, (plan, debut, duree, cle) in enumerate(MONTAGE):
        source = os.path.join(plans, plan + ".avi")
        depart = debut_plan(plans, plan) + debut
        sortie_m = os.path.join(tmp, "m%02d.mp4" % i)
        entree = ["-ss", "%.3f" % depart, "-t", "%.3f" % duree, "-i", source]
        filtres = "[0:v]setpts=PTS-STARTPTS,fps=%d[v0]" % FPS
        dernier = "v0"
        entrees_img = []
        if plan == "titre":  # cache la ligne « prototype » en bas de l'écran titre
            img = os.path.join(tmp, "avert.png")
            avertissement(plans, t["avertissement"], img)
            entrees_img.append(img)
        if cle:
            img = os.path.join(tmp, "b%02d.png" % i)
            bandeau(plans, t[cle][0], t[cle][1], img, grand=(cle in ("accroche", "fin")))
            entrees_img.append(img)
        args = ["ffmpeg", "-v", "error", "-y"] + entree
        for n, img in enumerate(entrees_img):
            args += ["-loop", "1", "-t", "%.3f" % duree, "-i", img]
            k = n + 1
            apparition = 0.35 if os.path.basename(img).startswith("b") else 0.0
            filtres += ";[%d:v]format=rgba,fade=t=in:st=%.2f:d=0.25:alpha=1[i%d]" % (k, apparition, k)
            filtres += ";[%s][i%d]overlay=0:0[v%d]" % (dernier, k, k)
            dernier = "v%d" % k
        filtres += ";[0:a]asetpts=PTS-STARTPTS,aresample=48000[a]"
        args += ["-filter_complex", filtres, "-map", "[%s]" % dernier, "-map", "[a]",
                 "-c:v", "libx264", "-preset", "medium", "-crf", "14", "-pix_fmt", "yuv420p",
                 "-c:a", "pcm_s16le", "-t", "%.3f" % duree, sortie_m]
        lancer(args)
        morceaux.append((sortie_m, duree))

    # Enchaînement : fondus blancs courts, son du jeu en fondu croisé.
    args = ["ffmpeg", "-v", "error", "-y"]
    for m, _ in morceaux:
        args += ["-i", m]
    f = []
    v, a, total = "0:v", "0:a", morceaux[0][1]
    for i in range(1, len(morceaux)):
        f.append("[%s][%d:v]xfade=transition=fadewhite:duration=%.2f:offset=%.3f[xv%d]" % (v, i, FONDU, total - FONDU, i))
        f.append("[%s][%d:a]acrossfade=d=%.2f[xa%d]" % (a, i, FONDU, i))
        v, a = "xv%d" % i, "xa%d" % i
        total += morceaux[i][1] - FONDU
    # Fondu au noir final ; musique de Gaël sous le son du jeu.
    f.append("[%s]fade=t=out:st=%.3f:d=0.8[vf]" % (v, total - 0.8))
    musique_i = len(morceaux)
    args += ["-stream_loop", "-1", "-i", MUSIQUE]
    f.append("[%d:a]atrim=0:%.3f,asetpts=PTS-STARTPTS,afade=t=in:d=0.3,afade=t=out:st=%.3f:d=2.5,volume=0.9[mus]" % (musique_i, total, total - 2.5))
    f.append("[%s]volume=0.45[jeu]" % a)
    f.append("[mus][jeu]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-15:TP=-1.5:LRA=11,aresample=48000[af]")
    args += ["-filter_complex", ";".join(f), "-map", "[vf]", "-map", "[af]",
             "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-maxrate", "16M", "-bufsize", "32M",
             "-pix_fmt", "yuv420p", "-r", str(FPS), "-profile:v", "high", "-movflags", "+faststart",
             "-c:a", "aac", "-b:a", "320k", "-ac", "2", "-t", "%.3f" % total,
             os.path.join(sortie, "trailer-%s.mp4" % langue)]
    lancer(args)
    print("trailer-%s.mp4 : %.1f s" % (langue, total))


if __name__ == "__main__":
    langues = sys.argv[3:] or ["fr", "en"]
    for lg in langues:
        monter(sys.argv[1], sys.argv[2], lg)
