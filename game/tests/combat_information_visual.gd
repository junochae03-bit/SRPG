extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func render():
	game._process(.1);game.hud.refresh();game.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await render()
	check(root.get_texture().get_image().save_png("res://../artifacts/"+name+".png")==OK,"rendered "+name)
func pointer(at:Vector2):
	game.aim_pointer_received=true;game.aim_pointer_viewport=root.canvas_transform*at
	game.inspection_panel._process(.01)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/combat-information/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	var sim=Sim.new(31,"cave",12);var kind=sim.enemies[1].kind;sim.enemies.clear();var p=sim.add_player(1,"별하")
	p.pos=Vector2(sim.map.rooms[1]);p.level=20;sim.recalculate(p)
	var enemy=sim.spawn_enemy(kind,p.pos+Vector2(2,0),20);enemy.hp=int(enemy.max_hp*.7);enemy.slow_time=3.
	game.session.sim=sim;game.session.refresh();game.on_entered();game.update_battle_camera(p,0.,true)
	game.inspection_panel.set_process(false);game.noise_feedback.set_process(false)
	await render()
	check(game.monster_aim_frames.has(enemy.id),"live actor has rendered hit frame")
	if game.monster_aim_frames.has(enemy.id):
		var frame=game.monster_aim_frames[enemy.id];pointer(frame.transform*frame.rect.get_center())
	check(game.inspection_panel.visible and game.inspection_panel.target_id==enemy.id,"actual body hover opens inspection")
	check(game.inspection_panel.health.text=="%d / %d"%[enemy.hp,enemy.max_hp],"health uses current authority")
	check(game.inspection_panel.status_row.get_child_count()==1,"actual active debuff is shown")
	check(game.inspection_panel.status_row.get_child(0).tooltip_text=="둔화","debuff has readable name")
	await capture("enemy-inspection-live")
	for label in [game.inspection_panel.heading,game.inspection_panel.subtitle,game.inspection_panel.health,game.inspection_panel.shapes]:
		check(label.get_theme_font("font").get_height(label.get_theme_font_size("font_size"))<=label.size.y,"inspection font height fits")
	enemy.guard_break_time=2.;enemy.stun_time=2.;enemy.taunt_time=2.;enemy.job_status={}
	for key in ["root","bleed","blind","vulnerable","weaken"]:enemy.job_status[key]={"time":2.}
	game.session.refresh();game.inspection_panel._process(.01)
	check(game.inspection_panel.status_row.get_child_count()==9 and game.inspection_panel.status_row.get_child(8).text=="+1","excess statuses have a count")
	check(not game.inspection_panel.status_row.get_child(8).tooltip_text.is_empty(),"excess statuses retain their names")
	await capture("enemy-inspection-statuses")
	game.inspection_panel.codex_button.pressed.emit()
	check(game.codex.visible and game.codex.selected_tab=="monsters" and game.codex.selected_id==enemy.kind and int(game.codex.filters.floor)==12,"actual codex button keeps monster and floor")
	game.codex.close();game.session.paused=false
	sim.kill(1,enemy);game.session.refresh();await render()
	var corpse=sim.inspection.corpses[0]
	check(game.inspection_panel.corpse_frames.has(corpse.record_id),"dead actor has a visible investigation marker")
	if game.inspection_panel.corpse_frames.has(corpse.record_id):pointer(game.inspection_panel.corpse_frames[corpse.record_id].get_center())
	check(game.inspection_panel.visible and game.inspection_panel.target_is_corpse,"corpse hover opens death record")
	await capture("enemy-inspection-corpse")
	game.inspection_panel.drops_button.pressed.emit()
	check(game.codex.visible and game.codex.selected_tab=="drops" and game.codex.filters.monster_id==enemy.kind and game.codex.result.total>0,"actual corpse button selects real drop table")
	game.codex.close();game.session.paused=false
	sim.awareness.emit(1,p.pos,6);game.session.refresh();game.noise_feedback._process(0.)
	check(game.noise_feedback.visible,"own recent sound has feedback")
	var rebuilds=game.noise_feedback.rebuilds
	for i in range(30):game.noise_feedback._process(.016)
	check(game.noise_feedback.rebuilds==rebuilds,"static pulse reuses propagation cache")
	check(game.noise_feedback.visible_edges().all(func(edge):return game.vision.sees(edge[0])),"sound outline exposes no unseen floor")
	await capture("enemy-noise-guide")
	p.pos=Vector2(70,70);game.session.refresh();game.refresh_vision();game.inspection_panel._process(.01)
	check(not game.inspection_panel.visible,"lost sight closes death record")
	sim.clock=2.;game.session.refresh();game.noise_feedback._process(0.)
	check(not game.noise_feedback.visible,"noise feedback expires")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("COMBAT_INFORMATION_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
