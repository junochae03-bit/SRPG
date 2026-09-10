shader_type canvas_item;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	vec2 pixels = round(vec2(1.0) / TEXTURE_PIXEL_SIZE);
	bool gat_sheet = (pixels.x == 1374.0 && pixels.y == 1145.0) || (pixels.x == 1122.0 && pixels.y == 1402.0) || (pixels.x == 1024.0 && pixels.y == 1536.0) || (pixels.x == 1536.0 && pixels.y == 1536.0) || (pixels.x == 1024.0 && pixels.y == 1024.0) || (pixels.x == 1536.0 && pixels.y == 1024.0) || (pixels.x == 1774.0 && pixels.y == 887.0) || (pixels.x == 1254.0 && pixels.y == 1254.0) || (pixels.x == 1448.0 && pixels.y == 1086.0);
	if (pixels.x == 1536.0 && pixels.y == 1024.0) {
		// New illustrated atlases contain legitimate violet crystals: key only
		// colors close to source magenta, preserving existing vertex tint/alpha.
		vec3 difference = abs(sample_color.rgb - vec3(1.0, 0.0, 1.0));
		float distance_from_key = max(difference.r, max(difference.g, difference.b));
		float key_alpha = smoothstep(0.15, 0.20, distance_from_key);
		// Despill only a silhouette edge touching keyed background. Interior
		// amethyst faces stay untouched even when their hue resembles magenta.
		float deficit = max(min(sample_color.r, sample_color.b) - sample_color.g, 0.0);
		float edge = 0.0;
		if (deficit > 0.04 && key_alpha > 0.0) {
			vec2 offsets[4] = vec2[](vec2(1,0),vec2(-1,0),vec2(0,1),vec2(0,-1));
			for (int i=0; i<4; i++) {
				vec3 delta = abs(texture(TEXTURE, UV+offsets[i]*TEXTURE_PIXEL_SIZE).rgb-vec3(1,0,1));
				edge=max(edge,1.0-smoothstep(0.15,0.20,max(delta.r,max(delta.g,delta.b))));
			}
		}
		float balance = 1.0-smoothstep(0.25,0.55,abs(sample_color.r-sample_color.b));
		float key_mix = clamp(deficit*balance*edge,0.0,0.92);
		float coverage=1.0-key_mix;
		vec3 foreground=clamp((sample_color.rgb-vec3(key_mix,0,key_mix))/coverage,vec3(0),vec3(1));
		COLOR=vec4(foreground,sample_color.a*key_alpha*coverage)*vertex_tint;
	} else if ((gat_sheet || pixels == vec2(2172.0,724.0)) && sample_color.r > 0.65 && sample_color.b > 0.65 && sample_color.g < 0.35) {
		COLOR.a = 0.0;
	}
}
