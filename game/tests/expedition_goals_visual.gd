extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Goals=preload("res://scripts/expedition_goals.gd")
const GoalPanel=preload("res://scripts/expedition_goal_panel.gd")
var game
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func panel():return game.town_panel.body.get_children().filter(func(child):return child is GoalPanel)[0]
func labels_fit(node):
	if node is Label and node.visible:
		var width=node.get_theme_font("font").get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x
		check(width<=node.size.x,"goal label fits: "+node.text)
		check(node.size.y>=node.get_theme_font("font").get_height(node.get_theme_font_size("font_size")),"goal label has full line height: "+node.text)
	for child in node.get_children():labels_fit(child)
func capture(name):
	await process_frame;await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(1920,1080) and image.save_png("res://../artifacts/"+name+".png")==OK,"actual screenshot "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/goal-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	var sim=Sim.new(792,"town");var p=sim.add_player(1,"단서를 좇는 모험가")
	p.level=20;p.highest_floor=12;p.cleared_floor=11;p.tutorial_done=true
	p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.portal.pos
	game.session.sim=sim;game.session.refresh();game.on_entered()
	game.town_panel.open("portal");game.town_panel.portal_mode="clues";game.town_panel.refresh()
	await process_frame
	check(panel().rows.size()==5,"research, rumors, materials and advancement available together")
	labels_fit(panel());await capture("expedition-goals-selection")
	var material=panel().rows.filter(func(row):return row.offer.id=="materials")[0]
	material.button.pressed.emit();await process_frame
	check(p.expedition_goal.kind=="materials" and game.town_panel.selected_floor==p.expedition_goal.floor,"actual selection registers personal goal and selects destination")
	panel().clear_button.pressed.emit();await process_frame
	check(p.expedition_goal.is_empty(),"actual clear button removes personal objective")
	var secret=panel().rows.filter(func(row):return row.offer.id=="secret")[0]
	secret.button.pressed.emit();await process_frame
	check(p.expedition_goal.kind=="secret" and panel().rows.any(func(row):return row.offer.id=="secret" and row.selected.visible),"authoritative goal highlighted")
	check(game.session.parse_save(game.session.save_path()).expedition_goal==p.expedition_goal,"UI selection persisted to isolated save")
	game.town_panel.confirm_button.pressed.emit();await process_frame
	check(game.session.sim.map.floor_number==p.expedition_goal.floor,"actual departure follows chosen destination")
	sim=game.session.sim;p=sim.players[1];var region=sim.map.hidden_regions[0]
	for enemy in sim.enemies.values():enemy.hp=0
	p.pos=region.pos;sim.tick(.05);game.session.refresh();game.hud.refresh()
	check(p.expedition_goal.stage==1 and game.hud.quest.text.contains("발견한 벽 틈"),"HUD changes from rumor to discovered clue")
	game._process(.1);game.queue_redraw();await capture("expedition-goals-discovered")
	check(not game.session.paused,"personal objective does not pause exploration")
	check(preload("res://scripts/icon_library.gd").audit().unknown_requests.is_empty(),"all objective icons resolve")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("EXPEDITION_GOALS_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
