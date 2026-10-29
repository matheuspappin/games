# =============================================================================
# weapon_visual_registry.gd
# Registro Central de Modelos 3D, Apresentação e Gunsmith Modular
# Fornece modelos individuais, alinhamento calibrado e montagem 3D de acessórios
# para todas as 18 armas do arsenal.
# =============================================================================
class_name WeaponVisualRegistry
extends RefCounted

# Dicionário de calibração e caminhos individuais por ID de arma
static var REGISTRY: Dictionary = {
	# ── FUZIS DE ASSALTO ──────────────────────────────────────────────────────
	"acr68": {
		"name": "ACR 6.8",
		"category": "ar",
		"scene": "res://scenes/weapons/modular/acr68.tscn",
		"scale": 0.52,
		"vm_scale": 0.98,
		"vm_offset": Vector3(1.6, 1.1, 10.2),
		"hip_offset": Vector3(-0.092, -0.315, 0.360),
		"ads_depth": -0.44,
		"ads_depth_optic": -0.38,
		"model_rotation": Vector3(0, 0, 0),
		"vm_rotation": Vector3(2.0, -2.5, 0.5),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0.0064, 0.1650, 0.0260),
		"socket_muzzle": Vector3(0.0064, 0.0430, -0.2750),
		"socket_mag": Vector3(0.0064, -0.0183, -0.0260),
		"socket_underbarrel": Vector3(0.0064, -0.0030, -0.1300),
		"socket_stock": Vector3(0.0064, 0.0430, 0.2300),
		"socket_rear_grip": Vector3(0.0064, -0.0290, 0.0780),
		"socket_iron_ads": Vector3(0.0064, 0.1820, 0.1832)
	},
	"ak47": {
		"name": "ACR 6.8",
		"category": "ar",
		"scene": "res://scenes/weapons/modular/acr68.tscn",
		"scale": 0.52,
		"vm_scale": 0.98,
		"vm_offset": Vector3(1.6, 1.1, 10.2),
		"hip_offset": Vector3(-0.092, -0.315, 0.360),
		"ads_depth": -0.44,
		"ads_depth_optic": -0.38,
		"model_rotation": Vector3(0, 0, 0),
		"vm_rotation": Vector3(2.0, -2.5, 0.5),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0.0064, 0.1650, 0.0260),
		"socket_muzzle": Vector3(0.0064, 0.0430, -0.2750),
		"socket_mag": Vector3(0.0064, -0.0183, -0.0260),
		"socket_underbarrel": Vector3(0.0064, -0.0030, -0.1300),
		"socket_stock": Vector3(0.0064, 0.0430, 0.2300),
		"socket_rear_grip": Vector3(0.0064, -0.0290, 0.0780),
		"socket_iron_ads": Vector3(0.0064, 0.1820, 0.1832)
	},
	"m4a1": {
		"name": "M4A1",
		"category": "ar",
		"scene": "res://scenes/weapons/modular/m4a1.tscn",
		"scale": 0.52,
		"vm_scale": 0.84,
		"vm_offset": Vector3(0.0, 2.2, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.092, -0.315, 0.360),
		"ads_depth": -0.36,
		"model_rotation": Vector3(-0.572, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0.0221, 0.1344, 0.0250),
		"socket_muzzle": Vector3(0.0221, 0.0653, -0.4250),
		"socket_mag": Vector3(0.0221, 0.0880, 0.0530),
		"socket_underbarrel": Vector3(0.0221, 0.0049, -0.1890),
		"socket_stock": Vector3(0.0221, 0.0450, 0.1516),
		"socket_rear_grip": Vector3(0.0221, -0.0404, 0.1470),
		"socket_iron_ads": Vector3(0.0221, 0.1595, 0.1694)
	},
	"scar_h": {
		"name": "SCAR-H",
		"category": "ar",
		"scene": "res://scenes/weapons/modular/scar_h.tscn",
		"scale": 0.53,
		"vm_scale": 0.88,
		"vm_offset": Vector3(0.0, 2.2, 3.2),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.092, -0.315, 0.360),
		"ads_depth": -0.36,
		"model_rotation": Vector3(0, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0, 0.0957, 0.0265),
		"socket_muzzle": Vector3(0, 0.0442, -0.2800),
		"socket_mag": Vector3(0, -0.0204, -0.0265),
		"socket_underbarrel": Vector3(0, -0.0042, -0.1325),
		"socket_stock": Vector3(0, 0.0442, 0.2350),
		"socket_rear_grip": Vector3(0, -0.0317, 0.0795),
		"socket_iron_ads": Vector3(0, 0.1490, 0.1829)
	},
	"man_o_war": {
		"name": "Man-O-War",
		"category": "ar",
		"scene": "res://scenes/weapons/modular/man_o_war.tscn",
		"scale": 0.53,
		"vm_scale": 0.86,
		"vm_offset": Vector3(0.0, 2.0, 3.0),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.092, -0.315, 0.360),
		"ads_depth": -0.36,
		"model_rotation": Vector3(0, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0, 0.1418, 0.0265),
		"socket_muzzle": Vector3(0, 0.0580, -0.2800),
		"socket_mag": Vector3(0, -0.0434, -0.0265),
		"socket_underbarrel": Vector3(0, -0.0180, -0.1325),
		"socket_stock": Vector3(0, 0.0580, 0.2350),
		"socket_rear_grip": Vector3(0, -0.0612, 0.0795),
		"socket_iron_ads": Vector3(0, 0.2218, 0.0552)
	},

	# ── SUBMETRALHADORAS ──────────────────────────────────────────────────────
	"mp7": {
		"name": "MP7",
		"category": "smg",
		"scene": "res://scenes/weapons/modular/mp7.tscn",
		"scale": 0.44,
		"vm_scale": 0.58,
		"vm_offset": Vector3(0.0, 1.5, 4.0),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.075, -0.280, 0.345),
		"ads_depth": -0.36,
		"model_rotation": Vector3(0, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(-0.0135, 0.1267, 0.0500),
		"socket_muzzle": Vector3(-0.0135, 0.0731, -0.2871),
		"socket_mag": Vector3(-0.0135, -0.0347, -0.0220),
		"socket_underbarrel": Vector3(-0.0135, -0.0128, -0.1100),
		"socket_stock": Vector3(-0.0135, 0.0528, 0.1900),
		"socket_rear_grip": Vector3(-0.0135, -0.0500, 0.0660),
		"socket_iron_ads": Vector3(-0.0135, 0.1504, 0.1447)
	},
	"pp90m1": {
		"name": "PP90M1",
		"category": "smg",
		"scene": "res://scenes/weapons/modular/pp90m1.tscn",
		"scale": 0.45,
		"vm_scale": 0.58,
		"vm_offset": Vector3(0.0, 1.2, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.075, -0.280, 0.345),
		"ads_depth": -0.36,
		"model_rotation": Vector3(180, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"hide_nodes": ["Icosphere"],
		"socket_optic": Vector3(-0.0032, 0.0790, 0.0000),
		"socket_muzzle": Vector3(-0.0032, 0.0545, -0.2764),
		"socket_mag": Vector3(-0.0032, -0.0400, -0.0700),
		"socket_underbarrel": Vector3(-0.0032, 0.0100, -0.1500),
		"socket_stock": Vector3(-0.0032, 0.0114, 0.2789),
		"socket_rear_grip": Vector3(-0.0032, -0.0450, 0.0500),
		"socket_iron_ads": Vector3(-0.0032, 0.0875, 0.0656)
	},
	"vmp": {
		"name": "VMP",
		"category": "smg",
		"scene": "res://scenes/weapons/modular/vmp.tscn",
		"scale": 0.46,
		"vm_scale": 0.60,
		"vm_offset": Vector3(0.0, 1.4, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.075, -0.280, 0.345),
		"ads_depth": -0.36,
		"model_rotation": Vector3(0, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"hide_nodes": ["Cartridge", "Cube.013_Cartridge_0"],
		"socket_optic": Vector3(0, 0.0908, 0.0230),
		"socket_muzzle": Vector3(0, 0.0427, -0.2450),
		"socket_mag": Vector3(0, -0.0179, -0.0230),
		"socket_underbarrel": Vector3(0, -0.0027, -0.1150),
		"socket_stock": Vector3(0, 0.0427, 0.2000),
		"socket_rear_grip": Vector3(0, -0.0285, 0.0690),
		"socket_iron_ads": Vector3(0, 0.1405, 0.0635)
	},
	"smg": {
		"name": "SMG-45",
		"category": "smg",
		"scene": "res://scenes/weapons/modular/smg.tscn",
		"scale": 0.46,
		"vm_scale": 0.60,
		"vm_offset": Vector3(0.0, 1.4, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.075, -0.280, 0.345),
		"ads_depth": -0.36,
		"model_rotation": Vector3(-1.981, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0.0062, 0.1352, -0.0200),
		"socket_muzzle": Vector3(0.0062, 0.0855, -0.2947),
		"socket_mag": Vector3(0.0062, -0.0400, -0.0800),
		"socket_underbarrel": Vector3(0.0062, 0.0200, -0.1600),
		"socket_stock": Vector3(0.0062, 0.0800, 0.2500),
		"socket_rear_grip": Vector3(0.0062, -0.0200, 0.0900),
		"socket_iron_ads": Vector3(0.0062, 0.1533, 0.0800)
	},
	"smg45": {
		"name": "SMG-45",
		"category": "smg",
		"scene": "res://scenes/weapons/modular/smg.tscn",
		"scale": 0.46,
		"vm_scale": 0.60,
		"vm_offset": Vector3(0.0, 1.4, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.075, -0.280, 0.345),
		"ads_depth": -0.36,
		"model_rotation": Vector3(-1.981, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0.0062, 0.1352, -0.0200),
		"socket_muzzle": Vector3(0.0062, 0.0855, -0.2947),
		"socket_mag": Vector3(0.0062, -0.0400, -0.0800),
		"socket_underbarrel": Vector3(0.0062, 0.0200, -0.1600),
		"socket_stock": Vector3(0.0062, 0.0800, 0.2500),
		"socket_rear_grip": Vector3(0.0062, -0.0200, 0.0900),
		"socket_iron_ads": Vector3(0.0062, 0.1533, 0.0800)
	},
	# ── ESCOPETAS ─────────────────────────────────────────────────────────────
	"spas12": {
		"name": "SPAS-12",
		"category": "shotgun",
		"scene": "res://scenes/weapons/modular/spas12.tscn",
		"scale": 0.54,
		"vm_scale": 0.84,
		"vm_offset": Vector3(0.0, 1.8, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.085, -0.300, 0.365),
		"ads_depth": -0.36,
		"model_rotation": Vector3(-1.556, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"hide_nodes": ["Object_4"],
		"socket_optic": Vector3(-0.0208, 0.0856, -0.1000),
		"socket_muzzle": Vector3(-0.0208, 0.0246, -0.4200),
		"socket_mag": Vector3(-0.0208, -0.0100, -0.0500),
		"socket_underbarrel": Vector3(-0.0208, -0.0150, -0.2000),
		"socket_stock": Vector3(-0.0208, 0.0500, 0.3500),
		"socket_rear_grip": Vector3(-0.0208, -0.0300, 0.1500),
		"socket_iron_ads": Vector3(-0.0208, 0.0878, 0.0800)
	},
	"krm262": {
		"name": "KRM-262",
		"category": "shotgun",
		"scene": "res://scenes/weapons/modular/krm262.tscn",
		"scale": 0.52,
		"vm_scale": 0.82,
		"vm_offset": Vector3(0.0, 1.6, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.085, -0.300, 0.365),
		"ads_depth": -0.36,
		"model_rotation": Vector3(0, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"hide_nodes": ["Icosphere"],
		"socket_optic": Vector3(0, 0.1085, 0.0260),
		"socket_muzzle": Vector3(0, 0.0481, -0.2750),
		"socket_mag": Vector3(0, -0.0268, -0.0260),
		"socket_underbarrel": Vector3(0, -0.0081, -0.1300),
		"socket_stock": Vector3(0, 0.0481, 0.2300),
		"socket_rear_grip": Vector3(0, -0.0398, 0.0780),
		"socket_iron_ads": Vector3(0, 0.1634, 0.3688)
	},
	"shotgun": {
		"name": "Sawnoff",
		"category": "shotgun",
		"scene": "res://scenes/weapons/modular/shotgun.tscn",
		"scale": 0.44,
		"vm_scale": 0.58,
		"vm_offset": Vector3(0.0, 1.4, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.085, -0.300, 0.365),
		"ads_depth": -0.36,
		"model_rotation": Vector3(0, 0, 180),
		"rotation_deg": Vector3(0, 85, 3),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0, 0.0889, -0.0500),
		"socket_muzzle": Vector3(0, 0.0712, -0.2900),
		"socket_mag": Vector3(0, 0.0200, 0.0170),
		"socket_underbarrel": Vector3(0, 0.0100, -0.1500),
		"socket_stock": Vector3(0, -0.0300, 0.2500),
		"socket_rear_grip": Vector3(0, -0.0500, 0.1200),
		"socket_iron_ads": Vector3(0, 0.0889, 0.0600)
	},
	"sawnoff": {
		"name": "Sawnoff",
		"category": "shotgun",
		"scene": "res://scenes/weapons/modular/shotgun.tscn",
		"scale": 0.44,
		"vm_scale": 0.58,
		"vm_offset": Vector3(0.0, 1.4, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.085, -0.300, 0.365),
		"ads_depth": -0.36,
		"model_rotation": Vector3(0, 0, 180),
		"rotation_deg": Vector3(0, 85, 3),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0, 0.0889, -0.0500),
		"socket_muzzle": Vector3(0, 0.0712, -0.2900),
		"socket_mag": Vector3(0, 0.0200, 0.0170),
		"socket_underbarrel": Vector3(0, 0.0100, -0.1500),
		"socket_stock": Vector3(0, -0.0300, 0.2500),
		"socket_rear_grip": Vector3(0, -0.0500, 0.1200),
		"socket_iron_ads": Vector3(0, 0.0889, 0.0600)
	},

	# ── METRALHADORAS LEVES ───────────────────────────────────────────────────
	"rpk": {
		"name": "RPK",
		"category": "lmg",
		"scene": "res://scenes/weapons/modular/rpk.tscn",
		"scale": 0.58,
		"vm_scale": 1.04,
		"vm_offset": Vector3(0.0, 2.2, 3.8),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.095, -0.315, 0.370),
		"ads_depth": -0.36,
		"model_rotation": Vector3(0, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"hide_nodes": [
			"545_20", "casing_545_17", "Object_44", "Object_45",
			"Object_52", "Object_53", "Object_54"
		],
		"socket_optic": Vector3(0, 0.1061, 0.0290),
		"socket_muzzle": Vector3(0, 0.0473, -0.3050),
		"socket_mag": Vector3(0, -0.0255, -0.0290),
		"socket_underbarrel": Vector3(0, -0.0073, -0.1450),
		"socket_stock": Vector3(0, 0.0473, 0.2600),
		"socket_rear_grip": Vector3(0, -0.0383, 0.0870),
		"socket_iron_ads": Vector3(0.0409, 0.0632, -0.0259)
	},
	"lmg": {
		"name": "LMG-63",
		"category": "lmg",
		"scene": "res://scenes/weapons/modular/lmg.tscn",
		"scale": 0.58,
		"vm_scale": 0.95,
		"vm_offset": Vector3(0.0, 1.8, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.095, -0.315, 0.370),
		"ads_depth": -0.36,
		"model_rotation": Vector3(-0.729, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0.0021, 0.1030, 0.0000),
		"socket_muzzle": Vector3(0.0021, 0.0733, -0.5000),
		"socket_mag": Vector3(-0.0400, 0.0000, 0.0200),
		"socket_underbarrel": Vector3(0.0021, 0.0200, -0.2000),
		"socket_stock": Vector3(0.0021, 0.0800, 0.4500),
		"socket_rear_grip": Vector3(0.0021, -0.0400, 0.1500),
		"socket_iron_ads": Vector3(0.0021, 0.1432, 0.1800)
	},
	"lmg63": {
		"name": "LMG-63",
		"category": "lmg",
		"scene": "res://scenes/weapons/modular/lmg.tscn",
		"scale": 0.58,
		"vm_scale": 0.95,
		"vm_offset": Vector3(0.0, 1.8, 3.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.095, -0.315, 0.370),
		"ads_depth": -0.36,
		"model_rotation": Vector3(-0.729, 0, 0),
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3(0.0021, 0.1030, 0.0000),
		"socket_muzzle": Vector3(0.0021, 0.0733, -0.5000),
		"socket_mag": Vector3(-0.0400, 0.0000, 0.0200),
		"socket_underbarrel": Vector3(0.0021, 0.0200, -0.2000),
		"socket_stock": Vector3(0.0021, 0.0800, 0.4500),
		"socket_rear_grip": Vector3(0.0021, -0.0400, 0.1500),
		"socket_iron_ads": Vector3(0.0021, 0.1432, 0.1800)
	},

	# ── FUZIS DE PRECISÃO (SNIPERS) ───────────────────────────────────────────
	# (Locus e DSR-50 removidos - aguardando inclusão da nova sniper)


	# ── SECUNDÁRIAS, PISTOLAS & CORPO A CORPO ─────────────────────────────────
	"deagle": {
		"name": ".50 GS Deagle",
		"category": "secondary",
		"scene": "res://scenes/weapons/modular/deagle.tscn",
		"scale": 0.38,
		"vm_scale": 0.28,
		"vm_offset": Vector3(0.0, 0.5, 1.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.060, -0.250, 0.320),
		"ads_depth": -0.34,
		"model_rotation": Vector3(0, 0, 0),
		"rotation_deg": Vector3(0, 85, 4),
		"y_offset": 0.015,
		"has_arms": false,
		"hide_nodes": ["Bullet_low", "BulletCase_low", "BulletThrow_low"],
		"socket_optic": Vector3(0, 0.1181, 0.0190),
		"socket_muzzle": Vector3(0, 0.0474, -0.2050),
		"socket_mag": Vector3(0, -0.0391, -0.0190),
		"socket_underbarrel": Vector3(0, -0.0174, -0.0950),
		"socket_stock": Vector3(0, 0.0474, 0.1600),
		"socket_rear_grip": Vector3(0, -0.0542, 0.0570),
		"socket_iron_ads": Vector3(0, 0.0905, 0.0880)
	},
	"pistol": {
		"name": "Pistola C19",
		"category": "secondary",
		"scene": "res://scenes/weapons/modular/pistol.tscn",
		"scale": 0.34,
		"vm_scale": 0.28,
		"vm_offset": Vector3(0.0, 0.5, 1.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.060, -0.250, 0.320),
		"ads_depth": -0.34,
		"model_rotation": Vector3(-2.764, 0, 0),
		"rotation_deg": Vector3(0, 85, 4),
		"y_offset": 0.015,
		"has_arms": false,
		"socket_optic": Vector3(0.0020, 0.0850, -0.0200),
		"socket_muzzle": Vector3(0.0020, 0.0550, -0.1950),
		"socket_mag": Vector3(0.0020, -0.0300, 0.0900),
		"socket_underbarrel": Vector3(0.0020, -0.0100, -0.0800),
		"socket_stock": Vector3(0.0020, 0.0100, 0.1700),
		"socket_rear_grip": Vector3(0.0020, -0.0400, 0.0600),
		"socket_iron_ads": Vector3(0.0020, 0.0845, 0.0800)
	},
	"c19": {
		"name": "Pistola C19",
		"category": "secondary",
		"scene": "res://scenes/weapons/modular/pistol.tscn",
		"scale": 0.34,
		"vm_scale": 0.28,
		"vm_offset": Vector3(0.0, 0.5, 1.5),
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.060, -0.250, 0.320),
		"ads_depth": -0.34,
		"model_rotation": Vector3(-2.764, 0, 0),
		"rotation_deg": Vector3(0, 85, 4),
		"y_offset": 0.015,
		"has_arms": false,
		"socket_optic": Vector3(0.0020, 0.0850, -0.0200),
		"socket_muzzle": Vector3(0.0020, 0.0550, -0.1950),
		"socket_mag": Vector3(0.0020, -0.0300, 0.0900),
		"socket_underbarrel": Vector3(0.0020, -0.0100, -0.0800),
		"socket_stock": Vector3(0.0020, 0.0100, 0.1700),
		"socket_rear_grip": Vector3(0.0020, -0.0400, 0.0600),
		"socket_iron_ads": Vector3(0.0020, 0.0845, 0.0800)
	},
	"knife": {
		"name": "Combat Knife",
		"category": "secondary",
		"scene": "res://scenes/weapons/modular/knife.tscn",
		"scale": 0.34,
		"vm_scale": 0.30,
		"vm_offset": Vector3.ZERO,
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.055, -0.220, 0.300),
		"ads_depth": -0.30,
		"model_rotation": Vector3(0, 90, 0),
		"rotation_deg": Vector3(0, 85, 4),
		"y_offset": 0.015,
		"has_arms": true,
		"socket_optic": Vector3.ZERO,
		"socket_muzzle": Vector3.ZERO,
		"socket_mag": Vector3.ZERO,
		"socket_underbarrel": Vector3.ZERO,
		"socket_stock": Vector3.ZERO,
		"socket_rear_grip": Vector3.ZERO,
		"socket_iron_ads": Vector3.ZERO
	}
}

