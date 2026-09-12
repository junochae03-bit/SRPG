extends SceneTree
const Options=preload("res://scripts/game_options.gd")
var checks=0
var failures=[]
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func click(control:Control):
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=control.get_global_transform_with_canvas()*(control.size*.5);event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func capture(name:String):
	game.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../artifacts/hud-tab-"+name+".png")==OK,"capture "+name)
func run():
	for usable in [Rect2i(0,0,1920,1040),Rect2i(-1920,0,1920,1040),Rect2i(0,0,1280,680)]:
		var fitted=Options.fitted_window(Vector2i(1920,1080),usable,Vector2i(16,39),Vector2i(8,31))
		check(usable.encloses(Rect2i(fitted.position-Vector2i(8,31),fitted.size+Vector2i(16,39))),"decorated window entirely inside work area "+str(usable))
	root.borderless=false;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);root.position=Vector2i(-50,-40)
	game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/hud-tabs/"+str(Time.get_ticks_usec()));root.add_child(game)
	await process_frame;await process_frame
	Options.fit_window(game);await process_frame
	var actual=Rect2i(DisplayServer.window_get_position_with_decorations(),DisplayServer.window_get_size_with_decorations())
	check(DisplayServer.screen_get_usable_rect(root.current_screen).encloses(actual),"actual native decorated window fully visible")
	root.borderless=true;root.size=Vector2i(1920,1080)
	game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var session=game.session;var p=session.sim.players[1];p.level=100;p.tutorial_done=true;p.highest_floor=100
	session.travel("town");session.enter_floor(12);p=session.sim.players[1];p.pos=Vector2(session.sim.map.rooms[0]);session.sim.recalculate(p);p.hp=p.max_hp
	for e in session.sim.enemies.values():e.hp=0
	game.update_battle_camera(p,1.,true);session.refresh();game.forest.update_camera();game.exploration_panel.hide()
	var hud=game.hud;var chrome=hud.expedition
	click(chrome.tabs[0]);await process_frame
	check(hud.job_resource.display_mode==0 and not game.skill_tree.visible,"stats tab remains compact")
	var crit=preload("res://scripts/combat_stats.gd").critical(p,session.sim.combat.jobs)
	check(is_zero_approx(crit.chance),"no invented base critical chance")
	var base=session.sim.damage_for(p,"physical");session.sim.combat.jobs.buff(p,"attack",.2,10.)
	var actual_damage=session.sim.combat.jobs.outgoing(p,{"pos":p.pos+Vector2(4,0)},base)
	check(preload("res://scripts/combat_stats.gd").rows(session.sim,p)[0][1]==str(actual_damage) and actual_damage>base,"HUD reflects the same common attack buff as real outgoing damage")
	p.job_state.buffs.crit={"time":10.,"value":.2};session.refresh()
	check(is_equal_approx(preload("res://scripts/combat_stats.gd").critical(p,session.sim.combat.jobs).chance,.2),"critical updates with live buff")
	await capture("stats")
	for rect in hud.job_resource.content_draw_rects:check(hud.job_resource.content_bounds().encloses(rect),"stat text inside content area")
	p.class_id="gambler";session.sim.combat.jobs.reset(p);session.refresh();click(chrome.tabs[1]);await process_frame
	check(hud.job_resource.display_mode==1 and not p.job_state.hand.is_empty(),"skill tab shows actual gambler hand")
	await capture("identity")
	click(chrome.tabs[2]);await process_frame
	check(not game.bag.visible and chrome.consumables.position==Vector2(106,802),"bag tab contains existing quick slots")
	var panel_bounds=hud.job_resource.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,hud.job_resource.size)
	for slot in chrome.consumables.slots:check(panel_bounds.encloses(slot.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,slot.size)),"quick slot within compact panel")
	click(chrome.consumables.slots[1]);await process_frame
	check(chrome.consumables.picker.visible,"empty quick slot opens real registration")
	click(chrome.consumables.assign_button);await process_frame
	check(chrome.consumables.assignments[1]=="potion","register from compact bag panel")
	await capture("quickslots")
	p.hp=10;p.potion_cd=0.;session.refresh();click(chrome.consumables.slots[1]);await process_frame
	check(p.hp>10,"registered slot consumes actual potion")
	var potions=chrome.consumables
	for key in ["mana_potion","power_potion"]:check(preload("res://scripts/inventory_model.gd").add_stack(p,key,3),"supply "+key)
	session.refresh();potions.open_picker(2);await process_frame
	await capture("potion-picker")
	click(potions.assign_buttons.mana_potion);await process_frame
	potions.open_picker(3);click(potions.assign_buttons.power_potion);await process_frame
	check(potions.assignments[2]=="mana_potion" and potions.assignments[3]=="power_potion","register two distinct consumables")
	potions.loaded_path="";potions.load_preferences();check(potions.assignments[2]=="mana_potion","slot preference reload")
	p.stamina=0;p.potion_cd=0;session.refresh();click(potions.slots[2]);await process_frame
	check(p.stamina==60 and p.consumables.mana_potion==2,"click mana uses actual resource")
	p.potion_cd=0;session.refresh();click(potions.slots[3]);await process_frame
	check(p.job_state.buffs.has("potion_attack") and p.consumables.power_potion==2,"click power grants timed effect")
	await capture("registered-potions")
	for level in [1,30,60,100]:
		p.level=level;session.refresh();await capture("portrait-level-"+str(level))
	p.class_id="healer";p.stats.technique=0;p.gear_stats={}
	var details=preload("res://scripts/combat_stats.gd").details(session.sim,p)
	check(details.contains("기술 무력화 보정 +0.0%") and details.contains("직업 무력화 보정 +42.9%"),"technique and low damage role stagger contributions are separate")
	check(await game.audio_director.shutdown(),"audio drained")
	session.connected=false;game.queue_free();await process_frame;await process_frame
	print("HUD_TABS checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
