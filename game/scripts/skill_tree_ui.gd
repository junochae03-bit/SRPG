extends Panel
const Content=preload("res://scripts/content.gd")
const Progression=preload("res://scripts/progression.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Balance=preload("res://scripts/job_balance.gd")
const Art=preload("res://scripts/ui_art.gd")
var game
var nodes={}
var points:Label
var description:Label
var selected:Label
var invest:Button
var choice=""
var class_buttons={}
var class_picker:OptionButton
var role_label:Label
var headings=[]
var loadout_strip:Control
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
				var start=owner_tree.node_position(from_node)+Vector2(owner_tree.node_width(),36);var end=owner_tree.node_position(node)+Vector2(0,36)
				if is_equal_approx(start.x-owner_tree.node_width(),end.x):start=owner_tree.node_position(from_node)+Vector2(owner_tree.node_width()/2,72);end=owner_tree.node_position(node)+Vector2(owner_tree.node_width()/2,0)
				var focus=node.id==owner_tree.choice or parent==owner_tree.choice
				var color=Color("bd852f") if focus else Color("348779") if p.skill_ranks.get(parent,0)>0 else Color("8d978c80")
				var line=PackedVector2Array()
				for i in range(21):
					var t=i/20.0;line.append(pow(1-t,3)*start+3*pow(1-t,2)*t*(start+Vector2(22,0))+3*(1-t)*t*t*(end-Vector2(22,0))+pow(t,3)*end)
				draw_polyline(line,color,3.5 if focus else 1.8,true)
				if focus:draw_colored_polygon(PackedVector2Array([end,end+Vector2(-7,-4),end+Vector2(-7,4)]),color)
func setup(owner_game):
	game=owner_game;Content.initialize_jobs();position=Vector2(24,24);size=Vector2(1392,852);mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());Art.decorate(self,"paper",38)
	Art.picture(self,Art.texture("crest"),Vector2(24,14),Vector2(74,74))
	game.label(self,"별자리의 길",Vector2(112,22),Vector2(400,40),31)
	points=game.label(self,"",Vector2(676,23),Vector2(510,38),24)
	game.button(self,"닫기  K",Vector2(1214,26),Vector2(145,42),game.toggle_skills)
	class_picker=OptionButton.new();class_picker.position=Vector2(30,90);class_picker.size=Vector2(265,43)
	class_picker.add_theme_font_override("font",game.fonts);class_picker.get_popup().add_theme_font_override("font",game.fonts);class_picker.add_theme_font_size_override("font_size",18)
	add_child(class_picker)
	for state in ["normal","hover","pressed","focus"]:class_picker.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	class_picker.add_theme_color_override("font_color",Color("25454b"));Art.decorate(class_picker,"paper",15)
	for key in Content.CLASSES:
		var c=Content.CLASSES[key];class_picker.add_item(c.name+(" · 전직" if c.has("base") and not c.get("starter",false) else " · 기초"));class_picker.set_item_metadata(class_picker.item_count-1,key)
	class_picker.item_selected.connect(func(i):game.session.act("class",class_picker.get_item_metadata(i));choice="";search.text="";scroll.scroll_vertical=0;refresh(true))
	role_label=game.label(self,"",Vector2(310,92),Vector2(647,40),18)
	game.button(self,"스킬 트리",Vector2(974,90),Vector2(168,43),func():mode="skills";refresh(true))
	game.button(self,"능력치 배분",Vector2(1154,90),Vector2(205,43),func():mode="stats";refresh(true))
	reset_button=game.button(self,"스킬 초기화",Vector2(716,795),Vector2(237,34),func():game.session.act("reset_skills" if mode=="skills" else "reset_stats");refresh(true))
	search=game.line_edit(self,"",Vector2(30,150),Vector2(315,40));search.placeholder_text="스킬 이름 · 효과 검색";search.text_changed.connect(func(_v):refresh(true);focus_match())
	for i in range(3):filters.append(game.button(self,["전체 경로","액티브","투자 가능"][i],Vector2(359+i*139,150),Vector2(129,40),func():filter_index=i;refresh(true);focus_match()))
	game.button(self,"선택 찾기",Vector2(792,150),Vector2(160,40),func():focus_choice())
	for i in range(5):
		var heading=game.label(self,["Ⅰ  기초","Ⅱ  단련","Ⅲ  전투","Ⅳ  숙련","Ⅴ  특화"][i],Vector2(43+i*176,204),Vector2(160,27),18);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;headings.append(heading)
	scroll=ScrollContainer.new();scroll.position=Vector2(30,236);scroll.size=Vector2(923,500);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	plot=Web.new();plot.owner_tree=self;plot.custom_minimum_size=Vector2(902,943);scroll.add_child(plot)
	loadout_strip=Control.new();loadout_strip.position=Vector2(30,742);loadout_strip.size=Vector2(923,47);add_child(loadout_strip)
	details=Art.panel(self,Vector2(974,151),Vector2(385,688),"paper",27)
	selected_icon=Art.picture(details,null,Vector2(19,19),Vector2(66,66));selected=game.label(details,"",Vector2(99,20),Vector2(267,64),23);selected.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status=game.label(details,"",Vector2(22,96),Vector2(343,28),18)
	description=game.label(details,"",Vector2(22,130),Vector2(343,56),16);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible=3;description.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	comparison=Control.new();comparison.position=Vector2(22,193);comparison.size=Vector2(342,230);details.add_child(comparison)
	prerequisites=Control.new();prerequisites.position=Vector2(22,430);prerequisites.size=Vector2(342,78);details.add_child(prerequisites)
	invest=game.button(details,"",Vector2(22,517),Vector2(342,49),invest_selected,true)
	for i in range(6):
		var action=Content.ACTIONS[i]
		var b=game.button(details,"QFVCZX"[i]+" 배치",Vector2(22+(i%3)*117,578+int(i/3)*48),Vector2(107,42),func():game.session.act("bind_skill",action+":"+choice);refresh(true))
		b.add_theme_font_size_override("font_size",15);bind_buttons.append(b)

	notice=game.label(self,"휠: 경로 탐색 · 연결선: 선행 조건 · 장착 변경은 마을에서",Vector2(36,795),Vector2(662,38),16)
	stats_panel=Art.panel(self,Vector2(30,204),Vector2(923,580),"paper",25)
	stats_text=game.label(stats_panel,"",Vector2(30,26),Vector2(865,76),24)
	var index=0
	for key in Progression.NAMES:
		game.label(stats_panel,Progression.NAMES[key],Vector2(35,139+index*96),Vector2(96,34),25)
		game.label(stats_panel,Progression.HELP[key],Vector2(149,141+index*96),Vector2(560,56),18)
		stat_buttons[key]=game.button(stats_panel,"+1",Vector2(744,129+index*96),Vector2(140,50),func():game.session.act("stat",key);refresh(true));index+=1
	hide()
