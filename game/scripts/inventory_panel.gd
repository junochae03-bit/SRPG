extends Panel
const Content=preload("res://scripts/content.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const ItemControl=preload("res://scripts/inventory_item_ui.gd")
const Art=preload("res://scripts/ui_art.gd")
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
var starter_button:Button
var costume_picker:OptionButton
var avatar_picker:OptionButton
var portrait:TextureRect
var detail_icon:TextureRect
var item_grade:Label
var wallet:Label
var filter_buttons=[]
func setup(owner_game):
	game=owner_game;position=Vector2(24,24);size=Vector2(1392,852);mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());Art.decorate(self,"paper",38)
	Art.picture(self,preload("res://scripts/icon_art.gd").function_icon("satchel"),Vector2(27,14),Vector2(76,76))
	game.label(self,"모험가의 소지품",Vector2(118,21),Vector2(700,42),32)
	wallet=game.label(self,"",Vector2(838,32),Vector2(344,32),23)
	game.button(self,"닫기  I",Vector2(1211,26),Vector2(147,43),game.toggle_bag)
	var gear=Art.panel(self,Vector2(24,103),Vector2(388,676),"paper",25)
	game.label(gear,"장비 · 모험가",Vector2(41,23),Vector2(324,34),24)
	stat_label=game.label(gear,"",Vector2(25,60),Vector2(340,40),16)
	Art.picture(gear,Art.texture("alcove"),Vector2(93,152),Vector2(203,366))
	portrait=Art.picture(gear,null,Vector2(118,237),Vector2(156,218))
	var positions={"head":Vector2(162,106),"weapon":Vector2(23,198),"chest":Vector2(23,310),"hands":Vector2(23,422),"legs":Vector2(300,198),"feet":Vector2(300,310),"accessory":Vector2(300,422)}
	for slot in Content.SLOTS:
		var control=ItemControl.new();control.configure(self,{},slot);control.position=positions[slot];control.size=Vector2(66,73);gear.add_child(control);equipment_controls[slot]=control
		var caption=game.label(gear,Content.SLOT_NAMES[slot],positions[slot]+Vector2(-7,76),Vector2(82,24),15);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	game.label(gear,"외형 보관함",Vector2(27,546),Vector2(340,26),18)
	avatar_picker=picker(gear,Vector2(25,578));avatar_picker.add_item("기본 캐릭터 · 직업에 맞춤")
	for key in Content.AVATARS:avatar_picker.add_item("기본 · "+Content.AVATARS[key])
	avatar_picker.item_selected.connect(func(index):game.session.act("avatar","auto" if index==0 else Content.AVATARS.keys()[index-1]);refresh(true))
	costume_picker=picker(gear,Vector2(25,622))
	for key in Content.COSTUMES:costume_picker.add_item("코스튬 · "+Content.COSTUMES[key])
	costume_picker.item_selected.connect(func(index):game.session.act("costume",Content.COSTUMES.keys()[index]);refresh(true))
	var storage=Art.panel(self,Vector2(427,103),Vector2(551,676),"paper",25)
	game.label(storage,"여행 가방",Vector2(41,23),Vector2(264,34),25)
	capacity=game.label(storage,"",Vector2(388,25),Vector2(142,28),19)
	for i in range(4):filter_buttons.append(game.button(storage,["전체","장비","소모품","재료"][i],Vector2(25+i*127,77),Vector2(121,42),func():filter_index=i;refresh(true)))
	grid=preload("res://scripts/inventory_grid_ui.gd").new();grid.setup(self);grid.position=Vector2(25,139);storage.add_child(grid)
	game.label(storage,"모든 물건은 한 칸 · 끌어서 이동하거나 장착하세요",Vector2(26,455),Vector2(506,29),16)
	game.label(storage,"일반     ◆ 마법     ◆ 희귀     ✦ 선택한 아이템",Vector2(26,494),Vector2(506,29),16)
	starter_button=game.button(storage,"연습 무기 4종 받기",Vector2(25,606),Vector2(501,45),func():game.session.act("claim_starters");refresh(true))
	Art.picture(storage,Art.texture("crest"),Vector2(28,540),Vector2(47,48))
	game.label(storage,"장착품은 가방 칸을 쓰지 않습니다.\n물약과 같은 재료는 한 묶음으로 보관합니다.",Vector2(88,543),Vector2(438,48),16)
	var detail=Art.panel(self,Vector2(993,103),Vector2(366,676),"paper",25)
	Art.picture(detail,Art.texture("medallion"),Vector2(22,22),Vector2(99,99))
	detail_icon=Art.picture(detail,null,Vector2(39,38),Vector2(63,63))
	game.label(detail,"선택한 전리품",Vector2(135,28),Vector2(204,31),21)
	item_grade=game.label(detail,"",Vector2(136,72),Vector2(208,38),16)
	detail_name=game.label(detail,"",Vector2(25,141),Vector2(318,76),25);detail_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_body=game.label(detail,"",Vector2(25,229),Vector2(318,305),18);detail_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	primary=game.button(detail,"장착하기",Vector2(25,552),Vector2(317,49),activate_selected,true)
	discard_button=game.button(detail,"정리 · 금화 +3",Vector2(25,618),Vector2(317,39),func():game.session.act("discard",selected_id);refresh(true))
	game.label(self,"소지품을 살피는 동안 모험은 잠시 멈춥니다.  I / ESC로 닫기",Vector2(70,793),Vector2(1228,25),17)
	hide()
