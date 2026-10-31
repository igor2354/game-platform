shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sight_distances : filter_nearest, repeat_disable;
uniform bool fog_active = false;
uniform vec2 eye;
uniform vec2 gaze = vec2(1.0,0.0);
uniform float sight_max = 2000.0;
uniform float samples = 192.0;
uniform vec2 ranges = vec2(1800.0,600.0);
uniform vec2 half_angles = vec2(1.745,1.571);
uniform float near_range = 150.0;
varying vec2 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	vec4 color = COLOR;
	if (fog_active) {
		vec2 delta = world_position-eye;
		float distance_to_eye = length(delta);
		float alignment = dot(delta/max(distance_to_eye,0.0001),gaze);
		float allowed = near_range;
		if (alignment >= cos(half_angles.x)) allowed = max(allowed,ranges.x);
		if (-alignment >= cos(half_angles.y)) allowed = max(allowed,ranges.y);
		float slot = fract(atan(delta.y,delta.x)/6.28318530718+1.0)*samples;
		float a = texture(sight_distances,vec2((floor(slot)+0.5)/samples,0.5)).r;
		float b = texture(sight_distances,vec2((mod(floor(slot)+1.0,samples)+0.5)/samples,0.5)).r;
		// Use the nearer adjacent sample rather than smoothing an obstruction edge.
		allowed = min(allowed,min(a,b)*sight_max);
		color.a *= step(distance_to_eye,allowed+0.25);
	}
	COLOR = color;
}
