# Mede mãos das skins dos bots no Blender (fonte da verdade da malha): ossos, hierarquia e malha da mão.
import bpy, json, sys
from mathutils import Vector
OUT = r"C:\gemini cli\games\_prints\blender_hands.json"
SKINS = ["t_phoenix", "ct_sas", "ct_urban", "t_leet"]
res = {}
def yup(v): return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]
for skin in SKINS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=r"C:\gemini cli\games\assets\models\mixamo\%s.glb" % skin)
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
    mw = arm.matrix_world
    info = {"arm_scale": list(arm.scale), "bones": {}}
    for b in arm.data.bones:
        if any(k in b.name for k in ["Hand", "Arm", "Shoulder", "Neck", "Head", "Spine"]):
            info["bones"][b.name] = {"parent": b.parent.name if b.parent else None, "head": yup(mw @ b.head_local), "tail": yup(mw @ b.tail_local)}
    for side in ["Right", "Left"]:
        groups = {}
        meshes = [o for o in bpy.data.objects if o.type == 'MESH']
        pts = []
        for o in meshes:
            idx = {g.index: g.name for g in o.vertex_groups}
            for v in o.data.vertices:
                w = 0.0
                for g in v.groups:
                    n = idx.get(g.group, "")
                    if ("%sHand" % side) in n: w += g.weight
                if w > 0.5:
                    pts.append(o.matrix_world @ v.co)
        if pts:
            c = sum(pts, Vector()) / len(pts)
            mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
            mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
            info[side] = {"n": len(pts), "centroid": yup(c), "min": yup(mn), "max": yup(mx)}
        else:
            info[side] = {"n": 0}
    info["groups_sample"] = sorted({g.name for o in bpy.data.objects if o.type == 'MESH' for g in o.vertex_groups if "Hand" in g.name})
    res[skin] = info
json.dump(res, open(OUT, "w"), indent=1)
