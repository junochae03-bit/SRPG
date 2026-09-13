extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Research=preload("res://scripts/town_research.gd")
const View=preload("res://scripts/town_research_panel.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.session.refresh();game.hud.refresh();game.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await frame();check(root.get_texture().get_image().save_png("res://../artifacts/journey-"+name+".png")==OK,"capture "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/journey-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var sim=Sim.new(7919,"town");var p=sim.add_player(1,"별하");p.gold=1000;p.tutorial_done=true
	game.session.sim=sim;game.session.refresh();game.on_entered()
	p.pos=Research.World.FACILITIES.portal.pos;game.town_panel.open("portal");game.town_panel.portal_mode="clues";game.town_panel.refresh();await frame()
	var goals=game.town_panel.body.get_children().filter(func(node):return node.get_script()==preload("res://scripts/expedition_goal_panel.gd"))[0]
	check(goals.rows.size()==5,"research recommendation included alongside exploration choices")
	var first=goals.rows[0];check(first.offer.id=="research:field_tools","new base study recommended")
	await capture("recommendations")
	var scroll=goals.get_child(0);scroll.scroll_vertical=200;await frame()
	var last=goals.rows[4]
	check(scroll.get_global_rect().encloses(last.button.get_global_rect()),"fifth choice fully visible inside scrolled viewport")
	await capture("last-choice")
	last.button.pressed.emit();await frame();check(p.expedition_goal.kind=="advance","fifth card actually selects advancement")
	goals=game.town_panel.body.get_children().filter(func(node):return node.get_script()==preload("res://scripts/expedition_goal_panel.gd"))[0];first=goals.rows[0]
	first.button.pressed.emit();await frame()
	check(p.expedition_goal.kind=="research","actual card selects authority goal")
	p.pos=Research.World.FACILITIES.smith.pos;game.town_panel.open("smith");await frame()
	var view=game.town_panel.body.get_child(0)
	check(view is View and view.selected=="field_tools","relevant facility opens matching research")
	check(view.goal_button.disabled and not view.start_button.tooltip_text.is_empty(),"active target and current missing cost")
	await capture("missing-materials")
	game.town_panel.research_button.pressed.emit();await frame()
	check(not game.town_panel.research_mode,"can still return to normal facility services")
	p.materials.seed=12;p.pos=Research.World.FACILITIES.alchemy.pos;game.town_panel.open("alchemy");await frame()
	check(game.town_panel.operation=="ore" and not game.town_panel.research_mode,"early research shortage opens actual refinery")
	await capture("refinement")
	for i in range(2):check(sim.action(1,"facility",JSON.stringify({"facility":"alchemy","operation":"ore"})),"actual conversion")
	p.pos=Research.World.FACILITIES.smith.pos;game.town_panel.open("smith");await frame();view=game.town_panel.body.get_child(0)
	view.start_button.pressed.emit();await frame();Research.tick(sim,30);await frame()
	check(not view.craft_button.disabled,"after wait actual recipe enabled")
	view.craft_button.pressed.emit();await frame()
	check(p.expedition_goal.stage==3 and view.goal_button.text=="다음 탐사 선택" and not view.goal_button.disabled,"craft exposes next adventure action")
	for label in view.labels:check(label.get_visible_line_count()>0 and label.get_line_count()<=label.max_lines_visible,"visible research text "+label.text)
	await capture("next-expedition")
	view.goal_button.pressed.emit();await frame()
	check(p.expedition_goal.kind=="advance" and game.town_destination=="portal" and not game.town_panel.visible,"next button selects new goal and guides to portal without teleport")
	p.highest_floor=12;p.cleared_floor=11;p.materials.seed=0;p.materials.ore=2
	check(sim.action(1,"select_goal",JSON.stringify({"id":"research:lure_mixture","floor":12})),"register forest materials from deepest-floor context")
	p.pos=Research.World.FACILITIES.portal.pos;game.town_panel.open("portal");await frame()
	check(game.town_panel.selected_floor==preload("res://scripts/expedition_goals.gd").describe(p).floor and game.town_panel.selected_floor!=12,"portal defaults to current objective material floor")
	await capture("target-floor")
	game.session.connected=false;game.queue_free();await process_frame
	print("RESEARCH_JOURNEY_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
