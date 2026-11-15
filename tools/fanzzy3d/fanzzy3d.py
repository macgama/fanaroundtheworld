"""Construit un FANZZY 3D animé à partir d'un skin préparé (preparer.py).

blender -b -P fanzzy3d.py -- <dossier prep> <ID> <dossier sortie>

Le modèle : corps (tête, buste, jambes) gonflé d'un seul tenant, bras à part
(ils peuvent se lever sans arracher le buste), texture de face projetée,
texture de dos calculée. Squelette de 12 os aux noms français et 5 actions :
attente, course, lancer, victoire, depit. Sortie : <ID>.glb et <ID>.blend.
Taille : 1 unité = 1 m, pieds à z = 0, face vers -Y (+Z dans Godot).
"""
import sys, os, json, math
import numpy as np
import bpy, bmesh
from mathutils import Vector, Matrix, Quaternion

argv = sys.argv[sys.argv.index("--") + 1:]
PREP, IDENT, SORTIE = os.path.abspath(argv[0]), argv[1], os.path.abspath(argv[2])
os.makedirs(SORTIE, exist_ok=True)

TETE, TORSE, JAMBE_G, JAMBE_D, BRAS_G, BRAS_D = 1, 2, 3, 4, 5, 6
PAS = 6                 # pixels par case de la grille
ECHELLE = 1.75 / 945.0  # mètres par pixel (image de 945 px de haut)
DOS = 0.95              # le dos est un peu moins bombé que la face

d = np.load(os.path.join(PREP, IDENT + ".npz"))
info = json.load(open(os.path.join(PREP, IDENT + ".json"), encoding="utf8"))
lab = d["lab"]
H, W = lab.shape
R = info["reperes"]
pieds_y = np.nonzero(lab.any(1))[0].max()
centre_x = (R["hanche.L"][0] + R["hanche.R"][0]) / 2


def vers3d(x, y, prof=0.0):
    return Vector(((x - centre_x) * ECHELLE, prof * ECHELLE, (pieds_y - y) * ECHELLE))


def P(n):
    return vers3d(*R[n])


# ---------------------------------------------------------------- scène vide
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def materiau(nom, image):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(image)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.75
    return m


MAT_AVANT = materiau(IDENT + "_avant", os.path.join(PREP, IDENT + "-avant.png"))
MAT_DOS = materiau(IDENT + "_dos", os.path.join(PREP, IDENT + "-dos.png"))


def gonfler(nom, masque, z):
    """Maillage fermé : face avant (z), dos (-z), bord cousu."""
    gy, gx = np.mgrid[0:H:PAS, 0:W:PAS]
    dedans = masque[gy, gx]
    ny, nx = dedans.shape
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UV")
    av, ar, pix, ordre = {}, {}, {}, []
    for j in range(ny):
        for i in range(nx):
            if dedans[j, i]:
                x, y = gx[j, i], gy[j, i]
                zz = max(float(z[y, x]), 1.0)
                av[j, i] = bm.verts.new(vers3d(x, y, -zz))
                ar[j, i] = bm.verts.new(vers3d(x, y, zz * DOS))
                ordre.append((int(x), int(y)))
                ordre.append((int(x), int(y)))
                pix[av[j, i]] = pix[ar[j, i]] = (x, y)
    bords = {}

    def face(vs, mat):
        f = bm.faces.new(vs)
        f.material_index = mat
        for l in f.loops:
            x, y = pix[l.vert]
            l[uv].uv = (x / W, 1 - y / H)
        return f

    for j in range(ny - 1):
        for i in range(nx - 1):
            c = [(j, i), (j, i + 1), (j + 1, i + 1), (j + 1, i)]
            if all(k in av for k in c):
                face([av[k] for k in c[::-1]], 0)  # normale vers -Y (face)
                face([ar[k] for k in c], 1)
                for a, b in zip(c, c[1:] + c[:1]):
                    cle = (min(a, b), max(a, b))
                    bords[cle] = bords.get(cle, 0) + 1
    bord = set()
    for (a, b), n in bords.items():
        if n == 1:
            bord.update((av[a], av[b], ar[a], ar[b]))
            try:
                face([av[a], av[b], ar[b], ar[a]], 0)
            except ValueError:
                pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # silhouette sans marches d'escalier : lisse les sommets du bord
    bord = list(bord)
    for _ in range(8):
        bmesh.ops.smooth_vert(bm, verts=bord, factor=0.5, use_axis_x=True, use_axis_y=False, use_axis_z=True)
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT_AVANT)
    me.materials.append(MAT_DOS)
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(nom, me)
    scene.collection.objects.link(ob)
    return ob, ordre


