extends SceneTree
const Hidden=preload("res://scripts/hidden_rooms.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func capture(name:String):
	game.hud.refresh();game.forest.update_camera();game.queue_redraw();game.map_overlay.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../artifacts/hidden-room-"+name+".png")==OK,"capture "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/hidden-rooms-visual/"+str(Time.get_ticks_usec()));root.add_child(game)
	await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var session=game.session;session.sim=preload("res://scripts/simulation.gd").new(123,"cave",12)
	var p=session.sim.add_player(1,"비밀방 탐사");p.level=100;p.materials.tool=1;p.tutorial_done=true;session.sim.recalculate(p);p.hp=p.max_hp
	for e in session.sim.enemies.values():e.hp=0
	session.refresh();game.on_entered()
	var site=session.sim.map.hidden_regions[1];p.pos=site.pos;Hidden.discover(session.sim);session.refresh();game.update_battle_camera(p,1.,true)
	game.exploration_panel._process(0)
	check(game.exploration_panel.visible and game.exploration_panel.first.text.contains("도구"),"tool opening visible in interaction panel")
	await capture("sealed")
	var original=game.forest.map_revision;game.exploration_panel.first.pressed.emit();await process_frame
	check(session.sim.map.opened_regions.has(site.id) and p.materials.tool==0,"visible opening button spends actual tool")
	check(game.forest.map_revision>original,"ground mask rebuilt after opening")
	p.pos=site.center;session.refresh();game.update_battle_camera(p,1.,true);game.exploration_panel._process(0)
	check(game.exploration_panel.first.text.contains("회수"),"opened chamber displays personal reward action")
	await capture("opened")
	game.exploration_panel.first.pressed.emit();await process_frame;game.exploration_panel._process(0)
	check(p.materials.essence==4 and not game.exploration_panel.visible,"claim closes completed interaction")
	check(preload("res://scripts/icon_library.gd").audit().unknown_requests.is_empty(),"all hidden room icons exist")
	check(await game.audio_director.shutdown(),"audio drained")
	session.connected=false;game.queue_free();await process_frame;await process_frame
	print("HIDDEN_ROOMS_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
