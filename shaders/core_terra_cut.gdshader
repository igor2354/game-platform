shader_type canvas_item;
uniform sampler2D terra_cut : filter_linear, repeat_disable;
uniform vec2 cut_origin;
uniform vec2 cut_size;
uniform sampler2D bullet_cut : filter_nearest, repeat_disable;
uniform vec2 bullet_origin;
uniform vec2 bullet_size=vec2(1.0);
uniform bool clip_enabled = false;
uniform vec2 clip_origin;
uniform vec2 clip_size;
varying vec2 terrain_world;
void vertex(){terrain_world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
	if (clip_enabled && (any(lessThan(terrain_world,clip_origin)) || any(greaterThanEqual(terrain_world,clip_origin+clip_size)))) discard;
	vec2 p=(terrain_world-cut_origin)/cut_size;
	float removed=0.0;
	if(all(greaterThanEqual(p,vec2(0.0)))&&all(lessThanEqual(p,vec2(1.0)))) removed=texture(terra_cut,p).r;
	vec2 b=(terrain_world-bullet_origin)/bullet_size;
	if(all(greaterThanEqual(b,vec2(0.0)))&&all(lessThanEqual(b,vec2(1.0)))) removed=max(removed,texture(bullet_cut,b).r);
	COLOR.a*=1.0-removed;
}
