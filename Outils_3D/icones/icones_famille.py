"""
Icônes d'inventaire (256 × 256, fond transparent) des objets famille, modélisées et rendues dans Blender (Cycles).
  preservatif.png · pilule_contraceptive.png · implant_contraceptif.png · test_grossesse.png
Lancement : python3 icones_famille.py <dossier_sortie>
"""
import math
import os
import sys

import bpy
import bmesh
import mathutils

OUT = os.path.abspath(sys.argv[-1] if len(sys.argv) > 1 else '.')


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 64
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 256
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new('w')
    sc.world = w
    if bpy.app.version < (5, 0, 0):
        w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = (1, 1, 1, 1)
    w.node_tree.nodes['Background'].inputs[1].default_value = 0.55
    for rot, energy in (((math.radians(40), math.radians(10), math.radians(-35)), 3.2), ((math.radians(70), 0, math.radians(140)), 1.2)):
        ld = bpy.data.lights.new('l', 'SUN')
        ld.energy = energy
        ld.angle = math.radians(12)
        lo = bpy.data.objects.new('l', ld)
        lo.rotation_euler = rot
        sc.collection.objects.link(lo)
    cam = bpy.data.cameras.new('c')
    cam.type = 'ORTHO'
    co = bpy.data.objects.new('c', cam)
    sc.collection.objects.link(co)
    sc.camera = co
    return sc, co


def mat(name, color, rough=0.4, metal=0.0, alpha=1.0, emission=None):
    m = bpy.data.materials.new(name)
    if bpy.app.version < (5, 0, 0):
        m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if alpha < 1:
        b.inputs['Alpha'].default_value = alpha
    if emission:
        b.inputs['Emission Color'].default_value = (*emission, 1)
        b.inputs['Emission Strength'].default_value = 1.0
    return m


def add(obj, m):
    obj.data.materials.append(m)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def cube(size, loc, m, bevel=0.0, seg=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        md = o.modifiers.new('b', 'BEVEL')
        md.width = bevel
        md.segments = seg
    return add(o, m)


def shoot(co, name, target=(0, 0, 0), direction=(0.35, -0.55, 1.0), scale=2.4):
    d = mathutils.Vector(direction).normalized()
    co.location = mathutils.Vector(target) + d * 10
    co.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    co.data.ortho_scale = scale
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(OUT, name + '.png')
    bpy.ops.render.render(write_still=True)


# ── Préservatif : sachet carré en aluminium, bords dentelés, anneau en relief ──
sc, co = reset()
foil = mat('foil', (0.62, 0.12, 0.30), rough=0.3, metal=0.6)
cube((1.9, 1.9, 0.06), (0, 0, 0), foil, bevel=0.08, seg=4)
# bord serti (dents) : petites arêtes autour du sachet
crimp = mat('sertissage', (0.5, 0.09, 0.24), rough=0.4, metal=0.6)
for k in range(15):
    t = -0.84 + k * 0.12
    for x, y in ((t, -0.9), (t, 0.9), (-0.9, t), (0.9, t)):
        cube((0.05, 0.05, 0.07), (x, y, 0.0), crimp)
bpy.ops.mesh.primitive_torus_add(major_radius=0.48, minor_radius=0.07, location=(0, 0, 0.05))
add(bpy.context.active_object, mat('anneau', (0.75, 0.2, 0.42), rough=0.2, metal=0.8))
bpy.ops.mesh.primitive_cylinder_add(radius=0.42, depth=0.02, location=(0, 0, 0.045))
add(bpy.context.active_object, mat('centre', (0.55, 0.1, 0.27), rough=0.3, metal=0.85))
shoot(co, 'preservatif', direction=(0.25, -0.45, 1.0), scale=3.0)

# ── Pilule : plaquette avec alvéoles et comprimés ──
sc, co = reset()
cube((2.0, 1.25, 0.04), (0, 0, 0), mat('alu', (0.82, 0.84, 0.88), rough=0.3, metal=0.9), bevel=0.03)
dome = mat('dome', (0.9, 0.93, 0.98), rough=0.05, alpha=0.35)
pill = mat('pilule', (0.98, 0.72, 0.80), rough=0.35)
for i in range(4):
    for j in range(2):
        x, y = -0.72 + i * 0.48, -0.28 + j * 0.56
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.19, location=(x, y, 0.02), segments=32, ring_count=16)
        s = bpy.context.active_object
        s.scale = (1, 1, 0.55)
        add(s, dome)
        if not (i == 3 and j == 1):
            bpy.ops.mesh.primitive_cylinder_add(radius=0.13, depth=0.07, location=(x, y, 0.06), vertices=32)
            c = bpy.context.active_object
            md = c.modifiers.new('b', 'BEVEL')
            md.width = 0.03
            md.segments = 4
            add(c, pill)
shoot(co, 'pilule_contraceptive', direction=(0.3, -0.6, 1.0), scale=2.6)

# ── Implant : bâtonnet souple + applicateur ──
sc, co = reset()
bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=1.6, location=(0, 0.25, 0), rotation=(0, math.radians(90), math.radians(-20)), vertices=32)
c = bpy.context.active_object
md = c.modifiers.new('b', 'BEVEL')
md.width = 0.05
md.segments = 5
add(c, mat('implant', (0.95, 0.95, 0.92), rough=0.35))
cube((1.5, 0.28, 0.2), (0.05, -0.35, 0), mat('applicateur', (0.25, 0.55, 0.85), rough=0.35), bevel=0.08, seg=4)
bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=0.7, location=(-1.05, -0.35, 0), rotation=(0, math.radians(90), 0), vertices=24)
add(bpy.context.active_object, mat('aiguille', (0.8, 0.82, 0.85), rough=0.15, metal=1.0))
shoot(co, 'implant_contraceptif', direction=(0.2, -0.5, 1.0), scale=2.5)

# ── Test de grossesse : bâtonnet, fenêtre avec deux traits ──
sc, co = reset()
cube((2.1, 0.42, 0.16), (0, 0, 0), mat('plastique', (0.97, 0.97, 0.98), rough=0.3), bevel=0.12, seg=5)
cube((0.6, 0.4, 0.17), (-0.85, 0, 0.0), mat('capuchon', (0.45, 0.35, 0.8), rough=0.3), bevel=0.1, seg=4)
cube((0.5, 0.18, 0.02), (0.35, 0, 0.08), mat('fenetre', (0.92, 0.94, 0.96), rough=0.1), bevel=0.02)
traits = mat('traits', (0.85, 0.15, 0.35), rough=0.4)
for x in (0.25, 0.45):
    cube((0.035, 0.15, 0.02), (x, 0, 0.09), traits)
shoot(co, 'test_grossesse', direction=(0.15, -0.55, 1.0), scale=2.3)
print('icônes écrites dans', OUT)
