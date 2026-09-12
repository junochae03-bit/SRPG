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
func frame()->Image:
	game.queue_redraw();game.map_overlay.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func sample(image:Image,pos:Vector2)->Color:
	var point=(root.canvas_transform*game.world_point(pos))*Vector2(1.2,1.2)
	return image.get_pixelv(Vector2i(point))
func difference(a:Color,b:Color)->float:return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/vision-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	var sim=Sim.new(751,"cave",12);sim.enemies.clear()
	sim.map.floor_cells.clear()
	for x in range(1,31):
		for y in range(1,31):sim.map.floor_cells[Vector2i(x,y)]=true
	sim.map.exploration_sites=[];sim.map.hidden_regions=[];sim.map.spawn=Vector2(12,12)
	var p=sim.add_player(1,"시야 확인");p.pos=Vector2(12,12)
	game.session.sim=sim;game.session.refresh();game.on_entered();game.world_zoom=1.;root.canvas_transform=Transform2D.IDENTITY
	game.refresh_vision();game.forest.update_camera(1.)
	var baseline=await frame()
	check(game.map_overlay.static_map.floor_points.size()>0 and game.map_overlay.static_map.floor_points.size()<sim.map.floor_cells.size(),"undiscovered map absent in actual minimap")
	var line=Attacks.area("line",p.pos+Vector2(5,0),p.pos+Vector2(11,0),.65)
	game.session.state.enemy_attacks=[line]
	var with_line=await frame()
	check(difference(sample(baseline,p.pos+Vector2(7,0)),sample(with_line,p.pos+Vector2(7,0)))>.03,"line visible portion drawn even with hidden end")
	check(difference(sample(baseline,p.pos+Vector2(10,0)),sample(with_line,p.pos+Vector2(10,0)))<.01,"line hidden portion clipped per pixel")
	game.session.state.enemy_attacks=[Attacks.area("circle",p.pos,p.pos+Vector2(10,0),3.)]
	var with_circle=await frame()
	check(difference(sample(baseline,p.pos+Vector2(7.5,0)),sample(with_circle,p.pos+Vector2(7.5,0)))>.03,"circle visible rim drawn even with hidden center")
	check(difference(sample(baseline,p.pos+Vector2(10,0)),sample(with_circle,p.pos+Vector2(10,0)))<.01,"hidden circle center remains concealed")
	check(with_line.save_png(ProjectSettings.globalize_path("res://../artifacts/dungeon-vision-telegraph.png"))==OK,"telegraph screenshot")
	game.session.state.enemy_attacks=[]
	var legacy=sim.spawn_enemy("warden",p.pos+Vector2(10,0),1,true);legacy.raid=false;legacy.windup=1.;legacy.attack_pos=p.pos+Vector2(8,0)
	game.session.refresh()
	var legacy_image=await frame()
	check(difference(sample(baseline,p.pos+Vector2(7,0)),sample(legacy_image,p.pos+Vector2(7,0)))>.03,"legacy boss telegraph visible with hidden caster")
	check(difference(sample(baseline,p.pos+Vector2(9,0)),sample(legacy_image,p.pos+Vector2(9,0)))<.01,"legacy boss hidden portion clipped")
	sim.enemies.clear()
	var old=p.pos;p.pos+=Vector2(11,0);game.session.refresh();game.visual_time=1.;game.refresh_vision()
	game.visual_time=3.;game.refresh_vision();game.update_battle_camera(p,1.,true);game.refresh_vision();game.forest.update_camera(1.)
	var memory=await frame()
	check(game.vision.discovered(old) and not game.vision.sees(old),"left area retains dim memory")
	check(memory.save_png(ProjectSettings.globalize_path("res://../artifacts/dungeon-vision-memory.png"))==OK,"memory screenshot")
	var builds=game.map_overlay.static_builds;await frame();check(game.map_overlay.static_builds==builds,"settled minimap not rebuilt every frame")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("DUNGEON_VISION_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
