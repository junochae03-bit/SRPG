extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Research=preload("res://scripts/town_research.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
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
	await frame();check(root.get_texture().get_image().save_png("res://../artifacts/research-"+name+".png")==OK,"capture "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/research-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var sim=Sim.new(7996,"town");var p=sim.add_player(1,"별하");p.gold=1000;p.tutorial_done=true
	for material in ["seed","ore","essence"]:Inventory.add_stack(p,material,100)
	game.session.sim=sim;game.session.refresh();game.on_entered()
	for facility in ["smith","alchemy","inn"]:
		p.pos=Research.World.FACILITIES[facility].pos;game.session.refresh();game.town_panel.open(facility);await frame()
		check(game.town_panel.research_button.visible,"facility exposes research entry")
		game.town_panel.research_button.pressed.emit();await frame()
		var view=game.town_panel.body.get_child(0)
		check(view is View and view.search.visible,"research view with search")
		for label in view.labels:
			check(label.get_visible_line_count()>0 and label.get_line_count()<=label.max_lines_visible,"research text visible without line clipping: "+label.text)
		check(view.start_button!=null and not view.start_button.disabled,"base research actionable")
		await capture(facility+"-initial")
		var keys=Research.matches(facility,"");view.start_button.pressed.emit();await frame()
		check(p.town_research.queue.any(func(row):return row.id==keys[0]),"actual UI starts authority research")
		check(game.town_panel.money.text=="보유 금화  %d G"%p.gold,"research header reflects spent gold")
		view.selected=keys[1];view.rebuild();await frame()
		check(not view.start_button.disabled and view.start_button.text.contains("예약"),"successor can be queued after reserved parent")
		view.start_button.pressed.emit();await frame()
		check(p.town_research.queue.size()==2,"queue displays prerequisite and successor")
		await capture(facility+"-queue")
		Research.tick(sim,90.);await frame()
		check(p.town_research.queue.is_empty() and Research.completed(p,keys[1]),"research queue completes in order")
		view.search.text=Research.DEFINITIONS[keys[1]].output;view.search.text_changed.emit(view.search.text);await frame()
		check(view.selected==keys[1] and view.craft_button!=null and not view.craft_button.disabled,"product search opens unlocked recipe")
		await capture(facility+"-unlocked")
		var quote=Research.stage(p,keys[1],"research_craft");view.craft_button.pressed.emit();await frame()
		for field in ["gold","materials","potions","consumables"]:check(p[field]==quote.player[field],"actual UI craft matches quote "+field)
		game.town_panel.research_button.pressed.emit();await frame()
		check(not game.town_panel.research_mode and game.town_panel.confirm_button!=null,"return to original services")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("TOWN_RESEARCH_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
