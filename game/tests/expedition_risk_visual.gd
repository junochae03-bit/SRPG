extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Risk=preload("res://scripts/expedition_risk.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.session.refresh();game.refresh_vision();game.hud.refresh();game.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await frame();check(root.get_texture().get_image().save_png("res://../artifacts/"+name+".png")==OK,"captured "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/risk-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game();game.session.set_physics_process(false);game.set_process(false);game.set_physics_process(false)
	var sim=Sim.new(741,"town");var p=sim.add_player(1,"별하");p.level=100;p.highest_floor=100;p.tutorial_done=true
	p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.portal.pos
	game.session.sim=sim;game.session.refresh();game.on_entered();game.town_panel.open("portal")
	var town=game.town_panel
	for depth in [1,12,31,61,100]:
		town.selected_floor=depth;town.chapter=int((depth-1)/10);town.refresh();await frame()
		for rank in range(4):check(town.risk_buttons[rank].disabled==(rank>Risk.cap(depth)),"region-specific buttons B%d rank%d"%[depth,rank])
		for card in town.products.values():
			check(card.get_rect().end.y<=town.body.size.y,"floor cards fit body")
			var labels=card.get_children().filter(func(child):return child is Label)
			for a in labels:
				check(a.get_visible_line_count()>0,"floor label actually renders a text line")
				check(a.get_rect().end.y<=card.size.y and a.get_rect().position.y>=6,"floor text clears border")
				for b in labels:
					if a!=b:check(not a.get_rect().intersects(b.get_rect()),"floor labels never overlap")
	town.selected_floor=61;town.chapter=6;town.refresh();town.risk_buttons[3].pressed.emit();await frame()
	check(sim.departure_plan.floor==61 and sim.departure_plan.risk==3,"risk button changes authoritative plan")
	check(town.preview.result.contains("정수 +6"),"visible reward matches risk")
	await capture("expedition-risk-choice")
	for id in range(2,7):
		var friend=sim.add_player(id,"동료 %d"%id);friend.level=100;friend.highest_floor=100;friend.tutorial_done=true
	game.session.network_role="host";game.session.ready_players={1:true,2:true,3:true,4:true,5:true,6:true};game.session.refresh()
	town.risk_buttons[2].pressed.emit();await frame()
	check(game.session.ready_players.values().all(func(ready):return not ready) and town.confirm_button.disabled,"risk change visibly clears six-person readiness")
	await capture("expedition-risk-party")
	town.hide();game.coop_panel.open();await frame()
	check(game.coop_panel.information.text.contains("험지") and game.coop_panel.information.text.contains("증원 4마리") and game.coop_panel.information.text.contains("정수 +4"),"separate party window shows conditions before ready")
	check(game.coop_panel.information.get_visible_line_count()==3 and game.coop_panel.information.get_rect().end.y<game.coop_panel.ready_button.position.y,"party condition lines fit above readiness")
	await capture("expedition-risk-room")
	game.coop_panel.close();town.show()
	# A guest mirror follows the host's selected floor and cannot edit risk.
	game.session.network_role="client";game.session.local_id=2;game.session.refresh();town.refresh();await frame()
	check(town.risk_buttons.all(func(button):return button.disabled),"guest sees risk but cannot edit")
	sim.departure_plan={"floor":31,"risk":1,"revision":sim.departure_plan.revision+1};game.session.refresh();town._process(0.);await frame()
	check(town.selected_floor==31 and town.chapter==3,"open guest portal follows changed host proposal")
	game.session.network_role="offline";game.session.local_id=1;sim.players={1:p};sim.departure_plan={"floor":61,"risk":3,"revision":99};game.session.refresh()
	town.selected_floor=61;town.chapter=6;town.refresh();town.confirm_button.pressed.emit();await frame()
	check(game.session.sim.map.floor_number==61 and game.session.sim.map.risk_level==3 and game.session.sim.enemies.size()==29,"confirmed portal creates chosen risk expedition")
	check(game.hud.region.text.contains("극한"),"in-game region identifies active risk")
	var map=game.session.sim.map
	game.session.sim.players[1].pos=Vector2(map.rooms[7])+Vector2(-5,-2);game.session.refresh();game.camera_pos=game.Dungeon.iso(game.session.sim.players[1].pos)
	await capture("expedition-risk-encounter")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("EXPEDITION_RISK_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
