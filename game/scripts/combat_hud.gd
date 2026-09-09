extends Control
const Content=preload("res://scripts/content.gd")
const Circle=preload("res://scripts/action_circle.gd")
const Icons=preload("res://scripts/icon_library.gd")
const Art=preload("res://scripts/ui_art.gd")
var game
var p:Dictionary={}
var circles={}
var name_label:Label
var class_label:Label
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
var codex_button:Button
var boss_hud:Control
var job_resource:Control
var quest_icon="quest"
var quest_emblem:TextureRect
var quest_panel:Control
var quest_toggle:Button
var quest_collapsed=false
func setup(owner_game):
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_IGNORE
	material=preload("res://scripts/gat_art.gd").material()
	name_label=white_label("",Vector2(127,23),Vector2(290,34),24)
	name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter=Control.MOUSE_FILTER_PASS
	class_label=white_label("",Vector2(129,66),Vector2(286,25),16,Color("f3e5c5"))
	hp_label=white_label("",Vector2(133,94),Vector2(270,22),15);hp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	money_label=white_label("",Vector2(153,136),Vector2(258,25),16)
	region=white_label("",Vector2(1079,196),Vector2(324,30),18)
	region.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;region.add_theme_font_override("font",game.serif)
	quest_panel=Art.panel(self,Vector2(1092,237),Vector2(312,112),"paper",15)
	quest_title=game.label(quest_panel,"",Vector2(48,11),Vector2(224,27),18,Color("29434a"))
	quest_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	quest=game.label(quest_panel,"",Vector2(22,49),Vector2(272,52),16,Color("29434a"))
	quest.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	quest_emblem=Icons.picture(quest_panel,"quest",Vector2(13,10),Vector2(28,28))
	quest_toggle=Button.new();quest_toggle.position=Vector2.ZERO;quest_toggle.size=Vector2(312,44);quest_toggle.focus_mode=Control.FOCUS_NONE
	for state in ["normal","hover","pressed","focus"]:
		var style=StyleBoxEmpty.new();style.content_margin_right=14;quest_toggle.add_theme_stylebox_override(state,style)
	quest_toggle.text="−";quest_toggle.alignment=HORIZONTAL_ALIGNMENT_RIGHT;quest_toggle.add_theme_font_override("font",game.fonts);quest_toggle.add_theme_font_size_override("font_size",22);quest_toggle.add_theme_color_override("font_color",Color("29434a"))
	quest_toggle.pressed.connect(toggle_quest);quest_panel.add_child(quest_toggle)
	quest_toggle.tooltip_text="목표 접기";quest_toggle.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	bag_button=preload("res://scripts/hud_sprite_button.gd").new()
	bag_button.setup(game,Icons.texture("bag"),"가방","I",game.toggle_bag);bag_button.position=Vector2(954,20);add_child(bag_button)
	var book=Icons.texture("skills")
	growth_button=preload("res://scripts/hud_sprite_button.gd").new()
	growth_button.setup(game,book,"성장","K",game.toggle_skills);growth_button.position=Vector2(1052,20);add_child(growth_button)
	codex_button=preload("res://scripts/hud_sprite_button.gd").new()
	codex_button.setup(game,Icons.texture("codex"),"도감","B",game.toggle_codex);codex_button.position=Vector2(1150,20);add_child(codex_button)
	var definitions=[
		["skill_q","기술","Q",Vector2(1028,618),96],
		["skill_f","기술","F",Vector2(1152,618),96],
		["skill_v","기술","V",Vector2(1276,618),96],
		["skill_c","기술","C",Vector2(1028,750),96],
		["skill_z","기술","Z",Vector2(1152,750),96],
		["skill_x","기술","X",Vector2(1276,750),96],
		["potion","물약","1",Vector2(596,788),76],
		["interact","상호작용","E",Vector2(698,780),84],
		["return","마을 귀환","R",Vector2(808,796),68]]
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
	charge_label=white_label("",Vector2(982,575),Vector2(416,30),19,Color("ffe09d"));charge_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;charge_label.hide()
	job_resource=preload("res://scripts/job_resource_hud.gd").new();job_resource.setup(game);job_resource.position=Vector2(28,675);add_child(job_resource)
	toast=white_label("",Vector2(427,173),Vector2(612,54),20,Color("fff5cd"));toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.region_label=region;game.quest_label=quest;game.hud_stats=money_label;game.health_label=hp_label;game.toast=toast
	game.connection_label=white_label("",Vector2(44,874),Vector2(660,20),12,Color("e6f0dc"))
	game.connection_label.hide()
	boss_hud=preload("res://scripts/boss_hud.gd").new();boss_hud.setup(game);add_child(boss_hud)

