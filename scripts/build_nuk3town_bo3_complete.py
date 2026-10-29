import bpy
import json
import os
import sys
import time

t0 = time.time()
print("==========================================================", flush=True)
print("  BATCH-CONSOLIDATING NUK3TOWN BO3 MAP TO HIGH QUALITY GLB", flush=True)
print("==========================================================", flush=True)

BLEND_PATH = os.path.abspath(r"assets/models/nuk3town_bo3/Nuketown (BO3) Futuristic/Nuketown (BO3).blend")
JSON_PATH = os.path.abspath(r"assets/models/nuk3town_bo3/Nuketown (BO3) Futuristic/exported_files/exported_maps/black_ops_3/mp_nuketown_x_mats.json")
IMG_DIR = os.path.abspath(r"assets/models/nuk3town_bo3/Nuketown (BO3) Futuristic/exported_files/exported_images/black_ops_3")
OUTPUT_GLB = os.path.abspath(r"assets/models/nuk3town_bo3/nuk3town_bo3.glb")

# 1. Unhide all layer collections
def unhide_layer_col(lc):
    lc.exclude = False
    lc.hide_viewport = False
    for child in lc.children:
        unhide_layer_col(child)

unhide_layer_col(bpy.context.view_layer.layer_collection)
print(f"[{time.time()-t0:.1f}s] Layer collections unhidden.", flush=True)

