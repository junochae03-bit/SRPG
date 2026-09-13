extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Guard=preload("res://scripts/enemy_defense.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
var game
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func frame(name:String):
	game.session.refresh();game.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../artifacts/enemy-defense-"+name+".png")==OK,"actual framebuffer "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/enemy-defense-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var sim=Sim.new(613,"cave",62);sim.enemies.clear();var center=Vector2(sim.map.rooms[1])
	var p=sim.add_player(1,"별하");p.pos=center;p.tutorial_done=true;p.invulnerable=1000.
	for index in range(3):
		var kind=["beetle","clockwork","centurion"][index]
		var enemy=sim.spawn_enemy(kind,center+Vector2(-3+index*3,2),62);enemy.hp=100000;enemy.max_hp=100000;enemy.speed=0.;enemy.cooldown=1000.
	game.session.sim=sim;game.session.refresh();game.on_entered();game.update_battle_camera(p,1.,true);game.forest.update_camera(1.);game.hud.refresh()
	await frame("intact")
	for enemy in sim.enemies.values():Guard.factor(sim,enemy,Stagger.context(Stagger.basic_token(true,1.,sim.clock)))
	check(sim.enemies[2].guard_layers==1 and sim.enemies[1].guard_pressure>0,"partially damaged defense states")
	await frame("damaged")
	for enemy in sim.enemies.values():Guard.factor(sim,enemy,Stagger.context(Stagger.basic_token(true,1.,sim.clock)))
	check(sim.enemies.values().all(func(enemy):return Guard.exposed(enemy)),"all defense profiles expose after counter")
	for event in sim.events:
		if event.get("fx","")=="guard_break":
			game.on_event(event.duplicate(true));game.effects.back().life=.2
	await frame("broken")
	game.inspection_panel.set_process(false);game.inspection_panel.show();game.inspection_panel.present(sim.enemies[2])
	await frame("inspection")
	check(game.inspection_panel.defense.text.contains("연속 타격"),"inspection shows matching counter")
	game.session.connected=false;game.queue_free();await process_frame
	print("ENEMY_DEFENSE_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
