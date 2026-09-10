extends Panel
const World=preload("res://scripts/world_catalog.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Content=preload("res://scripts/content.gd")
const Art=preload("res://scripts/ui_art.gd")
const Library=preload("res://scripts/icon_library.gd")
const Quote=preload("res://scripts/service_quote.gd")
const TownOperations=preload("res://scripts/town_operations.gd")
const OP_NAMES={"buy":"장비 구매","sell":"장비 판매","potion":"회복 물약","essence":"정수 합성","ore":"광석 정제","upgrade":"장비 강화","reforge":"옵션 재련","salvage":"장비 분해","accept":"토벌 의뢰","claim":"의뢰 보상","cancel":"의뢰 포기","supply":"재료 납품","rest":"숙박","resupply":"원정 재정비","travel":"던전 입장","training_reset":"훈련 기록"}
var game
var facility=""
var title:Label
var money:Label
var body:Control
var selected_item=""
var resident_portrait:TextureRect
var greeting:Label
var facility_icon:TextureRect
var counter:TextureRect
var response:Label
var operation=""
var quantity=1
var quantity_buttons={}
var operation_buttons={}
var shop_mode="buy"
var shop_tabs={}
var wardrobe_selection=""
var wardrobe_page=0
var wardrobe_view
var selected_index=0
var selected_zone="forest"
var selected_floor=1
var chapter=0
var last_receipt=""
var receipt_success=false
var confirm_button:Button
var preview={}
var products={}
var resource_labels={}
var review_panel:Control
var review_labels={}
var review_result_scroll:ScrollContainer
var product_scroll:ScrollContainer
var product_scroll_value=0

func setup(owner_game):
	game=owner_game;position=Vector2(-60,24);size=Vector2(1560,852);mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());Art.decorate(self,"paper",6)
	facility_icon=Art.picture(self,null,Vector2(28,22),Vector2(70,70))
	title=game.label(self,"",Vector2(116,25),Vector2(970,43),32)
	Library.attach(game.button(self,"닫기  ESC",Vector2(1376,28),Vector2(152,46),close),"close")
	Library.picture(self,"gold",Vector2(275,80),Vector2(25,25))
	money=game.label(self,"",Vector2(311,78),Vector2(306,29),20)
	for i in range(3):
		var key=["seed","ore","essence"][i]
		Library.picture(self,key,Vector2(646+i*286,80),Vector2(25,25))
		resource_labels[key]=game.label(self,"",Vector2(679+i*286,78),Vector2(234,29),18)
	Art.panel(self,Vector2(26,128),Vector2(224,692),"paper",6)
	counter=Art.picture(self,null,Vector2(40,146),Vector2(196,196))
	resident_portrait=Art.picture(self,null,Vector2(64,354),Vector2(148,192));resident_portrait.material=preload("res://scripts/gat_art.gd").material()
	greeting=wrapped(self,"",Vector2(45,559),Vector2(186,100),20,3)
	response=wrapped(self,"",Vector2(45,689),Vector2(186,84),18,3)
	body=Control.new();body.position=Vector2(274,130);body.size=Vector2(1258,690);add_child(body)
	inset_buttons(self);hide()

func wrapped(parent:Node,value:String,at:Vector2,dimensions:Vector2,font_size:int=20,lines:int=2)->Label:
	var label=game.label(parent,"",at,dimensions,font_size)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.max_lines_visible=lines;label.clip_contents=true;label.clip_text=true
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.text=value;label.size=dimensions
	label.tooltip_text=value;label.mouse_filter=Control.MOUSE_FILTER_PASS
	return label

func inset_buttons(parent:Node):
	for button in parent.find_children("*","Button",true,false):
		if button.text.is_empty() or not button.has_meta("rpg_frame"):continue
		var dimensions=button.size
		button.clip_text=true;button.add_theme_constant_override("h_separation",8)
		for state in ["normal","hover","pressed","disabled","focus"]:
			var style=StyleBoxEmpty.new();style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=5;style.content_margin_bottom=5
			button.add_theme_stylebox_override(state,style)
		var font=button.get_theme_font("font");var font_size=button.get_theme_font_size("font_size")
		var icon_space=button.get_theme_constant("icon_max_width")+8 if button.icon!=null else 0
		while font_size>14 and font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+icon_space>dimensions.x-36:font_size-=1
		button.add_theme_font_size_override("font_size",font_size);button.size=dimensions

