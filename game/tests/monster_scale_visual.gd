extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const World=preload("res://scripts/world_catalog.gd")
const Dungeon=preload("res://scripts/dungeon.gd")
const Aim=preload("res://scripts/monster_aim.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.refresh_vision();game.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/monster-scale-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var results=[]
	for row in [{"floor":12,"kinds":["mole","orc_champion","golem"]},{"floor":62,"kinds":["skeleton","centurion","sentinel"]}]:
		var sim=Sim.new(12321,"cave",row.floor);sim.enemies.clear()
		# A flat comparison stage isolates silhouette and selection from combat.
		sim.map.floor_cells.clear()
		for x in range(4,45):
			for y in range(4,45):sim.map.floor_cells[Vector2i(x,y)]=true
		sim.map.path_cells=sim.map.floor_cells;sim.map.environment.sight=20
		sim.map.exploration_sites=[];sim.map.exploration_cues=[];sim.map.hidden_regions=[];sim.map.ground_remains=[]
		var p=sim.add_player(1,"별하");p.pos=Vector2(16,24);p.level=100;p.tutorial_done=true
		var enemies=[]
		for i in range(row.kinds.size()):enemies.append(sim.spawn_enemy(row.kinds[i],p.pos+Vector2(3.5,-3.5)*(i+1),1,i==2))
		game.session.sim=sim;game.session.refresh();game.on_entered()
		game.world_zoom=1.;root.canvas_transform=Transform2D.IDENTITY
		game.camera_pos=Dungeon.iso(p.pos+Vector2(5.25,-5.25))-Vector2(0,140);game.forest.update_camera(1.);game.hud.refresh()
		await frame()
		for enemy in enemies:
			check(game.monster_aim_frames.has(enemy.id),"actual actor registered "+enemy.kind)
			var entry=game.monster_aim_frames[enemy.id];var rect:Rect2=entry.rect
			var point=entry.transform*(rect.position+rect.size*Vector2(.5,.55))
			var target=Aim.target_at(point,game.session.state.enemies,game.monster_aim_frames,p.pos,sim.map)
			check(target.get("id",0)==enemy.id,"expanded torso can be selected "+enemy.kind)
			results.append({"floor":row.floor,"kind":enemy.kind,"body_height":World.display_height(enemy.kind,row.floor),"rendered_rect":[rect.size.x,rect.size.y]})
		check(root.get_texture().get_image().save_png("res://../artifacts/monster-scale-B%d.png"%row.floor)==OK,"same zoom hero/common/elite/boss framebuffer")
	var file=FileAccess.open("res://../artifacts/monster-scale-visual.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	game.session.connected=false;game.queue_free();await process_frame
	print("MONSTER_SCALE_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
