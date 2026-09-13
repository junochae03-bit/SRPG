extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Remains=preload("res://scripts/cave_remains.gd")
const Visibility=preload("res://scripts/actor_visibility.gd")
const Attacks=preload("res://scripts/monster_attacks.gd")
class Opaque extends "res://scripts/actor_visibility.gd":
	func opacity(_id:int,_bounds:Rect2)->float:return 1.
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame()->Image:
	game.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/actor-visibility/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var sim=Sim.new(491549,"cave",62);var p=sim.add_player(1,"별하");p.level=100;p.tutorial_done=true
	var rows=Remains.generate(sim.map)
	rows.sort_custom(func(a,b):
		var da=INF;var db=INF
		for enemy in sim.enemies.values():
			da=minf(da,a.pos.distance_to(enemy.pos));db=minf(db,b.pos.distance_to(enemy.pos))
		return da>db)
	var row=rows[0];p.pos=Vector2(sim.map.rooms[row.room]).lerp(row.pos,.6).round()
	if not sim.map.walkable(p.pos):p.pos=row.pos+Vector2.LEFT
	game.session.sim=sim;game.session.refresh();game.on_entered();game.update_battle_camera(p,1.,true);game.forest.update_camera(1.);game.hud.refresh()
	game.actor_visibility=Opaque.new();var before=await frame()
	check(before.save_png("res://../artifacts/player-occlusion-before-B62.png")==OK,"exact reported cover position before")
	game.actor_visibility=Visibility.new();var after=await frame()
	check(after.save_png("res://../artifacts/player-occlusion-after-B62.png")==OK,"same position after")
	var faded=[]
	for id in game.actor_visibility.alphas:
		if game.actor_visibility.alphas[id]<1.:faded.append(id)
	check(not faded.is_empty(),"actual foreground monster becomes translucent")
	var point=Vector2i((root.canvas_transform*game.world_point(p.pos-Vector2.ZERO))*1.2-Vector2(0,65))
	var difference=0.
	for x in range(-20,21):
		for y in range(-35,36):
			var a=before.get_pixelv(point+Vector2i(x,y));var b=after.get_pixelv(point+Vector2i(x,y))
			difference+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
	check(difference>50.,"actual framebuffer reveals the player body under cover")
	var attack=Attacks.area("circle",p.pos,p.pos,3.)
	attack.enemy=faded[0] if not faded.is_empty() else 0;attack.timer=.5
	game.session.state.enemy_attacks=[attack]
	var warned=await frame()
	check(warned.save_png("res://../artifacts/player-occlusion-telegraph-B62.png")==OK,"warning remains visible with covering monster")
	check(not game.monster_aim_frames.is_empty(),"transparent enemies retain actual selection geometry")
	game.session.connected=false;game.queue_free();await process_frame
	print("ACTOR_VISIBILITY_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
