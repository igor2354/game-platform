shader_type canvas_item;
render_mode unshaded;
uniform vec2 room_size = vec2(920.0,232.0);
uniform vec2 lamp_position = vec2(440.0,38.0);
uniform float radius = 680.0;
uniform float energy = 1.0;
uniform float ambient = 0.0;
void fragment() {
	float distance_to_lamp = length(UV*room_size-lamp_position);
	float light = clamp(ambient+energy*(1.0-smoothstep(radius*.65,radius,distance_to_lamp)),0.0,1.0);
	COLOR = vec4(vec3(.012,.022,.032),.80*(1.0-light));
}
