extends RefCounted
## No World/Content preload: the caller may inject definitions during startup.
const PATH = "res://data/monster_ecology_v071.json"
static var _data: Dictionary = {}
static var _loaded: bool = false
var sim_ref: WeakRef
var pending: Array = []
var shots: Array = []
var serial: int = 0
var sim:
	get: return sim_ref.get_ref() if sim_ref != null else null

func _init(owner = null):
	if owner != null: sim_ref = weakref(owner)

static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if parsed is Dictionary: _data = parsed
	return _data

static func recognizes(kind: String) -> bool:
	return data().get("monsters", {}).has(kind)

static func definition(kind: String) -> Dictionary:
	return data().get("monsters", {}).get(kind, {}).get("definition", {}).duplicate(true)

static func inject_definitions(target: Dictionary) -> Dictionary:
	var conflicts: Array = []
	for kind in data().get("monsters", {}):
		if target.has(kind) and target[kind] != definition(kind): conflicts.append(kind)
	if not conflicts.is_empty(): return {"ok": false, "conflicts": conflicts, "added": []}
	var added: Array = []
	for kind in data().get("monsters", {}):
		if not target.has(kind): target[kind] = definition(kind); added.append(kind)
	return {"ok": true, "conflicts": [], "added": added}

static func stats(kind: String, floor_number: int) -> Dictionary:
	if not recognizes(kind): return {}
	var source: Dictionary = data().monsters[kind].appearances.get(str(floor_number), {})
	if source.is_empty(): return {}
	var result: Dictionary = {}
	for key in ["health", "damage", "speed", "xp", "gold", "level"]: result[key] = source[key]
	result["range"] = data().monsters[kind].pattern.range_tiles
	result["species_drop_materials"] = drop_materials(kind)
	return result

static func drop_materials(kind: String) -> Array:
	return data().get("monsters", {}).get(kind, {}).get("species_drop_materials", []).duplicate()

static func drop_rows(kind: String) -> Array:
	return data().get("monsters", {}).get(kind, {}).get("drops", []).duplicate(true)

static func roll_drops(kind: String, rng: RandomNumberGenerator) -> Array:
	var result: Array = []
	for row in drop_rows(kind):
		if rng.randf() < float(row.chance): result.append(row)
	return result

static func equipment_rows(kind: String, floor_number: int, legacy_tables: Dictionary) -> Array:
	var baseline = str(data().get("monsters", {}).get(kind, {}).get("equipment_baseline_by_floor", {}).get(str(floor_number), ""))
	var result: Array = []
	for row in legacy_tables.get(baseline, []):
		if row.get("kind", "") in ["weapon", "armor", "accessory"]: result.append(row.duplicate(true))
	return result

static func candidate(floor_number: int, original: String, roll: float) -> String:
	if floor_number < 1 or floor_number > 100 or floor_number % 10 == 0: return original
	if not is_finite(roll) or roll < 0 or roll >= .4: return original
	var region: Dictionary = data().regions[int((floor_number - 1) / 10)]
	var kind = str(region.species[mini(3, int(floor(roll * 10)))])
	return kind if recognizes(kind) and not stats(kind, floor_number).is_empty() else original

static func _group_valid(group: Array, definitions: Dictionary, floor_number: int) -> bool:
	var counts: Dictionary = {}
	var ranged = 0
	var poison = false
	for entry in group:
		var kind = str(entry.get("kind", ""))
		counts[kind] = int(counts.get(kind, 0)) + 1
		var config: Dictionary = definition(kind) if recognizes(kind) else definitions.get(kind, {})
		if config.get("ai", "") in ["ranged", "spore", "healer"]: ranged += 1
		if recognizes(kind): poison = poison or data().monsters[kind].source_combat.damage_element == "poison"
	if counts.size() > 2 or ranged > 1 or (floor_number <= 3 and ranged > 0 and poison): return false
	for kind in counts:
		if not recognizes(kind): continue
		var row: Dictionary = data().monsters[kind]
		if int(counts[kind]) < int(row.spawn.group_size[0]) or int(counts[kind]) > int(row.spawn.group_size[1]): return false
		for other in row.ecology.prey_ids + row.ecology.predator_ids:
			if counts.has(other): return false
	return true

