"""planche.py sortie.png largeur hauteur img1 img2 ... : met des images côte à côte."""
import sys
from PIL import Image
out, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
ims = [Image.open(p).convert("RGB").resize((w, h)) for p in sys.argv[4:]]
o = Image.new("RGB", (w * len(ims), h))
for k, im in enumerate(ims): o.paste(im, (w * k, 0))
o.save(out)