corps, pix_corps = gonfler(IDENT + "_corps", d["m_corps"], d["z_corps"])
bras_g, pix_bg = gonfler(IDENT + "_bras.L", d["m_bras_g"], d["z_bras_g"])
bras_d, pix_bd = gonfler(IDENT + "_bras.R", d["m_bras_d"], d["z_bras_d"])

# ---------------------------------------------------------------- squelette
arm = bpy.data.armatures.new(IDENT + "_squelette")
rig = bpy.data.objects.new(IDENT + "_squelette", arm)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.edit_bones
mil_h = (P("hanche.L") + P("hanche.R")) / 2
mil_ep = (P("epaule.L") + P("epaule.R")) / 2
cou = vers3d(R["nez"][0], info["cou_y"])
cou.x = mil_ep.x
haut_tete = vers3d(R["nez"][0], np.nonzero(lab.any(1))[0].min())


def os_(nom, a, b, parent=None, connecte=False):
    e = eb.new(nom)
    e.head, e.tail = a, b
    e.align_roll(Vector((0, -1, 0)))
    if parent:
        e.parent = eb[parent]
        e.use_connect = connecte
    return e


os_("racine", Vector((0, 0, 0)), Vector((0, 0.15, 0)))
os_("hanches", mil_h, mil_h.lerp(mil_ep, 0.45), "racine")
os_("torse", mil_h.lerp(mil_ep, 0.45), cou, "hanches", True)
os_("tete", cou, haut_tete, "torse", True)
for c in "LR":
    e, co, p = P("epaule." + c), P("coude." + c), P("poignet." + c)
    os_("bras." + c, e, co, "torse")
    os_("avantbras." + c, co, p + (p - co) * 0.4, "bras." + c, True)
    h, g, ch = P("hanche." + c), P("genou." + c), P("cheville." + c)
    os_("cuisse." + c, h, g, "hanches")
    os_("tibia." + c, g, ch, "cuisse." + c, True)
bpy.ops.object.mode_set(mode="OBJECT")


