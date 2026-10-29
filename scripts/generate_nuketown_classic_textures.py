import os
import numpy as np
from PIL import Image, ImageFilter

OUT_DIR = "assets/textures/nuketown_classic"
os.makedirs(OUT_DIR, exist_ok=True)
SIZE = 1024

def save_normal_from_height(height_map, filepath, strength=2.5):
    # Sobel filters for normal map generation
    gx = np.zeros_like(height_map)
    gy = np.zeros_like(height_map)
    
    gx[:, 1:-1] = (height_map[:, 2:] - height_map[:, :-2]) * strength
    gx[:, 0] = (height_map[:, 1] - height_map[:, -1]) * strength
    gx[:, -1] = (height_map[:, 0] - height_map[:, -2]) * strength
    
    gy[1:-1, :] = (height_map[2:, :] - height_map[:-2, :]) * strength
    gy[0, :] = (height_map[1, :] - height_map[-1, :]) * strength
    gy[-1, :] = (height_map[0, :] - height_map[-2, :]) * strength
    
    gz = np.ones_like(height_map)
    norm = np.sqrt(gx**2 + gy**2 + gz**2)
    
    nx = ((gx / norm) * 0.5 + 0.5) * 255.0
    ny = ((-gy / norm) * 0.5 + 0.5) * 255.0  # OpenGL Y+
    nz = ((gz / norm) * 0.5 + 0.5) * 255.0
    
    normal_img = np.stack([nx, ny, nz], axis=2).astype(np.uint8)
    Image.fromarray(normal_img).save(filepath)

print("1. Generating Mint Green Siding (BO1 Green House)...")
# 16 horizontal planks (each 64px tall)
y_indices = np.arange(SIZE)[:, None]
plank_h = 64
plank_pos = (y_indices % plank_h) / float(plank_h)  # 0 at top, 1 at bottom of each plank

# Base mint green color: RGB(128, 170, 155)
base_col = np.array([126.0, 168.0, 152.0])
# Shadow at the bottom overlap edge of each plank
shadow = np.clip(1.0 - (plank_pos ** 8) * 0.45, 0.55, 1.0)
# Subtle wood grain noise
np.random.seed(42)
noise = np.random.normal(0, 1, (SIZE, SIZE))
noise_x = np.repeat(np.random.normal(0, 1, (SIZE, 128)), 8, axis=1) * 4.0

mint_diff = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
for c in range(3):
    mint_diff[:, :, c] = np.clip((base_col[c] + noise_x + noise * 3.0) * shadow, 0, 255)

Image.fromarray(mint_diff.astype(np.uint8)).save(os.path.join(OUT_DIR, "siding_mint_green.png"))

# Heightmap for siding: ramp upwards with sharp drop
height_siding = (1.0 - plank_pos.astype(np.float32)) + (noise * 0.03)
save_normal_from_height(height_siding, os.path.join(OUT_DIR, "siding_mint_green_norm.png"), strength=3.0)

print("2. Generating Vintage Yellow Siding (BO1 Yellow House)...")
# Base warm cream yellow: RGB(222, 202, 140)
base_yellow = np.array([222.0, 202.0, 138.0])
yellow_diff = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
for c in range(3):
    yellow_diff[:, :, c] = np.clip((base_yellow[c] + noise_x + noise * 3.0) * shadow, 0, 255)

Image.fromarray(yellow_diff.astype(np.uint8)).save(os.path.join(OUT_DIR, "siding_vintage_yellow.png"))
save_normal_from_height(height_siding, os.path.join(OUT_DIR, "siding_vintage_yellow_norm.png"), strength=3.0)

