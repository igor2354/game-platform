shader_type canvas_item;
render_mode unshaded;
uniform vec2 world_origin = vec2(12000.0,760.0);
uniform float texture_units = 1.0097598;
varying vec2 ground_position;

void vertex() {
	ground_position = VERTEX;
}
void fragment() {
	// Reuse an opaque soil-only patch of the existing approved gameplay strip.
	// Mirrored sampling avoids a hard tile seam; projection stays fixed in world.
	vec2 local = (ground_position-world_origin)/texture_units;
	vec2 tile = 1.0-abs(mod(local/vec2(512.0,96.0),2.0)-1.0);
	vec2 uv = (vec2(640.0,1110.0)+tile*vec2(512.0,96.0))*TEXTURE_PIXEL_SIZE;
	vec3 earth = texture(TEXTURE,uv).rgb;
	float depth = smoothstep(300.0,1100.0,ground_position.y-world_origin.y);
	COLOR = vec4(earth*(1.0-.20*depth),1.0);
}
