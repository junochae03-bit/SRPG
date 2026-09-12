extends SceneTree
const S=preload("res://scripts/boss_stagger.gd")
var checks=0
var failures=[]
func _initialize():
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func capture(name:String):
	await create_timer(.15).timeout;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/v03-stagger-"+name+".png"))==OK,"capture "+name)
func run():
	# Full HD client area, independent of desktop title-bar constraints.
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;root.add_child(game);await process_frame
	var local=game.session;local.save_directory=ProjectSettings.globalize_path("res://../runtime/stagger-ui-v03/"+str(Time.get_ticks_usec()));game.join_game();local.set_physics_process(false);game.set_physics_process(false)
	var p=local.sim.players[1];p.level=100;p.tutorial_done=true;p.highest_floor=100;p.cleared_floor=99
	p.stats={"strength":90,"endurance":87,"technique":60,"agility":60,"magic":0};p.skill_ranks={"blade_wave":1};local.sim.recalculate(p);local.travel("town");local.refresh()
	game.toggle_skills();game.skill_tree.choice="blade_wave";game.skill_tree.refresh(true)
	var rows=game.skill_tree.comparison_rows.filter(func(row):return row[0]=="시전당 무력화")
	check(rows.size()==1,"learned active has stagger comparison")
	check(float(rows[0][2])>float(rows[0][1]),"next rank strengthens stagger")
	check(game.skill_tree.comparison_scroll.get_rect().end.y<game.skill_tree.prerequisites.position.y,"long skill details scroll within their frame")
	await capture("skill");game.skill_tree.mode="stats";game.skill_tree.refresh(true);await capture("stats");game.toggle_skills()
	check(local.enter_floor(100),"raid entry")
	p=local.sim.players[1];var boss=local.sim.enemies.values().filter(func(e):return e.get("guardian",false))[0]
	p.pos=boss.pos-Vector2(1.7,0);p.aim=Vector2.RIGHT;boss.hp=roundi(boss.max_hp*.69);S.initialize(boss,local.sim.clock)
	game.camera_pos=preload("res://scripts/dungeon.gd").iso(p.pos);game.battle_anchor_y=590
	for state in ["ready","check","down","immune"]:
		boss.stagger.state=state;boss.stagger.value=boss.stagger.max_value*.64;boss.stagger.check_value=boss.stagger.check_max*.7
		boss.stagger.time_left=8.3 if state=="check" else 58.3 if state=="immune" else 2.8
		boss.stagger.time_max=12. if state=="check" else S.DOWN_SECONDS if state=="down" else S.IMMUNITY_SECONDS
		local.refresh();await process_frame;await process_frame
		check(game.hud.boss_hud.visible,"boss HUD visible: "+state);check(game.hud.boss_hud.boss.get("stagger",{}).get("state","")==state,"HUD reads simulation state: "+state)
		var before=JSON.stringify(boss.stagger);await capture(state);check(before==JSON.stringify(boss.stagger),"render never mutates stagger state: "+state)
	game.toggle_codex("monsters");await process_frame;await process_frame;check(not game.hud.boss_hud.visible,"codex hides boss HUD")
	var before=JSON.stringify(boss.stagger);await create_timer(.2).timeout;check(before==JSON.stringify(boss.stagger),"paused codex keeps stagger clock")
	game.codex.close();await process_frame;await process_frame;check(game.hud.boss_hud.visible,"closing codex restores boss HUD")
	game.stop_audio();local.disconnect_game();game.queue_free();await process_frame
	print("STAGGER_UI_V03_TESTS checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
