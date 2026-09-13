extends SceneTree
const Atlas = preload("res://scripts/skill_atlas_v06.gd")

class MockGame extends RefCounted:
	var session = {"state":{"players":{}}}
	func world_point(pos: Vector2) -> Vector2: return pos

var checks = 0
var failures = 0
func check(condition: bool, label: String):
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _initialize():
	var data = Atlas.data()
	check(data.animations.size() == 18, "assertion 6")
	check(data.bindings.size() == 37, "assertion 7")
	check(not data.bindings.has("runesword_a02"), "assertion 8")
	for id in data.bindings:
		var b = data.bindings[id]
		var e = {"skill_id":id,"class_id":b.class_id,"skill_mode":b.mode}
		var a = data.animations[b.effect_id]
		for i in range(6):
			var s = Atlas.sample(e, (i+.5)/6.0, 1.0, b.channel)
			check(s.frame == i, "assertion 15")
			check(float(a.rotation_safe_extents[i])*float(s.scale) <= 224.001, "assertion 16")
			check(ResourceLoader.exists(s.sheet), "assertion 17")
		check(Atlas.sample(e, -1, 1, b.channel).is_empty(), "assertion 18")
		check(Atlas.sample(e, 1, 1, b.channel).is_empty(), "assertion 19")
		e["visual_scale"] = 20
		check(Atlas.sample(e,.5,1,b.channel).scale == a.runtime_scale, "assertion 21")
		e["skill_mode"] = "invalid"
		check(Atlas.sample(e,.5,1,b.channel).is_empty(), "assertion 23")
	var pulse = {"skill_id":"whirlwind","class_id":"warrior","skill_mode":"spin","pulse_times":[.2,.8]}
	check(Atlas.sample(pulse,.1,2).is_empty(), "assertion 25")
	check(not Atlas.sample(pulse,.3,2).is_empty(), "assertion 26")
	check(Atlas.sample(pulse,.79,2).is_empty(), "assertion 27")
	check(not Atlas.sample(pulse,.9,2).is_empty(), "assertion 28")
	pulse["skill_phase"] = "windup"
	check(Atlas.sample(pulse,.9,2).is_empty(), "assertion 30")
	check(Atlas.binding({"skill_id":"dragon_breath"}).is_empty(), "assertion 31")
	var mock = MockGame.new()
	var owner = {"hp":100,"pos":Vector2(4,7),"aim":Vector2.UP,"motion_aim":Vector2.RIGHT,
		"motion":"spin","motion_aim_motion":"spin","motion_time":1.,"motion_duration":1.,"motion_aim_duration":1.}
	mock.session.state.players[1] = owner
	var layer = Atlas.new()
	var following = {"skill_id":"whirlwind","class_id":"warrior","skill_mode":"spin","owner":1,"follow_owner":true,"follow_offset":2.}
	check(layer.render(mock,following,.3,1.),"follow event accepted")
	check(layer.commands.back().at == Vector2(4,5),"follow position uses current aim, not locked pose aim")
	owner.aim = Vector2.LEFT
	layer.begin_frame()
	layer.render(mock,following,.3,1.)
	check(layer.commands.back().at == Vector2(2,7),"follow position changes on next tick")
	check(owner.motion_aim == Vector2.RIGHT,"body pose lock preserved")
	layer.free()
	print("SKILL_ATLAS_V06 checks=", checks, " failures=", failures, " bindings=37 effects=18 frames=108")
	quit(0 if failures == 0 else 1)
