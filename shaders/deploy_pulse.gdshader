shader_type canvas_item;

// Shader de pulso radioativo tático para o botão Deploy do NukeFPS
uniform float pulse_speed : hint_range(0.3, 4.0) = 1.6;
uniform float glow_intensity : hint_range(0.0, 1.5) = 0.7;
uniform vec4 glow_color_inner : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform vec4 glow_color_outer : source_color = vec4(1.0, 0.5, 0.05, 1.0);
uniform float edge_width : hint_range(0.01, 0.25) = 0.12;
uniform float radiation_bands : hint_range(0.0, 8.0) = 3.0;

void fragment() {
    // Preservar cor do StyleBoxFlat do botão
    vec3 base_col = COLOR.rgb;

    // Pulso sinusoidal
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float pulse_sec = sin(TIME * pulse_speed * 0.8 + 1.2) * 0.5 + 0.5;

    // Distância das bordas
    float edge_x = min(UV.x, 1.0 - UV.x);
    float edge_y = min(UV.y, 1.0 - UV.y);
    float edge_dist = min(edge_x, edge_y);
    float edge_glow = smoothstep(edge_width, 0.0, edge_dist);

    // Bandas sutis de energia radioativa
    float radiation = sin(UV.x * radiation_bands * PI + TIME * 2.2) * 0.5 + 0.5;
    radiation *= smoothstep(0.4, 0.0, edge_dist);

    // Gradiente de cor do glow
    vec3 glow = mix(glow_color_inner.rgb, glow_color_outer.rgb, edge_glow);

    // Misturar brilho radioativo na cor base
    vec3 final_rgb = base_col;
    final_rgb = mix(final_rgb, glow, edge_glow * pulse * glow_intensity);
    final_rgb += glow_color_inner.rgb * radiation * pulse_sec * 0.35;

    // Pulso geral no brilho
    final_rgb *= 1.0 + pulse * 0.12;

    COLOR = vec4(final_rgb, COLOR.a);
}
