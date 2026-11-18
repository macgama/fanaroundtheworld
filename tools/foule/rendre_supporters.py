"""Rend le mannequin Quaternius (Universal Animation Library, CC0) en sprites
de supporter 2D, calque par calque, pour la foule des tribunes.

    VARIANTE=a|b|c python3 foule_rendu.py UAL1_Standard.glb dossier_sortie [geste ...]

(Blender en module Python : pip install bpy. Le .glb vient de
https://quaternius.itch.io/universal-animation-library, version Standard, CC0.)
Variantes : a cheveux courts bruns, b cheveux longs blonds, c bonnet du club.

Calques rendus pour chaque image :
  base     : supporter complet aux couleurs par défaut (contour, jean, baskets, cheveux)
  peau     : la peau seule, en niveaux de gris (teintée par le jeu)
  maillot  : le maillot seul + les rayures de l'écharpe (teinté couleur 1)
  echarpe  : l'écharpe seule (teintée couleur 2)
Les autres calques sont « holdout » : ils masquent ce qui est derrière eux,
donc chaque calque est déjà découpé à la bonne forme.
"""
import bpy, sys, math, os, json
from mathutils import Vector, Matrix, Quaternion

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
GLB, SORTIE = ARGS[0], ARGS[1]
SEULS = ARGS[2:]
L_IMG, H_IMG = 96, 128  # taille d'une image de sprite
os.makedirs(SORTIE, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
arm = bpy.data.objects["Armature"]
me = bpy.data.objects["Mannequin"]
bpy.data.objects.remove(bpy.data.objects["Icosphere"], do_unlink=True)
sc = bpy.context.scene

# ---------------------------------------------------------------- matériaux
def mat_toon(nom, couleur):
    """Ombrage « cel » : couleur pleine, ombre franche côté opposé à la lumière."""
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = Vector((-0.45, -0.55, 0.7)).normalized()
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.66, 0.66, 0.70, 1)
    ramp.color_ramp.elements[1].position = 0.18
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    nt.links.new(dot.outputs["Value"], ramp.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    mul.inputs[6].default_value = (*couleur, 1)
    nt.links.new(ramp.outputs["Color"], mul.inputs[7])
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(mul.outputs[2], em.inputs[0])
    hold = nt.nodes.new("ShaderNodeHoldout")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = 0.0
    mix.name = "masque"
    nt.links.new(em.outputs[0], mix.inputs[1])
    nt.links.new(hold.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    m["coul"] = list(couleur)
    m["emission"] = em.name
    m["mulnode"] = mul.name
    return m


def mat_contour():
    m = bpy.data.materials.new("contour")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    em = nt.nodes.new("ShaderNodeEmission"); em.inputs[0].default_value = (0.055, 0.04, 0.12, 1)
    hold = nt.nodes.new("ShaderNodeHoldout")
    noir = nt.nodes.new("ShaderNodeMixShader"); noir.name = "masque"; noir.inputs[0].default_value = 0.0
    nt.links.new(em.outputs[0], noir.inputs[1]); nt.links.new(hold.outputs[0], noir.inputs[2])
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(noir.outputs[0], mix.inputs[1])  # face avant de la coque = trait
    nt.links.new(tr.outputs[0], mix.inputs[2])    # face arrière = transparente
    nt.links.new(mix.outputs[0], out.inputs[0])
    return m

COUL = {
    "peau": (0.95, 0.76, 0.6),
    "maillot": (0.85, 0.85, 0.88),
    "jean": (0.16, 0.2, 0.42),
    "basket": (0.95, 0.95, 0.95),
    "cheveux": (0.2, 0.12, 0.08),
    "yeux": (0.06, 0.05, 0.1),
    "echarpe": (0.85, 0.85, 0.88),
    "rayure": (0.85, 0.85, 0.88),
}
MATS = {k: mat_toon(k, v) for k, v in COUL.items()}
CONTOUR = mat_contour()
# calque -> matériaux qui y sont visibles (tous les autres en holdout)
CALQUES = {
    "base": None,
    "peau": ["peau"],
    "maillot": ["maillot", "rayure"],
    "echarpe": ["echarpe"],
}
# pour les calques teintés, matière blanche (le jeu multiplie par la couleur)
BLANC = (1.0, 1.0, 1.0)

# ------------------------------------------- découpe du mannequin par os
ZONE = {}
for b in arm.data.bones:
    n = b.name
    if n.startswith(("spine", "clavicle", "upperarm")):
        ZONE[n] = "maillot"
    elif n.startswith(("pelvis", "thigh", "calf")):
        ZONE[n] = "jean"
    elif n.startswith(("foot", "ball")):
        ZONE[n] = "basket"
    else:  # tête, cou, avant-bras, mains, doigts
        ZONE[n] = "peau"
noms_vg = [vg.name for vg in me.vertex_groups]
mesh = me.data
mesh.materials.clear()
ordre = ["peau", "maillot", "jean", "basket"]
for k in ordre:
    mesh.materials.append(MATS[k])
mesh.materials.append(CONTOUR)
zone_v = []
for v in mesh.vertices:
    poids = {}
    for g in v.groups:
        z = ZONE.get(noms_vg[g.group], "peau")
        poids[z] = poids.get(z, 0) + g.weight
    zone_v.append(max(poids, key=poids.get) if poids else "peau")
# le maillot descend un peu sur le bassin (le haut du jean redevient maillot)
for p in mesh.polygons:
    zs = [zone_v[i] for i in p.vertices]
    z = max(set(zs), key=zs.count)
    c = me.matrix_world @ p.center
    if z == "jean" and c.z > 0.98:
        z = "maillot"
    if z == "peau" and c.z < 1.45 and abs(c.x) < 0.25:  # le cou reste peau, pas le torse
        z = "maillot"
    p.material_index = ordre.index(z)


def contour(obj, ep=0.022):
    s = obj.modifiers.new("contour", "SOLIDIFY")
    s.thickness = ep
    s.offset = 1.0
    s.use_flip_normals = True
    s.use_rim = False
    s.material_offset = len(obj.data.materials)
    obj.data.materials.append(CONTOUR)

# contour du mannequin : déjà le slot CONTOUR en dernier, décalage = 4
s = me.modifiers.new("contour", "SOLIDIFY")
s.thickness = 0.03; s.offset = 1.0; s.use_flip_normals = True; s.use_rim = False
s.material_offset = 4
vg = me.vertex_groups.new(name="epaisseur_contour")
for v in mesh.vertices:
    mains = any(noms_vg[g.group].startswith(("hand", "index", "middle", "ring", "pinky", "thumb")) and g.weight > 0.5 for g in v.groups)
    vg.add([v.index], 0.0 if mains else 1.0, "REPLACE")
s.vertex_group = "epaisseur_contour"
s.thickness_vertex_group = 0.25

# ------------------------------------------------ cheveux, yeux (sur la tête)
tete = [me.matrix_world @ v.co for v, z in zip(mesh.vertices, zone_v) if z == "peau" and (me.matrix_world @ v.co).z > 1.6]
cx = sum(p.x for p in tete) / len(tete); cy = sum(p.y for p in tete) / len(tete)
zmin = min(p.z for p in tete); zmax = max(p.z for p in tete)
ymin = min(p.y for p in tete); ymax = max(p.y for p in tete)
xmax = max(p.x for p in tete)
cz = (zmin + zmax) / 2
print("tête", cx, cy, cz, zmin, zmax, ymin, ymax, xmax)


def attacher_os(obj, os_nom):
    bpy.context.view_layer.update()
    mw = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = os_nom
    bpy.context.view_layer.update()
    obj.matrix_world = mw

VARIANTE = os.environ.get("VARIANTE", "a")
rx = xmax - cx; ry = (ymax - ymin) / 2; rz = (zmax - zmin) / 2


def ellipsoide(nom, echelle, pos, mat, ep=0.02, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1)
    o = bpy.context.object
    o.name = nom
    o.scale = echelle
    o.location = pos
    o.rotation_euler = rot
    o.data.materials.append(MATS[mat])
    bpy.ops.object.shade_flat()
    contour(o, ep)
    attacher_os(o, "Head")
    return o

if VARIANTE == "a":    # cheveux courts bruns
    ellipsoide("cheveux", (rx * 1.12, ry * 1.12, rz * 0.62), (cx, cy + ry * 0.12, cz + rz * 0.5), "cheveux")
elif VARIANTE == "b":  # cheveux longs blonds
    MATS["cheveux"]["coul"] = [0.93, 0.72, 0.32]
    ellipsoide("cheveux", (rx * 1.18, ry * 1.18, rz * 0.7), (cx, cy + ry * 0.14, cz + rz * 0.45), "cheveux")
    ellipsoide("nuque", (rx * 1.1, ry * 0.55, rz * 1.05), (cx, cy + ry * 0.75, cz - rz * 0.55), "cheveux")
else:                  # bonnet aux couleurs du club (+ pompon couleur 2)
    ellipsoide("bonnet", (rx * 1.16, ry * 1.16, rz * 0.72), (cx, cy + ry * 0.08, cz + rz * 0.42), "rayure")
    ellipsoide("pompon", (rx * 0.32, rx * 0.32, rx * 0.32), (cx, cy + ry * 0.08, cz + rz * 1.18), "echarpe")

yeux = []
for sx in (-1, 1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=1)
    o = bpy.context.object
    o.scale = (rx * 0.16, ry * 0.08, rz * 0.22)
    o.location = (cx + sx * rx * 0.38, ymin + ry * 0.12, cz + rz * 0.1)
    o.data.materials.append(MATS["yeux"])
    attacher_os(o, "Head")
    yeux.append(o)

# ----------------------------------------------------------------- écharpe
def faire_echarpe():
    """Une bande de 12 segments (rayures alternées) qu'on tend entre les mains."""
    n = 12
    verts, faces, mats = [], [], []
    for i in range(n + 1):
        t = i / n
        verts += [(t, 0, -0.5), (t, 0, 0.5), (t, 0.25, -0.5), (t, 0.25, 0.5)]
    for i in range(n):
        a = i * 4; b = a + 4
        faces += [(a, b, b + 1, a + 1), (a + 2, a + 3, b + 3, b + 2), (a, a + 2, b + 2, b), (a + 1, b + 1, b + 3, a + 3)]
        m = 1 if (i // 2) % 2 else 0
        mats += [m] * 4
    faces += [(0, 1, 3, 2), (n * 4, n * 4 + 2, n * 4 + 3, n * 4 + 1)]
    mats += [0, 0]
    md = bpy.data.meshes.new("echarpe")
    md.from_pydata(verts, [], faces)
    md.materials.append(MATS["echarpe"])
    md.materials.append(MATS["rayure"])
    for p, m in zip(md.polygons, mats):
        p.material_index = m
    o = bpy.data.objects.new("echarpe", md)
    sc.collection.objects.link(o)
    contour(o, 0.018)
    return o

echarpe = faire_echarpe()
echarpe.hide_render = True


def placer_echarpe(pg, pd, creux=0.12):
    """Tend l'écharpe d'une main à l'autre, avec un léger creux au milieu."""
    md = echarpe.data
    n = 12
    larg, ep = 0.16, 0.025
    for i in range(n + 1):
        t = i / n
        p = pd.lerp(pg, t)
        p.z -= math.sin(math.pi * t) * creux
        for j, (dy, dz) in enumerate([(0, -larg / 2), (0, larg / 2), (ep, -larg / 2), (ep, larg / 2)]):
            md.vertices[i * 4 + j].co = p + Vector((0, -0.06 + dy, dz))
    md.update()
    echarpe.hide_render = False

# ------------------------------------------------------------- pose directe
REPOS = {}


def pose_de(action, frame):
    """Lit la pose d'une animation Quaternius (rotations locales des os)."""
    arm.animation_data_create()
    arm.animation_data.action = bpy.data.actions[action]
    sc.frame_set(int(frame))
    sc.frame_subframe = frame - int(frame)
    bpy.context.view_layer.update()
    p = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in arm.pose.bones}
    arm.animation_data.action = None
    return p


def appliquer(p):
    for pb in arm.pose.bones:
        loc, rot = p[pb.name]
        pb.location = loc
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = rot
    bpy.context.view_layer.update()


def viser(nom, direction):
    """Oriente un os (axe Y = sa longueur) vers une direction de l'armature."""
    pb = arm.pose.bones[nom]
    d = Vector(direction).normalized()
    m = pb.matrix.copy()
    y = m.to_3x3() @ Vector((0, 1, 0))
    q = y.rotation_difference(d)
    nm = Matrix.Translation(m.translation) @ q.to_matrix().to_4x4() @ m.to_3x3().to_4x4()
    pb.matrix = nm
    bpy.context.view_layer.update()


def tourner(nom, axe, angle):
    """Rotation d'un os autour d'un axe de l'armature (degrés)."""
    pb = arm.pose.bones[nom]
    m = pb.matrix.copy()
    q = Quaternion(Vector(axe).normalized(), math.radians(angle))
    pb.matrix = Matrix.Translation(m.translation) @ q.to_matrix().to_4x4() @ m.to_3x3().to_4x4()
    bpy.context.view_layer.update()


def bras(cote, haut, bas):
    """cote 1 = bras gauche (x>0), -1 = droit ; directions données pour la gauche."""
    s = "l" if cote > 0 else "r"
    viser("upperarm_" + s, (haut[0] * cote, haut[1], haut[2]))
    viser("lowerarm_" + s, (bas[0] * cote, bas[1], bas[2]))


def bassin(dz=0.0, flex=0.0):
    """Monte/descend le bassin (m) ; flex = flexion des genoux (degrés)."""
    pb = arm.pose.bones["pelvis"]
    m = pb.matrix.copy()
    m.translation.z += dz
    pb.matrix = m
    bpy.context.view_layer.update()
    if flex:
        for s in ("l", "r"):
            tourner("thigh_" + s, (1, 0, 0), -flex)
            tourner("calf_" + s, (1, 0, 0), flex * 1.9)
            tourner("foot_" + s, (1, 0, 0), -flex * 0.9)


def main(s):
    return arm.matrix_world @ arm.pose.bones["hand_" + s].tail


def lisse(t):
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))


