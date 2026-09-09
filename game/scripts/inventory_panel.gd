extends Panel
const Content=preload("res://scripts/content.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const ItemControl=preload("res://scripts/inventory_item_ui.gd")
const Art=preload("res://scripts/ui_art.gd")
const Library=preload("res://scripts/icon_library.gd")
var game
var grid
var selected_id=""
var filter_index=0
var signature=""
var equipment_controls={}
var detail_name:Label
var detail_body:Label
var stat_label:Label
var capacity:Label
var primary:Button
var discard_button:Button
var costume_picker:OptionButton
var avatar_picker:OptionButton
var portrait:TextureRect
var detail_icon:TextureRect
var item_grade:Label
var wallet:Label
var filter_buttons=[]
var detail_scroll:ScrollContainer
var appearance_status:Label
var avatar_keys:Array=[]
var costume_keys:Array=[]
var grid_scroll:ScrollContainer
var storage_buttons:Array=[]
var comparison_panel:VBoxContainer
var comparison_grid:GridContainer
var comparison_values:Array=[]
var comparison_current_icon:TextureRect
var comparison_current_name:Label
var comparison_notice:Label
var comparison_rows:Array=[]
var comparison_current_id=""
var comparison_selected_id=""
var pending_storage_scroll:Dictionary={}
func setup(owner_game):
	game=owner_game;size=Vector2(1560,852);mouse_filter=Control.MOUSE_FILTER_STOP
	fit_viewport()
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());Art.decorate(self,"paper",38)
	Library.picture(self,"bag",Vector2(34,20),Vector2(72,72))
	game.label(self,"모험가의 소지품",Vector2(122,35),Vector2(700,42),32)
	Library.picture(self,"gold",Vector2(1030,40),Vector2(28,28));wallet=game.label(self,"",Vector2(1068,38),Vector2(287,32),23)
	Library.attach(game.button(self,"닫기",Vector2(1376,32),Vector2(140,44),game.toggle_bag),"close",22)
	var gear=Art.panel(self,Vector2(24,103),Vector2(380,725),"paper",25)
	Library.picture(gear,"equip",Vector2(38,39),Vector2(28,28));game.label(gear,"장비",Vector2(80,38),Vector2(252,34),26)
	stat_label=game.label(gear,"",Vector2(44,84),Vector2(292,48),17)
	Art.picture(gear,Art.texture("alcove"),Vector2(86,219),Vector2(208,342))
	portrait=Art.picture(gear,null,Vector2(108,254),Vector2(164,244))
	var positions={"head":Vector2(148,144),"weapon":Vector2(22,241),"chest":Vector2(22,348),"hands":Vector2(22,455),"legs":Vector2(274,241),"feet":Vector2(274,348),"accessory":Vector2(274,455)}
	for slot in Content.SLOTS:
		var control=ItemControl.new();control.configure(self,{},slot);control.position=positions[slot];control.size=Vector2(84,84);gear.add_child(control);equipment_controls[slot]=control
		var caption=game.label(gear,Content.SLOT_NAMES[slot],positions[slot]+Vector2(-5,85),Vector2(94,25),17);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	appearance_status=game.label(gear,"",Vector2(44,580),Vector2(292,25),17)
	avatar_picker=picker(gear,Vector2(24,613))
	avatar_picker.item_selected.connect(func(index):game.session.act("avatar",avatar_keys[index]);refresh(true))
	costume_picker=picker(gear,Vector2(24,662))
	costume_picker.item_selected.connect(func(index):game.session.act("costume",costume_keys[index]);refresh(true))
	var storage=Art.panel(self,Vector2(420,103),Vector2(680,725),"paper",25)
	game.label(storage,"여행 가방",Vector2(44,38),Vector2(330,36),27)
	Library.picture(storage,"bag",Vector2(471,42),Vector2(26,26));capacity=game.label(storage,"",Vector2(508,40),Vector2(129,30),20)
	for i in range(4):filter_buttons.append(game.button(storage,["전체","장비","소모품","재료"][i],Vector2(44+i*150,103),Vector2(142,46),func():show_storage_filter(i)))
	grid_scroll=ScrollContainer.new();grid_scroll.position=Vector2(12,187);grid_scroll.size=Vector2(656,384);grid_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;grid_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS;grid_scroll.mouse_filter=Control.MOUSE_FILTER_STOP;storage.add_child(grid_scroll)
	grid=preload("res://scripts/inventory_grid_ui.gd").new();grid.setup(self);grid.custom_minimum_size=grid.size;grid_scroll.add_child(grid)
	for i in range(2):
		var page=game.button(storage,"",Vector2(44+i*307,606),Vector2(293,43),func():show_storage_page(i));storage_buttons.append(page)
		page.mouse_entered.connect(func():if get_viewport().gui_is_dragging():show_storage_page(i))
	grid_scroll.get_v_scroll_bar().value_changed.connect(func(_value):refresh_storage_buttons())
	grid_scroll.sort_children.connect(finish_storage_scroll,CONNECT_DEFERRED)
	visibility_changed.connect(func():
		if not is_visible_in_tree():pending_storage_scroll.clear()
		elif not pending_storage_scroll.is_empty():grid_scroll.queue_sort())
	refresh_storage_buttons()
	var detail=Art.panel(self,Vector2(1116,103),Vector2(420,725),"paper",25)
	Art.picture(detail,Art.texture("medallion"),Vector2(35,32),Vector2(112,112))
	detail_icon=Art.picture(detail,null,Vector2(49,46),Vector2(84,84))
	game.label(detail,"선택한 전리품",Vector2(163,40),Vector2(213,32),22)
	item_grade=game.label(detail,"",Vector2(164,84),Vector2(212,56),18);item_grade.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_scroll=ScrollContainer.new();detail_scroll.position=Vector2(44,164);detail_scroll.size=Vector2(332,413);detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail.add_child(detail_scroll)
	var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",8);detail_scroll.add_child(content)
	detail_name=flow_label(content,22);detail_name.add_theme_constant_override("line_spacing",1)
	comparison_notice=flow_label(content,17)
	comparison_panel=VBoxContainer.new();comparison_panel.add_theme_constant_override("separation",6);content.add_child(comparison_panel)
	var current_row=HBoxContainer.new();current_row.add_theme_constant_override("separation",12);comparison_panel.add_child(current_row)
	comparison_current_icon=TextureRect.new();comparison_current_icon.custom_minimum_size=Vector2(44,44);comparison_current_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;comparison_current_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;comparison_current_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;current_row.add_child(comparison_current_icon)
	var current_text=VBoxContainer.new();current_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;current_row.add_child(current_text)
	flow_label(current_text,16).text="현재 장착";comparison_current_name=flow_label(current_text,17)
	comparison_grid=GridContainer.new();comparison_grid.columns=4;comparison_grid.add_theme_constant_override("h_separation",5);comparison_grid.add_theme_constant_override("v_separation",3);comparison_panel.add_child(comparison_grid)
	for entry in [["능력치",92],["현재",50],["교체 후",50],["변화",88]]:
		var label=flow_label(comparison_grid,14);label.custom_minimum_size.x=entry[1];label.text=entry[0]
	for _i in range(5):
		var title=flow_label(comparison_grid,16);title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;title.custom_minimum_size.y=30
		var before=flow_label(comparison_grid,17);before.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var after=flow_label(comparison_grid,17);after.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var delta=flow_label(comparison_grid,15);delta.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;comparison_values.append([title,before,after,delta])
	detail_body=flow_label(content,18);detail_body.add_theme_constant_override("line_spacing",6)
	primary=game.button(detail,"장착하기",Vector2(36,596),Vector2(348,52),activate_selected,true)
	discard_button=game.button(detail,"정리 · 금화 +3",Vector2(36,661),Vector2(348,40),func():game.session.act("discard",selected_id);refresh(true))
	Library.attach(primary,"equip",22);Library.attach(discard_button,"sell",22)
	hide()

