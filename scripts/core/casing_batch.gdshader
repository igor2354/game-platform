shader_type canvas_item;
uniform sampler2D air_stg44 : source_color, filter_linear, repeat_disable;
uniform sampler2D rest_stg44 : source_color, filter_linear, repeat_disable;
uniform sampler2D air_mp40 : source_color, filter_linear, repeat_disable;
uniform sampler2D rest_mp40 : source_color, filter_linear, repeat_disable;
uniform sampler2D air_svt : source_color, filter_linear, repeat_disable;
uniform sampler2D rest_svt : source_color, filter_linear, repeat_disable;
uniform sampler2D air_m1911 : source_color, filter_linear, repeat_disable;
uniform sampler2D rest_m1911 : source_color, filter_linear, repeat_disable;
uniform int sheets[256];
varying flat float sheet;
varying vec4 tint;
void vertex() {
    sheet = float(sheets[INSTANCE_ID]);
    UV = INSTANCE_CUSTOM.rg + UV * INSTANCE_CUSTOM.ba;
    tint = COLOR;
}
void fragment() {
    vec4 pixel;
    if (sheet < 0.5) { pixel = texture(air_stg44, UV); }
    else if (sheet < 1.5) { pixel = texture(rest_stg44, UV); }
    else if (sheet < 2.5) { pixel = texture(air_mp40, UV); }
    else if (sheet < 3.5) { pixel = texture(rest_mp40, UV); }
    else if (sheet < 4.5) { pixel = texture(air_svt, UV); }
    else if (sheet < 5.5) { pixel = texture(rest_svt, UV); }
    else if (sheet < 6.5) { pixel = texture(air_m1911, UV); }
    else { pixel = texture(rest_m1911, UV); }
    COLOR = tint * pixel;
}
