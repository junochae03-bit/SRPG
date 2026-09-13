extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Motion=preload("res://scripts/skill_motion_art_v06.gd")
const Objects=preload("res://scripts/exploration_object_art_v06.gd")
var checks=0
var failures=[]
var game
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize():run.call_deferred()
func render():
	game.session.refresh();game._process(.1);game.hud.refresh();game.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await render()
	check(root.get_texture().get_image().save_png("res://../artifacts/"+name+".png")==OK,"GPU screenshot "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/agent-art-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	var sim=Sim.new(941,"cave",12);sim.enemies.clear()
	var p=sim.add_player(1,"별하");p.pos=Vector2(sim.map.rooms[1]);p.aim=Vector2.RIGHT;p.level=100
	var other=sim.add_player(2,"이룸");other.class_id="ranger";other.pos=p.pos+Vector2(-1,1);sim.combat.initialize(other)
	var enemy=sim.spawn_enemy("spider",p.pos+Vector2(2,0),20);enemy.hp=100000;enemy.max_hp=100000;enemy.speed=0.;enemy.cooldown=1000.
	game.session.sim=sim;game.session.refresh();game.on_entered();game.update_battle_camera(p,0.,true)
	p.skill_ranks={"whirlwind":1};p.skill_loadout={"skill_q":"whirlwind"};p.stamina=1000.
	check(sim.action(1,"skill_q"),"actual cast on real map")
	game.session.flush_events()
	await capture("agent-art-v06-combat")
	check(not game.skill_atlas.commands.is_empty(),"real event reaches additive atlas layer")
	check(game.skill_atlas.z_index<game.visible_telegraphs.z_index,"enemy ground warning above decorative atlas")
	check(game.skill_atlas.material.get_shader_parameter("enabled")==game.vision.active,"actual per-pixel sight mask enabled")
	check(Motion.selection(p).get("phase",-1)==2,"actual integrated hero release")
	check(game.monster_aim_frames.has(enemy.id),"new monster body registered for targeting")
	# Personal snapshots change the object state without moving it or granting loot.
	var site={"id":"fixture","generation":"941.cave.12","kind":"gather","material":"ore","claimed":false}
	var full=Objects.frame(site,"cave",12);site.claimed=true;var empty=Objects.frame(site,"cave",12)
	check(not full.is_empty() and not empty.is_empty() and full.id==empty.id and full.state!=empty.state,"claim changes state on same authored object")
	check(full.foot==empty.foot or full.height==empty.height,"depletion retains world anchor scale")
	# No stale draw commands survive an empty frame or session departure.
	game.effects.clear();sim.combat.projectiles.clear();await render()
	check(game.skill_atlas.commands.is_empty(),"empty frame clears previous effect commands")
	var Capture=preload("res://scripts/export_capture_v052.gd")
	var before=sim.persistent(p.id).duplicate(true);p.pos=sim.map.spawn
	game.options["capture-view"]="encounter";game.options["capture"]="unused-test-capture"
	var isolated=game.options["save-dir"];game.options.erase("save-dir")
	Capture.prepare(game)
	check(p.pos==sim.map.spawn,"capture relocation requires explicitly isolated save directory")
	game.options["save-dir"]=isolated
	for role in ["host","client"]:
		game.session.network_role=role;Capture.prepare(game)
		check(p.pos==sim.map.spawn,"capture does not relocate cooperative "+role)
	game.session.network_role="offline";Capture.prepare(game)
	check(p.pos==Vector2(sim.map.rooms[1]) and sim.map.walkable(p.pos),"isolated encounter observer placed on walkable room floor")
	check(game.vision.active and game.vision.sees(enemy.pos),"capture retains actual observer sight and sees nearby monster")
	check(sim.persistent(p.id)==before,"capture relocation does not change possessions or progression")
	game.options.erase("capture");game.options.erase("capture-view")
	game.session.disconnect_game();await render()
	check(game.skill_atlas.commands.is_empty(),"disconnect removes atlas commands")
	game.stop_audio();game.queue_free();await process_frame;await process_frame
	print("AGENT_ART_INTEGRATION_VISUAL checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
