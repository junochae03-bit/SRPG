extends Node2D

const Dungeon = preload("res://scripts/dungeon.gd")
const LocalSession = preload("res://scripts/local_session.gd")
const ForestEnvironment = preload("res://scripts/forest_environment.gd")
const Content=preload("res://scripts/content.gd")
const GatArt=preload("res://scripts/gat_art.gd")
const SemanticIcons=preload("res://scripts/icon_library.gd")
const EquipmentArt=preload("res://scripts/equipment_art.gd")
const GOLD = Color("237c70")
const PALE = Color("29494c")
const MUTED = Color("617b78")
var session
var keybindings=preload("res://scripts/key_bindings.gd").new()
var keybindings_path=""
var dungeon
var forest
var fonts
var bold_font: Font
var serif: Font
var textures: Dictionary = {}
var camera_pos = Vector2.ZERO
var smooth_positions: Dictionary = {}
var art_usage={"costume":{"id":"","draws":0,"frame_indices":[],"source_sheets":[],"fallback":false},"environment":{"theme":"","drawn_ids":[]},"monsters":{"drawn_ids":[],"fallback_kinds":[]}}
var visual_time = 0.0
var effects: Array = []
var menu: Control
var title_backdrop:TextureRect
var hud: Control
var bag: Control
var help_panel: Control
var skill_tree: Control
var town_panel:Control
var codex:Control
var character_sheet:Control
var npc_dialogue:Control
var start_button:Button
var slot_summary:Label
var menu_status: Label
var name_input: LineEdit
var slot_picker: OptionButton
var hud_stats: Label
var quest_label: Label
var connection_label: Label
var toast: Label
var toast_time = 0.0
var health_label: Label
var action_buttons: Dictionary = {}
var action_badges: Dictionary = {}
var options: Dictionary = {}
var scenery: Dictionary = {}
var region_label: Label
var bag_signature = ""
var input_timer = 0.0
var capture_done = false
var bot_elapsed = 0.0
var bot_route: Array = []
var bot_route_index = 0
var bot_max_peers = 0
var bot_initial_xp = -1
var bot_kills = 0
var bot_distance = 0.0
var bot_last_pos = Vector2.ZERO
var map_overlay: Node2D
var status_text = ""
var quitting = false
var audio_director
var building_alphas:Dictionary={}
var battle_anchor_y=438.0
var world_zoom=1.0

func stop_audio():
	if is_instance_valid(audio_director):audio_director.stop_all()

func finish_run():
	if quitting: return
	quitting=true
	if options.has("report"): write_bot_report()
	if session.connected:
		session.paused=true
		session.save_game()
	if is_instance_valid(audio_director) and not await audio_director.shutdown():
		push_error("Audio playback did not drain before shutdown")
		get_tree().quit(1)
		return
	get_tree().quit()

func _notification(what: int):
	if what==NOTIFICATION_WM_CLOSE_REQUEST and session!=null: finish_run()
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and session!=null and session.connected:session.sim.combat.act(session.sim.players[session.local_id],"cancel_charge")

func _ready():
	get_tree().auto_accept_quit=false
	for argument in OS.get_cmdline_user_args():
		var pair = argument.trim_prefix("--").split("=", true, 1)
		options[pair[0]] = pair[1] if pair.size() > 1 else "true"
	if options.has("capture") and DisplayServer.get_name() != "headless":
		# Automated framebuffer captures need a full client area even when the
		# desktop cannot fit a 1080p window plus its native title bar.
		get_window().borderless = true
		get_window().size = Vector2i(1920, 1080)
	session = LocalSession.new()
	if options.has("save-dir"): session.save_directory = options["save-dir"]
	keybindings_path=session.save_directory.path_join("keybindings.json")
	keybindings.load_file(keybindings_path)
	preload("res://scripts/sprite_names.gd").configure(session.save_directory.path_join("sprite-names.json"))
	add_child(session)
	dungeon = Dungeon.new()
	camera_pos = Dungeon.iso(dungeon.spawn)
	load_art()
	material=GatArt.material()
	forest=ForestEnvironment.new(self)
	forest.rebuild(dungeon)
	audio_director=preload("res://scripts/audio_director.gd").new()
	add_child(audio_director)
	audio_director.setup(self)
	build_interface()
	var overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 2
	overlay_layer.offset=ui_offset()
	add_child(overlay_layer)
	map_overlay = Node2D.new()
	map_overlay.set_script(preload("res://scripts/minimap.gd"))
	map_overlay.game = self
	overlay_layer.add_child(map_overlay)
	session.status_changed.connect(on_status)
	session.changed.connect(update_hud)
	session.event_received.connect(on_event)
	session.entered.connect(on_entered)
	session.facility_requested.connect(func(key):npc_dialogue.open(key))
	if options.has("name"): name_input.text=options.name
	slot_picker.select(clampi(int(options.get("slot","1"))-1,0,2))
	refresh_slot_summary()
	if options.has("bot"):join_game()
	elif options.has("play") or options.has("show-creation"):begin_adventure()

func begin_adventure():
	var state=session.slot_state(slot_picker.selected+1)
	if state=="empty":
		menu.hide();character_sheet.open(slot_picker.selected+1)
	elif state=="saved":join_game()
	else:menu_status.text="이 모험 기록을 읽을 수 없습니다. 다른 슬롯을 선택해 주세요. 기존 파일은 보존됩니다."

func refresh_slot_summary():
	if slot_summary==null:return
	var state=session.slot_state(slot_picker.selected+1)
	start_button.text="모험 시작" if state=="empty" else "이어서 하기"
	slot_summary.text="읽을 수 없는 기록" if state=="damaged" else ""
	start_button.disabled=state=="damaged"
	menu.refresh_records()

