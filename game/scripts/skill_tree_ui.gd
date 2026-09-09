extends Panel
const Content=preload("res://scripts/content.gd")
const Progression=preload("res://scripts/progression.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Art=preload("res://scripts/ui_art.gd")
var game
var nodes={}
var points:Label
var description:Label
var selected:Label
var invest:Button
var choice=""
var class_buttons={}
var reset_button:Button
var signature=""
var mode="skills"
var stats_panel:Control
var stats_text:Label
var stat_buttons={}
var bind_buttons=[]
var details:Control
var selected_icon:TextureRect
var scroll:ScrollContainer
var plot:Control
var search:LineEdit
var filter_index=0
var filters=[]
var status:Label
var prerequisites:Control
var comparison:Control
var comparison_rows=[]
var notice:Label
class Web extends Control:
	var owner_tree
	func _draw():
		var p=owner_tree.player();var list=Content.SKILLS[p.class_id]
		for node in list:
			for parent in node.parents:
				var from_node=list.filter(func(n):return n.id==parent)[0]
				var start=owner_tree.node_position(from_node)+Vector2(160,36);var end=owner_tree.node_position(node)+Vector2(0,36)
				var focus=node.id==owner_tree.choice or parent==owner_tree.choice
				var color=Color("bd852f") if focus else Color("348779") if p.skill_ranks.get(parent,0)>0 else Color("8d978c80")
				var line=PackedVector2Array()
				for i in range(21):
					var t=i/20.0;line.append(pow(1-t,3)*start+3*pow(1-t,2)*t*(start+Vector2(22,0))+3*(1-t)*t*t*(end-Vector2(22,0))+pow(t,3)*end)
				draw_polyline(line,color,3.5 if focus else 1.8,true)
				if focus:draw_colored_polygon(PackedVector2Array([end,end+Vector2(-7,-4),end+Vector2(-7,4)]),color)
func setup(owner_game):
	game=owner_game;position=Vector2(24,24);size=Vector2(1392,852);mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());Art.decorate(self,"paper",38)
	Art.picture(self,Art.texture("crest"),Vector2(24,14),Vector2(74,74))
	game.label(self,"별자리의 길",Vector2(112,22),Vector2(400,40),31)
	points=game.label(self,"",Vector2(676,23),Vector2(510,38),24)
	game.button(self,"닫기  K",Vector2(1214,26),Vector2(145,42),game.toggle_skills)
	var index=0
	for key in Content.CLASSES:
		class_buttons[key]=game.button(self,Content.CLASSES[key].name,Vector2(30+index*186,90),Vector2(176,43),func():game.session.act("class",key);choice="";refresh(true));index+=1
	game.button(self,"스킬 트리",Vector2(656,90),Vector2(134,43),func():mode="skills";refresh(true))
	game.button(self,"능력치 배분",Vector2(802,90),Vector2(151,43),func():mode="stats";refresh(true))
	reset_button=game.button(self,"스킬 초기화",Vector2(1094,90),Vector2(265,43),func():game.session.act("reset_skills" if mode=="skills" else "reset_stats");refresh(true))
	search=game.line_edit(self,"",Vector2(30,150),Vector2(315,40));search.placeholder_text="스킬 이름 · 효과 검색";search.text_changed.connect(func(_v):refresh(true);focus_match())
	for i in range(3):filters.append(game.button(self,["전체 50","액티브","배울 수 있음"][i],Vector2(359+i*139,150),Vector2(129,40),func():filter_index=i;refresh(true);focus_match()))
	game.button(self,"선택 찾기",Vector2(792,150),Vector2(160,40),func():focus_choice())
	for i in range(5):
		var heading=game.label(self,["Ⅰ  기초","Ⅱ  단련","Ⅲ  전투","Ⅳ  숙련","Ⅴ  특화"][i],Vector2(43+i*176,204),Vector2(160,27),18);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	scroll=ScrollContainer.new();scroll.position=Vector2(30,236);scroll.size=Vector2(923,548);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	plot=Web.new();plot.owner_tree=self;plot.custom_minimum_size=Vector2(902,943);scroll.add_child(plot)
	details=Art.panel(self,Vector2(974,151),Vector2(385,645),"paper",27)
	selected_icon=Art.picture(details,null,Vector2(19,19),Vector2(66,66));selected=game.label(details,"",Vector2(99,20),Vector2(267,64),23);selected.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status=game.label(details,"",Vector2(22,96),Vector2(343,28),18)
	description=game.label(details,"",Vector2(22,130),Vector2(343,56),16);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	comparison=Control.new();comparison.position=Vector2(22,193);comparison.size=Vector2(342,230);details.add_child(comparison)
	prerequisites=Control.new();prerequisites.position=Vector2(22,430);prerequisites.size=Vector2(342,78);details.add_child(prerequisites)
	invest=game.button(details,"",Vector2(22,517),Vector2(342,49),invest_selected,true)
	for i in range(3):
		var action=["skill_f","skill_v","skill_c"][i]
		bind_buttons.append(game.button(details,["F 배치","V 배치","C 배치"][i],Vector2(22+i*117,585),Vector2(107,40),func():game.session.act("bind_skill",action+":"+choice);refresh(true)))
	notice=game.label(self,"이름이 보이는 노드를 선택하세요. 휠로 아래 경로까지 탐색할 수 있습니다.",Vector2(70,793),Vector2(894,25),16)
	stats_panel=Art.panel(self,Vector2(30,204),Vector2(923,580),"paper",25)
	stats_text=game.label(stats_panel,"",Vector2(30,26),Vector2(865,76),24)
	index=0
	for key in Progression.NAMES:
		game.label(stats_panel,Progression.NAMES[key],Vector2(35,139+index*96),Vector2(96,34),25)
		game.label(stats_panel,Progression.HELP[key],Vector2(149,141+index*96),Vector2(560,56),18)
		stat_buttons[key]=game.button(stats_panel,"+1",Vector2(744,129+index*96),Vector2(140,50),func():game.session.act("stat",key);refresh(true));index+=1
	hide()
