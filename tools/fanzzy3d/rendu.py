"""Rendus de contrôle et vidéo d'un FANZZY 3D.

blender -b <ID>.blend -P rendu.py -- <sortie> images      # planche de vues fixes
blender -b <ID>.blend -P rendu.py -- <sortie> video        # vidéo des 5 animations
"""
import sys, os, math
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SORTIE, MODE = os.path.abspath(argv[0]), argv[1]
os.makedirs(SORTIE, exist_ok=True)
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == "ARMATURE")
IDENT = rig.name.split("_")[0]

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 640, 720
scene.render.fps = 24
w = scene.world or bpy.data.worlds.new("monde")
scene.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.75, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
scene.view_settings.view_transform = "Standard"

# sol (pelouse stylisée) + lumières
bpy.ops.mesh.primitive_plane_add(size=12)
sol = bpy.context.object
m = bpy.data.materials.new("sol")
m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.55, 0.22, 1)
sol.data.materials.append(m)
bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(-35)))
bpy.context.object.data.energy = 3.5
bpy.context.object.data.angle = math.radians(8)
bpy.ops.object.light_add(type="SUN", rotation=(math.radians(60), 0, math.radians(150)))
bpy.context.object.data.energy = 1.2

cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
scene.collection.objects.link(cam)
scene.camera = cam
cam_d.lens = 50


def viser(azimut, hauteur, dist=4.2, cible=Vector((0, 0, 0.85))):
    a, h = math.radians(azimut), math.radians(hauteur)
    cam.location = cible + Vector((math.sin(a) * math.cos(h), -math.cos(a) * math.cos(h), math.sin(h))) * dist
    cam.rotation_euler = (cible - cam.location).to_track_quat("-Z", "Y").to_euler()


def action(nom):
    rig.animation_data.action = bpy.data.actions[nom]
    for t in rig.animation_data.nla_tracks:
        t.mute = True


def rendre(chemin):
    scene.render.filepath = chemin
    bpy.ops.render.render(write_still=True)


if MODE == "images":
    action("attente")
    scene.frame_set(1)
    for nom, az, ht in (("face", 0, 8), ("trois-quarts", 35, 20), ("profil", 90, 8), ("dos", 180, 15),
                        ("dessus", 20, 55)):
        viser(az, ht)
        rendre(os.path.join(SORTIE, f"{IDENT}-{nom}.png"))
    for nom, f in (("course", 5), ("lancer", 9), ("lancer", 13), ("victoire", 13), ("depit", 26)):
        action(nom)
        scene.frame_set(f)
        viser(35, 20)
        rendre(os.path.join(SORTIE, f"{IDENT}-{nom}-{f}.png"))
else:
    # une seule vidéo : chaque animation à la suite, caméra qui tourne doucement
    seq = [("attente", 1, 49, 2), ("course", 1, 17, 4), ("lancer", 1, 19, 3), ("victoire", 1, 25, 3),
           ("depit", 1, 49, 1)]
    tmp = os.path.join(SORTIE, "_images")
    os.makedirs(tmp, exist_ok=True)
    scene.render.image_settings.file_format = "PNG"
    n = 0
    for nom, a, b, rep in seq:
        action(nom)
        for r in range(rep):
            for f in range(a, b):
                scene.frame_set(f)
                viser(20 + 25 * math.sin(n / 60), 18)
                scene.render.filepath = os.path.join(tmp, f"{n:05d}.png")
                bpy.ops.render.render(write_still=True)
                n += 1
    print("IMAGES", n)
