extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var game
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func frame(name:String):
	game.session.refresh();game.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../artifacts/enemy-support-"+name+".png")==OK,"actual framebuffer "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/enemy-support-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var sim=Sim.new(91322,"cave",22);sim.enemies.clear()
	var center=Vector2(sim.map.rooms[1]);var p=sim.add_player(1,"별하");p.level=100;p.tutorial_done=true;p.pos=center+Vector2(0,-4);p.invulnerable=1000.
	var healer=sim.spawn_enemy("goblin_shaman",center+Vector2(-2,0),22);healer.ability_cd=0.;healer.cooldown=100.;healer.encounter_room=4
	var ally=sim.spawn_enemy("skeleton",center+Vector2(1,0),22);ally.hp=roundi(ally.max_hp*.4);ally.stun_time=100.;ally.encounter_room=4
	game.session.sim=sim;game.session.refresh();game.on_entered();game.update_battle_camera(p,1.,true);game.forest.update_camera(1.);game.hud.refresh()
	sim.tick(.05);sim.tick(.4)
	check(healer.has("support_cast") and sim.map.line_clear(healer.pos,p.pos),"actual AI reaches visible healing windup")
	await frame("casting")
	healer.stun_time=.4;sim.tick(.05)
	check(not healer.has("support_cast"),"actual stun cancels displayed cast")
	await frame("interrupted")
	game.session.connected=false;game.queue_free();await process_frame
	print("ENEMY_SUPPORT_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