func toggle_quest():
	quest_collapsed=not quest_collapsed
	quest.visible=not quest_collapsed;quest_panel.size.y=44 if quest_collapsed else 112
	quest_toggle.tooltip_text="목표 펼치기" if quest_collapsed else "목표 접기"
	quest_toggle.text="+" if quest_collapsed else "−"
	queue_redraw()

func white_label(value:String,at:Vector2,dimensions:Vector2,font_size:int,color:Color=Color("f3f7ee"))->Label:
	var label=game.label(self,value,at,dimensions,font_size,color)
	label.add_theme_color_override("font_outline_color",Color("203e45b0"));label.add_theme_constant_override("outline_size",4)
	return label

func refresh():
	p=game.session.state.players.get(game.session.local_id,{})
	if p.is_empty():return
	name_label.text=p.name;name_label.tooltip_text=p.name
	class_label.text=Content.CLASSES[p.class_id].name
	hp_label.text="%d / %d" % [p.hp,p.max_hp]
	money_label.text="%s 금화" % str(p.gold)
	var floor_number=game.dungeon.floor_number
	region.text="햇살 마을" if game.dungeon.zone=="town" else preload("res://scripts/abyss_catalog.gd").config(floor_number).name if floor_number>0 else "꽃바람 숲 · 튜토리얼"
	quest_title.text="100층으로 향하는 길";quest_icon="quest"
	if not p.tutorial_done:
		quest_title.text="첫 모험 · 꽃바람 숲";quest_icon="quest_complete" if p.tutorial_kills>=5 else "quest";quest.text="숲의 적 처치   %d / 5\n%s"%[mini(5,p.tutorial_kills),"햇살 마을로 향하기" if p.tutorial_kills>=5 else "보상 · 금화 100"]
	elif game.dungeon.zone=="town":quest.text="최고 돌파   B%d / B100\n다음 목적지 · 원정의 문"%p.cleared_floor
	else:
		var clear=not game.session.state.enemies.values().any(func(e):return e.get("guardian",false) and e.hp>0)
		quest_title.text="B%d · %s"%[floor_number,"레이드" if floor_number%10==0 else "던전 탐사"]
		quest_icon="trophy" if floor_number==100 and clear else "quest_complete" if clear else "boss" if floor_number%10==0 else "quest"
		quest.text="100층 레이드 완료\n마력핵을 잠재웠습니다." if floor_number==100 and clear else "다음 층으로 향하는 길이\n열렸습니다." if clear else "최종 보스 격파" if floor_number==100 else "보스 격파 · 다음 층 해금" if floor_number%10==0 else "최심부 수문장 격파"
	game.connection_label.text=""
	quest_title.tooltip_text=quest_title.text
	quest_emblem.texture=Icons.texture(quest_icon)
	portrait=preload("res://scripts/gat_art.gd").portrait(p) if Content.gat_appearance(p) else game.textures[Content.costume_role(p)].idle[0]
	for key in circles:
		var control=circles[key];control.cooldown=p.get(key+"_cd",0.0);control.max_cooldown={"nova":4.0,"dodge":0.8,"potion":2.0,"return":8.0}.get(key,0.8)
		if key=="heavy":control.cooldown=p.attack_cd
		if key=="potion":control.count=str(p.potions)
		if key=="nova":control.caption=Content.CLASSES[p.class_id].skill
		if key in Content.ACTIONS:
			var node=Content.active_node(p,key);var trained=Content.action_rank(p,key)>0
			control.caption=node.get("name","미장착") if trained else "미장착" if node.is_empty() else "미습득"
			control.locked=not trained
			if trained:
				control.max_cooldown=preload("res://scripts/job_balance.gd").profile(p,node,Content.action_rank(p,key),game.session.sim.damage_for(p),p.max_hp,p.skill_ranks.get(node.id+"_upgrade",0)>0).cooldown if Content.job(p) else preload("res://scripts/skill_scaling.gd").profile(node,Content.action_rank(p,key),preload("res://scripts/active_skills.gd").bonuses(p)).cooldown
			control.cooldown=p.skill_cooldowns.get(node.get("id",""),0.)
			control.rank_text=str(Content.action_rank(p,key))+"/"+str(Content.max_rank(node)) if trained else ""
		if key in Content.ACTIONS and Content.action_rank(p,key)<=0:
			control.picture=Icons.texture("skill_empty" if Content.active_node(p,key).is_empty() else "skill_locked")
		else:control.picture=preload("res://scripts/icon_art.gd").action(p,key,game.session.sim.combat.weapon_type(p))
		control.tooltip_text=control.caption+" ("+control.hotkey+")"
		if key in Content.ACTIONS and control.locked:control.tooltip_text="K · 성장에서 기술을 배우고 배치하세요." if Content.active_node(p,key).is_empty() else Content.active_node(p,key).name+" · 아직 배우지 않은 기술"
		control.queue_redraw()
		game.action_badges[key].text="%.1fs" % control.cooldown if control.cooldown>0 else ""
	var interact=circles.interact;interact.caption="상호작용"
	if game.dungeon.zone=="town":
		if not preload("res://scripts/world_catalog.gd").nearest(p.pos).is_empty():interact.caption="대화"
	elif game.session.state.drops.values().any(func(drop):return drop.owner==p.id and drop.pos.distance_to(p.pos)<=1.8):interact.caption="줍기"
	elif game.dungeon.floor_number>0 and p.pos.distance_to(game.dungeon.exit_position)<2.8:interact.caption="출구"
	elif game.dungeon.in_town(p.pos):interact.caption="회복 · 보급"
	interact.tooltip_text=interact.caption+" (E)"
	charge_label.text="강공격 충전  %d%%" % clampi(p.charge_time/0.9*100,0,100) if p.charge_time>=0 else ""
	charge_label.visible=p.charge_time>=0
	job_resource.refresh(p)
	queue_redraw()

