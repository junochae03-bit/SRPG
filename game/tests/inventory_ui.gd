extends SceneTree
const Inventory=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok:bool,name:String):
	checks+=1
	if not ok:failures.append(name);push_error(name)
func run():
	var surface=SubViewport.new();surface.size=Vector2i(1440,900);root.add_child(surface)
	var game=load("res://main.tscn").instantiate();surface.add_child(game)
	await process_frame
	game.session.save_directory=ProjectSettings.globalize_path("res://../runtime/inventory-ui/"+str(Time.get_ticks_usec()))
	game.join_game();game.toggle_bag()
	var session=game.session
	var p=session.sim.players[1]
	check(session.act("claim_starters"),"starter grant succeeds through paused session")
	game.bag.refresh(true)
	check(p.inventory.size()==4 and p.equipped=="training-sword","four distinct starter weapons")
	var bag=game.bag
	bag.select_item("training-bow")
	check(bag.detail_name.text.contains("사냥활"),"selected detail names bow")
	bag.primary.pressed.emit()
	check(p.equipped=="training-bow","detail button equips bow")
	check(not p.bag_positions.has("training-bow") and p.bag_positions.has("training-sword"),"equipment frees grid space and returns old gear")
	var data={"kind":"inventory_item","id":"training-bow","slot":"weapon","rotated":false}
	check(not bag.grid._can_drop_data(Vector2(-20,0),data),"equipped drag rejects bounds")
	var staged=p.duplicate(true);staged.equipment.weapon=""
	var fit=Inventory.first_fit(staged,"training-bow")
	data.rotated=fit.rotated
	var at=Vector2(fit.x,fit.y)*bag.grid.CELL+Vector2.ONE*3
	check(bag.grid._can_drop_data(at,data),"equipment can be dropped into free grid region")
	bag.grid._drop_data(at,data)
	check(p.equipped=="" and p.bag_positions["training-bow"].x==fit.x,"grid drop unequips at chosen cell")
	var before=p.bag_positions.duplicate(true)
	check(not session.act("move_item",JSON.stringify({"id":"training-bow","x":10,"y":5,"rotated":false})),"invalid placement rejected through session")
	check(p.bag_positions==before,"failed drop keeps all item positions")
	bag.filter_index=2;bag.refresh(true)
	check(bag.grid.get_child_count()==4+1,"filter preserves equipment and potion controls")
	var faded=0
	for child in bag.grid.get_children():
		if child.faded:faded+=1
	check(faded==4,"consumable filter dims all four weapons")
	bag.filter_index=0;bag.refresh(true)
	var drag={"kind":"inventory_item","id":"training-bow","slot":"","rotated":false}
	bag.grid.force_drag(drag,null)
	var key=InputEventKey.new();key.physical_keycode=KEY_R;key.pressed=true
	surface.push_input(key)
	check(not drag.rotated,"one-cell inventory no longer rotates items")
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=Vector2.ZERO
	surface.push_input(release)
	await process_frame
	bag.refresh(true)
	var source_control
	for child in bag.grid.get_children():
		if child.item.id=="training-bow":source_control=child
	var start=source_control.global_position+Vector2(12,12)
	var motion=InputEventMouseMotion.new();motion.position=start;surface.push_input(motion)
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=start;surface.push_input(press)
	motion=InputEventMouseMotion.new();motion.position=start+Vector2(25,10);motion.relative=Vector2(25,10);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(motion)
	await process_frame
	check(surface.gui_is_dragging(),"pointer drag starts from real item button")
	if surface.gui_is_dragging():
		var active=surface.gui_get_drag_data()
		check(active.id=="training-bow" and is_instance_valid(active.preview),"pointer drag retains valid item preview")
		var destination=Vector2i.ZERO
		for y in range(Inventory.HEIGHT):
			for x in range(Inventory.WIDTH):
				if Inventory.can_place(p,active.id,Vector2i(x,y),active.rotated):destination=Vector2i(x,y)
		var drop_at=bag.grid.global_position+Vector2(destination)*bag.grid.CELL+Vector2.ONE*10
		motion=InputEventMouseMotion.new();motion.position=drop_at;motion.relative=drop_at-start;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(motion)
		Input.flush_buffered_events()
		release.position=drop_at;surface.push_input(release)
		check(p.bag_positions[active.id].x==destination.x and p.bag_positions[active.id].y==destination.y,"pointer release commits grid destination")
	await process_frame
	session.save_game()
	var saved=session.parse_save(session.save_path())
	check(saved!=null and saved.schema_version==5 and saved.bag_positions==p.bag_positions,"v5 one-cell grid persists to disk")
	game.stop_audio();session.disconnect_game();await create_timer(0.5).timeout;surface.queue_free();await process_frame
	print("INVENTORY_UI_TESTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