# Cenas de acessórios 3D
const ATTACHMENT_SCENES: Dictionary = {
	"optic_red_dot": "res://scenes/weapons/attachments/optic_red_dot.tscn",
	"red_dot": "res://scenes/weapons/attachments/optic_red_dot.tscn",
	"optic_holo": "res://scenes/weapons/attachments/optic_holo.tscn",
	"holo": "res://scenes/weapons/attachments/optic_holo.tscn",
	"optic_acog": "res://scenes/weapons/attachments/optic_acog.tscn",
	"acog": "res://scenes/weapons/attachments/optic_acog.tscn",
	"optic_sniper": "res://scenes/weapons/attachments/optic_sniper.tscn",
	"sniper": "res://scenes/weapons/attachments/optic_sniper.tscn",
	"silencer": "res://scenes/weapons/attachments/muzzle_silencer.tscn",
	"muzzle_suppressor": "res://scenes/weapons/attachments/muzzle_silencer.tscn",
	"compensator": "res://scenes/weapons/attachments/muzzle_compensator.tscn",
	"muzzle_compensator": "res://scenes/weapons/attachments/muzzle_compensator.tscn",
	"extended": "res://scenes/weapons/attachments/mag_extended.tscn",
	"mag_extended": "res://scenes/weapons/attachments/mag_extended.tscn",
	"fast": "res://scenes/weapons/attachments/mag_fast.tscn",
	"mag_fast": "res://scenes/weapons/attachments/mag_fast.tscn",
	"fast_mag": "res://scenes/weapons/attachments/mag_fast.tscn",
	"grip_vertical": "res://scenes/weapons/attachments/grip_vertical.tscn",
	"vertical_grip": "res://scenes/weapons/attachments/grip_vertical.tscn",
	"grip_angled": "res://scenes/weapons/attachments/grip_angled.tscn",
	"angled_grip": "res://scenes/weapons/attachments/grip_angled.tscn",
	"stock_light": "res://scenes/weapons/attachments/stock_light.tscn",
	"stock_heavy": "res://scenes/weapons/attachments/stock_heavy.tscn",
	"grip_rubber": "res://scenes/weapons/attachments/grip_rear.tscn",
	"grip_stippled": "res://scenes/weapons/attachments/grip_rear.tscn"
}

