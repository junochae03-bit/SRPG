extends SceneTree
const Creation=preload("res://scripts/character_creation.gd")
const World=preload("res://scripts/world_catalog.gd")
var checks=0
var failures=[]
func _initialize():
	run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func capture(name:String):
	await create_timer(.12).timeout;await process_frame;await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../artifacts/v04-"+name+".png");DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+name)
func key(code:int):
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func click(control:Control):
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=control.get_global_transform_with_canvas()*(control.size*.5);event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func run():
	# Full HD client area, independent of desktop title-bar constraints.
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var local=game.session;local.save_directory=ProjectSettings.globalize_path("res://../runtime/creator-ui-v04/"+str(Time.get_ticks_usec()));game.refresh_slot_summary()
	await capture("title")
	click(game.start_button);await process_frame
	var panel=game.character_sheet
	check(panel.visible and not local.connected and not game.menu.visible,"start click opens creator before simulation")
	check(panel.create_button.disabled,"blank name cannot finish")
	key(KEY_ESCAPE);await process_frame
	check(not panel.visible and game.menu.visible and local.slot_state(1)=="empty","ESC cancel returns title without writing")
	click(game.start_button);await process_frame
	panel.name_field.text="새벽별";panel.name_field.text_changed.emit("새벽별");click(panel.job_buttons.mage);panel.sheet.stats=Creation.suggested("mage");panel.refresh()
	await process_frame
	check(panel.sheet.avatar=="auto" and panel.sheet.costume=="none" and panel.sheet.class_id=="mage" and not panel.avatar_grid.visible,"class selection keeps fixed default appearance")
	check(not panel.create_button.disabled and panel.balance_label.text.ends_with("0"),"ready sheet")
	for label in panel.stat_labels.values():check(label.get_line_height()<=label.size.y,"stat digits not clipped")
	await capture("character-sheet")
	click(panel.create_button);await process_frame;local.set_physics_process(false);game.set_physics_process(false)
	check(local.connected and not panel.visible and game.hud.visible,"finish enters tutorial")
	var p=local.sim.players[1];check(p.name=="새벽별" and p.class_id=="mage" and p.stats.magic==5,"sheet committed")
	check(not game.connection_label.visible and game.connection_label.text.is_empty(),"persistent save explanation removed")
	await capture("clean-hud")
	p.tutorial_kills=5;check(local.travel("town"),"town arrival");local.set_physics_process(false)
	var npc=game.npc_dialogue
	for facility in World.RESIDENTS:
		local.sim.players[1].pos=World.resident_pos(facility);local.refresh();check(local.act("interact"),facility+" interaction")
		check(npc.visible and local.paused and not game.town_panel.visible,facility+" speaks before services")
		check(npc.speaker.text==World.RESIDENTS[facility].name and npc.portrait.texture!=null,facility+" correct name portrait")
		check(not local.act("attack"),"dialogue blocks combat")
		if facility=="smith":
			await capture("npc-dialogue");click(npc.story_button);check(npc.dialogue.text==npc.STORIES.smith,"conversation branch")
			click(npc.service_button);await process_frame
			check(game.town_panel.visible and not npc.visible and local.paused,"service choice opens counter")
			game.town_panel.close();npc.open(facility)
		key(KEY_ESCAPE);await process_frame
		check(not npc.visible and not local.paused and not game.help_panel.visible,"ESC exits dialogue without menu")
	for modal in ["growth","help","bag","codex"]:
		var paused_player=local.sim.players[1];paused_player.hp=1;paused_player.potions=5;local.refresh()
		match modal:
			"growth":game.toggle_skills()
			"help":game.toggle_help()
			"bag":game.toggle_bag()
			"codex":game.toggle_codex()
		await process_frame
		check(local.paused,"modal pauses "+modal)
		key(KEY_1);await process_frame
		check(paused_player.potions==5 and paused_player.hp==1,"combat potion hotkey does not act through "+modal)
		key(KEY_ESCAPE);await process_frame
		check(not local.paused,"modal closes "+modal)
	local.save_game();local.disconnect_game();game.refresh_slot_summary();click(game.start_button);await process_frame
	check(local.connected and not panel.visible and local.sim.players[1].name=="새벽별","existing character continues without creator")
	game.stop_audio();local.disconnect_game();root.remove_child(game);game.queue_free();await process_frame
	print("CHARACTER_DIALOGUE_UI_V04_TESTS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
