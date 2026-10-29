import bpy
import json
import os
import sys

print("==================================================")
print("  OPTIMIZING & BATCHING NUK3TOWN BO3 IN BLENDER   ")
print("==================================================")

JSON_PATH = os.path.abspath(r"assets/models/nuk3town_bo3/Nuketown (BO3) Futuristic/exported_files/exported_maps/black_ops_3/mp_nuketown_x_mats.json")
IMG_DIR = os.path.abspath(r"assets/models/nuk3town_bo3/Nuketown (BO3) Futuristic/exported_files/exported_images/black_ops_3")
OUTPUT_GLB = os.path.abspath(r"assets/models/nuk3town_bo3/nuk3town_bo3.glb")

# 1. Micro-clutter keywords to remove
CLUTTER_KEYWORDS = [
    "banana", "orange", "peach", "pear", "cucumber", "eggplant", "pepper", "vegetable", "tomato", "fruit",
    "fork", "spoon", "plate", "cup", "mug", "bowl", "jar", "dish", "pot", "pan", "grinder", "dinnerware",
    "pencil", "pen", "book", "magazine", "newspaper", "stapler", "tape_measure", "screwdriver", "socket",
    "wrench", "pouch", "outlet", "incense", "candle", "globe", "pillow", "blanket", "vase",
    "plush", "toy", "paper_towel", "trash", "butter_lettuce", "kale", "spinach", "watercress",
    "decal", "small_toy", "artwork", "photo_frame", "tablet_reader"
]

print(f"Total initial objects: {len(bpy.data.objects)}")

# Remove cameras and lights
for obj in list(bpy.data.objects):
    if obj.type in ['CAMERA', 'LIGHT']:
        bpy.data.objects.remove(obj, do_unlink=True)

# Remove clutter meshes
removed_clutter = 0
for obj in list(bpy.data.objects):
    if obj.type == 'MESH':
        name_lower = obj.name.lower()
        is_clutter = any(k in name_lower for k in CLUTTER_KEYWORDS)
        
        # Also check collection names
        if not is_clutter:
            for col in obj.users_collection:
                cname = col.name.lower()
                if any(k in cname for k in CLUTTER_KEYWORDS):
                    is_clutter = True
                    break
                    
        # Check size: if smaller than 0.25m bounding box and not map geometry
        if not is_clutter and "mapgeometry" not in name_lower:
            dim = obj.dimensions
            if max(dim.x, dim.y, dim.z) < 0.20:
                is_clutter = True

        if is_clutter:
            bpy.data.objects.remove(obj, do_unlink=True)
            removed_clutter += 1

print(f"Removed {removed_clutter} micro-clutter objects.")
surviving_meshes = [o for o in bpy.data.objects if o.type == 'MESH']
print(f"Surviving mesh objects: {len(surviving_meshes)}")

# 2. Categorize surviving meshes into major consolidated groups
CATEGORIES = {
    "BO3_MapGeometry": [],
    "BO3_HouseBlue": [],
    "BO3_HouseOrange": [],
    "BO3_GreenHouse": [],
    "BO3_Fences": [],
    "BO3_Vehicles": [],
    "BO3_Props_Major": [],
    "BO3_Foliage": [],
    "BO3_Vista": [],
    "BO3_Structures_Misc": []
}