func fit_viewport():
	var width=game.get_viewport().get_visible_rect().size.x
	var factor=minf(1.0,(width-40.0)/1560.0)
	scale=Vector2.ONE*factor;position=Vector2((width-size.x*factor)*.5-game.ui_offset().x,24)

func flow_label(parent:Node,font_size:int)->Label:
	var result=Label.new();result.add_theme_font_override("font",game.fonts);result.add_theme_font_size_override("font_size",font_size);result.add_theme_color_override("font_color",game.PALE)
	result.size_flags_horizontal=Control.SIZE_EXPAND_FILL;result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(result);return result

func picker(parent:Node,at:Vector2)->OptionButton:
	var result=OptionButton.new();result.position=at;result.size=Vector2(332,39);result.add_theme_font_override("font",game.fonts);result.add_theme_font_size_override("font_size",17);result.add_theme_color_override("font_color",game.PALE)
	for state in ["font_hover_color","font_pressed_color","font_focus_color"]:result.add_theme_color_override(state,game.PALE)
	for state in ["normal","hover","pressed","focus"]:
		var box=StyleBoxEmpty.new();box.content_margin_left=12;box.content_margin_right=12;result.add_theme_stylebox_override(state,box)
	var popup=result.get_popup();popup.max_size=Vector2i(600,440)
	var paper=StyleBoxEmpty.new()
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:paper.set_content_margin(side,10)
	popup.add_theme_stylebox_override("panel",paper);popup.add_theme_font_override("font",game.fonts);popup.add_theme_font_size_override("font_size",18);popup.add_theme_color_override("font_color",game.PALE);popup.add_theme_constant_override("v_separation",8)
	popup.add_theme_stylebox_override("hover",StyleBoxEmpty.new());popup.add_theme_color_override("font_hover_color",Color("89552e"))
	var background_layer=CanvasLayer.new();background_layer.layer=-1;popup.add_child(background_layer)
	var background=Control.new();background.mouse_filter=Control.MOUSE_FILTER_IGNORE;background_layer.add_child(background);Art.decorate(background,"paper",10)
	popup.size_changed.connect(func():background.size=Vector2(popup.size))
	popup.about_to_popup.connect(func():background.size=Vector2(popup.size))
	parent.add_child(result);Art.decorate(result,"paper",9);return result
