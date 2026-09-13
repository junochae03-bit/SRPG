extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Visual=preload("res://scripts/projectile_visual_v071.gd")
var game
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func render():
	game.session.refresh();game._process(.005);game.hud.refresh();game.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await render()
	check(root.get_texture().get_image().save_png("res://../artifacts/projectile-live-v071-"+name+".png")==OK,"capture "+name)
func run():
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/projectile-live-v071/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	var sim=Sim.new(941,"cave",12);sim.enemies.clear()
	var p=sim.add_player(1,"Projectile");p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT
	var at:Vector2=p.pos+Vector2(3,0)
	check(sim.map.walkable(at) and sim.map.line_clear(p.pos,at),"real cave path clear")
	var enemy=sim.spawn_enemy("spider",at,20);enemy.hp=100000;enemy.max_hp=100000;enemy.speed=0.;enemy.cooldown=1000.
	game.session.sim=sim;game.session.refresh();game.on_entered();game.update_battle_camera(p,0.,true)
	for key in Visual.data().families:
		game.effects.clear();sim.events.clear();sim.combat.projectiles.clear()
		var hp=enemy.hp
		sim.combat.launch(p,"bow",Vector2.RIGHT,37,8,14,0)
		sim.combat.projectiles.back().visual_family=key
		sim.combat.tick_projectiles(.005);game.session.flush_events()
		await capture(key+"-launch")
		check(not game.projectile_visual.commands.is_empty(),"real launch reaches layer "+key)
		game.effects.clear();sim.combat.tick_projectiles(.055);game.session.flush_events()
		await capture(key+"-flight")
		check(not sim.combat.projectiles.is_empty() and not game.projectile_visual.commands.is_empty(),"real flight reaches layer "+key)
		for i in range(30):
			if sim.combat.projectiles.is_empty():break
			sim.combat.tick_projectiles(.01)
		check(sim.events.any(func(e):return e.type=="projectile_impact") and enemy.hp==hp-37,"real collision accepted "+key)
		game.effects.clear();game.session.flush_events()
		for e in game.effects:
			if e.type=="projectile_impact":e.life=e.max_life-.06
		await capture(key+"-impact")
		check(not game.projectile_visual.commands.is_empty(),"accepted event reaches GPU "+key)
	check(game.projectile_visual.z_index<game.visible_telegraphs.z_index,"hostile warning layer above decoration")
	check(game.projectile_visual.impact_layer.z_index==0 and not game.projectile_visual.impact_layer.z_as_relative,"contact flash above monster body")
	check(game.projectile_visual.material.get_shader_parameter("enabled")==game.vision.active,"real sight mask synchronized")
	game.effects.clear();sim.combat.projectiles.clear();await render()
	check(game.projectile_visual.commands.is_empty(),"no stale commands on empty frame")
	# A real floor-cell wall blocks both simulation hits and visibility of a
	# previously accepted contact event still within its short display lifetime.
	var hp=enemy.hp
	var column=int(p.pos.x)+1
	for y in range(int(p.pos.y)-16,int(p.pos.y)+17):sim.map.floor_cells.erase(Vector2i(column,y))
	game.vision.reset();game.refresh_vision()
	sim.events.clear();sim.combat.launch(p,"bow",Vector2.RIGHT,37,8,14,0)
	for i in range(30):sim.combat.tick_projectiles(.02)
	check(enemy.hp==hp and not sim.events.any(func(e):return e.type=="projectile_impact"),"actual wall produces no contact or damage")
	game.session.flush_events();game.effects.clear()
	game.on_event({"type":"projectile_impact","projectile_type":"staff","visual_family":"fire","pos":enemy.pos,"visual_offset":Vector2(0,-70),"duration":.24})
	await capture("wall-hidden-contact")
	check(not game.vision.sees(enemy.pos) and game.projectile_visual.commands.is_empty(),"wall-hidden contact not drawn above fog")
	game.session.disconnect_game();await render()
	check(game.projectile_visual.commands.is_empty(),"no stale commands on disconnect")
	game.stop_audio();game.queue_free();await process_frame;await process_frame
	print("PROJECTILE_LIVE_VISUAL_V071 checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
