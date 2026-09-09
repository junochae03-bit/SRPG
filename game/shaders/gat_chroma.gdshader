shader_type canvas_item;
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	vec2 pixels = round(vec2(1.0) / TEXTURE_PIXEL_SIZE);
	bool gat_sheet = (pixels.x == 1374.0 && pixels.y == 1145.0) || (pixels.x == 1122.0 && pixels.y == 1402.0) || (pixels.x == 1024.0 && pixels.y == 1536.0) || (pixels.x == 1536.0 && pixels.y == 1536.0) || (pixels.x == 1024.0 && pixels.y == 1024.0) || (pixels.x == 1536.0 && pixels.y == 1024.0) || (pixels.x == 1774.0 && pixels.y == 887.0) || (pixels.x == 1254.0 && pixels.y == 1254.0) || (pixels.x == 1448.0 && pixels.y == 1086.0);
	if (gat_sheet && sample_color.r > 0.65 && sample_color.b > 0.65 && sample_color.g < 0.35) {
		COLOR.a = 0.0;
	}
}
