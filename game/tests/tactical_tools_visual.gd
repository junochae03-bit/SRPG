extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Inv=preload("res://scripts/inventory_model.gd")
var game
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frame():
	game.session.refresh();game.refresh_vision();game.visible_telegraphs._process(0.);game.hud.refresh();game.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
func capture(name:String):
	await frame();check(root.get_texture().get_image().save_png("res://../artifacts/"+name+".png")==OK,"captured "+name)
func run():
	root.borderless=true;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();game.options.mute=true
	game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/tactical-visual/"+str(Time.get_ticks_usec()))
	root.add_child(game);await process_frame;game.join_game()
	game.session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
	var sim=Sim.new(741,"cave",12);sim.enemies.clear();sim.map.floor_cells.clear()
	for x in range(18,45):
		for y in range(18,45):sim.map.floor_cells[Vector2i(x,y)]=true
	var p=sim.add_player(1,"별하");p.pos=Vector2(30,30);p.level=100;sim.recalculate(p)
	for item in ["lure_stone","snare_trap","fire_bottle"]:Inv.add_stack(p,item,5)
	game.session.sim=sim;game.session.refresh();game.on_entered();game.camera_pos=game.Dungeon.iso(p.pos)
	await frame()
	var bar=game.hud.expedition.consumables
	for i in range(3):check(bar.assign(i+1,["lure_stone","snare_trap","fire_bottle"][i]),"assign tactical quickslot %d"%i)
	bar.open_picker(1);await frame()
	check(bar.assign_buttons.size()==6,"picker contains six actual consumables")
	var bottom=bar.assign_buttons.fire_bottle.get_rect().end.y
	check(bottom<313 and bar.picker.get_global_rect().position.y>0,"expanded picker rows fit without overlap")
	await capture("tactical-quickslots");bar.picker.hide()
	check(bar.use_slot(2),"quickslot actually deploys snare")
	check(p.consumables.snare_trap==4 and sim.tactical.records.size()==1,"quickslot owner quantity and record")
	var ally=sim.add_player(2,"여울");ally.pos=p.pos+Vector2(-1,1);Inv.add_stack(ally,"snare_trap",2);ally.aim=Vector2.LEFT
	sim.action(2,"snare_trap");sim.clock=.5
	var enemy=sim.spawn_enemy("orc_axeman",p.pos+Vector2(6,0),12)
	p.tool_cd=0.;p.aim=p.pos.direction_to(enemy.pos);check(bar.use_slot(3),"quickslot throws fire bottle")
	sim.clock=.8;await capture("tactical-tools-ground")
	check(game.session.state.tactical_tools.size()==3,"own and party pending tools rendered")
	game.toggle_bag();game.bag.select_item("@consumable:snare_trap");game.bag.refresh(true);await frame()
	check(game.bag.primary.text=="퀵슬롯에 등록","inventory offers registration instead of throwing under menu")
	var before=p.consumables.snare_trap
	game.bag.activate_selected();await process_frame
	var menus=game.bag.get_children().filter(func(child):return child is PopupMenu)
	check(menus.size()==1 and menus[0].item_count==4,"inventory exposes four slot choices")
	if not menus.is_empty():menus[0].id_pressed.emit(1);menus[0].hide()
	check(bar.assignments[1]=="snare_trap" and p.consumables.snare_trap==before,"inventory registers without consuming")
	game.toggle_bag()
	var town=Sim.new(741,"town");p=town.add_player(1,"별하");p.gold=1000;p.pos=preload("res://scripts/world_catalog.gd").FACILITIES.shop.pos
	game.session.sim=town;game.session.refresh();game.on_entered();await frame()
	game.town_panel.open("shop");game.town_panel.choose("fire_bottle");await frame()
	check(game.town_panel.products.has("fire_bottle") and game.town_panel.products.has("snare_trap") and game.town_panel.products.has("lure_stone"),"shop lists every deployable")
	check(game.town_panel.preview.cost==45 and game.town_panel.preview.outputs.fire_bottle==1,"review uses authoritative quote")
	check(game.town_panel.review_labels.result.text.contains("반경 2.5칸") and game.town_panel.review_labels.result.text.contains("피해 60"),"purchase review shows effect and damage before payment")
	game.town_panel.product_scroll.scroll_vertical=10000;await process_frame
	await capture("tactical-tools-shop")
	game.town_panel.confirm_button.pressed.emit();await frame()
	check(p.gold==955 and p.consumables.get("fire_bottle",0)==1,"shop confirmation charges and delivers once")
	check(game.town_panel.last_receipt.contains("화염병 +1"),"receipt names actual delivered tool")
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("TACTICAL_TOOLS_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
