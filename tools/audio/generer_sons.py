#!/usr/bin/env python3
"""Fabrique toute la banque de sons du jeu par synthèse, sans aucun fichier source.

Pourquoi : les sons de TheBestFan viennent presque tous d'Artlist, dont la
licence standard ne couvre pas un jeu vendu sur Steam (voir docs/AUDIO.md).
Ici, chaque son est calculé à partir de bruit et d'oscillateurs : il appartient
au projet, sans licence à suivre. La graine est fixe, deux exécutions donnent
les mêmes fichiers.

Règles reprises de TheBestFan : du rythme, des bruits, des accords tenus,
**jamais un air connu** (les chants de supporters reprennent souvent des airs
protégés).

Usage :
    pip install numpy scipy
    python3 tools/audio/generer_sons.py          # écrit assets/audio/...
    python3 tools/audio/generer_sons.py --liste  # affiche seulement la liste

Sorties :
    assets/audio/sfx/*.wav        sons brefs, mono 16 bits 44,1 kHz (aucun
                                  décodage : ils tombent pile)
    assets/audio/ambiances/*.ogg  boucles stéréo de 12 s, Ogg Vorbis
Le catalogue qui les décrit est data/audio/catalogue_sons.json (écrit à la main).
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
RACINE = Path(__file__).resolve().parents[2]
SFX = RACINE / "assets" / "audio" / "sfx"
AMB = RACINE / "assets" / "audio" / "ambiances"

rng = np.random.default_rng(20261114)


# --------------------------------------------------------------- outils

def t_(duree: float) -> np.ndarray:
    return np.arange(int(SR * duree)) / SR


def blanc(n: int) -> np.ndarray:
    return rng.uniform(-1, 1, n)


def rose(n: int) -> np.ndarray:
    """Bruit rose (filtre de Paul Kellet, version économique en IIR)."""
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    x = signal.lfilter(b, a, rng.standard_normal(n + 2000))[2000:]
    return x / (np.max(np.abs(x)) + 1e-9)


def filtre(x, kind, f, ordre=2):
    if kind == "bande":
        sos = signal.butter(ordre, [f[0], f[1]], btype="bandpass", fs=SR, output="sos")
    elif kind == "bas":
        sos = signal.butter(ordre, f, btype="lowpass", fs=SR, output="sos")
    else:
        sos = signal.butter(ordre, f, btype="highpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def env_exp(n, tau):
    return np.exp(-np.arange(n) / SR / tau)


def attaque(x, ms=3.0):
    k = min(len(x), int(SR * ms / 1000))
    x = x.copy()
    x[:k] *= np.linspace(0, 1, k)
    return x


def fondu_fin(x, ms=20.0):
    k = min(len(x), int(SR * ms / 1000))
    x = x.copy()
    x[-k:] *= np.linspace(1, 0, k)[:, None] if x.ndim == 2 else np.linspace(1, 0, k)
    return x


def reverbe(x, duree=1.2, mix=0.25, couleur=4000, stereo=False):
    """Réverbération par convolution avec un bruit qui s'éteint."""
    n = int(SR * duree)
    def ri():
        r = filtre(blanc(n), "bas", couleur) * env_exp(n, duree / 6.5)
        r[: int(SR * 0.012)] = 0  # pré-délai
        return r / np.sqrt(np.sum(r ** 2))
    if x.ndim == 1 and not stereo:
        w = signal.fftconvolve(x, ri())[: len(x)]
        return (1 - mix) * x + mix * w
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    out = np.empty_like(x)
    for c in range(2):
        w = signal.fftconvolve(x[:, c], ri())[: len(x)]
        out[:, c] = (1 - mix) * x[:, c] + mix * w
    return out


def normaliser_crete(x, dbfs=-3.0):
    return x * (10 ** (dbfs / 20) / (np.max(np.abs(x)) + 1e-9))


