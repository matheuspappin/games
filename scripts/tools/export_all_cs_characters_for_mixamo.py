"""
export_all_cs_characters_for_mixamo.py
Script executado via Blender headless para extrair e converter todas as 8 skins de CS:Source
(4 Contra-Terroristas e 4 Terroristas) nos formatos aceitos pelo Mixamo:
 - FBX (.fbx)
 - OBJ (.obj + .mtl)
 - ZIP (.zip com .obj, .mtl e texturas .png completas para visualização com cores no Mixamo)

Todos os modelos são:
 - Isolados individualmente (1 personagem por arquivo)
 - Modificadores aplicados/colapsados (eliminando distorções de bind pose da Valve)
 - Centralizados no eixo X=0, Y=0 (profundidade)
 - Pés apoiados perfeitamente no chão (Z=0 no Blender -> Y=0 no OBJ/FBX exportado)
 - Escala padronizada para altura real humana (~1.81m, padrão Mixamo)
 - Orientados de frente para a câmera (+Z)
 - Materiais balanceados sem excesso de brilho branco (Ka=0, Ks=0)
"""

import bpy
import os
import shutil
import zipfile
from mathutils import Vector

BASE_DIR = r"C:\gemini cli\games"
OUT_DIR = os.path.join(BASE_DIR, "assets", "models", "mixamo_ready")
CHAR_SRC_DIR = os.path.join(BASE_DIR, "assets", "models", "characters")

CT_GLB = os.path.join(CHAR_SRC_DIR, "counter_terrorist.glb")
T_GLB = os.path.join(CHAR_SRC_DIR, "terrorist.glb")

CT_CONFIGS = [
    {
        "id": "ct_urban",
        "name": "SEAL Team 6 (Urban)",
        "mesh_names": ["Object_394", "Object_395"],
        "materials": {
            "Material.007": "counter_terrorist_5.png",
            "Material.006": "counter_terrorist_6.png"
        }
    },
    {
        "id": "ct_sas",
        "name": "SAS (Special Air Service)",
        "mesh_names": ["Object_296", "Object_297"],
        "materials": {
            "Material.009": "counter_terrorist_3.png",
            "Material.008": "counter_terrorist_4.png"
        }
    },
    {
        "id": "ct_gsg9",
        "name": "GSG-9 (Antiterrorismo Alemao)",
        "mesh_names": ["Object_196"],
        "materials": {
            "Material.010": "counter_terrorist_2.png"
        }
    },
    {
        "id": "ct_gign",
        "name": "GIGN (Gendarmerie Francesa)",
        "mesh_names": ["Object_99", "Object_100"],
        "materials": {
            "Material.012": "counter_terrorist_0.png",
            "Material.011": "counter_terrorist_1.png"
        }
    }
]

T_CONFIGS = [
    {
        "id": "t_phoenix",
        "name": "Phoenix Connexion",
        "mesh_names": ["Object_447"],
        "materials": {
            "Material.017": "terrorist_4.png"
        }
    },
    {
        "id": "t_leet",
        "name": "Elite Crew (1337 Krew)",
        "mesh_names": ["Object_335", "Object_336"],
        "materials": {
            "Material.016": "terrorist_2.png",
            "Material.015": "terrorist_3.png"
        }
    },
    {
        "id": "t_guerilla",
        "name": "Guerilla Warfare",
        "mesh_names": ["Object_224"],
        "materials": {
            "Material.014": "terrorist_1.png"
        }
    },
    {
        "id": "t_arctic",
        "name": "Arctic Avengers",
        "mesh_names": ["Object_113"],
        "materials": {
            "Material.013": "terrorist_0.png"
        }
    }
]

