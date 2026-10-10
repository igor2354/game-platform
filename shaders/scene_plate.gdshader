shader_type canvas_item;
// The complete room, its floor and distant view share one projection.
uniform bool blend_left = false;
uniform float overlap_fraction = 0.15625;
uniform bool effects_enabled = true;
uniform float luminance = 1.0;
uniform vec3 palette_tint = vec3(1.0);
void fragment() {
    vec4 color = texture(TEXTURE,UV);
    // Optical softness is restricted to the high distant sky, never to feet.
    float distant = 1.0 - smoothstep(0.12,0.28,UV.y);
    if (effects_enabled && distant > 0.01) {
        vec2 d = TEXTURE_PIXEL_SIZE * 1.6;
        vec3 soft = color.rgb * 0.4;
        soft += texture(TEXTURE,UV+vec2(d.x,0.0)).rgb * 0.15;
        soft += texture(TEXTURE,UV-vec2(d.x,0.0)).rgb * 0.15;
        soft += texture(TEXTURE,UV+vec2(0.0,d.y)).rgb * 0.15;
        soft += texture(TEXTURE,UV-vec2(0.0,d.y)).rgb * 0.15;
        color.rgb = mix(color.rgb,soft,distant);
    }
    color.rgb *= palette_tint * luminance;
    if (blend_left) color.a *= smoothstep(0.0,overlap_fraction,UV.x);
    COLOR = color;
}