func player()->Dictionary:return game.session.sim.players[game.session.local_id]
func open(key:String):
	if not World.FACILITIES.has(key):return
	if game.npc_dialogue!=null:game.npc_dialogue.hide()
	facility=key;selected_item="";selected_index=0;shop_mode="buy";selected_zone="forest";last_receipt="";receipt_success=false;quantity=1;product_scroll_value=0
	selected_floor=int(player().get("highest_floor",1));chapter=int((selected_floor-1)/10)
	operation={"smith":"upgrade","shop":"buy","alchemy":"potion","guild":"accept","inn":"rest","portal":"travel","costume":"buy","training":"training_reset"}[key]
	if key=="inn":operation=TownOperations.DEFAULT_INN_OPERATION
	if key=="costume":shop_mode="costume"
	if key=="smith" and not player().inventory.is_empty():selected_item=player().inventory[0].id
	if key=="guild" and not player().guild_contract.is_empty():operation="claim"
	game.bag.hide();game.skill_tree.hide();game.help_panel.hide();game.codex.hide();show();game.session.paused=true;refresh()
func close():hide();game.session.paused=false

func receipt_changes(before:Dictionary,after:Dictionary)->String:
	var rows:PackedStringArray=[]
	var gold=int(after.gold)-int(before.gold)
	if gold!=0:rows.append("금화 %+d G"%gold)
	var potions=int(after.potions)-int(before.potions)
	if potions!=0:rows.append("물약 %+d"%potions)
	for key in ["seed","ore","essence"]:
		var difference=int(after.materials.get(key,0))-int(before.materials.get(key,0))
		if difference!=0:rows.append(Content.MATERIALS[key]+" %+d"%difference)
	if int(after.hp)>int(before.hp):rows.append("생명력 회복")
	return " · ".join(rows)

func request(kind:String,extras:Dictionary={})->bool:
	if not World.FACILITIES.has(facility):return false
	var before=player().duplicate(true);var q=Quote.quote(player(),facility,kind,extras)
	var payload=extras.duplicate();payload.merge({"facility":facility,"operation":kind})
	var success=game.session.act("facility",JSON.stringify(payload));receipt_success=success
	if success:
		last_receipt=OP_NAMES.get(kind,q.title)+" 완료\n"+receipt_changes(before,player())
		game.audio_director.play_sound("equip" if facility=="smith" else "potion" if facility in ["alchemy","inn"] else "pickup")
		if kind in ["sell","salvage"]:selected_item=""
	else:last_receipt=q.reason if not q.reason.is_empty() else "현재 상태에서는 거래할 수 없습니다."
	refresh();return success

func choose(kind:String,extras:Dictionary={}):
	if operation!=kind:
		quantity=1;product_scroll_value=0
		if is_instance_valid(product_scroll):product_scroll.scroll_vertical=0
		if kind in ["sell","salvage"] and not extras.has("item"):selected_item=""
	operation=kind;selected_item=str(extras.get("item",selected_item));selected_index=int(extras.get("index",selected_index));selected_zone=str(extras.get("zone",selected_zone))
	last_receipt="";receipt_success=false;refresh()
func extra()->Dictionary:return {"index":selected_index,"item":selected_item,"zone":selected_zone,"quantity":quantity}
func select_quantity(value:int):
	if value not in ([1,5,10] if facility=="shop" else [1,3,5]):return
	quantity=value;last_receipt="";receipt_success=false;refresh()

