shader_type canvas_item;
render_mode unshaded;

// One unchanged image_gen atlas. Filtering never crosses a panel's 16px inset.
uniform sampler2D material_atlas : source_color, filter_linear, repeat_disable;
uniform sampler2D walk_mask : filter_linear, repeat_disable;
uniform sampler2D accent_mask : filter_linear, repeat_disable;
uniform vec2 accent_panel = vec2(0.0);
uniform float accent_strength = 0.0;
uniform vec2 ground_panel = vec2(0.0);
uniform vec2 path_panel = vec2(2.0,0.0);
uniform vec3 ground_tint = vec3(1.0);
uniform vec3 path_tint = vec3(1.0);
uniform float path_saturation = 1.0;
uniform vec2 camera = vec2(0.0);
uniform vec2 screen_anchor = vec2(763.0,438.0);
uniform vec2 terrain_extent = vec2(3200.0,1800.0);
uniform vec2 terrain_origin = vec2(-800.0,-450.0);
uniform vec2 camp = vec2(6.0);
uniform float mask_size = 64.0;
uniform float mask_offset = 12.0;

vec3 surface(vec2 world,vec2 panel) {
	// Five logical cells per material swatch, exactly the source pack scale.
	// World anchoring and mirrored joins stay fixed when the camera pans/zooms.
	vec2 mirrored=1.0-abs(mod(world/5.0,2.0)-1.0);
	vec2 atlas_uv=(panel*512.0+vec2(16.0)+mirrored*480.0)/vec2(1536.0,1024.0);
	return texture(material_atlas,atlas_uv).rgb;
}
void fragment() {
	vec2 s=UV*terrain_extent+terrain_origin-screen_anchor+camera;
	vec2 world=vec2(s.x/96.0+s.y/48.0,s.y/48.0-s.x/96.0);
	float mask=texture(walk_mask,(world+vec2(mask_offset+0.5))/mask_size).r;
	float path=smoothstep(0.40,0.64,mask);
	vec3 ground=surface(world,ground_panel)*ground_tint;
	vec3 paving=surface(world,path_panel);
	// Optional floor-local clearings use another existing material panel. The
	// mask is built once per map; it never drifts or adds animated tile noise.
	float accent=texture(accent_mask,(world+vec2(mask_offset+0.5))/mask_size).r;
	paving=mix(paving,surface(world,accent_panel),accent*accent_strength);
	float luminance=dot(paving,vec3(0.299,0.587,0.114));
	paving=mix(vec3(luminance),paving,path_saturation)*path_tint;
	// A narrow soil contact shade makes the existing walkable path legible.
	float edge=smoothstep(0.22,0.40,mask)*(1.0-smoothstep(0.40,0.64,mask));
	COLOR=vec4(mix(ground,paving,path)*(1.0-edge*0.10),1.0);
}
