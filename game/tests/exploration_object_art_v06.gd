extends SceneTree
const Art = preload("res://scripts/exploration_object_art_v06.gd")
const CostumeArt = preload("res://scripts/costume_art_v04.gd")
var checks: int = 0
var failures: int = 0
var finished: bool = false

func _initialize():
	create_timer(120).timeout.connect(_timeout)
	call_deferred("_run")

func _check(condition: bool, label: String = ""):
	checks += 1
	if not condition:
		failures += 1
		push_error("Exploration art check %d failed: %s" % [checks, label])

func _timeout():
	if not finished:
		failures += 1
		push_error("Exploration art test timed out or stopped on a script error")
		_finish()

func _finish():
	finished = true
	print("EXPLORATION_OBJECT_ART_V06_DONE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _run():
	var color_probe = Image.create(2, 1, false, Image.FORMAT_RGBA8)
	color_probe.set_pixel(0, 0, Color8(255, 0, 255))
	color_probe.set_pixel(1, 0, Color8(200, 50, 200))
	var keyed_probe = CostumeArt._keyed_image(color_probe, "magenta_narrow")
	_check(keyed_probe != null, "narrow key helper")
	if keyed_probe != null:
		_check(keyed_probe.get_pixel(0, 0).a == 0)
		_check(keyed_probe.get_pixel(1, 0) == color_probe.get_pixel(1, 0), "purple RGB/alpha preserved")
	var catalog = Art.data()
	if not catalog.has("objects"):
		_check(false, "missing catalog"); _finish(); return
	_check(catalog.objects.size() == 12)
	_check(catalog.authored_frame_count == 36 and catalog.runtime_frame_count == 24)
	var initial = {"id": "room_3", "generation": "20260913.forest.1", "kind": "gather", "material": "seed", "claimed": false}
	var pristine: Dictionary = initial.duplicate(true)
	_check(Art.selection(initial, "forest", 1).id == "starleaf_herb")
	_check(Art.selection(initial, "forest", 11).id == "moonbell_herb")
	_check(Art.selection(initial, "forest", 51).id == "frostroot_herb")
	_check(initial == pristine, "selection mutated snapshot")
	var invalid = initial.duplicate(true)
	invalid.erase("claimed")
	_check(Art.frame(invalid, "forest", 1).is_empty(), "raw map site must fall back")
	invalid.claimed = 1
	_check(Art.selection(invalid, "forest", 1).is_empty(), "claim must be boolean snapshot field")
	invalid = initial.duplicate(true)
	invalid.material = "essence"
	_check(Art.selection(invalid, "forest", 1).is_empty())
	for kind in ["rest", "shrine", "challenge", "secret", "new_kind"]:
		invalid = initial.duplicate(true)
		invalid.kind = kind
		invalid.opened = true
		_check(Art.frame(invalid, "forest", 1).is_empty(), "unsupported site " + kind)
	invalid = initial.duplicate(true)
	invalid.kind = "cache"
	invalid.event = "unknown_event"
	_check(Art.selection(invalid, "forest", 1).is_empty())
	_check(Art.selection(initial, "forest", 0).is_empty())
	var seen = {}
	# Both personal states must choose identical species despite unrelated UI data.
	for floor_number in range(1, 101):
		for serial in range(16):
			for category in ["seed", "ore", "cache", "herbalist", "sealed_supplies"]:
				var site = initial.duplicate(true)
				site.generation = "%d.forest.%d" % [serial, floor_number]
				site.kind = "gather" if category in ["seed", "ore"] else "cache"
				site.material = category if site.kind == "gather" else "ore"
				site.event = category if category in ["herbalist", "sealed_supplies"] else ""
				var before = site.duplicate(true)
				var unclaimed = Art.selection(site, "forest", floor_number)
				_check(not unclaimed.is_empty())
				if unclaimed.is_empty(): continue
				_check(site == before, "reader mutated the site")
				seen[unclaimed.id] = {"site": before, "floor": floor_number}
				site.claimed = true
				site.remaining = 100
				site.opened = true
				site.state = "partial"
				site.request_pending = true
				site.claimed_by = 999
				var claimed = Art.selection(site, "forest", floor_number)
				_check(unclaimed.id == claimed.id, "state/player changed identity")
				var is_chest = category in ["cache", "sealed_supplies"]
				_check(unclaimed.state == ("closed" if is_chest else "available"))
				_check(claimed.state == ("empty" if is_chest else "depleted"))
				_check(not claimed.state in ["opened", "partial"])
				if floor_number >= 11 and floor_number <= 20 and is_chest:
					_check(claimed.id in ["oak_chest", "buried_urn"], "cave has monumental chest art")
	_check(seen.size() == 12, "all finished object identities have a supported binding")
	var frames = 0
	for identity in seen:
		var fixture: Dictionary = seen[identity]
		var site: Dictionary = fixture.site.duplicate(true)
		var height = 0.0
		for claimed in [false, true]:
			site.claimed = claimed
			var frame = Art.frame(site, "forest", int(fixture.floor))
			_check(not frame.is_empty(), "texture load " + identity)
			if frame.is_empty(): continue
			var pose: Dictionary = catalog.objects[identity].frames[frame.state]
			_check(frame.id == identity)
			if not claimed: height = frame.height
			_check(frame.height == height, "depletion changed scale")
			_check(frame.foot == Vector2(pose.foot[0], pose.foot[1]))
			_check(frame.texture.margin == Rect2())
			_check(frame.texture.atlas.get_size() == Vector2(1255, 1255))
			_check(frame.texture.atlas.get_image().get_pixel(0, 0).a == 0)
			_check(frame.texture == Art.frame(site, "forest", int(fixture.floor)).texture)
			frames += 1
	_check(frames == 24)
	if failures == 0: print("EXPLORATION_OBJECT_ART_V06_PASS species=12 runtime_frames=24")
	_finish()