def normaliser_rms(x, dbfs=-24.0, crete_max=-3.0):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    y = x * (10 ** (dbfs / 20) / rms)
    pic = np.max(np.abs(y))
    lim = 10 ** (crete_max / 20)
    if pic > lim:  # limiteur doux plutôt que de baisser tout
        y = np.tanh(y / lim) * lim
    return y


def panner(x, pan):
    """Panoramique à puissance constante, pan de -1 (gauche) à 1 (droite)."""
    a = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def boucle(x, fondu=0.25):
    """Rend une boucle sans couture : la fin se fond dans le début."""
    k = int(SR * fondu)
    tete, corps = x[:k], x[k:]
    w = np.sqrt(np.linspace(0, 1, k))[:, None] if x.ndim == 2 else np.sqrt(np.linspace(0, 1, k))
    corps = corps.copy()
    corps[-k:] = corps[-k:] * w[::-1] + tete * w
    return corps


# ------------------------------------------------------------ les matières

def tambour(force=1.0, f_haut=130.0, f_bas=52.0, duree=0.55):
    """Grosse caisse de tribune frappée à la mailloche (repris de TheBestFan)."""
    t = t_(duree)
    f = f_bas + (f_haut - f_bas) * np.exp(-t / 0.05)
    peau = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(len(t), 0.16)
    choc = filtre(blanc(len(t)), "bas", 900) * env_exp(len(t), 0.012) * 0.8
    harm = signal.sawtooth(2 * np.pi * np.cumsum(240 * np.exp(-t / 0.15) + 100) / SR, 0.5)
    harm *= env_exp(len(t), 0.04) * 0.25
    x = attaque(peau + choc + harm, 1.5) * force
    return reverbe(x, 0.9, 0.18, 3000)


def caisse_claire(force=1.0):
    t = t_(0.3)
    timbre = filtre(blanc(len(t)), "bande", (1800, 7000)) * env_exp(len(t), 0.06)
    peau = np.sin(2 * np.pi * 190 * t) * env_exp(len(t), 0.03) * 0.7
    return reverbe(attaque(timbre + peau, 1) * force, 0.7, 0.2)


def clap_foule(force=1.0, mains=180):
    """Des centaines de mains, jamais tout à fait ensemble."""
    n = int(SR * 0.45)
    x = np.zeros(n)
    for _ in range(mains):
        d = int(abs(rng.normal(0, 0.012)) * SR)
        lg = int(SR * 0.02)
        if d + lg >= n:
            continue
        g = rng.uniform(0.3, 1.0)
        x[d:d + lg] += filtre(blanc(lg), "bande", (rng.uniform(800, 1400), rng.uniform(2500, 4000))) \
            * env_exp(lg, 0.004) * g
    x = attaque(x, 0.5) * force
    return reverbe(x, 1.1, 0.3, 5000)


def voix(duree, f0, voyelle="a", glisse=(1.0, 1.12, 0.8), souffle=0.15):
    """Une voix qui crie sans mots : dent de scie dans deux formants."""
    formants = {"a": (750, 1200), "o": (500, 900), "e": (550, 1800), "i": (320, 2300), "ou": (350, 800)}
    t = t_(duree)
    courbe = np.interp(t, [0, duree * 0.35, duree], [f0 * glisse[0], f0 * glisse[1], f0 * glisse[2]])
    courbe *= 1 + 0.012 * np.sin(2 * np.pi * rng.uniform(4.5, 6.5) * t)  # vibrato
    src = signal.sawtooth(2 * np.pi * np.cumsum(courbe) / SR) + souffle * blanc(len(t))
    f1, f2 = formants[voyelle]
    y = filtre(src, "bande", (f1 * 0.85, f1 * 1.15)) + 0.6 * filtre(src, "bande", (f2 * 0.88, f2 * 1.12))
    e = np.interp(t, [0, 0.04, duree * 0.65, duree], [0, 1, 0.85, 0])
    return y * e