func player()->Dictionary:return game.session.state.players.get(game.session.local_id,{})
func item_by_id(id:String)->Dictionary:return Inventory.find_item(player(),id)
func show_storage_page(index:int):
	pending_storage_scroll={"offset":clampi(index,0,1)*6*grid.CELL};apply_storage_scroll();grid_scroll.queue_sort()
func show_storage_filter(index:int):
	# 직접 고른 구간과 필터는 이전 아이템 선택의 예약 스크롤보다 우선합니다.
	pending_storage_scroll={"offset":grid_scroll.scroll_vertical}
	filter_index=clampi(index,0,filter_buttons.size()-1);refresh(true);grid_scroll.queue_sort()
func apply_storage_scroll():
	if pending_storage_scroll.has("offset"):
		grid_scroll.scroll_vertical=int(pending_storage_scroll.offset)
	elif pending_storage_scroll.has("item"):
		var id=str(pending_storage_scroll.item);var positions=player().get("bag_positions",{})
		if id!=selected_id or not positions.has(id):return
		var row=int(positions[id].y)*grid.CELL
		if row<grid_scroll.scroll_vertical:grid_scroll.scroll_vertical=row
		elif row+grid.CELL>grid_scroll.scroll_vertical+grid_scroll.size.y:grid_scroll.scroll_vertical=int(row+grid.CELL-grid_scroll.size.y)
	refresh_storage_buttons()
func finish_storage_scroll():
	if pending_storage_scroll.is_empty() or not is_visible_in_tree():return
	# 처음 표시할 때는 컨테이너가 스크롤 범위를 계산한 뒤 적용해야 합니다.
	if not get_viewport().gui_is_dragging():apply_storage_scroll()
	pending_storage_scroll.clear()
func refresh_storage_buttons():
	for i in range(storage_buttons.size()):
		var active=(grid_scroll.scroll_vertical>=3*grid.CELL)==(i==1)
		storage_buttons[i].text=("◆ " if active else "")+("1–60" if i==0 else "61–120")
func matches_filter(item:Dictionary)->bool:
	return filter_index==0 or filter_index==1 and item.category in ["weapon","armor","accessory"] or filter_index==2 and item.category=="consumable" or filter_index==3 and item.category=="material"
func select_item(id:String):
	if selected_id!=id:detail_scroll.scroll_vertical=0
	selected_id=id;pending_storage_scroll={"item":id};refresh(true)
	apply_storage_scroll();grid_scroll.queue_sort()
