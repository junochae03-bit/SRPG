extends SceneTree
const Ecology = preload("res://scripts/monster_ecology_v071.gd")
const Attacks = preload("res://scripts/monster_attacks.gd")
var checks: int = 0
var failures: int = 0
var finished: bool = false

class TestMap extends RefCounted:
	var wall: float = 100.0
	func walkable(pos: Vector2) -> bool: return pos.x < wall
	func line_clear(a: Vector2, b: Vector2) -> bool: return a.x < wall and b.x < wall

class ImpactRecorder extends RefCounted:
	var impacts: Array = []
	func contains(area: Dictionary, pos: Vector2) -> bool: return Attacks.contains(area, pos)
	func impact(area: Dictionary, enemy: Dictionary):
		impacts.append({"area": area.duplicate(true), "enemy": enemy.id})

class TestSim extends RefCounted:
	var map = TestMap.new()
	var monster_attacks = ImpactRecorder.new()
	var enemies: Dictionary = {}
	var players: Dictionary = {1: {"hp": 100, "pos": Vector2(2, 0)}}

func _initialize():
	create_timer(150).timeout.connect(_timeout)
	call_deferred("_run")

func _check(condition: bool, label: String):
	checks += 1
	if not condition:
		failures += 1
		push_error("Ecology runtime check %d: %s" % [checks, label])