func join_game():
	session.start_game(name_input.text, slot_picker.selected+1)
	if options.has("bot"):session.travel("forest")
	elif options.has("floor"):session.enter_floor(int(options.floor))

func toggle_help():
	if help_panel.visible:
		help_panel.close();return
	if session.connected:session.sim.combat.act(session.sim.players[session.local_id],"cancel_charge")
	help_panel.open()
	if toast!=null:toast.hide()

func continue_game():
	help_panel.close()

func on_keybindings_changed():
	if hud.has_method("refresh_key_labels"):hud.refresh_key_labels()
	if skill_tree.has_method("refresh_key_labels"):skill_tree.refresh_key_labels()
	update_hud()

func text_input_focused()->bool:
	var focus=get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func key_escape(event:InputEvent)->bool:
	return event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_ESCAPE or event.keycode==KEY_ESCAPE)

func load_art():
	serif = load("res://assets/fonts/dnf_forged_blade_medium.ttf")
	bold_font = load("res://assets/fonts/dnf_bitbit_v2.ttf")
	scenery.forest_background=load("res://assets/koongya/forest_background.png")
	fonts = load("res://assets/fonts/dnf_forged_blade_medium.ttf")
	fonts.fallbacks = [bold_font]
	var art = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations.json"))
	var costume_art=JSON.parse_string(FileAccess.get_file_as_string("res://assets/costumes/animations.json"))
	art.merge(costume_art)
	for role in art:
		textures[role] = {}
		for state_name in art[role]:
			textures[role][state_name] = []
			for path in art[role][state_name]: textures[role][state_name].append(load(path))

func style(bg: Color, _border: Color = Color("b4c9b7"), _radius: int = 3) -> StyleBoxTexture:
	var box = StyleBoxTexture.new()
	box.texture=preload("res://scripts/ui_art.gd").texture("paper")
	box.texture_margin_left=30;box.texture_margin_right=30;box.texture_margin_top=30;box.texture_margin_bottom=30
	box.modulate_color=Color(1,1,1,bg.a)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func label(parent: Node, text_value: String, pos: Vector2, size_value: Vector2, font_size: int = 18, color: Color = PALE) -> Label:
	var control = Label.new()
	control.text = text_value
	control.position = pos
	control.size = size_value
	control.add_theme_font_override("font", fonts)
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", color)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control

func panel(parent: Node, pos: Vector2, dimensions: Vector2, _background: Color = Color("fff9eaf2")) -> Panel:
	var control = Panel.new()
	control.position = pos
	control.size = dimensions
	control.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	preload("res://scripts/ui_art.gd").decorate(control,"paper",18)
	return control

func button(parent: Node, text_value: String, pos: Vector2, dimensions: Vector2, callback: Callable, accent: bool = false, icon_key:String = "") -> Button:
	var control = Button.new()
	control.text = text_value
	control.position = pos
	control.custom_minimum_size = dimensions
	control.size = dimensions
	control.add_theme_font_override("font", bold_font)
	control.add_theme_font_size_override("font_size", 18)
	control.add_theme_color_override("font_color", PALE)
	control.add_theme_color_override("font_hover_color", PALE)
	control.add_theme_color_override("font_pressed_color", PALE)
	control.add_theme_color_override("font_focus_color", PALE)
	control.add_theme_color_override("font_disabled_color", Color("728073"))
	for state in ["normal","hover","pressed","disabled","focus"]:control.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	control.pressed.connect(callback)
	parent.add_child(control)
	var frame=preload("res://scripts/ui_art.gd").decorate(control,"paper",12)
	control.set_meta("rpg_frame",frame)
	if accent:frame.modulate=Color(1.05,.98,.80)
	control.mouse_entered.connect(func():frame.modulate=Color(1.12,1.06,.9))
	control.mouse_exited.connect(func():frame.modulate=Color(1.05,.98,.80) if accent else Color.WHITE)
	if not icon_key.is_empty():SemanticIcons.attach(control,icon_key)
	return control

func line_edit(parent: Node, text_value: String, pos: Vector2, dimensions: Vector2) -> LineEdit:
	var control = LineEdit.new()
	control.text = text_value
	control.position = pos
	control.size = dimensions
	control.add_theme_font_override("font", fonts)
	control.add_theme_font_size_override("font_size", 19)
	control.add_theme_color_override("font_color", PALE)
	control.add_theme_color_override("caret_color", GOLD)
	control.add_theme_color_override("font_placeholder_color", MUTED)
	control.add_theme_color_override("font_selected_color", Color.WHITE)
	control.add_theme_color_override("selection_color", GOLD)
	var field_style=StyleBoxEmpty.new();field_style.content_margin_left=12;field_style.content_margin_right=12;field_style.content_margin_top=8;field_style.content_margin_bottom=8
	control.add_theme_stylebox_override("normal",field_style);control.add_theme_stylebox_override("focus",field_style)
	parent.add_child(control)
	preload("res://scripts/ui_art.gd").decorate(control,"paper",12)
	return control

