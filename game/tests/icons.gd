extends SceneTree
## Model coverage: every catalog entry and every real skill node uses the library.
const Library = preload("res://scripts/icon_library.gd")
const IconArt = preload("res://scripts/icon_art.gd")
const Content = preload("res://scripts/content.gd")
const StatusMarkers = preload("res://scripts/status_markers.gd")
const Simulation = preload("res://scripts/simulation.gd")
const Build = preload("res://scripts/skill_build.gd")
var checks = 0
var failures: Array[String] = []
var coverage: Array = []

func _initialize():
	run.call_deferred()

func check(condition: bool, description: String):
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func verify_status_markers():
	for is_hero in [true, false]:
		check(StatusMarkers.keys_for({}, is_hero).is_empty(), "empty actor has no status icons")
		check(StatusMarkers.keys_for({"hp": 0, "slow_time": 3., "enemy_slow_time": 3., "invulnerable": 3., "job_status": {"bleed": {"time": 3.}}}, is_hero).is_empty(), "dead actor has no status icons")
	var hero = {"hp": 10, "enemy_slow_time": 2., "invulnerable": 1., "barrier_time": 3., "haste_time": 2., "job_state": {
		"shield": 12., "parry": 1., "counter": 2., "buffs": {
			"haste": {"time": 1.}, "speed": {"time": 1.}, "evade": {"time": 1.},
			"defense": {"time": 1.}, "armor": {"time": 1.}, "regen": {"time": 0.}, "attack": {"time": -1.}
		}
	}}
	var before = hero.duplicate(true)
	var hero_keys: Array = StatusMarkers.keys_for(hero, true)
	check(hero == before, "status lookup preserves hero combat state")
	check(hero_keys.size() == 8, "hero statuses deduplicate shared haste/shield/agility/defense icons")
	for key in ["slow", "invulnerable", "shield", "haste", "guard", "counter", "agility", "defense"]:
		check(hero_keys.count(key) == 1, "live hero status appears exactly once " + key)
	check("regen" not in hero_keys and "physical_attack" not in hero_keys, "expired hero buffs are hidden")
	var enemy = {"hp": 20, "slow_time": 2., "stun_time": 2., "taunt_time": 2., "stagger": {"state": "down"}, "job_status": {
		"slow": {"time": 2.}, "stun": {"time": 2.}, "bleed": {"time": 3.}, "break_armor": {"time": 2.},
		"blind": {"time": 0.}, "root": {"time": -1.}, "unrecognized_status": {"time": 2.}
	}}
	before = enemy.duplicate(true)
	var enemy_keys: Array = StatusMarkers.keys_for(enemy, false)
	check(enemy == before, "status lookup preserves enemy combat state")
	check(enemy_keys.size() == 5, "enemy statuses deduplicate timed and stagger sources")
	for key in ["slow", "stun", "taunt", "bleed", "armor_break"]:
		check(enemy_keys.count(key) == 1, "live enemy status appears exactly once " + key)
	check("blind" not in enemy_keys and "root" not in enemy_keys, "expired enemy statuses are hidden")
	for key in hero_keys + enemy_keys:
		check(Library.has_key(key), "live status has semantic artwork " + key)
	check(StatusMarkers.keys_for({"hp": 1, "stagger": {"state": "ready"}}, false).is_empty(), "ready boss is not shown as stunned")
	check(StatusMarkers.keys_for({"hp": 1, "stagger": {"state": "down"}}, false) == ["stun"], "down boss contributes stun marker")
	# Check expiry through production combat updates, not just a hand-authored
	# dictionary with timers already set to zero.
	var sim = Simulation.new(123)
	sim.enemies.clear()
	var p = sim.add_player(1, "상태 만료 검사", {"schema_version": 6, "level": 100, "class_id": "healer"})
	p.pos = Vector2(sim.map.rooms[1])
	var target = sim.spawn_enemy("shade", p.pos + Vector2.RIGHT, 1)
	p.barrier_time = .1
	p.haste_time = .1
	p.job_state.shield = 10.
	p.job_state.shield_time = .1
	sim.combat.jobs.buff(p, "haste", .2, .1)
	sim.combat.jobs.status(p, target, "weaken", .1)
	check("shield" in StatusMarkers.keys_for(p, true) and "haste" in StatusMarkers.keys_for(p, true), "live combat timers produce hero markers")
	check("weaken" in StatusMarkers.keys_for(target, false), "live applied combat debuff produces enemy marker")
	sim.combat.tick_player(p, .2)
	check("shield" not in StatusMarkers.keys_for(p, true) and "haste" not in StatusMarkers.keys_for(p, true), "combat update expires hero markers")
	check("weaken" not in StatusMarkers.keys_for(target, false), "combat update expires enemy marker")
	sim = null

