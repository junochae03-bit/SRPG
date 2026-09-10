shader_type canvas_item;
uniform vec4 top_color : source_color = vec4(1.0, 0.96, 0.75, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.93, 0.67, 0.24, 1.0);
uniform float glyph_height = 30.0;
varying float text_y;
void vertex() { text_y = VERTEX.y; }
void fragment() {
	COLOR.rgb *= mix(top_color.rgb, bottom_color.rgb, clamp(text_y / max(glyph_height, 1.0), 0.0, 1.0));
}