func build_interface():
	var canvas = CanvasLayer.new()
	canvas.offset=ui_offset()
	add_child(canvas)
	menu=preload("res://scripts/title_screen.gd").new()
	canvas.add_child(menu)
	menu.setup(self)
	hud=preload("res://scripts/combat_hud.gd").new()
	canvas.add_child(hud)
	hud.setup(self)
	hud.hide()
	bag=preload("res://scripts/inventory_panel.gd").new()
	hud.add_child(bag)
	bag.setup(self)
	skill_tree=preload("res://scripts/skill_tree_ui.gd").new()
	hud.add_child(skill_tree)
	skill_tree.setup(self)
	town_panel=preload("res://scripts/town_panel.gd").new();hud.add_child(town_panel);town_panel.setup(self)
	codex=preload("res://scripts/codex_panel.gd").new();hud.add_child(codex);codex.setup(self)
	npc_dialogue=preload("res://scripts/npc_dialogue.gd").new();hud.add_child(npc_dialogue);npc_dialogue.setup(self)
	character_sheet=preload("res://scripts/character_sheet_ui.gd").new();canvas.add_child(character_sheet);character_sheet.setup(self)
	help_panel=preload("res://scripts/keyboard_panel.gd").new();canvas.add_child(help_panel);help_panel.setup(self)

func on_status(message: String):
	status_text = message
	menu_status.text = ""
	if not session.connected:
		world_zoom=1.0;battle_anchor_y=438.0;get_viewport().canvas_transform=Transform2D.IDENTITY
		menu.show()
		title_backdrop.show()
		if character_sheet!=null:character_sheet.hide()
		hud.hide()
		bag.hide()
		refresh_slot_summary()

func on_entered():
	art_usage={"costume":{"id":"","draws":0,"frame_indices":[],"source_sheets":[],"fallback":false},"environment":{"theme":"","drawn_ids":[]},"monsters":{"drawn_ids":[],"fallback_kinds":[]}}
	bag.hide();skill_tree.hide();help_panel.hide();town_panel.hide();codex.hide();npc_dialogue.hide();character_sheet.hide()
	dungeon = session.sim.map
	forest.rebuild(dungeon)
	camera_pos = Dungeon.iso(dungeon.spawn)
	if session.state.players.has(session.local_id):update_battle_camera(session.state.players[session.local_id],1.0,true)
	smooth_positions.clear()
	menu.hide()
	title_backdrop.hide()
	hud.show()
	name_input.release_focus()
	slot_picker.release_focus()
	bag_signature=""
	update_hud()
	show_toast("햇살 마을" if dungeon.zone=="town" else (preload("res://scripts/abyss_catalog.gd").config(dungeon.floor_number).name if dungeon.floor_number>0 else "꽃바람 숲"))
	bot_route = make_route(dungeon.spawn, Vector2(dungeon.rooms[1])) if dungeon.rooms.size()>1 else []
	bot_last_pos = dungeon.spawn

func show_toast(message: String):
	toast.text = message
	toast_time = 5.0

func on_event(event: Dictionary):
	if event.type == "notice":
		show_toast(event.text)
	else:
		event["life"] = event.get("duration",0.7 if event.type == "damage" else 0.35)
		event["max_life"]=event.life
		effects.append(event)

func toggle_bag():
	npc_dialogue.hide()
	codex.hide()
	town_panel.hide()
	audio_director.play_sound("inventory",-5)
	session.sim.combat.act(session.sim.players[session.local_id],"cancel_charge")
	skill_tree.hide()
	bag.visible = not bag.visible
	session.paused=bag.visible or help_panel.visible or skill_tree.visible
	toast.visible=not session.paused
	update_hud()

func toggle_skills():
	npc_dialogue.hide()
	codex.hide()
	town_panel.hide()
	audio_director.play_sound("inventory",-5)
	session.sim.combat.act(session.sim.players[session.local_id],"cancel_charge")
	bag.hide()
	skill_tree.visible=not skill_tree.visible
	session.paused=skill_tree.visible or help_panel.visible
	skill_tree.refresh(true)

func toggle_codex(tab:String=""):
	npc_dialogue.hide()
	if codex.visible and tab.is_empty():
		codex.close()
		return
	session.sim.combat.act(session.sim.players[session.local_id],"cancel_charge")
	bag.hide();skill_tree.hide();help_panel.hide();town_panel.hide()
	audio_director.play_sound("inventory",-5)
	codex.open(tab)
	session.paused=true
	toast.hide()

func update_hud():
	if not session.state.players.has(session.local_id):return
	hud.refresh()
	if bag.visible:bag.refresh()

func rarity_color(rarity: int) -> Color:
	return preload("res://scripts/equipment_catalog.gd").COLORS[clampi(rarity,0,4)]

func _unhandled_input(event: InputEvent):
	if character_sheet.visible:
		if key_escape(event):character_sheet.cancel();get_viewport().set_input_as_handled()
		return
	if help_panel.visible:return
	if key_escape(event):
		if npc_dialogue.visible:npc_dialogue.close()
		elif codex.visible:codex.close()
		elif town_panel.visible:town_panel.close()
		elif bag.visible:toggle_bag()
		elif skill_tree.visible:toggle_skills()
		else:toggle_help()
		get_viewport().set_input_as_handled();return
	if not session.connected: return
	if npc_dialogue.visible or text_input_focused():return
	# Modal controls submit their own actions; combat hotkeys must not consume
	# items or act through a paused inventory, growth, service or settings panel.
	var action=keybindings.action_for_event(event)
	if session.paused and action not in ["bag","skills","codex"]:return
	match action:
		"bag":toggle_bag()
		"skills":toggle_skills()
		"codex":toggle_codex()
		"dodge","skill_q","skill_f","skill_v","skill_c","skill_z","skill_x","card_next","potion","interact","return":session.act(action)
	if not action.is_empty():get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		session.act("heavy_begin" if event.pressed else "heavy")