static func replace_candidates(placements: Array, floor_number: int, seed_value: int, definitions: Dictionary) -> Array:
	var result = placements.duplicate(true)
	if floor_number < 1 or floor_number > 100 or floor_number % 10 == 0: return result
	var rooms: Dictionary = {}
	for index in range(result.size()):
		var entry: Dictionary = result[index]
		if entry.get("role", "") != "normal" or entry.get("risk_reinforcement", false): continue
		if str(entry.get("kind", "")).is_empty(): continue
		var room = int(entry.get("room", -1))
		if not rooms.has(room): rooms[room] = []
		rooms[room].append(index)
	for room in rooms:
		var group: Array = []
		var changed = false
		for index in rooms[room]:
			var entry: Dictionary = result[index]
			var rng = RandomNumberGenerator.new()
			rng.seed = hash("ecology:%d:%d:%d:%d" % [seed_value, floor_number, room, int(entry.get("mob_index", index))])
			var kind = candidate(floor_number, str(entry.kind), rng.randf())
			changed = changed or kind != entry.kind
			entry.kind = kind
			if recognizes(kind): entry["combat_role"] = "ranged" if definition(kind).ai == "ranged" else "frontline"
			group.append(entry)
		if changed and not _group_valid(group, definitions, floor_number):
			for index in rooms[room]: result[index] = placements[index].duplicate(true)
	return result

static func _area(shape: String, origin: Vector2, target: Vector2, radius: float, delay: float, multiplier: float) -> Dictionary:
	return {"shape": shape, "from": origin, "pos": target, "radius": radius,
		"delay": delay, "multiplier": multiplier, "drain": 0.0, "slow": 0.0,
		"knock": 0.0, "sound": "hit_sword"}

static func pattern(kind: String, origin: Vector2, target: Vector2) -> Array:
	if not recognizes(kind): return []
	var row: Dictionary = data().monsters[kind]
	var source: Dictionary = row.pattern
	var mapping: Dictionary = row.physical_mapping
	var direction = origin.direction_to(target)
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var result: Array = []
	if source.shape == "two_bites":
		for delay in mapping.hit_delays:
			result.append(_area("circle", origin, target, mapping.radius, delay, source.damage_multiplier))
	elif source.shape in ["projectile", "short_dash"]:
		result.append(_area("line", origin, origin + direction * float(mapping.distance), mapping.radius, 0, source.damage_multiplier))
	elif source.shape == "cone":
		result.append(_area("cone", origin, origin + direction, mapping.radius, 0, source.damage_multiplier))
		result[0]["angle"] = mapping.angle
	else:
		result.append(_area("circle", origin, target, mapping.radius, 0, source.damage_multiplier))
	for index in range(result.size()):
		result[index]["ecology"] = true
		result[index]["pattern_id"] = source.id
		result[index]["zone_index"] = index
	return result

static func recovering(enemy: Dictionary) -> bool:
	return recognizes(str(enemy.get("kind", ""))) and float(enemy.get("attack_motion", 0)) > 0

static func _disabled(enemy: Dictionary) -> bool:
	return enemy.is_empty() or float(enemy.get("hp", 0)) <= 0 or float(enemy.get("stun_time", 0)) > 0 or enemy.get("stagger", {}).get("state", "") in ["check", "down"]

func cancel(enemy: Dictionary):
	var id = int(enemy.get("id", -1))
	pending = pending.filter(func(row): return int(row.enemy) != id)
	shots = shots.filter(func(row): return int(row.enemy) != id)
	enemy.windup = 0.0
	enemy.attack_motion = 0.0
	enemy["attack_impact_time"] = 0.0
	enemy["ecology_stage"] = "idle"
	enemy.erase("attack_areas")
	enemy.erase("ecology_attack_token")

func begin(enemy: Dictionary, target: Vector2) -> bool:
	var kind = str(enemy.get("kind", ""))
	if not recognizes(kind): return false
	if _disabled(enemy) or enemy.get("boss", false) or enemy.get("raid", false):
		cancel(enemy)
		return true
	if enemy.get("ecology_stage", "") == "windup" or recovering(enemy): return true
	serial += 1
	enemy["ecology_attack_token"] = serial
	enemy["ecology_stage"] = "windup"
	enemy.attack_pos = target
	enemy.windup = float(data().monsters[kind].pattern.windup_seconds)
	enemy.attack_motion = 0.0
	enemy["attack_impact_time"] = 0.0
	enemy["attack_motion_kind"] = "attack"
	enemy["attack_areas"] = pattern(kind, enemy.pos, target)
	return true

func _current(id: int, token: int) -> Dictionary:
	var enemy: Dictionary = sim.enemies.get(id, {})
	if _disabled(enemy) or int(enemy.get("ecology_attack_token", -1)) != token: return {}
	return enemy

func _impact(enemy: Dictionary, area: Dictionary):
	if _disabled(enemy): return
	enemy["attack_impact_time"] = .12
	sim.monster_attacks.impact(area, enemy)

