extends Panel
const World=preload("res://scripts/world_catalog.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Content=preload("res://scripts/content.gd")
const Art=preload("res://scripts/ui_art.gd")
const Icons=preload("res://scripts/icon_art.gd")
const Quote=preload("res://scripts/service_quote.gd")
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
var shop_mode="buy"
var selected_index=0
var selected_zone="forest"
var selected_floor=1
var chapter=0
var last_receipt=""
var confirm_button:Button
var preview={}
var products={}
func setup(owner_game):
	game=owner_game;position=Vector2(24,24);size=Vector2(1392,852);mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());Art.decorate(self,"paper",38)
	facility_icon=Art.picture(self,null,Vector2(26,18),Vector2(73,73))
	title=game.label(self,"",Vector2(115,25),Vector2(810,43),32)
	money=game.label(self,"",Vector2(115,78),Vector2(1190,29),18)
	game.button(self,"닫기  ESC",Vector2(1210,28),Vector2(149,43),close)
	Art.panel(self,Vector2(26,128),Vector2(336,654),"paper",24)
	counter=Art.picture(self,null,Vector2(33,143),Vector2(321,321))
	resident_portrait=Art.picture(self,null,Vector2(44,496),Vector2(117,177));resident_portrait.material=preload("res://scripts/gat_art.gd").material()
	greeting=game.label(self,"",Vector2(177,494),Vector2(162,185),18);greeting.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	response=game.label(self,"",Vector2(58,700),Vector2(276,55),16);response.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body=Control.new();body.position=Vector2(384,132);body.size=Vector2(976,651);add_child(body)
	game.label(self,"상품과 작업을 선택하고, 오른쪽에서 비용과 결과를 확인하세요.",Vector2(70,793),Vector2(1240,25),17)
	hide()
func player()->Dictionary:return game.session.sim.players[game.session.local_id]
func open(key:String):
	facility=key;selected_item="";selected_index=0;shop_mode="buy";selected_zone="forest";last_receipt=""
	selected_floor=int(player().get("highest_floor",1));chapter=int((selected_floor-1)/10)
	operation={"smith":"upgrade","shop":"buy","alchemy":"potion","guild":"accept","inn":"rest","portal":"travel"}[key]
	game.bag.hide();game.skill_tree.hide();game.help_panel.hide();game.codex.hide();show();game.session.paused=true;refresh()
func close():hide();game.session.paused=false
func request(kind:String,extra:Dictionary={})->bool:
	var before=player().gold;var q=Quote.quote(player(),facility,kind,extra)
	var payload=extra.duplicate();payload.merge({"facility":facility,"operation":kind})
	var success=game.session.act("facility",JSON.stringify(payload))
	if success:
		last_receipt=q.title+" · 완료\n금화 %+d G" % (player().gold-before)
		game.audio_director.play_sound("equip" if facility=="smith" else "potion" if facility in ["alchemy","inn"] else "pickup")
		if kind=="sell":selected_item=""
	else:last_receipt=q.reason if not q.reason.is_empty() else "현재 상태에서는 거래할 수 없습니다."
	refresh();return success
func choose(kind:String,extra:Dictionary={}):
	operation=kind;selected_item=str(extra.get("item",selected_item));selected_index=int(extra.get("index",selected_index));selected_zone=str(extra.get("zone",selected_zone));refresh()
func extra()->Dictionary:
	return {"index":selected_index,"item":selected_item,"zone":selected_zone}
func refresh():
	for child in body.get_children():body.remove_child(child);child.queue_free()
	products.clear();var p=player()
	title.text=World.FACILITIES[facility].name;facility_icon.texture=Icons.function_icon(facility);counter.texture=Art.facility(facility)
	resident_portrait.visible=World.RESIDENTS.has(facility)
	if World.RESIDENTS.has(facility):
		var resident=World.RESIDENTS[facility];resident_portrait.texture=preload("res://scripts/gat_art.gd").texture(resident.avatar,0)
		greeting.text=resident.name+"\n\n“"+resident.greeting+"”"
	else:greeting.text="원정의 문\n\n준비를 마쳤다면 새로운 모험으로 떠나세요."
	money.text="보유 금화 %d G     ·     별씨앗 %d     ·     광석 %d     ·     정수 %d" % [p.gold,p.materials.get("seed",0),p.materials.get("ore",0),p.materials.get("essence",0)]
	response.text="“좋은 선택이에요. 또 찾아주세요.”" if not last_receipt.is_empty() and "완료" in last_receipt else {"shop":"“마음에 드는 물건을 골라보세요.”","smith":"“장비를 맡기면 더 단단하게 벼려드릴게요.”","alchemy":"“조합식과 필요한 재료를 살펴보세요.”","guild":"“의뢰를 골라 모험을 떠나보세요.”","inn":"“잠시 쉬고 기운을 되찾으세요.”","portal":"갈 곳을 골라 원정을 시작하세요."}[facility]
	match facility:
		"shop":shop(p)
		"smith":smith(p)
		"alchemy":alchemy(p)
		"guild":guild(p)
		"inn":inn(p)
		"portal":portal(p)
	review(p)
