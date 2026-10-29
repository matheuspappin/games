import struct
import json
import zipfile
import os

def inspect_glb(path):
    print(f"\n=== {path} ===")
    if not os.path.exists(path):
        print("File does not exist!")
        return
    with open(path, 'rb') as f:
        magic, version, length = struct.unpack('<4sII', f.read(12))
        chunk_len, chunk_type = struct.unpack('<II', f.read(8))
        json_data = json.loads(f.read(chunk_len).decode('utf-8'))
    
    print('Nodes count:', len(json_data.get('nodes', [])))
    print('Skins count:', len(json_data.get('skins', [])))
    for s in json_data.get('skins', []):
        print('  Skin:', s.get('name'), 'joints count:', len(s.get('joints', [])))
    
    anims = json_data.get('animations', [])
    print('Animations count:', len(anims))
    for a in anims:
        print('  Anim:', a.get('name'), 'channels:', len(a.get('channels', [])))
    
    nodes = json_data.get('nodes', [])
    print('Sample node names (first 15):')
    for i, n in enumerate(nodes[:15]):
        print(f"  [{i}] {n.get('name')} (mesh: {n.get('mesh')}, skin: {n.get('skin')}, rot: {n.get('rotation')}, trans: {n.get('translation')})")

def inspect_bones_only(path):
    with open(path, 'rb') as f:
        f.seek(12)
        chunk_len, _ = struct.unpack('<II', f.read(8))
        d = json.loads(f.read(chunk_len).decode('utf-8'))
    nodes = d.get('nodes', [])
    print(f"\n=== {path} bones: ===")
    for n in nodes:
        name = n.get('name', '')
        if any(k in name for k in ['Hips', 'Spine', 'RightHand', 'RightArm', 'Head']):
            print(name, "trans=", n.get('translation'), "rot=", n.get('rotation'))

inspect_bones_only('assets/models/mixamo/ct_urban.glb')

print("\nChecking zip contents in assets/models/mixamo_ready/zip:")
for zf in os.listdir('assets/models/mixamo_ready/zip'):
    if zf.endswith('.zip'):
        zpath = os.path.join('assets/models/mixamo_ready/zip', zf)
        with zipfile.ZipFile(zpath, 'r') as z:
            print(f"Zip: {zf} -> {z.namelist()}")