func _input(event:InputEvent):
	if character_sheet!=null and character_sheet.visible and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		character_sheet.cancel();get_viewport().set_input_as_handled();return
	if help_panel!=null and not help_panel.visible and key_escape(event):
		_unhandled_input(event);return
	if session==null or not session.connected:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:
		if session.sim.players[session.local_id].charge_time>=0:
			if session.paused or text_input_focused():session.sim.combat.act(session.sim.players[session.local_id],"cancel_charge")
			else:session.act("heavy")
			get_viewport().set_input_as_handled()

func _physics_process(delta: float):
	if session == null: return
	if not session.connected or not session.state.players.has(session.local_id): return
	input_timer += delta
	if options.has("bot"):
		bot_step(delta)
		return
	if input_timer < 0.05: return
	input_timer = 0.0
	var p = session.state.players[session.local_id]
	var direction = Vector2.ZERO
	var can_act=not session.paused and not text_input_focused()
	if can_act:
		direction = Vector2(float(keybindings.is_pressed("move_right"))-float(keybindings.is_pressed("move_left")),float(keybindings.is_pressed("move_down"))-float(keybindings.is_pressed("move_up")))
		# Keyboard axes follow screen directions; convert to logical isometric coordinates.
		direction = Dungeon.from_iso(direction).normalized()
	var logical_mouse = Dungeon.from_iso(get_global_mouse_position() - screen_center() + camera_pos)
	var aim = (logical_mouse - p.pos).normalized()
	session.send_input(direction, aim, can_act and keybindings.is_pressed("sprint"))
	if can_act:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control() == null:
			session.act("attack")

func _process(delta: float):
	if session == null: return
	visual_time += delta
	toast_time -= delta
	if toast_time <= 0: toast.text = ""
	toast.visible = not bag.visible and not help_panel.visible and not skill_tree.visible and not town_panel.visible and not codex.visible and not npc_dialogue.visible
	if session.state.players.has(session.local_id):
		var p=session.state.players[session.local_id]
		update_battle_camera(p,delta)
		if options.has("capture") and options.get("capture-view","")=="encounter" and dungeon.rooms.size()>1:camera_pos=Dungeon.iso(Vector2(dungeon.rooms[1]))
		if options.has("capture") and options.get("capture-view","")=="raid":
			var guardians=session.state.enemies.values().filter(func(e):return e.get("raid",false) and e.hp>0)
			if not guardians.is_empty():
				# Screenshot framing only; the player, boss and combat state stay untouched.
				update_battle_camera({"pos":guardians[0].pos+Vector2(2.2,2.2)},delta,true)
	forest.update_camera(delta)
	if session.connected and dungeon.zone=="town":
		var p=session.state.players[session.local_id];var body=world_point(p.pos)-Vector2(0,55)
		for key in preload("res://scripts/world_catalog.gd").FACILITIES:
			var building=preload("res://scripts/world_catalog.gd").FACILITIES[key]
			var sprite=preload("res://scripts/world_art.gd").frame("town",building.art)
			var dimensions=sprite.texture.get_size()*(building.height/sprite.height)
			var rect=Rect2(world_point(building.pos)-Vector2(dimensions.x*.5,dimensions.y),dimensions).grow(-20)
			var covered=building.pos.x+building.pos.y>p.pos.x+p.pos.y and rect.has_point(body)
			building_alphas[key]=ForestEnvironment.approach_alpha(building_alphas.get(key,1.0),.28 if covered else 1.0,delta)
	for effect in effects: effect.life -= delta
	effects = effects.filter(func(e): return e.life > 0)
	queue_redraw()
	map_overlay.queue_redraw()
	if options.has("capture") and not capture_done and visual_time > float(options.get("capture-at", "4")):
		capture_done = true
		if options.has("show-bag") and not bag.visible: toggle_bag()
		if options.has("show-skills") and not skill_tree.visible:toggle_skills()
		if options.has("show-keys") and not help_panel.visible:toggle_help()
		if options.has("show-codex"):toggle_codex(str(options.get("codex-tab","equipment")))
		if options.has("show-dialogue") and session.connected:npc_dialogue.open(str(options.get("show-dialogue","smith")))
		capture.call_deferred()
	if options.has("duration") and visual_time > float(options.duration):
		finish_run()

func capture():
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var path = str(options.capture)
	var err = img.save_png(path)
	print("CAPTURE ", path, " ", error_string(err))

func screen_center() -> Vector2:
	return Vector2(763, battle_anchor_y) if session.connected else Vector2(1140, 446)

func ui_offset()->Vector2:
	return Vector2(maxf(0,(get_viewport().get_visible_rect().size.x-1440)*.5),0)

func update_battle_camera(player:Dictionary,delta:float,snap:bool=false):
	var frame=preload("res://scripts/battle_camera.gd").framing(player,session.state.enemies.values())
	var blend=1.0 if snap else 1.0-exp(-8.0*delta)
	battle_anchor_y=lerpf(battle_anchor_y,frame.anchor,blend)
	world_zoom=lerpf(world_zoom,frame.zoom,blend)
	if frame.position.distance_to(camera_pos)>700:camera_pos=frame.position
	camera_pos=camera_pos.lerp(frame.position,blend)
	var anchor=screen_center()
	get_viewport().canvas_transform=Transform2D(Vector2(world_zoom,0),Vector2(0,world_zoom),anchor*(1.0-world_zoom))

func world_point(pos: Vector2) -> Vector2:
	return Dungeon.iso(pos) - camera_pos + screen_center()

