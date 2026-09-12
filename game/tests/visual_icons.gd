extends SceneTree
## Real Godot rendering of all icon cells plus the UI that consumes them.
const Library = preload("res://scripts/icon_library.gd")
const IconArt = preload("res://scripts/icon_art.gd")
const Content = preload("res://scripts/content.gd")
const Dungeon = preload("res://scripts/dungeon.gd")
const Stagger = preload("res://scripts/boss_stagger.gd")
const StatusMarkers = preload("res://scripts/status_markers.gd")
const GatArt = preload("res://scripts/gat_art.gd")
const Build = preload("res://scripts/skill_build.gd")
var checks = 0
var failures: Array[String] = []
var captures: Array[String] = []
var logger: RenderErrors

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

class Gallery extends Node2D:
	var icon_size = 24
	var catalog: Array = []
	var font: Font = ThemeDB.fallback_font
	var chroma_probe: Texture2D
	func _ready():
		material = GatArt.material()
		# The production shader keys atlas-sized textures. This exact-color probe
		# verifies actual GPU keying and cream preservation, not a CPU imitation.
		var probe = Image.create(1536, 1024, false, Image.FORMAT_RGBA8)
		probe.fill(Color("ff00ff"))
		probe.fill_rect(Rect2i(768, 0, 768, 1024), Color("f1e7d4"))
		chroma_probe = ImageTexture.create_from_image(probe)
	func _draw():
		draw_rect(Rect2(0, 0, 1600, 900), Color("182c30"))
		draw_string(font, Vector2(24, 38), "SEMANTIC ICON LIBRARY  /  168 ICONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("fff2d6"))
		draw_string(font, Vector2(24, 68), "%d logical px / Full HD x1.2  |  native GPU chroma on light / dark surfaces" % icon_size, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("b5c5ba"))
		if chroma_probe:
			draw_texture_rect(chroma_probe, Rect2(1216, 20, 192, 32), false)
			draw_string(font, Vector2(1220, 69), "KEY REMOVED  /  CREAM KEPT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b5c5ba"))
		for index in range(catalog.size()):
			var key = str(catalog[index])
			var at = Vector2(22 + (index % 14) * 100, 100 + int(index / 14) * 64)
			var background = Color("f1e7d4") if int(index / 14) % 2 == 0 else Color("31494a")
			draw_rect(Rect2(at, Vector2(96, 60)), background)
			var texture: Texture2D = Library.texture(key)
			var dimensions = texture.get_size()
			dimensions *= icon_size / maxf(dimensions.x, dimensions.y)
			draw_texture_rect(texture, Rect2(at + Vector2(48, 26) - dimensions * .5, dimensions), false)
			draw_string(font, at + Vector2(2, 58), key, HORIZONTAL_ALIGNMENT_CENTER, 92, 9, Color("253c3c") if int(index / 14) % 2 == 0 else Color("f0e7d3"))

func _initialize():
	logger = RenderErrors.new()
	OS.add_logger(logger)
	run.call_deferred()

func check(condition: bool, description: String):
	checks += 1
	if not condition:
		failures.append(description)
		print("ICON_VISUAL_FAIL ", description)

func capture(name: String):
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	check(not image.is_empty() and image.get_size() == Vector2i(1920, 1080), "capture dimensions " + name)
	if name.begins_with("gallery-"):
		var rgba = image.duplicate()
		rgba.convert(Image.FORMAT_RGBA8)
		var pixels = rgba.get_data()
		var magenta_pixels = 0
		for offset in range(0, pixels.size(), 4):
			if pixels[offset] >= 166 and pixels[offset + 1] <= 89 and pixels[offset + 2] >= 166 and pixels[offset + 3] > 0:
				magenta_pixels += 1
		check(magenta_pixels == 0, "no bright magenta survives gallery shader " + name)
		var keyed_at=root.get_final_transform()*Vector2(1264,36);var cream_at=root.get_final_transform()*Vector2(1360,36)
		var keyed: Color = image.get_pixel(roundi(keyed_at.x),roundi(keyed_at.y))
		var cream: Color = image.get_pixel(roundi(cream_at.x),roundi(cream_at.y))
		var background = Color("182c30")
		var expected_cream = Color("f1e7d4")
		check(absf(keyed.r - background.r) < .025 and absf(keyed.g - background.g) < .025 and absf(keyed.b - background.b) < .025, "GPU magenta reveals original background " + name)
		check(absf(cream.r - expected_cream.r) < .025 and absf(cream.g - expected_cream.g) < .025 and absf(cream.b - expected_cream.b) < .025, "GPU preserves cream artwork color " + name)
	var path = ProjectSettings.globalize_path("res://../artifacts/icons-" + name + ".png")
	if image.save_png(path) == OK:
		captures.append(name)
		print("ICON_CAPTURE ", path)
	else:
		check(false, "save capture " + name)

