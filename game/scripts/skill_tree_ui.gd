extends Panel
const Content=preload("res://scripts/content.gd")
const Progression=preload("res://scripts/progression.gd")
var game
var nodes={}
var points:Label
var description:Label
var selected:Label
var invest:Button
var choice=""
var class_buttons={}
var reset_button:Button
var branch_labels=[]
var signature=""
var mode="skills"
var stats_panel:Panel
var stats_text:Label
var stat_buttons={}
var bind_buttons=[]
var details:Panel
var selected_icon:TextureRect
func setup(owner_game):
	game=owner_game;position=Vector2(128,66);size=Vector2(1184,770);mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",game.style(Color("eaf1e9fc"),Color("a2b9a7"),12))
	game.label(self,"별자리의 길",Vector2(28,18),Vector2(350,43),31)
	game.button(self,"닫기  K",Vector2(1035,24),Vector2(122,38),game.toggle_skills)
	points=game.label(self,"",Vector2(670,28),Vector2(360,32),20,game.GOLD)
	var index=0
	for key in Content.CLASSES:
		var b=game.button(self,Content.CLASSES[key].name,Vector2(26+index*211,76),Vector2(196,41),func():game.session.act("class",key);choice="";refresh(true))
		class_buttons[key]=b;index+=1
	game.button(self,"스킬 50",Vector2(680,76),Vector2(145,41),func():mode="skills";refresh(true))
	game.button(self,"능력치 투자",Vector2(838,76),Vector2(170,41),func():mode="stats";refresh(true))
	game.label(self,"연결된 선행 중 하나를 배워 경로를 여세요. 밝은 테두리: 액티브 · 각 노드 최대 3랭크",Vector2(29,137),Vector2(1090,24),15,game.MUTED)
	details=game.panel(self,Vector2(860,182),Vector2(297,493),Color("dce8dd"))
	selected_icon=TextureRect.new();selected_icon.position=Vector2(16,18);selected_icon.size=Vector2(64,64);selected_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;selected_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;details.add_child(selected_icon)
	selected=game.label(details,"스킬을 선택하세요",Vector2(88,16),Vector2(192,64),23);selected.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description=game.label(details,"",Vector2(20,88),Vector2(256,255),17);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	invest=game.button(details,"포인트 투자 +1",Vector2(20,348),Vector2(257,43),func():game.session.act("invest",choice);refresh(true),true)
	for i in range(3):
		var action=["skill_f","skill_v","skill_c"][i]
		bind_buttons.append(game.button(details,["F 배치","V 배치","C 배치"][i],Vector2(20+i*87,412),Vector2(82,41),func():game.session.act("bind_skill",action+":"+choice);refresh(true)))
	reset_button=game.button(self,"스킬 초기화",Vector2(895,711),Vector2(242,37),func():game.session.act("reset_skills" if mode=="skills" else "reset_stats");refresh(true))
	game.label(self,"레벨마다 스킬 +1 · 능력치 +3 / 마을에서 무료 초기화",Vector2(29,720),Vector2(850,27),16,game.MUTED)
	stats_panel=game.panel(self,Vector2(28,180),Vector2(803,502),Color("dce8dd"))
	stats_text=game.label(stats_panel,"",Vector2(28,18),Vector2(749,70),22)
	index=0
	for key in Progression.NAMES:
		game.label(stats_panel,Progression.NAMES[key],Vector2(28,116+index*83),Vector2(90,30),24)
		game.label(stats_panel,Progression.HELP[key],Vector2(125,117+index*83),Vector2(516,55),17)
		stat_buttons[key]=game.button(stats_panel,"+1",Vector2(655,108+index*83),Vector2(112,48),func():game.session.act("stat",key);refresh(true))
		index+=1
	hide()
func player()->Dictionary:return game.session.state.players.get(game.session.local_id,{})
func _process(_delta):
	if visible:refresh()
