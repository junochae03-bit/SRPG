extends SceneTree
const Production=preload("res://scripts/production_queue.gd")
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/production_panel.gd")
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
func inspect(view):
	for label in view.content.find_children("*","Label",true,false):
		check(label.get_visible_line_count()>0 and label.get_line_count()<=label.max_lines_visible,"production label fits: "+label.text)
	check(not game.town_panel.production_button.get_global_rect().intersects(game.town_panel.research_button.get_global_rect()),"production and research entries do not overlap")
func capture(name):
	await frame();check(root.get_texture().get_image().save_png("res://../artifacts/production-"+name+".png")==OK,"capture "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/production-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	var sim=Sim.new(711,"town");var p=sim.add_player(1,"별하");p.gold=10000;p.tutorial_done=true;p.potions=0
	p.town_research.completed=Production.Research.DEFINITIONS.keys()
	for material in ["seed","ore","essence"]:Production.Inventory.add_stack(p,material,100)
	game.session.sim=sim;game.session.refresh();game.on_entered()
	for facility in ["smith","alchemy","inn"]:
		p.pos=Production.World.FACILITIES[facility].pos;game.session.refresh();game.town_panel.open(facility);await frame()
		check(game.town_panel.production_button.visible,"facility exposes production entry")
		game.town_panel.production_button.pressed.emit();await frame()
		var view=game.town_panel.body.get_child(0)
		check(view is View and view.start_button!=null and not view.start_button.disabled,"production view has usable recipe")
		view.quantity_input.value=2;await frame()
		check(view.quantity==2 and view.request().quantity==2,"quantity input changes actual work request")
		var before=p.gold;var definition=Production.recipes()[view.selected]
		view.start_button.pressed.emit();await frame()
		check(p.production.queue.size()==1 and p.production.queue[0].remaining==2 and p.gold==before-definition.gold,"actual button queues two batches but reserves only first")
		Production.tick(sim,2.);view.update_clocks(p);await frame();inspect(view);await capture(facility+"-working")
		Production.tick(sim,30.);view.rebuild();await frame()
		check(p.production.queue.is_empty(),"actual queued order produces both batches")
		game.town_panel.research_button.pressed.emit();await frame()
		check(game.town_panel.research_mode and not game.town_panel.production_mode,"research and work views switch independently")
		game.town_panel.production_button.pressed.emit();await frame()
		check(game.town_panel.research_button.text=="시설 연구","research button state resets when entering production")
		game.town_panel.production_button.pressed.emit();await frame()
		check(not game.town_panel.production_mode and game.town_panel.confirm_button!=null,"original service screen remains accessible")
	p.pos=Production.World.FACILITIES.alchemy.pos;game.session.refresh();game.town_panel.open("alchemy");game.town_panel.production_button.pressed.emit();await frame()
	var view=game.town_panel.body.get_child(0)
	view.selected="alchemy:ore";view.mode="target";view.quantity=130;view.rebuild();await frame()
	check(view.quantity_input.value==130,"material target supports larger stock counts")
	view.selected="alchemy:mana_potion";p.consumables.mana_potion=2;view.rebuild();await frame()
	check(view.quantity_input.value==20 and view.quantity==20 and view.request().quantity==20 and not view.start_button.disabled,"recipe switch clamps displayed quoted and submitted target together")
	view.selected="alchemy:ore";view.quantity=130;view.rebuild();await frame()
	view.start_button.pressed.emit();await frame()
	view.selected="alchemy:essence";view.mode="repeat";view.rebuild();view.start_button.pressed.emit();await frame()
	view.selected="alchemy:mana_potion";view.mode="count";view.quantity=1;view.rebuild();view.start_button.pressed.emit();await frame()
	check(p.production.queue.size()==3 and view.start_button.disabled,"full workbench disables further reservation")
	view.rebuild();await frame();inspect(view);await capture("three-orders")
	view.search.text="존재하지 않는 제작법";view.search.text_changed.emit(view.search.text);await frame()
	check(view.selected.is_empty() and view.start_button==null,"empty recipe search does not leave stale craft action")
	await capture("empty-search")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("PRODUCTION_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