def foule_qui_crie(duree, voix_n, voyelle="o", f_min=160, f_max=300, etalement=0.12):
    n = int(SR * (duree + etalement + 0.1))
    x = np.zeros((n, 2))
    for _ in range(voix_n):
        d = int(rng.uniform(0, etalement) * SR)
        v = voix(duree * rng.uniform(0.85, 1.0), rng.uniform(f_min, f_max), voyelle)
        x[d:d + len(v)] += panner(v * rng.uniform(0.5, 1.0), rng.uniform(-0.8, 0.8))
    return x


def babillage(duree, voix_n, f_min=110, f_max=260, niveau=1.0, stereo=True):
    """Le murmure d'un lieu plein : des syllabes courtes, au hasard."""
    n = int(SR * duree)
    x = np.zeros((n, 2))
    for _ in range(voix_n):
        pos = rng.uniform(-0.9, 0.9)
        f0 = rng.uniform(f_min, f_max)
        t = rng.uniform(0, 0.3)
        while t < duree - 0.4:
            lg = rng.uniform(0.08, 0.28)
            syl = voix(lg, f0 * rng.uniform(0.9, 1.15), rng.choice(["a", "o", "e", "i", "ou"]),
                       glisse=(1, rng.uniform(0.95, 1.1), rng.uniform(0.85, 1.0)), souffle=0.25)
            i = int(t * SR)
            x[i:i + len(syl)] += panner(syl * rng.uniform(0.3, 1.0), pos)
            t += lg + rng.exponential(0.12)
            if rng.random() < 0.08:
                t += rng.uniform(0.5, 1.5)  # la voix reprend son souffle
    return x * niveau


# --------------------------------------------------------------- la banque

def s_tambour(i):
    return lambda: normaliser_crete(tambour(1.0, 130 + 8 * i, 52 - 2 * i), -2)


def s_clap(i):
    return lambda: normaliser_crete(clap_foule(1.0, 150 + 30 * i), -3)


def s_eclat(voyelle):
    def f():
        x = foule_qui_crie(0.45, 1, voyelle, 180, 280, 0.0)
        return normaliser_crete(reverbe(x, 1.2, 0.3, 4000), -4)
    return f


def s_cri_groupe():
    x = foule_qui_crie(0.6, 40, "o", 150, 320, 0.15)
    return normaliser_crete(reverbe(x, 1.8, 0.35, 4000), -3)


def s_hey():
    x = foule_qui_crie(0.32, 60, "e", 170, 330, 0.05)
    return normaliser_crete(reverbe(x, 1.6, 0.35, 4500), -3)


def s_sifflet_arbitre(long=False):
    def f():
        segs = [0.35, 0.35, 1.0] if long else [0.45]
        x = []
        for d in segs:
            t = t_(d)
            trille = 1 + 0.04 * signal.square(2 * np.pi * 28 * t)
            s = np.sin(2 * np.pi * np.cumsum(2850 * trille) / SR) + 0.3 * filtre(blanc(len(t)), "bande", (2500, 3500))
            s *= np.interp(t, [0, 0.02, d - 0.05, d], [0, 1, 1, 0])
            x += [s, np.zeros(int(SR * 0.12))]
        return normaliser_crete(reverbe(np.concatenate(x), 1.5, 0.25, 6000, stereo=True), -6)
    return f


def s_corne():
    t = t_(1.4)
    x = sum(signal.sawtooth(2 * np.pi * f * t) for f in (233.1, 293.7, 349.2))  # accord tenu, pas un air
    x = filtre(x, "bas", 2500) * np.interp(t, [0, 0.05, 1.2, 1.4], [0, 1, 0.9, 0])
    return normaliser_crete(reverbe(x, 2.0, 0.3, 4000, stereo=True), -4)