func learned_character(game, cls: String) -> Dictionary:
	var sim = game.session.sim
	sim.players.clear()
	var p = sim.add_player(1, "아이콘 검증", {"schema_version": 6, "level": 100, "class_id": cls, "tutorial_done": true})
	p.pos = sim.map.spawn
	p.gold = 24000
	for node in Content.SKILLS[cls]:
		if node.effect == "active" and p.skill_loadout.size() < 6:
			p.skill_ranks[node.id] = 3
			p.skill_loadout[Content.ACTIONS[p.skill_loadout.size()]] = node.id
	sim.recalculate(p)
	game.session.refresh()
	game.camera_pos = Dungeon.iso(p.pos)
	return p

func check_tree(game, cls: String):
	learned_character(game, cls)
	var tree = game.skill_tree
	tree.choice = ""
	tree.search.text = ""
	tree.filter_index = 0
	tree.mode = "skills"
	tree.refresh(true)
	check(tree.nodes.size() == Content.SKILLS[cls].size()+45, "original and specialization controls exist " + cls)
	tree.graph.fit_all()
	check(tree.graph.scope_cluster==-1,"manual overview exposes icons across all branches "+cls)
	for node in Build.nodes_for(cls):
		var control = tree.nodes.get(node.id)
		check(control != null and control.icon == IconArt.skill(node), "UI uses semantic skill icon " + str(node.id))
		check(control.material==GatArt.material(),"graph icon uses production chroma material "+str(node.id))
	check(tree.selected_icon.texture != null, "selected skill detail has icon " + cls)
	game.queue_redraw()

func capture_battle_states(game):
	# Reuse stagger_ui_v03's real raid/state shapes, then freeze simulation time
	# while exercising the production world, HUD and minimap draw paths.
	var p = learned_character(game, "warrior")
	p.highest_floor = 100
	p.cleared_floor = 99
	check(game.session.enter_floor(100), "enter real raid for status and minimap capture")
	var sim = game.session.sim
	p = sim.players[1]
	var bosses = sim.enemies.values().filter(func(enemy): return enemy.get("guardian", false) and enemy.get("boss", false))
	check(not bosses.is_empty(), "raid has a real guardian boss")
	if bosses.is_empty():
		return
	var boss = bosses[0]
	p.pos = boss.pos - Vector2(1.7, 0)
	p.aim = Vector2.RIGHT
	p.hp = roundi(p.max_hp * .65)
	p.enemy_slow_time = 2.
	p.invulnerable = 1.
	p.barrier_time = 4.
	sim.combat.jobs.buff(p, "haste", .2, 4.)
	sim.combat.jobs.buff(p, "attack", .2, 4.)
	sim.combat.jobs.buff(p, "regen", .02, 4.)
	for status in ["bleed", "weaken", "break_armor"]:
		sim.combat.jobs.status(p, boss, status, 8.)
	boss.slow_time = 2.
	boss.hp = roundi(boss.max_hp * .39)
	boss.phase = 2
	Stagger.initialize(boss, sim.clock)
	Stagger.check_threshold(sim, boss)
	check(boss.stagger.state == "check", "real raid threshold starts stagger check")
	boss.stagger.check_value = boss.stagger.check_max * .7
	boss.stagger.time_left = 8.3
	check(StatusMarkers.keys_for(p, true).size() > 5, "hero status row exercises overflow count")
	check(StatusMarkers.keys_for(boss, false).size() >= 4, "boss has several live status markers")
	game.camera_pos = Dungeon.iso(p.pos)
	game.battle_anchor_y = 590.
	game.forest.update_camera(0.)
	for stage in ["check", "down-empty"]:
		if stage == "down-empty":
			Stagger.break_boss(sim, boss)
			# A basic warrior with no learned skills naturally has locked F/V/C
			# default skills and empty Q/Z/X slots; no invalid binding is needed.
			p.skill_ranks.clear()
			p.skill_loadout.clear()
		game.session.refresh()
		game.hud.refresh()
		game.hud.boss_hud._process(0.)
		check(game.hud.boss_hud.visible and game.hud.boss_hud.boss.phase == 2, "enraged boss HUD visible " + stage)
		check(game.hud.boss_hud.boss.stagger.state == ("check" if stage == "check" else "down"), "boss HUD reads real stagger state " + stage)
		check(game.map_overlay.is_visible_in_tree() and not game.bag.visible and not game.skill_tree.visible and not game.town_panel.visible and not game.codex.visible, "battle minimap draw path is visible " + stage)
		check(sim.enemies.values().any(func(enemy): return enemy.get("guardian", false) and enemy.hp > 0), "minimap reads a sealed dungeon exit " + stage)
		if stage == "down-empty":
			check("stun" in StatusMarkers.keys_for(boss, false), "down state draws boss stun marker")
			for action in ["skill_f", "skill_v", "skill_c"]:
				check(game.hud.circles[action].picture == Library.texture("skill_locked"), "unlearned default uses locked HUD icon " + action)
			for action in ["skill_q", "skill_z", "skill_x"]:
				check(game.hud.circles[action].picture == Library.texture("skill_empty"), "unassigned slot uses empty HUD icon " + action)
		var before = JSON.stringify(boss.stagger)
		game.queue_redraw()
		game.map_overlay.queue_redraw()
		await capture("battle-" + stage)
		check(before == JSON.stringify(boss.stagger), "icon rendering preserves boss state " + stage)