func player()->Dictionary:return game.session.state.players.get(game.session.local_id,{})
func _process(_delta):
	if visible:refresh()
func node_position(node:Dictionary)->Vector2:return Vector2(14+int(node.tier)*176,12+int(node.column)*92)
func matches(node:Dictionary,p:Dictionary)->bool:
	var query=search.text.strip_edges().to_lower()
	return (query.is_empty() or (node.name+" "+node.description).to_lower().contains(query)) and (filter_index==0 or filter_index==1 and node.effect=="active" or filter_index==2 and Content.can_invest(p,node.id))
func focus_choice():
	if nodes.has(choice):scroll.ensure_control_visible(nodes[choice])
func focus_match():
	for node in Content.SKILLS[player().class_id]:
		if matches(node,player()):choice=node.id;refresh(true);focus_choice();return
	notice.text="조건에 맞는 기술이 없습니다. 검색어나 필터를 바꿔보세요."
func clear(control:Node):
	for child in control.get_children():control.remove_child(child);child.queue_free()
func invest_selected():
	var name=selected.text
	if game.session.act("invest",choice):notice.text=name+" · Lv."+str(player().skill_ranks[choice])+" 강화 완료 — 새 효과가 적용되었습니다."
	refresh(true)
func refresh(force=false):
	var p=player()
	if p.is_empty():return
	var next=JSON.stringify([p.class_id,p.skill_ranks,p.level,p.get("stats",{}),p.get("skill_loadout",{}),p.equipment,p.inventory,game.dungeon.in_town(p.pos),choice,mode,search.text,filter_index])
	if next==signature and not force:return
	signature=next;clear(plot);nodes.clear();stats_panel.visible=mode=="stats";scroll.visible=mode=="skills"
	points.text="LV.%d   ·   스킬 포인트 %d   ·   능력치 %d" % [p.level,Content.available_points(p),Progression.available(p)]
	var list=Content.SKILLS[p.class_id]
	if not list.any(func(n):return n.id==choice):choice=list[0].id
	for skill in list:
		var rank=int(p.skill_ranks.get(skill.id,0));var ready=Content.can_invest(p,skill.id);var active=skill.effect=="active"
		if mode=="skills":
			var b=game.button(plot,"",node_position(skill),Vector2(160,72),func():choice=skill.id;refresh(true))
			b.get_meta("rpg_frame").hide()
			for state_name in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
			b.icon=preload("res://scripts/icon_art.gd").skill(skill);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",1)
			for state_name in ["normal","hover","pressed","focus","disabled"]:b.add_theme_color_override("icon_"+state_name+"_color",Color.TRANSPARENT)
			Art.decorate(b,"equipped" if rank>0 else "magic" if active else "socket",12)
			Art.picture(b,b.icon,Vector2(10,13),Vector2(39,39))
			var name=game.label(b,skill.name,Vector2(56,10),Vector2(94,38),16,Color("fff1cf"));name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			game.label(b,"Lv.%d/3 %s" % [rank,"MAX" if rank==3 else "강화" if ready and rank>0 else "학습" if ready else "배움" if rank>0 else "잠금" if not skill.parents.is_empty() else "대기"],Vector2(54,42),Vector2(103,20),13,Color("95efd4") if rank>0 else Color("ffe4a5"))
			if choice==skill.id:b.modulate=Color(1.18,1.15,.94)
			elif not matches(skill,p):b.modulate=Color(.55,.55,.55,.6)
			b.tooltip_text=skill.name+" · "+("사용 기술" if active else "상시 효과")+"\n"+skill.description;nodes[skill.id]=b
		if choice==skill.id:show_details(skill,p,rank)
	if mode=="stats":
		stats_text.text="사용 가능한 능력치 %d\n힘 %d  ·  민첩 %d  ·  지능 %d  ·  체력 %d" % [Progression.available(p),p.stats.strength,p.stats.dexterity,p.stats.intelligence,p.stats.vitality]
		for key in stat_buttons:stat_buttons[key].disabled=Progression.available(p)<=0
		selected.text="모험가의 성장";selected_icon.texture=Art.texture("crest");status.text="레벨마다 능력치 +3 / 스킬 +1"
		description.text="얻은 포인트를 직접 배분하면 능력치가 강해집니다. 마을에서 무료로 초기화할 수 있습니다."
		clear(comparison);clear(prerequisites);comparison_rows=[]
		var rows=[["공격력",str(game.session.sim.damage_for(p))],["최대 생명력",str(p.max_hp)],["방어력",str(p.defense)],["최대 기력",str(int(p.max_stamina))],["다음 레벨 경험치","%d / %d" % [p.xp,Progression.xp_required(p.level)]]]
		for i in range(rows.size()):game.label(comparison,rows[i][0]+"    "+rows[i][1],Vector2(0,i*37),Vector2(340,31),19)
		invest.text="왼쪽에서 능력치를 배분하세요";invest.disabled=true
		for b in bind_buttons:b.disabled=true
	for key in class_buttons:class_buttons[key].disabled=not game.dungeon.in_town(p.pos) or p.class_id==key
	reset_button.disabled=not game.dungeon.in_town(p.pos);reset_button.text="스킬 초기화" if mode=="skills" else "능력치 초기화"
	plot.queue_redraw()