# Mapeamento explícito de apelidos e identificadores para chaves primárias do registro
const ALIASES: Dictionary = {
	"acr68": "acr68",
	"acr": "acr68",
	"ak47": "acr68",
	"ak": "acr68",
	"ak-47": "acr68",
	"m4": "m4a1",
	"m4-a1": "m4a1",
	"sawnoff": "shotgun",
	"c19": "pistol",
	"pistol_m9": "pistol",
	"m9": "pistol",
	"smg45": "smg",
	"mp-7": "mp7",
	"lmg63": "lmg",
	"scarh": "scar_h",
	"scar": "scar_h",
	"manowar": "man_o_war",
	"spas": "spas12",
	"spas-12": "spas12",
	"krm": "krm262",
	"krm-262": "krm262",
	"pp90": "pp90m1",
	"pp-90m1": "pp90m1",
	"pp19": "pp90m1",
	"bizon": "pp90m1",
	"desert_eagle": "deagle",
	"deserteagle": "deagle",
	"faca": "knife"
}

# ── OBTENÇÃO DA CONFIGURAÇÃO DA ARMA ──────────────────────────────────────────
static func get_weapon_config(weapon_path_or_id: String) -> Dictionary:
	var key = _extract_key(weapon_path_or_id)
	if REGISTRY.has(key):
		return REGISTRY[key]
	
	# Fallback inteligente por categoria somente se houver correspondência exata de chave
	var p_low = weapon_path_or_id.to_lower()
	for k in REGISTRY.keys():
		if k == p_low or p_low.ends_with("/" + k) or p_low.ends_with("/" + k + ".tres"):
			return REGISTRY[k]

	# Fallback geral neutro isolado (NUNCA retorna REGISTRY["acr68"] para não contaminar outras armas)
	push_warning("[WeaponVisualRegistry] Arma '%s' não encontrada no registro! Usando configuração neutra isolada." % weapon_path_or_id)
	return {
		"name": "Arma Desconhecida",
		"category": "ar",
		"scene": "",
		"scale": 0.52,
		"vm_scale": 1.0,
		"vm_offset": Vector3.ZERO,
		"vm_rotation": Vector3.ZERO,
		"hip_offset": Vector3(-0.092, -0.315, 0.360),
		"ads_depth": -0.36,
		"model_rotation": Vector3.ZERO,
		"rotation_deg": Vector3(0, 80, 4),
		"y_offset": 0.02,
		"has_arms": false,
		"socket_optic": Vector3.ZERO,
		"socket_muzzle": Vector3.ZERO,
		"socket_mag": Vector3.ZERO,
		"socket_underbarrel": Vector3.ZERO,
		"socket_stock": Vector3.ZERO,
		"socket_rear_grip": Vector3.ZERO,
		"socket_iron_ads": Vector3.ZERO
	}

