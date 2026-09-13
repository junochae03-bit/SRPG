extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Remains=preload("res://scripts/cave_remains.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/cave-remains-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var captures=[]
	for depth in [12,42,62]:
		var sim=Sim.new(571+depth*7919,"cave",depth)
		var p=sim.add_player(1,"별하");p.level=100;p.tutorial_done=true
		var rows=Remains.generate(sim.map)
		check(not rows.is_empty(),"actual generated remains on B%d"%depth)
		# Use an unobscured naturally generated cluster for visual inspection.
		rows.sort_custom(func(a,b):
			var da=INF;var db=INF
			for enemy in sim.enemies.values():
				da=minf(da,a.pos.distance_to(enemy.pos));db=minf(db,b.pos.distance_to(enemy.pos))
			return da>db)
		var row=rows[0];p.pos=Vector2(sim.map.rooms[row.room]).lerp(row.pos,.6).round()
		if not sim.map.walkable(p.pos):p.pos=row.pos+Vector2.LEFT
		game.session.sim=sim;game.session.refresh();game.on_entered();game.update_battle_camera(p,1.,true);game.forest.update_camera(1.)
		game.hud.refresh();game.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
		check(Remains.visible(game,game.forest.remains).has(row),"generated remains visible in actual scene")
		var path="res://../artifacts/cave-remains-B%d.png"%depth
		check(root.get_texture().get_image().save_png(path)==OK,"actual framebuffer saved")
		captures.append({"floor":depth,"seed":sim.map.seed_value,"pos":[row.pos.x,row.pos.y],"kind":row.kind,"clusters":rows.size(),"props":game.forest.props.size(),"path":path})
		var stored=game.forest.remains.duplicate(true)
		for region in sim.map.hidden_regions:preload("res://scripts/hidden_rooms.gd").open(sim.map,region.id)
		game.forest.rebuild(sim.map)
		check(game.forest.remains==stored,"render rebuild preserves existing remains after passages open")
	var evidence=FileAccess.open("res://../artifacts/cave-remains-visual.json",FileAccess.WRITE);evidence.store_string(JSON.stringify(captures,"\t"));evidence.close()
	game.session.connected=false;game.queue_free();await process_frame
	print("CAVE_REMAINS_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
