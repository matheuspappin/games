shader_type canvas_item;

// Heat haze / distorção de calor pós-nuclear sutil para o fundo do menu
uniform float distortion_strength : hint_range(0.0, 0.02) = 0.004;
uniform float wave_speed : hint_range(0.1, 3.0) = 0.8;
uniform float wave_frequency_x : hint_range(1.0, 20.0) = 8.0;
uniform float wave_frequency_y : hint_range(1.0, 20.0) = 6.0;
uniform float fade_top : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec2 uv = UV;

    // Fade: efeito mais forte na parte inferior (onde estaria o chão/fogo)
    float intensity = smoothstep(fade_top, 1.0, uv.y);

    // Ondulações de calor
    float wave_x = sin(uv.y * wave_frequency_x + TIME * wave_speed) * distortion_strength * intensity;
    float wave_y = cos(uv.x * wave_frequency_y + TIME * wave_speed * 0.7) * distortion_strength * 0.5 * intensity;

    vec2 distorted_uv = uv + vec2(wave_x, wave_y);

    COLOR = texture(TEXTURE, distorted_uv);
}
