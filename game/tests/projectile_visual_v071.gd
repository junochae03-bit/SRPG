extends SceneTree
const Visual=preload("res://scripts/projectile_visual_v071.gd")
const Presentation=preload("res://scripts/character_presentation.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize():
	check(Visual.data().families.size()==8,"eight visual families")
	for key in Visual.data().families:
		var shot={"type":"staff","visual_family":key,"dir":Vector2.RIGHT,"pos":Vector2.ZERO,"visual_start":Vector2.ZERO,"visual_origin":Vector2(41,-104),"age":0.,"speed":14.}
		var saved=shot.duplicate(true)
		var s=Visual.flight(shot)
		check(s.offset==Vector2(41,-104),"launch socket preserved "+key)
		check(s.trail_length==0,"no trail behind spawn "+key)
		check(shot==saved,"sampling does not mutate simulation "+key)
		var frames={}
		for i in range(4):
			shot.age=(i+.1)/12.
			frames[Visual.flight(shot).frame]=true
		check(frames.size()==4,"flight loop covers four frames "+key)
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,1).normalized()]:
			shot.dir=direction;shot.pos=direction*8.;shot.age=.7
			s=Visual.flight(shot)
			check(absf(angle_difference(s.angle,Dungeon.iso(direction).angle()))<.0001,"tip follows actual velocity "+key)
			check(s.offset.distance_to(Vector2(0,-70))<.001,"flight elevation convergence "+key)
			check(s.trail_length<=76.,"bounded trail "+key)
		shot.speed=0
		check(Visual.flight(shot).trail_length==0,"zero speed has no trail "+key)
		var unscaled=Visual.flight(shot)
		shot.visual_scale=50
		check(Visual.flight(shot)==unscaled,"legacy scale does not affect flight "+key)
	check(Visual.family({"type":"bow","class_id":"hunter"})=="bolt","hunter bolt")
	check(Visual.family({"type":"bow"})=="arrow","plain arrow")
	check(Visual.family({"type":"staff"})=="arcane","untyped staff not forced fire")
	check(Visual.family({"type":"staff","class_id":"mage","skill_mode":"burst"})=="fire","mode-only fire")
	check(Visual.family({"type":"staff","class_id":"mage","skill_mode":"slow"})=="frost","mode-only frost")
	check(Visual.family({"type":"staff","vfx":"thunder"})=="thunder","explicit VFX without skill ID")
	check(Visual.family({"type":"wave"}).is_empty(),"wave fallback retained")
	check(Visual.family({"type":"staff","class_id":"gambler"}).is_empty(),"gambler fallback retained")
	check(Visual.family({"type":"staff","visual_family":"unknown"}).is_empty(),"unknown explicit family rejected")
	var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_presentation.json")).profiles
	for profile in profiles.values():
		var raw=profile.get("release_offset",[0,-70])
		var offset=Vector2(raw[0],raw[1])
		check(Presentation.projectile_offset({"pos":Vector2.ZERO,"visual_start":Vector2.ZERO,"visual_origin":offset})==offset,"profile launch offset preserved")
	print("PROJECTILE_VISUAL_V071 checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
