extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Creation=preload("res://scripts/character_creation.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func key(code:int,pressed:bool=true):
	var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
func tap(code:int):key(code);key(code,false)
func release_focus():
	var focus=root.gui_get_focus_owner()
	if focus!=null:focus.release_focus()
func capture(name:String):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/client-v051-"+name+".png"))==OK,"framebuffer "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	var folder=ProjectSettings.globalize_path("res://../runtime/client-flow-v051/"+str(Time.get_ticks_usec()))
	var game=load("res://main.tscn").instantiate();game.options={"mute":true,"save-dir":folder};root.add_child(game);await process_frame
	game.set_physics_process(false);game.session.set_physics_process(false)
	var local=game.session
	check(game.keybindings_path==folder.path_join("keybindings.json"),"preferences use explicitly isolated save directory")
	check(game.start_button.text=="모험 시작","empty slot starts adventure")
	for index in range(2):
		var sim=Sim.new(20260908,"town");var p=sim.add_player(1,"가나다라마바사아자차카타파하가나" if index==0 else "여",{})
		p.level=7 if index==0 else 4;p.tutorial_done=true;sim.recalculate(p)
		var record=sim.persistent(1);record.world_seed=20260908
		check(local.write_save(record,folder.path_join("slot-%d.json"%(index+1))),"write title fixture "+str(index))
	game.refresh_slot_summary()
	check(game.menu.records[0].text.contains("Lv.7") and game.menu.records[0].text.replace("\n","").contains("가나다라마바사아자차카타파하가나"),"record shows full 16-character nickname and level")
	check(game.menu.records[1].text.contains("Lv.4") and game.menu.records[1].text.contains("여"),"second record has its own character")
	check(game.menu.records[2].text.contains("빈 기록"),"empty slot distinguished")
	for b in game.menu.records:
		var font=b.get_theme_font("font");var pixels=b.get_theme_font_size("font_size");var lines=b.text.split("\n")
		check(font.get_height(pixels)*lines.size()<=b.size.y,"all saved-name lines fit vertically")
		for line in lines:check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x<=b.size.x-4,"record glyphs fit horizontally")
	await capture("records")
	tap(KEY_ESCAPE);await process_frame
	check(game.help_panel.is_visible_in_tree() and not local.connected,"ESC opens keyboard from title without a simulation")
	tap(KEY_ESCAPE);await process_frame
	check(not game.help_panel.visible and game.menu.visible,"ESC returns to title")
	game.slot_picker.select(2);game.refresh_slot_summary();game.begin_adventure()
	check(game.character_sheet.visible and local.slot_state(3)=="empty","empty record opens creation without writing a save")
	for cls in Creation.CLASSES:
		game.character_sheet.select_class(cls)
		check(game.character_sheet.sheet.avatar=="auto" and game.character_sheet.sheet.costume=="none" and not game.character_sheet.avatar_grid.visible,"creator fixed class appearance "+cls)
	tap(KEY_ESCAPE);game.slot_picker.select(0);game.refresh_slot_summary();game.begin_adventure();await process_frame
	local.set_physics_process(false);var p=local.sim.players[1];local.sim.enemies.clear();local.refresh();release_focus()
	check(local.connected and game.hud.visible and not game.menu.visible,"saved adventure resumes")
	var keymap=game.keybindings
	for pair in [["bag",KEY_J],["skills",KEY_U],["codex",KEY_O],["move_up",KEY_UP],["sprint",KEY_CTRL],["dodge",KEY_2],["potion",KEY_3]]:
		check(keymap.assign(keymap.bindings,pair[0],pair[1]).ok,"map action "+pair[0])
	game.on_keybindings_changed()
	check(game.hud.bag_button.hotkey=="J" and game.hud.circles.potion.hotkey=="3","actual HUD reads changed keys")
	tap(KEY_I);check(not game.bag.visible,"old bag key no longer opens bag")
	tap(KEY_J);check(game.bag.visible and local.paused,"mapped bag key opens inventory")
	tap(KEY_J);check(not game.bag.visible and not local.paused,"mapped bag key closes inventory")
	tap(KEY_U);check(game.skill_tree.visible,"mapped growth key opens skill tree")
	game.skill_tree.search.grab_focus();var potions=p.potions
	tap(KEY_3);check(p.potions==potions and game.skill_tree.visible,"typing in search cannot use potion")
	tap(KEY_J);check(not game.bag.visible and game.skill_tree.visible,"typing cannot switch modals")
	tap(KEY_ESCAPE);check(not game.skill_tree.visible,"ESC still closes a focused text modal")
	release_focus();tap(KEY_O);check(game.codex.visible and local.paused,"mapped codex key opens encyclopedia")
	tap(KEY_ESCAPE);release_focus()
	key(KEY_UP);key(KEY_CTRL);game._physics_process(.06)
	check(p.dir.is_equal_approx(game.Dungeon.from_iso(Vector2.UP).normalized()) and p.sprint,"movement polling uses mapped direction and sprint")
	key(KEY_UP,false);key(KEY_CTRL,false);key(KEY_W);game._physics_process(.06)
	check(p.dir==Vector2.ZERO and not p.sprint,"old direction and sprint keys no longer held")
	key(KEY_W,false);p.dodge_cd=0.;p.stamina=p.max_stamina;tap(KEY_2)
	check(p.dodge_cd>0 and p.dodge_time>0,"mapped dodge triggers actual combat action")
	p.hp=maxi(1,p.max_hp-30);p.potions=2;p.potion_cd=0.;tap(KEY_3)
	check(p.potions==1 and p.potion_cd>0,"mapped potion triggers actual healing")
	local.change_map("forest",1);p=local.sim.players[1];p.pos=Vector2(local.sim.map.rooms[1]);local.sim.enemies.clear();local.refresh()
	p.attack_cd=0.;p.dodge_time=0.;local.act("heavy_begin");check(p.charge_time>=0,"mouse heavy charge fixture begins outside safe town")
	game.toggle_help();check(p.charge_time<0 and local.paused,"keyboard opening cancels pending heavy attack")
	await capture("keys")
	tap(KEY_ESCAPE);check(not local.paused,"closing settings restores active play")
	game.toggle_bag();game.toggle_help();check(local.paused,"settings can open over paused inventory")
	tap(KEY_ESCAPE);check(game.bag.visible and local.paused,"settings close preserves underlying modal pause")
	game.toggle_bag();local.save_game()
	check(local.parse_save(local.save_path()).name=="가나다라마바사아자차카타파하가나","routing and UI preserve character identity")
	await game.audio_director.shutdown();game.queue_free();await process_frame
	print("CLIENT_FLOW_V051_TESTS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