def s_clameur_but():
    """Le but : la tribune explose, tient, puis retombe en applaudissant."""
    d = 5.0
    n = int(SR * d)
    t = np.arange(n) / SR
    rugir = filtre(rose(n), "bande", (250, 3500))
    forme = np.interp(t, [0, 0.12, 0.5, 3.0, 5.0], [0, 1, 0.95, 0.6, 0])
    x = np.stack([rugir, np.roll(rugir, 1337)], 1) * forme[:, None] * 0.6
    cris = foule_qui_crie(2.4, 120, "o", 150, 340, 0.3)
    x[: len(cris)] += cris * 0.5
    ap = np.zeros(n)
    for _ in range(900):
        i = int(rng.uniform(0.8, 4.8) * SR)
        lg = int(SR * 0.015)
        if i + lg < n:
            ap[i:i + lg] += filtre(blanc(lg), "bande", (1000, 4000)) * env_exp(lg, 0.004) * rng.uniform(0.2, 1)
    x += panner(ap * 0.4, 0)
    return fondu_fin(normaliser_crete(reverbe(x, 2.5, 0.35, 4000), -2), 300)


def s_deception():
    d = 2.2
    x = foule_qui_crie(1.6, 90, "ou", 140, 260, 0.2) * 0.8
    n = int(SR * d)
    y = np.zeros((n, 2))
    y[: len(x)] += x
    t = np.arange(n) / SR
    y *= np.interp(t, [0, 0.2, 1.4, d], [0.6, 1, 0.5, 0])[:, None]
    return normaliser_crete(reverbe(y, 2.2, 0.35, 3500), -4)


def s_sifflets_foule():
    """La tribune siffle (désaccord) : des sifflets bouche, chacun le sien."""
    d = 2.0
    n = int(SR * d)
    x = np.zeros((n, 2))
    for _ in range(50):
        i = int(rng.uniform(0, 0.3) * SR)
        lg = int(rng.uniform(0.8, 1.6) * SR)
        lg = min(lg, n - i)
        t = np.arange(lg) / SR
        f = rng.uniform(1800, 3200) * (1 + 0.05 * np.sin(2 * np.pi * rng.uniform(3, 7) * t))
        s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.interp(t, [0, 0.05, t[-1] - 0.1, t[-1]], [0, 1, 0.8, 0])
        x[i:i + lg] += panner(s * rng.uniform(0.2, 0.7), rng.uniform(-0.9, 0.9))
    x += np.stack([filtre(rose(n), "bande", (1500, 5000))] * 2, 1) * 0.2
    return normaliser_crete(reverbe(x, 2.0, 0.3, 6000), -6)


def s_ola():
    """La ola passe de gauche à droite : une vague de cris et de souffle."""
    d = 3.2
    n = int(SR * d)
    t = np.arange(n) / SR
    x = np.zeros((n, 2))
    for k in range(70):
        pos = -1 + 2 * k / 69
        i = int((0.2 + 2.4 * k / 69 + rng.normal(0, 0.03)) * SR)
        v = voix(rng.uniform(0.4, 0.7), rng.uniform(170, 320), rng.choice(["o", "a"]),
                 glisse=(0.9, 1.25, 1.0))
        if i + len(v) < n:
            x[i:i + len(v)] += panner(v * rng.uniform(0.4, 1.0), pos)
    souffle = filtre(rose(n), "bande", (300, 2500)) * np.interp(t, [0, 1.4, d], [0.1, 0.5, 0])
    pan = np.clip(np.interp(t, [0, d], [-1, 1]), -1, 1)
    a = (pan + 1) * np.pi / 4
    x += np.stack([souffle * np.cos(a), souffle * np.sin(a)], 1)
    return fondu_fin(normaliser_crete(reverbe(x, 2.0, 0.3, 4500), -3), 200)


