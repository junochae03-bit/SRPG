extends SceneTree
const Content=preload("res://scripts/content.gd")
var checks=0
var failures=[]
var captures=[]
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func capture(name:String):
	game.queue_redraw();game.map_overlay.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../artifacts/expedition-hud-"+name+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+name);captures.append(path)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/expedition-hud/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	var session=game.session;session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	var p=session.sim.players[1];p.level=100;p.tutorial_done=true;p.cleared_floor=99;p.highest_floor=100
	check(session.travel("town") and session.enter_floor(12),"enter exploration floor from town")
	p=session.sim.players[1];game.update_battle_camera(p,1.,true);game.forest.update_camera(1.)
	var hud=game.hud;var chrome=hud.expedition
	session.refresh();hud.refresh()
	check(not hud.bag_button.visible and not hud.growth_button.visible,"no duplicate top bag and growth controls")
	check(hud.codex_button.visible,"unrelated codex remains available")
	check(not hud.circles.has("attack") and not hud.circles.has("heavy") and not hud.circles.has("dodge"),"no extra attack controls")
	check(chrome.PROFILE.size.y<180,"character pane reserves less than 180 logical pixels")
	for label in [hud.name_label,hud.hp_label]:check(label.get_rect().end.y<800,"health strip stays above skill icons")
	check(hud.job_resource.position==chrome.PROFILE.position,"class detail occupies requested lower-left area")
	check(hud.status_strip.get_rect().end.y<chrome.tabs[0].position.y,"all three status rows stay above tabs")
	for index in range(3):
		chrome.tabs[index].pressed.emit();hud.refresh_chrome()
		check(hud.chrome.visible and chrome.visible and not game.bag.visible and not game.skill_tree.visible,"tab stays inside compact HUD")
		check(hud.job_resource.display_mode==index,"tab selects stats identity or quick slots")
		check(chrome.consumables.position==Vector2(106,802) if index==2 else chrome.consumables.position==Vector2(665,744),"same live slots move into bag tab")
	chrome.open_tab(1)
	for panel in [game.settings_panel,game.npc_dialogue,game.codex]:
		panel.show();hud.refresh_chrome();check(not chrome.visible,"modal hides backdrop and tabs")
		panel.hide();hud.refresh_chrome();check(chrome.visible,"modal restores backdrop and tabs")
	# Existing snapshot identity governs the profile; no host-only assumption.
	var peer=session.sim.add_player(2,"두 번째 모험가");peer.level=82
	session.local_id=2;session.refresh();hud.refresh()
	check(hud.name_label.text==peer.name and hud.hp_label.text=="%d / %d"%[peer.hp,peer.max_hp],"guest profile follows local identity")
	session.local_id=1;session.sim.players.erase(2);session.refresh();hud.refresh()
	check(not chrome.party.visible,"solo hides party strip")
	for i in range(2,7):
		var friend=session.sim.add_player(i,"파티원 %d"%i)
		friend.hp=friend.max_hp/2;friend.stamina=friend.max_stamina/4
		friend.job_state=friend.job_state.duplicate(true);friend.job_state.buffs={"attack":{"time":8.,"value":.1}}
		friend.enemy_slow_time=4.
	session.refresh();hud.refresh()
	game.map_overlay.refresh_static()
	check(game.map_overlay.static_map.floor_points.size()==session.sim.map.floor_cells.size(),"expanded dungeon entirely fits minimap")
	check(chrome.party.rows.filter(func(row):return row.visible).size()==5,"all five other members shown")
	var mana_sample={"mana":25.,"max_mana":80.,"stamina":90.,"max_stamina":100.}
	check(chrome.party.resource(mana_sample)==25 and chrome.party.resource_max(mana_sample)==80,"mana values take precedence over stamina")
	check(is_equal_approx((chrome.get_global_transform_with_canvas()*(chrome.PERSONAL.position+hud.profile_offset)).x,12.),"personal panel anchored at left edge")
	check((chrome.get_global_transform_with_canvas()*(chrome.PERSONAL.position+hud.profile_offset)).y>=36,"personal panel has top safe margin")
	check(hud.name_label.position.y-(chrome.PERSONAL.position.y+hud.profile_offset.y)>=14,"name inset below upper frame")
	for row in chrome.party.rows:
		right_press(row);check(p.charge_time<0,"party row blocks right press before release");right_release(row)
		check(row.actor.id!=session.local_id and row.actor.hp==session.state.players[row.actor.id].hp,"party bars follow remote snapshot")
		check(row.buffs.size()==1 and row.buffs[0].key=="buff:attack","only active buffs beside party bars")
		check(row.get_rect().end.y+chrome.party.position.y<hud.status_strip.position.y,"party rows do not overlap local status")
	session.local_id=4;session.refresh();hud.refresh()
	check(chrome.party.rows.all(func(row):return row.actor.id!=4),"guest excludes their own row")
	session.sim.players[2].job_state.buffs.attack.time=0.;session.sim.players[2].hp=0
	session.refresh();hud.refresh()
	check(chrome.party.rows[1].buffs.is_empty() and chrome.party.rows[1].actor.hp==0,"dead member loses active icons")
	session.local_id=1
	for i in range(2,7):session.sim.players.erase(i)
	session.refresh();hud.refresh();check(not chrome.party.visible,"departures clear party strip")
	p.hp=maxi(1,p.max_hp-40);p.potion_cd=0.;p.potions=5;session.paused=false
	session.refresh();hud.refresh();var before=p.hp
	click(hud.expedition.consumables.slots[0]);await process_frame
	check(p.hp>before,"actual consumable slot click invokes healing")
	var rectangles=[]
	for key in hud.circles:
		var button=hud.circles[key]
		if not button.visible:continue
		var bounds=button.get_rect().grow(3)
		check(not button.show_caption and not button.tooltip_description().is_empty(),"slot names available on hover "+key)
		check(Rect2(0,0,1440,890).encloses(bounds),"slot inside bottom safe area "+key)
		for other in rectangles:check(not bounds.intersects(other),"slot targets stay separate "+key)
		rectangles.append(bounds)
		check(button._has_point(button.size*.5),"slot center is clickable "+key)
	var regions=chrome.world_regions()
	var gap=chrome.get_global_transform_with_canvas()*Vector2(480,795)
	check(not regions.any(func(rect):return rect.has_point(gap)),"empty space between profile and skills stays unobstructed")
	await check_consumables(session,p)
	await check_inputs(session,p)
	await capture("solo")
	check(await game.audio_director.shutdown(),"audio drained")
	session.connected=false;game.queue_free();await process_frame;await process_frame
	print("EXPEDITION_HUD checks=%d failures=%d captures=%s"%[checks,failures.size(),JSON.stringify(captures)])
	quit(0 if failures.is_empty() else 1)