func run():
	Content.initialize_jobs()
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/icons/semantic_catalog.json"))
	var known: Array = Library.keys()
	check(known.size() == 168, "library exposes all 168 semantic icons")
	var by_instance: Dictionary = {}
	var seen: Dictionary = {}
	for sheet in catalog.sheets:
		for index in range(sheet.items.size()):
			var key = str(sheet.items[index])
			check(not seen.has(key), "unique semantic key " + key)
			seen[key] = true
			check(key in known and Library.has_key(key), "catalog entry available " + key)
			var texture: Texture2D = Library.texture(key)
			check(texture != null, "texture loads " + key)
			if texture == null:
				continue
			var bounds = sheet.get("frames", [])[index] if sheet.has("frames") else [(index % 6) * 256, int(index / 6) * 256, 256, 256]
			var expected = Rect2(bounds[0], bounds[1], bounds[2], bounds[3])
			check(texture.get_size() == expected.size, "catalogued crop dimensions " + key)
			check(Library.texture(key) == texture, "stable texture cache " + key)
			check(not by_instance.has(texture.get_instance_id()), "distinct catalog regions " + key)
			by_instance[texture.get_instance_id()] = key
			if texture is AtlasTexture:
				check(texture.region == expected, "correct sheet cell " + key)
				check(texture.atlas != null and texture.atlas.get_size() == Vector2(1536, 1024), "correct atlas dimensions " + key)
				check(texture.atlas.resource_path == "res://assets/icons/wood-" + str(sheet.name) + ".png", "correct atlas source " + key)
			var button = Button.new()
			button.text = "Keep label"
			button.tooltip_text = "Keep meaning"
			Library.attach(button, key, 24)
			check(button.icon == texture, "button receives semantic icon " + key)
			check(button.text == "Keep label" and button.tooltip_text == "Keep meaning", "icon attachment preserves label and tooltip " + key)
			button.free()
	check(not Library.has_key("__missing_icon_for_test__"), "unknown key is not catalogued")
	check(Library.texture("__missing_icon_for_test__") == Library.texture("unknown"), "unknown key returns visible fallback")
	check(Library.texture("") != null, "empty key is safe")
	check(Library.keys() == known, "fallback requests do not expand the catalog")
	var node_lookup: Dictionary = {}
	for cls in Content.SKILLS:
		for node in Build.nodes_for(cls):
			node_lookup[node.id] = node
	var classes: Dictionary = {}
	var aliases: Dictionary = {}
	for cls in Content.SKILLS:
		classes[cls] = 0
		for node in Build.nodes_for(cls):
			var texture: Texture2D = IconArt.skill(node)
			check(texture != null, "skill has a texture " + str(node.id))
			var key = str(by_instance.get(texture.get_instance_id(), "")) if texture else ""
			check(not key.is_empty() and key not in ["unknown", "skill_empty"], "skill has an explicit semantic icon " + str(node.id))
			check(IconArt.key_for_skill(node) == key, "declared semantic mapping matches texture " + str(node.id))
			check(IconArt.skill(node) == texture, "skill uses cached texture " + str(node.id))
			if node.get("effect", "") == "upgrade":
				var target = node_lookup.get(node.get("target", ""), {})
				check(not target.is_empty(), "upgrade target exists " + str(node.id))
				check(not target.is_empty() and IconArt.skill(target) == texture, "upgrade preserves target's symbol " + str(node.id))
			classes[cls] += 1
			if not aliases.has(key):
				aliases[key] = []
			aliases[key].append(node.id)
			coverage.append({"class_id": cls, "skill_id": node.id, "name": node.name, "effect": node.effect, "mode": node.get("mode", ""), "icon": key})
	check(coverage.size() == 1510, "all 610 originals and 900 specializations audited")
	check(coverage.filter(func(row):return row.effect=="constellation").size()==900,"all specialization effects explicitly mapped")
	for pair in [["rogue_venom","poison"],["mage_burn","burn"],["ranger_snare","trap"],["fighter_crush","charge"],["stagger_power","stagger"],["skill_haste","cooldown"]]:
		check(IconArt.key_for_skill({"effect":"constellation","effects":{pair[0]:1}})==pair[1],"specialization represents actual behavior "+pair[0])
	check(classes.size() == 20, "all 20 classes audited")
	# An empty slot is an expected interface state, unlike an unmapped skill.
	check(IconArt.skill({}) != null, "empty skill slot is safe")
	verify_status_markers()
	var output_dir = ProjectSettings.globalize_path("res://../artifacts")
	check(DirAccess.make_dir_recursive_absolute(output_dir) == OK, "create coverage output directory")
	var report = {"status": "PASS" if failures.is_empty() else "FAIL", "checks": checks, "failures": failures, "icons": known.size(), "nodes": coverage.size(), "classes": classes, "aliases": aliases, "skills": coverage}
	var file = FileAccess.open(output_dir.path_join("icon-skill-coverage.json"), FileAccess.WRITE)
	check(file != null, "write semantic coverage report")
	if file:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("ICON_MODEL_TESTS checks=", checks, " failures=", failures.size(), " icons=", known.size(), " skills=", coverage.size(), " classes=", classes.size())
	quit(0 if failures.is_empty() else 1)
