import bpy
import json
import os
import sys

print("==================================================")
print("  BUILDING NUK3TOWN BO3 MODEL WITH TEXTURES")
print("==================================================")

JSON_PATH = os.path.abspath(r"assets/models/nuk3town_bo3/Nuketown (BO3) Futuristic/exported_files/exported_maps/black_ops_3/mp_nuketown_x_mats.json")
IMG_DIR = os.path.abspath(r"assets/models/nuk3town_bo3/Nuketown (BO3) Futuristic/exported_files/exported_images/black_ops_3")
OUTPUT_GLB = os.path.abspath(r"assets/models/nuk3town_bo3/nuk3town_bo3.glb")

with open(JSON_PATH, "r") as f:
    mats_data = json.load(f)

print(f"Loaded {len(mats_data)} materials from JSON.")

# Cache loaded images to avoid reloading same texture multiple times
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
        except Exception as e:
            return None
    return None

mat_count = 0
tex_count = 0

for mat in bpy.data.materials:
    mat_count += 1
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
    
    # Remove existing group / math nodes
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
    # Color
    if "colorOpacity" in textures:
        c_name = textures["colorOpacity"].get("Name", "")
        img = get_image(c_name + ".TGA")
        if img:
            tex_count += 1
            tex_node = nodes.new('ShaderNodeTexImage')
            tex_node.image = img
            links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
            # If transparent material
            if "glass" in mat.name.lower() or "decal" in mat.name.lower():
                links.new(tex_node.outputs['Alpha'], bsdf.inputs['Alpha'])
                mat.blend_method = 'BLEND'
                
    # Normal
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

print(f"Processed {mat_count} materials, linked {tex_count} diffuse textures.")

# Optimization: Join objects by major parent / collection to prevent thousands of draw calls
print("Consolidating scene geometry...")
# Delete cameras and lights from scene
for obj in list(bpy.data.objects):
    if obj.type in ['CAMERA', 'LIGHT']:
        bpy.data.objects.remove(obj, do_unlink=True)

# Select all meshes and apply transforms
bpy.ops.object.select_all(action='DESELECT')
mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH']
print(f"Total mesh objects: {len(mesh_objs)}")

# Export to GLB
print(f"Exporting to {OUTPUT_GLB}...")
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

print("Export complete! GLB successfully created.")
