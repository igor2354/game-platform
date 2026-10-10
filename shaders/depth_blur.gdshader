shader_type canvas_item;
uniform float blur_pixels = 2.0;
void fragment() {
    vec2 step_uv = TEXTURE_PIXEL_SIZE * blur_pixels;
    vec4 sum = texture(TEXTURE,UV) * 0.28;
    sum += texture(TEXTURE, UV + vec2(step_uv.x,0.0)) * 0.12;
    sum += texture(TEXTURE, UV - vec2(step_uv.x,0.0)) * 0.12;
    sum += texture(TEXTURE, UV + vec2(0.0,step_uv.y)) * 0.12;
    sum += texture(TEXTURE, UV - vec2(0.0,step_uv.y)) * 0.12;
    sum += texture(TEXTURE, UV + step_uv) * 0.11;
    sum += texture(TEXTURE, UV - step_uv) * 0.11;
    COLOR = sum * COLOR;
}