def melange(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))

# directions des bras (côté gauche) : (x vers l'extérieur, y vers la caméra (-), z haut)
AVANT = ((0.22, -0.95, 0.15), (0.12, -0.9, 0.45))
BAS = ((0.25, -0.05, -1.0), (0.12, -0.25, -1.0))
V_HAUT = ((0.5, -0.12, 0.86), (0.35, -0.12, 0.93))
DROIT_HAUT = ((0.22, -0.1, 1.0), (0.08, -0.05, 1.0))
CLAP_OUVERT = ((0.35, -0.55, -0.55), (-0.15, -0.95, 0.35))
CLAP_FERME = ((0.25, -0.65, -0.55), (-0.62, -0.75, 0.3))
ECHARPE_H = ((0.62, -0.2, 0.72), (0.12, -0.15, 1.0))
TETE_MAINS = ((0.75, -0.25, 0.55), (-0.55, -0.25, 0.8))


def geste_repos(i, n):
    appliquer(pose_de("Idle_Loop", 60.0 * i / n))


def geste_sauter(i, n):
    # cycle : accroupi -> saut bras en V -> réception
    t = i / n
    appliquer(pose_de("Idle_Loop", 0))
    h = math.sin(math.pi * t)  # 0..1..0 (hauteur gérée par le jeu, ici l'élan)
    flex = 38 * (1 - h) ** 2
    bassin(-0.12 * (1 - h) ** 2, flex)
    a = lisse(h * 1.4)
    for c in (1, -1):
        bras(c, arc(BAS[0], AVANT[0], V_HAUT[0], a), arc(BAS[1], AVANT[1], V_HAUT[1], a))