# ---------------------------------------------------------------- poids
def lisse(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def proj(p, a, b):
    ab = b - a
    return (p - a).dot(ab) / max(ab.length_squared, 1e-9)


def poids_corps(ob, pix):
    groupes = {n: ob.vertex_groups.new(name=n) for n in
               ["hanches", "torse", "tete", "cuisse.L", "tibia.L", "cuisse.R", "tibia.R"]}
    me = ob.data
    bande = 0.05  # m
    for v in me.vertices:
        p = v.co
        x, y = pix_xy[v.index]
        l = lab[min(y, H - 1), min(x, W - 1)]
        w = {}
        if l == TETE or p.z > cou.z + bande:
            t = lisse((p.z - (cou.z - bande)) / (2 * bande))
            w = {"tete": t, "torse": 1 - t}
        elif l in (JAMBE_G, JAMBE_D):
            c = "L" if l == JAMBE_G else "R"
            g = P("genou." + c)
            tk = lisse((g.z + bande - p.z) / (2 * bande))  # 1 sous le genou
            th = lisse((mil_h.z + bande - p.z) / (2 * bande))  # 1 sous la hanche
            w = {"tibia." + c: tk, "cuisse." + c: (1 - tk) * th, "hanches": (1 - th)}
        else:
            t = lisse((p.z - mil_h.z) / max(mil_ep.z - mil_h.z, 1e-3))
            w = {"torse": t, "hanches": 1 - t}
            if p.z < mil_h.z:  # bas du manteau : suit un peu les jambes
                c = "L" if p.x > 0 else "R"
                s = lisse((mil_h.z - p.z) / 0.25) * 0.5
                w = {"hanches": 1 - s, "cuisse." + c: s}
        for n, val in w.items():
            if val > 0.001:
                groupes[n].add([v.index], val, "REPLACE")


def poids_bras(ob, c):
    gb = ob.vertex_groups.new(name="bras." + c)
    ga = ob.vertex_groups.new(name="avantbras." + c)
    e, co = P("epaule." + c), P("coude." + c)
    for v in ob.data.vertices:
        t = proj(v.co, e, co)
        a = lisse((t - 0.85) / 0.3)
        ga.add([v.index], a, "REPLACE")
        gb.add([v.index], 1 - a, "REPLACE")


pix_xy = pix_corps  # bmesh.to_mesh garde l'ordre de création des sommets
poids_corps(corps, pix_corps)
poids_bras(bras_g, "L")
poids_bras(bras_d, "R")

for ob in (corps, bras_g, bras_d):
    ob.parent = rig
    mod = ob.modifiers.new("squelette", "ARMATURE")
    mod.object = rig

# ---------------------------------------------------------------- animations
rig.rotation_mode = "XYZ"
pb = rig.pose.bones
for b in pb:
    b.rotation_mode = "QUATERNION"
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def rot(nom, *rotations):
    """Rotations exprimées dans les axes du monde (repos) : (axe, angle)..."""
    b = pb[nom]
    M = b.bone.matrix_local.to_3x3()
    R_ = Matrix.Identity(3)
    for axe, ang in rotations:
        R_ = Matrix.Rotation(ang, 3, axe) @ R_
    b.rotation_quaternion = (M.inverted() @ R_ @ M).to_quaternion()


def lever(dz=0.0, dy=0.0):
    b = pb["racine"]
    M = b.bone.matrix_local.to_3x3()
    b.location = M.inverted() @ Vector((0, dy, dz))


def repos():
    for b in pb:
        b.rotation_quaternion = Quaternion()
        b.location = Vector()


def cle(f):
    for b in pb:
        b.keyframe_insert("rotation_quaternion", frame=f)
        b.keyframe_insert("location", frame=f)


rig.animation_data_create()
actions = []


def nouvelle(nom):
    a = bpy.data.actions.new(nom)
    a.use_fake_user = True
    rig.animation_data.action = a
    actions.append(a)
    return a


GAUCHE = {"L": 1, "R": -1}

# attente : respiration, léger balancement (2 s en boucle)
nouvelle("attente")
for f, s in ((1, 0), (13, 1), (25, 0), (37, -1), (49, 0)):
    repos()
    rot("torse", (X, 0.03 * abs(s) - 0.01), (Y, 0.025 * s))
    rot("tete", (Y, -0.04 * s), (X, -0.02 * abs(s)))
    for c in "LR":
        rot("bras." + c, (Y, -GAUCHE[c] * (0.06 + 0.02 * abs(s))), (X, -0.04 * s * GAUCHE[c]))
        rot("avantbras." + c, (X, -0.12))
    lever(0.004 * abs(s))
    cle(f)

# course : 16 images en boucle
nouvelle("course")
for f in range(1, 18, 2):
    ph = (f - 1) / 16 * 2 * math.pi
    s = math.sin(ph)
    repos()
    lever(0.035 * abs(math.cos(ph)))
    rot("hanches", (Z, 0.18 * s), (X, 0.12))
    rot("torse", (X, 0.15), (Z, -0.25 * s))
    rot("tete", (X, -0.2))
    for c, sg in (("L", 1), ("R", -1)):
        a = s * sg
        rot("cuisse." + c, (X, -0.75 * a))
        rot("tibia." + c, (X, 0.35 + 0.9 * max(a, 0) if False else 0.35 + 0.95 * lisse((a + 0.2) / 1.2)))
        rot("bras." + c, (X, 0.8 * a), (Y, -GAUCHE[c] * 0.15))
        rot("avantbras." + c, (X, -1.3))
    cle(f)

# lancer : bras droit armé derrière la tête puis projeté vers l'avant (0,75 s)
nouvelle("lancer")
etapes = [  # image, bras droit X, coude, torse Z, torse X, bras gauche X, cuisse gauche
    (1, 0, -0.1, 0, 0, 0, 0),
    (6, -2.6, -1.7, 0.45, -0.12, -0.9, -0.15),
    (9, -2.75, -1.9, 0.5, -0.15, -1.0, -0.4),
    (12, -1.6, -0.1, -0.35, 0.25, 0.4, -0.5),
    (14, -0.9, -0.2, -0.45, 0.3, 0.6, -0.5),
    (18, 0, -0.1, 0, 0, 0, 0),
]
for f, br, co, tz, tx, bg, cg in etapes:
    repos()
    rot("bras.R", (X, br), (Y, 0.2 if br < -2 else 0.0))
    rot("avantbras.R", (X, co))
    rot("torse", (Z, tz), (X, tx))
    rot("bras.L", (X, bg), (Y, -0.2))
    rot("cuisse.L", (X, cg))
    rot("tibia.L", (X, -cg * 0.6))
    rot("cuisse.R", (X, -cg * 0.4))
    cle(f)

# victoire : saute, bras en V, poings qui battent (1 s en boucle)
nouvelle("victoire")
for f, z, b, coude, accroupi in ((1, 0, 2.5, -0.5, 0.25), (7, 0.16, 2.8, -0.1, 0),
                                  (13, 0.2, 2.7, -0.4, 0.35), (19, 0.04, 2.6, -0.2, 0.1),
                                  (25, 0, 2.5, -0.5, 0.25)):
    repos()
    lever(z - accroupi * 0.05)
    for c in "LR":
        rot("bras." + c, (Y, -GAUCHE[c] * b), (X, -0.2))
        rot("avantbras." + c, (X, coude))
        rot("cuisse." + c, (X, -accroupi * 1.2))
        rot("tibia." + c, (X, accroupi * 2.0))
    rot("hanches", (X, accroupi * 0.6))
    rot("tete", (X, -0.25))
    cle(f)

# dépit : tête basse, épaules tombantes, hoche la tête (2 s, reste baissé)
nouvelle("depit")
for f, tete, torse, non in ((1, 0, 0, 0), (10, 0.45, 0.3, 0), (18, 0.5, 0.33, 0.25),
                            (26, 0.5, 0.33, -0.25), (34, 0.5, 0.33, 0.18), (48, 0.5, 0.35, 0)):
    repos()
    lever(-0.03 * (torse / 0.35))
    rot("torse", (X, torse))
    rot("tete", (X, tete), (Z, non))
    for c in "LR":
        rot("bras." + c, (X, -0.25 * torse / 0.35), (Y, GAUCHE[c] * 0.05))
        rot("avantbras." + c, (X, -0.2))
        rot("cuisse." + c, (X, -0.1 * torse / 0.35))
        rot("tibia." + c, (X, 0.2 * torse / 0.35))
    cle(f)

# interpolation adoucie, boucles sans à-coup
for a in actions:
    for fc in getattr(a, "fcurves", []):
        for k in fc.keyframe_points:
            k.interpolation = "BEZIER"

rig.animation_data.action = bpy.data.actions["attente"]
for a in actions:  # une piste NLA par action pour l'export
    t = rig.animation_data.nla_tracks.new()
    t.name = a.name
    t.strips.new(a.name, 1, a)
    t.mute = True

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SORTIE, IDENT + ".blend"))
bpy.ops.object.select_all(action="DESELECT")
for ob in (rig, corps, bras_g, bras_d):
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(SORTIE, IDENT + ".glb"), use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_image_format="WEBP", export_image_quality=85)
print("FINI", IDENT, len(corps.data.polygons) + len(bras_g.data.polygons) + len(bras_d.data.polygons), "faces")