func list_surface(at:Vector2,dimensions:Vector2,height:float)->Control:
	var scroll=ScrollContainer.new();scroll.position=at;scroll.size=dimensions;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
	var list=Control.new();list.custom_minimum_size=Vector2(dimensions.x-16,height);scroll.add_child(list);return list
func item_card(parent:Node,item:Dictionary,at:Vector2,caption:String,callback:Callable,chosen=false)->Button:
	var b=game.button(parent,"",at,Vector2(263,106),callback)
	Art.picture(b,Art.texture("equipped" if chosen else ["socket","magic","rare","rare","rare"][clampi(int(item.rarity),0,4)]),Vector2(12,15),Vector2(66,72))
	Art.picture(b,Content.icon_texture(item),Vector2(20,24),Vector2(50,52))
	if item.get("category","") in ["weapon","armor","accessory"]:
		var edge=Line2D.new();edge.points=PackedVector2Array([Vector2(19,23),Vector2(71,23),Vector2(71,79),Vector2(19,79),Vector2(19,23)]);edge.width=2;edge.default_color=Equipment.COLORS[clampi(int(item.rarity),0,4)];b.add_child(edge)
	var name=game.label(b,item.name,Vector2(91,17),Vector2(160,49),18);name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.label(b,caption,Vector2(91,71),Vector2(161,24),16);return b
func shop(p:Dictionary):
	game.button(body,"구매 · 진열 상품",Vector2(0,0),Vector2(263,43),func():shop_mode="buy";operation="buy";refresh())
	game.button(body,"판매 · 내 장비",Vector2(277,0),Vector2(263,43),func():shop_mode="sell";operation="sell";selected_item="";refresh())
	var items=[]
	if shop_mode=="buy":
		for key in Equipment.SHOP_TYPES:items.append(Equipment.make(key,mini(9,int(p.level/10)),0,"preview","none",p.class_id))
	else:items=p.inventory.filter(func(item):return not Inventory.is_equipped(p,item.id))
	var list=list_surface(Vector2(0,58),Vector2(556,580),maxf(570,ceil((items.size()+1)/2.0)*117))
	for i in range(items.size()):
		var item=items[i];var cost=preload("res://scripts/town_services.gd").price(p,i) if shop_mode=="buy" else Quote.sell_price(item)
		products[str(i)]=item_card(list,item,Vector2(i%2*273,int(i/2)*117),str(cost)+" G",func():choose("buy" if shop_mode=="buy" else "sell",{"index":i,"item":item.id}),operation=="buy" and selected_index==i or operation=="sell" and selected_item==item.id)
	if shop_mode=="buy":
		var potion={"category":"consumable","name":"회복 물약 ×1","rarity":0};products.potion=item_card(list,potion,Vector2(0,ceil(items.size()/2.0)*117),"15 G",func():choose("potion"),operation=="potion")
	elif items.is_empty():game.label(list,"판매할 장비가 없습니다.\n착용 중인 장비는 진열되지 않습니다.",Vector2(15,35),Vector2(514,94),21)
func smith(p:Dictionary):
	game.button(body,"확정 강화 · 최대 +5",Vector2.ZERO,Vector2(264,43),func():operation="upgrade";refresh())
	game.button(body,"옵션 재련",Vector2(278,0),Vector2(264,43),func():operation="reforge";refresh())
	if selected_item.is_empty() and not p.inventory.is_empty():selected_item=p.inventory[0].id
	var list=list_surface(Vector2(0,57),Vector2(556,336),maxf(328,ceil(p.inventory.size()/2.0)*117))
	for i in range(p.inventory.size()):
		var item=p.inventory[i];products[item.id]=item_card(list,item,Vector2(i%2*273,int(i/2)*117),"강화 +"+str(item.get("upgrade",0)),func():selected_item=item.id;refresh(),selected_item==item.id)
	if p.inventory.is_empty():game.label(list,"작업할 장비가 없습니다.\n가방에서 연습 무기를 받거나 상점을 이용하세요.",Vector2(20,30),Vector2(510,120),21)
	var item=Inventory.find_item(p,selected_item)
	if not item.is_empty():
		Art.picture(body,Content.icon_texture(item),Vector2(40,455),Vector2(87,95))
		game.label(body,"→",Vector2(152,471),Vector2(72,55),42)
		Art.picture(body,Art.texture("equipped"),Vector2(249,433),Vector2(119,126));Art.picture(body,Content.icon_texture(item),Vector2(270,454),Vector2(77,81))
		game.label(body,"작업 전",Vector2(36,565),Vector2(140,29),18)
		game.label(body,"강화 +%d" % mini(5,int(item.get("upgrade",0))+1) if operation=="upgrade" else "새로운 옵션",Vector2(245,567),Vector2(289,29),20)
		game.label(body,"그림을 선택해 작업할 장비를 바꿀 수 있습니다.",Vector2(10,614),Vector2(530,29),16)
