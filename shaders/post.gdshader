shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float aberration = 1.25;
uniform float vignette = 0.42;
uniform float injury = 0.0;
uniform bool effects_enabled = true;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = uv - 0.5;
    float edge = smoothstep(0.23, 0.7, length(center));
    vec2 shift = center * SCREEN_PIXEL_SIZE * aberration * edge * 2.0;
    vec3 col = texture(screen_texture, uv).rgb;
    if (effects_enabled) {
        col.r = texture(screen_texture, uv + shift).r;
        col.b = texture(screen_texture, uv - shift).b;
        col *= 1.0 - edge * vignette;
        col += (hash(uv * vec2(1440.0,900.0) + floor(TIME * 12.0)) - 0.5) * 0.008;
    }
    col = mix(col, vec3(0.45,0.045,0.025), edge * injury * 0.55);
    COLOR = vec4(col, 1.0);
}
