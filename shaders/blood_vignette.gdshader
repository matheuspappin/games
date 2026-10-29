shader_type canvas_item;

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 blood_color : source_color = vec4(0.85, 0.03, 0.03, 1.0);
uniform vec4 dark_blood_color : source_color = vec4(0.28, 0.0, 0.0, 1.0);

// Hash pseudo-aleatório para respingos orgânicos nas bordas
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5);
	vec2 d = (uv - center) * 2.0;
	float dist = length(d);

	// Distorção orgânica de sangue estilo CoD Modern Warfare
	float angle = atan(d.y, d.x);
	float splatter = noise(vec2(angle * 3.5, dist * 5.0)) * 0.16 + noise(vec2(angle * 8.0, dist * 10.0)) * 0.07;
	float dist_noisy = dist + splatter;

	// Vinheta suave nas bordas da tela
	float vignette = smoothstep(0.68, 1.38, dist_noisy);

	// Fator de vida baixa (< 35%)
	float low_hp_factor = clamp((0.35 - health_ratio) / 0.35, 0.0, 1.0);

	// Combinação: flash imediato ao tomar dano + pulso persistente se vida estiver baixa
	float total_vignette = vignette * (flash_intensity * 0.85 + low_hp_factor * (0.45 + pulse_intensity * 0.45));
	total_vignette = clamp(total_vignette, 0.0, 0.90);

	// Cor entre sangue arterial vivo no impacto e sangue venoso escuro
	vec4 final_color = mix(dark_blood_color, blood_color, clamp(flash_intensity + pulse_intensity * 0.5, 0.0, 1.0));

	COLOR = vec4(final_color.rgb, total_vignette);
}
