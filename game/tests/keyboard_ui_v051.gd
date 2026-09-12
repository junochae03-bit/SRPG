extends SceneTree
const Keys=preload("res://scripts/key_bindings.gd")
var checks=0
var failures=[]
var game
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func click(control:Control):
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=control.get_global_transform_with_canvas()*(control.size*.5);event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func key(code:int):
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func capture(name:String):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image();check(image.get_size()==Vector2i(1920,1080),"FullHD "+name)
	check(image.save_png(ProjectSettings.globalize_path("res://../artifacts/keyboard-v051-"+name+".png"))==OK,"capture "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	var model=Keys.new();check(model.valid(model.defaults()),"default keys unique and complete")
	var draft=model.defaults();var result=model.assign(draft,"bag",KEY_K)
	check(result.ok and result.swapped=="skills" and draft.bag==KEY_K and draft.skills==KEY_I,"conflict swaps two actions")
	check(model.key_for("bag")==KEY_I,"draft leaves live keys untouched")
	var before=draft.duplicate();check(not model.assign(draft,"bag",KEY_ESCAPE).ok and draft==before,"Escape reserved without mutation")
	check(not model.assign(draft,"missing",KEY_Y).ok,"unknown action rejected")
	for invalid in [{}, {"bag":KEY_I}, model.defaults().merged({"bag":KEY_K},true), model.defaults().merged({"bag":1.5},true)]:check(not model.valid(invalid),"invalid binding rejected")
	for action in Keys.DEFAULTS:
		var event=InputEventKey.new();event.physical_keycode=Keys.DEFAULTS[action];event.pressed=true
		check(model.action_for_event(event)==action,"physical key resolves "+action);event.echo=true;check(model.action_for_event(event)=="","echo ignored "+action);event.echo=false;event.pressed=false;check(model.action_for_event(event)=="","release ignored "+action)
	game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	game.session.save_directory=ProjectSettings.globalize_path("res://../runtime/keyboard-v051/"+str(Time.get_ticks_usec()));game.keybindings_path=game.session.save_directory.path_join("keybindings.json");game.keybindings.bindings=Keys.DEFAULTS.duplicate()
	var panel=game.help_panel;game.toggle_help();await process_frame
	for button in panel.action_buttons.values()+panel.key_buttons.values():
		for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
			check(button.get_theme_color(state).get_luminance()<.45,"dark paper text in "+state+" "+button.text)
	await process_frame;await process_frame
	var hover_events={"entered":0}
	panel.action_buttons.skill_c.mouse_entered.connect(func():hover_events.entered+=1)
	var hover=InputEventMouseMotion.new();hover.position=panel.action_buttons.skill_c.get_global_transform_with_canvas()*(panel.action_buttons.skill_c.size*.5);hover.global_position=hover.position;root.push_input(hover,true)
	await process_frame
	check(hover_events.entered>0,"real action-button hover")
	await capture("hover-contrast")
	check(panel.visible and not game.session.connected and not panel.title_button.visible,"settings work on disconnected title")
	check(panel.action_buttons.size()==Keys.DEFAULTS.size(),"all configurable actions visible")
	for code in panel.key_buttons:
		var button=panel.key_buttons[code];check(Rect2(Vector2.ZERO,panel.size).encloses(button.get_rect()),"keyboard key inside panel "+Keys.key_name(code))
		var font=button.get_theme_font("font");var pixels=button.get_theme_font_size("font_size")
		check(font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x<=button.size.x-12,"key legend fits "+button.text)
		for character in button.text:check(font.has_char(character.unicode_at(0)),"key glyph available "+button.text)
	await capture("title")
	click(panel.action_buttons.bag);key(KEY_K);await process_frame
	check(panel.draft.bag==KEY_K and panel.draft.skills==KEY_I and game.keybindings.key_for("bag")==KEY_I,"real action click and physical key swap draft only")
	key(KEY_ESCAPE);check(not panel.visible and game.keybindings.key_for("bag")==KEY_I,"Escape cancels draft")
	game.toggle_help();click(panel.action_buttons.bag);key(KEY_K);click(panel.key_buttons[KEY_ESCAPE]);await process_frame
	check(not panel.visible and game.keybindings.key_for("bag")==KEY_I,"on-screen Escape closes and cancels the draft")
	game.toggle_help();click(panel.action_buttons.bag);click(panel.key_buttons[KEY_PAGEDOWN]);await process_frame
	check(panel.draft.bag==KEY_PAGEDOWN,"on-screen physical key click assigns")
	click(panel.apply_button);await process_frame
	check(not panel.visible and game.keybindings.key_for("bag")==KEY_PAGEDOWN,"Apply commits and closes")
	var restarted=Keys.new();check(restarted.load_file(game.keybindings_path) and restarted.bindings==game.keybindings.bindings,"restart reads exact saved mapping")
	var saved=restarted.bindings.duplicate();var corrupt=FileAccess.open(game.keybindings_path+".invalid",FileAccess.WRITE);corrupt.store_string("{\"schema_version\":1,\"bindings\":{}}");corrupt.close()
	check(not restarted.load_file(game.keybindings_path+".invalid") and restarted.bindings==saved,"invalid file preserves live mapping")
	check(restarted.save_file(game.keybindings_path),"atomic save replaces an existing preferences file")
	var reload=Keys.new();check(reload.load_file(game.keybindings_path) and reload.bindings==saved,"overwritten preferences remain readable")
	game.toggle_help();panel.reset_draft();check(panel.draft.bag==KEY_I and game.keybindings.key_for("bag")==KEY_PAGEDOWN,"reset remains draft until apply");panel.close()
	game.join_game();game.session.set_physics_process(false);game.set_physics_process(false);await process_frame
	game.toggle_bag();game.toggle_help();check(panel.visible and panel.was_paused and panel.title_button.visible,"keyboard over paused inventory remembers pause")
	key(KEY_ESCAPE);check(game.session.paused and game.bag.visible,"keyboard close restores existing modal pause");game.toggle_bag()
	game.toggle_help();check(game.session.paused and not panel.was_paused,"keyboard pauses active game")
	# Drag the actual action control to a physical key, traversing Godot's GUI.
	var origin=panel.action_buttons.codex.get_global_transform_with_canvas()*(panel.action_buttons.codex.size*.5)
	var target=panel.key_buttons[KEY_HOME].get_global_transform_with_canvas()*(panel.key_buttons[KEY_HOME].size*.5)
	var down=InputEventMouseButton.new();down.position=origin;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;root.push_input(down,true)
	var motion=InputEventMouseMotion.new();motion.position=origin+Vector2(20,0);motion.relative=Vector2(20,0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true);await process_frame
	motion=motion.duplicate();motion.position=target;motion.relative=target-origin;root.push_input(motion,true);await process_frame
	var up=down.duplicate();up.position=target;up.pressed=false;root.push_input(up,true);await process_frame
	check(panel.draft.codex==KEY_HOME,"actual GUI drag assigns action to physical key")
	await capture("assigned")
	panel.close();check(not game.session.paused,"closing keyboard resumes previous gameplay")
	game.hud.refresh_key_labels();check(game.hud.bag_button.hotkey=="PGDN","HUD label follows persisted map")
	game.toggle_help();click(panel.title_button);await process_frame
	check(not game.session.connected and not panel.visible and game.menu.visible,"save and title remains available from settings")
	check(await game.audio_director.shutdown(),"audio drains before test exit")
	print("KEYBOARD_UI_V051 checks=%d failures=%d"%[checks,failures.size()]);print(JSON.stringify({"suite":"keyboard_ui_v051","checks":checks,"failures":failures}));game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
