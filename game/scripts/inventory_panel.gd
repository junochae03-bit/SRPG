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
	for i in range(4):filter_buttons.append(game.button(storage,["전체","장비","소모품","재료"][i],Vector2(44+i*150,103),Vector2(142,46),func():filter_index=i;refresh(true)))
	grid=preload("res://scripts/inventory_grid_ui.gd").new();grid.setup(self);grid.position=Vector2(20,187);storage.add_child(grid)
	var detail=Art.panel(self,Vector2(1116,103),Vector2(420,725),"paper",25)
	Art.picture(detail,Art.texture("medallion"),Vector2(35,32),Vector2(112,112))
	detail_icon=Art.picture(detail,null,Vector2(49,46),Vector2(84,84))
	game.label(detail,"선택한 전리품",Vector2(163,40),Vector2(213,32),22)
	item_grade=game.label(detail,"",Vector2(164,84),Vector2(212,56),18);item_grade.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_scroll=ScrollContainer.new();detail_scroll.position=Vector2(44,164);detail_scroll.size=Vector2(332,413);detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail.add_child(detail_scroll)
	var content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",23);detail_scroll.add_child(content)
	detail_name=flow_label(content,24);detail_name.add_theme_constant_override("line_spacing",5)
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
func matches_filter(item:Dictionary)->bool:
	return filter_index==0 or filter_index==1 and item.category in ["weapon","armor","accessory"] or filter_index==2 and item.category=="consumable" or filter_index==3 and item.category=="material"
func select_item(id:String):
	if selected_id!=id:detail_scroll.scroll_vertical=0
	selected_id=id;refresh(true)
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
	var next=JSON.stringify([p.inventory,p.equipment,p.bag_positions,p.materials,p.potions,p.class_id,p.costume,p.get("avatar","auto"),p.level,p.hp,p.gold,p.skill_ranks,p.stats,selected_id,filter_index])
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
	capacity.text="%d / 60 칸" % Inventory.bag_items(p).size()
	for i in range(filter_buttons.size()):
		filter_buttons[i].text=["전체","장비","소모품","재료"][i];Library.attach(filter_buttons[i],"selected" if i==filter_index else ["filter","equip","consumable","material"][i],20)
	var item=item_by_id(selected_id)
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
		var damage=game.session.sim.damage_for(p);var next_damage=game.session.sim.damage_for(trial)
		var eq=preload("res://scripts/equipment_catalog.gd")
		var reason=eq.reason(p,item)
		detail_body.text=eq.restriction_text(item)+("\n"+reason if not reason.is_empty() else "")+"\n\n장착 시 능력치\n공격  %d → %d (%+d)\n방어  %d → %d (%+d)\n생명  %d → %d\n\n추가 옵션\n%s"%[damage,next_damage,next_damage-damage,p.defense,trial.defense,trial.defense-p.defense,p.max_hp,trial.max_hp,eq.option_text(item)]
		primary.disabled=not Inventory.is_equipped(p,selected_id) and not reason.is_empty()
		primary.tooltip_text=reason
		primary.text="장착 해제" if Inventory.is_equipped(p,selected_id) else "장착하기"
		Library.attach(primary,"unequip" if Inventory.is_equipped(p,selected_id) else "locked" if primary.disabled else "equip",22)
	elif item.category=="consumable":
		detail_body.text="생명력 %d 회복\n보유 %d개 / 최대 20개\n재사용 대기 2초\n\n전투 중에는 1키로 빠르게 사용할 수 있습니다." % [60+roundi(p.max_hp*.20)+Content.skill_bonus(p,"potion_power"),item.count];primary.text="물약 사용하기"
		Library.attach(primary,"consumable",22)
	else:detail_body.text="보유 %d개\n\n마을에서 제작과 장비 정비에 사용합니다.\n\n별씨앗 · 물약 조제\n광석 · 장비 강화\n정수 · 장비 옵션 재련" % item.count

func refresh_appearance(p:Dictionary):
	var allowed_avatars=Content.avatar_options(p.class_id);var allowed_costumes=Content.costume_options(p.class_id)
	if avatar_keys!=allowed_avatars:
		avatar_keys=allowed_avatars;avatar_picker.clear()
		for key in avatar_keys:avatar_picker.add_item("기본 · "+("직업에 맞춤" if key=="auto" else Content.AVATARS[key]))
	if costume_keys!=allowed_costumes:
		costume_keys=allowed_costumes;costume_picker.clear()
		for key in costume_keys:costume_picker.add_item("의상 · "+Content.COSTUMES[key])
	avatar_picker.select(avatar_keys.find(p.get("avatar","auto")));costume_picker.select(costume_keys.find(p.costume))
	appearance_status.text="현재 외형 · "+("기본 캐릭터" if p.costume=="none" else "코스튬 착용 중")
