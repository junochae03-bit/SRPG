extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Cues=preload("res://scripts/exploration_cues.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.session.refresh();game.hud.refresh();game.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/cues-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	for trace in ["ore","herbs","tracks"]:
		var sim=Sim.new(571+12*7919,"forest" if trace=="herbs" else "cave",12)
		var p=sim.add_player(1,"별하");p.level=100;p.tutorial_done=true
		var cue=sim.map.exploration_cues.filter(func(row):return row.trace==trace)[0]
		p.pos=cue.pos-cue.direction*2.+cue.direction.orthogonal()*1.8
		if not sim.map.walkable(p.pos):p.pos=cue.pos-cue.direction
		game.session.sim=sim;game.session.refresh();game.on_entered();game.update_battle_camera(p,1.,true);game.forest.update_camera(1.)
		await frame()
		check(Cues.visible_marks(game,cue).size()>=2,"several ground marks visible at branch "+trace)
		for old in ["광석 조각","떨어진 씨앗","깊게 패인 발자국"]:check(not game.visible_world_labels.has(old),"no explanatory caption "+old)
		check(root.get_texture().get_image().save_png("res://../artifacts/exploration-cues-"+trace+".png")==OK,"actual framebuffer "+trace)
		var end=cue.marks[-1]
		for mark in cue.marks:check(sim.map.walkable(mark.pos),"visible trace follows walkable ground")
		p.pos=end.pos;game.session.refresh();game.vision.update(sim.map,game.session.state.players,sim.clock+1.)
		check(game.vision.sees(end.pos),"moving forward reveals next local trace")
	game.session.connected=false;game.queue_free();await process_frame
	print("EXPLORATION_CUES_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
