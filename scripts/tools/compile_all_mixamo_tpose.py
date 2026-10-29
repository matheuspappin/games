"""
compile_all_mixamo_tpose.py
Converte todos os 8 personagens Mixamo (4 CT e 4 T) para o padrão exato do x_bot e t_leet:
1. Importa o FBX base do personagem (com sua malha e materiais).
2. Centraliza a geometria e os ossos em X=0 (anula o offset de lineup do CS original).
3. Converte a pose de descanso de A-pose (braços caídos em 52.5°) para T-pose padrão Mixamo (braços horizontais),
   garantindo que qualquer animação do Mixamo encaixe perfeitamente ("plug and play") como no x_bot.
4. Importa todas as 15 animações do Shooter Pack Mixamo e cria NLA tracks dedicadas.
5. Exporta GLB com esqueleto, malha e materiais para assets/models/mixamo/<char>.glb.
"""

import bpy
import os
import math
from mathutils import Vector, Quaternion

EXTRACTED_ROOT = r"C:\gemini cli\games\assets\models\mixamo_ready\extracted"
OUTPUT_DIR     = r"C:\gemini cli\games\assets\models\mixamo"

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
    "walk backwards stop.fbx":     "stop_walk_backward"
}

def process_character(char_id):
    char_dir = os.path.join(EXTRACTED_ROOT, char_id)
    base_fbx = os.path.join(char_dir, f"{char_id}.fbx")
    if not os.path.exists(base_fbx):
        print(f"[ERRO] {base_fbx} nao encontrado")
        return False

    print(f"\n{'='*60}")
    print(f"  PROCESSANDO: {char_id}")
    print(f"{'='*60}")

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Importar FBX base com escala 100.0 (escala humana padrao metros)
    bpy.ops.import_scene.fbx(filepath=base_fbx, global_scale=100.0)

    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
    arm.name = "Armature"
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']

    # 2. Centralizar Armature e Meshes no eixo X
    dx = arm.data.bones['mixamorig:Hips'].head_local.x
    print(f"  Offset X detectado: {dx:.3f}m -> Centralizando...")

    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for eb in arm.data.edit_bones:
        eb.head.x -= dx
        eb.tail.x -= dx
    bpy.ops.object.mode_set(mode='OBJECT')

    for m in meshes:
        for v in m.data.vertices:
            v.co.x -= dx
        m.data.update()

    # 3. Se o modelo estiver em A-pose (braços apontando para baixo), alinhar para T-pose padrão Mixamo
    b_ra = arm.data.bones.get('mixamorig:RightArm')
    b_la = arm.data.bones.get('mixamorig:LeftArm')

    if b_ra and b_la:
        v_ra = (b_ra.tail_local - b_ra.head_local).normalized()
        angle_diff = v_ra.angle(Vector((-1.0, 0.0, 0.0)))
        print(f"  Inclinacao do braco direito: {math.degrees(angle_diff):.2f}°")

        if angle_diff > math.radians(10.0):
            print("  Convertendo A-pose para T-pose padrao...")
            bpy.context.view_layer.objects.active = arm
            bpy.ops.object.mode_set(mode='POSE')

            pb_ra = arm.pose.bones['mixamorig:RightArm']
            pb_la = arm.pose.bones['mixamorig:LeftArm']

            v_la = (b_la.tail_local - b_la.head_local).normalized()

            q_ra = v_ra.rotation_difference(Vector((-1.0, 0.0, 0.0)))
            q_la = v_la.rotation_difference(Vector((1.0, 0.0, 0.0)))

            pb_ra.rotation_mode = 'QUATERNION'
            pb_la.rotation_mode = 'QUATERNION'
            pb_ra.rotation_quaternion = q_ra
            pb_la.rotation_quaternion = q_la

            bpy.context.view_layer.update()

            # Congelar deformação nas malhas
            bpy.ops.object.mode_set(mode='OBJECT')
            for m in meshes:
                bpy.context.view_layer.objects.active = m
                for mod in list(m.modifiers):
                    if mod.type == 'ARMATURE':
                        try:
                            bpy.ops.object.modifier_apply(modifier=mod.name)
                        except Exception as e:
                            pass

            # Aplicar nova pose de repouso no esqueleto
            bpy.context.view_layer.objects.active = arm
            bpy.ops.object.mode_set(mode='POSE')
            bpy.ops.pose.armature_apply()
            bpy.ops.object.mode_set(mode='OBJECT')

            # Re-vincular modificador Armature
            for m in meshes:
                mod = m.modifiers.new('Armature', 'ARMATURE')
                mod.object = arm

    # 4. Importar as 15 animações do Shooter Pack
    imported_actions = {}
    for fbx_file, anim_name in ANIM_MAP.items():
        anim_path = os.path.join(char_dir, fbx_file)
        if not os.path.exists(anim_path):
            continue

        pre_actions = set(bpy.data.actions)
        pre_obs = set(bpy.data.objects)

        bpy.ops.import_scene.fbx(filepath=anim_path, global_scale=100.0)

        new_acts = list(set(bpy.data.actions) - pre_actions)
        new_obs = list(set(bpy.data.objects) - pre_obs)

        if new_acts:
            act = new_acts[0]
            act.name = anim_name
            act.use_fake_user = True
            imported_actions[anim_name] = act

        for o in new_obs:
            bpy.data.objects.remove(o, do_unlink=True)

    print(f"  Animacoes importadas: {len(imported_actions)}")

    # 5. Criar NLA Tracks na Armature
    if not arm.animation_data:
        arm.animation_data_create()

    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)

    for anim_name, act in imported_actions.items():
        tr = arm.animation_data.nla_tracks.new()
        tr.name = anim_name
        tr.strips.new(anim_name, 0, act)

    # Definir idle como ativa por padrão
    if "idle" in imported_actions:
        arm.animation_data.action = imported_actions["idle"]
    else:
        arm.animation_data.action = None

    # 6. Selecionar Armature e malhas para exportação
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = arm

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_glb = os.path.join(OUTPUT_DIR, f"{char_id}.glb")

    bpy.ops.export_scene.gltf(
        filepath=out_glb,
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_nla_strips=True,
        export_apply=False,
        export_skins=True,
        export_yup=True
    )

    size_kb = os.path.getsize(out_glb) / 1024.0
    print(f"  [OK] Exportado: {char_id}.glb ({size_kb:.1f} KB)")
    return True

def main():
    print("="*60)
    print("  COMPILACAO FINAL PERFEITA DOS 8 PERSONAGENS (PADRAO T-POSE)")
    print("="*60)
    success = 0
    for c in CHARACTERS:
        try:
            if process_character(c):
                success += 1
        except Exception as e:
            print(f"[ERRO] Falha em {c}: {e}")
            import traceback
            traceback.print_exc()

    print(f"\nFinalizado: {success}/{len(CHARACTERS)} compilados com sucesso.")

if __name__ == "__main__":
    main()
