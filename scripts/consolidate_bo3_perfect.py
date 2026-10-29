import bpy
import json
import os
import sys

print("==========================================================", flush=True)
print("  CONSOLIDATING FULL NUK3TOWN BO3 MAP TO HIGH QUALITY GLB ", flush=True)
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

# 2. Remove cameras and lights
for obj in list(bpy.data.objects):
    if obj.type in ['CAMERA', 'LIGHT']:
        bpy.data.objects.remove(obj, do_unlink=True)

# 3. Micro-clutter to clean up (bottles, cutlery, tiny debris)
TRASH = {
    "fork", "spoon", "pencil", "pen", "stapler", "tape_measure", "screwdriver", "socket", "wrench",
    "paper_towel", "butter_lettuce", "kale", "spinach", "watercress", "banana", "peach", "pear", "cucumber",
    "bottle", "bucket", "plate", "cup", "mug", "dish", "bowl", "jar", "candle", "sponge", "soap",
    "hanger", "broom", "dustpan", "wire", "cable", "outlet", "switch_box", "small_toy"
}

removed_clutter = 0
removed_vista = 0

for obj in list(bpy.data.objects):
    if obj.type == 'MESH':
        name_lower = obj.name.lower()
        if any(k in name_lower for k in TRASH):
            bpy.data.objects.remove(obj, do_unlink=True)
            removed_clutter += 1
            continue
            
        loc = obj.location
        if abs(loc.x) > 95 or abs(loc.y) > 95 or "vista" in name_lower or "skyscraper" in name_lower or "sky1" in name_lower:
            bpy.data.objects.remove(obj, do_unlink=True)
            removed_vista += 1
            continue

print(f"Cleaned up {removed_clutter} micro-trash and {removed_vista} distant vista meshes.", flush=True)

# 4. Move all surviving meshes to a unified master collection
master_col = bpy.data.collections.new("BO3_Master")
bpy.context.scene.collection.children.link(master_col)

surviving_meshes = []
for obj in list(bpy.data.objects):
    if obj.type == 'MESH':
        obj.hide_viewport = False
        obj.hide_set(False)
        obj.hide_select = False
        
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        master_col.objects.link(obj)
        surviving_meshes.append(obj)

print(f"Surviving playable meshes: {len(surviving_meshes)}", flush=True)

# 5. Smart categorization
CATEGORIES = {
    "BO3_MapGeometry": [],
    "BO3_HouseBlue": [],
    "BO3_HouseOrange": [],
    "BO3_GreenHouse": [],
    "BO3_Vehicles": [],
    "BO3_Fences": [],
    "BO3_StreetProps": [],
    "BO3_Furniture": [],
    "BO3_Foliage": [],
    "BO3_CoverCrates": [],
    "BO3_Backyard": [],
    "BO3_Decorations": []
}

unmatched = []

for obj in surviving_meshes:
    n = obj.name.lower()
    
    if "supercar" in n or "hover_train" in n or "civ_car" in n or "van" in n or "car_platform" in n:
        CATEGORIES["BO3_Vehicles"].append(obj)
    elif "foliage" in n or "tree" in n or "bush" in n or "cactus" in n or "fern" in n or "grass" in n or "plant" in n:
        CATEGORIES["BO3_Foliage"].append(obj)
    elif "greenhouse" in n or "planter_greenhouse" in n:
        CATEGORIES["BO3_GreenHouse"].append(obj)
    elif "blue_house" in n or "blue_garage" in n or "blue_exterior" in n or "blue_bldg" in n or "blue_refridgerator" in n:
        CATEGORIES["BO3_HouseBlue"].append(obj)
    elif "orange_house" in n or "orange_garage" in n or "office_orange" in n or "orange_exterior" in n or "orange_bldg" in n:
        CATEGORIES["BO3_HouseOrange"].append(obj)
    elif "fence" in n or "gate" in n or "barrier" in n or "curb" in n:
        CATEGORIES["BO3_Fences"].append(obj)
    elif "mapgeometry" in n or "road" in n or "terrain" in n or "sidewalk" in n or "ground" in n or "floor" in n:
        CATEGORIES["BO3_MapGeometry"].append(obj)
    elif "mannequin" in n or "billboard" in n or "welcome_sign" in n or "bench" in n or "robot" in n or "flag" in n or "bomb" in n or "light_lamp" in n or "mailbox" in n:
        CATEGORIES["BO3_StreetProps"].append(obj)
    elif "cover_crates" in n or "crates" in n:
        CATEGORIES["BO3_CoverCrates"].append(obj)
    elif "playset" in n or "sauna" in n or "fireplace" in n:
        CATEGORIES["BO3_Backyard"].append(obj)
    elif "mural" in n or "rug" in n or "poster" in n or "signage" in n or "art" in n or "display" in n or "monitor" in n:
        CATEGORIES["BO3_Decorations"].append(obj)
    elif "bed" in n or "couch" in n or "chair" in n or "table" in n or "desk" in n or "sink" in n or "stove" in n or "cabinet" in n or "tv" in n or "counter" in n:
        CATEGORIES["BO3_Furniture"].append(obj)
    else:
        unmatched.append(obj)

print(f"Categorized into main groups. Unmatched meshes: {len(unmatched)}", flush=True)

# 6. Join each category safely with transforms applied
joined_objects = []

for cat_name, objs in CATEGORIES.items():
    if not objs:
        continue
    print(f"Joining category '{cat_name}' ({len(objs)} objects)...", flush=True)
    
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    
    try:
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    except Exception:
        pass
        
    if len(objs) > 1:
        bpy.ops.object.join()
        
    res = bpy.context.view_layer.objects.active
    res.name = cat_name
    joined_objects.append(res)

# For unmatched meshes, keep any that are significant (>0.3m size)
kept_unmatched = 0
for u in unmatched:
    dim = u.dimensions
    if max(dim.x, dim.y, dim.z) > 0.35:
        joined_objects.append(u)
        kept_unmatched += 1
    else:
        bpy.data.objects.remove(u, do_unlink=True)

print(f"Total objects in final scene: {len(joined_objects)} (including {kept_unmatched} architectural props)", flush=True)

# 7. Link PBR textures from JSON
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

print(f"Total actively used materials: {len(used_materials)}", flush=True)
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

print(f"Materials configured: {linked_diff} diffuse, {linked_norm} normal textures.", flush=True)

# 8. Export cleanly to nuk3town_bo3.glb
print(f"Exporting to {OUTPUT_GLB}...", flush=True)
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

print("SUCCESS: Full consolidated GLB exported successfully!", flush=True)
sys.exit(0)
