shader_type canvas_item;
render_mode blend_add;
uniform sampler2D sight_mask : filter_nearest, repeat_disable;
uniform bool enabled=false;
uniform vec2 camera=vec2(0.0);
uniform vec2 screen_anchor=vec2(763.0,438.0);
uniform float mask_size=104.0;
varying vec2 canvas_position;
varying vec2 height_offset;
void vertex() {
 canvas_position=VERTEX;
 height_offset=(COLOR.rg-vec2(0.5))*2048.0;
 COLOR.rgb=vec3(1.0);
}
void fragment() {
 vec4 tex=texture(TEXTURE,UV);
 float brightness=max(tex.r,max(tex.g,tex.b));
 COLOR.rgb*=smoothstep(0.18,0.28,brightness);
 if(enabled) {
  vec2 s=canvas_position-height_offset-screen_anchor+camera;
  vec2 world=vec2(s.x/96.0+s.y/48.0,s.y/48.0-s.x/96.0);
  vec2 uv=(world+vec2(12.5))/mask_size;
  float visible=texture(sight_mask,uv).g;
  if(any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0))))visible=0.0;
  COLOR.a*=visible;
 }
}
