shader_type canvas_item;

// Efeito de scanlines militares sutis + vinheta para o menu NukeFPS
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float scanline_opacity : hint_range(0.0, 0.3) = 0.05;
uniform float scanline_frequency : hint_range(100.0, 800.0) = 320.0;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.65;
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.95;
uniform vec4 vignette_color : source_color = vec4(0.01, 0.01, 0.02, 1.0);
uniform float chromatic_shift : hint_range(0.0, 3.0) = 0.6;

void fragment() {
    vec2 uv = SCREEN_UV;

    // Chromatic aberration sutil nas bordas
    float dist_from_center = length(uv - 0.5) * 2.0;
    float shift = chromatic_shift * dist_from_center * 0.0018;
    float r = texture(screen_texture, uv + vec2(shift, 0.0)).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - vec2(shift, 0.0)).b;
    vec3 col = vec3(r, g, b);

    // Scanlines horizontais (efeito CRT/monitor tático)
    float scanline = sin(uv.y * scanline_frequency * PI) * 0.5 + 0.5;
    col.rgb -= scanline_opacity * (1.0 - scanline);

    // Vinheta radial focando no centro e no operador
    float vignette = smoothstep(vignette_radius, vignette_radius - 0.5, dist_from_center);
    col.rgb = mix(vignette_color.rgb, col.rgb, vignette);

    COLOR = vec4(col, 1.0);
}
