extends SceneTree
const Options=preload("res://scripts/game_options.gd")
var checks=0
var failures=[]
var game
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func key(code:int):
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func click(control:Control):
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=control.get_global_transform_with_canvas()*(control.size*.5);event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func capture(name:String):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/settings-v052-"+name+".png"))==OK,"capture "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	var model=Options.new();check(model.valid(Options.DEFAULTS),"valid initial options")
	for change in [{"music":-1},{"effects":2},{"window_mode":"broken"},{"fps":-60},{"resolution":9},{"enemy_names":1},{"damage_numbers":"true"}]:check(not model.valid(Options.DEFAULTS.merged(change,true)),"bad option rejected "+str(change))
	game=load("res://main.tscn").instantiate();game.options.mute=true;game.options.capture="";root.add_child(game);await process_frame
	game.session.save_directory=ProjectSettings.globalize_path("res://../runtime/settings-v052/"+str(Time.get_ticks_usec()));game.keybindings_path=game.session.save_directory.path_join("keybindings.json");game.audio_director.settings_path=game.session.save_directory.path_join("audio-settings.json")
	game.preferences.values=Options.DEFAULTS.duplicate()
	var panel=game.settings_panel
	key(KEY_ESCAPE);await process_frame
	check(panel.visible and not game.help_panel.visible,"ESC opens options, not keyboard")
	check(not panel.title_button.visible,"no save/title action when already at title")
	var backdrop=panel.get_node("ModalBackdrop")
	check(backdrop.mouse_filter==Control.MOUSE_FILTER_STOP and Rect2(backdrop.get_global_transform_with_canvas().origin,backdrop.size).has_point(Vector2(1550,850)),"modal backdrop covers outside controls")
	var underneath=Button.new();underneath.position=Vector2(2,790);underneath.size=Vector2(120,90);game.menu.add_child(underneath)
	var hits=[0];underneath.pressed.connect(func():hits[0]+=1)
	click(underneath);await process_frame
	check(hits[0]==0 and panel.visible,"outside click cannot activate underlying title control")
	underneath.queue_free()
	panel.controls.music.value=18
	check(is_equal_approx(float(panel.draft.music),.18) and game.preferences.values.music==.45,"sound edits stay in draft")
	click(panel.key_button);await process_frame
	check(game.help_panel.visible and not panel.visible,"keys are a child page")
	game.help_panel.select_action("bag");key(KEY_K)
	check(game.help_panel.draft.bag==KEY_K,"nested editor accepts actual key")
	key(KEY_ESCAPE);await process_frame
	check(panel.visible and not game.help_panel.visible and game.keybindings.key_for("bag")==KEY_I,"ESC returns to options and cancels key draft")
	check(is_equal_approx(float(panel.draft.music),.18),"option draft survives key subpage")
	click(panel.apply_button);await process_frame
	check(is_equal_approx(game.audio_director.music_gain,.18),"Apply changes actual mixer")
	var restored=Options.new();check(restored.load_file(game.session.save_directory.path_join("game-options.json")) and restored.values==game.preferences.values,"options restore after restart")
	panel.controls.music.value=77;key(KEY_ESCAPE)
	check(not panel.visible and is_equal_approx(game.audio_director.music_gain,.18),"closing discards unapplied values")
	key(KEY_ESCAPE);await capture("sound")
	click(panel.tabs.display);await capture("display")
	check(panel.pages.display.visible and not panel.pages.sound.visible,"actual display tab changes page")
	click(panel.tabs.combat);click(panel.controls.damage_numbers);click(panel.apply_button)
	check(not game.preferences.values.damage_numbers,"combat number visibility persists")
	await capture("combat")
	for control in panel.find_children("*","Label",true,false):
		if not control.visible or control.text.is_empty():continue
		check(control.get_line_count()*control.get_line_height()<=control.size.y+1,"label height "+control.text)
	key(KEY_ESCAPE);game.join_game();game.set_physics_process(false);game.session.set_physics_process(false);await process_frame
	var p=game.session.sim.players[1];p.charge_time=.4;key(KEY_ESCAPE)
	check(panel.visible and game.session.paused and p.charge_time<0,"settings pauses and cancels charged attack")
	click(panel.key_button);game.help_panel.select_action("bag");key(KEY_K);click(game.help_panel.apply_button);await process_frame
	check(panel.visible and game.session.paused and game.keybindings.key_for("bag")==KEY_K,"key apply returns to paused settings")
	key(KEY_ESCAPE);check(not game.session.paused,"closing settings resumes game")
	game.toggle_bag();game.toggle_settings();key(KEY_ESCAPE)
	check(game.bag.visible and game.session.paused,"options preserves an underlying modal")
	game.toggle_bag();game.toggle_settings();click(panel.title_button);await process_frame
	check(not game.session.connected and game.menu.visible and not panel.visible,"save and title closes settings cleanly")
	check(await game.audio_director.shutdown(),"audio drained")
	game.queue_free();await process_frame
	print("SETTINGS_V052 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
