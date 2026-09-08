extends Panel
const World=preload("res://scripts/world_catalog.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
var game
var facility=""
var title:Label
var money:Label
var body:Control
var selected_item=""
var resident_portrait:TextureRect
var greeting:Label
var facility_icon:TextureRect
func setup(owner_game):
	game=owner_game;position=Vector2(242,108);size=Vector2(956,686);mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",game.style(Color("ecf2e9"),Color("97b4a2"),12))
	title=game.label(self,"",Vector2(96,20),Vector2(640,40),28)
	facility_icon=TextureRect.new();facility_icon.position=Vector2(26,12);facility_icon.size=Vector2(56,56);facility_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;facility_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;add_child(facility_icon)
	money=game.label(self,"",Vector2(30,71),Vector2(880,30),17)
	game.button(self,"닫기  ESC",Vector2(780,22),Vector2(145,40),close)
	resident_portrait=TextureRect.new();resident_portrait.position=Vector2(32,105);resident_portrait.size=Vector2(78,90);resident_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;resident_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;resident_portrait.material=preload("res://scripts/gat_art.gd").material();add_child(resident_portrait)
	greeting=game.label(self,"",Vector2(130,107),Vector2(790,93),18);greeting.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body=Control.new();body.position=Vector2(28,228);body.size=Vector2(900,424);add_child(body);hide()
func open(key:String):
	facility=key;selected_item="";game.bag.hide();game.skill_tree.hide();game.help_panel.hide();show();game.session.paused=true;refresh()
func close():hide();game.session.paused=false
func request(operation:String,extra:Dictionary={}):
	extra=extra.duplicate();extra.merge({"facility":facility,"operation":operation})
	game.session.act("facility",JSON.stringify(extra));refresh()
func refresh():
	for child in body.get_children():body.remove_child(child);child.queue_free()
	var p=game.session.sim.players[game.session.local_id]
	title.text=World.FACILITIES[facility].name
	facility_icon.texture=preload("res://scripts/icon_art.gd").function_icon(facility)
	resident_portrait.visible=World.RESIDENTS.has(facility)
	if World.RESIDENTS.has(facility):
		var resident=World.RESIDENTS[facility]
		resident_portrait.texture=preload("res://scripts/gat_art.gd").texture(resident.avatar,0)
		greeting.text=resident.name+"\n“"+resident.greeting+"”"
	else:greeting.text="원정의 문\n탐험할 곳을 선택하세요. R을 누르면 마을로 돌아옵니다."
	money.text="금화 %d  ·  씨앗 %d  ·  광석 %d  ·  정수 %d" % [p.gold,p.materials.get("seed",0),p.materials.get("ore",0),p.materials.get("essence",0)]
	match facility:
		"portal":
			var i=0
			for zone in World.DUNGEONS:
				var data=World.DUNGEONS[zone]
				game.label(body,"권장 LV.%d  %s" % [data.level,data.name],Vector2(0,i*124),Vector2(670,35),24)
				game.label(body,data.description,Vector2(0,i*124+40),Vector2(700,48),17)
				game.button(body,"입장",Vector2(742,i*124+15),Vector2(145,50),func():close();game.session.travel(zone));i+=1
		"shop":
			var keys=Equipment.BASES.keys()
			for i in range(keys.size()):
				var item=Equipment.make(keys[i],mini(4,int(p.level/5)),0,"preview")
				game.button(body,"%s · %dG" % [item.name,preload("res://scripts/town_services.gd").price(p,i)],Vector2(i%2*449,int(i/2)*53),Vector2(430,45),func():request("buy",{"index":i})).add_theme_font_size_override("font_size",17)
			game.button(body,"물약 1개 · 15G",Vector2(0,282),Vector2(260,44),func():request("potion"))
			item_picker(p,Vector2(0,345));game.button(body,"선택 장비 판매",Vector2(648,343),Vector2(232,44),func():request("sell",{"item":selected_item}))
		"smith":
			game.label(body,"강화는 확정 성공 · 최대 +5\n강화 비용: 다음 단계 × 50금화 / 다음 단계 × 광석 1개\n무기 공격력 +2 · 방어구/장신구 수치 +1",Vector2(0,0),Vector2(880,110),20)
			item_picker(p,Vector2(0,135))
			game.button(body,"선택 장비 강화",Vector2(0,211),Vector2(422,55),func():request("upgrade",{"item":selected_item}))
			game.button(body,"옵션 재련 · 80G / 정수 1",Vector2(452,211),Vector2(428,55),func():request("reforge",{"item":selected_item}))
			game.label(body,"재련은 기존 옵션을 다른 옵션으로 바꿉니다.\n활력·집중·수호·숨결·행운 중 하나가 부여됩니다.",Vector2(0,302),Vector2(860,70),18)
		"alchemy":
			game.label(body,"별씨앗과 광석을 모아 새로운 재료를 조제하세요.",Vector2(0,0),Vector2(890,35),21)
			game.button(body,"회복 물약 ×3 조제 · 씨앗 3 / 10G",Vector2(0,90),Vector2(880,67),func():request("potion"))
			game.button(body,"정원의 정수 ×1 합성 · 씨앗 5 / 광석 5 / 40G",Vector2(0,191),Vector2(880,67),func():request("essence"))
			game.label(body,"물약은 최대 20개. 가방이 가득 차거나 재료가 부족하면 소모하지 않습니다.",Vector2(0,313),Vector2(890,70),17)
		"guild":
			if p.guild_contract.is_empty():
				game.label(body,"토벌 의뢰 · 해당 던전의 적 10마리\n보상: 180금화 / 정원의 정수 1",Vector2(0,0),Vector2(880,75),23)
				var i=0
				for zone in World.DUNGEONS:
					game.button(body,World.DUNGEONS[zone].name+" 의뢰 수락",Vector2(0,115+i*80),Vector2(880,60),func():request("accept",{"zone":zone}));i+=1
			else:
				var q=p.guild_contract;game.label(body,"%s 토벌\n%d / %d마리\n보상: 180금화 / 정수 1" % [World.DUNGEONS[q.zone].name,q.progress,q.target],Vector2(0,0),Vector2(880,170),25)
				game.button(body,"완료 보상 받기",Vector2(0,205),Vector2(880,60),func():request("claim")).disabled=q.progress<q.target
		"inn":
			game.label(body,"모닥불이 따뜻한 초승달 여관\n\n숙박하면 생명력과 기력이 모두 회복됩니다.\n현재 생명력 %d / %d · 기력 %d / %d" % [p.hp,p.max_hp,p.stamina,p.max_stamina],Vector2(0,0),Vector2(880,200),24)
			game.button(body,"푹 쉬기 · 10금화",Vector2(0,243),Vector2(880,65),func():request("rest"))
func item_picker(p:Dictionary,at:Vector2):
	var picker=OptionButton.new();picker.position=at;picker.size=Vector2(616,46);picker.add_theme_font_override("font",game.fonts);picker.add_theme_font_size_override("font_size",17);body.add_child(picker)
	var items=p.inventory.filter(func(item):return facility!="shop" or not Inventory.is_equipped(p,item.id))
	if items.is_empty():picker.add_item("선택할 장비가 없습니다");selected_item="";return
	var ids=[]
	for item in items:picker.add_item(item.name+" · 능력 "+str(item.bonus));ids.append(item.id)
	if selected_item not in ids:selected_item=ids[0]
	picker.select(ids.find(selected_item));picker.item_selected.connect(func(index):selected_item=ids[index])
