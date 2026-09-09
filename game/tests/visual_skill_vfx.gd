extends SceneTree
## Real combat dispatch and the main scene's CanvasItem/projectile draw paths.
const Content = preload("res://scripts/content.gd")
const Dungeon = preload("res://scripts/dungeon.gd")
const Catalog = preload("res://scripts/skill_vfx_catalog.gd")
const CASES = [
	["mage-thunder", "mage", "thunder", "", "thunder"],
	["mage-frost", "mage", "frost_nova", "", "frost"],
	["mage-fire", "mage", "mage_burst", "", "fire"],
	["gambler-cards", "gambler", "", "settle", "cards"],
	["reaper-chain", "reaper", "", "chain_pull", "chain"],
	["healer-heal", "healer", "", "heal", "heal"],
	["breaker-impact", "breaker", "", "charge", "impact"],
	["summoner-summon", "summoner", "", "summon", "summon"],
]
var checks = 0
var failures: Array[String] = []
var captures = 0
var logger: RenderErrors


# Godot 4.6 Logger catches errors raised from deferred _draw callbacks as well
# as the test coroutine. Backtraces are not retained, so they cannot retain nodes.
# https://docs.godotengine.org/en/4.6/classes/class_logger.html
class RenderErrors extends Logger:
	var errors: Array[String] = []
	var mutex = Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		errors.append("%s:%d %s: %s %s" % [file, line, function, code, rationale])
		mutex.unlock()

	func snapshot() -> Array[String]:
		mutex.lock()
		var result: Array[String] = errors.duplicate()
		mutex.unlock()
		return result


func _initialize() -> void:
	logger = RenderErrors.new()
	OS.add_logger(logger)
	run.call_deferred()


func check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures.append(description)
		print("VISUAL_SKILL_VFX_FAIL ", description)
	return condition


func definition(entry: Array) -> Dictionary:
	for node in Content.SKILLS[entry[1]]:
		if node.effect != "active":
			continue
		if (not str(entry[2]).is_empty() and node.id == entry[2]) or (not str(entry[3]).is_empty() and node.get("mode", "") == entry[3]):
			return node
	return {}


func capture_case(game, entry: Array) -> void:
	var node = definition(entry)
	if not check(not node.is_empty(), "skill definition exists: " + entry[0]):
		return
	var session = game.session
	var sim = session.sim
	game.effects.clear()
	game.smooth_positions.clear()
	sim.events.clear()
	sim.players.clear()
	sim.enemies.clear()
	sim.drops.clear()
	sim.combat.projectiles.clear()
	sim.combat.skills.zones.clear()
	sim.rng.seed = 246810
	var p = sim.add_player(1, "이펙트 시연", {
		"schema_version": 6, "level": 100, "class_id": entry[1],
		"skill_ranks": {node.id: 3}, "skill_loadout": {"skill_q": node.id},
		"tutorial_done": true,
	})
	p.pos = Vector2(sim.map.rooms[1])
	p.aim = Vector2.RIGHT
	p.dir = Vector2.ZERO
	p.hp = maxi(1, int(p.max_hp * 0.45))
	p.stamina = p.max_stamina
	for i in range(3):
		var location = sim.combat.skills.target(p, 2.4 + i * 0.7)
		var enemy = sim.spawn_enemy("shade", location, 1)
		enemy.hp = 1000000
		enemy.max_hp = 1000000
	session.refresh()
	if not check(session.act("skill_q"), "session.act casts " + str(node.id)):
		return
	# Advance only combat windup; no enemy AI or keyboard/mouse simulation runs.
	var steps = 0
	while not p.job_state.get("casting", {}).is_empty() and steps < 160:
		sim.combat.tick_player(p, 0.05)
		steps += 1
	check(p.job_state.get("casting", {}).is_empty(), "windup releases: " + str(node.id))
	if entry[1] == "gambler":
		check(not sim.combat.projectiles.is_empty(), "gambler creates real card projectiles")
		# A short real update separates the projectiles from their owner's sprite.
		sim.combat.tick_projectiles(0.055)
	if entry[1] == "summoner":
		sim.combat.jobs.tick(p, 0.2)
		check(not p.job_state.pets.is_empty(), "summoner creates a rendered companion")
	session.flush_events()
	game.effects = game.effects.filter(func(event): return event.get("type", "") == "skill_fx" and event.get("skill_phase", "") != "windup")
	var matched = 0
	for event in game.effects:
		if event.get("skill_id", "") == node.id:
			matched += 1
			check(Catalog.profile(event).family == entry[4], "expected visual family: " + str(node.id))
		# Fix the visual pose without replacing the actual dispatched event.
		event.life = float(event.max_life) * (0.76 if entry[4] == "thunder" else 0.6)
	check(matched > 0, "main event consumer receives cast: " + str(node.id))
	p.motion_time = minf(float(p.motion_duration) * 0.6, float(p.motion_time))
	game.visual_time = 0.4
	game.camera_pos = Dungeon.iso(p.pos)
	game.battle_anchor_y = 475.0
	game.toast.text = str(Content.CLASSES[entry[1]].name) + "  ·  " + str(node.name) + "  ·  랭크 3"
	game.toast.visible = true
	session.refresh()
	game.forest.update_camera(0.0)
	game.queue_redraw()
	game.map_overlay.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path = ProjectSettings.globalize_path("res://../artifacts/skill-effects-combat-" + entry[0] + ".png")
	var image = root.get_texture().get_image()
	if check(not image.is_empty() and image.get_width() == 1440 and image.get_height() == 900, "combat capture dimensions: " + entry[0]):
		if check(image.save_png(path) == OK, "write combat capture: " + entry[0]):
			captures += 1
			print("SKILL_VFX_COMBAT_CAPTURE ", path)


func run() -> void:
	Content.initialize_jobs()
	check(DisplayServer.get_name() != "headless", "combat captures require a real renderer")
	if not failures.is_empty():
		finish()
		return
	var output = ProjectSettings.globalize_path("res://../artifacts")
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "create capture output directory")
	var game = load("res://main.tscn").instantiate()
	game.options.mute = true
	game.options["save-dir"] = ProjectSettings.globalize_path("res://../runtime/visual-skill-vfx/" + str(Time.get_ticks_usec()))
	root.add_child(game)
	# Disabling processing also disables child HUD animation and live input.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.session.set_physics_process(false)
	await process_frame
	game.join_game()
	var initial = game.session.sim.players[1]
	initial.tutorial_done = true
	check(game.session.travel("town"), "travel to town using the local session")
	check(game.session.travel("forest"), "enter forest floor one using the local session")
	check(game.session.sim.map.zone == "forest" and game.session.sim.map.floor_number == 1, "forest combat stage loaded")
	for entry in CASES:
		await capture_case(game, entry)
	check(captures == CASES.size(), "all eight representative casts captured")
	game.stop_audio()
	game.session.disconnect_game()
	game.queue_free()
	await process_frame
	await process_frame
	finish()


func finish() -> void:
	var runtime_errors = logger.snapshot()
	check(runtime_errors.is_empty(), "no engine or script errors in actual combat rendering")
	for message in runtime_errors:
		print("VISUAL_SKILL_VFX_RENDER_ERROR ", message)
	OS.remove_logger(logger)
	print("VISUAL_SKILL_VFX_TESTS checks=", checks, " failures=", failures.size(), " captures=", captures, " render_errors=", runtime_errors.size())
	if failures.is_empty():
		print("VISUAL_SKILL_VFX_PASS")
	quit(0 if failures.is_empty() else 1)
