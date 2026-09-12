extends SceneTree
const Brief=preload("res://scripts/expedition_brief.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var sim=Sim.new(84,"town",0);var p=sim.add_player(1,"별하");p.level=100;p.highest_floor=100;p.tutorial_done=true
	for floor_id in range(1,101):
		var info=Brief.floor_info(p,floor_id)
		check(info.reason.is_empty() and info.raid==(floor_id%10==0),"floor availability "+str(floor_id))
		check(not info.has("seed") and not info.has("hidden_regions") and not info.has("pos"),"no secret discovery leakage")
		if info.raid:
			check(info.monsters.is_empty() and info.guardian=="raid:%03d"%floor_id,"raid preview links the actual floor boss without absent normal mobs")
			check(not preload("res://scripts/game_database.gd").detail("monsters",info.guardian).is_empty(),"floor boss codex record exists")
		for id in info.monsters:check(preload("res://scripts/world_catalog.gd").ENEMIES.has(id),"known biome enemy "+id)
	p.potions=3;p.materials={"tool":2}
	var supplies=Brief.supplies(p);check(supplies.potions==3 and supplies.tools==2 and supplies.skills==0,"actual personal supplies")
	var other=sim.add_player(7,"친구");other.level=20;other.highest_floor=11;other.tutorial_done=true
	var rows=Brief.party_status(sim.players,{1:true,7:false},12)
	check(rows.size()==2 and not rows[1].ready and not rows[1].reason.is_empty(),"party readiness and unlock evaluated per player")
	other.highest_floor=12;other.down_time=10
	check(Brief.party_status(sim.players,{1:true,7:true},12)[1].reason=="구조 필요","downed teammate cannot depart")
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/brief-visual/"+str(Time.get_ticks_usec()));root.add_child(game)
	await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	game.session.sim=sim;game.session.refresh();game.on_entered();p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.portal.pos;game.session.refresh()
	game.town_panel.open("portal");var town=game.town_panel;town.selected_floor=12;town.chapter=1;town.refresh()
	check(not town.confirm_button.disabled and town.review_panel.summary.text.contains("탐사 도구 2"),"ready solo portal displays actual supplies")
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../artifacts/expedition-brief.png")==OK,"actual departure screen capture")
	var before=game.session.sim.map.floor_number;town.confirm_button.pressed.emit();await process_frame
	check(before==0 and game.session.sim.map.floor_number==12,"actual enter floor button")
	game.session.travel("town");sim=game.session.sim;p=sim.players[1];p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.portal.pos
	for id in range(2,7):
		var friend=sim.add_player(id,"친구 %d"%id);friend.level=100;friend.tutorial_done=true;friend.highest_floor=100
	game.session.network_role="host";game.session.ready_players={1:true,2:false,3:true,4:true,5:false,6:true};game.session.refresh()
	game.town_panel.open("portal");town.selected_floor=20;town.chapter=1;town.refresh();await process_frame
	var panel=town.review_panel
	check(panel.party.visible and panel.party_rows.size()==6,"departure shows six individual party rows")
	for row in panel.party_rows:
		check(row.name.visible and row.status.visible and panel.party.get_rect().size.x>=row.status.get_rect().end.x and panel.party.size.y>=row.status.get_rect().end.y,"every member is visible within party region")
	check(town.confirm_button.disabled and panel.party_rows[1].status.text=="대기","six-player ready state controls departure")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../artifacts/expedition-brief-party.png")==OK,"six-player departure capture")
	game.session.network_role="offline"
	check(preload("res://scripts/icon_library.gd").audit().unknown_requests.is_empty(),"brief icons resolved")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("EXPEDITION_BRIEF checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
