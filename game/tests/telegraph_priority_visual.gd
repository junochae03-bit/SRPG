extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Attacks=preload("res://scripts/monster_attacks.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.refresh_vision();game.visible_telegraphs._process(0.);game.danger_hud._process(0.)
	game.queue_redraw();game.hud.refresh()
	await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await frame()
	check(root.get_texture().get_image().save_png("res://../artifacts/"+name+".png")==OK,"captured "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/telegraph-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	var sim=Sim.new(31,"cave",12);sim.enemies.clear();sim.map.floor_cells.clear()
	for x in range(18,43):
		for y in range(18,43):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"별하");p.pos=Vector2(30,30);p.level=100;p.tutorial_done=true;sim.recalculate(p)
	var source=p.pos+Vector2(-4.5,4.5)
	var e=sim.spawn_enemy("orc_axeman",source,12);e.windup=.6;e.attack_areas=[Attacks.area("line",source,p.pos,.6)]
	game.session.sim=sim;game.session.refresh();game.on_entered()
	game.camera_pos=game.Dungeon.iso(p.pos)
	root.canvas_transform=Transform2D(0,Vector2(250,450)-game.world_point(p.pos))
	await frame()
	check(game.vision.sees(e.pos),"off-camera source remains in current party sight")
	check(game.danger_hud.visible and game.danger_hud.warnings.size()==1,"real HUD shows offscreen direction")
	if not game.danger_hud.warnings.is_empty():
		var warning=game.danger_hud.warnings[0]
		check(warning.direction.x<0 and absf(warning.direction.y)<.01,"actual isometric transform points toward left attacker")
		var rect=Rect2(warning.point-Vector2(24,24),Vector2(48,70))
		check(not game.hud.world_label_regions().any(func(region):return region.intersects(rect)),"rendered edge marker avoids HUD")
	await capture("telegraph-offscreen-direction")
	game.session.paused=true;game.danger_hud._process(0.);check(not game.danger_hud.visible,"modal hides personal direction warning")
	game.session.paused=false
	root.canvas_transform=Transform2D.IDENTITY
	game.camera_pos=game.Dungeon.iso(p.pos)
	for id in range(2,7):
		var ally=sim.add_player(id,"동료 %d"%id);ally.pos=p.pos+Vector2(id%3-1,2+id/3.)
	for id in range(6):
		var enemy=sim.spawn_enemy("orc_axeman",p.pos+Vector2(3,id*.2),12)
		enemy.windup=.8;enemy.attack_areas=[Attacks.area("circle",enemy.pos,p.pos,2.5)]
	var ring=Attacks.area("ring",p.pos+Vector2(4,0),p.pos+Vector2(2,1),3.5);ring.inner=1.6
	ring.enemy=e.id;ring.timer=.4
	sim.monster_attacks.zones=[ring]
	game.session.refresh();await frame()
	check(game.visible_telegraphs.records.any(func(record):return record.count==6),"six overlapping casts merge visually")
	check(game.visible_telegraphs.records.filter(func(record):return record.fill).size()<=4,"rendered fill count stays bounded")
	check(game.visible_telegraphs.records[-1].priority==2,"personal warning drawn last")
	check(not game.danger_hud.visible,"onscreen attackers do not create edge arrows")
	await capture("telegraph-six-player-overlap")
	var start=Time.get_ticks_usec()
	for sample in range(120):game.visible_telegraphs._process(0.)
	print("TELEGRAPH_PRESENTATION_MEAN_US ",float(Time.get_ticks_usec()-start)/120.)
	for enemy in sim.enemies.values():enemy.hp=0
	sim.monster_attacks.zones=[];game.session.refresh();await frame()
	check(game.visible_telegraphs.records.is_empty() and not game.danger_hud.visible,"finished combat clears all active previews")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("TELEGRAPH_PRIORITY_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
