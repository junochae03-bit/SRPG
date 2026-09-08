extends Panel

const Content=preload("res://scripts/content.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const ItemControl=preload("res://scripts/inventory_item_ui.gd")
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

func setup(owner_game):
	game=owner_game
	position=Vector2(116,94);size=Vector2(1208,712)
	add_theme_stylebox_override("panel",game.style(Color("edf3eafa"),Color("a3b4a5"),12))
	mouse_filter=Control.MOUSE_FILTER_STOP
	game.label(self,"모험가의 소지품",Vector2(28,18),Vector2(800,45),30)
	game.label(self,"EQUIPMENT  /  INVENTORY",Vector2(30,62),Vector2(750,24),12,game.MUTED)
	game.button(self,"닫기  I",Vector2(1062,22),Vector2(116,40),game.toggle_bag)
	var gear=game.panel(self,Vector2(20,98),Vector2(350,556),Color("dde7de"))
	game.label(gear,"장비",Vector2(18,12),Vector2(300,34),23)
	stat_label=game.label(gear,"",Vector2(18,48),Vector2(316,28),14)
	portrait=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position=Vector2(127,183);portrait.size=Vector2(96,178);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	gear.add_child(portrait)
	var positions={"head":Vector2(143,91),"chest":Vector2(28,184),"hands":Vector2(28,283),"legs":Vector2(253,184),"feet":Vector2(253,283),"weapon":Vector2(28,382),"accessory":Vector2(253,382)}
	for slot in Content.SLOTS:
		var control=ItemControl.new();control.configure(self,{},slot)
		control.position=positions[slot];control.size=Vector2(64,72)
		gear.add_child(control);equipment_controls[slot]=control
		var caption=game.label(gear,Content.SLOT_NAMES[slot],positions[slot]+Vector2(-8,73),Vector2(80,22),13)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	avatar_picker=OptionButton.new();avatar_picker.position=Vector2(20,480);avatar_picker.size=Vector2(310,30)
	avatar_picker.add_theme_font_override("font",game.fonts);avatar_picker.add_theme_color_override("font_color",game.PALE)
	avatar_picker.add_theme_stylebox_override("normal",game.style(Color("f4f6e9")))
	avatar_picker.add_item("기본 캐릭터 · 직업에 맞춤")
	for key in Content.AVATARS:avatar_picker.add_item("기본 · "+Content.AVATARS[key])
	avatar_picker.item_selected.connect(func(index):game.session.act("avatar","auto" if index==0 else Content.AVATARS.keys()[index-1]);refresh(true))
	gear.add_child(avatar_picker)
	costume_picker=OptionButton.new();costume_picker.position=Vector2(20,518);costume_picker.size=Vector2(310,30)
	costume_picker.add_theme_font_override("font",game.fonts);costume_picker.add_theme_color_override("font_color",game.PALE)
	costume_picker.add_theme_stylebox_override("normal",game.style(Color("f4f6e9")))
	for key in Content.COSTUMES:costume_picker.add_item("코스튬 · "+Content.COSTUMES[key])
	costume_picker.item_selected.connect(func(index):game.session.act("costume",Content.COSTUMES.keys()[index]);refresh(true))
	gear.add_child(costume_picker)
	var storage=game.panel(self,Vector2(388,98),Vector2(500,556),Color("f5f6ea"))
	game.label(storage,"가방",Vector2(20,12),Vector2(290,34),23)
	capacity=game.label(storage,"",Vector2(333,18),Vector2(145,24),14,game.MUTED)
	var filters=["전체","장비","소모품","기타"]
	for i in range(filters.size()):
		game.button(storage,filters[i],Vector2(20+i*116,65),Vector2(108,34),func():filter_index=i;refresh(true))
	grid=preload("res://scripts/inventory_grid_ui.gd").new();grid.setup(self);grid.position=Vector2(20,115);storage.add_child(grid)
	game.label(storage,"모든 아이템은 한 칸 · 드래그로 이동\n녹색: 수납 가능   /   빨간색: 겹침 또는 공간 부족",Vector2(20,409),Vector2(465,54),15,game.MUTED)
	starter_button=game.button(storage,"연습 무기 4종 받기",Vector2(20,485),Vector2(460,44),func():game.session.act("claim_starters");refresh(true))
	var detail=game.panel(self,Vector2(906,98),Vector2(282,556),Color("e1e9df"))
	game.label(detail,"아이템 정보",Vector2(18,12),Vector2(246,34),23)
	detail_name=game.label(detail,"",Vector2(18,67),Vector2(244,82),23);detail_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_body=game.label(detail,"",Vector2(18,152),Vector2(244,226),17);detail_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	primary=game.button(detail,"장착",Vector2(18,404),Vector2(246,47),activate_selected,true)
	discard_button=game.button(detail,"정리 · 금화 +3",Vector2(18,465),Vector2(246,40),func():game.session.act("discard",selected_id);refresh(true))
	game.label(self,"가방을 열면 모험이 잠시 멈춥니다. 장착 중인 물건은 가방 공간을 차지하지 않습니다.",Vector2(28,669),Vector2(1150,24),15,game.MUTED)
	hide()

func player() -> Dictionary:return game.session.state.players.get(game.session.local_id,{})
func item_by_id(id: String) -> Dictionary:return Inventory.find_item(player(),id)
func matches_filter(item: Dictionary) -> bool:
	return filter_index==0 or (filter_index==1 and item.category in ["weapon","armor","accessory"]) or (filter_index==2 and item.category=="consumable") or (filter_index==3 and item.category=="material")
func select_item(id: String):selected_id=id;refresh(true)
func activate_selected():
	var item=item_by_id(selected_id)
	if item.is_empty():return
	if item.category=="consumable":game.session.act("potion")
	elif Inventory.is_equipped(player(),selected_id):game.session.act("unequip",item.slot)
	else:game.session.act("equip",selected_id)
	refresh(true)

func _process(_delta):
	if visible:refresh()

func refresh(force: bool=false):
	var p=player()
	if p.is_empty() or get_viewport().gui_is_dragging():return
	var next=JSON.stringify([p.inventory,p.equipment,p.bag_positions,p.materials,p.potions,p.class_id,p.costume,p.get("avatar","auto"),p.level,p.hp,p.gold])
	if not force and next==signature:return
	signature=next
	grid.rebuild()
	for slot in equipment_controls:
		var control=equipment_controls[slot]
		var item=item_by_id(p.equipment.get(slot,""))
		control.item=item;control.picture=null if item.is_empty() else Content.icon_texture(item)
		control.selected=selected_id!="" and item.get("id")==selected_id;control.queue_redraw()
	stat_label.text="%s · 공격 %d · 방어 %d" % [Content.CLASSES[p.class_id].name,game.session.sim.damage_for(p),p.defense]
	portrait.texture=preload("res://scripts/gat_art.gd").texture(preload("res://scripts/gat_art.gd").avatar(p),0) if Content.gat_appearance(p) else game.textures[Content.costume_role(p)].idle[0]
	portrait.material=preload("res://scripts/gat_art.gd").material() if Content.gat_appearance(p) else null
	avatar_picker.select(0 if p.get("avatar","auto")=="auto" else Content.AVATARS.keys().find(p.avatar)+1)
	costume_picker.select(Content.COSTUMES.keys().find(p.costume))
	var used=0
	for item in Inventory.bag_items(p):var dims=Content.item_size(item);used+=dims.x*dims.y
	capacity.text="%d / 60 칸" % used
	starter_button.disabled=p.training_given or not game.dungeon.in_town(p.pos)
	starter_button.text="연습 무기 수령 완료" if p.training_given else ("연습 무기 4종 받기" if game.dungeon.in_town(p.pos) else "연습 무기는 쉼터에서 받아요")
	var item=item_by_id(selected_id)
	primary.visible=not item.is_empty() and item.category!="material"
	discard_button.visible=not item.is_empty() and item.category in ["weapon","armor","accessory"] and not Inventory.is_equipped(p,selected_id)
	if item.is_empty():detail_name.text="물건을 선택하세요";detail_body.text="아이콘을 눌러 능력치를 확인하거나 드래그해서 장비를 바꿔 보세요.";return
	detail_name.text=item.name
	var dims=Content.item_size(item)
	detail_body.text="%s · %d × %d 칸\n\n" % [["일반","마법","희귀"][int(item.rarity)],dims.x,dims.y]
	if item.category in ["weapon","armor","accessory"]:
		var equipped=item_by_id(p.equipment.get(item.slot,""))
		var diff=int(item.bonus)-int(equipped.get("bonus",0))
		detail_body.text+="%s +%d\n장착품 대비 %+d\n\n%s" % ["방어력" if item.category=="armor" else "공격력",item.bonus,diff,Content.SLOT_NAMES[item.slot]]
		if item.category=="weapon":detail_body.text+="\n"+Content.WEAPONS[item.weapon_type].description
		primary.text="장착 해제" if Inventory.is_equipped(p,selected_id) else "장착하기"
	elif item.category=="consumable":detail_body.text+="생명력 60 회복\n보유 %d개\n\n재사용 대기 2초" % item.count;primary.text="사용하기"
	else:detail_body.text+="모험 중 얻은 재료\n보유 %d개" % item.count
