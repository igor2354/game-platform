shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength = 1.0;
uniform float pixel_size = 1.0;
uniform float contrast = 1.05;
uniform float gamma = 1.05;
uniform float shadow_lift = 0.045;
uniform float highlight_cap = 0.86;
uniform float red_strength = 1.0;
uniform float red_width = 12.0;
uniform float red_feather = 6.0;
uniform float red_saturation = 0.45;
uniform float red_brightness = 1.2;

void fragment() {
	vec2 uv = SCREEN_UV;
	if (pixel_size >= 2.0) {
		// Screen-anchored square blocks; do not blend neighbours when sampling.
		vec2 screen_pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
		uv = (floor(screen_pixel / pixel_size) * pixel_size + vec2(0.5 * pixel_size)) * SCREEN_PIXEL_SIZE;
		uv = clamp(uv, SCREEN_PIXEL_SIZE * 0.5, vec2(1.0) - SCREEN_PIXEL_SIZE * 0.5);
	}
	vec3 original = textureLod(screen_texture, uv, 0.0).rgb;
	float high = max(original.r, max(original.g, original.b));
	float low = min(original.r, min(original.g, original.b));
	float chroma = high - low;
	float saturation = chroma / max(high, 0.0001);
	float hue = 0.0;
	if (chroma > 0.0001) {
		if (high == original.r) hue = mod((original.g - original.b) / chroma, 6.0);
		else if (high == original.g) hue = (original.b - original.r) / chroma + 2.0;
		else hue = (original.r - original.g) / chroma + 4.0;
		hue = mod(hue + 6.0, 6.0) * 60.0;
	}
	float red_distance = min(hue, 360.0 - hue);
	float red_mask = (1.0 - smoothstep(red_width, red_width + red_feather, red_distance))
		* smoothstep(red_saturation, min(1.0, red_saturation + 0.1), saturation)
		* smoothstep(0.025, 0.1, high);
	float gray = dot(original, vec3(0.2126, 0.7152, 0.0722));
	gray = clamp((gray - 0.5) * contrast + 0.5, 0.0, 1.0);
	gray = pow(gray, 1.0 / max(gamma, 0.01));
	gray = mix(shadow_lift, highlight_cap, gray);
	// Preserve the shading of existing reds, but give the accent a clear scarlet hue.
	float red_value = clamp(high * red_brightness, 0.0, 1.0);
	vec3 scarlet = vec3(1.0, 0.035, 0.055) * red_value;
	vec3 filtered = mix(vec3(gray), scarlet, red_mask * red_strength);
	COLOR = vec4(mix(original, filtered, strength), 1.0);
}
