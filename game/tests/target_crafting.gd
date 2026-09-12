extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Ops=preload("res://scripts/town_operations.gd")
const World=preload("res://scripts/world_catalog.gd")
const Inv=preload("res://scripts/inventory_model.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func click(control:Control):
	var event=InputEventMouseButton.new();event.position=control.get_global_transform_with_canvas()*(control.size*.5);event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
func run():
	var sim=Sim.new(77,"town",0);var p=sim.add_player(1,"목표 제작")
	p.pos=World.FACILITIES.alchemy.pos;p.gold=10000;p.materials.seed=1000;p.materials.ore=1000;p.potions=4
	var original=var_to_bytes(p);var q=Ops.quote(p,"alchemy","potion",{"target_quantity":10})
	check(q.reason.is_empty() and q.batches==2 and q.outputs.potion==6 and q.cost==20 and q.final_quantity==10,"only missing stock determines batches")
	check(var_to_bytes(p)==original,"quote has no player mutation")
	var request=JSON.stringify({"facility":"alchemy","operation":"potion","target_quantity":10})
	check(sim.action(1,"facility",request) and p.potions==10 and p.gold==9980 and p.materials.seed==994,"real transaction applies matching cost and output")
	original=var_to_bytes(p)
	check(not sim.action(1,"facility",request) and var_to_bytes(p)==original,"repeated fulfilled target consumes nothing")
	p.potions=4;q=Ops.quote(p,"alchemy","potion",{"target_quantity":5})
	check(q.final_quantity==7 and q.outputs.potion==3 and q.result.contains("목표 5"),"recipe batch rounding explicitly quotes final stock")
	p.potions=19;original=var_to_bytes(p);q=Ops.quote(p,"alchemy","potion",{"target_quantity":20})
	check(not q.reason.is_empty() and q.reason.contains("상한") and var_to_bytes(p)==original,"rounding beyond potion cap is rejected without charge")
	p.potions=4;p.gold=0;original=var_to_bytes(p)
	check(not sim.action(1,"facility",request) and var_to_bytes(p)==original,"insufficient gold is atomic")
	p.gold=10000;p.materials.seed=1;original=var_to_bytes(p)
	check(not sim.action(1,"facility",request) and var_to_bytes(p)==original,"insufficient ingredients are atomic")
	for invalid in [0,-1,21,1.5,"10",null,true]:
		q=Ops.quote(p,"alchemy","potion",{"target_quantity":invalid})
		check(not q.reason.is_empty(),"malformed or over-cap target rejected "+str(invalid))
	check(not Ops.quote(p,"shop","potion",{"target_quantity":10}).reason.is_empty(),"target cannot bypass another facility rules")
	p.materials.seed=1000;p.materials.essence=4;q=Ops.quote(p,"alchemy","essence",{"target_quantity":25})
	check(q.reason.is_empty() and q.outputs.essence==21 and q.cost==840,"single-output recipe supports target above old batch menu")
	p.materials.ore=4;q=Ops.quote(p,"alchemy","ore",{"target_quantity":10})
	check(q.outputs.ore==6 and q.materials.seed==10 and q.cost==40,"ore target uses its own recipe")
	check(Ops.quote(p,"alchemy","potion",{"quantity":3}).outputs.potion==9,"legacy fixed-batch recipe unchanged")
	# Keep ingredient stacks present while filling all remaining bag cells.
	p.materials.essence=0;Inv.initialize(p)
	var n=0
	while Inv.add_gear(p,Equipment.make("head",0,0,"full-"+str(n),"none","warrior")):n+=1
	original=var_to_bytes(p);q=Ops.quote(p,"alchemy","essence",{"target_quantity":10})
	check(not q.reason.is_empty() and var_to_bytes(p)==original,"full bag rejects new output stack without ingredient loss")
	root.borderless=true;root.size=Vector2i(1920,1080)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/target-crafting/"+str(Time.get_ticks_usec()));root.add_child(game)
	await process_frame;game.join_game();game.set_process(false);game.set_physics_process(false);game.session.set_physics_process(false)
	p=game.session.sim.players[1];p.tutorial_done=true;game.session.travel("town");p=game.session.sim.players[1]
	p.pos=World.FACILITIES.alchemy.pos;p.gold=1000;p.materials.seed=100;p.potions=4;game.session.refresh()
	var panel=game.town_panel;panel.open("alchemy")
	click(panel.body.find_child("TargetMode",true,false));await process_frame
	check(panel.target_quantity==10 and panel.preview.outputs.potion==6,"real UI switches to target stock quote")
	click(panel.quantity_buttons[5]);await process_frame
	check(panel.preview.final_quantity==7 and panel.preview.result.contains("목표 5"),"UI previews rounded real output")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../artifacts/target-crafting.png")==OK,"actual target crafting preview captured")
	click(panel.confirm_button);await process_frame
	check(p.potions==7 and p.gold==990 and panel.confirm_button.disabled,"confirmation crafts once and disables fulfilled target")
	check(game.session.save_game(),"crafted inventory saves")
	panel.close();game.session.disconnect_game();game.session.start_game("",1)
	check(game.session.sim.players[1].potions==7 and game.session.sim.players[1].gold==990,"saved target output persists across restart")
	p=game.session.sim.players[1];p.gold=1000;p.materials.seed=100;p.materials.essence=100;p.materials.ore=100
	var consumables=preload("res://scripts/consumables.gd")
	for key in ["mana_potion","power_potion"]:
		p.pos=World.FACILITIES.shop.pos;panel.open("shop")
		panel.products[key].pressed.emit();await process_frame
		check(panel.operation==key and panel.preview.cost==consumables.ITEMS[key].price,"new potion card opens correct purchase quote "+key)
		panel.confirm_button.pressed.emit();await process_frame
		check(consumables.count(p,key)==1 and panel.last_receipt.contains(consumables.ITEMS[key].name+" +1"),"new potion purchase receipt includes delivered item "+key)
		panel.close();p.pos=World.FACILITIES.alchemy.pos;panel.open("alchemy");panel.choose(key)
		click(panel.body.find_child("TargetMode",true,false));await process_frame
		click(panel.quantity_buttons[5]);await process_frame
		check(panel.preview.final_quantity==7 and panel.quantity_buttons.has(20),"new potion target obeys 20-item cap and batch rounding "+key)
		click(panel.confirm_button);await process_frame
		check(consumables.count(p,key)==7 and panel.confirm_button.disabled,"new potion target actually crafts once "+key)
		check(panel.preview.title==consumables.ITEMS[key].name and panel.preview.result.contains("목표 달성"),"fulfilled target retains selected item identity "+key)
		check(panel.review_labels.result.text==panel.last_receipt.replace(" · ","\n") and panel.review_labels.result.max_lines_visible<0,"all receipt deltas remain readable without ellipsis "+key)
		panel.product_scroll.scroll_vertical=10000
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://../artifacts/new-potion-crafting.png")==OK,"new consumable crafting receipt captured")
	panel.close()
	check(await game.audio_director.shutdown(),"audio drained")
	game.session.connected=false;game.queue_free();await process_frame;await process_frame
	print("TARGET_CRAFTING checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