def s_applaudissements():
    d = 3.0
    n = int(SR * d)
    x = np.zeros((n, 2))
    for _ in range(2500):
        i = int(rng.uniform(0, d - 0.05) * SR)
        lg = int(SR * 0.015)
        c = filtre(blanc(lg), "bande", (rng.uniform(800, 1500), rng.uniform(2500, 5000))) * env_exp(lg, 0.004)
        x[i:i + lg] += panner(c * rng.uniform(0.2, 1), rng.uniform(-0.9, 0.9))
    t = np.arange(n) / SR
    x *= np.interp(t, [0, 0.3, 2.2, d], [0, 1, 0.8, 0])[:, None]
    return normaliser_crete(reverbe(x, 1.5, 0.3, 6000), -5)


def s_tifo():
    """Une immense bâche qui se déploie au-dessus de la tribune."""
    d = 2.4
    n = int(SR * d)
    t = np.arange(n) / SR
    tissu = filtre(rose(n), "bande", (150, 3000)) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 3.5 * t)))
    x = tissu * np.interp(t, [0, 0.3, 1.6, d], [0, 1, 0.7, 0])
    y = np.stack([x, np.roll(x, 911)], 1)
    ov = foule_qui_crie(1.2, 60, "a", 160, 320, 0.2)
    i = int(0.9 * SR)
    y[i:i + len(ov)] += ov[: n - i] * 0.6
    return normaliser_crete(reverbe(y, 2.0, 0.3, 4000), -4)


def s_fumigene():
    d = 1.8
    n = int(SR * d)
    t = np.arange(n) / SR
    x = filtre(blanc(n), "haut", 2500) * np.interp(t, [0, 0.05, 1.4, d], [0, 1, 0.8, 0])
    x += filtre(blanc(n), "bande", (300, 900)) * 0.3 * np.interp(t, [0, 0.02, 0.15], [0, 1, 0.2], right=0.2)
    return normaliser_crete(reverbe(x, 1.5, 0.25, 6000, stereo=True), -8)


def note(f, d, forme="sinus", tau=None):
    t = t_(d)
    if forme == "sinus":
        x = np.sin(2 * np.pi * f * t)
    else:
        x = signal.sawtooth(2 * np.pi * f * t, 0.5)
    return attaque(x * env_exp(len(t), tau or d / 4), 2)


def s_ui_parfait():
    x = sum(note(f, 0.5, tau=0.12) * g for f, g in ((1318.5, 1), (1975.5, 0.6), (2637, 0.3)))
    x2 = sum(note(f, 0.5, tau=0.12) * g for f, g in ((1760, 0.7), (2637, 0.3)))
    k = int(SR * 0.06)
    y = np.zeros(k + len(x2))
    y[: len(x)] += x
    y[k:] += x2
    return normaliser_crete(reverbe(y, 0.8, 0.2, 8000), -6)


def s_ui_bien():
    return normaliser_crete(reverbe(note(1046.5, 0.3, tau=0.08) + 0.4 * note(1568, 0.3, tau=0.06), 0.6, 0.15), -8)


def s_ui_rate():
    t = t_(0.25)
    x = signal.sawtooth(2 * np.pi * np.cumsum(180 * np.exp(-t / 0.2) + 60) / SR, 0.5)
    x = filtre(x, "bas", 900) * env_exp(len(t), 0.07)
    return normaliser_crete(attaque(x, 2), -9)


def s_ui_combo(niveau):
    def f():
        base = [523.25, 659.25, 783.99, 1046.5][niveau]
        x = sum(note(base * r, 0.4, "tri", tau=0.1) * g for r, g in ((1, 1), (1.5, 0.5), (2, 0.4)))
        return normaliser_crete(reverbe(x, 0.7, 0.2, 8000), -7)
    return f


def s_ui_clic():
    t = t_(0.05)
    x = filtre(blanc(len(t)), "bande", (2000, 6000)) * env_exp(len(t), 0.006)
    return normaliser_crete(x + 0.5 * note(1800, 0.05, tau=0.01), -10)


def s_ui_decompte(dernier=False):
    def f():
        x = note(1760 if dernier else 880, 0.35 if dernier else 0.2, tau=0.09)
        return normaliser_crete(reverbe(x, 0.6, 0.2), -8)
    return f


