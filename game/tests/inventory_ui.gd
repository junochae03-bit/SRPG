extends SceneTree
const Inventory=preload("res://scripts/inventory_model.gd")
var checks=0
var failures=[]
var surface:SubViewport
func _initialize():
	run.call_deferred()
func check(ok:bool,name:String):
	checks+=1
	if not ok:failures.append(name);push_error(name)
func run():
	# Full HD client area, independent of desktop title-bar constraints.
	root.borderless=true;root.size=Vector2i(1920,1080)
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.size_2d_override=Vector2i(1600,900);surface.size_2d_override_stretch=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;surface.gui_embed_subwindows=true;root.add_child(surface)
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
	check(bag.detail_name.text==Inventory.find_item(p,"training-bow").name,"선택한 방어구의 현재 카탈로그 이름 표시")
	bag.primary.pressed.emit()
	check(p.equipment.chest=="training-bow","detail button equips bow")
	check(not p.bag_positions.has("training-bow") and not p.bag_positions.has("training-sword"),"equipment frees grid space and returns old gear")
	var data={"kind":"inventory_item","id":"training-bow","slot":"chest","rotated":false}
	check(not bag.grid._can_drop_data(Vector2(-20,0),data),"equipped drag rejects bounds")
	var staged=p.duplicate(true);staged.equipment.chest=""
	var fit=Inventory.first_fit(staged,"training-bow")
	data.rotated=fit.rotated
	var at=Vector2(fit.x,fit.y)*bag.grid.CELL+Vector2.ONE*3
	check(bag.grid._can_drop_data(at,data),"equipment can be dropped into free grid region")
	bag.grid._drop_data(at,data)
	check(p.equipment.chest=="" and p.bag_positions["training-bow"].x==fit.x,"grid drop unequips at chosen cell")
	var before=p.bag_positions.duplicate(true)
	check(not session.act("move_item",JSON.stringify({"id":"training-bow","x":10,"y":5,"rotated":false})),"invalid placement rejected through session")
	check(p.bag_positions==before,"failed drop keeps all item positions")
	bag.filter_index=2;bag.refresh(true)
	check(bag.grid.get_child_count()==3+1,"filter preserves equipment and potion controls")
	var faded=0
	for child in bag.grid.get_children():
		if child.faded:faded+=1
	check(faded==3,"consumable filter dims all four weapons")
	bag.filter_index=0;bag.refresh(true)
	var drag={"kind":"inventory_item","id":"training-bow","slot":"","rotated":false}
	bag.grid.force_drag(drag,null)
	var key=InputEventKey.new();key.physical_keycode=KEY_R;key.pressed=true
	surface.push_input(key,true)
	check(not drag.rotated,"one-cell inventory no longer rotates items")
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=Vector2.ZERO
	surface.push_input(release,true)
	await process_frame
	bag.refresh(true)
	var source_control
	for child in bag.grid.get_children():
		if child.item.id=="training-bow":source_control=child
	var start=source_control.get_global_transform_with_canvas()*Vector2(12,12)
	var motion=InputEventMouseMotion.new();motion.position=start;surface.push_input(motion,true)
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=start;surface.push_input(press,true)
	motion=InputEventMouseMotion.new();motion.position=start+Vector2(25,10);motion.relative=Vector2(25,10);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(motion,true)
	await process_frame
	check(surface.gui_is_dragging(),"pointer drag starts from real item button")
	if surface.gui_is_dragging():
		var active=surface.gui_get_drag_data()
		check(active.id=="training-bow" and is_instance_valid(active.preview),"pointer drag retains valid item preview")
		var destination=Vector2i.ZERO
		for y in range(Inventory.HEIGHT):
			for x in range(Inventory.WIDTH):
				if Inventory.can_place(p,active.id,Vector2i(x,y),active.rotated):destination=Vector2i(x,y)
		# The expanded lower rows are real storage. Scroll to expose the drop
		# destination before sending the same actual pointer-release interaction.
		bag.grid_scroll.scroll_vertical=maxi(0,(destination.y-5)*bag.grid.CELL);await process_frame
		var drop_at=bag.grid.get_global_transform_with_canvas()*(Vector2(destination)*bag.grid.CELL+Vector2.ONE*10)
		motion=InputEventMouseMotion.new();motion.position=drop_at;motion.relative=drop_at-start;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(motion,true)
		release.position=drop_at;surface.push_input(release,true)
		check(p.bag_positions[active.id].x==destination.x and p.bag_positions[active.id].y==destination.y,"pointer release commits grid destination: expected=%s actual=%s at=%s grid=%s hovered=%s allowed=%s"%[destination,p.bag_positions[active.id],drop_at,bag.grid.get_global_transform_with_canvas(),bag.grid.hovered_cell,bag.grid.allowed])
	await process_frame
	session.save_game()
	var saved=session.parse_save(session.save_path())
	check(saved!=null and saved.schema_version==7 and saved.bag_positions==p.bag_positions,"v5 one-cell grid persists to disk")
	var cls=p.class_id
	var content=preload("res://scripts/content.gd")
	for class_id in ["warrior","ranger","mage","rogue","fighter"]:
		p.class_id=class_id;session.refresh();bag.refresh(true)
		var wardrobe=preload("res://scripts/wardrobe.gd")
		check(bag.avatar_keys==wardrobe.owned_avatars(p) and bag.costume_keys==wardrobe.owned_costumes(p),"picker indexes match owned class-compatible appearances "+class_id)
		check(bag.avatar_keys==["auto"] and bag.costume_keys==["none"],"unbought appearances absent from inventory "+class_id)
		check(bag.avatar_picker.get_item_text(0)==wardrobe.label("base:"+class_id),"class change refreshes default appearance name "+class_id)
		var blocked=content.COSTUMES.keys().filter(func(id):return not bag.costume_keys.has(id))
		if not blocked.is_empty():
			var before_costume=p.costume
			check(not session.act("costume",blocked[0]) and p.costume==before_costume,"blocked costume cannot bypass class filter "+class_id)
	p.class_id=cls;p.level=100;session.sim.recalculate(p)
	# 정규화가 카탈로그 이름을 복원하므로 긴 이름도 카탈로그 경유로 주입한다.
	var names=preload("res://scripts/content_names.gd");var name_key="weapon:"+cls+":1";var saved_name=names.data.equipment[name_key]
	names.data.equipment[name_key]="별들의 기억을 잇는 영원의 서약 — 잊힌 왕국 최후의 수호검"
	var long_item=preload("res://scripts/equipment_catalog.gd").make("sword",1,4,"ui-long-item","none",cls)
	long_item.upgrade=3;long_item.bonus=87
	check(Inventory.add_gear(p,long_item),"long equipment fixture added through inventory model")
	session.refresh();bag.select_item(long_item.id);await process_frame;await process_frame
	var current
	for child in bag.grid.get_children():
		if child.item.id==long_item.id:current=child
	check(current.quantity_text()=="+3","upgrade badge uses upgrade rank, not +87 combat bonus")
	check(bag.grid.CELL==64 and current.size==Vector2(64,64),"one-cell item art has readable 64px slot")
	check(bag.detail_name.get_line_count()>=2 and bag.detail_name.text==long_item.name,"long name wraps without truncating text")
	check(bag.detail_scroll.get_v_scroll_bar().max_value>bag.detail_scroll.size.y,"overflow details are scrollable")
	check(bag.primary.position.y>bag.detail_scroll.position.y+bag.detail_scroll.size.y,"equip action stays below scrolling details")
	var bounds=bag.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,bag.size)
	check(surface.get_visible_rect().encloses(bounds),"wide inventory fits logical viewport with safe margins")
	await capture("inventory-v04-long-name")
	var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.double_click=true;click.position=current.get_global_transform_with_canvas()*(current.size*.5)
	surface.push_input(click,true);release.position=click.position;surface.push_input(release,true);await process_frame
	check(p.equipment.weapon==long_item.id,"real double-click equips selected valid weapon")
	check(bag.equipment_controls.weapon.quantity_text()=="+3","equipped control keeps actual enhancement badge")
	names.data.equipment[name_key]=saved_name
	p.hp=p.max_hp-100;p.potion_cd=0;var prior_potions=p.potions;var prior_hp=p.hp;session.refresh();bag.refresh(true)
	var potion_control=bag.grid.get_children().filter(func(child):return child.item.category=="consumable")[0]
	click.position=potion_control.get_global_transform_with_canvas()*(potion_control.size*.5);surface.push_input(click,true);release.position=click.position;surface.push_input(release,true);await process_frame
	check(p.potions==prior_potions-1 and p.hp>prior_hp,"real double-click consumes potion and heals")
	bag.select_item(long_item.id)
	var popup=bag.costume_picker.get_popup()
	check(popup.max_size.y==440,"appearance popup has bounded height")
	# Stress the actual picker presentation with the whole catalog. Class-filtered
	# choices are restored afterward; no disallowed choice is submitted.
	for id in content.COSTUMES:bag.costume_picker.add_item(content.COSTUMES[id])
	bag.costume_picker.grab_focus();key=InputEventKey.new();key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=true;surface.push_input(key,true)
	await process_frame;await process_frame
	check(popup.visible and popup.size.y<=440,"long appearance menu opens and scrolls within cap")
	await capture("inventory-v04-appearance-menu");popup.hide();bag.costume_keys=[];bag.refresh(true)
	var stats_button=bag.find_children("*","Button",true,false).filter(func(button):return button.text=="능력치")[0]
	click.double_click=false;click.position=stats_button.get_global_transform_with_canvas()*(stats_button.size*.5)
	surface.push_input(click,true);release.position=click.position;surface.push_input(release,true);await process_frame
	check(bag.stats_overlay.visible,"real inventory ability button opens detail sheet")
	check(bag.stats_values.size()==17,"detail sheet exposes all combat and primary stats")
	for pair in bag.stats_values:
		for label in pair:
			check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x,"stat caption and value fit full width "+label.text)
		check(not pair[0].get_rect().intersects(pair[1].get_rect()),"stat title and value do not overlap")
	await capture("inventory-v054-statistics")
	bag.hide();check(not bag.stats_overlay.visible,"closing inventory also closes statistics")
	game.stop_audio();session.disconnect_game();await create_timer(0.5).timeout;surface.queue_free();await process_frame
	print("INVENTORY_UI_TESTS checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func capture(name:String):
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	var picture=surface.get_texture().get_image()
	check(picture.get_size()==Vector2i(1920,1080),"full-HD inventory capture")
	var path=ProjectSettings.globalize_path("res://../artifacts/"+name+".png")
	check(picture.save_png(path)==OK,"save inventory evidence "+name)
