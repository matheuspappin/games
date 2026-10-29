"""
Clean and definitive compiler for all 8 Mixamo characters to GLB:
- Reads directly from assets/models/mixamo_ready/extracted/<char>/
- Imports base mesh and skeleton untouched (no destructive edit-bone shifts or rest-pose warping)
- Integrates all 15 downloaded Mixamo animations into NLA tracks
- Exports clean binary GLB to assets/models/mixamo/<char>.glb
"""

import bpy
import os
import sys

EXTRACTED_ROOT = r"C:\gemini cli\games\assets\models\mixamo_ready\extracted"
OUTPUT_DIR     = r"C:\gemini cli\games\assets\models\mixamo"
os.makedirs(OUTPUT_DIR, exist_ok=True)

CHARACTERS = [
    "ct_urban", "ct_sas", "ct_gsg9", "ct_gign",
    "t_phoenix", "t_leet", "t_guerilla", "t_arctic"
]

ANIM_MAP = {
    "rifle aiming idle.fbx":       "idle",
    "walking.fbx":                 "walk",
    "rifle run.fbx":               "run",
    "walking backwards.fbx":       "walk_backward",
    "run backwards.fbx":           "run_backward",
    "strafe.fbx":                  "strafe_left",
    "strafe (2).fbx":              "strafe_right",
    "firing rifle.fbx":            "shoot",
    "walking to dying.fbx":        "die",
    "jump forward.fbx":            "jump_forward",
    "jump backward.fbx":           "jump_backward",
    "start walking.fbx":           "start_walk",
    "stop walking.fbx":            "stop_walk",
    "start walking backwards.fbx": "start_walk_backward",
    "walk backwards stop.fbx":     "stop_walk_backward",
}

def process_character(char_name):
    char_dir = os.path.join(EXTRACTED_ROOT, char_name)
    base_fbx = os.path.join(char_dir, f"{char_name}.fbx")
    out_glb  = os.path.join(OUTPUT_DIR, f"{char_name}.glb")

    if not os.path.isfile(base_fbx):
        print(f"[SKIP] Base FBX not found: {base_fbx}")
        return False

    print(f"\n========================================================")
    print(f"  COMPILING CLEAN GLB: {char_name}")
    print(f"========================================================")

    # 1. Start with factory clean empty scene
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 2. Import base character (mesh + armature)
    print(f"  Importing base FBX: {base_fbx}")
    bpy.ops.import_scene.fbx(filepath=base_fbx)

    armature = None
    for ob in bpy.data.objects:
        if ob.type == 'ARMATURE':
            armature = ob
            break

    if not armature:
        print(f"  [ERROR] No armature found in {base_fbx}")
        return False

    armature.name = "Armature"

    # Clean default action if any
    if armature.animation_data and armature.animation_data.action:
        bpy.data.actions.remove(armature.animation_data.action)

    # 3. Import each animation FBX
    imported_actions = []

    for filename, clean_anim_name in ANIM_MAP.items():
        anim_path = os.path.join(char_dir, filename)
        if not os.path.exists(anim_path):
            print(f"  [WARN] Missing animation file: {filename}")
            continue

        existing_actions = set(bpy.data.actions)
        existing_objects = set(bpy.data.objects)

        bpy.ops.import_scene.fbx(filepath=anim_path)

        new_objects = set(bpy.data.objects) - existing_objects
        new_actions = set(bpy.data.actions) - existing_actions

        for act in new_actions:
            act.name = clean_anim_name
            act.use_fake_user = True
            imported_actions.append(act)
            print(f"  + Added action '{clean_anim_name}'")

        # Purge all newly imported objects (extra armatures/empties)
        for ob in new_objects:
            bpy.data.objects.remove(ob, do_unlink=True)

    # 4. Set up NLA tracks on base armature
    if not armature.animation_data:
        armature.animation_data_create()

    for track in list(armature.animation_data.nla_tracks):
        armature.animation_data.nla_tracks.remove(track)

    for act in imported_actions:
        track = armature.animation_data.nla_tracks.new()
        track.name = act.name
        strip = track.strips.new(act.name, int(act.frame_range[0]), act)
        strip.action = act

    armature.animation_data.action = None

    # Clean up orphan meshes or loose objects not attached to base armature
    for ob in list(bpy.data.objects):
        if ob != armature and ob not in armature.children:
            bpy.data.objects.remove(ob, do_unlink=True)

    # 5. Export clean GLB
    print(f"  Exporting to {out_glb}...")
    bpy.ops.export_scene.gltf(
        filepath=out_glb,
        export_format='GLB',
        export_animations=True,
        export_nla_strips=True,
        export_def_bones=True,
        export_optimize_animation_size=False
    )

    size_kb = os.path.getsize(out_glb) / 1024 if os.path.exists(out_glb) else 0
    print(f"  [SUCCESS] {char_name}.glb exported successfully! ({size_kb:.1f} KB, {len(imported_actions)} anims)")
    return True

def main():
    print("Starting clean compilation of all 8 Mixamo characters...")
    success = 0
    for char in CHARACTERS:
        try:
            if process_character(char):
                success += 1
        except Exception as e:
            print(f"[ERROR] Failed to compile {char}: {e}")
            import traceback
            traceback.print_exc()

    print(f"\n========================================================")
    print(f"COMPILATION COMPLETE: {success}/{len(CHARACTERS)} characters built successfully!")
    print(f"========================================================")

if __name__ == "__main__":
    main()
