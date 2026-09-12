extends RefCounted
## Render-only measurements. Simulation positions and hit geometry stay in world space.
const Dungeon=preload("res://scripts/dungeon.gd")
const BODY_PIXELS=112.
static var registry:Dictionary={}
static func profile(key:String)->Dictionary:
	if registry.is_empty():registry=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_presentation.json"))
	return registry.profiles.get(key,{})
static func apply(frame:Dictionary,key:String)->Dictionary:
	var settings=profile(key)
	var result=frame.duplicate()
	# Some supplied sheets change source pixel density between poses (notably
	# Riko's attack replacements). Their calibrated per-frame height is required;
	# replacing it by one sheet height makes these poses almost twice as large.
	result.height=float(frame.height)*float(settings.get("height_scale",1.))
	result.body_pixels=BODY_PIXELS
	result.source_facing=float(settings.get("source_facing_by_frame",{}).get(str(int(frame.index)),settings.get("source_facing",1)))
	result.presentation_id=key
	return result
static func aim(p:Dictionary)->Vector2:
	if p.get("motion_time",0)>0 and p.get("motion","")==p.get("motion_aim_motion","!") and p.get("motion_duration",0)==p.get("motion_aim_duration",-1) and p.get("dodge_time",0)<=0 and p.get("hurt_time",0)<=0 and p.get("down_time",0)<=0 and p.get("charge_time",-1)<0:
		return p.get("motion_aim",p.get("aim",Vector2.RIGHT))
	return p.get("aim",Vector2.RIGHT)
static func facing(p:Dictionary,source_facing:float=1)->float:
	return (-1. if Dungeon.iso(aim(p)).x<0 else 1.)*source_facing
static func pose(p:Dictionary)->Dictionary:
	var drawing=p.duplicate();drawing.aim=aim(p)
	return preload("res://scripts/character_motion.gd").pose(drawing)
static func projectile_offset(shot:Dictionary)->Vector2:
	var offset:Vector2=shot.get("visual_origin",Vector2(0,-70))
	var traveled=Dungeon.iso(shot.get("pos",Vector2.ZERO)-shot.get("visual_start",shot.get("pos",Vector2.ZERO))).length()
	return offset.lerp(Vector2(0,-70),clampf(traveled/120.,0.,1.))