func quick_activate(id:String):
	select_item(id)
	var item=item_by_id(id)
	if item.is_empty() or item.category=="material":return
	activate_selected()
func activate_selected():
	var item=item_by_id(selected_id)
	if item.is_empty():return
	if item.category=="consumable":game.session.act("potion")
	elif Inventory.is_equipped(player(),selected_id):game.session.act("unequip",item.slot)
	else:game.session.act("equip",selected_id)
	refresh(true)
func _process(_delta):
	if visible:refresh()
func refresh(force=false):
	var p=player()
	if p.is_empty() or get_viewport().gui_is_dragging():return
	var next=JSON.stringify([p.inventory,p.equipment,p.bag_positions,p.materials,p.potions,p.class_id,p.costume,p.get("avatar","auto"),p.get("owned_appearances",[]),preload("res://scripts/sprite_names.gd").revision,p.level,p.hp,p.gold,p.skill_ranks,p.stats,selected_id,filter_index])
	if not force and next==signature:return
	signature=next;grid.rebuild()
	for slot in equipment_controls:
		var control=equipment_controls[slot];var item=item_by_id(p.equipment.get(slot,""))
		control.item=item;control.picture=null if item.is_empty() else Content.icon_texture(item);control.selected=selected_id!="" and item.get("id")==selected_id;control.queue_redraw()
	stat_label.text="%s · LV.%d\n공격 %d   방어 %d   생명력 %d" % [Content.CLASSES[p.class_id].name,p.level,game.session.sim.damage_for(p),p.defense,p.max_hp]
	portrait.texture=preload("res://scripts/gat_art.gd").frame(p,0.).texture if Content.gat_appearance(p) else game.textures[Content.costume_role(p)].idle[0]
	portrait.material=preload("res://scripts/gat_art.gd").material() if Content.gat_appearance(p) else null
	refresh_appearance(p)
	wallet.text="보유 금화   %s G" % p.gold
	capacity.text="%d / %d" % [Inventory.bag_items(p).size(),Inventory.CAPACITY]
	for i in range(filter_buttons.size()):
		filter_buttons[i].text=["전체","장비","소모품","재료"][i];Library.attach(filter_buttons[i],"selected" if i==filter_index else ["filter","equip","consumable","material"][i],20)
	var item=item_by_id(selected_id)
	comparison_panel.hide();comparison_notice.hide();comparison_rows=[];comparison_current_id="";comparison_selected_id=""
	primary.visible=not item.is_empty() and item.category!="material"
	discard_button.visible=not item.is_empty() and item.category in ["weapon","armor","accessory"] and not Inventory.is_equipped(p,selected_id)
	detail_icon.texture=null if item.is_empty() else Content.icon_texture(item)
	detail_icon.material=Art.icon_material(detail_icon.texture)
	if item.is_empty():
		detail_name.text="모험의 전리품";item_grade.text="";detail_body.text="";return
	primary.disabled=false
	detail_name.text=item.name;item_grade.text=preload("res://scripts/equipment_catalog.gd").GRADES[int(item.rarity)]+" · "+Content.SLOT_NAMES.get(item.get("slot",""),"소모품" if item.category=="consumable" else "제작 재료")
	if item.category in ["weapon","armor","accessory"]:item_grade.text+="\n강화 +%d"%int(item.get("upgrade",0))
	if item.category in ["weapon","armor","accessory"]:
		var trial=p.duplicate(true);trial.equipment[item.slot]=item.id
		if item.slot=="weapon":trial.equipped=item.id
		game.session.sim.recalculate(trial)
		var eq=preload("res://scripts/equipment_catalog.gd")
		var reason=eq.reason(p,item)
		var worn=Inventory.is_equipped(p,selected_id);comparison_current_id=str(p.equipment.get(item.slot,""));comparison_selected_id=str(item.id)
		var current_item=Inventory.find_item(p,comparison_current_id)
		comparison_notice.show();comparison_notice.text="현재 장착 중" if worn else reason if not reason.is_empty() else "같은 부위의 장비와 비교"
		comparison_notice.add_theme_color_override("font_color",Color("963c32") if not reason.is_empty() else game.PALE)
		if not worn and reason.is_empty():
			comparison_panel.show();comparison_current_name.text=str(current_item.get("name","장착한 장비 없음"));comparison_current_icon.texture=Content.icon_texture(current_item) if not current_item.is_empty() else Library.texture(item.slot);comparison_current_icon.material=Art.icon_material(comparison_current_icon.texture)
			comparison_rows=[["물리 공격",game.session.sim.damage_for(p,"physical"),game.session.sim.damage_for(trial,"physical")],["마법 공격",game.session.sim.damage_for(p,"magic"),game.session.sim.damage_for(trial,"magic")],["방어",p.defense,trial.defense],["마법 방어",p.magic_defense,trial.magic_defense],["최대 생명력",p.max_hp,trial.max_hp]]
			for i in range(comparison_rows.size()):
				var row=comparison_rows[i];var labels=comparison_values[i];var difference=int(row[2])-int(row[1])
				labels[0].text=row[0];labels[1].text=str(int(row[1]));labels[2].text=str(int(row[2]));labels[3].text=("▲ +%d"%difference if difference>0 else "▼ %d"%difference if difference<0 else "— 동일")
				labels[3].add_theme_color_override("font_color",Color("287243") if difference>0 else Color("a33f35") if difference<0 else Color("697269"))
		var current_options=eq.option_text(current_item) if not current_item.is_empty() else "없음"
		detail_body.text=eq.restriction_text(item)+"\n\n"+("추가 옵션\n"+eq.option_text(item) if worn else "추가 옵션 · 현재 → 선택\n\n현재 장착\n"+current_options+"\n\n선택한 장비\n"+eq.option_text(item))
		primary.disabled=not Inventory.is_equipped(p,selected_id) and not reason.is_empty()
		if worn and Inventory.bag_items(p).size()>=Inventory.CAPACITY:primary.disabled=true;reason="가방이 가득 찼습니다"
		primary.tooltip_text=reason
		primary.text="장착 해제" if Inventory.is_equipped(p,selected_id) else "장착하기"
		Library.attach(primary,"unequip" if Inventory.is_equipped(p,selected_id) else "locked" if primary.disabled else "equip",22)
	elif item.category=="consumable":
		detail_body.text="생명력 %d 회복\n보유 %d개 / 최대 20개\n재사용 대기 2초" % [60+roundi(p.max_hp*.20)+Content.skill_bonus(p,"potion_power"),item.count];primary.text="물약 사용하기"
		Library.attach(primary,"consumable",22)
	else:detail_body.text="보유 %d개\n\n마을에서 제작과 장비 정비에 사용합니다.\n\n별씨앗 · 물약 조제\n광석 · 장비 강화\n정수 · 장비 옵션 재련" % item.count