# 2. Realize collection instances in Model Instances
mod_inst = bpy.data.collections.get('Model Instances')
if mod_inst and len(mod_inst.objects) > 0:
    print(f"[{time.time()-t0:.1f}s] Realizing {len(mod_inst.objects)} instances in Model Instances...", flush=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in mod_inst.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mod_inst.objects[0]
    bpy.ops.object.duplicates_make_real()
    print(f"[{time.time()-t0:.1f}s] Duplicates made real!", flush=True)

# 3. Remove prototype collection at origin (XModels) so we don't have duplicate props sitting at 0,0,0
xmodels_col = bpy.data.collections.get('XModels [DO NOT DELETE]')
if xmodels_col:
    def remove_col_recursive(col):
        for child in list(col.children):
            remove_col_recursive(child)
        for obj in list(col.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(col)
    remove_col_recursive(xmodels_col)
    print(f"[{time.time()-t0:.1f}s] Cleaned up prototype library at origin.", flush=True)

# 4. Remove empties, cameras, lights
for obj in list(bpy.data.objects):
    if obj.type in ['CAMERA', 'LIGHT', 'EMPTY']:
        bpy.data.objects.remove(obj, do_unlink=True)

# 5. Filter micro-trash, distant vistas, and micro-foliage
EXCLUDE_KEYWORDS = [
    # micro trash
    "fork", "spoon", "knife", "pencil", "pen", "stapler", "tape_measure", "screwdriver", "socket", "wrench",
    "paper_towel", "butter_lettuce", "kale", "spinach", "watercress", "banana", "peach", "pear", "cucumber",
    "bottle", "bucket", "plate", "cup", "mug", "dish", "bowl", "jar", "candle", "sponge", "soap",
    "hanger", "dustpan", "small_toy", "plush", "blanket", "pill", "tablet_reader", "photo_frame", "dinnerware",
    # micro foliage (individual tomato leaves, weeds, grass blades, petals, stems that cause OOM)
    "tomato", "grass_tall", "leaf", "leaves", "flower", "stem", "watercress", "plant_hydro", "meskel", "bougainvillea"
]

removed_trash = 0
removed_vista = 0
kept_meshes = []

for obj in list(bpy.data.objects):
    if obj.type == 'MESH':
        nl = obj.name.lower()
        if any(k in nl for k in EXCLUDE_KEYWORDS):
            bpy.data.objects.remove(obj, do_unlink=True)
            removed_trash += 1
            continue
            
        loc = obj.location
        if abs(loc.x) > 95 or abs(loc.y) > 95 or "vista" in nl or "skyscraper" in nl or "sky1" in nl:
            bpy.data.objects.remove(obj, do_unlink=True)
            removed_vista += 1
            continue
            
        dim = obj.dimensions
        if max(dim.x, dim.y, dim.z) < 0.20 and "mapgeometry" not in nl:
            bpy.data.objects.remove(obj, do_unlink=True)
            removed_trash += 1
            continue
            
        kept_meshes.append(obj)

print(f"[{time.time()-t0:.1f}s] Filtered: removed {removed_trash} micro-items, {removed_vista} distant vistas. Surviving: {len(kept_meshes)} meshes.", flush=True)

# 6. Categorize surviving meshes
CATEGORIES = {
    "BO3_MapGeometry": [],
    "BO3_HouseBlue_Exterior": [],
    "BO3_HouseBlue_Interior": [],
    "BO3_HouseOrange_Exterior": [],
    "BO3_HouseOrange_Interior": [],
    "BO3_Vehicles": [],
    "BO3_GreenHouses": [],
    "BO3_Fences_Barriers": [],
    "BO3_StreetProps": [],
    "BO3_CoverCrates": [],
    "BO3_Trees_Foliage": [],
    "BO3_Furniture": [],
    "BO3_Decorations": [],
    "BO3_Glass": [],
    "BO3_Floors_Paths": [],
    "BO3_Panels_Walls": [],
    "BO3_MiscStructures": []
}

for obj in kept_meshes:
    nl = obj.name.lower()
    
    if "glass" in nl or "frosted" in nl:
        CATEGORIES["BO3_Glass"].append(obj)
    elif "supercar" in nl or "hover_train" in nl or "civ_car" in nl or "van" in nl or "car_platform" in nl:
        CATEGORIES["BO3_Vehicles"].append(obj)
    elif ("tree" in nl or "bush" in nl or "foliage" in nl or "plant" in nl) and not any(k in nl for k in ["leaf", "grass", "tomato", "flower", "stem"]):
        CATEGORIES["BO3_Trees_Foliage"].append(obj)
    elif "greenhouse" in nl or "planter_greenhouse" in nl:
        CATEGORIES["BO3_GreenHouses"].append(obj)
    elif "blue_house" in nl or "blue_garage" in nl or "blue_exterior" in nl or "blue_bldg" in nl or "bluehouse" in nl:
        if "chair" in nl or "desk" in nl or "bed" in nl or "couch" in nl or "rug" in nl or "shelf" in nl:
            CATEGORIES["BO3_HouseBlue_Interior"].append(obj)
        else:
            CATEGORIES["BO3_HouseBlue_Exterior"].append(obj)
    elif "orange_house" in nl or "orange_garage" in nl or "office_orange" in nl or "orange_exterior" in nl or "orange_bldg" in nl or "orangehouse" in nl:
        if "chair" in nl or "desk" in nl or "bed" in nl or "couch" in nl or "rug" in nl or "shelf" in nl or "oven" in nl or "refrigerator" in nl:
            CATEGORIES["BO3_HouseOrange_Interior"].append(obj)
        else:
            CATEGORIES["BO3_HouseOrange_Exterior"].append(obj)
    elif "fence" in nl or "gate" in nl or "barrier" in nl or "curb" in nl:
        CATEGORIES["BO3_Fences_Barriers"].append(obj)
    elif "mapgeometry" in nl or "road" in nl or "terrain" in nl or "sidewalk" in nl or "ground" in nl:
        CATEGORIES["BO3_MapGeometry"].append(obj)
    elif "mannequin" in nl or "billboard" in nl or "welcome_sign" in nl or "bench" in nl or "robot" in nl or "flag" in nl or "bomb" in nl or "light_lamp" in nl or "mailbox" in nl:
        CATEGORIES["BO3_StreetProps"].append(obj)
    elif "cover_crates" in nl or "crates" in nl or "barrel" in nl:
        CATEGORIES["BO3_CoverCrates"].append(obj)
    elif "bed" in nl or "couch" in nl or "chair" in nl or "table" in nl or "desk" in nl or "sink" in nl or "stove" in nl or "cabinet" in nl or "tv" in nl or "counter" in nl:
        CATEGORIES["BO3_Furniture"].append(obj)
    elif "mural" in nl or "rug" in nl or "poster" in nl or "signage" in nl or "art" in nl or "display" in nl or "monitor" in nl or "decal" in nl:
        CATEGORIES["BO3_Decorations"].append(obj)
    elif "floor" in nl or "stone_path" in nl or "grating" in nl or "granite" in nl:
        CATEGORIES["BO3_Floors_Paths"].append(obj)
    elif "ceramic" in nl or "panel" in nl or "metal" in nl or "plastic_base" in nl:
        CATEGORIES["BO3_Panels_Walls"].append(obj)
    else:
        CATEGORIES["BO3_MiscStructures"].append(obj)

for k, v in CATEGORIES.items():
    print(f"  Category {k}: {len(v)} objects", flush=True)

# 7. Make single-user so transforms can be applied without multi-user errors
print(f"[{time.time()-t0:.1f}s] Making mesh data single-user...", flush=True)
bpy.ops.object.select_all(action='DESELECT')
for o in kept_meshes:
    o.select_set(True)
if kept_meshes:
    bpy.context.view_layer.objects.active = kept_meshes[0]
    bpy.ops.object.make_single_user(object=True, obdata=True, material=False, animation=False)

# 8. Join each category in safe batches
# For trees and vehicles, batch size is small (10-20) because they have higher poly count
# For buildings and panels, batch size is 60
joined_objects = []

for cat_name, objs in CATEGORIES.items():
    if not objs:
        continue
    
    max_b = 15 if "Trees" in cat_name else (30 if "Vehicles" in cat_name else 60)
    batches = [objs[i:i + max_b] for i in range(0, len(objs), max_b)]
    print(f"[{time.time()-t0:.1f}s] Joining '{cat_name}' ({len(objs)} objects in {len(batches)} batches)...", flush=True)
    
    for b_idx, batch in enumerate(batches):
        batch_name = cat_name if len(batches) == 1 else f"{cat_name}_{b_idx+1}"
        
        bpy.ops.object.select_all(action='DESELECT')
        for o in batch:
            o.select_set(True)
        bpy.context.view_layer.objects.active = batch[0]
        
        try:
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        except Exception:
            pass
            
        if len(batch) > 1:
            bpy.ops.object.join()
            
        res = bpy.context.view_layer.objects.active
        res.name = batch_name
        
        # Remove unused material slots
        bpy.ops.object.material_slot_remove_unused()
        joined_objects.append(res)

print(f"[{time.time()-t0:.1f}s] All categories batched and joined into {len(joined_objects)} clean consolidated objects!", flush=True)

# 9. Load material definitions and wire diffuse + normal textures
with open(JSON_PATH, "r") as f:
    mats_data = json.load(f)

loaded_images = {}
def get_image(filename):
    if filename in loaded_images:
        return loaded_images[filename]
    path = os.path.join(IMG_DIR, filename)
    if os.path.exists(path):
        try:
            img = bpy.data.images.load(path)
            loaded_images[filename] = img
            return img
        except Exception:
            return None
    return None

used_materials = set()
for o in joined_objects:
    if o.data and hasattr(o.data, "materials"):
        for m in o.data.materials:
            if m:
                used_materials.add(m)

print(f"[{time.time()-t0:.1f}s] Configuring {len(used_materials)} active materials...", flush=True)
linked_diff = 0
linked_norm = 0

for mat in used_materials:
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    
    output_node = next((n for n in nodes if n.type == 'OUTPUT_MATERIAL'), None)
    if not output_node:
        output_node = nodes.new('ShaderNodeOutputMaterial')
        
    bsdf = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if not bsdf:
        bsdf = nodes.new('ShaderNodeBsdfPrincipled')
        
    links.new(bsdf.outputs['BSDF'], output_node.inputs['Surface'])
    
    for n in list(nodes):
        if n != output_node and n != bsdf:
            nodes.remove(n)
            
    base_name = mat.name.split(".")[0]
    info = mats_data.get(base_name) or mats_data.get(mat.name)
    if not info:
        continue
        
    settings = info.get("Settings", {})
    if "colorTint" in settings:
        try:
            parts = [float(x) for x in settings["colorTint"].split()]
            if len(parts) == 3:
                bsdf.inputs['Base Color'].default_value = (parts[0], parts[1], parts[2], 1.0)
        except Exception:
            pass

    textures = info.get("Textures", {})
    if "colorOpacity" in textures:
        c_name = textures["colorOpacity"].get("Name", "")
        img = get_image(c_name + ".TGA")
        if img:
            linked_diff += 1
            tex_node = nodes.new('ShaderNodeTexImage')
            tex_node.image = img
            links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
            if "glass" in mat.name.lower() or "frosted" in mat.name.lower():
                links.new(tex_node.outputs['Alpha'], bsdf.inputs['Alpha'])
                mat.blend_method = 'BLEND'

    if "normalMap" in textures:
        n_name = textures["normalMap"].get("Name", "")
        if n_name != "$normal":
            img_n = get_image(n_name + ".TGA")
            if img_n:
                linked_norm += 1
                img_n.colorspace_settings.name = 'Non-Color'
                tex_n = nodes.new('ShaderNodeTexImage')
                tex_n.image = img_n
                norm_node = nodes.new('ShaderNodeNormalMap')
                links.new(tex_n.outputs['Color'], norm_node.inputs['Color'])
                links.new(norm_node.outputs['Normal'], bsdf.inputs['Normal'])

print(f"[{time.time()-t0:.1f}s] Wired textures: {linked_diff} diffuse, {linked_norm} normal maps.", flush=True)

# 10. Clean up unused orphan materials
for m in list(bpy.data.materials):
    if m not in used_materials:
        bpy.data.materials.remove(m, do_unlink=True)

# 11. Export consolidated GLB cleanly
print(f"[{time.time()-t0:.1f}s] Exporting {len(joined_objects)} consolidated objects to {OUTPUT_GLB}...", flush=True)
bpy.ops.object.select_all(action='DESELECT')
for o in joined_objects:
    o.select_set(True)

bpy.ops.export_scene.gltf(
    filepath=OUTPUT_GLB,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_texcoords=True,
    export_normals=True,
    export_materials='EXPORT',
    export_image_format='AUTO'
)

print(f"[{time.time()-t0:.1f}s] SUCCESS! Complete consolidated Nuk3town BO3 exported successfully!", flush=True)
sys.exit(0)