static func _extract_key(weapon_path_or_id: String) -> String:
	var clean = weapon_path_or_id.to_lower().strip_edges()
	clean = clean.replace(".tres", "").replace("res://resources/weapons/", "")
	
	# Verificar apelidos diretos primeiro
	if ALIASES.has(clean):
		return ALIASES[clean]
	
	if REGISTRY.has(clean):
		return clean
		
	var clean_no_underscores = clean.replace("_", "").replace("-", "")
	if ALIASES.has(clean_no_underscores):
		return ALIASES[clean_no_underscores]

	for k in REGISTRY.keys():
		var k_clean = k.replace("_", "").replace("-", "")
		if clean_no_underscores == k or clean_no_underscores == k_clean:
			return k
	return clean

# ── INSTANCIAÇÃO DA ARMA PARA VIEWMODEL DE 1ª PESSOA NAS MÃOS ─────────────────
static func instantiate_weapon_for_hand(weapon_path_or_id: String) -> Node3D:
	var cfg = get_weapon_config(weapon_path_or_id)
	var scene_path = cfg["scene"]
	if not ResourceLoader.exists(scene_path):
		return null

	var sc = load(scene_path) as PackedScene
	if not sc:
		return null

	var inst = sc.instantiate() as Node3D
	if not inst:
		return null

	# Aplicar rotação nativa do modelo para orientação canônica (frente = -Z)
	if cfg.has("model_rotation"):
		inst.rotation_degrees = cfg["model_rotation"]

	# Ocultar braços se existirem na malha
	if cfg.get("has_arms", false):
		_clean_arms_recursive(inst)

	# Ocultar nós indesejados da malha (ex: cartuchos avulsos como Object_4, 545_20)
	for n_name in cfg.get("hide_nodes", []):
		for n in inst.find_children("*" + n_name + "*", "", true, false):
			if n is Node3D or n is CanvasItem:
				n.visible = false

	_cache_base_materials_recursive(inst)

	var wrapper = Node3D.new()
	wrapper.name = "CustomWeaponModel"
	wrapper.set_meta("config", cfg)

	var pivot = Node3D.new()
	pivot.name = "Pivot"
	wrapper.add_child(pivot)
	pivot.add_child(inst)

	# Centralizar e calibrar a arma para escala real de 1ª pessoa nas mãos
	var aabb = _calc_visible_mesh_aabb(inst)
	var longest = aabb.get_longest_axis_size()
	var target_scale = cfg.get("vm_scale", cfg.get("scale", 0.52))
	var scale_mult = target_scale / max(longest, 0.001)

	inst.scale = Vector3.ONE * scale_mult
	inst.position = -aabb.get_center() * scale_mult
	inst.position.y += cfg.get("y_offset", 0.02)

	# Na hierarquia do Bytez fps-ak/fps-hands, o eixo Z local do nó 'base' aponta para frente (+Z).
	# Os modelos clean têm frente canônica em -Z, então rotacionamos 180° no eixo Y para apontar para +Z.
	var rot_y = cfg.get("vm_rot_y", 180.0)
	pivot.rotation_degrees = Vector3(0, rot_y, 0)
	if cfg.has("vm_rotation"):
		pivot.rotation_degrees += cfg["vm_rotation"]

	return wrapper