func refresh(force=false):
	var p=player()
	if p.is_empty():return
	var next=JSON.stringify([p.class_id,p.skill_ranks,p.level,p.get("stats",{}),p.get("skill_loadout",{}),game.dungeon.in_town(p.pos)])+choice+mode
	if next==signature and not force:return
	signature=next
	for control in nodes.values():remove_child(control);control.queue_free()
	nodes.clear();stats_panel.visible=mode=="stats"
	points.text="스킬 %d  ·  능력치 %d" % [Content.available_points(p),Progression.available(p)]
	var list=Content.SKILLS[p.class_id]
	if choice=="":choice=list[0].id
	for i in range(list.size()):
		var skill=list[i];var rank=int(p.skill_ranks.get(skill.id,0))
		if mode=="skills":
			var b=game.button(self,"",node_position(skill),Vector2(38,38),func():choice=skill.id;refresh(true),rank>0)
			b.icon=preload("res://scripts/icon_art.gd").skill(skill);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",36)
			if rank>0:
				var badge=game.label(b,str(rank),Vector2(25,23),Vector2(16,16),12,Color("fff4c7"));badge.add_theme_constant_override("outline_size",4);badge.add_theme_color_override("font_outline_color",Color("163c37"))
			b.add_theme_font_size_override("font_size",12);b.tooltip_text=skill.name+" · "+skill.description
			b.add_theme_stylebox_override("normal",game.style(Color("c6e8df") if rank>0 else Color("f2f5e9"),Color("d2a750") if skill.effect=="active" else Color("709687"),19))
			if not Content.can_invest(p,skill.id) and rank==0:b.modulate=Color(.70,.77,.73)
			if choice==skill.id:b.add_theme_stylebox_override("normal",game.style(Color("ffe9ac"),Color("b18b3e"),19))
			for style_name in ["normal","hover","pressed","focus"]:
				var compact=b.get_theme_stylebox(style_name).duplicate()
				compact.content_margin_left=0;compact.content_margin_right=0;compact.content_margin_top=0;compact.content_margin_bottom=0
				b.add_theme_stylebox_override(style_name,compact)
			nodes[skill.id]=b
		if choice==skill.id:
			selected_icon.texture=preload("res://scripts/icon_art.gd").skill(skill)
			selected.text=skill.name;description.text=skill.description+"\n\n랭크 %d / 3 · 1포인트\n%s" % [rank,"액티브 · 배운 뒤 F/V/C 배치" if skill.effect=="active" else "패시브 · 배우면 항상 적용"]
			var names=PackedStringArray()
			for parent in skill.parents:
				for other in list:
					if other.id==parent:names.append(other.name)
			if not names.is_empty():description.text+="\n\n선행 중 하나:\n"+" / ".join(names)
			invest.disabled=not Content.can_invest(p,skill.id)
			for b in bind_buttons:b.disabled=skill.effect!="active" or rank<=0
	if mode=="stats":
		selected_icon.texture=preload("res://scripts/icon_art.gd").function_icon("growth")
		stats_text.text="능력치 포인트 %d · 레벨 %d\n힘 %d / 민첩 %d / 지능 %d / 체력 %d" % [Progression.available(p),p.level,p.stats.strength,p.stats.dexterity,p.stats.intelligence,p.stats.vitality]
		for key in stat_buttons:stat_buttons[key].disabled=Progression.available(p)<=0
		selected.text="내 성장";description.text="공격력 %d\n생명력 %d\n방어력 %d\n기력 %d\n\n다음 레벨 경험치\n%d / %d\n\n기존 레벨에도 미사용 포인트가 소급 지급됩니다." % [game.session.sim.damage_for(p),p.max_hp,p.defense,p.max_stamina,p.xp,Progression.xp_required(p.level)]
		invest.disabled=true
		for b in bind_buttons:b.disabled=true
	for key in class_buttons:class_buttons[key].disabled=not game.dungeon.in_town(p.pos) or p.class_id==key
	reset_button.disabled=not game.dungeon.in_town(p.pos);reset_button.text="스킬 초기화" if mode=="skills" else "능력치 초기화"
	queue_redraw()
func node_position(node:Dictionary)->Vector2:
	var angle=-PI/2+int(node.column)*TAU/10
	return Vector2(430,433)+Vector2(cos(angle)*1.46,sin(angle))*(70+int(node.tier)*42)-Vector2(19,19)
func _draw():
	var p=player()
	if p.is_empty() or mode!="skills":return
	for tier in range(5):
		draw_set_transform(Vector2(430,433),0,Vector2(1.46,1));draw_arc(Vector2.ZERO,70+tier*42,0,TAU,100,Color("adc7b160"),1,true)
	draw_set_transform(Vector2.ZERO)
	var list=Content.SKILLS[p.class_id]
	for node in list:
		for parent in node.parents:
			for other in list:
				if other.id==parent:draw_line(node_position(other)+Vector2(19,19),node_position(node)+Vector2(19,19),Color("4e9c86") if p.skill_ranks.get(parent,0)>0 else Color("a6bdae"),2,true)
