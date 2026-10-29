"""
import_all_mixamo_characters.py
Extrai os 8 arquivos ZIP gerados pelo Mixamo com os modelos e animacoes do Shooter Pack:
 - ct_urban mixamo.zip
 - ct_sas mixamo.zip
 - ct_gsg9 mixamo.zip
 - ct_gign mixamo.zip
 - t_phoenix mixamo.zip
 - t_leet mixamo.zip
 - t_guerilla mixamo.zip
 - t_arctic mixamo.zip

Para cada personagem:
 1. Extrai o FBX do modelo base + os 15 FBXs de animacao.
 2. No Blender, monta o esqueleto padronizado Mixamo com os tracks NLA de animacao nomeados:
    idle, walk, run, shoot, die, strafe_left, strafe_right,
    walk_backward, run_backward, jump_forward, jump_backward,
    start_walk, stop_walk, start_walk_backward, stop_walk_backward
 3. Exporta como GLB auto-contido com malha, materiais, esqueleto e animacoes para:
    assets/models/mixamo/<id>.glb
 4. Gera a cena Godot correspondente em:
    scenes/characters/skins/<id>.tscn
"""

import bpy
import os
import shutil
import zipfile

BASE_DIR = r"C:\gemini cli\games"
ZIP_DIR = os.path.join(BASE_DIR, "assets", "models", "mixamo_ready", "zip")
OUT_MODELS_DIR = os.path.join(BASE_DIR, "assets", "models", "mixamo")
OUT_SKINS_DIR = os.path.join(BASE_DIR, "scenes", "characters", "skins")
SCRATCH_DIR = os.path.join(BASE_DIR, "scratch", "mixamo_extract")

os.makedirs(OUT_MODELS_DIR, exist_ok=True)
os.makedirs(OUT_SKINS_DIR, exist_ok=True)
os.makedirs(SCRATCH_DIR, exist_ok=True)

CHARACTERS = [
    {"id": "ct_urban", "zip": "ct_urban mixamo.zip", "fbx": "ct_urban.fbx", "name": "SEAL Team 6 (Urban)"},
    {"id": "ct_sas", "zip": "ct_sas mixamo.zip", "fbx": "ct_sas.fbx", "name": "SAS"},
    {"id": "ct_gsg9", "zip": "ct_gsg9 mixamo.zip", "fbx": "ct_gsg9.fbx", "name": "GSG-9"},
    {"id": "ct_gign", "zip": "ct_gign mixamo.zip", "fbx": "ct_gign.fbx", "name": "GIGN"},
    {"id": "t_phoenix", "zip": "t_phoenix mixamo.zip", "fbx": "t_phoenix.fbx", "name": "Phoenix Connexion"},
    {"id": "t_leet", "zip": "t_leet mixamo.zip", "fbx": "t_leet.fbx", "name": "Elite Crew"},
    {"id": "t_guerilla", "zip": "t_guerilla mixamo.zip", "fbx": "t_guerilla.fbx", "name": "Guerilla Warfare"},
    {"id": "t_arctic", "zip": "t_arctic mixamo.zip", "fbx": "t_arctic.fbx", "name": "Arctic Avengers"}
]

ANIM_MAP = {
    "rifle aiming idle.fbx": "idle",
    "walking.fbx": "walk",
    "rifle run.fbx": "run",
    "walking backwards.fbx": "walk_backward",
    "run backwards.fbx": "run_backward",
    "strafe.fbx": "strafe_left",
    "strafe (2).fbx": "strafe_right",
    "firing rifle.fbx": "shoot",
    "walking to dying.fbx": "die",
    "jump forward.fbx": "jump_forward",
    "jump backward.fbx": "jump_backward",
    "start walking.fbx": "start_walk",
    "stop walking.fbx": "stop_walk",
    "start walking backwards.fbx": "start_walk_backward",
    "walk backwards stop.fbx": "stop_walk_backward"
}

