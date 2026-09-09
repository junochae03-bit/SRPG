extends Control
const Content=preload("res://scripts/content.gd")
const Circle=preload("res://scripts/action_circle.gd")
var game
var p:Dictionary={}
var circles={}
var name_label:Label
var hp_label:Label
var money_label:Label
var region:Label
var quest:Label
var quest_title:Label
var toast:Label
var charge_label:Label
var portrait:Texture2D
var bag_button:Button
var growth_button:Button
var boss_hud:Control
func setup(owner_game):
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
	material=preload("res://scripts/gat_art.gd").material()
	name_label=white_label("",Vector2(139,39),Vector2(405,33),25)
	white_label("별빛을 따라 걷는 모험가",Vector2(140,18),Vector2(450,23),13,Color("d4e6d4"))
	hp_label=white_label("",Vector2(148,78),Vector2(264,21),13)
	money_label=white_label("",Vector2(51,156),Vector2(420,30),18)
	region=white_label("",Vector2(1149,194),Vector2(265,31),23)
	region.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;region.add_theme_font_override("font",game.serif)
	var quest_panel=game.panel(self,Vector2(1082,246),Vector2(322,163),Color("22464cb0"))
	quest_panel.add_theme_stylebox_override("panel",game.style(Color("22464cb0"),Color("c5b67c60"),4))
	quest_title=white_label("◆ 정원의 소란",Vector2(1098,254),Vector2(290,34),23,Color("f5df9b"))
	quest=white_label("",Vector2(1100,297),Vector2(289,105),16)
	bag_button=preload("res://scripts/hud_sprite_button.gd").new()
	bag_button.setup(game,preload("res://scripts/icon_art.gd").function_icon("satchel"),"가방","I",game.toggle_bag);bag_button.position=Vector2(1047,23);add_child(bag_button)
	var book=preload("res://scripts/icon_art.gd").function_icon("growth")
	growth_button=preload("res://scripts/hud_sprite_button.gd").new()
	growth_button.setup(game,book,"성장","K",game.toggle_skills);growth_button.position=Vector2(1136,23);add_child(growth_button)
	var definitions=[
		["attack","기본 공격","LMB",Vector2(1270,733),102],
		["heavy","충전 강공격","RMB",Vector2(1157,760),84],
		["skill_q","기술","Q",Vector2(1278,611),78],
		["skill_f","기술","F",Vector2(1168,611),78],
		["skill_v","기술","V",Vector2(1058,611),78],
		["skill_c","기술","C",Vector2(948,611),78],
		["skill_z","기술","Z",Vector2(838,611),78],
		["skill_x","기술","X",Vector2(728,611),78],
		["dodge","회피","SPACE",Vector2(1045,764),78],
		["potion","물약","1",Vector2(661,776),62],
		["interact","줍기 / 보급","E",Vector2(741,776),62],
		["return","쉼터 귀환","R",Vector2(821,776),62]]
	for entry in definitions:
		var control=Circle.new();control.setup(game,entry[0],entry[1],entry[2]);control.position=entry[3];control.size=Vector2.ONE*entry[4]
		add_child(control);circles[entry[0]]=control
		var action=entry[0]
		if action=="heavy":
			control.button_down.connect(func():game.session.act("heavy_begin"))
			control.button_up.connect(func():game.session.act("heavy"))
		else:control.pressed.connect(func():game.session.act(action))
		game.action_buttons[action]=control
		var badge=Label.new();badge.hide();control.add_child(badge);game.action_badges[action]=badge
	charge_label=white_label("",Vector2(440,705),Vector2(640,65),17,Color("ffe09d"));charge_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	white_label("WASD 이동   ·   SHIFT 달리기   ·   ESC 메뉴",Vector2(46,845),Vector2(530,26),15,Color("e6f0dc"))
	toast=white_label("",Vector2(371,160),Vector2(685,54),20,Color("fff5cd"));toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	game.region_label=region;game.quest_label=quest;game.hud_stats=money_label;game.health_label=hp_label;game.toast=toast
	game.connection_label=white_label("",Vector2(44,874),Vector2(660,20),12,Color("e6f0dc"))
	boss_hud=preload("res://scripts/boss_hud.gd").new();boss_hud.setup(game);add_child(boss_hud)

func white_label(value:String,at:Vector2,dimensions:Vector2,font_size:int,color:Color=Color("f3f7ee"))->Label:
	var label=game.label(self,value,at,dimensions,font_size,color)
	label.add_theme_color_override("font_outline_color",Color("203e45b0"));label.add_theme_constant_override("outline_size",4)
	return label

