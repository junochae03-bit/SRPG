shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sight_mask : filter_nearest, repeat_disable;
uniform bool enabled=false;
uniform vec2 camera=vec2(0.0);
uniform vec2 screen_anchor=vec2(0.0);
uniform float mask_size=104.0;
varying vec2 canvas_position;
varying vec2 elevation;
varying float black_source;
void vertex(){
 canvas_position=VERTEX;
 elevation=(COLOR.rg-vec2(.5))*2048.0;
 black_source=COLOR.b;
 COLOR.rgb=vec3(1.0);
}
void fragment(){
 vec4 tex=texture(TEXTURE,UV);
 if(black_source>.5){
  float b=max(tex.r,max(tex.g,tex.b));
  COLOR.rgb=tex.rgb/max(b,.001);
  COLOR.a*=b*smoothstep(.18,.28,b);
 }
 if(enabled){
  vec2 s=canvas_position-elevation-screen_anchor+camera;
  vec2 w=vec2(s.x/96.0+s.y/48.0,s.y/48.0-s.x/96.0);
  vec2 uv=(w+vec2(12.5))/mask_size;
  float visibility=texture(sight_mask,uv).g;
  if(any(lessThan(uv,vec2(0.0)))||any(greaterThan(uv,vec2(1.0))))visibility=0.;
  COLOR.a*=visibility;
 }
}