func player()->Dictionary:return game.session.state.players.get(game.session.local_id,{})
func _process(_delta):
	if visible:refresh()
func node_width()->float:return 208. if Content.job(player()) else 160.
func node_position(node:Dictionary)->Vector2:return Vector2(14+int(node.tier)*(222 if Content.job(player()) else 176),12+int(node.column)*92)
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
	if game.session.act("invest",choice):notice.text=name+" · 랭크 "+str(player().skill_ranks[choice])+" 강화 완료 · 새 효과 적용"
	refresh(true)
func refresh(force=false):
	var p=player()
	if p.is_empty():return
	var next=JSON.stringify([p.class_id,p.skill_ranks,p.level,p.get("stats",{}),p.get("skill_loadout",{}),p.equipment,p.inventory,game.dungeon.in_town(p.pos),choice,mode,search.text,filter_index])
	if next==signature and not force:return
	signature=next;clear(plot);nodes.clear();stats_panel.visible=mode=="stats";scroll.visible=mode=="skills"
	points.text="LV.%d   ·   스킬 포인트 %d   ·   능력치 %d" % [p.level,Content.available_points(p),Progression.available(p)]
	role_label.text=Balance.role(p.class_id)[0];role_label.tooltip_text=Balance.role(p.class_id)[1]
	clear(loadout_strip);loadout_strip.visible=mode=="skills"
	for i in range(6):
		var equipped=Content.active_node(p,Content.ACTIONS[i]);var trained=Content.action_rank(p,Content.ACTIONS[i])>0
		var b=game.button(loadout_strip,"",Vector2(i*155,0),Vector2(148,44),func():
			if not equipped.is_empty() and trained:choice=equipped.id;refresh(true);focus_choice())
		if trained:Art.picture(b,preload("res://scripts/icon_art.gd").skill(equipped),Vector2(7,6),Vector2(31,31))
		game.label(b,"QFVCZX"[i]+" · "+(equipped.get("name","") if trained else "미장착"),Vector2(41,8),Vector2(100,31),12).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		b.tooltip_text=(equipped.get("name","")+" · 눌러서 경로 찾기") if trained else "배운 액티브를 선택하고 오른쪽에서 배치하세요."
	for i in range(class_picker.item_count):
		var key=class_picker.get_item_metadata(i);var cls=Content.CLASSES[key]
		class_picker.set_item_disabled(i,not game.dungeon.in_town(p.pos) or (cls.has("base") and not cls.get("starter",false) and (p.level<30 or Content.base_class(p.class_id)!=cls.base)))
		if key==p.class_id:class_picker.select(i)
	for i in range(headings.size()):
		headings[i].visible=mode=="skills" and (not Content.job(p) or i<4)
		headings[i].position.x=43+i*(222 if Content.job(p) else 176);headings[i].size.x=node_width()
		headings[i].text=(["Lv.30 · 시작","Lv.38 · 발전","Lv.46 · 숙련","Lv.54 · 완성"][mini(i,3)] if not Content.CLASSES[p.class_id].get("starter",false) else ["Lv.2 · 입문","Lv.8 · 단련","Lv.16 · 실전","Lv.24 · 전직 준비"][mini(i,3)]) if Content.job(p) else ["Ⅰ 기초","Ⅱ 단련","Ⅲ 전투","Ⅳ 숙련","Ⅴ 특화"][i]
	var list=Content.SKILLS[p.class_id]
	plot.custom_minimum_size.y=92*(1+list.map(func(n):return int(n.column)).max())+24
	if not list.any(func(n):return n.id==choice):choice=list[0].id
	for skill in list:
		var rank=int(p.skill_ranks.get(skill.id,0));var ready=Content.can_invest(p,skill.id);var active=skill.effect=="active"
		if mode=="skills":
			var b=game.button(plot,"",node_position(skill),Vector2(node_width(),72),func():choice=skill.id;refresh(true))
			b.get_meta("rpg_frame").hide()
			for state_name in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
			b.icon=preload("res://scripts/icon_art.gd").skill(skill);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",1)
			for state_name in ["normal","hover","pressed","focus","disabled"]:b.add_theme_color_override("icon_"+state_name+"_color",Color.TRANSPARENT)
			Art.decorate(b,"equipped" if rank>0 else "magic" if active else "socket",12)
			Art.picture(b,b.icon,Vector2(10,13),Vector2(39,39))
			var name=game.label(b,skill.name,Vector2(56,10),Vector2(node_width()-65,38),16,Color("fff1cf"));name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			var state_text="MAX" if rank==Content.max_rank(skill) else "강화" if ready and rank>0 else "학습" if ready else "배움" if rank>0 else "잠금" if not skill.parents.is_empty() else "대기"
			if Content.job(p):state_text+=" · L%d"%skill.get("level",1)
			game.label(b,"%d/%d %s" % [rank,Content.max_rank(skill),state_text],Vector2(54,42),Vector2(node_width()-57,20),13,Color("95efd4") if rank>0 else Color("ffe4a5"))
			if choice==skill.id:Art.decorate(b,"rare",12).modulate=Color(1,1,1,.35)
			elif not matches(skill,p):b.modulate=Color(.55,.55,.55,.6)
			b.tooltip_text=skill.get("path","")+" · 해금 Lv."+str(skill.get("level",1))+"\n"+skill.name+" · "+("사용 기술" if active else "상시 효과")+"\n"+skill.description;nodes[skill.id]=b
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
	var ready=Content.can_invest(p,skill.id);var maximum=Content.max_rank(skill)
	status.text={"active":"액티브","upgrade":"전직 강화","passive":"특성"}.get(skill.effect,"패시브")+" · %d/%d · "%[rank,maximum]+("완성" if rank==maximum else "투자 가능" if ready else "Lv.%d 필요"%skill.get("level",1) if p.level<skill.get("level",1) else "SP 부족" if Content.available_points(p)==0 else "선행 필요")
	description.text=skill.description.split(" · 강화")[0].split(" · 랭크별")[0].trim_prefix("F · ").trim_prefix("V · ").trim_prefix("C · ")
	description.tooltip_text=skill.description+"\n\n표는 기본값입니다. 치명타·기세·카드 배당·적 약화에 따라 실제 피해는 달라집니다."
	clear(comparison);clear(prerequisites)
	var bonuses=preload("res://scripts/active_skills.gd").bonuses(p)
	var current=Balance.metrics(p,skill,rank,game.session.sim.damage_for(p),p.max_hp) if Content.job(p) else Scaling.metrics(skill,rank,game.session.sim.damage_for(p),p.max_hp,bonuses)
	var upgraded=Balance.metrics(p,skill,mini(maximum,rank+1),game.session.sim.damage_for(p),p.max_hp) if Content.job(p) else Scaling.metrics(skill,mini(maximum,rank+1),game.session.sim.damage_for(p),p.max_hp,bonuses)
	comparison_rows=[]
	game.label(comparison,"효과",Vector2.ZERO,Vector2(166,26),16)
	game.label(comparison,"현재",Vector2(168,0),Vector2(72,26),16)
	game.label(comparison,"다음" if rank<maximum else "최대",Vector2(255,0),Vector2(86,26),16)
	for i in range(current.size()):
		comparison_rows.append([current[i][0],current[i][1],upgraded[i][1]])
		game.label(comparison,current[i][0],Vector2(0,31+i*27),Vector2(166,26),15)
		game.label(comparison,current[i][1],Vector2(168,31+i*27),Vector2(81,26),15)
		game.label(comparison,upgraded[i][1],Vector2(255,31+i*27),Vector2(89,26),15,Color("217d65"))
	if not skill.parents.is_empty():
		game.label(prerequisites,"선행 중 하나 %d랭크 · 눌러서 이동"%skill.get("required_rank",1),Vector2.ZERO,Vector2(343,23),14)
		for i in range(skill.parents.size()):
			var parent=skill.parents[i];var other=Content.SKILLS[p.class_id].filter(func(n):return n.id==parent)[0]
			var b=game.button(prerequisites,("✓ " if p.skill_ranks.get(parent,0)>0 else "")+other.name,Vector2(i*173,28),Vector2(166,38),func():choice=parent;refresh(true);focus_choice());b.add_theme_font_size_override("font_size",14)
	else:game.label(prerequisites,"시작 노드 · 선행 기술 없이 배울 수 있습니다.",Vector2(0,15),Vector2(343,40),15)
	invest.text="최대 레벨 달성" if rank==maximum else ("배우기 · 1 SP" if rank==0 else "Lv.%d → Lv.%d 강화 · 1 SP" % [rank,rank+1]);invest.disabled=not ready
	for i in range(bind_buttons.size()):
		var action=Content.ACTIONS[i];var assigned=Content.active_node(p,action).get("id","")==skill.id
		bind_buttons[i].disabled=skill.effect!="active" or rank<=0 or not game.dungeon.in_town(p.pos);bind_buttons[i].text="QFVCZX"[i]+(" 사용 중" if assigned and rank>0 else " 배치")
