shader_type spatial;
render_mode unshaded, cull_disabled;

// =============================================================================
// pip_scope_lens.gdshader
// Shader de Lente Picture-in-Picture (Dual Render) Estilo Modern Warfare (2019+)
// Projeta a cena ampliada da câmera secundária do SubViewport com aberração
// ótica nas bordas, sombra ocular (eye relief vignette) e retículo iluminado.
// =============================================================================

uniform sampler2D scope_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D reticle_texture : source_color, filter_linear, repeat_disable;
uniform vec4 reticle_color : source_color = vec4(1.0, 0.15, 0.15, 1.0);
uniform float reticle_scale : hint_range(0.2, 3.0) = 1.0;
uniform float reticle_energy : hint_range(0.5, 5.0) = 2.0;

uniform float vignette_radius : hint_range(0.2, 0.55) = 0.485;
uniform float vignette_feather : hint_range(0.01, 0.2) = 0.04;
uniform float edge_distortion : hint_range(0.0, 0.5) = 0.12;

uniform vec2 parallax_offset = vec2(0.0, 0.0);
uniform vec4 lens_tint : source_color = vec4(0.88, 0.95, 1.0, 1.0);
uniform float lens_tint_strength : hint_range(0.0, 0.3) = 0.05;

// Controle de ADS (0.0 = desligado/escuro, 1.0 = visão total nítida)
uniform float ads_blend : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 offset = UV - center;
    float dist = length(offset);

    // 1. Distorção esférica sutil de lente (Barrel Distortion de ótica de precisão)
    float r2 = dist * dist;
    vec2 distorted_uv = center + offset * (1.0 + edge_distortion * r2);

    // 2. Amostrar imagem do SubViewport com zoom
    vec4 scene_sample = texture(scope_texture, distorted_uv);

    // 3. Eye Relief Vignette (Scope Shadow escura nas bordas do tubo da luneta)
    float vignette = smoothstep(vignette_radius, vignette_radius - vignette_feather, dist);

    // 4. Parallax e Retículo Tático
    vec2 ret_uv = center + (offset + parallax_offset) / reticle_scale;
    vec4 reticle_sample = vec4(0.0);
    if (ret_uv.x >= 0.0 && ret_uv.x <= 1.0 && ret_uv.y >= 0.0 && ret_uv.y <= 1.0) {
        reticle_sample = texture(reticle_texture, ret_uv);
    }

    // 5. Composição de Cor
    // Tint anti-reflexo ótico leve
    vec3 base_scene = mix(scene_sample.rgb, scene_sample.rgb * lens_tint.rgb, lens_tint_strength);

    // Mesclar retículo com a cor configurada e energia de iluminação
    vec3 ret_col = reticle_color.rgb * reticle_energy;
    vec3 composite = mix(base_scene, ret_col, reticle_sample.a * reticle_color.a);

    // Aplicar a vinheta escura da borda do tubo
    composite *= vignette;

    // Quando não estiver mirando, esmaecer suavemente para manter a ilusão
    composite *= mix(0.15, 1.0, ads_blend);

    // Se estiver fora do raio da lente, renderiza o interior escuro do tubo da luneta
    if (dist > vignette_radius) {
        composite = vec3(0.02, 0.02, 0.03); // Aço escuro fosco do tubo
    }

    ALBEDO = composite;
    ALPHA = 1.0;
}
