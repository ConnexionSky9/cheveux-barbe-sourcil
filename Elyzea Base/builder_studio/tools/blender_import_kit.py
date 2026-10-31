"""Builder Studio - importe tous les OBJ du kit dans Blender (3.3 ou plus récent).
   Blender > Scripting > ouvrir ce fichier > modifier KIT_DIR > Exécuter.
   Chaque OBJ devient un objet nommé comme le modèle (ubk_w4_beton…), prêt à être
   converti en Drawable + collision avec Sollumz, puis exporté en .ydr / .ybn."""
import os
import bpy

KIT_DIR = r"C:\chemin\vers\kit\source\obj"   # dossier produit par tools/kit_generator.js
MATERIALS = None                               # ex. {"beton", "brique"} pour n'importer que ceux-là

for name in sorted(os.listdir(KIT_DIR)):
    if not name.endswith(".obj"):
        continue
    if MATERIALS and not any(name[:-4].endswith("_" + m) for m in MATERIALS):
        continue
    before = set(bpy.data.objects)
    if hasattr(bpy.ops.wm, "obj_import"):
        bpy.ops.wm.obj_import(filepath=os.path.join(KIT_DIR, name))
    else:  # anciennes versions
        bpy.ops.import_scene.obj(filepath=os.path.join(KIT_DIR, name))
    for obj in set(bpy.data.objects) - before:
        obj.name = name[:-4]
print("Import terminé")
