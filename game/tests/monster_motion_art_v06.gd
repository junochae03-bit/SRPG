extends SceneTree
const Motion = preload("res://scripts/monster_motion_art_v06.gd")
const World = preload("res://scripts/world_art.gd")
const CostumeArt = preload("res://scripts/costume_art_v04.gd")

var checks: int = 0
var failures: int = 0
var finished: bool = false

func _initialize():
	create_timer(120).timeout.connect(_timeout)
	call_deferred("_run")

func _check(condition: bool):
	checks += 1
	if not condition:
		failures += 1
		push_error("Monster motion check failed: " + str(checks))

func _timeout():
	if not finished:
		failures += 1
		push_error("Monster motion test timed out or stopped on a script error")
		_finish()

func _finish():
	finished = true
	print("MONSTER_MOTION_ART_V06_DONE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _run():
	# Catch accidentally routing the new key through the old broad-magenta branch.
	var color_probe = Image.create(3, 1, false, Image.FORMAT_RGBA8)
	color_probe.set_pixel(0, 0, Color8(255, 0, 255))
	color_probe.set_pixel(1, 0, Color8(200, 50, 200))
	color_probe.set_pixel(2, 0, Color8(210, 30, 210))
	var keyed_probe = CostumeArt._keyed_image(color_probe, "magenta_narrow")
	_check(keyed_probe != null)
	if keyed_probe != null:
		_check(keyed_probe.get_pixel(0, 0).a == 0)
		_check(keyed_probe.get_pixel(1, 0) == color_probe.get_pixel(1, 0))
		var edge = keyed_probe.get_pixel(2, 0)
		_check(edge.a > 0 and edge.a < 1)
		_check(is_equal_approx(edge.r, color_probe.get_pixel(2, 0).r))
		_check(is_equal_approx(edge.b, color_probe.get_pixel(2, 0).b))
	var catalog = Motion.data()
	if not catalog.has("species") or not catalog.has("base_ids"):
		_check(false); _finish(); return
	_check(catalog.species.size() == 48 and catalog.base_ids.size() == 24)
	var identities = {}
	# Check against the real legacy resolver, including all chapter boundaries.
	for kind in catalog.base_ids:
		for floor_number in range(101):
			for raid in [false, true]:
				var enemy = {"kind": kind, "floor": floor_number, "raid": raid, "hp": 100}
				var legacy = World.variant(kind, floor_number, raid)
				var expected = kind if legacy.is_empty() else str(legacy.species)
				_check(Motion.species_id(enemy) == expected)
				identities[expected] = enemy
	_check(identities.size() == 48)
	for kind in ["unknown", "forest_root_shrew", "boss_flood_anchor_admiral"]:
		_check(Motion.frame({"kind": kind, "hp": 1}, 0).is_empty())
	_check(Motion.frame({"kind": "shade", "hp": 0}, 0).is_empty())
	_check(Motion.frame({"kind": "shade", "training": true}, 0).is_empty())
	var state = {"kind": "shade", "hp": 1, "windup": 1.8, "attack_motion": .35}
	_check(Motion.pose_index(state) == 1)
	state.windup = .0001
	_check(Motion.pose_index(state) == 1)
	state.windup = 0
	_check(Motion.pose_index(state) == 2)
	state.attack_motion = .190
	_check(Motion.pose_index(state) == 2)
	state.attack_motion = .188
	_check(Motion.pose_index(state) == 3)
	state.attack_motion = .0001
	_check(Motion.pose_index(state) == 3)
	state.attack_motion = 0
	_check(Motion.pose_index(state) == 0)
	state.attack_motion = .7
	state.attack_motion_duration = 1.4
	_check(Motion.pose_index(state) == 3)
	state.attack_motion_duration = 0
	_check(Motion.pose_index(state) == 2)
	state.stun_time = 1
	_check(Motion.pose_index(state) == 0)
	state.stun_time = 0
	for stagger in ["check", "down"]:
		state.stagger = {"state": stagger}
		_check(Motion.pose_index(state) == 0)
	state.erase("stagger")
	state.support_cast = .5
	_check(Motion.pose_index(state) == 0)
	_check(Motion.size_policy({"kind": "warden", "floor": 40, "raid": true}).ratio == 10)
	_check(Motion.size_policy({"kind": "golem", "floor": 60, "raid": true}).ratio == 6)
	_check(Motion.size_policy({"kind": "sentinel", "floor": 100, "raid": true}).ratio == 6)
	_check(Motion.size_policy({"kind": "rat", "elite": true}).ratio == .5)
	_check(Motion.size_policy({"kind": "rat"}).applied_by_reader == false)
	_check(Motion.facing({"pos": Vector2.ZERO, "attack_pos": Vector2.RIGHT, "windup": 1.0}) == -1)
	_check(Motion.facing({"pos": Vector2.ZERO, "attack_pos": Vector2.LEFT, "attack_motion": .2}) == 1)
	_check(Motion.facing({"pos": Vector2.ZERO, "attack_pos": Vector2.DOWN, "windup": 1.0}) == 1)
	var chase = {"pos": Vector2.ZERO, "attack_pos": Vector2.LEFT * 5, "visual_direction": Vector2.RIGHT}
	_check(Motion.facing(chase) == -1)
	chase.pos = Vector2(10, 10)
	var stopped = chase.duplicate(true)
	_check(Motion.facing(chase) == -1)
	_check(Motion.facing(chase) == -1 and chase == stopped)
	chase.windup = .5
	_check(Motion.facing(chase) == 1)
	chase.stun_time = 1.0
	_check(Motion.facing(chase) == -1)
	chase.stun_time = 0.0
	for control in ["check", "down"]:
		chase.stagger = {"state": control}
		_check(Motion.facing(chase) == -1)
	chase.erase("stagger")
	chase.windup = 0.0
	chase.attack_motion = .2
	_check(Motion.facing(chase) == 1)
	chase.attack_motion = 0.0
	_check(Motion.facing(chase) == -1)
	_check(Motion.facing({"attack_pos": Vector2.RIGHT}) == 1)
	_check(Motion.facing({"visual_direction": Vector2.DOWN}) == 1)
	var visited = 0
	for identity in identities:
		var enemy: Dictionary = identities[identity].duplicate(true)
		var original: Dictionary = enemy.duplicate(true)
		var idle = Motion.frame(enemy, 0)
		if idle.is_empty():
			_check(false); continue
		_check(idle.phase == "idle" and Motion.frame(enemy, 999999).phase == "idle")
		_check(enemy == original)
		for index in range(4):
			enemy.windup = 1.5 if index == 1 else 0.0
			enemy.attack_motion = .35 if index == 2 else .1 if index == 3 else 0.0
			var frame = Motion.frame(enemy, 20)
			if frame.is_empty():
				_check(false); continue
			var authored = catalog.species[identity].frames[index]
			_check(frame.index == index and frame.species == identity)
			_check(frame.height == idle.height)
			_check(frame.foot == Vector2(authored.foot[0], authored.foot[1]))
			_check(frame.texture.margin == Rect2())
			_check(frame.texture == Motion.frame(enemy, 21).texture)
			_check(frame.texture.atlas.get_size() == Vector2(1537, 1025))
			_check(frame.texture.atlas.get_image().get_pixel(0, 0).a == 0)
			visited += 1
	var support={"hp":1,"windup":0.,"attack_motion":.35,"attack_motion_kind":"support","visual_direction":Vector2.LEFT,"pos":Vector2.ZERO,"attack_pos":Vector2.RIGHT}
	_check(Motion.pose_index(support)==0)
	_check(Motion.facing(support)==1.)
	support.attack_motion_kind="attack"
	_check(Motion.pose_index(support)==2)
	_check(visited == 192)
	if failures == 0: print("MONSTER_MOTION_ART_V06_PASS mappings=4848 species=48 frames=" + str(visited))
	_finish()
