extends SceneTree
const Journal=preload("res://scripts/expedition_journal.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
class FailingSession extends "res://scripts/coop_session.gd":
	var blocked=false
	func write_save(data:Dictionary,path:String)->bool:
		return false if blocked else super.write_save(data,path)
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run():
	var folder=ProjectSettings.globalize_path("res://../runtime/expedition-journal/"+str(Time.get_ticks_usec()))
	var session=FailingSession.new();session.save_directory=folder;root.add_child(session);session.set_physics_process(false)
	session.start_game("별하",1);session.sim.players[1].tutorial_done=true;session.change_map("town",0)
	check(session.sim.players[1].get("expedition_report",{}).is_empty(),"tutorial excluded")
	var p=session.sim.players[1];p.highest_floor=100;p.level=1;p.xp=200;p.gold=100;p.materials={"ore":5};p.potions=5
	check(session.enter_floor(1),"actual departure")
	p=session.sim.players[1];var first=p.expedition_journal.duplicate(true)
	p.gold+=70;p.materials.ore+=4;p.potions-=2;p.kills+=3;p.xp+=60;session.sim.apply_level_ups(p);session.sim.clock=60
	check(p.level==2,"XP crosses level boundary")
	session.change_map("forest",2);p=session.sim.players[1]
	check(p.expedition_journal.elapsed==60. and p.expedition_journal.id==first.id,"next floor retains baseline and elapsed")
	p.gold-=10;p.materials.ore-=2;p.kills+=2;p.cleared_floor=2;session.sim.clock=25
	var before=p.expedition_journal.duplicate(true);var old=session.sim
	session.blocked=true
	check(not session.travel("town") and session.sim==old and p.expedition_journal==before,"failed commit does not finish or advance live ledger")
	session.blocked=false;check(session.travel("town"),"successful retry")
	p=session.sim.players[1];var report=p.expedition_report
	check(report.gold_delta==60 and report.materials_delta.ore==2 and report.potions_delta==-2,"net changes include consumption")
	check(report.elapsed==85. and report.xp==60 and report.kills==5 and report.unlocked==2,"two floor time XP kills and unlock totals exactly once")
	check(not p.has("expedition_journal"),"active ledger ended")
	var frozen=report.duplicate(true);p.gold+=1000;p.materials.ore+=10
	check(report==frozen,"town transactions cannot change settled result")
	check(not session.sim.persistent(1).has("expedition_report") and not session.sim.persistent(1).has("expedition_journal"),"save schema unchanged")
	# Host transition carries each guest's authority-owned ledger independently.
	session.network_role="host"
	var guest=session.sim.add_player(7,"친구");guest.tutorial_done=true;guest.highest_floor=100;guest.gold=900
	session.change_map("forest",3);p=session.sim.players[1];guest=session.sim.players[7]
	p.gold+=11;guest.gold+=97;guest.kills+=4;session.sim.clock=13
	session.change_map("town",0);p=session.sim.players[1];guest=session.sim.players[7]
	check(p.expedition_report.gold_delta==11 and guest.expedition_report.gold_delta==97 and guest.expedition_report.kills==4,"host and guest have separate results")
	var host_view=session.sim.snapshot(1);var guest_view=session.sim.snapshot(7)
	check(not host_view.players[7].has("expedition_report") and not guest_view.players[1].has("expedition_report") and guest_view.players[7].expedition_report.gold_delta==97,"private report snapshot ownership")
	check(not host_view.players[1].has("expedition_journal"),"authority ledger never sent in snapshots")
	session.network_role="offline";session.connected=false;session.queue_free();await process_frame
	# Actual return UI and facility guidance, with no remote transaction bypass.
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options={"mute":true,"save-dir":folder.path_join("ui")};root.add_child(game);await process_frame
	game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	game.session.sim.players[1].tutorial_done=true;game.session.change_map("town",0)
	game.session.enter_floor(1);var hero=game.session.sim.players[1];hero.gold+=125;hero.materials.ore=8;hero.kills+=6;hero.potions=1;game.session.sim.clock=93
	game.session.travel("town");await process_frame;await process_frame
	check(game.town_panel.visible and game.town_panel.operation=="report","return opens personal record once")
	var town=game.town_panel;check(town.confirm_button==null,"report offers no transaction at spawn")
	var buttons=town.review_panel.find_children("*","Button",true,false)
	check(buttons.size()==3 and buttons[0].get_meta("destination")=="inn","low supplies prioritize inn")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../artifacts/expedition-return.png")==OK,"actual return framebuffer")
	buttons[0].pressed.emit()
	check(not town.visible and game.town_destination=="inn" and not game.town_path.is_empty(),"recommendation points to walkable facility route")
	check(not game.session.sim.action(1,"facility",JSON.stringify({"facility":"inn","operation":"rest"})),"remote inn action remains rejected")
	game.session.refresh();game.show_return_report()
	check(not town.visible,"snapshot refresh does not reopen dismissed report")
	game.shown_expedition_report="";game.codex.show();game.show_return_report()
	check(game.codex.visible and not town.visible and game.shown_expedition_report.is_empty(),"codex is not replaced by deferred report")
	game.codex.hide();game.help_panel.show();game.show_return_report()
	check(game.help_panel.visible and not town.visible and game.shown_expedition_report.is_empty(),"help is not replaced by deferred report")
	game.help_panel.hide();game.shown_expedition_report=game.session.sim.players[1].expedition_report.id
	hero=game.session.sim.players[1];hero.pos=preload("res://scripts/world_catalog.gd").FACILITIES.inn.pos;game.session.refresh()
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	check(game.town_destination.is_empty() and not town.visible and game.toast.text.contains(game.keybindings.label("interact")),"walking arrival clears guide and shows actual interaction key without a forced menu")
	game.guide_to_facility("inn")
	check(town.visible and town.facility=="inn","explicit facility choice at arrival opens actual service")
	check(preload("res://scripts/icon_library.gd").audit().unknown_requests.is_empty(),"all return icons resolve")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("EXPEDITION_JOURNAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