# ---------------------------------------------------------- les ambiances

def amb_stade(intensite):
    """La rumeur de tribune : 0 calme, 1 chaude, 2 ferveur."""
    d = 12.5
    n = int(SR * d)
    lit = np.stack([filtre(rose(n), "bande", (120, 2200)), filtre(rose(n), "bande", (120, 2200))], 1)
    lit *= [0.35, 0.5, 0.7][intensite]
    bab = babillage(d, [30, 50, 70][intensite], 120, 300, [0.4, 0.55, 0.7][intensite])
    x = lit + bab
    t = np.arange(n) / SR
    for _ in range([3, 7, 14][intensite]):  # des éclats au loin
        i = int(rng.uniform(0, d - 1) * SR)
        v = foule_qui_crie(rng.uniform(0.3, 0.6), int(rng.integers(1, 6 + 6 * intensite)),
                           rng.choice(["o", "a", "e"]), 160, 320, 0.1)
        x[i:i + len(v)] += v[: n - i] * rng.uniform(0.15, 0.4)
    if intensite == 2:  # des tambours lointains, jamais en mesure avec le jeu
        for k in np.arange(0.3, d - 0.6, 0.54):
            i = int((k + rng.normal(0, 0.01)) * SR)
            b = tambour(rng.uniform(0.3, 0.5))
            x[i:i + len(b)] += panner(b, -0.4)[: n - i] * 0.25
    x = reverbe(x, 2.8, 0.45, 3000)
    x *= (1 + 0.08 * np.sin(2 * np.pi * t / 6.2))[:, None]
    return normaliser_rms(boucle(x), [-26, -23, -20][intensite])


def amb_pub():
    """Un pub qui regarde le match : on parle, les verres, la télé au fond."""
    d = 12.5
    n = int(SR * d)
    x = babillage(d, 22, 95, 240, 0.7)
    for _ in range(14):  # verres
        i = int(rng.uniform(0, d - 0.5) * SR)
        f0 = rng.uniform(2400, 4200)
        tin = sum(note(f0 * r, 0.4, tau=0.06) * g for r, g in ((1, 1), (2.76, 0.4), (5.4, 0.2)))
        x[i:i + len(tin)] += panner(tin * rng.uniform(0.05, 0.15), rng.uniform(-0.8, 0.8))[: n - i]
    for _ in range(4):  # un rire de tablée
        i = int(rng.uniform(0, d - 1.5) * SR)
        r = np.concatenate([voix(0.12, rng.uniform(180, 260), "a", (1, 1.05, 0.95)) for _ in range(5)])
        x[i:i + len(r)] += panner(r * 0.3, rng.uniform(-0.6, 0.6))[: n - i]
    tele = filtre(rose(n), "bande", (400, 3000)) * 0.08  # la foule de la retransmission
    x += np.stack([tele, tele], 1)
    x = reverbe(x, 0.8, 0.35, 3500)
    return normaliser_rms(boucle(x), -25)


def amb_maison():
    """Le salon : la télé et sa foule dans un petit haut-parleur, la pièce."""
    d = 12.5
    n = int(SR * d)
    foule = filtre(rose(n), "bande", (250, 1800)) * 0.5
    foule += babillage(d, 25, 130, 300, 0.25)[:, 0]
    foule = filtre(foule, "bande", (300, 3500), 4)  # le haut-parleur de la télé
    t = np.arange(n) / SR
    foule *= 1 + 0.15 * np.sin(2 * np.pi * t / 4.1)
    piece = filtre(rose(n), "bas", 200) * 0.05  # le frigo, la rue
    x = np.stack([foule * 0.9 + piece, foule * 0.8 + piece], 1)
    x = reverbe(x, 0.4, 0.3, 3000)
    return normaliser_rms(boucle(x), -30)