func refresh():
	p=game.session.state.players.get(game.session.local_id,{})
	if p.is_empty():return
	name_label.text="%s  ·  Lv.%d" % [p.name,p.level]
	hp_label.text="%d / %d" % [p.hp,p.max_hp]
	money_label.text="● %d 금화    ·    %s" % [p.gold,Content.CLASSES[p.class_id].name]
	region.text="햇살 마을" if game.dungeon.zone=="town" else preload("res://scripts/world_catalog.gd").DUNGEONS[game.dungeon.zone].name
	quest.text="정원 친구들 구하기   %d / 5\n정원지기 진정시키기   %d / 1\n보상 · 금화 100" % [mini(5,p.kills),mini(1,p.boss_kills)]
	if p.quest_done:quest.text="✓ 정원에 웃음이 돌아왔어요.\n의뢰 완료 · 보상 지급 완료\n마을 원정의 문에서 다시 출발하세요."
	if game.dungeon.zone=="town":quest.text="E 시설 이용 · I 가방 · K 성장\n대장간·상점·공방·길드·여관\n원정의 문에서 던전을 고르세요."
	if not p.get("guild_contract",{}).is_empty():quest.text="길드 토벌 · %s\n%d / %d마리\n보상: 180금화 / 정수 1" % [preload("res://scripts/world_catalog.gd").DUNGEONS[p.guild_contract.zone].name,p.guild_contract.progress,p.guild_contract.target]
	quest_title.text="◆ 햇살 마을" if game.dungeon.zone=="town" else "◆ 정원의 소란"
	if not p.get("guild_contract",{}).is_empty():quest_title.text="◆ 길드 토벌 의뢰"
	game.connection_label.text="개인 모험 · 기록 %d · 자동 저장" % game.session.slot
	portrait=preload("res://scripts/gat_art.gd").portrait(p) if Content.gat_appearance(p) else game.textures[Content.costume_role(p)].idle[0]
	for key in circles:
		var control=circles[key];control.cooldown=p.get(key+"_cd",0.0);control.max_cooldown={"nova":4.0,"dodge":0.8,"potion":2.0,"return":8.0}.get(key,0.8)
		if key=="heavy":control.cooldown=p.attack_cd
		if key=="potion":control.count=str(p.potions)
		if key=="nova":control.caption=Content.CLASSES[p.class_id].skill
		if key in Content.ACTIONS:
			var node=Content.active_node(p,key);var trained=Content.action_rank(p,key)>0
			control.caption=node.get("name","미장착") if trained else "K · "+node.get("name","미장착")
			control.modulate=Color.WHITE if trained else Color(0.7,0.8,0.85,0.7)
			control.max_cooldown=maxf(1,node.get("cooldown",7.0)-Content.skill_bonus(p,"skill_haste"))
		control.picture=preload("res://scripts/icon_art.gd").action(p,key,game.session.sim.combat.weapon_type(p))
		control.tooltip_text=control.caption+" ("+control.hotkey+")"
		control.queue_redraw()
		game.action_badges[key].text="%.1fs" % control.cooldown if control.cooldown>0 else ""
	charge_label.text="강공격 충전  %d%%" % int(p.charge_time/0.9*100) if p.charge_time>=0 else ""
	if p.charge_time<0:charge_label.text=game.session.sim.combat.jobs.resource_text(p)
	queue_redraw()

func _draw():
	if p.is_empty():return
	var center=Vector2(82,77)
	draw_circle(center,49,Color("244851bc"));draw_arc(center,47,-PI*0.7,PI*1.17,64,Color("e6c767"),5,true)
	if portrait:
		if Content.gat_appearance(p):draw_texture_rect(portrait,Rect2(center-Vector2(32,32),Vector2(64,64)),false)
		else:
			var height=portrait.get_height()*0.53;var width=portrait.get_width()
			draw_texture_rect_region(portrait,Rect2(center-Vector2(29,33),Vector2(58,64)),Rect2(0,0,width,height))
	draw_circle(Vector2(116,112),16,Color("eed279"))
	draw_string(game.bold_font,Vector2(107,118),str(p.level),HORIZONTAL_ALIGNMENT_CENTER,21,16,Color("264743"))
	bar(Rect2(143,80,277,14),float(p.hp)/p.max_hp,Color("5ad18c"),10)
	bar(Rect2(143,105,277,8),p.stamina/p.max_stamina,Color("67cde2"),10)
	bar(Rect2(46,897,1350,3),float(p.xp)/preload("res://scripts/progression.gd").xp_required(p.level),Color("efd45c"),0)
	if p.charge_time>=0:bar(Rect2(653,758,164,5),p.charge_time/0.9,Color("f6ce70"),0)
func bar(rect:Rect2,ratio:float,color:Color,segments:int):
	draw_rect(rect,Color("1b3543cf"));draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)),color)
	for i in range(1,segments):
		var at=rect.position+Vector2(rect.size.x*i/segments,0);draw_line(at,at+Vector2(0,rect.size.y),Color("20454c90"),2)
