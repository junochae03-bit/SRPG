extends RefCounted
const Dungeon=preload("res://scripts/dungeon.gd")
static func pose(p:Dictionary)->Dictionary:
	var result={"offset":Vector2.ZERO,"angle":0.0,"weapon":0.0,"hand":Vector2(16,-30),"scale":Vector2.ONE,"progress":0.0}
	if p.get("motion_time",0)<=0:return result
	var t=clampf(1-p.motion_time/p.motion_duration,0,1)
	var wave=sin(t*PI)
	var direction=Dungeon.iso(p.aim).normalized()
	result.progress=t
	match p.get("motion",""):
		"cleave":result.angle=wave*.13*signf(direction.x);result.offset=direction*wave*7;result.weapon=lerpf(-1.2,1.7,t)
		"slam":result.angle=-sin(t*TAU)*.15;result.offset=Vector2(0,-wave*6);result.weapon=lerpf(-1.7,.8,t*t)
		"spin":result.angle=sin(t*TAU*2)*.12;result.weapon=t*TAU*2;result.hand=Vector2.from_angle(t*TAU*2)*20+Vector2(0,-30)
		"shoot":result.offset=-direction*wave*6;result.weapon=-wave*.16
		"shoot_high":result.offset=Vector2(0,-wave*8);result.weapon=-wave*.7;result.hand.y-=wave*13
		"cast":result.offset=Vector2(0,-wave*5);result.hand.y-=wave*12;result.weapon=-wave*.25
		"cast_high":result.offset=Vector2(0,-wave*13);result.hand.y-=wave*20;result.weapon=-wave*.65
		"dash":result.angle=direction.x*.24*wave;result.offset=direction*wave*10
		"leap":result.offset=Vector2(0,-wave*29);result.angle=-wave*.12
		"blink":result.offset=Vector2(0,-wave*10);result.scale=Vector2(1-wave*.2,1+wave*.1)
	return result