func _finish():
	finished = true
	print("MONSTER_ECOLOGY_V071_DONE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _timeout():
	if not finished:
		failures += 1
		push_error("Ecology runtime test interrupted or timed out")
		_finish()

func _kind(shape: String) -> String:
	for kind in Ecology.data().monsters:
		if Ecology.data().monsters[kind].pattern.shape == shape: return kind
	return ""

func _enemy(kind: String) -> Dictionary:
	return {"id": 10, "kind": kind, "hp": 100, "pos": Vector2.ZERO,
		"windup": 0.0, "attack_motion": 0.0, "cooldown": 0.0}

func _run():
	var data = Ecology.data()
	_check(data.get("monsters", {}).size() == 29, "approved species count")
	if data.get("monsters", {}).size() != 29: _finish(); return
	var definitions = {"legacy": {"ai": "melee"}, "archer": {"ai": "ranged"}}
	var injected = Ecology.inject_definitions(definitions)
	_check(injected.ok and injected.added.size() == 29, "inject all definitions")
	_check(Ecology.inject_definitions(definitions).added.is_empty(), "idempotent injection")
	var collision = {_kind("cone"): {"health": -1}}
	var before = collision.duplicate(true)
	_check(not Ecology.inject_definitions(collision).ok and collision == before, "transactional collision")
	var appearance_count = 0
	var drops_count = 0
	for kind in data.monsters:
		var row: Dictionary = data.monsters[kind]
		for floor_key in row.appearances:
			var actual = Ecology.stats(kind, int(floor_key))
			appearance_count += 1
			for field in ["health", "damage", "speed", "xp", "gold", "level"]:
				_check(actual[field] == row.appearances[floor_key][field], "exact floor stat %s/%s/%s" % [kind, floor_key, field])
			_check(actual.range == row.pattern.range_tiles, "attack trigger range")
			_check(actual.species_drop_materials == row.species_drop_materials, "generic material exclusions")
		_check(Ecology.stats(kind, 0).is_empty() and Ecology.stats(kind, 10).is_empty(), "no town/raid stats")
		var rng = RandomNumberGenerator.new()
		var oracle = RandomNumberGenerator.new()
		rng.seed = 718
		oracle.seed = 718
		for iteration in range(30):
			var expected: Array = []
			for drop in row.drops:
				if oracle.randf() < float(drop.chance): expected.append(drop)
			_check(Ecology.roll_drops(kind, rng) == expected, "exact independent fixed drop roll")
		drops_count += row.drops.size()
		_check(row.drops.size() == 3 and Ecology.drop_materials(kind).size() == 3, "three dedicated drops")
		var areas = Ecology.pattern(kind, Vector2.ZERO, Vector2.RIGHT * 2)
		_check(areas.size() == (2 if row.pattern.shape == "two_bites" else 1), "physical zone count")
		for area in areas:
			_check(area.multiplier == row.pattern.damage_multiplier, "source damage multiplier")
			_check(area.radius == row.physical_mapping.radius and area.slow == 0 and area.drain == 0, "explicit physical radius and no status")
	_check(appearance_count == 261 and drops_count == 87, "all authored rows")
	for held in data.deferred_ids:
		_check(not Ecology.recognizes(held) and Ecology.stats(held, 1).is_empty(), "held species excluded")
	for region_index in range(10):
		var floor_number = region_index * 10 + 1
		for slot in range(4):
			var source_kind = str(data.regions[region_index].species[slot])
			var expected = source_kind if Ecology.recognizes(source_kind) else "legacy"
			_check(Ecology.candidate(floor_number, "legacy", .05 + slot * .1) == expected, "original 10% slot retained")
		_check(Ecology.candidate(floor_number, "legacy", .4) == "legacy", "60% original pool")
		_check(Ecology.candidate(region_index * 10 + 10, "legacy", .05) == "legacy", "raid never replaced")
	_check(Ecology.candidate(1, "legacy", NAN) == "legacy", "invalid roll")
	var sample_kind = str(data.monsters.keys()[0])
	var sample_floor = int(data.monsters[sample_kind].spawn.floor_min)
	var baseline = str(data.monsters[sample_kind].equipment_baseline_by_floor[str(sample_floor)])
	var gear = Ecology.equipment_rows(sample_kind, sample_floor, {baseline: [{"kind": "weapon"}, {"kind": "material"}, {"kind": "potion"}, {"kind": "armor"}]})
	_check(gear == [{"kind": "weapon"}, {"kind": "armor"}], "optional equipment excludes legacy materials")
	var placements: Array = [
		{"kind": "legacy", "role": "normal", "room": 1, "mob_index": 0, "pos": Vector2(2, 3), "formation": "pair"},
		{"kind": "legacy", "role": "normal", "room": 1, "mob_index": 1, "pos": Vector2(3, 3)},
		{"kind": "legacy", "role": "guardian", "room": 1, "pos": Vector2.ONE},
		{"kind": "legacy", "role": "elite", "room": 2, "pos": Vector2.ONE},
		{"kind": "legacy", "role": "normal", "room": 1, "risk_reinforcement": true, "pos": Vector2.ONE}]
	before = placements.duplicate(true)
	var replacements = 0
	for seed_value in range(300):
		var result = Ecology.replace_candidates(placements, 1, seed_value, definitions)
		_check(result == Ecology.replace_candidates(placements, 1, seed_value, definitions), "deterministic replacement")
		_check(result.size() == placements.size(), "no new density")
		for index in range(result.size()):
			_check(result[index].pos == placements[index].pos, "positions preserved")
			if index >= 2: _check(result[index] == placements[index], "special slots preserved")
			elif result[index].kind != "legacy": replacements += 1
		_check(Ecology._group_valid([result[0], result[1]], definitions, 1), "valid changed group")
	_check(replacements > 0 and placements == before, "replacements occur without mutating input")
	_check(Ecology.replace_candidates(placements, 10, 1, definitions) == placements, "raid preserved")
	_test_attacks()
	_finish()

func _test_attacks():
	var sim = TestSim.new()
	var module = Ecology.new(sim)
	var enemy = _enemy(_kind("two_bites"))
	sim.enemies[10] = enemy
	var timing: Dictionary = Ecology.data().monsters[enemy.kind].pattern
	_check(module.begin(enemy, Vector2(2, 0)), "begin handled")
	_check(enemy.windup == timing.windup_seconds and enemy.attack_pos == Vector2(2, 0), "windup and locked target")
	module.release(enemy)
	_check(sim.monster_attacks.impacts.is_empty(), "no early release")
	enemy.windup = 0
	module.release(enemy)
	_check(enemy.cooldown == timing.cooldown_seconds and enemy.attack_motion == timing.recovery_seconds, "authored cooldown/recovery")
	_check(sim.monster_attacks.impacts.size() == 1 and module.pending.size() == 1, "first bite and delayed bite")
	module.release(enemy)
	_check(sim.monster_attacks.impacts.size() == 1, "release idempotent")
	module.tick(.24)
	_check(sim.monster_attacks.impacts.size() == 1, "second bite not early")
	module.tick(.02)
	_check(sim.monster_attacks.impacts.size() == 2 and module.pending.is_empty(), "second bite exactly once")
	module.tick(1)
	_check(sim.monster_attacks.impacts.size() == 2, "no repeated delayed hit")
	for cancellation in ["stun_time", "hp", "explicit", "token"]:
		module.cancel(enemy)
		enemy.hp = 100
		enemy.stun_time = 0
		module.begin(enemy, Vector2(2, 0))
		enemy.windup = 0
		module.release(enemy)
		var count = sim.monster_attacks.impacts.size()
		if cancellation == "stun_time": enemy.stun_time = 1
		elif cancellation == "hp": enemy.hp = 0
		elif cancellation == "token":
			enemy.attack_motion = 0
			module.begin(enemy, Vector2(3, 0))
		else: module.cancel(enemy)
		module.tick(.3)
		_check(sim.monster_attacks.impacts.size() == count and module.pending.is_empty(), "cancel delayed hit: " + cancellation)
	module.cancel(enemy)
	enemy = _enemy(_kind("projectile"))
	sim.enemies[10] = enemy
	sim.monster_attacks.impacts.clear()
	module.begin(enemy, Vector2(2, 0))
	enemy.windup = 0
	module.release(enemy)
	_check(sim.monster_attacks.impacts.is_empty() and module.shots.size() == 1, "projectile moves rather than instant hit")
	module.tick(.2)
	_check(sim.monster_attacks.impacts.is_empty() and is_equal_approx(module.shots[0].pos.x, .8), "projectile authored 4 tiles/sec")
	_check(module.projectile_snapshots().size() == 1 and module.telegraphs().size() == 1, "live shot snapshot and warning")
	module.tick(.3)
	_check(sim.monster_attacks.impacts.size() == 1 and module.shots.is_empty(), "swept projectile contacts once")
	module.tick(10)
	_check(sim.monster_attacks.impacts.size() == 1, "no repeat projectile impact")
	for cancel_type in ["wall", "death", "stun", "large_delta"]:
		module.cancel(enemy)
		enemy.hp = 100
		enemy.stun_time = 0
		sim.map.wall = 1.0 if cancel_type == "wall" else 100.0
		module.begin(enemy, Vector2(2, 0))
		enemy.windup = 0
		module.release(enemy)
		if cancel_type == "death": enemy.hp = 0
		if cancel_type == "stun": enemy.stun_time = 1
		var count = sim.monster_attacks.impacts.size()
		module.tick(10)
		_check(sim.monster_attacks.impacts.size() == count + (1 if cancel_type == "large_delta" else 0), "shot wall/cancel/no tunneling: " + cancel_type)
		_check(module.shots.is_empty(), "shot terminates")
	enemy = _enemy(_kind("short_dash"))
	sim.enemies[10] = enemy
	sim.map.wall = 1.0
	module.begin(enemy, Vector2(3, 0))
	enemy.windup = 0
	module.release(enemy)
	_check(enemy.pos.x > 0 and enemy.pos.x < 1.0, "dash blocked by wall")
	_check(sim.monster_attacks.impacts.back().area.pos == enemy.pos, "dash hit area ends at actual position")
	_check(not Attacks.contains(sim.monster_attacks.impacts.back().area, Vector2(2, 0)), "dash does not reach behind wall")
	module.cancel(enemy)
	_check(not Ecology.recovering(enemy) and module.telegraphs().is_empty(), "cancel clears recovery and telegraph")
