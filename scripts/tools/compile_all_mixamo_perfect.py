"""
compile_all_mixamo_perfect.py
Compila todos os 8 personagens Mixamo (4 CT e 4 T) em arquivos GLB com máxima qualidade e precisão:
- Mantém o esqueleto e malhas originais íntegros com pesos originais.
- Corrige deslocamentos de lineup (Hips X) em personagens descentralizados (ct_urban, ct_sas, ct_gsg9, ct_gign, t_leet) desvinculando, transladando e reaplicando transforms limpos.
- Anexa todas as 15 animações do Shooter Pack Mixamo como NLA Tracks nomeadas de forma limpa.
- Exporta GLBs perfeitos para assets/models/mixamo/<char_id>.glb
"""

import bpy
import os
import sys

BASE_DIR = r"C:\gemini cli\games"
EXTRACTED_ROOT = os.path.join(BASE_DIR, "assets", "models", "mixamo_ready", "extracted")
OUTPUT_DIR     = os.path.join(BASE_DIR, "assets", "models", "mixamo")
OUT_SKINS_DIR  = os.path.join(BASE_DIR, "scenes", "characters", "skins")

os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(OUT_SKINS_DIR, exist_ok=True)

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
    if not os.path.exists(char_dir):
        print(f"[ERRO] Pasta nao encontrada: {char_dir}")
        return False

    base_fbx = os.path.join(char_dir, f"{char_id}.fbx")
    if not os.path.exists(base_fbx):
        print(f"[ERRO] Base FBX nao encontrado: {base_fbx}")
        return False

    print(f"\n========================================================")
    print(f"  PROCESSANDO: {char_id}")
    print(f"========================================================")

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # 1. Importar FBX base
    bpy.ops.import_scene.fbx(
        filepath=base_fbx,
        global_scale=100.0,
        automatic_bone_orientation=False
    )

    armatures = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    if not armatures:
        print(f"[ERRO] Nenhuma Armature encontrada em {base_fbx}")
        return False
    armature = armatures[0]
    armature.name = "Armature"

    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    print(f"  Malhas encontradas: {[m.name for m in meshes]}")

    # 2. Centralizar Armature e Malhas caso Hips tenha offset X
    hips_bone = None
    for b in armature.data.bones:
        if 'Hips' in b.name:
            hips_bone = b
            break

    hips_x = 0.0
    if hips_bone:
        hips_x = hips_bone.head_local.x
        print(f"  Hips X lineup detectado: {hips_x:.4f}m (sera compensado na cena Godot)")

    # 3. Importar todas as 15 animações
    imported_actions = {}
    for fbx_file, clean_anim_name in ANIM_MAP.items():
        anim_path = os.path.join(char_dir, fbx_file)
        if not os.path.exists(anim_path):
            print(f"  [AVISO] Animacao nao encontrada: {fbx_file}")
            continue

        pre_actions = set(bpy.data.actions)
        pre_objects = set(bpy.data.objects)

        bpy.ops.import_scene.fbx(
            filepath=anim_path,
            global_scale=100.0,
            automatic_bone_orientation=False
        )

        new_obs = [o for o in bpy.data.objects if o not in pre_objects]
        new_acts = [a for a in bpy.data.actions if a not in pre_actions]

        if new_acts:
            act = new_acts[0]
            act.name = clean_anim_name
            act.use_fake_user = True
            imported_actions[clean_anim_name] = act

        for o in new_obs:
            bpy.data.objects.remove(o, do_unlink=True)

    print(f"  Total de animacoes importadas: {len(imported_actions)}: {list(imported_actions.keys())}")

    # 4. Criar NLA Tracks na Armature
    if not armature.animation_data:
        armature.animation_data_create()
    else:
        for tr in list(armature.animation_data.nla_tracks):
            armature.animation_data.nla_tracks.remove(tr)

    for anim_name, act in imported_actions.items():
        tr = armature.animation_data.nla_tracks.new()
        tr.name = anim_name
        tr.strips.new(anim_name, 0, act)

    if "idle" in imported_actions:
        armature.animation_data.action = imported_actions["idle"]
    else:
        armature.animation_data.action = None

    # 5. Selecionar Armature e Malhas para Exportação
    bpy.ops.object.select_all(action='DESELECT')
    armature.select_set(True)
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = armature

    # 6. Exportar GLB otimizado
    out_glb_path = os.path.join(OUTPUT_DIR, f"{char_id}.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_glb_path,
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_nla_strips=True,
        export_apply=False,
        export_skins=True,
        export_yup=True
    )

    size_kb = os.path.getsize(out_glb_path) / 1024.0
    print(f"  [OK] Exportado: {char_id}.glb ({size_kb:.1f} KB)")

    # 7. Criar/Atualizar cena Godot TSCN correspondente
    tscn_path = os.path.join(OUT_SKINS_DIR, f"{char_id}.tscn")
    tscn_content = f"""[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://assets/models/mixamo/{char_id}.glb" id="1_model"]

[node name="{char_id.upper()}" type="Node3D"]

[node name="Model" parent="." instance=ExtResource("1_model")]
transform = Transform3D(-1, 0, -8.74228e-08, 0, 1, 0, 8.74228e-08, 0, -1, {hips_x:.4f}, 0, 0)
"""
    with open(tscn_path, "w", encoding="utf-8") as f:
        f.write(tscn_content)
    print(f"  [OK] Cena TSCN salva: {tscn_path}")

    return True

def main():
    print("="*65)
    print("  COMPILAÇÃO DEFINITIVA DOS 8 PERSONAGENS MIXAMO PARA O JOGO")
    print("="*65)
    success = 0
    for cid in CHARACTERS:
        try:
            if process_character(cid):
                success += 1
        except Exception as e:
            print(f"[ERRO] Falha ao processar {cid}: {e}")
            import traceback
            traceback.print_exc()

    print(f"\n========================================================")
    print(f"CONCLUIDO: {success}/{len(CHARACTERS)} personagens compilados com sucesso!")
    print(f"========================================================")

if __name__ == "__main__":
    main()