func refresh():
	if not World.FACILITIES.has(facility):return
	if is_instance_valid(product_scroll):product_scroll_value=product_scroll.scroll_vertical
	for child in body.get_children():body.remove_child(child);child.queue_free()
	products.clear();shop_tabs.clear();quantity_buttons.clear();operation_buttons.clear();wardrobe_view=null;review_panel=null;confirm_button=null;product_scroll=null;review_labels.clear()
	var p=player()
	title.text=World.FACILITIES[facility].name
	facility_icon.texture=Library.texture({"costume":"chest","training":"physical_attack"}.get(facility,facility))
	counter.texture=Art.facility("shop" if facility=="costume" else "portal" if facility=="training" else facility);facility_icon.material=Art.icon_material(facility_icon.texture)
	if facility=="training":counter.texture=preload("res://scripts/training_art.gd").texture()
	resident_portrait.visible=World.RESIDENTS.has(facility)
	if World.RESIDENTS.has(facility):
		var resident=World.RESIDENTS[facility];resident_portrait.texture=preload("res://scripts/gat_art.gd").texture(resident.avatar,0)
		greeting.text=resident.name;greeting.tooltip_text=resident.name
	else:greeting.text="원정의 문";greeting.tooltip_text=greeting.text
	money.text="보유 금화  %d G"%p.gold
	for key in resource_labels:resource_labels[key].text=Content.MATERIALS[key]+"  "+str(p.materials.get(key,0))
	response.text={"shop":"장비 · 물약\n코스튬","smith":"강화 · 재련\n장비 분해","alchemy":"물약 · 정수\n광석 정제","guild":"토벌 의뢰\n재료 납품","inn":"휴식 · 회복\n원정 재정비","portal":"심층 던전\nB1 — B100","costume":"외형 · 코스튬\n이름 변경","training":"표적 연습\n훈련 기록"}[facility];response.tooltip_text=response.text
	match facility:
		"shop":shop(p)
		"smith":smith(p)
		"alchemy":alchemy(p)
		"guild":guild(p)
		"inn":inn(p)
		"portal":portal(p)
		"costume":costume(p)
		"training":training(p)
	if facility!="costume" and (facility!="shop" or shop_mode!="costume"):review(p)
	inset_buttons(body)

func list_surface(at:Vector2,dimensions:Vector2,height:float)->Control:
	product_scroll=ScrollContainer.new();product_scroll.position=at;product_scroll.size=dimensions
	product_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(product_scroll)
	var list=Control.new();list.custom_minimum_size=Vector2(dimensions.x-16,height);product_scroll.add_child(list)
	product_scroll.set_deferred("scroll_vertical",product_scroll_value);return list

func selection_marker(button:Button,chosen:bool):
	button.set_meta("selected",chosen)
	if chosen:
		Library.picture(button,"selected",Vector2(button.size.x-35,10),Vector2(24,24))
		var edge=Line2D.new();edge.points=PackedVector2Array([Vector2(6,12),Vector2(6,button.size.y-12)]);edge.width=4;edge.default_color=Color("298c80");button.add_child(edge)

func item_card(parent:Node,item:Dictionary,at:Vector2,caption:String,callback:Callable,chosen=false)->Button:
	var b=game.button(parent,"",at,Vector2(342,122),callback,chosen)
	Art.picture(b,Art.texture("equipped" if chosen else "socket"),Vector2(15,20),Vector2(80,82))
	Art.picture(b,Content.icon_texture(item),Vector2(21,25),Vector2(68,72))
	if item.get("category","") in ["weapon","armor","accessory"]:
		var edge=Line2D.new();edge.points=PackedVector2Array([Vector2(20,24),Vector2(91,24),Vector2(91,99),Vector2(20,99),Vector2(20,24)]);edge.width=2;edge.default_color=Equipment.COLORS[clampi(int(item.get("rarity",0)),0,4)];b.add_child(edge)
	wrapped(b,item.name,Vector2(110,12),Vector2(194,68),20,2)
	wrapped(b,caption,Vector2(110,88),Vector2(216,27),17,1)
	b.tooltip_text=item.name+"\n"+caption;selection_marker(b,chosen);return b

func operation_tabs(entries:Array):
	var width=(722.-(entries.size()-1)*12.)/entries.size()
	for i in range(entries.size()):
		var entry=entries[i];var key=entry[0]
		var button=game.button(body,entry[1],Vector2(i*(width+12),0),Vector2(width,46),func():choose(key),operation==key)
		if operation==key:Library.attach(button,"selected")
		operation_buttons[key]=button