func run():
	root.borderless = true
	root.size = Vector2i(1920, 1080)
	Content.initialize_jobs()
	check(DisplayServer.get_name() != "headless", "visual test requires real rendering")
	if not failures.is_empty():
		finish()
		return
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts")) == OK, "create screenshot directory")
	var gallery = Gallery.new()
	gallery.catalog = Library.keys()
	root.add_child(gallery)
	for size in [24, 32, 48]:
		gallery.icon_size = size
		gallery.queue_redraw()
		await capture("gallery-" + str(size))
	gallery.queue_free()
	await process_frame
	var game = load("res://main.tscn").instantiate()
	game.options.mute = true
	game.options["save-dir"] = ProjectSettings.globalize_path("res://../runtime/icon-visual-saves/" + str(Time.get_ticks_usec()))
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	await process_frame
	game.join_game()
	game.session.sim.players[1].tutorial_done = true
	check(game.session.travel("town"), "enter town through session")
	game.toggle_skills()
	for cls in Content.SKILLS:
		check_tree(game, cls)
		# Render every class, even those without a dedicated screenshot.
		await process_frame
		await RenderingServer.frame_post_draw
	for cls in ["mage", "gambler", "summoner"]:
		check_tree(game, cls)
		await capture("skills-" + cls)
	game.skill_tree.mode = "stats"
	game.skill_tree.refresh(true)
	await capture("stats")
	game.skill_tree.mode = "skills"
	game.toggle_skills()
	game.session.refresh()
	game.hud.refresh()
	for action in Content.ACTIONS:
		check(game.hud.circles[action].picture != null, "HUD skill slot has icon " + action)
	await capture("hud")
	game.toggle_bag()
	await capture("inventory")
	game.toggle_bag()
	game.town_panel.open("portal")
	await capture("portal")
	game.town_panel.close()
	game.toggle_codex("equipment")
	await capture("codex")
	game.codex.close()
	await capture_battle_states(game)
	game.stop_audio()
	await create_timer(.5).timeout
	game.session.disconnect_game()
	game.queue_free()
	game = null
	await process_frame
	await process_frame
	check(captures.size() == 13, "all three gallery sizes and ten UI/battle captures saved")
	finish()

func finish():
	var runtime_errors = logger.snapshot()
	check(runtime_errors.is_empty(), "no missing resources or draw errors")
	for message in runtime_errors:
		print("ICON_RENDER_ERROR ", message)
	OS.remove_logger(logger)
	print("ICON_VISUAL_TESTS checks=", checks, " failures=", failures.size(), " captures=", captures.size(), " render_errors=", runtime_errors.size())
	quit(0 if failures.is_empty() else 1)
