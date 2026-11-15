shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sky_base : filter_linear, repeat_disable;
uniform sampler2D cloud_band : filter_linear, repeat_enable;
uniform float animation_time = 0.0;
uniform float wind_speed = 1.0;
uniform float cloud_density = 1.0;
uniform bool foundation_enabled = true;
varying vec2 world_point;

void vertex() {
	// Local world coordinates: never sampled from camera/screen position.
	world_point = VERTEX;
}

vec4 clouds_at(float period, float top, float offset, float speed) {
	vec2 uv = vec2(world_point.x/period+offset-animation_time*wind_speed*speed/period,
		(world_point.y-top)/(period/3.0));
	vec4 c = texture(cloud_band,vec2(fract(uv.x),clamp(uv.y,0.0,1.0)));
	// Transparent breathing room at the seam; never translate a sky rectangle.
	float edge = smoothstep(0.0,.03,fract(uv.x))*(1.0-smoothstep(.97,1.0,fract(uv.x)));
	c.a *= edge*step(0.0,uv.y)*step(uv.y,1.0);
	return c;
}

void fragment() {
	float mirror_x = 1.0-abs(mod(world_point.x/11000.0,2.0)-1.0);
	vec4 sky = texture(sky_base,vec2(mirror_x,clamp((world_point.y+2200.0)/3100.0,0.0,1.0)));
	vec4 far = clouds_at(6000.0,-1600.0,.17,8.0);
	vec4 near_clouds = clouds_at(4200.0,-1200.0,.43,16.0);
	far.a *= .62*cloud_density;
	near_clouds.a *= .85*cloud_density;
	vec3 color = mix(sky.rgb,far.rgb,far.a);
	color = mix(color,near_clouds.rgb,near_clouds.a);
	float alpha = foundation_enabled ? 1.0 : far.a+near_clouds.a*(1.0-far.a);
	if (!foundation_enabled) {
		color = (far.rgb*far.a*(1.0-near_clouds.a)+near_clouds.rgb*near_clouds.a)/max(alpha,.00001);
	}
	COLOR = vec4(color,alpha);
}