func release(enemy: Dictionary) -> bool:
	var kind = str(enemy.get("kind", ""))
	if not recognizes(kind): return false
	if _disabled(enemy): cancel(enemy); return true
	if enemy.get("ecology_stage", "") != "windup" or float(enemy.get("windup", 0)) > 0: return true
	var row: Dictionary = data().monsters[kind]
	var areas: Array = enemy.get("attack_areas", []).duplicate(true)
	enemy["ecology_stage"] = "recovery"
	enemy.windup = 0.0
	enemy.attack_motion = float(row.pattern.recovery_seconds)
	enemy["attack_motion_duration"] = enemy.attack_motion
	enemy["attack_motion_kind"] = "attack"
	enemy.cooldown = float(row.pattern.cooldown_seconds)
	enemy.erase("attack_areas")
	for area in areas:
		if _disabled(enemy): break
		area["enemy"] = enemy.id
		area["attack_instance"] = enemy.ecology_attack_token
		if row.pattern.shape == "projectile":
			enemy["attack_impact_time"] = .12
			shots.append({"enemy": enemy.id, "token": enemy.ecology_attack_token, "area": area,
				"pos": area.from, "dir": area.from.direction_to(area.pos),
				"remaining": float(row.physical_mapping.distance), "speed": float(row.physical_mapping.speed)})
		elif row.pattern.shape == "short_dash":
			var direction: Vector2 = area.from.direction_to(area.pos)
			var remaining: float = area.from.distance_to(area.pos)
			while remaining > .001:
				var step = minf(.16, remaining)
				var next: Vector2 = enemy.pos + direction * step
				if not sim.map.walkable(next + direction * .18) or not sim.map.line_clear(enemy.pos, next): break
				enemy.pos = next
				remaining -= step
			area.pos = enemy.pos
			_impact(enemy, area)
		elif float(area.delay) > 0:
			pending.append({"enemy": enemy.id, "token": enemy.ecology_attack_token, "timer": float(area.delay), "area": area})
		else:
			_impact(enemy, area)
	return true

func _touches(area: Dictionary) -> bool:
	for player in sim.players.values():
		if player.get("hp", 0) > 0 and not player.get("network_leaving", false) and sim.monster_attacks.contains(area, player.pos): return true
		for pet in player.get("job_state", {}).get("pets", []):
			if pet.get("hp", 0) > 0 and sim.monster_attacks.contains(area, pet.pos): return true
	return false

func tick(delta: float):
	if sim == null or not is_finite(delta) or delta <= 0: return
	for enemy in sim.enemies.values():
		if not recognizes(str(enemy.get("kind", ""))): continue
		enemy["attack_impact_time"] = maxf(0, float(enemy.get("attack_impact_time", 0)) - delta)
		if _disabled(enemy): cancel(enemy)
	var keep: Array = []
	for record in pending:
		var enemy = _current(int(record.enemy), int(record.token))
		if enemy.is_empty(): continue
		record.timer -= delta
		if record.timer <= 0: _impact(enemy, record.area)
		else: keep.append(record)
	pending = keep
	keep = []
	for shot in shots:
		var enemy = _current(int(shot.enemy), int(shot.token))
		if enemy.is_empty(): continue
		var travel = minf(float(shot.remaining), float(shot.speed) * delta)
		var stopped = false
		while travel > .00001:
			var step = minf(.16, travel)
			var next: Vector2 = shot.pos + shot.dir * step
			if not sim.map.walkable(next) or not sim.map.line_clear(shot.pos, next): stopped = true; break
			var swept: Dictionary = shot.area.duplicate(true)
			swept.from = shot.pos
			swept.pos = next
			shot.pos = next
			shot.remaining -= step
			travel -= step
			if _touches(swept): _impact(enemy, swept); stopped = true; break
		if not stopped and shot.remaining > .00001: keep.append(shot)
	shots = keep

func telegraphs() -> Array:
	var result: Array = []
	for record in pending:
		if _current(int(record.enemy), int(record.token)).is_empty(): continue
		var area: Dictionary = record.area.duplicate(true)
		area["timer"] = record.timer
		result.append(area)
	for shot in shots:
		if _current(int(shot.enemy), int(shot.token)).is_empty(): continue
		var area: Dictionary = shot.area.duplicate(true)
		area.from = shot.pos
		area.pos = shot.pos + shot.dir * shot.remaining
		area["timer"] = shot.remaining / shot.speed
		result.append(area)
	return result

func projectile_snapshots() -> Array:
	var result: Array = []
	for shot in shots:
		if _current(int(shot.enemy), int(shot.token)).is_empty(): continue
		result.append({"enemy": shot.enemy, "attack_instance": shot.token, "pos": shot.pos,
			"dir": shot.dir, "speed": shot.speed, "radius": shot.area.radius, "physical": true})
	return result
