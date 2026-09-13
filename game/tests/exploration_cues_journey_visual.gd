extends SceneTree
## Controlled input traversal, not a human difficulty or enjoyment assessment.
const Sim=preload("res://scripts/simulation.gd")
const Cues=preload("res://scripts/exploration_cues.gd")
const Navigation=preload("res://scripts/exploration_shortcuts.gd")
var game
var checks=0
var failures=[]
var captures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.session.refresh();game.visual_time=game.session.sim.clock
	game.refresh_vision();game.update_battle_camera(game.session.state.players[1],1.,true);game.forest.update_camera(1.)
	game.hud.refresh();game.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func capture(label:String):
	await frame()
	var p=game.session.state.players[1]
	var traces=[]
	for cue in game.dungeon.exploration_cues:
		if not Cues.visible_marks(game,cue).is_empty():traces.append(cue.trace)
	var sites=[]
	for site in game.dungeon.exploration_sites:
		if game.vision.sees(site.pos):sites.append(site.id)
	var path="res://../artifacts/exploration-journey-"+label+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"actual journey framebuffer "+label)
	captures.append({"frame":label,"pos":[p.pos.x,p.pos.y],"seconds":game.session.sim.clock,"visible_traces":traces,"visible_sites":sites})
func walk(sim,p,target:Vector2):
	var graph=Navigation.navigation(sim.map)
	var path=graph.get_point_path(Vector2i(p.pos.round()),Vector2i(target.round()))
	check(not path.is_empty(),"actual walkable route exists")
	var ticks=0
	for point in path:
		while p.pos.distance_to(point)>.13 and ticks<2400:
			sim.set_input(p.id,p.pos.direction_to(point),p.pos.direction_to(point))
			sim.tick(1./30.);ticks+=1
			if ticks%15==0:await frame()
		if ticks>=2400:break
	sim.set_input(p.id,Vector2.ZERO,Vector2.RIGHT)
	check(p.pos.distance_to(target)<.8,"input movement reaches selected destination without teleport")
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/cues-journey/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var seed_value=571+12*7919
	for branch in [2,3]:
		var sim=Sim.new(seed_value,"cave",12)
		var p=sim.add_player(1,"별하");p.tutorial_done=true;p.invulnerable=999.
		var pair=sim.map.exploration_cues.filter(func(cue):return cue.room in [2,3])
		p.pos=Vector2(sim.map.rooms[1])
		game.session.sim=sim;game.session.refresh();game.on_entered()
		await frame()
		check(pair[0].trace!=pair[1].trace,"same junction presents distinct learned material traces")
		check(not Cues.visible_marks(game,pair[0]).is_empty() and not Cues.visible_marks(game,pair[1]).is_empty(),"both choices visible from same junction")
		var site=sim.map.exploration_sites.filter(func(row):return row.room==branch)[0]
		check(not game.vision.sees(site.pos),"destination is still unknown before choice")
		await capture("branch%d-choice"%branch)
		var cue=pair.filter(func(row):return row.room==branch)[0]
		await walk(sim,p,cue.marks[-1].pos)
		await capture("branch%d-trace"%branch)
		await walk(sim,p,site.pos)
		await capture("branch%d-destination"%branch)
		check(game.vision.sees(site.pos),"selected route reveals corresponding actual destination")
		check(Cues.signature(site).trace==cue.trace,"observed destination matches the material clue")
	var comparison=Sim.new(95600,"cave",12)
	var viewer=comparison.add_player(1,"별하");viewer.pos=Vector2(comparison.map.rooms[4]);viewer.tutorial_done=true
	game.session.sim=comparison;game.session.refresh();game.on_entered();await frame()
	for kind in ["ore","magic"]:
		var cue=comparison.map.exploration_cues.filter(func(row):return row.trace==kind)[0]
		check(not Cues.visible_marks(game,cue).is_empty(),"ore and purple rune shards visible at same junction: "+kind)
	await capture("magic-comparison")
	var report={"scope":"same junction, two alternative controlled input journeys with live AI; invulnerable fixture, no difficulty or fun claim","seed":seed_value,"floor":12,"captures":captures}
	var file=FileAccess.open("res://../artifacts/exploration-journey.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	game.session.connected=false;game.queue_free();await process_frame
	print("EXPLORATION_CUES_JOURNEY_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
