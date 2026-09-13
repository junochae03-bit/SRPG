extends SceneTree
const Art = preload("res://scripts/monster_ecology_art_v071.gd")
const CostumeArt = preload("res://scripts/costume_art_v04.gd")
var checks: int = 0
var failures: int = 0
var finished: bool = false

func _initialize():
	create_timer(150).timeout.connect(_timeout)
	call_deferred("_run")

func _check(condition: bool, label: String = ""):
	checks += 1
	if not condition:
		failures += 1
		push_error("Ecology art check %d: %s" % [checks, label])

func _finish():
	finished = true
	print("MONSTER_ECOLOGY_ART_V071_DONE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _timeout():
	if not finished:
		failures += 1
		push_error("Ecology art test stopped or timed out")
		_finish()

func _run():
	var catalog = Art.data()
	if not catalog.has("species"):
		_check(false, "missing catalog"); _finish(); return
	_check(catalog.species.size() == 29)
	_check(catalog.sheets.size() == 26)
	_check(catalog.deferred.size() == 11)
	for held in catalog.deferred:
		_check(not Art.recognizes(held.id), "held species leaked: " + str(held.id))
	for invalid in ["shade", "acorn_slinger", "warden", "new_unknown"]:
		_check(Art.frame({"kind": invalid}, 0).is_empty())
	for flag in ["boss", "raid", "training"]:
		var enemy = {"kind": "forest_root_shrew"}
		enemy[flag] = true
		_check(Art.frame(enemy, 0).is_empty())
	_check(Art.frame({"kind": "forest_root_shrew", "hp": 0}, 0).is_empty())
	var state = {"kind": "forest_root_shrew", "hp": 10, "windup": 1.1, "attack_motion": .65}
	_check(Art.pose_index(state) == 1)
	state.windup = .0001
	_check(Art.pose_index(state) == 1)
	state.windup = 0
	_check(Art.pose_index(state) == 2)
	state.attack_motion = .54
	_check(Art.pose_index(state) == 2)
	state.attack_motion = .52
	_check(Art.pose_index(state) == 3)
	state.attack_motion = .40
	_check(Art.pose_index(state) == 3, "no automatic scheduled second bite")
	state.attack_impact_time = .12
	_check(Art.pose_index(state) == 2, "authoritative second impact")
	state.attack_impact_time = 0
	_check(Art.pose_index(state) == 3)
	state.attack_motion = 0
	state.attack_impact_time = .12
	_check(Art.pose_index(state) == 0, "stale impact after cancellation")
	state.attack_impact_time = 0
	state.attack_motion = 1.0
	state.attack_motion_duration = 1.0
	_check(Art.pose_index(state) == 2)
	state.attack_motion = .87
	_check(Art.pose_index(state) == 3, "honor duration override")
	state.attack_motion_duration = 0
	state.attack_motion = .65
	_check(Art.pose_index(state) == 2, "invalid duration uses DB recovery")
	state.attack_motion_kind = "support"
	_check(Art.pose_index(state) == 0)
	state.attack_motion_kind = "attack"
	state.stun_time = 1.0
	_check(Art.pose_index(state) == 0)
	state.stun_time = 0
	for phase in ["check", "down"]:
		state.stagger = {"state": phase}
		_check(Art.pose_index(state) == 0)
	state.erase("stagger")
	state.support_cast = .5
	_check(Art.pose_index(state) == 0)
	var helper_probe = Image.create(2, 1, false, Image.FORMAT_RGBA8)
	helper_probe.set_pixel(0, 0, Color8(255, 0, 255))
	helper_probe.set_pixel(1, 0, Color8(200, 50, 200))
	var keyed = CostumeArt._keyed_image(helper_probe, "magenta_narrow")
	_check(keyed != null)
	if keyed != null:
		_check(keyed.get_pixel(0, 0).a == 0)
		_check(keyed.get_pixel(1, 0) == helper_probe.get_pixel(1, 0))
	var count = 0
	var checked_sheets = {}
	for identity in catalog.species:
		var entry: Dictionary = catalog.species[identity]
		var enemy = {"kind": identity, "hp": 10, "pos": Vector2.ZERO, "attack_pos": Vector2.RIGHT, "visual_direction": Vector2.LEFT}
		var original = enemy.duplicate(true)
		var idle = Art.frame(enemy, 0)
		_check(not idle.is_empty(), "idle load: " + str(identity))
		if idle.is_empty(): continue
		_check(enemy == original)
		_check(Art.frame(enemy, 123456).index == 0, "wall clock must not animate idle")
		_check(idle.facing == 1, "stale attack_pos ignored while idle")
		for index in range(4):
			enemy.windup = float(entry.timing.windup_seconds) if index == 1 else 0.0
			enemy.attack_motion = float(entry.timing.recovery_seconds) if index == 2 else .1 if index == 3 else 0.0
			var frame = Art.frame(enemy, 1)
			_check(not frame.is_empty(), str(identity) + ":" + str(index))
			if frame.is_empty(): continue
			_check(frame.index == index)
			_check(frame.height == idle.height and frame.scale == idle.scale)
			_check(is_equal_approx(frame.body_pixels, 112.0 * float(entry.display_ratio)))
			_check(is_equal_approx(frame.scale * frame.height, frame.body_pixels))
			_check(frame.foot == Vector2(entry.frames[index].foot[0], entry.frames[index].foot[1]))
			_check(frame.texture.margin == Rect2())
			_check(frame.texture == Art.frame(enemy, 99).texture)
			_check(frame.facing == (1 if index == 0 else -1))
			_check(frame.pattern_id == str(identity) + ":primary")
			for mirror in [-1.0, 1.0]:
				var offset = -frame.foot * frame.scale * Vector2(mirror, 1)
				_check((offset + frame.foot * frame.scale * Vector2(mirror, 1)).is_zero_approx())
			if not checked_sheets.has(frame.sheet):
				var dimensions: Array = catalog.sheets[frame.sheet].size
				_check(frame.texture.atlas.get_size() == Vector2(dimensions[0] + 1, dimensions[1] + 1))
				var image: Image = frame.texture.atlas.get_image()
				_check(image.get_pixel(image.get_width()-1, image.get_height()-1).a == 0)
				checked_sheets[frame.sheet] = true
			count += 1
	_check(count == 116)
	_check(checked_sheets.size() == 26)
	if failures == 0: print("MONSTER_ECOLOGY_ART_V071_PASS species=29 frames=116")
	_finish()