def geste_applaudir(i, n):
    appliquer(pose_de("Idle_Loop", 20))
    t = 0.5 - 0.5 * math.cos(2 * math.pi * i / n)
    for c in (1, -1):
        bras(c, melange(CLAP_OUVERT[0], CLAP_FERME[0], t), melange(CLAP_OUVERT[1], CLAP_FERME[1], t))
    tourner("spine_02", (1, 0, 0), -4 * t)


def arc(a, m, b, t):
    """Passe par m à mi-chemin (les bras montent par l'avant, pas en croix)."""
    return melange(a, m, t * 2) if t < 0.5 else melange(m, b, t * 2 - 1)


def geste_ola(i, n):
    # une seule vague : on se lève bras au ciel puis on se rassoit
    t = i / (n - 1)
    h = math.sin(math.pi * t) ** 0.8
    appliquer(pose_de("Idle_Loop", 0))
    bassin(0.04 * h - 0.06 * (1 - h), 22 * (1 - h))
    for c in (1, -1):
        bras(c, arc(BAS[0], AVANT[0], DROIT_HAUT[0], h), arc(BAS[1], AVANT[1], DROIT_HAUT[1], h))
    tourner("spine_02", (1, 0, 0), 8 * h)


def geste_echarpe(i, n):
    t = math.sin(2 * math.pi * i / n)
    appliquer(pose_de("Idle_Loop", 0))
    tourner("pelvis", (0, 1, 0), 7 * t)
    tourner("spine_02", (0, 1, 0), 6 * t)
    for c in (1, -1):
        hh = ECHARPE_H[0]
        bras(c, (hh[0], hh[1], hh[2] + 0.08 * t * c), ECHARPE_H[1])
    placer_echarpe(main("l"), main("r"))