# ── INSTANCIAÇÃO DA ARMA COM LIMPEZA DE BRAÇOS E CENTRALIZAÇÃO ────────────────
static func instantiate_weapon_showcase(weapon_path_or_id: String) -> Node3D:
	var cfg = get_weapon_config(weapon_path_or_id)
	var scene_path = cfg["scene"]
	
	if not ResourceLoader.exists(scene_path):
		scene_path = "res://assets/models/fps_hands_rifle/scene.gltf"

	var sc = load(scene_path) as PackedScene
	if not sc:
		return null

	var inst = sc.instantiate() as Node3D
	if not inst:
		return null

	# Aplicar rotação nativa do modelo para orientação canônica (frente = -Z)
	if cfg.has("model_rotation"):
		inst.rotation_degrees = cfg["model_rotation"]

	# Ocultar malhas de braços se o modelo for do pack fps-hands
	if cfg.get("has_arms", false):
		_clean_arms_recursive(inst)

	# Ocultar nós indesejados da malha (ex: cartuchos avulsos como Object_4, 545_20)
	for n_name in cfg.get("hide_nodes", []):
		for n in inst.find_children("*" + n_name + "*", "", true, false):
			if n is Node3D or n is CanvasItem:
				n.visible = false

	# Fazer cache de materiais originais para que o camo default nunca apague
	_cache_base_materials_recursive(inst)

	# Container raiz padronizado
	var wrapper = Node3D.new()
	wrapper.name = "ShowcaseWeaponRoot"
	wrapper.set_meta("config", cfg)

	var pivot = Node3D.new()
	pivot.name = "Pivot"
	wrapper.add_child(pivot)
	pivot.add_child(inst)

	# Calcular AABB composto considerando transform inicial e centralizar
	var aabb = _calc_visible_mesh_aabb(inst)
	var longest = aabb.get_longest_axis_size()
	var target_scale = cfg.get("scale", 0.52)
	var scale_mult = target_scale / max(longest, 0.001)

	inst.scale = Vector3.ONE * scale_mult
	inst.position = -aabb.get_center() * scale_mult
	inst.position.y += cfg.get("y_offset", 0.02)

	# Aplicar orientação base de apresentação tática
	var rot_deg = cfg.get("rotation_deg", Vector3(0, 80, 4))
	pivot.rotation_degrees = rot_deg

	return wrapper

