shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1600.0,900.0);
uniform float art_top = 90.0;
uniform float art_height = 716.0;
uniform float animation_time = 0.0;
uniform float opacity = 1.0;
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

float oval(vec2 p,vec2 center,vec2 radius) {
	return 1.0-smoothstep(0.65,1.0,length((p-center)/radius));
}
float band(float p,float start,float end,float feather) {
	return smoothstep(start,start+feather,p)*(1.0-smoothstep(end-feather,end,p));
}
float red_ink(vec3 c) {
	return smoothstep(0.07,0.25,c.r-max(c.g,c.b))*smoothstep(0.14,0.5,c.r);
}
float smoke_column(vec2 p,vec2 foot,vec2 top,float width) {
	float height = foot.y-top.y;
	float rise = clamp((foot.y-p.y)/height,0.0,1.0);
	float center = mix(foot.x,top.x,rise);
	return (1.0-smoothstep(width*0.35,width,abs(p.x-center)))*band(p.y,top.y,foot.y,0.02);
}
float water_area(vec2 p) {
	// Follow the painted creek, leaving the paths, bridge and rocks rigid.
	float a = oval(p,vec2(0.58,0.966),vec2(0.115,0.044));
	float b = oval(p,vec2(0.668,0.918),vec2(0.075,0.030));
	float c = oval(p,vec2(0.746,0.867),vec2(0.074,0.025));
	float d = oval(p,vec2(0.790,0.814),vec2(0.070,0.023));
	return max(max(a,b),max(c,d));
}
void fragment() {
	vec2 source_size = vec2(1672.0,941.0);
	float art_width = art_height*source_size.x/source_size.y;
	vec2 p = vec2((UV.x*viewport_size.x-(viewport_size.x-art_width)*0.5)/art_width,(UV.y*viewport_size.y-art_top)/art_height);
	float inside = step(0.0,p.y)*(1.0-smoothstep(0.997,1.0,p.y));
	// Preserve the whole illustration: softly fade side margins, with no
	// stretched trees or duplicated city/moon outside the original frame.
	inside *= smoothstep(0.0,0.025,p.x)*(1.0-smoothstep(0.975,1.0,p.x));
	p = clamp(p,vec2(0.002),vec2(0.998));
	vec4 original = texture(TEXTURE,p);
	vec2 pixel = 1.0/source_size;
	float creek = water_area(p);
	float city = band(p.x,0.62,0.91,0.025)*band(p.y,0.263,0.40,0.025);
	float foliage = red_ink(original.rgb)*(1.0-city)*(1.0-creek);
	// The user approved the red-leaf motion, not swaying whole tree silhouettes.
	// Warm bark and dark wood must never inherit the broad canopy displacement.
	float leaf_only = 1.0-smoothstep(0.34,0.38,max(original.g,original.b)/max(original.r,0.001));
	float pine = max(oval(p,vec2(0.29,0.19),vec2(0.07,0.24)),oval(p,vec2(0.46,0.24),vec2(0.06,0.22)));
	pine = max(pine,oval(p,vec2(0.56,0.38),vec2(0.045,0.13)));
	float wind = animation_time*wind_speed;
	vec2 offset = vec2(0.0);
	offset.x += (sin(wind*1.25+p.y*9.0+p.x*13.0)+0.35*sin(wind*2.6+p.x*37.0))*pixel.x*wind_strength*(foliage*2.0+pine*1.3)*leaf_only;
	offset.y += sin(wind*1.7+p.x*20.0)*pixel.y*wind_strength*foliage*0.65*leaf_only;
	float smoke = smoke_column(p,vec2(0.678,0.323),vec2(0.757,0.115),0.030);
	smoke = max(smoke,smoke_column(p,vec2(0.752,0.325),vec2(0.807,0.177),0.025));
	smoke = max(smoke,smoke_column(p,vec2(0.873,0.326),vec2(0.905,0.223),0.022));
	float st = animation_time*smoke_speed;
	offset.x += smoke*smoke_strength*pixel.x*(4.0*sin(p.y*47.0-st*1.1)+2.0*sin(p.y*91.0-st*1.7));
	offset.y += smoke*smoke_strength*pixel.y*2.5*sin(p.x*55.0+p.y*31.0-st*0.9);
	float moon = oval(p,vec2(0.852,0.125),vec2(0.048,0.068));
	float sky = band(p.x,0.37,0.96,0.04)*(1.0-smoothstep(0.19,0.29,p.y))*(1.0-moon)*(1.0-pine)*(1.0-smoke);
	// Cloud motion affects blue-grey sky, not branches crossing the sky mask.
	sky *= smoothstep(0.10,0.22,dot(original.rgb,vec3(0.2126,0.7152,0.0722)))*smoothstep(0.015,0.05,original.b-original.r);
	float ct = animation_time*clouds_speed;
	offset.x += sky*clouds_strength*pixel.x*2.8*sin(ct*0.24+p.y*13.0);
	float wt = animation_time*water_speed;
	float cool_water = smoothstep(-0.025,0.035,original.b-original.r);
	float wet = creek*cool_water;
	offset.x += wet*water_strength*pixel.x*2.2*sin(p.y*270.0-wt*2.8);
	offset.y += wet*water_strength*pixel.y*0.9*sin(p.x*180.0-wt*1.6);
	float hot = city*red_ink(original.rgb);
	float ft = animation_time*fire_speed;
	offset.y += hot*fire_strength*pixel.y*1.2*sin(ft*9.0+p.x*180.0);
	vec4 scene = texture(TEXTURE,clamp(p+offset,vec2(0.001),vec2(0.999)));
	float flame = (0.11*sin(ft*9.0+p.x*121.0)+0.07*sin(ft*17.0+p.x*233.0))*fire_strength*hot;
	scene.rgb += scene.rgb*flame;
	float shimmer = sin(p.y*350.0-wt*3.4+sin(p.x*85.0+wt))*0.045*wet*water_strength;
	scene.rgb += vec3(0.70,0.78,0.84)*shimmer;
	COLOR = vec4(scene.rgb,scene.a*inside*opacity);
}
