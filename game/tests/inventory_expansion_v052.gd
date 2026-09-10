extends SceneTree
const I=preload("res://scripts/inventory_model.gd")
const E=preload("res://scripts/equipment_catalog.gd")
const C=preload("res://scripts/content.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
var images=[]
var test_directory=""
var surface:SubViewport
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures.append(message);push_error(message)
func empty_bag(p:Dictionary):
	p.inventory=[];p.equipment={};p.equipped="";p.bag_positions={};p.potions=0;p.materials={};I.initialize(p)
func parse_copy(local,data:Dictionary,name:String):
	var path=test_directory+"/"+name+".json";var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close();return local.parse_save(path)
func model_cases():
	check(I.WIDTH==10 and I.HEIGHT==12 and I.CAPACITY==120,"120 one-cell positions preserve ten-column coordinates")
	var sim=Sim.new(20260910,"town");var p=sim.add_player(1,"보관 경계");p.level=100;empty_bag(p)
	for slot in C.SLOTS:
		var item=E.make("sword" if slot=="weapon" else slot,0,0,"equipped-"+slot,"none","warrior")
		check(I.add_gear(p,item) and I.equip(p,item.id),"equip protected slot "+slot)
	for index in range(60):check(I.add_gear(p,E.make("head",0,0,"kept-%d"%index,"none","warrior")),"fill old coordinate "+str(index))
	var old_positions=p.bag_positions.duplicate(true);I.initialize(p)
	check(old_positions==p.bag_positions,"existing sixty saved placements survive capacity migration exactly")
	check(I.move_item(p,"kept-0",Vector2i(9,11),false),"last expanded cell accepts one-cell item")
	check(p.bag_positions["kept-0"]=={"x":9,"y":11,"rotated":false},"new cell has stable absolute coordinates")
	var unchanged=var_to_bytes(p)
	for point in [Vector2i(10,11),Vector2i(9,12),Vector2i(-1,6),Vector2i(0,-1)]:check(not I.move_item(p,"kept-0",point,false) and var_to_bytes(p)==unchanged,"reject expanded boundary atomically "+str(point))
	for index in range(60,I.CAPACITY):check(I.add_gear(p,E.make("head",0,0,"kept-%d"%index,"none","warrior")),"fill expanded coordinate "+str(index))
	check(p.inventory.size()==I.CAPACITY+C.SLOTS.size() and p.bag_positions.size()==I.CAPACITY,"120 stored plus seven worn pieces")
	unchanged=var_to_bytes(p)
	check(not I.add_gear(p,E.make("head",0,0,"overflow","none","warrior")) and var_to_bytes(p)==unchanged,"121st bag pickup is rejected without loss")
	check(not I.unequip(p,"weapon") and var_to_bytes(p)==unchanged,"full expanded bag protects equipped weapon")
	check(not I.add_stack(p,"ore",1) and var_to_bytes(p)==unchanged,"new stack also consumes real capacity")
	var saved=sim.persistent(1);saved.world_seed=20260910
	var local=preload("res://scripts/local_session.gd").new();var restored=parse_copy(local,saved,"full-expanded")
	check(restored!=null and restored.bag_positions==p.bag_positions and restored.inventory.size()==127,"normal save parser accepts all expanded placements and worn gear")
	var invalid=saved.duplicate(true);invalid.bag_positions["kept-0"].y=12;check(parse_copy(local,invalid,"invalid-row")==null,"save parser rejects row beyond expanded capacity")
	invalid=saved.duplicate(true);invalid.inventory.append(E.make("head",0,0,"invalid-128","none","warrior"));check(parse_copy(local,invalid,"invalid-count")==null,"save parser rejects 128 owned gear")
	invalid=saved.duplicate(true);invalid.equipment={};invalid.equipped="";check(parse_copy(local,invalid,"invalid-unworn-count")==null,"save parser rejects more than120 actually unworn pieces")
	local.free()
func capture(name:String):
	var event=InputEventMouseMotion.new();event.position=Vector2(10,10);surface.push_input(event,true)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image=surface.get_texture().get_image();check(image.get_size()==Vector2i(1920,1080),"actual FullHD "+name)
	var path="res://../artifacts/inventory-v052-"+name+".png";check(image.save_png(ProjectSettings.globalize_path(path))==OK,"capture "+name);images.append(path)
func fitting(label:Label):
	check(label.get_line_count()*label.get_line_height()<=label.size.y+1,"unclipped inventory label "+label.text)
func settle_storage(bag):
	bag.grid_scroll.queue_sort()
	await bag.grid_scroll.sort_children
	await RenderingServer.frame_post_draw
func selected_storage_visible(bag)->bool:
	var selected=bag.grid.get_children().filter(func(control):return control.item.id==bag.selected_id)
	return selected.size()==1 and selected[0].selected and bag.grid_scroll.get_global_rect().encloses(selected[0].get_global_rect())
func run():
	root.borderless=true;root.size=Vector2i(1920,1080);test_directory=ProjectSettings.globalize_path("res://../runtime/inventory-expansion-v052/"+str(Time.get_ticks_usec()));DirAccess.make_dir_recursive_absolute(test_directory)
	model_cases()
	surface=SubViewport.new();surface.size=Vector2i(1920,1080);surface.size_2d_override=Vector2i(1600,900);surface.size_2d_override_stretch=true;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;surface.gui_embed_subwindows=true;root.add_child(surface)
	var game=load("res://main.tscn").instantiate();game.options.mute=true;surface.add_child(game);await process_frame
	var session=game.session;session.save_directory=test_directory+"/client";game.join_game();session.set_physics_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false)
	var p=session.sim.players[1];p.level=100;p.tutorial_done=true;session.travel("town");p=session.sim.players[1];empty_bag(p)
	var names=preload("res://scripts/content_names.gd");var saved_name=names.data.equipment["chest:warrior:1"]
	names.data.equipment["chest:warrior:1"]="별들의 기억을 잇는 영원의 서약 — 잊힌 왕국의 마력 갑옷"
	var old=E.make("chest",1,1,"compare-current","focus","warrior");old.upgrade=2
	var choice=E.make("chest",1,1,"compare-new","fortune","warrior");choice.upgrade=2
	check(I.add_gear(p,old) and I.equip(p,old.id) and I.add_gear(p,choice),"comparison fixture retains worn and candidate armor")
	check(I.move_item(p,choice.id,Vector2i(9,11),false),"최초 열기에서 선택할 장비를 실제 마지막 칸에 배치")
	for index in range(65):check(I.add_gear(p,E.make("head",0,0,"client-%d"%index,"none","warrior")),"client expanded item "+str(index))
	session.sim.recalculate(p);session.refresh();game.toggle_bag();var bag=game.bag;bag.select_item(choice.id)
	await settle_storage(bag)
	check(bag.grid_scroll.scroll_vertical==384 and selected_storage_visible(bag),"첫 표시와 같은 프레임에서 마지막 칸을 선택해도 선택 테두리 전체 노출")
	check(bag.selected_id==choice.id and bag.detail_name.text==choice.name,"최초 자동 스크롤과 상세 비교가 같은 장비를 표시")
	# 탐색 버튼을 직접 누르면 선택 정보는 유지하고 사용자가 고른 구간을 보여 줍니다.
	bag.select_item(choice.id);bag.storage_buttons[0].pressed.emit();bag.filter_buttons[3].pressed.emit()
	await settle_storage(bag)
	check(bag.grid_scroll.scroll_vertical==0 and bag.filter_index==3 and bag.selected_id==choice.id,"예약된 선택보다 직접 고른 첫 구간과 재료 필터가 우선")
	check(bag.grid.get_children().filter(func(control):return control.item.id==choice.id)[0].faded,"필터가 다른 선택 장비의 강조 정책 유지")
	bag.filter_buttons[0].pressed.emit();await settle_storage(bag)
	check(bag.grid_scroll.scroll_vertical==0 and bag.selected_id==choice.id,"전체 필터로 복귀해도 구간과 선택 유지")
	game.toggle_bag();game.toggle_bag();await settle_storage(bag)
	check(bag.grid_scroll.scroll_vertical==0 and bag.selected_id==choice.id and bag.filter_index==0,"재열기는 직접 선택한 구간과 장비를 그대로 유지")
	bag.select_item(choice.id);bag.select_item("client-0");await settle_storage(bag)
	check(bag.selected_id=="client-0" and selected_storage_visible(bag) and bag.grid_scroll.scroll_vertical==0,"같은 프레임의 연속 선택은 마지막 선택 장비만 노출")
	bag.select_item(choice.id);await settle_storage(bag)
	check(bag.grid_scroll.scroll_vertical==384 and selected_storage_visible(bag),"탐색 후 마지막 칸 재선택은 다시 정확히 노출")
	bag.storage_buttons[1].pressed.emit();await settle_storage(bag)
	game.toggle_bag();game.toggle_bag();await settle_storage(bag)
	check(bag.grid_scroll.scroll_vertical==384 and selected_storage_visible(bag),"아래 구간에서 재열어도 마지막 칸과 선택 테두리 유지")
	check(bag.capacity.text.contains("120") and bag.grid.CELL==64,"capacity visible with original readable cell art")
	check(bag.grid_scroll.size.y==6*bag.grid.CELL and bag.grid.custom_minimum_size.y==12*bag.grid.CELL,"six visible rows scroll through twelve real rows")
	check(bag.comparison_panel.visible and bag.comparison_current_id==old.id and bag.comparison_selected_id==choice.id,"comparison names exact worn and selected ownership")
	check(bag.detail_name.text==choice.name and bag.detail_name.get_line_count()>1,"full selected name wraps rather than truncates")
	var trial=p.duplicate(true);trial.equipment.chest=choice.id;session.sim.recalculate(trial)
	var expected=[[session.sim.damage_for(p,"physical"),session.sim.damage_for(trial,"physical")],[session.sim.damage_for(p,"magic"),session.sim.damage_for(trial,"magic")],[p.defense,trial.defense],[p.magic_defense,trial.magic_defense],[p.max_hp,trial.max_hp]]
	for index in range(expected.size()):
		var row=bag.comparison_rows[index];check(row[1]==expected[index][0] and row[2]==expected[index][1],"compare uses actual derived stat "+str(row[0]))
		for label in bag.comparison_values[index]:fitting(label)
		check(bag.detail_scroll.get_global_rect().encloses(bag.comparison_values[index][0].get_global_rect()),"all five main stats visible before scrolling "+str(index))
	check(bag.comparison_values[0][3].text.begins_with("▼") and bag.comparison_values[1][3].text.begins_with("▲"),"mixed upgrade shows loss and gain with distinct symbols")
	check(bag.comparison_values[0][3].get_theme_color("font_color")!=bag.comparison_values[1][3].get_theme_color("font_color"),"gain and loss colors also differ")
	check(bag.detail_body.text.contains(E.option_text(old)) and bag.detail_body.text.contains(E.option_text(choice)) and bag.detail_body.text.contains(E.restriction_text(choice)),"both option states and actual class restriction remain visible")
	check(bag.primary.position.y>bag.detail_scroll.get_rect().end.y,"equip action pinned below scrollable comparison")
	await capture("comparison")
	bag.detail_scroll.scroll_vertical=10000;await capture("options")
	bag.primary.pressed.emit();await process_frame
	check(p.equipment.chest==choice.id and bag.comparison_notice.text=="현재 장착 중" and not bag.comparison_panel.visible,"equip updates worn state rather than stale self-comparison")
	var forbidden=E.make("bow",0,1,"wrong-job","none","ranger");check(I.add_gear(p,forbidden),"foreign weapon fixture remains owned")
	session.refresh();bag.select_item(forbidden.id);await process_frame
	check(bag.primary.disabled and bag.comparison_notice.text.contains("전용 직업"),"class restriction visible and action disabled")
	check(not bag.comparison_panel.visible,"unwearable equipment never previews misleading removal stats")
	await capture("class-restriction")
	bag.show_storage_page(1);await process_frame;check(bag.grid_scroll.scroll_vertical==384,"lower storage page reaches second sixty cells")
	await capture("expanded-storage")
	# Drag an actual upper-page item to the last expanded cell. Coordinates are
	# recomputed after scrolling; hidden items must never be clickable through it.
	bag.select_item("client-0");await process_frame;var source=bag.grid.get_children().filter(func(control):return control.item.id=="client-0")[0]
	var start=source.get_global_transform_with_canvas()*(source.size*.5)
	var motion=InputEventMouseMotion.new();motion.position=start;surface.push_input(motion,true)
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=start;surface.push_input(press,true)
	motion=InputEventMouseMotion.new();motion.position=start+Vector2(25,10);motion.relative=Vector2(25,10);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(motion,true);await process_frame
	check(surface.gui_is_dragging(),"actual pointer starts expanded inventory drag")
	bag.show_storage_page(1);await process_frame
	var destination=bag.grid.get_global_transform_with_canvas()*(Vector2(9,11)*bag.grid.CELL+Vector2.ONE*20)
	motion=InputEventMouseMotion.new();motion.position=destination;motion.relative=destination-start;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;surface.push_input(motion,true)
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=destination;surface.push_input(release,true);await process_frame
	check(p.bag_positions["client-0"].x==9 and p.bag_positions["client-0"].y==11,"actual drop persists last expanded cell: actual=%s at=%s"%[p.bag_positions["client-0"],destination])
	session.save_game();var restored=session.parse_save(session.save_path());check(restored!=null and restored.bag_positions["client-0"]==p.bag_positions["client-0"],"actual moved item survives save/load parsing")
	await capture("last-cell")
	names.data.equipment["chest:warrior:1"]=saved_name
	var file=FileAccess.open("res://../artifacts/inventory-expansion-v052.json",FileAccess.WRITE);file.store_string(JSON.stringify({"suite":"inventory_expansion_v052","checks":checks,"failures":failures,"captures":images},"\t"));file.close()
	game.stop_audio();session.disconnect_game();game.queue_free();await process_frame;await process_frame;print("INVENTORY_EXPANSION_V052 checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