# ── ATUALIZAÇÃO MODULAR DE ACESSÓRIOS GUNSMITH EM TEMPO REAL ──────────────────
static func update_attachments(
	wrapper: Node3D,
	optic_id: String = "none",
	muzzle_id: String = "none",
	mag_id: String = "none",
	underbarrel_id: String = "none",
	stock_id: String = "none",
	grip_id: String = "none",
	barrel_id: String = "none"
) -> void:
	if not wrapper:
		return

	var cfg = wrapper.get_meta("config", {})
	if cfg.is_empty():
		return

	var pivot = wrapper.get_node_or_null("Pivot")
	if not pivot:
		return

	# Buscar a instância da arma dentro do Pivot (ou usar o pivot diretamente como fallback)
	var inst: Node3D = null
	for child in pivot.get_children():
		if child is Node3D and child.name != "AttachmentContainer":
			inst = child
			break
	var target_parent: Node3D = inst if inst else pivot

	# Nó container para anexar acessórios
	var att_container = target_parent.get_node_or_null("AttachmentContainer")
	if not att_container:
		att_container = Node3D.new()
		att_container.name = "AttachmentContainer"
		target_parent.add_child(att_container)
	else:
		for c in att_container.get_children():
			if c.is_inside_tree(): c.queue_free()
			else: c.free()

	# Se container estiver dentro da instância da arma, a escala relativa é 1.0 (a arma já aplica a escala apropriada)
	var att_scale = 1.0 if inst else (cfg.get("scale", 0.52) / 0.85)

	# 1. Mira Óptica (Optic)
	if optic_id != "none" and optic_id != "optic_iron" and ATTACHMENT_SCENES.has(optic_id):
		var socket_pos = _find_or_get_socket(target_parent, "SocketOptic", cfg.get("socket_optic", Vector3(0, 0.12, 0)))
		_spawn_attachment(att_container, ATTACHMENT_SCENES[optic_id], socket_pos, att_scale)

	# 2. Boca / Silenciador / Compensador (Muzzle)
	if muzzle_id != "none" and ATTACHMENT_SCENES.has(muzzle_id):
		var socket_pos = _find_or_get_socket(target_parent, "SocketMuzzle", cfg.get("socket_muzzle", Vector3(0, 0.02, -0.28)))
		_spawn_attachment(att_container, ATTACHMENT_SCENES[muzzle_id], socket_pos, att_scale)

	# 3. Carregador Estendido / Rápido (Mag)
	if mag_id != "none" and ATTACHMENT_SCENES.has(mag_id):
		var socket_pos = _find_or_get_socket(target_parent, "SocketMag", cfg.get("socket_mag", Vector3(0, -0.12, 0)))
		_spawn_attachment(att_container, ATTACHMENT_SCENES[mag_id], socket_pos, att_scale)

	# 4. Empunhadura Frontal / Underbarrel (Grip Vertical / Angled)
	if underbarrel_id != "none" and ATTACHMENT_SCENES.has(underbarrel_id):
		var socket_pos = _find_or_get_socket(target_parent, "SocketUnderbarrel", cfg.get("socket_underbarrel", Vector3(0, -0.06, -0.12)))
		_spawn_attachment(att_container, ATTACHMENT_SCENES[underbarrel_id], socket_pos, att_scale)

	# 5. Coronha Tática / Stock (Light / Heavy)
	if stock_id != "none" and ATTACHMENT_SCENES.has(stock_id):
		var socket_pos = _find_or_get_socket(target_parent, "SocketStock", cfg.get("socket_stock", Vector3(0, 0.06, 0.22)))
		_spawn_attachment(att_container, ATTACHMENT_SCENES[stock_id], socket_pos, att_scale)

	# 6. Cabo Traseiro / Rear Grip (Rubber / Stippled)
	if grip_id != "none" and ATTACHMENT_SCENES.has(grip_id):
		var socket_pos = _find_or_get_socket(target_parent, "SocketRearGrip", cfg.get("socket_rear_grip", Vector3(0, -0.10, 0.05)))
		_spawn_attachment(att_container, ATTACHMENT_SCENES[grip_id], socket_pos, att_scale)

	# Controle dinâmico unificado: Ocultar peças nativas (miras, magazine, coronha, boca, cabo) quando substituídas
	update_integrated_weapon_parts(target_parent, optic_id, muzzle_id, mag_id, underbarrel_id, stock_id, grip_id)