func alchemy(_p:Dictionary):
	var recipes=[{"operation":"potion","name":"회복 물약 ×3","category":"consumable","rarity":0,"caption":"별씨앗 3개 + 10 G"},{"operation":"essence","name":"정원의 정수 ×1","category":"material","material":"essence","rarity":0,"caption":"별씨앗 5개 + 광석 5개 + 40 G"}]
	for i in range(recipes.size()):
		var recipe=recipes[i];var b=game.button(body,"",Vector2(0,i*149),Vector2(543,136),func():choose(recipe.operation))
		Art.picture(b,Content.icon_texture(recipe),Vector2(24,24),Vector2(87,87))
		game.label(b,recipe.name,Vector2(136,27),Vector2(384,37),25);game.label(b,recipe.caption,Vector2(136,80),Vector2(384,32),18)
		products[recipe.operation]=b
	var q=Quote.quote(player(),facility,operation);var i=0
	for key in q.materials:
		Art.picture(body,Content.icon_texture({"category":"material","material":key}),Vector2(28+i*138,363),Vector2(80,80));game.label(body,Content.MATERIALS[key]+" ×"+str(q.materials[key]),Vector2(10+i*138,457),Vector2(149,35),17);i+=1
	game.label(body,"→",Vector2(300,377),Vector2(73,66),44);Art.picture(body,Content.icon_texture(recipes[0 if operation=="potion" else 1]),Vector2(396,357),Vector2(102,102))
	game.label(body,"재료를 모아 필요한 물품을 직접 만드세요.\n완성품을 보관할 가방 공간도 함께 확인합니다.",Vector2(20,539),Vector2(513,71),20)
func guild(p:Dictionary):
	if p.guild_contract.is_empty():
		operation="accept";var i=0
		for zone in World.DUNGEONS:
			var data=World.DUNGEONS[zone];var b=game.button(body,"",Vector2(0,i*178),Vector2(543,160),func():choose("accept",{"zone":zone}))
			Art.picture(b,Icons.function_icon("guild"),Vector2(23,25),Vector2(75,75));game.label(b,data.name+" 토벌 의뢰",Vector2(119,26),Vector2(405,43),24)
			game.label(b,"목표 10마리  ·  권장 LV."+str(data.level)+"\n보상 180 G + 정수 1개",Vector2(120,78),Vector2(403,61),19);products[zone]=b;i+=1
	else:
		operation="claim";var q=p.guild_contract
		Art.picture(body,Art.texture("scroll"),Vector2(91,5),Vector2(356,296))
		game.label(body,World.DUNGEONS[q.zone].name+" 토벌",Vector2(20,326),Vector2(521,43),27)
		game.label(body,"의뢰 진행   %d / %d" % [q.progress,q.target],Vector2(20,393),Vector2(521,46),27)
		for i in range(10):Art.picture(body,Art.texture("equipped" if i<q.progress else "socket"),Vector2(i*53,466),Vector2(47,49))
		game.label(body,"목표를 달성하면 오른쪽에서 보상을 받으세요.",Vector2(20,565),Vector2(518,59),19)
func inn(p:Dictionary):
	Art.picture(body,Art.facility("inn"),Vector2(37,0),Vector2(467,390))
	game.label(body,"따뜻한 불가에서 쉬어가세요",Vector2(20,423),Vector2(520,41),28)
	game.label(body,"생명력   %d / %d\n기력       %d / %d\n\n숙박하면 생명력과 기력이 모두 회복됩니다." % [p.hp,p.max_hp,p.stamina,p.max_stamina],Vector2(20,485),Vector2(520,148),21)