def amb_ecran_geant():
    """Une place en plein air devant un écran géant : foule ouverte, écho de sono."""
    d = 12.5
    n = int(SR * d)
    x = babillage(d, 45, 110, 290, 0.55)
    x += np.stack([filtre(rose(n), "bande", (100, 2000))] * 2, 1) * 0.3
    sono = filtre(rose(n), "bande", (500, 2500)) * 0.12
    eco = np.zeros(n)
    k = int(0.18 * SR)
    eco[k:] = sono[:-k] * 0.5
    x += np.stack([sono + eco, sono * 0.7 + eco], 1)
    x = filtre(x, "haut", 90)
    x = reverbe(x, 1.6, 0.2, 5000)  # peu de réverbe : on est dehors
    return normaliser_rms(boucle(x), -25)


SFX_BANQUE = {
    "tambour_1": s_tambour(0), "tambour_2": s_tambour(1), "tambour_3": s_tambour(2),
    "caisse_claire": lambda: normaliser_crete(caisse_claire(), -4),
    "clap_1": s_clap(0), "clap_2": s_clap(1), "clap_3": s_clap(2),
    "eclat_o": s_eclat("o"), "eclat_a": s_eclat("a"), "eclat_e": s_eclat("e"),
    "cri_groupe": s_cri_groupe, "hey": s_hey,
    "sifflet_court": s_sifflet_arbitre(False), "sifflet_fin": s_sifflet_arbitre(True),
    "corne": s_corne, "clameur_but": s_clameur_but, "deception": s_deception,
    "sifflets_foule": s_sifflets_foule, "ola": s_ola, "applaudissements": s_applaudissements,
    "tifo": s_tifo, "fumigene": s_fumigene,
    "ui_parfait": s_ui_parfait, "ui_bien": s_ui_bien, "ui_rate": s_ui_rate,
    "ui_combo_1": s_ui_combo(0), "ui_combo_2": s_ui_combo(1), "ui_combo_3": s_ui_combo(2),
    "ui_combo_4": s_ui_combo(3), "ui_clic": s_ui_clic,
    "ui_decompte": s_ui_decompte(False), "ui_decompte_go": s_ui_decompte(True),
}
AMB_BANQUE = {
    "stade_calme": lambda: amb_stade(0), "stade_chaud": lambda: amb_stade(1),
    "stade_ferveur": lambda: amb_stade(2), "pub": amb_pub, "maison": amb_maison,
    "ecran_geant": amb_ecran_geant,
}


# ------------------------------------------------------------- l'écriture

def ecrire_wav(chemin: Path, x: np.ndarray):
    x = np.clip(x, -1, 1)
    canaux = 1 if x.ndim == 1 else x.shape[1]
    with wave.open(str(chemin), "wb") as w:
        w.setnchannels(canaux)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def ecrire_ogg(chemin: Path, x: np.ndarray):
    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg est nécessaire pour écrire les ambiances en Ogg Vorbis.")
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d) / "x.wav"
        ecrire_wav(tmp, x)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(tmp), "-c:a", "libvorbis",
                        "-q:a", "4", str(chemin)], check=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--liste", action="store_true")
    p.add_argument("--seul", help="ne fabrique que ce son")
    a = p.parse_args()
    if a.liste:
        print("\n".join(list(SFX_BANQUE) + list(AMB_BANQUE)))
        return
    SFX.mkdir(parents=True, exist_ok=True)
    AMB.mkdir(parents=True, exist_ok=True)
    for nom, f in SFX_BANQUE.items():
        if a.seul and nom != a.seul:
            continue
        x = f()
        ecrire_wav(SFX / f"{nom}.wav", x)
        print(f"sfx       {nom:18s} {len(x) / SR:5.2f} s")
    for nom, f in AMB_BANQUE.items():
        if a.seul and nom != a.seul:
            continue
        x = f()
        ecrire_ogg(AMB / f"{nom}.ogg", x)
        print(f"ambiance  {nom:18s} {len(x) / SR:5.2f} s")


if __name__ == "__main__":
    main()