# ── CONTROLE DINÂMICO UNIFICADO DE PEÇAS ORIGINAIS DA ARMA ────────────────────
static func update_integrated_weapon_parts(
	root: Node3D,
	optic_id: String,
	muzzle_id: String,
	mag_id: String = "none",
	underbarrel_id: String = "none",
	stock_id: String = "none",
	grip_id: String = "none"
) -> void:
	if not root:
		return

	var has_optic = (optic_id != "none" and optic_id != "" and optic_id != "optic_iron")
	var has_muzzle = (muzzle_id != "none" and muzzle_id != "")
	var has_mag = (mag_id != "none" and mag_id != "")
	var has_underbarrel = (underbarrel_id != "none" and underbarrel_id != "")
	var has_stock = (stock_id != "none" and stock_id != "")
	var has_grip = (grip_id != "none" and grip_id != "")

	# Padrões de miras de ferro, lunetas e alças de mira nativas a ocultar quando optic != none
	var sight_patterns = [
		"rear sight", "rear_sight", "rearsight", "sight_base", "sight base", "sight_cam",
		"sight cam", "windage", "sight_eotech", "eotech", "rifle_scope",
		"integratedscope", "heavyscope", "object_14", "carryhandle", "ironsight",
		"front sight", "front_sight", "object_2", "object_24"
	]

	# Padrões de quebra-chamas, compensadores e silenciadores nativos a ocultar quando muzzle != none
	var muzzle_patterns = [
		"muzzle_brake", "compensator__0", "crush washer", "rifle_silencer",
		"flashlight", "object_13", "object_59", "muzzlebreak_mat_0"
	]

	# Padrões de carregadores nativos a ocultar quando um novo magazine for equipado
	var mag_patterns = [
		"clip_smg45_0", "magazine_acr", "magazine box__0", "mag_scar", "rifle_mag",
		"cube.013_cartridge_0", "magazine_low", "mag_lmg", "clip_mat_0",
		"magazine bottom plate__0", "magazine follower__0", "magazine spring__0",
		"object_56", "object_57", "object_32", "object_34", "object_18", "object_5"
	]

	# Padrões de coronhas nativas a ocultar quando coronha tática for equipada
	var stock_patterns = [
		"sliding buttstock__0", "buttstock release lever", "buttstock spring pin",
		"lock pin nut", "sliding buttstock", "buttstock", "object_8", "stock_2"
	]

	# Padrões de foregrips nativos a ocultar quando underbarrel for equipado
	var underbarrel_patterns = [
		"vertical pistol grip__0", "vertical pistol grip lock", "polysurface82_handle_mat_0"
	]

	# Padrões de grips traseiros nativos a ocultar quando rear grip for equipado
	var grip_patterns = [
		"pistol grip__0", "grip_low_mainbody_0", "object_33", "object_34"
	]

	for child in root.find_children("*", "Node3D", true, false):
		# 1. Checagem direta de nós modulares estruturados
		if child.has_meta("part_type"):
			var p_type = child.get_meta("part_type")
			match p_type:
				"magazine":
					child.visible = not has_mag
					continue
				"stock":
					child.visible = not has_stock
					continue
				"sight":
					child.visible = not has_optic
					continue
				"muzzle":
					child.visible = not has_muzzle
					continue
				"underbarrel":
					child.visible = not has_underbarrel
					continue
				"rear_grip":
					child.visible = not has_grip
					continue

		var c_name = child.name
		if c_name == "Magazine":
			child.visible = not has_mag
			continue
		elif c_name == "Stock":
			child.visible = not has_stock
			continue
		elif c_name == "Sight":
			child.visible = not has_optic
			continue
		elif c_name == "Muzzle":
			child.visible = not has_muzzle
			continue
		elif c_name == "Underbarrel":
			child.visible = not has_underbarrel
			continue
		elif c_name == "RearGrip":
			child.visible = not has_grip
			continue

		# 2. Fallback inteligente recursivo por substrings
		var n_low = c_name.to_lower()
		
		# Miras
		for pat in sight_patterns:
			if pat in n_low:
				child.visible = not has_optic
				break

		# Bocas
		for pat in muzzle_patterns:
			if pat in n_low:
				child.visible = not has_muzzle
				break

		# Carregadores
		for pat in mag_patterns:
			if pat in n_low:
				child.visible = not has_mag
				break

		# Coronhas
		for pat in stock_patterns:
			if pat in n_low:
				child.visible = not has_stock
				break

		# Foregrips
		for pat in underbarrel_patterns:
			if pat in n_low:
				child.visible = not has_underbarrel
				break

		# Rear grips
		for pat in grip_patterns:
			if pat in n_low:
				child.visible = not has_grip
				break

