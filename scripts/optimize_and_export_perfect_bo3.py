import bpy
import bmesh
import os
import sys
import time

t0 = time.time()
print("==========================================================", flush=True)
print("  OPTIMIZING CONSOLIDATED BO3 NUK3TOWN MAP FOR GODOT 4    ", flush=True)
print("==========================================================", flush=True)

OUTPUT_GLB = os.path.abspath(r"assets/models/nuk3town_bo3/nuk3town_bo3.glb")

mesh_objects = [o for o in bpy.data.objects if o.type == 'MESH']
print(f"[{time.time()-t0:.1f}s] Processing {len(mesh_objects)} consolidated mesh objects...", flush=True)

total_verts_before = sum(len(o.data.vertices) for o in mesh_objects)
print(f"Total vertices before weld: {total_verts_before:,}", flush=True)

# 1. Weld split vertices on all meshes
weld_count = 0
for o in mesh_objects:
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.005)
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    weld_count += 1
    if weld_count % 25 == 0:
        print(f"  Welded {weld_count}/{len(mesh_objects)} objects...", flush=True)

total_verts_after_weld = sum(len(o.data.vertices) for o in mesh_objects)
print(f"[{time.time()-t0:.1f}s] Vertices after weld: {total_verts_after_weld:,} (saved {total_verts_before - total_verts_after_weld:,} duplicate verts)", flush=True)

# 2. Planar dissolve on flat architecture meshes (walls, floors, roads) to eliminate redundant flat triangles
planar_categories = ["Panels_Walls", "Floors_Paths", "MapGeometry", "MiscStructures"]
decimated = 0
for o in mesh_objects:
    if any(k in o.name for k in planar_categories):
        mod = o.modifiers.new("PlanarDecimate", 'DECIMATE')
        mod.decimate_type = 'DISSOLVE'
        mod.angle_limit = 0.035 # ~2 degrees
        bpy.context.view_layer.objects.active = o
        try:
            bpy.ops.object.modifier_apply(modifier="PlanarDecimate")
            decimated += 1
        except Exception:
            o.modifiers.remove(mod)

total_verts_final = sum(len(o.data.vertices) for o in mesh_objects)
print(f"[{time.time()-t0:.1f}s] Applied planar dissolve to {decimated} architectural objects. Final verts: {total_verts_final:,}", flush=True)

# 3. Downscale high-res images in Blender to max 1024x1024 for smooth integrated GPU memory
print(f"[{time.time()-t0:.1f}s] Optimizing texture resolutions to 1024px...", flush=True)
scaled_imgs = 0
for img in bpy.data.images:
    if img.size[0] > 1024 or img.size[1] > 1024:
        new_w = min(1024, img.size[0] // 2)
        new_h = min(1024, img.size[1] // 2)
        try:
            img.scale(new_w, new_h)
            scaled_imgs += 1
        except Exception:
            pass

print(f"[{time.time()-t0:.1f}s] Rescaled {scaled_imgs} textures to 1024px max.", flush=True)

# 4. Save optimized blend
blend_path = os.path.abspath(r"assets/models/nuk3town_bo3/nuk3town_bo3_consolidated.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print(f"[{time.time()-t0:.1f}s] Saved updated {blend_path}.", flush=True)

# 5. Export to GLB with JPEG 75 quality
print(f"[{time.time()-t0:.1f}s] Exporting to {OUTPUT_GLB} with JPEG 75 compression...", flush=True)
bpy.ops.export_scene.gltf(
    filepath=OUTPUT_GLB,
    export_format='GLB',
    use_selection=False,
    export_apply=False,
    export_texcoords=True,
    export_normals=True,
    export_materials='EXPORT',
    export_image_format='JPEG',
    export_image_quality=75
)

size_mb = os.path.getsize(OUTPUT_GLB) / (1024 * 1024)
print(f"[{time.time()-t0:.1f}s] EXPORT COMPLETE! New GLB file size: {size_mb:.1f} MB", flush=True)
sys.exit(0)