for obj in surviving_meshes:
    n = obj.name.lower()
    
    # Check collection
    col_names = " ".join([c.name.lower() for c in obj.users_collection])
    
    if "vista" in n or "skyscraper" in n or "sky1" in n or "vista" in col_names:
        CATEGORIES["BO3_Vista"].append(obj)
    elif "supercar" in n or "hover_train" in n or "civ_car" in n or "van" in n or "car_platform" in n or "veh" in col_names:
        CATEGORIES["BO3_Vehicles"].append(obj)
    elif "foliage" in n or "tree" in n or "bush" in n or "cactus" in n or "fern" in n or "grass" in n or "foliage" in col_names:
        CATEGORIES["BO3_Foliage"].append(obj)
    elif "greenhouse" in n or "planter_greenhouse" in n or "greenhouse" in col_names:
        CATEGORIES["BO3_GreenHouse"].append(obj)
    elif "blue_house" in n or "blue_garage" in n:
        CATEGORIES["BO3_HouseBlue"].append(obj)
    elif "orange_house" in n or "orange_garage" in n or "office_orange" in n:
        CATEGORIES["BO3_HouseOrange"].append(obj)
    elif "fence" in n or "sidewalk" in n or "stone_path" in n or "curb" in n:
        CATEGORIES["BO3_Fences"].append(obj)
    elif "mapgeometry" in col_names or "road" in n or "terrain" in n:
        CATEGORIES["BO3_MapGeometry"].append(obj)
    elif "mannequin" in n or "billboard" in n or "welcome_sign" in n or "bench" in n or "bed" in n or "charging_station" in n or "stove" in n:
        CATEGORIES["BO3_Props_Major"].append(obj)
    else:
        CATEGORIES["BO3_Structures_Misc"].append(obj)

# 3. Join objects in each category
consolidated_objects = []

# Ensure object mode
if bpy.ops.object.mode_set.poll():
    bpy.ops.object.mode_set(mode='OBJECT')

for cat_name, objs in CATEGORIES.items():
    if not objs:
        continue
    print(f"Joining {len(objs)} objects in category: {cat_name}...")
    
    # Deselect all
    bpy.ops.object.select_all(action='DESELECT')
    
    # Select objects in category
    for o in objs:
        o.select_set(True)
        
    bpy.context.view_layer.objects.active = objs[0]
    
    # Apply transforms before join
    try:
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    except Exception as e:
        print(f"  Warning applying transform: {e}")
        
    # Join
    if len(objs) > 1:
        bpy.ops.object.join()
        
    joined_obj = bpy.context.view_layer.objects.active
    joined_obj.name = cat_name
    consolidated_objects.append(joined_obj)

print(f"Consolidation complete! Scene now has {len(consolidated_objects)} major mesh nodes.")

# 4. Link Materials & Textures from JSON
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

# Find which materials are actively used by consolidated objects
used_materials = set()
for o in consolidated_objects:
    for m in o.data.materials:
        if m:
            used_materials.add(m)

print(f"Total actively used materials: {len(used_materials)}")

linked_diffuse = 0
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
    
    # Remove existing unnecessary nodes
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
            linked_diffuse += 1
            tex_node = nodes.new('ShaderNodeTexImage')
            tex_node.image = img
            links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
            if "glass" in mat.name.lower() or "decal" in mat.name.lower():
                links.new(tex_node.outputs['Alpha'], bsdf.inputs['Alpha'])
                mat.blend_method = 'BLEND'

    if "normalMap" in textures:
        n_name = textures["normalMap"].get("Name", "")
        if n_name != "$normal":
            img_n = get_image(n_name + ".TGA")
            if img_n:
                img_n.colorspace_settings.name = 'Non-Color'
                tex_n = nodes.new('ShaderNodeTexImage')
                tex_n.image = img_n
                norm_node = nodes.new('ShaderNodeNormalMap')
                links.new(tex_n.outputs['Color'], norm_node.inputs['Color'])
                links.new(norm_node.outputs['Normal'], bsdf.inputs['Normal'])

print(f"Processed materials! Linked {linked_diffuse} textures.")

# Remove unused orphan materials
for m in list(bpy.data.materials):
    if m not in used_materials:
        bpy.data.materials.remove(m, do_unlink=True)

# 5. Export clean consolidated GLB
print(f"Exporting optimized scene to {OUTPUT_GLB}...")
bpy.ops.export_scene.gltf(
    filepath=OUTPUT_GLB,
    export_format='GLB',
    use_selection=False,
    export_apply=True,
    export_texcoords=True,
    export_normals=True,
    export_materials='EXPORT',
    export_image_format='AUTO'
)

print("OPTIMIZATION FINISHED SUCCESSFULLY!")