# Alias de compatibilidade retroativa
static func update_integrated_sights_and_muzzle(root: Node3D, optic_id: String, muzzle_id: String) -> void:
	update_integrated_weapon_parts(root, optic_id, muzzle_id)

static func _find_or_get_socket(root: Node3D, socket_name: String, fallback_pos: Vector3) -> Vector3:
	var marker = root.find_child(socket_name, true, false) as Marker3D
	if marker:
		return marker.position
	return fallback_pos

static func _spawn_attachment(parent: Node3D, scene_path: String, pos: Vector3, att_scale: float = 1.0) -> Node3D:
	if not ResourceLoader.exists(scene_path):
		return null
	var sc = load(scene_path) as PackedScene
	if not sc:
		return null
	var inst = sc.instantiate() as Node3D
	if inst:
		inst.position = pos
		inst.scale = Vector3.ONE * att_scale
		parent.add_child(inst)
	return inst

# ── APLICAÇÃO DE CAMUFLAGEM PBR E RESTAURAÇÃO BASE ────────────────────────────
static func apply_camo(wrapper: Node3D, camo_key: String) -> void:
	if not wrapper:
		return

	# Se for o padrão "Militar Padrão" ou vazio, restaurar os materiais originais autênticos
	if camo_key == "default" or camo_key.is_empty():
		_restore_materials_recursive(wrapper)
		return

	var mat: StandardMaterial3D = null
	match camo_key:
		"gold":
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.82, 0.25)
			mat.metallic = 0.95
			mat.roughness = 0.18
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.3, 0.05)
		"dark_matter":
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.18, 0.05, 0.32)
			mat.metallic = 0.8
			mat.roughness = 0.2
			mat.emission_enabled = true
			mat.emission = Color(0.65, 0.1, 0.85)
			mat.emission_energy_multiplier = 1.6
		"carbon":
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.14, 0.15, 0.18)
			mat.metallic = 0.5
			mat.roughness = 0.35
		_:
			_restore_materials_recursive(wrapper)
			return

	_apply_material_recursive(wrapper, mat)

static func _cache_base_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		mi.set_meta("base_material_override", mi.material_override)
	for child in node.get_children():
		_cache_base_materials_recursive(child)

static func _restore_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		if mi.has_meta("base_material_override"):
			mi.material_override = mi.get_meta("base_material_override")
		else:
			mi.material_override = null
	for child in node.get_children():
		_restore_materials_recursive(child)

static func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D and node.visible:
		# Não substituir lentes de vidro ou leds de mira para manter retículos visíveis
		var n_low = node.name.to_lower()
		if not ("glass" in n_low or "lens" in n_low or "reticle" in n_low or "led" in n_low):
			node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

# ── UTILITÁRIOS INTERNOS ──────────────────────────────────────────────────────
static func _clean_arms_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var n_low = node.name.to_lower()
		var m_name = node.mesh.resource_name.to_lower() if node.mesh else ""
		if "arm" in n_low or "hand" in n_low or "pole" in n_low or "wrist" in n_low or "arm" in m_name:
			node.visible = false
	for child in node.get_children():
		_clean_arms_recursive(child)

static func _calc_visible_mesh_aabb(root: Node3D) -> AABB:
	var total = AABB()
	var first = true
	var stack: Array = [[root, root.transform]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var curr = item[0]
		var tf: Transform3D = item[1]
		if curr is MeshInstance3D and curr.visible and curr.mesh:
			var mi = curr as MeshInstance3D
			var mesh_aabb = tf * mi.get_aabb()
			if first:
				total = mesh_aabb
				first = false
			else:
				total = total.merge(mesh_aabb)
		for c in curr.get_children():
			if c is Node3D:
				stack.append([c, tf * c.transform])
			else:
				stack.append([c, tf])
	return total