func picker(parent:Node,at:Vector2)->OptionButton:
	var result=OptionButton.new();result.position=at;result.size=Vector2(338,37);result.add_theme_font_override("font",game.fonts);result.add_theme_font_size_override("font_size",16);result.add_theme_color_override("font_color",game.PALE)
	for state in ["normal","hover","pressed","focus"]:
		var box=StyleBoxEmpty.new();box.content_margin_left=12;box.content_margin_right=12;result.add_theme_stylebox_override(state,box)
	result.get_popup().add_theme_stylebox_override("panel",game.style(Color.WHITE));result.get_popup().add_theme_font_override("font",game.fonts);result.get_popup().add_theme_color_override("font_color",game.PALE)
	parent.add_child(result);Art.decorate(result,"paper",9);return result
func player()->Dictionary:return game.session.state.players.get(game.session.local_id,{})
func item_by_id(id:String)->Dictionary:return Inventory.find_item(player(),id)
func matches_filter(item:Dictionary)->bool:
	return filter_index==0 or filter_index==1 and item.category in ["weapon","armor","accessory"] or filter_index==2 and item.category=="consumable" or filter_index==3 and item.category=="material"
func select_item(id:String):selected_id=id;refresh(true)
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
	portrait.texture=preload("res://scripts/gat_art.gd").texture(preload("res://scripts/gat_art.gd").avatar(p),0) if Content.gat_appearance(p) else game.textures[Content.costume_role(p)].idle[0]
	portrait.material=preload("res://scripts/gat_art.gd").material() if Content.gat_appearance(p) else null
	avatar_picker.select(0 if p.get("avatar","auto")=="auto" else Content.AVATARS.keys().find(p.avatar)+1);costume_picker.select(Content.COSTUMES.keys().find(p.costume))
	wallet.text="보유 금화   %s G" % p.gold
	capacity.text="%d / 60 칸" % Inventory.bag_items(p).size()
	for i in range(filter_buttons.size()):filter_buttons[i].text=("• " if i==filter_index else "")+["전체","장비","소모품","재료"][i]
	starter_button.disabled=p.training_given or not game.dungeon.in_town(p.pos)
	starter_button.text="연습 무기 수령 완료" if p.training_given else "연습 무기 4종 받기" if game.dungeon.in_town(p.pos) else "마을에서 연습 무기 받기"
	var item=item_by_id(selected_id)
	primary.visible=not item.is_empty() and item.category!="material"
	discard_button.visible=not item.is_empty() and item.category in ["weapon","armor","accessory"] and not Inventory.is_equipped(p,selected_id)
	detail_icon.texture=null if item.is_empty() else Content.icon_texture(item)
	if item.is_empty():
		detail_name.text="전리품을 살펴보세요";item_grade.text="아이템 선택 대기";detail_body.text="가방이나 장비의 그림을 선택하면 현재 장비와 능력치를 비교합니다.\n\n무기와 방어구는 캐릭터 옆의 알맞은 자리에 끌어 놓아도 장착됩니다.";return
	detail_name.text=item.name;item_grade.text=["일반","마법","희귀"][int(item.rarity)]+" · "+Content.SLOT_NAMES.get(item.get("slot",""),"소모품" if item.category=="consumable" else "제작 재료")
	if item.category in ["weapon","armor","accessory"]:
		var trial=p.duplicate(true);trial.equipment[item.slot]=item.id
		if item.slot=="weapon":trial.equipped=item.id
		game.session.sim.recalculate(trial)
		var damage=game.session.sim.damage_for(p);var next_damage=game.session.sim.damage_for(trial)
		detail_body.text="착용 전 → 착용 후\n공격력  %d → %d  (%+d)\n방어력  %d → %d  (%+d)\n생명력  %d → %d  (%+d)\n기력     %d → %d\n\n강화  +%d / +5\n%s" % [damage,next_damage,next_damage-damage,p.defense,trial.defense,trial.defense-p.defense,p.max_hp,trial.max_hp,trial.max_hp-p.max_hp,p.max_stamina,trial.max_stamina,item.get("upgrade",0),preload("res://scripts/equipment_catalog.gd").AFFIXES.get(item.get("affix","none"),{}).get("name","")]
		if item.category=="weapon":detail_body.text+="\n"+Content.WEAPONS[item.weapon_type].description
		primary.text="장착 해제" if Inventory.is_equipped(p,selected_id) else "장착하기"
	elif item.category=="consumable":
		detail_body.text="생명력 %d 회복\n보유 %d개 / 최대 20개\n재사용 대기 2초\n\n전투 중에는 1키로 빠르게 사용할 수 있습니다." % [60+Content.skill_bonus(p,"potion_power"),item.count];primary.text="물약 사용하기"
	else:detail_body.text="보유 %d개\n\n마을에서 제작과 장비 정비에 사용합니다.\n\n별씨앗 · 물약 조제\n광석 · 장비 강화\n정수 · 장비 옵션 재련" % item.count