func quantity_row(at_y:float):
	game.label(body,"수량",Vector2(10,at_y+8),Vector2(108,29),21)
	var amounts=[1,5,10] if facility=="shop" else [1,3,5]
	for i in range(amounts.size()):
		var amount=amounts[i]
		quantity_buttons[amount]=game.button(body,"× %d"%amount,Vector2(124+i*116,at_y),Vector2(104,44),func():select_quantity(amount),quantity==amount)
		quantity_buttons[amount].set_meta("selected",quantity==amount)

func shop(p:Dictionary):
	for i in range(3):
		var mode=["buy","sell","costume"][i]
		shop_tabs[mode]=game.button(body,{"buy":"구매","sell":"판매","costume":"코스튬"}[mode],Vector2(i*244,0),Vector2(232,46),func():select_shop_mode(mode),shop_mode==mode)
		if shop_mode==mode:Library.attach(shop_tabs[mode],"selected")
	if shop_mode=="costume":
		wardrobe_view=preload("res://scripts/wardrobe_shop.gd").new();body.add_child(wardrobe_view);wardrobe_view.setup(self,p);wardrobe_view.position.x=141
		return
	var items=[]
	if shop_mode=="buy":
		for key in Equipment.SHOP_TYPES:items.append(Equipment.make(key,mini(9,int(p.level/10)),0,"preview","none",p.class_id))
	else:items=p.inventory.filter(func(item):return not Inventory.is_equipped(p,item.id))
	var top=120 if operation=="potion" else 62
	if operation=="potion":quantity_row(62)
	var count=items.size()+(1 if shop_mode=="buy" else 0)
	var list=list_surface(Vector2(0,top),Vector2(722,684-top),maxf(680-top,ceili(count/2.0)*134.))
	for i in range(items.size()):
		var item=items[i];var cost=preload("res://scripts/town_services.gd").price(p,i) if shop_mode=="buy" else Quote.sell_price(item)
		products[str(i)]=item_card(list,item,Vector2(i%2*352,int(i/2)*134),str(cost)+" G",func():choose("buy" if shop_mode=="buy" else "sell",{"index":i,"item":item.id}),operation=="buy" and selected_index==i or operation=="sell" and selected_item==item.id)
	if shop_mode=="buy":products.potion=item_card(list,{"category":"consumable","name":"회복 물약","rarity":0},Vector2(items.size()%2*352,int(items.size()/2)*134),"15 G / 개",func():choose("potion"),operation=="potion")
	elif items.is_empty():wrapped(list,"판매할 장비가 없습니다.",Vector2(24,36),Vector2(650,80),24,2)

func select_shop_mode(mode:String):
	if mode not in ["buy","sell","costume"]:return
	shop_mode=mode;operation="buy" if mode=="costume" else mode;selected_item="";quantity=1;last_receipt="";product_scroll_value=0;refresh()

func costume(p:Dictionary):
	game.label(body,"외형 · 코스튬",Vector2(10,4),Vector2(1190,43),28)
	wardrobe_view=preload("res://scripts/wardrobe_shop.gd").new();body.add_child(wardrobe_view);wardrobe_view.setup(self,p);wardrobe_view.position.x=141

func training(p:Dictionary):
	game.label(body,"표적 연습",Vector2(6,4),Vector2(710,45),28)
	service_card(body,"practice","거대 훈련 허수아비","기본 공격 · 스킬 · 무력화 연습","physical_attack",Vector2(0,76),close,true,160)
	var stats=preload("res://scripts/training_ground.gd").summary(p)
	service_card(body,"record","이번 훈련","누적 피해 %d · 타격 %d회"%[stats.total_damage,stats.hits],"skills",Vector2(0,261),func():choose("training_reset"),true,160)
	var back=game.button(body,"허수아비로 돌아가기",Vector2(18,454),Vector2(680,54),close,true);Library.attach(back,"next")

func reset_training():
	receipt_success=game.session.act("training_reset")
	last_receipt="훈련 초기화 완료\n기록 · 기술 대기시간 초기화" if receipt_success else "수련장 안에서 이용할 수 있습니다."
	refresh()

