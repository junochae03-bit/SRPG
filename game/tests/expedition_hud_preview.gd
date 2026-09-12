extends SceneTree
const Content=preload("res://scripts/content.gd")
var game
func _initialize():run.call_deferred()
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/expedition-hud-preview/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	var session=game.session;session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	var config=preload("res://scripts/abyss_catalog.gd").config(12)
	session.sim=preload("res://scripts/simulation.gd").new(95599,config.terrain,12)
	var p=session.sim.add_player(1,"별하");p.level=100;p.tutorial_done=true;p.highest_floor=100;p.cleared_floor=99
	p.class_id="runesword";session.sim.recalculate(p);p.hp=int(p.max_hp*.76);p.job_state.runes=4
	var actives=Content.SKILLS.runesword.filter(func(n):return n.effect=="active")
	for i in range(6):p.skill_ranks[actives[i].id]=3;p.skill_loadout[Content.ACTIONS[i]]=actives[i].id
	p.skill_cooldowns[actives[0].id]=4.2
	for i in range(5):
		var friend=session.sim.add_player(i+2,["여울","솔","아린","다온","루미"][i]);friend.level=100;friend.class_id=["ranger","mage","rogue","fighter","warrior"][i];session.sim.recalculate(friend)
		friend.pos=p.pos+Vector2((i%3)*1.5+1,(i/3)*1.5+1);friend.hp=roundi(friend.max_hp*(.4+i*.12))
		friend.stamina=friend.max_stamina*(.35+i*.13);friend.job_state.buffs={"attack":{"time":12.,"value":.1},"haste":{"time":8.,"value":.1}}
	session.refresh();game.on_entered();game.update_battle_camera(p,1.,true);game.forest.update_camera(1.)
	game.hud.refresh();game.queue_redraw();game.map_overlay.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../artifacts/expedition-hud-party-layout.png")
	var err=root.get_texture().get_image().save_png(path);print("HUD_PREVIEW ",path," ",error_string(err))
	await game.audio_director.shutdown();session.connected=false;game.queue_free();await process_frame;await process_frame;quit(0 if err==OK else 1)