def patch_mtl_textures(mtl_path, mat_to_tex):
    """Garante que map_Kd aponte para a imagem png e remove Ka/Ks estourados que causam excesso de brilho branco no Mixamo"""
    if not os.path.exists(mtl_path):
        return
        
    lines = []
    for mat_name, tex_file in mat_to_tex.items():
        lines.append(f"newmtl {mat_name}\n")
        lines.append("Ka 0.000000 0.000000 0.000000\n")  # Sem luz ambiente estourada
        lines.append("Kd 1.000000 1.000000 1.000000\n")  # Difuso limpo para a textura
        lines.append("Ks 0.000000 0.000000 0.000000\n")  # Sem brilho especular branco
        lines.append("Ns 10.000000\n")
        lines.append("d 1.000000\n")
        lines.append("illum 1\n")
        lines.append(f"map_Kd {tex_file}\n\n")
        
    with open(mtl_path, "w", encoding="utf-8") as f:
        f.writelines(lines)

def process_file_characters(glb_path, configs):
    for cfg in configs:
        char_id = cfg["id"]
        char_name = cfg["name"]
        print(f"\n========================================================")
        print(f"Processando: {char_id} ({char_name})")
        print(f"========================================================")
        
        # Recarregar cena limpa
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=glb_path)
        
        target_meshes = [bpy.data.objects[n] for n in cfg["mesh_names"] if n in bpy.data.objects]
        if not target_meshes:
            print(f"[ERRO] Malhas nao encontradas para {char_id}: {cfg['mesh_names']}")
            continue
            
        # Selecionar e duplicar as malhas
        bpy.ops.object.select_all(action='DESELECT')
        for obj in target_meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = target_meshes[0]
        
        bpy.ops.object.duplicate()
        dup_objs = list(bpy.context.selected_objects)
        
        # IMPORTANTE: Aplicar todos os modificadores (Armature / Skinning) em cada malha duplicada
        # Isso garante que a geometria estática fique no tamanho e pose corretos sem herdar escalonamento de ossos
        for obj in dup_objs:
            bpy.context.view_layer.objects.active = obj
            for m in list(obj.modifiers):
                try:
                    bpy.ops.object.modifier_apply(modifier=m.name)
                except Exception as e:
                    print(f"  [AVISO] Nao foi possivel aplicar modificador {m.name}: {e}")
                    
        # Desconectar hierarquia de pais mantendo a posicao mundial
        bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
        
        # Juntar em uma unica malha se houver mais de um objeto
        if len(dup_objs) > 1:
            bpy.ops.object.join()
        char_obj = bpy.context.view_layer.objects.active
        char_obj.name = char_id
        
        # Aplicar transforms pendentes
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        
        # Calcular bounds exatos da malha final
        verts = [v.co for v in char_obj.data.vertices]
        min_c = Vector((min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts)))
        max_c = Vector((max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts)))
        size = max_c - min_c
        
        center_x = (min_c.x + max_c.x) / 2
        center_y = (min_c.y + max_c.y) / 2
        min_z = min_c.z  # Pés apoiados no chão
        
        # Altura humana padrão do Mixamo: ~1.8088 metros
        scale_factor = 1.8088 / size.z
        print(f"  Bounds originais: size={size}, min_z={min_z:.3f}, scale_factor={scale_factor:.6f}")
        
        # Transformar vértices diretamente para garantir precisão absoluta
        for v in char_obj.data.vertices:
            v.co.x = (v.co.x - center_x) * scale_factor
            v.co.y = (v.co.y - center_y) * scale_factor
            v.co.z = (v.co.z - min_z) * scale_factor
        char_obj.data.update()
        
        v_check = [v.co for v in char_obj.data.vertices]
        print(f"  Bounds finais: X=[{min(v.x for v in v_check):.3f}, {max(v.x for v in v_check):.3f}], "
              f"Y=[{min(v.y for v in v_check):.3f}, {max(v.y for v in v_check):.3f}], "
              f"Z=[{min(v.z for v in v_check):.3f}, {max(v.z for v in v_check):.3f}]")
        
        # Criar pasta dedicada para este personagem
        char_dir = os.path.join(OUT_DIR, char_id)
        os.makedirs(char_dir, exist_ok=True)
        
        # Copiar texturas necessarias para a pasta do personagem
        copied_textures = []
        for mat_name, tex_file in cfg["materials"].items():
            src_tex = os.path.join(CHAR_SRC_DIR, tex_file)
            dst_tex = os.path.join(char_dir, tex_file)
            if os.path.exists(src_tex):
                shutil.copy2(src_tex, dst_tex)
                copied_textures.append(tex_file)
                print(f"  [Textura] Copiada: {tex_file}")
            else:
                print(f"  [AVISO] Textura nao encontrada: {src_tex}")
                
        # Exportar OBJ
        obj_path = os.path.join(char_dir, f"{char_id}.obj")
        bpy.ops.wm.obj_export(
            filepath=obj_path,
            export_selected_objects=True,
            export_materials=True,
            export_uv=True,
            export_normals=True,
            up_axis='Y',
            forward_axis='NEGATIVE_Z'
        )
        mtl_path = os.path.join(char_dir, f"{char_id}.mtl")
        patch_mtl_textures(mtl_path, cfg["materials"])
        print(f"  [OBJ] Exportado: {obj_path} ({os.path.getsize(obj_path):,} bytes)")
        
        # Exportar FBX
        fbx_path = os.path.join(char_dir, f"{char_id}.fbx")
        bpy.ops.export_scene.fbx(
            filepath=fbx_path,
            use_selection=True,
            object_types={'MESH'},
            mesh_smooth_type='FACE',
            apply_unit_scale=True,
            axis_forward='-Z',
            axis_up='Y'
        )
        print(f"  [FBX] Exportado: {fbx_path} ({os.path.getsize(fbx_path):,} bytes)")
        
        # Copiar para pastas gerais fbx/ e obj/
        fbx_general = os.path.join(OUT_DIR, "fbx", f"{char_id}.fbx")
        shutil.copy2(fbx_path, fbx_general)
        
        obj_general = os.path.join(OUT_DIR, "obj", f"{char_id}.obj")
        shutil.copy2(obj_path, obj_general)
        mtl_general = os.path.join(OUT_DIR, "obj", f"{char_id}.mtl")
        if os.path.exists(mtl_path):
            shutil.copy2(mtl_path, mtl_general)
        for tex_file in copied_textures:
            tex_gen = os.path.join(OUT_DIR, "obj", tex_file)
            if not os.path.exists(tex_gen):
                shutil.copy2(os.path.join(char_dir, tex_file), tex_gen)
                
        # Criar pacote ZIP pronto para arrastar no Mixamo (com OBJ + MTL + Texturas)
        zip_path = os.path.join(OUT_DIR, "zip", f"{char_id}.zip")
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(obj_path, f"{char_id}.obj")
            if os.path.exists(mtl_path):
                zf.write(mtl_path, f"{char_id}.mtl")
            for tex_file in copied_textures:
                zf.write(os.path.join(char_dir, tex_file), tex_file)
        print(f"  [ZIP] Pacote Mixamo criado: {zip_path} ({os.path.getsize(zip_path):,} bytes)")

def main():
    print("Iniciando exportacao corrigida de modelos CS:Source para Mixamo...")
    os.makedirs(os.path.join(OUT_DIR, "fbx"), exist_ok=True)
    os.makedirs(os.path.join(OUT_DIR, "obj"), exist_ok=True)
    os.makedirs(os.path.join(OUT_DIR, "zip"), exist_ok=True)
    
    print("\n>>> PROCESSANDO CONTRA-TERRORISTAS <<<")
    process_file_characters(CT_GLB, CT_CONFIGS)
    
    print("\n>>> PROCESSANDO TERRORISTAS <<<")
    process_file_characters(T_GLB, T_CONFIGS)
    
    print("\n========================================================")
    print("CONCLUIDO! Todos os modelos estao perfeitamente centrados e prontos para o Mixamo.")
    print(f"Pasta principal: {OUT_DIR}")
    print("========================================================")

if __name__ == "__main__":
    main()