func smith(p:Dictionary):
	operation_tabs([["upgrade","장비 강화"],["reforge","옵션 재련"],["salvage","장비 분해"]])
	var items=p.inventory.filter(func(item):return item.get("category","") in ["weapon","armor","accessory"] and (operation!="salvage" or not Inventory.is_equipped(p,item.id)))
	# A completed sale/dismantle never silently selects the next inventory row.
	var list=list_surface(Vector2(0,64),Vector2(722,620),maxf(610,ceili(items.size()/2.0)*134.))
	for i in range(items.size()):
		var item=items[i];var caption="강화 +%d · %s"%[item.get("upgrade",0),"착용 중" if Inventory.is_equipped(p,item.id) else "보관 중"]
		products[item.id]=item_card(list,item,Vector2(i%2*352,int(i/2)*134),caption,func():choose(operation,{"item":item.id}),selected_item==item.id)
	if items.is_empty():wrapped(list,"작업할 장비가 없습니다.",Vector2(24,36),Vector2(650,80),24,2)

func service_card(parent:Node,key:String,name:String,detail:String,icon:String,at:Vector2,callback:Callable,chosen:bool,height:float=142)->Button:
	var b=game.button(parent,"",at,Vector2(704,height),callback,chosen)
	Library.picture(b,icon,Vector2(24,26),Vector2(82,82))
	wrapped(b,name,Vector2(130,23),Vector2(520,39),25,1)
	wrapped(b,detail,Vector2(130,75),Vector2(546,height-87),20,2)
	b.tooltip_text=name+"\n"+detail;selection_marker(b,chosen);products[key]=b;return b

func alchemy(_p:Dictionary):
	game.label(body,"조합식",Vector2(6,4),Vector2(710,38),28);quantity_row(60)
	var recipes=[["potion","회복 물약 ×3","별씨앗 3 + 10 G","consumable"],["essence","정원의 정수 ×1","별씨앗 5 + 광석 5 + 40 G","essence"],["ore","광석 ×3","별씨앗 5 + 20 G","ore"]]
	var list=list_surface(Vector2(0,122),Vector2(722,562),558)
	for i in range(recipes.size()):
		var recipe=recipes[i];service_card(list,recipe[0],recipe[1],recipe[2],recipe[3],Vector2(0,i*172),func():choose(recipe[0]),operation==recipe[0],158)

func guild(p:Dictionary):
	operation_tabs([["claim" if not p.guild_contract.is_empty() else "accept","토벌 의뢰"],["supply","재료 납품"]])
	if operation=="supply":
		service_card(body,"supply","길드 보급품 납품","별씨앗 10 + 광석 5 → 300 G","quest_reward",Vector2(0,76),func():choose("supply"),true,170)
		return
	if p.guild_contract.is_empty():
		var list=list_surface(Vector2(0,66),Vector2(722,618),610);var i=0
		for zone in World.DUNGEONS:
			var data=World.DUNGEONS[zone]
			service_card(list,zone,data.name+" 토벌","10마리 · 권장 LV.%d\n180 G + 정수 1"%data.level,"quest",Vector2(0,i*183),func():choose("accept",{"zone":zone}),operation=="accept" and selected_zone==zone,167);i+=1
	else:
		var contract=p.guild_contract
		service_card(body,"claim",World.DUNGEONS[contract.zone].name+" 토벌","진행 %d / %d  ·  보상 180 G + 정수 1"%[contract.progress,contract.target],"quest_complete" if contract.progress>=contract.target else "quest",Vector2(0,76),func():choose("claim"),operation=="claim",164)
		for i in range(10):Library.picture(body,"quest_complete" if i<contract.progress else "quest",Vector2(18+i*68,272),Vector2(52,52)).modulate=Color.WHITE if i<contract.progress else Color(1,1,1,.32)
		var cancel=game.button(body,"현재 의뢰 포기",Vector2(16,382),Vector2(320,48),func():choose("cancel"),operation=="cancel");operation_buttons.cancel=cancel

