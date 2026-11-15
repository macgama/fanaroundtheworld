"""Repères du corps (épaules, coudes, poignets, hanches, genoux, chevilles, nez)
d'une image FANZZY de face, via MediaPipe Pose (Apache 2.0)."""
import sys, json, numpy as np
from PIL import Image
import mediapipe as mp
from mediapipe.tasks.python import vision, BaseOptions

NOMS = {0: "nez", 11: "epaule.L", 12: "epaule.R", 13: "coude.L", 14: "coude.R",
        15: "poignet.L", 16: "poignet.R", 23: "hanche.L", 24: "hanche.R",
        25: "genou.L", 26: "genou.R", 27: "cheville.L", 28: "cheville.R",
        7: "oreille.L", 8: "oreille.R", 31: "pied.L", 32: "pied.R"}

def detecteur(modele):
    o = vision.PoseLandmarkerOptions(base_options=BaseOptions(model_asset_path=modele),
                                     num_poses=1, min_pose_detection_confidence=0.2)
    return vision.PoseLandmarker.create_from_options(o)

def reperes(det, chemin):
    im = Image.open(chemin).convert("RGBA")
    w, h = im.size
    # fond gris neutre, marge pour que le personnage ne touche pas les bords
    m = int(h * 0.15)
    fond = Image.new("RGB", (w + 2 * m, h + 2 * m), (128, 128, 128))
    fond.paste(im, (m, m), im)
    r = det.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.asarray(fond)))
    if not r.pose_landmarks:
        return None
    W, H = fond.size
    return {n: [p.x * W - m, p.y * H - m, p.visibility]
            for i, n in NOMS.items() for p in [r.pose_landmarks[0][i]]}

if __name__ == "__main__":
    det = detecteur(sys.argv[1])
    print(json.dumps({c: reperes(det, c) for c in sys.argv[2:]}, indent=0))
