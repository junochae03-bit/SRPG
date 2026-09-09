shader_type canvas_item;
render_mode unshaded;

uniform sampler2D walk_mask : filter_linear, repeat_disable;
uniform vec2 camera = vec2(0.0);
uniform vec2 screen_anchor = vec2(683.0, 438.0);
uniform vec2 camp = vec2(6.0);
uniform float mask_size = 64.0;
uniform float mask_offset = 12.0;
uniform int theme = 0;
uniform bool town = false;
uniform int biome = -1;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x),
		mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), f.x), f.y);
}
void fragment() {
	vec2 s = UV * vec2(1440.0,900.0) - screen_anchor + camera;
	vec2 world = vec2(s.x / 96.0 + s.y / 48.0, s.y / 48.0 - s.x / 96.0);
	float broad = noise(world * 0.42);
	float detail = noise(world * 4.5);
	float fine = noise(world * 23.0);
	float mask = texture(walk_mask, (world + vec2(mask_offset + 0.5)) / mask_size).r;
	float dirt = smoothstep(0.35, 0.72, mask + (detail - 0.5) * 0.10);
	vec3 grass = mix(vec3(0.34,0.51,0.23), vec3(0.54,0.66,0.31), broad);
	grass += (detail - 0.5) * 0.047 + (fine - 0.5) * 0.026;
	vec3 soil = mix(vec3(0.67,0.55,0.34), vec3(0.82,0.71,0.48), noise(world * 0.7));
	soil += (detail - 0.5) * 0.06 + (fine - 0.5) * 0.038;
	if (theme == 1) { grass = mix(vec3(.22,.32,.40),vec3(.36,.48,.52),broad); soil = mix(vec3(.46,.57,.60),vec3(.62,.69,.69),detail); }
	if (theme == 2) { grass = mix(vec3(.46,.49,.35),vec3(.65,.64,.45),broad); soil = mix(vec3(.72,.66,.49),vec3(.84,.78,.61),detail); }
	// All fine detail is anchored in world coordinates, never screen pixels or TIME.
	if (biome == 2) { grass = mix(vec3(.12,.34,.39),vec3(.24,.49,.52),broad); soil = mix(vec3(.56,.61,.54),vec3(.69,.72,.61),detail); }
	if (biome == 3) { grass = mix(vec3(.24,.34,.36),vec3(.4,.49,.43),broad); soil = mix(vec3(.55,.57,.44),vec3(.67,.67,.49),detail); }
	if (biome == 4) {
		float crust = smoothstep(.42,.64,noise(world * .75));
		vec3 lava = mix(vec3(.64,.18,.055),vec3(1.,.56,.12),noise(world*2.2));
		grass = mix(lava,vec3(.22,.24,.27)+(detail-.5)*.08,crust);
		soil = mix(vec3(.34,.34,.34),vec3(.48,.45,.40),detail);
	}
	if (biome == 5) {
		float fissure = 1.-smoothstep(.02,.10,abs(noise(world*1.1)-.5));
		grass = mix(vec3(.27,.53,.64),vec3(.65,.8,.84),broad);
		grass -= fissure*.12;soil = mix(vec3(.62,.75,.79),vec3(.84,.9,.88),detail);
	}
	if (biome == 6) { grass=mix(vec3(.28,.34,.35),vec3(.40,.44,.42),broad);soil=mix(vec3(.47,.48,.43),vec3(.63,.61,.51),detail); }
	if (biome == 7) { grass=mix(vec3(.43,.4,.22),vec3(.65,.53,.3),broad);soil=mix(vec3(.64,.52,.34),vec3(.77,.66,.45),detail); }
	if (biome == 8) { grass=mix(vec3(.23,.27,.42),vec3(.38,.43,.58),broad);soil=mix(vec3(.49,.54,.64),vec3(.65,.65,.73),detail); }
	if (biome == 9) { grass=mix(vec3(.25,.28,.34),vec3(.40,.38,.47),broad);soil=mix(vec3(.48,.47,.54),vec3(.63,.6,.66),detail); }
	float edge = smoothstep(0.15,0.4,mask) * (1.0 - smoothstep(0.4,0.7,mask));
	vec3 color = mix(grass, soil, dirt);
	color -= edge * 0.035;
	float paving = (1.0 - smoothstep(1.65,2.35,length(world - camp))) * dirt;
	if (town || theme == 2) { paving = dirt; }
	vec2 brick = (world - camp) * 2.1;
	brick.x += mod(floor(brick.y),2.0) * 0.5;
	vec2 bevel = min(fract(brick),1.0-fract(brick));
	float mortar = 1.0-smoothstep(0.015,0.07,min(bevel.x,bevel.y));
	vec3 stone = mix(vec3(0.71,0.69,0.56),vec3(0.82,0.79,0.65),hash21(floor(brick)));
	stone -= mortar * 0.10;
	if (biome >= 0) { stone = mix(stone,soil,.75); }
	color = mix(color,stone,paving);
	COLOR = vec4(color,1.0);
}