func _draw():
	if p.is_empty():return
	Icons.draw(self,"gold",Rect2(126,136,22,22))
	var center=Vector2(72,73)
	draw_texture_rect(Art.texture("medallion"),Rect2(center-Vector2(53,53),Vector2(106,106)),false)
	if portrait:
		if Content.gat_appearance(p):draw_texture_rect(portrait,Rect2(center-Vector2(32,32),Vector2(64,64)),false)
		else:
			var height=portrait.get_height()*0.53;var width=portrait.get_width()
			draw_texture_rect_region(portrait,Rect2(center-Vector2(29,33),Vector2(58,64)),Rect2(0,0,width,height))
	draw_string_outline(game.bold_font,Vector2(46,139),"LV."+str(p.level),HORIZONTAL_ALIGNMENT_CENTER,70,16,4,Color("263b35"))
	draw_string(game.bold_font,Vector2(46,139),"LV."+str(p.level),HORIZONTAL_ALIGNMENT_CENTER,70,16,Color("fff0b9"))
	bar(Rect2(130,95,278,23),float(p.hp)/p.max_hp,Color("5ad18c"),0)
	bar(Rect2(130,123,278,7),p.stamina/p.max_stamina,Color("67cde2"),0)
	bar(Rect2(46,897,1350,3),float(p.xp)/preload("res://scripts/progression.gd").xp_required(p.level),Color("efd45c"),0)

func bar(rect:Rect2,ratio:float,color:Color,segments:int):
	draw_rect(rect,Color("1b3543cf"));draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)),color)
	for i in range(1,segments):
		var at=rect.position+Vector2(rect.size.x*i/segments,0);draw_line(at,at+Vector2(0,rect.size.y),Color("20454c90"),2)