func show_details(skill:Dictionary,p:Dictionary,rank:int):
	selected.text=skill.name;selected_icon.texture=preload("res://scripts/icon_art.gd").skill(skill)
	var ready=Content.can_invest(p,skill.id)
	status.text=("액티브" if skill.effect=="active" else "패시브")+"  ·  Lv.%d / 3  ·  " % rank+("완성" if rank==3 else "투자 가능" if ready else "포인트 부족" if Content.available_points(p)==0 else "선행 필요")
	description.text=skill.description.split(" · 강화")[0].split(" · 랭크별")[0].trim_prefix("F · ").trim_prefix("V · ").trim_prefix("C · ")
	clear(comparison);clear(prerequisites)
	var bonuses=preload("res://scripts/active_skills.gd").bonuses(p)
	var current=Scaling.metrics(skill,rank,game.session.sim.damage_for(p),p.max_hp,bonuses)
	var upgraded=Scaling.metrics(skill,mini(3,rank+1),game.session.sim.damage_for(p),p.max_hp,bonuses)
	comparison_rows=[]
	game.label(comparison,"효과",Vector2.ZERO,Vector2(166,26),16)
	game.label(comparison,"현재",Vector2(168,0),Vector2(72,26),16)
	game.label(comparison,"다음" if rank<3 else "최대",Vector2(255,0),Vector2(86,26),16)
	for i in range(current.size()):
		comparison_rows.append([current[i][0],current[i][1],upgraded[i][1]])
		game.label(comparison,current[i][0],Vector2(0,31+i*27),Vector2(166,26),15)
		game.label(comparison,current[i][1],Vector2(168,31+i*27),Vector2(81,26),15)
		game.label(comparison,upgraded[i][1],Vector2(255,31+i*27),Vector2(89,26),15,Color("217d65"))
	if not skill.parents.is_empty():
		game.label(prerequisites,"선행 중 하나를 배우세요 · 눌러서 이동",Vector2.ZERO,Vector2(343,23),14)
		for i in range(skill.parents.size()):
			var parent=skill.parents[i];var other=Content.SKILLS[p.class_id].filter(func(n):return n.id==parent)[0]
			var b=game.button(prerequisites,("✓ " if p.skill_ranks.get(parent,0)>0 else "")+other.name,Vector2(i*173,28),Vector2(166,38),func():choice=parent;refresh(true);focus_choice());b.add_theme_font_size_override("font_size",14)
	else:game.label(prerequisites,"시작 노드 · 선행 기술 없이 배울 수 있습니다.",Vector2(0,15),Vector2(343,40),15)
	invest.text="최대 레벨 달성" if rank==3 else ("배우기 · 1 SP" if rank==0 else "Lv.%d → Lv.%d 강화 · 1 SP" % [rank,rank+1]);invest.disabled=not ready
	for i in range(bind_buttons.size()):
		var action=["skill_f","skill_v","skill_c"][i];var assigned=Content.active_node(p,action).get("id","")==skill.id
		bind_buttons[i].disabled=skill.effect!="active" or rank<=0;bind_buttons[i].text=["F","V","C"][i]+(" 사용 중" if assigned and rank>0 else " 배치")
