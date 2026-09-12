extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Hidden=preload("res://scripts/hidden_rooms.gd")
const Shortcuts=preload("res://scripts/exploration_shortcuts.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.session.refresh();game.refresh_vision();game.hud.refresh();game.forest.update_camera();game.queue_redraw();game.map_overlay.queue_redraw();game.exploration_panel._process(0.)
	await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await frame();check(root.get_texture().get_image().save_png("res://../artifacts/shortcut-"+name+".png")==OK,"capture "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/shortcut-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var sim=Sim.new(7996,"forest",1);var p=sim.add_player(1,"별하");p.level=100;p.tutorial_done=true;p.materials.tool=1
	sim.recalculate(p);p.hp=p.max_hp
	for enemy in sim.enemies.values():enemy.hp=0
	game.session.sim=sim;game.session.refresh();game.on_entered()
	var site=sim.map.hidden_regions.filter(func(value):return value.get("shortcut",false))[0]
	p.pos=site.pos;Hidden.discover(sim);game.session.refresh();game.update_battle_camera(p,1.,true);await frame()
	var panel=game.exploration_panel
	check(panel.visible and panel.first.text=="지름길 개방 · 탐사 도구 1","discovery has a clear opening action")
	check(panel.detail.text.contains("앞 구역") and panel.detail.text.contains("도구 1"),"benefit and owned cost visible before committing")
	for label in [panel.heading,panel.detail]:
		check(label.get_visible_line_count()>0 and label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x,"discovery title and detail fit their text bounds")
	check(not game.vision.discovered(site.center),"sealed passage remains hidden behind visible clue")
	await capture("sealed")
	var previous=game.forest.map_revision;panel.first.pressed.emit();await frame()
	check(sim.map.opened_regions.has(site.id) and p.materials.tool==0,"visible button opens real shared terrain")
	check(game.forest.map_revision>previous,"floor rendering rebuilt on geometry revision")
	check(not game.vision.discovered(sim.map.exit_position),"opening does not reveal whole destination")
	await capture("opened")
	p.pos=site.center;sim.clock+=1.;game.session.refresh();game.update_battle_camera(p,1.,true);await frame()
	check(panel.visible and panel.heading.text=="열린 지름길" and panel.first.text.contains("회수"),"inside passage offers individual reward")
	await capture("treasure")
	panel.first.pressed.emit();await frame();check(not panel.visible and p.materials.essence==3,"claim hides completed reward panel")
	var route=Shortcuts.navigation(sim.map).get_point_path(Vector2i(p.pos),Vector2i(site.forward_exit))
	for point in route:
		for step in range(16):p.pos=sim.map.move(p.pos,(point-p.pos).limit_length(.12))
		sim.clock+=.1;game.refresh_vision()
	game.session.refresh();game.update_battle_camera(p,1.,true);await frame()
	check(p.pos.distance_to(site.forward_exit)<.2 and not panel.visible,"walk onward through discovered shortcut after looting")
	check(game.vision.discovered(site.center) and game.vision.sees(site.forward_exit),"minimap remembers traversed passage and lights current exit")
	await capture("forward-exit")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("EXPLORATION_SHORTCUTS_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