def process_character(char_info):
    char_id = char_info["id"]
    char_name = char_info["name"]
    zip_filename = char_info["zip"]
    fbx_filename = char_info["fbx"]
    
    zip_path = os.path.join(ZIP_DIR, zip_filename)
    if not os.path.exists(zip_path):
        print(f"[ERRO] Arquivo ZIP nao encontrado: {zip_path}")
        return False
        
    print(f"\n========================================================")
    print(f"Processando: {char_id} - {char_name}")
    print(f"========================================================")
    
    # 1. Extrair ZIP para scratch
    char_scratch = os.path.join(SCRATCH_DIR, char_id)
    if os.path.exists(char_scratch):
        shutil.rmtree(char_scratch)
    os.makedirs(char_scratch, exist_ok=True)
    
    with zipfile.ZipFile(zip_path, 'r') as zf:
        zf.extractall(char_scratch)
    print(f"  [1/4] Extraido para: {char_scratch}")
    
    # 2. Iniciar Blender limpo
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    base_fbx = os.path.join(char_scratch, fbx_filename)
    if not os.path.exists(base_fbx):
        # Tentar achar qualquer fbx que nao seja de animacao
        all_fbx = [f for f in os.listdir(char_scratch) if f.endswith(".fbx") and f not in ANIM_MAP]
        if all_fbx:
            base_fbx = os.path.join(char_scratch, all_fbx[0])
        else:
            print(f"[ERRO] FBX base nao encontrado para {char_id}")
            return False
            
    print(f"  [2/4] Importando FBX base: {base_fbx}")
    bpy.ops.import_scene.fbx(filepath=base_fbx)
    
    armatures = [ob for ob in bpy.data.objects if ob.type == 'ARMATURE']
    if not armatures:
        print("[ERRO] Nenhuma Armature encontrada no FBX base!")
        return False
    armature = armatures[0]
    armature.name = "Armature"
    
    # Aplicar scale na Armature e meshes base
    bpy.ops.object.select_all(action='DESELECT')
    for ob in bpy.data.objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    # 3. Importar cada animacao
    print(f"  [3/4] Importando animacoes...")
    imported_actions = []
    
    for anim_file, clean_anim_name in ANIM_MAP.items():
        anim_path = os.path.join(char_scratch, anim_file)
        if not os.path.exists(anim_path):
            continue
            
        existing_actions = set(bpy.data.actions)
        existing_obs = set(bpy.data.objects)
        
        bpy.ops.import_scene.fbx(filepath=anim_path)
        
        new_obs = set(bpy.data.objects) - existing_obs
        new_actions = set(bpy.data.actions) - existing_actions
        
        new_armatures = [ob for ob in new_obs if ob.type == 'ARMATURE']
        if new_armatures:
            bpy.ops.object.select_all(action='DESELECT')
            for ob in new_obs:
                ob.select_set(True)
            bpy.context.view_layer.objects.active = new_armatures[0]
            try:
                bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            except Exception as e:
                pass
                
        for act in new_actions:
            act.name = clean_anim_name
            act.use_fake_user = True
            imported_actions.append(act)
            
        for ob in new_obs:
            bpy.data.objects.remove(ob, do_unlink=True)
            
    print(f"  Total de acoes carregadas: {len(imported_actions)}")
    
    # Criar NLA tracks para exportacao GLB
    if not armature.animation_data:
        armature.animation_data_create()
        
    for act in imported_actions:
        track = armature.animation_data.nla_tracks.new()
        track.name = act.name
        strip = track.strips.new(act.name, int(act.frame_range[0]), act)
        strip.action = act
        
    # 4. Exportar GLB
    out_glb_path = os.path.join(OUT_MODELS_DIR, f"{char_id}.glb")
    print(f"  [4/4] Exportando GLB: {out_glb_path}")
    bpy.ops.export_scene.gltf(
        filepath=out_glb_path,
        export_format='GLB',
        export_animations=True,
        export_nla_strips=True,
        export_def_bones=True,
        export_optimize_animation_size=False
    )
    print(f"  [OK] GLB gerado com sucesso! ({os.path.getsize(out_glb_path):,} bytes)")
    
    # 5. Gerar cena Godot TSCN limpa que instancia o GLB
    tscn_path = os.path.join(OUT_SKINS_DIR, f"{char_id}.tscn")
    glb_res_path = f"res://assets/models/mixamo/{char_id}.glb"
    
    tscn_content = f"""[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="{glb_res_path}" id="1_model"]

[node name="{char_id.upper()}" type="Node3D"]

[node name="Model" parent="." instance=ExtResource("1_model")]
transform = Transform3D(-1, 0, -8.74228e-08, 0, 1, 0, 8.74228e-08, 0, -1, 0, 0, 0)
"""
    with open(tscn_path, "w", encoding="utf-8") as f:
        f.write(tscn_content)
    print(f"  [OK] Cena Godot atualizada: {tscn_path}")
    
    return True

def main():
    print("=================================================================")
    print("INICIANDO IMPORTACAO COMPLETA DE PERSONAGENS MIXAMO PARA O JOGO")
    print("=================================================================")
    
    success_count = 0
    for char_info in CHARACTERS:
        if process_character(char_info):
            success_count += 1
            
    print(f"\n=================================================================")
    print(f"FINALIZADO! {success_count}/{len(CHARACTERS)} personagens importados com sucesso.")
    print("=================================================================")

if __name__ == "__main__":
    main()