func portal(p:Dictionary):
	var abyss=preload("res://scripts/abyss_catalog.gd")
	game.label(body,"심층 탐사 기록   B%d / B100"%p.get("cleared_floor",0),Vector2(8,0),Vector2(533,36),25)
	for i in range(10):
		var b=game.button(body,"%d–%d층"%[i*10+1,i*10+10],Vector2(i%5*109,48+int(i/5)*48),Vector2(103,41),func():chapter=i;selected_floor=chapter*10+1;refresh())
		b.add_theme_font_size_override("font_size",15)
	var data=abyss.BIOMES[chapter]
	game.label(body,data.name,Vector2(10,158),Vector2(528,35),27)
	var lore=game.label(body,data.lore,Vector2(10,200),Vector2(528,51),17);lore.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for i in range(10):
		var f=chapter*10+i+1;var locked=not abyss.locked_reason(p,f).is_empty();var cfg=abyss.config(f)
		var b=game.button(body,"",Vector2(i%2*275,267+int(i/2)*71),Vector2(267,64),func():selected_floor=f;refresh())
		var icon=Icons.function_icon("portal" if not cfg.raid else "guild")
		Art.picture(b,icon,Vector2(10,9),Vector2(45,45))
		game.label(b,"B%d  ·  %s"%[f,"레이드 보스" if cfg.raid else "던전 탐사"],Vector2(68,12),Vector2(185,24),18)
		game.label(b,"잠김" if locked else "돌파 완료" if f<=p.cleared_floor else "도전 가능",Vector2(68,37),Vector2(185,20),14,Color("905e49") if locked else Color("267d6c"))
		b.tooltip_text=abyss.locked_reason(p,f) if locked else "권장 LV.%d · 클릭하여 입장 준비"%cfg.level;products[str(f)]=b

func review(p:Dictionary):
	var panel=Art.panel(body,Vector2(572,0),Vector2(403,646),"paper",26)
	preview=Quote.quote(p,facility,operation,extra())
	if facility=="portal":
		var cfg=preload("res://scripts/abyss_catalog.gd").config(selected_floor)
		preview={"title":cfg.name,"cost":0,"materials":{},"item":{},"icon":"portal","reason":preload("res://scripts/abyss_catalog.gd").locked_reason(p,selected_floor),"result":"권장 LV.%d\n%s\n%s"%[cfg.level,"레이드: "+cfg.title if cfg.raid else "일반 적 21 · 엘리트 · 수문장","유니크 보장 / 에픽 이상 확률 드랍" if cfg.raid else "수문장 격파 후 출구 E로 다음 층"]}
	game.label(panel,"원정 준비" if facility=="portal" else "거래 · 작업 확인",Vector2(43,27),Vector2(327,34),25)
	var tex=Content.icon_texture(preview.item) if not preview.item.is_empty() else Icons.function_icon(preview.icon)
	Art.picture(panel,tex,Vector2(28,89),Vector2(84,89))
	var name=game.label(panel,preview.title,Vector2(134,94),Vector2(245,78),23);name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.label(panel,("받을 금화   %d G" % -preview.cost) if preview.cost<0 else ("필요 금화   %d G" % preview.cost),Vector2(28,193),Vector2(351,30),22)
	game.label(panel,"내 금화  %d → %d G" % [p.gold,p.gold-preview.cost],Vector2(28,234),Vector2(350,29),19)
	var mats=""
	for key in preview.materials:mats+=Content.MATERIALS[key]+"  %d / %d개\n" % [p.materials.get(key,0),preview.materials[key]]
	game.label(panel,mats,Vector2(28,278),Vector2(350,62),18)
	var result=game.label(panel,preview.result,Vector2(28,351),Vector2(350,111),19);result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var feedback=game.label(panel,preview.reason if not preview.reason.is_empty() else last_receipt,Vector2(28,470),Vector2(350,71),18,Color("8b432e") if not preview.reason.is_empty() else Color("247660"));feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var caption={"buy":"구매하기","sell":"선택 장비 판매","potion":"조제하기" if facility=="alchemy" else "물약 구매","essence":"합성하기","upgrade":"장비 강화하기","reforge":"옵션 재련하기","accept":"의뢰 수락","claim":"완료 보상 받기","rest":"숙박하고 회복","travel":"원정 시작"}.get(operation,"실행")
	confirm_button=game.button(panel,caption,Vector2(28,566),Vector2(349,50),func():
		if facility=="portal":
			if game.session.enter_floor(selected_floor):close()
		else:request(operation,extra()),true)
	confirm_button.disabled=not preview.reason.is_empty()