func refresh_appearance(p:Dictionary):
	var wardrobe=preload("res://scripts/wardrobe.gd")
	var allowed_avatars=wardrobe.owned_avatars(p);var allowed_costumes=wardrobe.owned_costumes(p)
	if avatar_keys!=allowed_avatars or avatar_picker.get_meta("class_id","")!=p.class_id or int(avatar_picker.get_meta("name_revision",-1))!=preload("res://scripts/sprite_names.gd").revision:
		avatar_keys=allowed_avatars;avatar_picker.clear()
		for key in avatar_keys:avatar_picker.add_item(wardrobe.label("base:"+p.class_id if key=="auto" else "avatar:"+key))
		avatar_picker.set_meta("name_revision",preload("res://scripts/sprite_names.gd").revision)
		avatar_picker.set_meta("class_id",p.class_id)
	if costume_keys!=allowed_costumes or int(costume_picker.get_meta("name_revision",-1))!=preload("res://scripts/sprite_names.gd").revision:
		costume_keys=allowed_costumes;costume_picker.clear()
		for key in costume_keys:costume_picker.add_item("직업 기본 외형" if key=="none" else wardrobe.label("costume:"+key))
		costume_picker.set_meta("name_revision",preload("res://scripts/sprite_names.gd").revision)
	avatar_picker.select(avatar_keys.find(p.get("avatar","auto")));costume_picker.select(costume_keys.find(p.costume))
	appearance_status.text="현재 외형 · "+("기본 캐릭터" if p.costume=="none" else "코스튬 착용 중")