func check_consumables(session,p):
	var bar=game.hud.expedition.consumables
	check(bar.slots.size()==4 and bar.get_rect().end.y<game.hud.circles.skill_q.position.y,"four consumable slots directly above skill bar")
	check(bar.assign(1,"potion") and bar.assign(2,"potion") and bar.assign(3,"potion"),"all four slots can register owned consumable")
	check(not bar.assign(0,"not-a-consumable") and not bar.assign(4,"potion"),"invalid registrations rejected")
	var saved=bar.assignments.duplicate();bar.loaded_path="";bar.load_preferences()
	check(bar.assignments==saved,"registered items persist on reload")
	p.hp=maxi(1,p.max_hp-200);p.potions=5;p.potion_cd=0.;session.refresh();game.hud.refresh()
	var before=p.potions
	check(bar.use_slot(1),"registered second slot invokes session item use")
	check(p.potions==before-1 and p.potion_cd>0,"real inventory decremented and cooldown started")
	check(not bar.use_slot(2) and p.potions==before-1,"duplicate item in another slot shares cooldown")
	check(bar.assign(1,"") and not bar.use_slot(1),"cleared slot cannot consume item")
	bar.open_picker(1);check(bar.picker.visible,"empty slot opens registration picker")
	check(not bar.use_slot(0),"picker prevents consumption behind selection")
	bar.picker.hide();p.potion_cd=0.;p.hp=p.max_hp;session.refresh()
	check(not bar.use_slot(0) and p.potions==before-1,"full health does not waste item")
	var keys=game.keybindings;var old=keys.defaults()
	for key in ["consumable_2","consumable_3","consumable_4"]:old.erase(key)
	old.potion=KEY_3
	var migrated=keys.migrate(old)
	check(keys.valid(migrated) and migrated.potion==KEY_3,"old custom binding preserved without new key collision")
	for key in old:check(migrated[key]==old[key],"existing binding retained "+key)