def geste_depit(i, n):
    t = 0.5 - 0.5 * math.cos(2 * math.pi * i / n)
    appliquer(pose_de("Idle_Loop", 0))
    tourner("spine_02", (1, 0, 0), -6 - 4 * t)
    tourner("neck_01", (1, 0, 0), -10 * t)
    for c in (1, -1):
        bras(c, TETE_MAINS[0], TETE_MAINS[1])


def geste_danser(i, n):
    appliquer(pose_de("Dance_Loop", 24.0 * i / n))


GESTES = {
    "repos": (geste_repos, 8),
    "sauter": (geste_sauter, 8),
    "applaudir": (geste_applaudir, 6),
    "ola": (geste_ola, 10),
    "echarpe": (geste_echarpe, 8),
    "depit": (geste_depit, 6),
    "danser": (geste_danser, 8),
}

# ------------------------------------------------------------ caméra, rendu
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 2.55
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam
elev = math.radians(10)
cible = Vector((0, 0, 1.12))
cam.location = cible + Vector((0, -math.cos(elev), math.sin(elev))) * 10
cam.rotation_euler = (math.pi / 2 - elev, 0, 0)
sc.render.engine = "CYCLES"
sc.cycles.samples = 24
sc.cycles.use_denoising = False
sc.cycles.max_bounces = 2
sc.cycles.transparent_max_bounces = 8
sc.render.film_transparent = True
sc.render.resolution_x = L_IMG * 2
sc.render.resolution_y = H_IMG * 2
sc.render.resolution_percentage = 50
sc.render.filter_size = 1.2
sc.view_settings.view_transform = "Standard"
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.render.threads_mode = "AUTO"
sc.world = bpy.data.worlds.new("monde")
sc.world.color = (0, 0, 0)


def regler_calque(nom):
    vis = CALQUES[nom]
    for k, m in MATS.items():
        nt = m.node_tree
        masque = vis is not None and k not in vis
        nt.nodes["masque"].inputs[0].default_value = 1.0 if masque else 0.0
        coul = BLANC if (vis is not None and k in vis) else tuple(m["coul"])
        nt.nodes[m["mulnode"]].inputs[6].default_value = (*coul, 1)
    CONTOUR.node_tree.nodes["masque"].inputs[0].default_value = 0.0 if vis is None else 1.0


infos = {}
for nom, (fn, n) in GESTES.items():
    if SEULS and nom not in SEULS:
        continue
    for i in range(n):
        echarpe.hide_render = True
        fn(i, n)
        for cal in CALQUES:
            if cal == "echarpe" and echarpe.hide_render:
                continue
            regler_calque(cal)
            sc.render.filepath = os.path.join(SORTIE, f"{nom}_{i:02d}_{cal}.png")
            bpy.ops.render.render(write_still=True)
    infos[nom] = n
    print("geste", nom, n)
with open(os.path.join(SORTIE, "gestes.json"), "w") as f:
    json.dump({"images": infos, "taille": [L_IMG, H_IMG]}, f)
