extends SceneTree
## Actual item gallery, inventory details and dropped equipment; original actors.
const C = preload("res://scripts/content.gd")
const E = preload("res://scripts/equipment_catalog.gd")
const Art = preload("res://scripts/equipment_art.gd")
const Gat = preload("res://scripts/gat_art.gd")
const DB = preload("res://scripts/game_database.gd")
const Inventory = preload("res://scripts/inventory_model.gd")
const Dungeon = preload("res://scripts/dungeon.gd")
var checks = 0
var failures: Array[String] = []
var captures: Array[String] = []
var logger: RenderErrors

class RenderErrors extends Logger:
	var errors: Array[String] = []
	var mutex = Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock(); errors.append("%s:%d %s: %s %s" % [file, line, function, code, rationale]); mutex.unlock()
	func snapshot() -> Array[String]:
		mutex.lock(); var result: Array[String] = errors.duplicate(); mutex.unlock(); return result

class Gallery extends Node2D:
	var items: Array = []
	var drawn = 0
	var font: Font = ThemeDB.fallback_font
	func _ready(): material = Gat.material()
	func _draw():
		drawn = 0
		draw_rect(Rect2(-80, 0, 1600, 900), Color("203c3d"))
		draw_string(font, Vector2(24, 37), "EQUIPMENT SPRITES  /  60 WEAPONS + 50 ARMOR + 5 ACCESSORIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("fff0cb"))
		for index in range(items.size()):
			var item: Dictionary = items[index]
			var at = Vector2(25 + index % 12 * 116, 75 + int(index / 12) * 80)
			draw_rect(Rect2(at, Vector2(110, 75)), Color("e6dcc7") if int(index / 12) % 2 == 0 else Color("476064"))
			var texture: Texture2D = Art.texture(item)
			var dimensions = texture.get_size(); dimensions *= 53. / maxf(dimensions.x, dimensions.y)
			draw_texture_rect(texture, Rect2(at + Vector2(55, 29) - dimensions * .5, dimensions), false)
			draw_string(font, at + Vector2(3, 69), Art.key(item), HORIZONTAL_ALIGNMENT_CENTER, 104, 8, Color("293f3c") if int(index / 12) % 2 == 0 else Color("fff0cb"))
			drawn += 1

func _initialize():
	logger = RenderErrors.new(); OS.add_logger(logger); run.call_deferred()
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message); print("EQUIPMENT_ART_VISUAL_FAIL ", message)
func capture(name: String):
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	check(not image.is_empty() and image.get_size() == Vector2i(1920, 1080), "Full HD capture dimensions " + name)
	var path = ProjectSettings.globalize_path("res://../artifacts/equipment-" + name + ".png")
	check(image.save_png(path) == OK, "save actual render " + name)
	captures.append(name)
	print("EQUIPMENT_ART_CAPTURE ", path)
func refresh_scene(game):
	game.session.refresh(); game.hud.refresh()
	game.forest.update_camera(0.); game.queue_redraw(); game.map_overlay.queue_redraw()

func actual_screens(game):
	var local = game.session
	local.sim.players[1].tutorial_done = true
	check(local.travel("town"), "prepare equipment in real town")
	var p = local.sim.players[1]
	p.level = 100
	var costume = p.costume; var avatar = p.avatar
	refresh_scene(game)
	var portrait = game.hud.portrait
	for slot in C.SLOTS:
		var item = E.make("sword" if slot == "weapon" else slot, 8, 3, "visual-" + slot, "focus", "warrior")
		check(Inventory.add_gear(p, item) and Inventory.equip(p, item.id), "equip real showcase item " + slot)
	local.sim.recalculate(p)
	refresh_scene(game)
	check(p.costume == costume and p.avatar == avatar and game.hud.portrait == portrait, "item artwork preserves existing actor and HUD portrait")
	game.toggle_bag(); game.bag.select_item("visual-weapon")
	check(game.bag.detail_icon.texture == Art.texture(Inventory.find_item(p, "visual-weapon")), "bag detail uses new equipment sprite")
	for slot in C.SLOTS:
		check(game.bag.equipment_controls[slot].picture == Art.texture(Inventory.find_item(p, p.equipment[slot])), "equipped slot uses new item sprite " + slot)
	await capture("bag")
	game.toggle_bag()
	check(local.travel("forest"), "enter real field with existing character")
	p = local.sim.players[1]; var sim = local.sim
	sim.enemies.clear()
	p.pos = Vector2(sim.map.rooms[1]); p.aim = Vector2.RIGHT
	game.camera_pos = Dungeon.iso(p.pos)
	for index in range(5):
		var slot = ["sword", "head", "hands", "feet", "accessory"][index]
		var item = E.make(slot, index * 2, index, "showcase-drop-" + str(index), "focus", "warrior")
		# Keep all five silhouettes clear of the hero: 72px above and 106..336px left.
		sim.drops[item.id] = {"item": item, "pos": p.pos + Vector2(-5. + index * .6, 2. - index * .6), "owner": 1, "expires": sim.clock + 90.}
	refresh_scene(game)
	check(local.state.drops.size() == 5, "five real equipment drops reach world renderer")
	check(p.costume == costume and p.avatar == avatar and game.hud.portrait == portrait, "field retains original character choice")
	await capture("drops")

func run():
	root.borderless = true
	root.size = Vector2i(1920, 1080)
	root.gui_disable_input = true
	C.initialize_jobs()
	check(DisplayServer.get_name() != "headless", "equipment captures use real renderer")
	if not failures.is_empty(): finish(); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts"))
	var unique: Dictionary = {}
	for item in DB.snapshot().equipment:
		if not unique.has(Art.key(item)): unique[Art.key(item)] = item
	var gallery = Gallery.new(); gallery.position=Vector2(80,0); gallery.items = unique.values(); root.add_child(gallery)
	await capture("items-gallery")
	check(gallery.drawn == 115, "all item sprites actually drawn")
	gallery.queue_free(); await process_frame
	var game = load("res://main.tscn").instantiate()
	game.options.mute = true
	game.options["save-dir"] = ProjectSettings.globalize_path("res://../runtime/equipment-art-visual/" + str(Time.get_ticks_usec()))
	root.add_child(game); game.process_mode = Node.PROCESS_MODE_DISABLED
	game.set_process_input(false); game.set_process_unhandled_input(false); game.set_process_unhandled_key_input(false)
	await process_frame
	game.join_game()
	await actual_screens(game)
	check(await game.audio_director.shutdown(), "audio players drain before scene cleanup")
	game.session.disconnect_game(); game.queue_free(); game = null
	await process_frame; await process_frame
	check(captures.size() == 3, "item gallery, actual inventory and actual ground drops")
	finish()
func finish():
	var errors = logger.snapshot()
	check(errors.is_empty(), "no missing resources or draw errors")
	for error in errors: print("EQUIPMENT_ART_RENDER_ERROR ", error)
	OS.remove_logger(logger)
	print("EQUIPMENT_ART_VISUAL checks=", checks, " failures=", failures.size(), " captures=", captures.size(), " render_errors=", errors.size())
	quit(0 if failures.is_empty() else 1)
