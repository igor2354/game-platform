shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 blur_pixels = vec2(0.0);
void fragment() {
    vec2 step_uv = blur_pixels * SCREEN_PIXEL_SIZE;
    vec4 sample_color = vec4(0.0);
    // Weighted symmetric shutter samples, preserving premultiplied group alpha.
    for (int i = -4; i <= 4; i++) {
        float weight = 5.0 - float(abs(i));
        sample_color += textureLod(screen_texture, SCREEN_UV + step_uv * (float(i) / 4.0), 0.0) * weight;
    }
    sample_color /= 25.0;
    if (sample_color.a > 0.0001) sample_color.rgb /= sample_color.a;
    COLOR *= sample_color;
}