func diamond(center: Vector2, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([center+Vector2(0,-height),center+Vector2(width,0),center+Vector2(0,height),center+Vector2(-width,0)])

func text_at(point: Vector2, value: String, font_size: int, color: Color, centered: bool = false):
	if centered: point.x -= fonts.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2
	for off in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:
		draw_string(fonts,point+off,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("233b2bd9"))
	draw_string(fonts, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw():
	if session == null or dungeon == null: return
	if not session.connected:
		draw_rect(Rect2(0,0,1600,900),Color("c3dfbc"))
		draw_texture_rect(scenery.forest_background,Rect2(550,0,1200,900),false,Color(1.12,1.10,1.04))
		return
	var actors = forest.visible_props()
	if dungeon.floor_number>0:
		var exit_at=world_point(dungeon.exit_position);var clear=not session.state.enemies.values().any(func(e):return e.get("guardian",false) and e.hp>0)
		SemanticIcons.draw(self,"trophy" if dungeon.floor_number==100 else "stairs" if clear else "locked",Rect2(exit_at-Vector2(38,58),Vector2(76,76)),Color.WHITE if clear else Color(.7,.7,.7,.65))
		text_at(exit_at+Vector2(0,35),"100층 최종 제단" if dungeon.floor_number==100 else "E · 다음 층" if clear else "수문장 봉인",17,Color("f7e3ab"),true)
	if dungeon.zone=="town":
		var index=0
		for visitor in preload("res://scripts/town_visitors.gd").RESIDENTS:actors.append({"type":"visitor","data":visitor})
		for key in preload("res://scripts/world_catalog.gd").FACILITIES:
			var data=preload("res://scripts/world_catalog.gd").FACILITIES[key].duplicate();data["key"]=key;data["render_id"]=index;actors.append({"type":"building","data":data});index+=1
			if preload("res://scripts/world_catalog.gd").RESIDENTS.has(key):
				actors.append({"type":"resident","data":{"key":key,"pos":preload("res://scripts/world_catalog.gd").resident_pos(key),"render_id":index}})
	if session.connected:
		for p in session.state.players.values(): actors.append({"type":"hero","data":p})
		for e in session.state.enemies.values():
			if e.hp > 0: actors.append({"type":e.kind,"data":e})
		var nearest={};var nearest_distance=1.8
		for drop in session.state.drops.values():
			var distance=session.state.players[session.local_id].pos.distance_to(drop.pos)
			if distance<nearest_distance:nearest_distance=distance;nearest=drop
			var point = world_point(drop.pos)
			var color = rarity_color(drop.item.rarity)
			var picture=preload("res://scripts/content.gd").icon_texture(drop.item)
			var dimensions=picture.get_size();dimensions*=34.0/maxf(dimensions.x,dimensions.y)
			draw_colored_polygon(diamond(point,19,8),Color("284a3b60"))
			if drop.item.rarity>0:draw_line(point,point+Vector2(0,-44),Color(color,0.4),2)
			draw_texture_rect(picture,Rect2(point-Vector2(dimensions.x*0.5,dimensions.y+4),dimensions),false)
		if not nearest.is_empty():
			var point=world_point(nearest.pos)
			var amount=int(nearest.item.get("amount",1))
			text_at(point+Vector2(0,-49),nearest.item.name+(" ×"+str(amount) if amount>1 else ""),14,Color("ffefb5"),true)
			SemanticIcons.draw(self,"pickup",Rect2(point+Vector2(-41,-1),Vector2(20,20)))
			text_at(point+Vector2(8,17),"E  줍기",12,Color("fff1c3"),true)
	else:
		actors.append({"type":"hero","data":{"id":0,"pos":dungeon.spawn+Vector2(1.2,0.4),"name":"","hp":120,"max_hp":120,"dir":Vector2.ZERO,"swing":0.0}})
	actors.sort_custom(ForestEnvironment.actor_before)
	for area in session.state.get("enemy_attacks",[]):preload("res://scripts/monster_attacks.gd").draw_area(self,area,Color("ed8268"))
	for actor in actors:
		if actor.type=="scenery":forest.draw_prop(actor.data)
		elif actor.type=="building":draw_building(actor.data)
		elif actor.type=="resident":draw_resident(actor.data)
		elif actor.type=="visitor":preload("res://scripts/town_visitors.gd").draw(self,actor.data)
		else:draw_actor(actor)
	for hero in session.state.players.values():preload("res://scripts/job_art.gd").pets(self,hero,visual_time)
	for e in effects:
		var point = world_point(e.pos)
		if e.type == "damage":
			text_at(point+Vector2(0,-85-(0.7-e.life)*65),str(e.amount),23,GOLD if e.enemy else Color("ff776b"),true)
		elif e.type=="monster_attack":
			preload("res://scripts/monster_attacks.gd").draw_area(self,e.area,Color(1,.73,.35,e.life/e.max_life))
		elif e.type in ["nova","skill_fx"]:
			preload("res://scripts/skill_effects.gd").render(self,e)
		elif e.type == "attack" or e.type == "heavy":
			var angle = Dungeon.iso(e.dir).angle()
			if e.get("weapon","") not in ["bow","staff"]:
				draw_arc(point+Vector2(0,-23),103 if e.type=="heavy" else 68,angle-1.2,angle+1.2,22,Color(0.95,0.82,0.58,e.life*2.7),9 if e.type=="heavy" else 5,true)
		elif e.type=="dodge":
			draw_arc(point,28,0,TAU,30,Color(0.5,0.9,1,e.life*2),3,true)
	for shot in session.state.get("projectiles",[]):
		preload("res://scripts/skill_effects.gd").projectile(self,shot)
	if session.connected:
		pass
	else:
		draw_rect(Rect2(0,0,690,900),Color("fff9e440"))
	# Sparse embers keep the environment alive without obscuring combat.
	for i in range(25):
		var x = fposmod(i*197.0 + sin(visual_time*0.21+i)*25,1600)
		var y = fposmod(i*97.0 - visual_time*(9+i%7),900)
		draw_circle(Vector2(x,y),1.2,Color(1.0,0.98,0.75,0.5+0.15*sin(i+visual_time)))

func draw_actor(actor: Dictionary):
	var p = actor.data
	var role = actor.type
	var key = role+str(p.id)
	var target = world_point(p.pos)
	if target.x < -180 or target.x > 1620 or target.y < -160 or target.y > 1100: return
	var point = target
	if smooth_positions.has(key) and smooth_positions[key].distance_to(target) < 180:
		point = smooth_positions[key].lerp(target,0.45)
	smooth_positions[key] = point
	var is_hero = role == "hero"
	var boss=not is_hero and p.get("boss",role=="warden")
	var is_self = is_hero and p.id == session.local_id
	var size_scale = 2.2 if is_hero else (3.7 if role=="warden" else 2.0)
	if not is_hero and p.windup > 0 and boss and not p.get("raid",false):
		var telegraph = world_point(p.attack_pos)
		var config=preload("res://scripts/world_catalog.gd").ENEMIES[role]
		var radius=48.0*(.9 if config.ai in ["ranged","healer"] else config.range)
		draw_colored_polygon(diamond(telegraph,radius,radius/2),Color(0.85,0.16,0.12,0.25))
		var border = diamond(telegraph,radius,radius/2)
		draw_polyline(PackedVector2Array([border[0],border[1],border[2],border[3],border[0]]),Color("ea7559"),2)
	if not is_hero and (not boss or p.get("raid",false)) and p.windup>0:
		for area in p.get("attack_areas",[]):preload("res://scripts/monster_attacks.gd").draw_area(self,area,Color("ed8268"))
	draw_set_transform(point,0,Vector2(1,0.42))
	draw_circle(Vector2.ZERO,66 if boss else 37 if p.get("elite",false) else 24,Color("32574a40"))
	if is_self: draw_arc(Vector2.ZERO,30,0,TAU,40,GOLD,2,true)
	draw_set_transform(Vector2.ZERO)
	var animation = "idle"
	if not is_hero or p.get("dir", Vector2.ZERO).length()>0.1: animation="move"
	if is_hero and (p.get("swing",0.0)>0 or p.get("motion_time",0.0)>0): animation="attack"
	var fallback=textures.get(role,textures.hero)
	if not fallback.has(animation): animation="move"
	var base_actor=is_hero and Content.gat_appearance(p)
	var rendered_costume={};var rendered_monster=""
	var art_role=Content.costume_role(p) if is_hero and not base_actor else role
	var frames = textures.get(art_role,fallback)[animation]
	var pose=preload("res://scripts/character_motion.gd").pose(p) if is_hero else {"offset":Vector2.ZERO,"angle":0.0,"scale":Vector2.ONE,"weapon":0.0,"hand":Vector2(16,-30),"progress":0.0}
	var frame_index=mini(frames.size()-1,int(pose.progress*frames.size())) if is_hero and p.get("motion_time",0)>0 else int(visual_time*8)%frames.size()
	var frame: Texture2D = frames[frame_index]
	var foot=Vector2(frame.get_width()/2.0,frame.get_height())
	var facing=1.0
	if is_hero and not base_actor:
		# One fixed body metric per costume, shared by every animation frame.
		var rest:Texture2D=textures[art_role].idle[0]
		size_scale=112.0/rest.get_height()
	if base_actor:
		var data=GatArt.frame(p,visual_time);frame=data.texture;size_scale=112.0/data.height;foot=data.foot
		if data.has("costume_id"):rendered_costume=data
		facing=-1.0 if Dungeon.iso(p.get("aim",Vector2.RIGHT)).x<0 else 1.0
		if data.get("animated",false):pose.scale=Vector2.ONE;pose.angle*=.35
		elif p.get("dir",Vector2.ZERO).length()>.1 and p.get("motion_time",0)<=0:pose.offset.y=-absf(sin(visual_time*11))*3
	if not is_hero:
		var config=preload("res://scripts/world_catalog.gd").ENEMIES[role]
		var data:Dictionary
		var themed=preload("res://scripts/world_art.gd").variant_frame(role,int(p.get("floor",0)),p.get("raid",false),p.get("attack_motion",0)>0 or p.windup>0)
		if not themed.is_empty():
			data=themed
			rendered_monster=themed.art_id
			size_scale=(335.0 if boss else preload("res://scripts/world_catalog.gd").display_height(role))/data.height
			if boss and p.get("stagger",{}).get("state","")=="down":pose.scale=Vector2(1.04,.84);pose.angle=.10
		elif boss:
			var boss_index=["warden","golem","sentinel"].find(role)
			var index=1 if p.windup>0 else 2 if p.get("attack_motion",0)>0 else 0
			data=preload("res://scripts/world_art.gd").frame("bosses",boss_index*3+index)
			var standing=preload("res://scripts/world_art.gd").frame("bosses",boss_index*3)
			size_scale=335.0/standing.height
			if p.get("stagger",{}).get("state","")=="down":pose.scale=Vector2(1.04,.84);pose.angle=.10
		else:
			data=preload("res://scripts/world_art.gd").frame(config.get("art_sheet","enemies"),config.art)
			size_scale=preload("res://scripts/world_catalog.gd").display_height(role)/data.height;pose.offset.y=-absf(sin(visual_time*4+p.id))*3
		frame=data.texture;foot=data.foot
		if not boss:
			var recoil=sin(clampf(p.get("attack_motion",0)/.35,0,1)*PI)
			var direction=Dungeon.iso(p.attack_pos-p.pos).normalized()
			pose.offset+=direction*recoil*(-8 if config.ai in ["ranged","healer"] else 10)
			pose.angle=recoil*.10*signf(direction.x)
			if role in ["shade","ember_slime","frost_slime"]:pose.scale=Vector2(1+recoil*.12,1-recoil*.12)
	var dimensions = frame.get_size()*size_scale
	var rect = Rect2(-foot*size_scale,dimensions)
	var tint = Color.WHITE
	if not is_hero and p.get("slow_time",0)>0:tint=Color("97d9ff")
	if is_hero and p.get("invulnerable",0)>0:tint=Color(0.6,0.9,1,0.6)
	draw_set_transform(point+pose.offset,pose.angle,pose.scale*Vector2(facing,1))
	draw_texture_rect(frame,rect,false,tint)
	draw_set_transform(Vector2.ZERO)
	if is_self and not rendered_costume.is_empty():record_art_usage("costume",rendered_costume.costume_id,int(rendered_costume.index),str(rendered_costume.get("frame_source_path","")))
	if not is_hero:record_art_usage("monsters" if not rendered_monster.is_empty() else "monster_fallback",rendered_monster if not rendered_monster.is_empty() else role)
	if not is_hero and (p.get("stun_time",0)>0 or p.get("stagger",{}).get("state","")=="down"):
		for i in range(3):preload("res://scripts/skill_effects.gd").star(self,point+Vector2(sin(visual_time*5+i*TAU/3)*18,-dimensions.y-26),5,Color("fff3a6"))
	if session.connected:preload("res://scripts/status_markers.gd").draw(self,p,point+Vector2(0,-dimensions.y-54),is_hero)
	if is_hero and session.connected and not base_actor:
		var weapon_type=session.sim.combat.weapon_type(p)
		var weapon_art:Texture2D=preload("res://scripts/item_art.gd").texture(weapon_type)
		var weapon_size=weapon_art.get_size();weapon_size*=43.0/maxf(weapon_size.x,weapon_size.y)
		var aim_angle=Dungeon.iso(p.aim).angle()+PI*0.25
		aim_angle+=pose.weapon
		if p.get("charge_time",-1)>=0:aim_angle-=p.charge_time*1.1
		draw_set_transform(point+pose.offset+pose.hand,aim_angle)
		draw_texture_rect(weapon_art,Rect2(Vector2(-weapon_size.x*0.23,-weapon_size.y*0.80),weapon_size),false,tint)
		draw_set_transform(Vector2.ZERO)
	if session.connected:
		if not is_hero and not boss:
			var elite=bool(p.get("elite",false))
			var width=115 if elite else 55
			if elite:text_at(point+Vector2(0,-dimensions.y-25),"◆ LV.%d %s" % [p.level,p.name],16,Color("ffe0a2"),true)
			draw_rect(Rect2(point+Vector2(-width/2,-dimensions.y-15),Vector2(width,7 if elite else 5)),Color("e4b96c") if elite else Color("e8d5c7"))
			draw_rect(Rect2(point+Vector2(-width/2,-dimensions.y-15),Vector2(width*float(p.hp)/p.max_hp,5)),Color("d8787d"))
			if role=="warden": text_at(point+Vector2(0,-dimensions.y-28),p.name,18,GOLD,true)
		elif is_hero:
			text_at(point+Vector2(0,-dimensions.y-13),p.name,15,Color("fff4d0") if is_self else Color("8dd9d8"),true)

func draw_building(data:Dictionary):
	var frame=preload("res://scripts/world_art.gd").frame("town",data.art)
	var height=float(data.height);var scale=height/frame.height
	var point=world_point(data.pos);var dimensions=frame.texture.get_size()*scale
	draw_texture_rect(frame.texture,Rect2(point-Vector2(dimensions.x*.5,dimensions.y),dimensions),false,Color(1,1,1,building_alphas.get(data.key,1.0)))
	if data.key not in preload("res://scripts/world_catalog.gd").RESIDENTS:text_at(point+Vector2(0,22),data.name,18,Color("fff0bf"),true)

func draw_resident(data:Dictionary):
	var resident=preload("res://scripts/world_catalog.gd").RESIDENTS[data.key]
	var point=world_point(data.pos)
	var frame=GatArt.frame({"avatar":resident.avatar,"class_id":"warrior"},visual_time)
	var scale=112.0/frame.height
	draw_set_transform(point,0,Vector2(1,.42));draw_circle(Vector2.ZERO,24,Color("32574a40"));draw_set_transform(Vector2.ZERO)
	draw_texture_rect(frame.texture,Rect2(point-frame.foot*scale,frame.texture.get_size()*scale),false)
	var near_player=session.state.players[session.local_id].pos.distance_to(data.pos)<.9
	if not near_player and not (npc_dialogue.visible and npc_dialogue.facility==data.key):text_at(point+Vector2(0,-130),resident.name,16,Color("ffeda9"),true)
	if not session.paused and session.state.players[session.local_id].pos.distance_to(data.pos)<2.7:
		SemanticIcons.draw(self,"interact",Rect2(point+Vector2(-58,6),Vector2(22,22)))
		text_at(point+Vector2(8,25),"E 대화",15,Color("fff5dc"),true)


func make_route(start: Vector2, goal: Vector2) -> Array:
	var begin = Vector2i(roundi(start.x),roundi(start.y))
	var end = Vector2i(roundi(goal.x),roundi(goal.y))
	var queue = [begin]
	var came = {begin:begin}
	var index = 0
	while index < queue.size():
		var current = queue[index]
		index += 1
		if current==end: break
		for off in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var next = current+off
			if dungeon.floor_cells.has(next) and not came.has(next):
				came[next]=current
				queue.append(next)
	var result = []
	if not came.has(end): return result
	var current = end
	while current!=begin:
		result.push_front(Vector2(current))
		current=came[current]
	return result

func bot_step(delta: float):
	bot_elapsed += delta
	var p = session.state.players[session.local_id]
	bot_max_peers = maxi(bot_max_peers,session.state.players.size())
	bot_kills = maxi(bot_kills,p.kills)
	bot_distance += p.pos.distance_to(bot_last_pos)
	bot_last_pos = p.pos
	if bot_initial_xp < 0: bot_initial_xp=p.xp
	if input_timer < 0.08:return
	input_timer=0.0
	var direction=Vector2.ZERO
	var aim=Vector2.RIGHT
	var closest: Dictionary={}
	var distance=3.3
	for e in session.state.enemies.values():
		var d=p.pos.distance_to(e.pos)
		if e.hp>0 and d<distance and dungeon.line_clear(p.pos,e.pos):
			distance=d;closest=e
	if not closest.is_empty():
		aim=p.pos.direction_to(closest.pos)
		if distance>1.2:direction=aim
		session.act("attack")
		session.act("nova")
	elif bot_route_index<bot_route.size():
		var destination: Vector2=bot_route[bot_route_index]
		if p.pos.distance_to(destination)<0.3:bot_route_index+=1
		else:direction=p.pos.direction_to(destination)
	else:
		var goal=Vector2(dungeon.rooms[mini(8,1+int(bot_elapsed/18))])
		bot_route=make_route(p.pos,goal);bot_route_index=0
	session.send_input(direction,aim)
	if p.hp<p.max_hp*0.6:session.act("potion")
	for drop in session.state.drops.values():
		if p.pos.distance_to(drop.pos)<1.8:session.act("interact")

func write_bot_report():
	var p=session.state.players.get(session.local_id,{})
	var report={"world_seed":session.world_seed,"paused":session.paused,"connected":session.connected,"status":status_text,"snapshots":session.received_snapshots,"max_peers":bot_max_peers,"kills":bot_kills,"distance":bot_distance,"player":p}
	report["floor"]=session.sim.map.floor_number if session.sim!=null else 0
	report["codex"]={"visible":codex.visible,"tab":codex.selected_tab,"total":codex.result.get("total",0)}
	report["guardians"]=session.sim.enemies.values().filter(func(e):return e.get("guardian",false)) if session.sim!=null else []
	report["ui"]={"title":menu.visible,"creator":character_sheet.visible,"dialogue":npc_dialogue.visible,"speaker":npc_dialogue.speaker.text,"skill_tree":skill_tree.visible,"keyboard":help_panel.visible,"title_records":menu.records.map(func(b):return b.text),"creator_appearance":character_sheet.sheet.duplicate(true) if character_sheet.visible else {}}
	report["art_usage"]=art_usage.duplicate(true);report.art_usage["icons"]=SemanticIcons.audit()
	report.art_usage["ground"]=forest.ground_evidence()
	report.art_usage["equipment"]=EquipmentArt.audit()
	report.art_usage["equipment_consumers"]=equipment_ui_evidence()
	report.art_usage["prepared"]=preload("res://scripts/prepared_art_v05.gd").loads.duplicate()
	report["capture_view"]=str(options.get("capture-view","player"))
	var file=FileAccess.open(options.report,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(report,"\t"));file.close()

func equipment_ui_evidence()->Dictionary:
	var result={"bag_visible":bag.is_visible_in_tree(),"bag_items":[],"codex_visible":codex.is_visible_in_tree(),"codex_detail":{},"codex_rows":[]}
	if result.bag_visible:
		var controls=bag.grid.get_children()+bag.equipment_controls.values()
		for control in controls:
			if not control.is_visible_in_tree():continue
			var asset=EquipmentArt.describe_texture(control.picture)
			if asset.is_empty():continue
			asset["item_id"]=str(control.item.get("id",""));asset["slot"]=control.equip_slot
			result.bag_items.append(asset)
	if result.codex_visible and codex.selected_tab=="equipment":
		result.codex_detail=EquipmentArt.describe_texture(codex.detail_icon.texture)
		for id in codex.row_buttons:
			var button=codex.row_buttons[id]
			if not button.is_visible_in_tree():continue
			for child in button.get_children():
				if not child is TextureRect or not child.is_visible_in_tree():continue
				var asset=EquipmentArt.describe_texture(child.texture)
				if not asset.is_empty():
					asset["record_id"]=str(id);result.codex_rows.append(asset)
	return result

func record_art_usage(kind:String,id:String,index:int=-1,source:String=""):
	if not options.has("report"):return
	if kind=="costume":
		var record=art_usage.costume;record.id=id;record.draws+=1
		if index not in record.frame_indices:record.frame_indices.append(index)
		if not source.is_empty() and source not in record.source_sheets:record.source_sheets.append(source)
	elif kind=="environment":
		art_usage.environment.theme=preload("res://scripts/environment_art.gd").theme(dungeon.zone,dungeon.floor_number)
		if id not in art_usage.environment.drawn_ids:art_usage.environment.drawn_ids.append(id)
	elif kind=="monsters":
		if id not in art_usage.monsters.drawn_ids:art_usage.monsters.drawn_ids.append(id)
	elif kind=="monster_fallback":
		if id not in art_usage.monsters.fallback_kinds:art_usage.monsters.fallback_kinds.append(id)
	elif kind=="npc":
		if not art_usage.has("npcs"):art_usage["npcs"]=[]
		if id not in art_usage.npcs:art_usage.npcs.append(id)