func inn(p:Dictionary):
	game.label(body,"머무르기",Vector2(6,4),Vector2(710,38),28)
	service_card(body,"rest","숙박 · 10 G","생명력 %d → %d · 기력 %d → %d"%[p.hp,p.max_hp,p.stamina,p.max_stamina],"inn",Vector2(0,70),func():choose("rest"),operation=="rest",158)
	for i in range(2):
		var key=["resupply_small","resupply"][i];var q=Quote.quote(p,"inn",key)
		var target=maxi(int(TownOperations.INN_RESUPPLY_TARGETS[key]),int(p.potions))
		service_card(body,key,("가벼운 채비" if i==0 else "장기 원정 채비")+" · %d G"%int(q.cost),"생명력 · 기력 회복\n물약 %d → %d"%[p.potions,target],"consumable",Vector2(0,244+i*174),func():choose(key),operation==key,158)

func portal(p:Dictionary):
	var abyss=preload("res://scripts/abyss_catalog.gd")
	game.label(body,"심층 탐사 기록  B%d / B100"%p.get("cleared_floor",0),Vector2(8,0),Vector2(705,36),26)
	for i in range(10):
		var b=game.button(body,"%d–%d"%[i*10+1,i*10+10],Vector2(i%5*145,51+int(i/5)*49),Vector2(134,41),func():chapter=i;selected_floor=chapter*10+1;last_receipt="";refresh(),chapter==i)
		b.tooltip_text=abyss.BIOMES[i].name
	wrapped(body,abyss.BIOMES[chapter].name,Vector2(8,161),Vector2(706,46),27,1)
	for i in range(10):
		var floor_id=chapter*10+i+1;var locked=not abyss.locked_reason(p,floor_id).is_empty();var cfg=abyss.config(floor_id)
		var b=game.button(body,"",Vector2(i%2*364,220+int(i/2)*91),Vector2(352,80),func():selected_floor=floor_id;last_receipt="";refresh(),selected_floor==floor_id)
		Library.picture(b,"boss" if cfg.raid else "floor",Vector2(16,14),Vector2(50,50))
		wrapped(b,"B%d · %s"%[floor_id,"레이드 보스" if cfg.raid else "던전 탐사"],Vector2(84,11),Vector2(226,31),20,1)
		wrapped(b,"잠김" if locked else "돌파 완료" if floor_id<=p.cleared_floor else "도전 가능",Vector2(84,45),Vector2(220,29),17,1)
		selection_marker(b,selected_floor==floor_id);b.tooltip_text=abyss.locked_reason(p,floor_id) if locked else cfg.name;products[str(floor_id)]=b

