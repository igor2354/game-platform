shader_type canvas_item;
uniform sampler2D anatomy_mask : filter_nearest, repeat_disable;
uniform vec4 hidden_a = vec4(0.0);
uniform vec2 hidden_b = vec2(0.0);
uniform int flash_part = 0;
uniform int isolated_part = 0;
varying vec4 frame_tint;
void vertex() {
	frame_tint = COLOR;
}
void fragment() {
	vec4 color = texture(TEXTURE, UV) * frame_tint;
	int part = int(round(texture(anatomy_mask, UV).r * 255.0));
	float hidden = 0.0;
	if (part == 1) hidden = hidden_a.x;
	if (part == 2) hidden = hidden_a.y;
	if (part == 3) hidden = hidden_a.z;
	if (part == 4) hidden = hidden_a.w;
	if (part == 5) hidden = hidden_b.x;
	if (part == 6) hidden = hidden_b.y;
	if (isolated_part > 0 && part != isolated_part) hidden = 1.0;
	if (flash_part > 0 && part == flash_part) color.rgb *= vec3(1.7,1.3,1.15);
	color.a *= 1.0-hidden;
	COLOR = color;
}
