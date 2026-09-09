extends SceneTree
const Dungeon=preload("res://scripts/dungeon.gd")
func _initialize():run.call_deferred()
func capture(name:String):
	await create_timer(.3).timeout;await process_frame;await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../artifacts/jobs-"+name+".png")
	assert(root.get_texture().get_image().save_png(path)==OK);print("CAPTURE ",path)
func run():
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	game.session.save_directory=ProjectSettings.globalize_path("res://../runtime/visual-jobs/"+str(Time.get_ticks_usec()));game.join_game();game.session.set_physics_process(false);game.set_physics_process(false)
	var p=game.session.sim.players[1];p.level=100;p.class_id="breaker";game.session.sim.combat.jobs.reset(p)
	for i in range(6):p.skill_ranks["breaker_a%02d"%(i+1)]=3;p.skill_loadout[preload("res://scripts/content.gd").ACTIONS[i]]="breaker_a%02d"%(i+1)
	game.session.refresh();game.toggle_skills();await capture("tree");game.toggle_skills()
	for entry in [["healer","healer_a01"],["healer","healer_a01_upgrade"],["breaker","breaker_p02"]]:
		p.class_id=entry[0];p.max_hp=890;p.hp=480;p.skill_ranks={entry[0]+"_a01":3};p.skill_loadout={"skill_q":entry[0]+"_a01"};game.session.sim.combat.jobs.reset(p);game.session.refresh()
		game.toggle_skills();game.skill_tree.choice=entry[1];game.skill_tree.refresh(true);await capture(entry[1]);game.toggle_skills()
	game.session.travel("forest");p=game.session.sim.players[1];p.pos=Vector2(game.session.sim.map.rooms[1]);game.camera_pos=Dungeon.iso(p.pos);p.aim=Vector2.RIGHT
	for cls in ["tank","swordsman","runesword","elementalist","healer","sniper","hunter","explorer","breaker","infighter","martialist","thief","reaper","gambler","summoner"]:
		p.class_id=cls;game.session.sim.combat.jobs.reset(p);p.motion_time=0.;p.dir=Vector2.ZERO;p.skill_ranks={};p.skill_loadout={}
		for i in range(6):var id=cls+"_a%02d"%(i+1);p.skill_ranks[id]=1;p.skill_loadout[preload("res://scripts/content.gd").ACTIONS[i]]=id
		if cls=="runesword":p.job_state.runes=4
		if cls=="breaker":p.job_state.momentum=65
		if cls=="infighter":p.job_state.rush=7
		if cls=="martialist":p.job_state.combo=2
		game.session.refresh();await capture(cls)
		if cls=="breaker":
			game.session.sim.combat.skills.fx(p,"breaker:1",p.pos,1.,3.);game.session.flush_events();await capture("breaker-effect")
		if cls=="summoner":
			assert(game.session.act("skill_q"));game.session.sim.combat.jobs.tick(p,.1);assert(not p.job_state.pets.is_empty());p.job_state.pets[0].pos=p.pos+Vector2(1.5,-1.5);game.session.refresh();await capture("summoner-pet")
	game.stop_audio();await create_timer(.5).timeout;game.session.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()