func click(control:Control,button=MOUSE_BUTTON_LEFT):
	var at=control.get_global_transform_with_canvas()*(control.size*.5)
	var motion=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
	var event=InputEventMouseButton.new();event.position=at;event.button_index=button;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func press(code:int):
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func right_press(control:Control):
	var at=control.get_global_transform_with_canvas()*(control.size*.5)
	var motion=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
	var event=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true;root.push_input(event,true)
func right_release(control:Control):
	var event=InputEventMouseButton.new();event.position=control.get_global_transform_with_canvas()*(control.size*.5);event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=false;root.push_input(event,true)
func check_inputs(session,p):
	var hud=game.hud;var bar=hud.expedition.consumables
	p.pos=Vector2(session.sim.map.rooms[1]);session.refresh();hud.refresh()
	for i in range(4):bar.assign(i,"potion")
	for i in range(4):
		p.hp=1;p.potion_cd=0;p.potions=8;session.refresh();hud.refresh()
		press(game.keybindings.bindings[bar.ACTIONS[i]]);await process_frame
		check(p.potions==7 and p.hp>1,"actual registered hotkey consumes once "+str(i+1))
	click(bar.slots[1],MOUSE_BUTTON_RIGHT);await process_frame
	check(bar.picker.visible and p.charge_time<0,"right click opens registration without charging")
	press(KEY_ESCAPE);await process_frame
	check(not bar.picker.visible and not game.settings_panel.visible,"ESC closes registration only")
	for surface in [hud.expedition.personal_surface,hud.job_resource,hud.name_label,hud.hp_label]:
		p.attack_cd=0;p.charge_time=-1;right_press(surface)
		check(p.charge_time<0,"HUD surface blocks heavy press before release");right_release(surface)
		var event=InputEventMouseButton.new();event.position=root.get_final_transform()*(surface.get_global_transform_with_canvas()*(surface.size*.5));event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
		Input.parse_input_event(event);Input.flush_buffered_events();game._physics_process(.06)
		check(p.attack_cd==0,"held primary attack blocked during real physics input "+str(surface.name))
		event=event.duplicate();event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
	p.attack_cd=0;p.charge_time=-1
	var world=InputEventMouseButton.new();world.position=Vector2(800,450);world.button_index=MOUSE_BUTTON_RIGHT;world.pressed=true
	var motion=InputEventMouseMotion.new();motion.position=world.position;root.push_input(motion,true);root.push_input(world,true)
	check(p.charge_time>=0,"world right press still starts charge")
	motion=motion.duplicate();motion.position=hud.hp_label.get_global_transform_with_canvas()*(hud.hp_label.size*.5);root.push_input(motion,true);right_release(hud.hp_label)
	check(p.charge_time<0 and p.attack_cd==0,"release over UI cancels world charge without attack")
	var old=p.potions;game.toggle_bag();press(KEY_1);await process_frame
	check(p.potions==old,"inventory blocks consumable key");game.toggle_bag()
