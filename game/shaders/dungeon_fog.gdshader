shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sight_mask : filter_linear, repeat_disable;
uniform vec2 camera=vec2(0.0);
uniform vec2 screen_anchor=vec2(763.0,438.0);
uniform float mask_size=104.0;
void fragment(){
	vec2 s=UV*vec2(3200.0,1800.0)+vec2(-800.0,-450.0)-screen_anchor+camera;
	vec2 world=vec2(s.x/96.0+s.y/48.0,s.y/48.0-s.x/96.0);
	vec2 uv=(world+vec2(12.5))/mask_size;
	float light=texture(sight_mask,uv).r;
	if(any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0))))light=0.0;
	COLOR=vec4(vec3(0.018,0.022,0.027),1.0-light);
}
