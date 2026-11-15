shader_type canvas_item;
render_mode unshaded;
uniform sampler2D clean_background : filter_linear, repeat_disable;
// Diagnostic output: normal composite / background only / foliage only.
uniform int render_layer = 0;
uniform float animation_time = 0.0;
uniform float opacity = 1.0;
// Defaults preserve the original one-screen rendering; used by the wide master.
uniform float source_extent_x = 1.0;
uniform float right_fade_start = 1.0;
uniform float wind_strength = 1.0;
uniform float wind_speed = 1.0;
uniform float clouds_strength = 1.0;
uniform float clouds_speed = 1.0;
uniform float smoke_strength = 1.0;
uniform float smoke_speed = 1.0;
uniform float fire_strength = 1.0;
uniform float fire_speed = 1.0;
uniform float water_strength = 1.0;
uniform float water_speed = 1.0;

float band(float p,float a,float b,float feather) {
	return smoothstep(a,a+feather,p)*(1.0-smoothstep(b-feather,b,p));
}
float oval(vec2 p,vec2 c,vec2 r) {
	return 1.0-smoothstep(.65,1.0,length((p-c)/r));
}
float leaves(vec3 c) {
	// Include dark leaves and their edges, but exclude orange bark and neutral wood.
	float ratio = max(c.g,c.b)/max(c.r,.001);
	return (1.0-smoothstep(.32,.40,ratio))*smoothstep(.025,.075,c.r)*smoothstep(.01,.035,c.r-max(c.g,c.b));
}
float creek(vec2 p,vec3 c) {
	p.x *= source_extent_x;
	float area = oval(p,vec2(.70,.57),vec2(.045,.020));
	area = max(area,oval(p,vec2(.66,.61),vec2(.065,.021)));
	area = max(area,oval(p,vec2(.59,.666),vec2(.11,.030)));
	area = max(area,oval(p,vec2(.69,.705),vec2(.095,.024)));
	area = max(area,oval(p,vec2(.77,.755),vec2(.085,.025)));
	area = max(area,oval(p,vec2(.86,.815),vec2(.085,.024)));
	if (source_extent_x > 1.01) {
		area = max(area,oval(p,vec2(1.00,.81),vec2(.16,.055)));
		area = max(area,oval(p,vec2(1.19,.75),vec2(.17,.060)));
		area = max(area,oval(p,vec2(1.39,.83),vec2(.17,.065)));
		area = max(area,oval(p,vec2(1.59,.92),vec2(.18,.065)));
	}
	return area*smoothstep(.025,.075,c.b-c.r)*smoothstep(.20,.36,max(c.b,c.g));
}
float plume(vec2 p,vec2 foot,vec2 top,float width) {
	float rise = clamp((foot.y-p.y)/(foot.y-top.y),0.0,1.0);
	float center = mix(foot.x,top.x,rise);
	return (1.0-smoothstep(width*.4,width,abs(p.x-center)))*band(p.y,top.y,foot.y,.025)*smoothstep(0.0,.25,rise);
}
float leaf_alpha(vec2 p,vec3 color) {
	float fire_area = band(p.x*source_extent_x,.59,.83,.025)*band(p.y,.35,.47,.015);
	// Red reflections in the pool are not foliage.
	float water_area = creek(p,vec3(0.0,1.0,1.0));
	// Only the original pool has red reflections. New stream banks contain
	// actual red extraction leaves, which must not remain static/uncoloured.
	if (source_extent_x > 1.01) water_area *= 1.0-step(1.0,p.x*source_extent_x);
	return leaves(color)*(1.0-fire_area)*(1.0-water_area);
}
vec4 background_at(sampler2D original_texture,vec2 p,vec2 pixel) {
	p = clamp(p,vec2(0.0),vec2(1.0));
	vec4 painted = texture(original_texture,p);
	float cut = leaf_alpha(p,painted.rgb);
	// Clear the antialiased rim as well; do not leave a stationary red outline.
	cut = max(cut,leaf_alpha(p+vec2(pixel.x,0.0),texture(original_texture,p+vec2(pixel.x,0.0)).rgb));
	cut = max(cut,leaf_alpha(p-vec2(pixel.x,0.0),texture(original_texture,p-vec2(pixel.x,0.0)).rgb));
	cut = max(cut,leaf_alpha(p+vec2(0.0,pixel.y),texture(original_texture,p+vec2(0.0,pixel.y)).rgb));
	cut = max(cut,leaf_alpha(p-vec2(0.0,pixel.y),texture(original_texture,p-vec2(0.0,pixel.y)).rgb));
	cut = max(cut,leaf_alpha(p+pixel,texture(original_texture,p+pixel).rgb));
	cut = max(cut,leaf_alpha(p-pixel,texture(original_texture,p-pixel).rgb));
	cut = max(cut,leaf_alpha(p+vec2(pixel.x,-pixel.y),texture(original_texture,p+vec2(pixel.x,-pixel.y)).rgb));
	cut = max(cut,leaf_alpha(p+vec2(-pixel.x,pixel.y),texture(original_texture,p+vec2(-pixel.x,pixel.y)).rgb));
	cut = max(cut,leaf_alpha(p+vec2(2.0*pixel.x,0.0),texture(original_texture,p+vec2(2.0*pixel.x,0.0)).rgb));
	cut = max(cut,leaf_alpha(p-vec2(2.0*pixel.x,0.0),texture(original_texture,p-vec2(2.0*pixel.x,0.0)).rgb));
	cut = max(cut,leaf_alpha(p+vec2(0.0,2.0*pixel.y),texture(original_texture,p+vec2(0.0,2.0*pixel.y)).rgb));
	cut = max(cut,leaf_alpha(p-vec2(0.0,2.0*pixel.y),texture(original_texture,p-vec2(0.0,2.0*pixel.y)).rgb));
	if (cut <= .001) return painted;
	return mix(painted,texture(clean_background,p),smoothstep(.001,.05,cut));
}
void fragment() {
	vec2 p = UV;
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec4 original = texture(TEXTURE,p);
	vec2 effect_uv = vec2(p.x*source_extent_x,p.y);
	float fire_area = band(effect_uv.x,.59,.83,.025)*band(p.y,.35,.47,.015);
	float hot = fire_area*smoothstep(.10,.24,original.r-original.b)*smoothstep(.12,.24,original.g)*smoothstep(.35,.65,original.r);
	float wet = creek(p,original.rgb);
	float smoke = max(plume(effect_uv,vec2(.67,.40),vec2(.79,.19),.039),plume(effect_uv,vec2(.75,.405),vec2(.85,.245),.032));
	float moon = oval(effect_uv,vec2(.843,.135),vec2(.043,.065));
	float sky = band(p.y,-.1,.35,.03)*smoothstep(.025,.065,original.b-original.r)*smoothstep(.12,.22,max(original.r,original.g));
	sky *= (1.0-moon)*(1.0-smoke);
	vec4 scene = background_at(TEXTURE,p,pixel);
	float ct = animation_time*clouds_speed;
	vec2 cloud_offset = vec2(2.8*sin(ct*.24+p.y*13.0),.5*sin(ct*.17+p.x*7.0))*pixel*clouds_strength*sky;
	float st = animation_time*smoke_speed;
	vec2 smoke_offset = vec2(4.0*sin(p.y*47.0-st*1.1)+2.0*sin(p.y*91.0-st*1.7),2.5*sin(p.x*55.0+p.y*31.0-st*.9))*pixel*smoke_strength*smoke;
	if (sky*clouds_strength+smoke*smoke_strength > .0001) scene = background_at(TEXTURE,clamp(p+cloud_offset+smoke_offset,vec2(.001),vec2(.999)),pixel);
	float ft = animation_time*fire_speed;
	if (hot*fire_strength > .0001) {
		scene = background_at(TEXTURE,p+vec2(0.0,1.2*sin(ft*9.0+p.x*180.0))*pixel*fire_strength*hot,pixel);
		scene.rgb += scene.rgb*(.11*sin(ft*9.0+p.x*121.0)+.07*sin(ft*17.0+p.x*233.0))*fire_strength*hot;
	}
	float water_t = animation_time*water_speed;
	if (wet*water_strength > .0001) {
		vec2 water_offset = vec2(2.2*sin(p.y*270.0-water_t*2.8),.9*sin(p.x*180.0-water_t*1.6))*pixel*water_strength*wet;
		vec4 water_sample = background_at(TEXTURE,p+water_offset,pixel);
		scene = mix(scene,water_sample,step(.1,creek(p+water_offset,water_sample.rgb)));
		scene.rgb += vec3(.70,.78,.84)*sin(p.y*350.0-water_t*3.4+sin(p.x*85.0+water_t))*.045*wet*water_strength;
	}
	// Move an independent cutout across the clean plate, including its silhouette.
	// No destination-red mask: vacated pixels must show the plate, not old leaves.
	float wt = animation_time*wind_speed;
	vec2 wind_offset = vec2((sin(wt*1.25+p.y*9.0+p.x*13.0)+.35*sin(wt*2.6+p.x*37.0))*2.0,sin(wt*1.7+p.x*20.0)*.65)*pixel*wind_strength;
	vec2 leaf_uv = clamp(p+wind_offset,vec2(0.0),vec2(1.0));
	vec4 foliage = texture(TEXTURE,leaf_uv);
	float inside = step(0.0,p.x+wind_offset.x)*step(p.x+wind_offset.x,1.0)*step(0.0,p.y+wind_offset.y)*step(p.y+wind_offset.y,1.0);
	float alpha = leaf_alpha(leaf_uv,foliage.rgb)*inside;
	// Match dry grass beside the car in strip_00; preserve the leaf's tonal detail.
	float leaf_light = pow(max(foliage.r,0.0),.65);
	foliage.rgb = leaf_light*vec3(.53,.385,.21);
	float visibility = opacity;
	if (right_fade_start < 1.0) visibility *= 1.0-smoothstep(right_fade_start,1.0,p.x);
	if (render_layer == 1) COLOR = vec4(scene.rgb,scene.a*visibility);
	else if (render_layer == 2) COLOR = vec4(foliage.rgb,alpha*visibility);
	else COLOR = vec4(mix(scene.rgb,foliage.rgb,alpha),scene.a*visibility);
}