func review(p:Dictionary):
	var panel=Art.panel(body,Vector2(746,0),Vector2(510,688),"paper",6)
	review_panel=panel;preview=Quote.quote(p,facility,operation,extra())
	if facility=="portal":
		var cfg=preload("res://scripts/abyss_catalog.gd").config(selected_floor)
		preview={"title":cfg.name,"cost":0,"materials":{},"item":{},"icon":"portal","reason":preload("res://scripts/abyss_catalog.gd").locked_reason(p,selected_floor),"result":"권장 LV.%d\n%s\n%s"%[cfg.level,"레이드: "+cfg.title if cfg.raid else "일반 적 21 · 엘리트 · 수문장","유니크 보장 · 에픽 이상 드랍" if cfg.raid else "수문장 격파 → 다음 층 개방"]}
	if facility=="training":
		var stats=preload("res://scripts/training_ground.gd").summary(p)
		preview={"title":"거대 훈련 허수아비","cost":0,"materials":{},"item":{},"icon":"physical_attack","reason":"" if preload("res://scripts/training_ground.gd").contains(p.pos) else "수련장 안에서 이용할 수 있습니다.","result":"마지막 기술\n%s\n측정 %.1f초"%[stats.last_skill,stats.elapsed]}
	wrapped(panel,OP_NAMES.get(operation,"작업 확인"),Vector2(32,26),Vector2(446,50),28,1)
	var icon="essence" if operation=="essence" else "ore" if operation in ["ore","salvage"] else "boss" if facility=="portal" and selected_floor%10==0 else "quest_reward" if operation in ["claim","supply"] else preview.icon
	var tex=Content.icon_texture(preview.item) if not preview.item.is_empty() else Library.texture(icon)
	Art.picture(panel,tex,Vector2(32,86),Vector2(98,102))
	var name_text=preview.item.get("name",preview.title) if facility=="smith" else preview.title
	review_labels.name=wrapped(panel,name_text,Vector2(150,84),Vector2(328,110),22,3)
	Library.picture(panel,"physical_attack" if facility=="training" else "gold",Vector2(32,214),Vector2(27,27))
	review_labels.price=wrapped(panel,("받는 금화  %d G"%-preview.cost) if preview.cost<0 else "지불 금화  %d G"%preview.cost,Vector2(76,210),Vector2(402,35),23,1)
	review_labels.balance=wrapped(panel,"금화  %d → %d G"%[p.gold,p.gold-preview.cost],Vector2(32,254),Vector2(446,34),20,1)
	var mats:PackedStringArray=[]
	for key in preview.materials:mats.append("%s  %d → %d  (−%d)"%[Content.MATERIALS[key],p.materials.get(key,0),int(p.materials.get(key,0))-int(preview.materials[key]),preview.materials[key]])
	review_labels.materials=wrapped(panel,"\n".join(mats),Vector2(32,298),Vector2(446,66),20,2)
	if facility=="training":
		var stats=preload("res://scripts/training_ground.gd").summary(p)
		review_labels.price.text="누적 피해  %d"%stats.total_damage;review_labels.price.tooltip_text=review_labels.price.text
		review_labels.balance.text="초당 피해  %.1f"%stats.dps;review_labels.balance.tooltip_text=review_labels.balance.text
		review_labels.materials.text="타격 %d회  ·  치명타 %d회"%[stats.hits,stats.criticals];review_labels.materials.tooltip_text=review_labels.materials.text
	review_result_scroll=ScrollContainer.new();review_result_scroll.position=Vector2(32,378);review_result_scroll.size=Vector2(446,119);review_result_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(review_result_scroll)
	var result=game.label(review_result_scroll,"",Vector2.ZERO,Vector2(428,119),22)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result.size_flags_horizontal=Control.SIZE_EXPAND_FILL;result.custom_minimum_size.x=428
	result.text=preview.result
	if facility=="shop" and operation=="buy" and not preview.item.is_empty():
		var item:Dictionary=preview.item;var current=Inventory.find_item(p,str(p.equipment.get(item.slot,"")))
		var attribute="장비 방어력" if item.category=="armor" else "장비 공격력"
		result.text="%s  %d → %d\n%s\n%s"%[attribute,current.get("bonus",0),item.bonus,Equipment.restriction_text(item),Equipment.option_text(item)]
		review_labels["comparison_attribute"]=attribute
	review_labels.result=result
	# A completed transaction stays visible when the next quote becomes invalid.
	var message=last_receipt if not last_receipt.is_empty() else preview.reason
	var success=not last_receipt.is_empty() and receipt_success
	if not message.is_empty():Library.picture(panel,"success" if success else "warning",Vector2(32,524),Vector2(30,30))
	review_labels.feedback=wrapped(panel,message,Vector2(77,518),Vector2(401,74),19,2)
	review_labels.feedback.add_theme_color_override("font_color",Color("247660") if success else Color("8b432e"))
	var caption={"buy":"구매하기","sell":"선택 장비 판매","potion":"조제하기" if facility=="alchemy" else "물약 구매","essence":"정수 합성","ore":"광석 정제","upgrade":"확정 강화","reforge":"옵션 재련","salvage":"선택 장비 분해","accept":"의뢰 수락","claim":"보상 받기","cancel":"현재 의뢰 포기","supply":"재료 납품","rest":"숙박하고 회복","resupply":"회복 · 물약 보충","travel":"던전 입장"}.get(operation,"실행")
	if facility=="training":caption="기록 · 기술 대기시간 초기화"
	if operation=="resupply_small":caption="회복 · 물약 5개 채우기"
	confirm_button=game.button(panel,caption,Vector2(32,614),Vector2(446,48),func():
		if facility=="portal":
			if game.session.enter_floor(selected_floor):close()
		elif facility=="training":reset_training()
		else:request(operation,extra()),true)
	confirm_button.disabled=not preview.reason.is_empty();confirm_button.tooltip_text=preview.reason
	Library.attach(confirm_button,"locked" if confirm_button.disabled else "confirm")