print("3. Generating Charcoal Roof Shingles...")
# Shingle rows of 48px, offset alternating rows by half-width (64px)
shingle_h = 48
shingle_w = 96
row_idx = y_indices // shingle_h
x_indices = np.arange(SIZE)[None, :]
x_offset = np.where((row_idx % 2) == 1, (x_indices + shingle_w // 2) % SIZE, x_indices)

shingle_x_pos = (x_offset % shingle_w)
shingle_y_pos = (y_indices % shingle_h)

# Slanted shadow per shingle
shingle_shade = (1.0 - (shingle_y_pos / float(shingle_h)) ** 6 * 0.4)
# Gap between vertical shingles
gap = np.where((shingle_x_pos < 3) | (shingle_y_pos < 3), 0.55, 1.0)

shingle_noise = np.random.normal(0, 7.0, (SIZE, SIZE))
base_roof = 68.0  # dark charcoal slate
roof_diff = np.clip((base_roof + shingle_noise) * shingle_shade * gap, 25, 230)
roof_rgb = np.stack([roof_diff, roof_diff * 1.02, roof_diff * 1.05], axis=2).astype(np.uint8)
Image.fromarray(roof_rgb).save(os.path.join(OUT_DIR, "roof_shingles_charcoal.png"))

height_roof = (1.0 - (shingle_y_pos / float(shingle_h))) * np.where(gap < 0.8, 0.2, 1.0)
save_normal_from_height(height_roof, os.path.join(OUT_DIR, "roof_shingles_norm.png"), strength=3.5)

print("4. Generating Red Brick Foundation/Chimney...")
# Bricks running bond: brick height 32, width 80
brick_h = 32
brick_w = 80
brow_idx = y_indices // brick_h
bx_offset = np.where((brow_idx % 2) == 1, (x_indices + brick_w // 2) % SIZE, x_indices)
bx_pos = bx_offset % brick_w
by_pos = y_indices % brick_h

mortar_mask = (bx_pos < 4) | (by_pos < 4)
# Brick color variation
brick_var = ((brow_idx * 17 + (bx_offset // brick_w) * 31) % 23) - 11.0
brick_noise = np.random.normal(0, 8.0, (SIZE, SIZE))

base_brick_r = 168.0 + brick_var + brick_noise
base_brick_g = 82.0 + brick_var * 0.7 + brick_noise * 0.8
base_brick_b = 60.0 + brick_var * 0.5 + brick_noise * 0.7

mortar_r = 185.0 + brick_noise * 0.5
mortar_g = 180.0 + brick_noise * 0.5
mortar_b = 172.0 + brick_noise * 0.5

r_ch = np.where(mortar_mask, mortar_r, base_brick_r)
g_ch = np.where(mortar_mask, mortar_g, base_brick_g)
b_ch = np.where(mortar_mask, mortar_b, base_brick_b)
brick_rgb = np.clip(np.stack([r_ch, g_ch, b_ch], axis=2), 0, 255).astype(np.uint8)
Image.fromarray(brick_rgb).save(os.path.join(OUT_DIR, "brick_wall_red.png"))

height_brick = np.where(mortar_mask, 0.2, 0.95 + brick_noise * 0.005)
save_normal_from_height(height_brick, os.path.join(OUT_DIR, "brick_wall_norm.png"), strength=3.5)

print("5. Generating White Picket Fence (clean enamel painted wood)...")
# Subtle vertical wood grain, soft eggshell white
fence_grain = np.repeat(np.random.normal(0, 1, (128, SIZE)), 8, axis=0) * 3.0
fence_noise = np.random.normal(0, 2, (SIZE, SIZE))
fence_val = np.clip(240.0 + fence_grain + fence_noise, 220, 255)
fence_rgb = np.stack([fence_val, fence_val * 0.99, fence_val * 0.97], axis=2).astype(np.uint8)
Image.fromarray(fence_rgb).save(os.path.join(OUT_DIR, "white_picket_fence.png"))

print("6. Generating Deck Wood Planks (Porch/Stairs)...")
# Wood planks along Y, plank width 48px
plank_w = 48
px_pos = x_indices % plank_w
p_seam = np.where(px_pos < 3, 0.65, 1.0)
wood_grain_y = np.repeat(np.random.normal(0, 1, (SIZE, 128)), 8, axis=1) * 8.0
wood_noise = np.random.normal(0, 4, (SIZE, SIZE))
base_wood_r = (168.0 + wood_grain_y + wood_noise) * p_seam
base_wood_g = (126.0 + wood_grain_y * 0.8 + wood_noise * 0.8) * p_seam
base_wood_b = (88.0 + wood_grain_y * 0.6 + wood_noise * 0.6) * p_seam
deck_rgb = np.clip(np.stack([base_wood_r, base_wood_g, base_wood_b], axis=2), 0, 255).astype(np.uint8)
Image.fromarray(deck_rgb).save(os.path.join(OUT_DIR, "deck_wood_planks.png"))

print("7. Generating Suburban Lawn Grass...")
grass_noise_large = np.array(Image.fromarray(np.random.normal(0, 1, (64, 64)).astype(np.float32)).resize((SIZE, SIZE), Image.BILINEAR)) * 14.0
grass_noise_fine = np.random.normal(0, 6, (SIZE, SIZE))
base_grass_r = np.clip(68.0 + grass_noise_large * 0.6 + grass_noise_fine, 35, 110)
base_grass_g = np.clip(124.0 + grass_noise_large + grass_noise_fine * 1.2, 70, 175)
base_grass_b = np.clip(52.0 + grass_noise_large * 0.5 + grass_noise_fine * 0.8, 25, 95)
grass_rgb = np.stack([base_grass_r, base_grass_g, base_grass_b], axis=2).astype(np.uint8)
Image.fromarray(grass_rgb).save(os.path.join(OUT_DIR, "suburban_lawn_grass.png"))

print("8. Generating Dark Asphalt Road...")
asph_noise = np.random.normal(0, 5, (SIZE, SIZE))
asph_grain = np.array(Image.fromarray(np.random.normal(0, 1, (256, 256)).astype(np.float32)).resize((SIZE, SIZE), Image.BILINEAR)) * 7.0
asph_val = np.clip(52.0 + asph_noise + asph_grain, 32, 78)
asph_rgb = np.stack([asph_val, asph_val * 1.01, asph_val * 1.03], axis=2).astype(np.uint8)
Image.fromarray(asph_rgb).save(os.path.join(OUT_DIR, "road_asphalt_dark.png"))
save_normal_from_height(asph_noise * 0.1, os.path.join(OUT_DIR, "road_asphalt_norm.png"), strength=2.0)

print("9. Generating Clean Concrete Sidewalk...")
conc_noise = np.random.normal(0, 4, (SIZE, SIZE))
conc_val = np.clip(185.0 + conc_noise, 150, 220)
# Pavement expansion joints every 256px
joint_mask = np.where((x_indices % 256 < 3) | (y_indices % 256 < 3), 0.72, 1.0)
conc_val = conc_val * joint_mask
conc_rgb = np.stack([conc_val, conc_val * 0.98, conc_val * 0.94], axis=2).astype(np.uint8)
Image.fromarray(conc_rgb).save(os.path.join(OUT_DIR, "sidewalk_concrete_clean.png"))

print("10. Generating White Garage Door...")
# 4 sectional horizontal panels with rectangular bevels
g_panel_h = 256
g_y_pos = y_indices % g_panel_h
g_seam = np.where(g_y_pos < 6, 0.7, 1.0)
g_val = np.clip((232.0 + np.random.normal(0, 2, (SIZE, SIZE))) * g_seam, 160, 255)
garage_rgb = np.stack([g_val, g_val * 0.99, g_val * 0.98], axis=2).astype(np.uint8)
Image.fromarray(garage_rgb).save(os.path.join(OUT_DIR, "garage_door_white.png"))

print("All Nuketown Classic textures generated successfully!")
