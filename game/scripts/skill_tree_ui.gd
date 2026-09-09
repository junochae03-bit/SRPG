extends Panel
const Content=preload("res://scripts/content.gd")
const Progression=preload("res://scripts/progression.gd")
const Scaling=preload("res://scripts/skill_scaling.gd")
const Balance=preload("res://scripts/job_balance.gd")
const Rules=preload("res://scripts/skill_build.gd")
const Art=preload("res://scripts/ui_art.gd")
const Icons=preload("res://scripts/icon_art.gd")
const Stagger=preload("res://scripts/boss_stagger.gd")
const Library=preload("res://scripts/icon_library.gd")
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
var scroll
var plot
var graph
var search:LineEdit
var filter_index=0
var filters=[]
var status:Label
var prerequisites:Control
var comparison:Control
var comparison_scroll:ScrollContainer
var comparison_rows=[]
var comparison_context=""
var notice:Label
var detail_body:RichTextLabel
var tag_picker:OptionButton
var tag_filter=""
var zoom_label:Label
var path_button:Button
var refund_button:Button
var refund_mode=false
var node_list:Array=[]
var view_controls:Array=[]
var class_panel:Control
var class_detail:Label
var class_portrait:TextureRect
var class_commit:Button
var class_choice=""
var pending_search=0.
var applied_search_text=""
var branch_picker:OptionButton
var filter_picker:OptionButton
var overview_button:Button
var mode_buttons={}
var content_refreshes=0
var search_applications=0
const DETAIL_WIDTH=360

func setup(owner_game):
	game=owner_game;Content.initialize_jobs();position=Vector2(-60,24);size=Vector2(1560,852);mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());Art.decorate(self,"paper",38)
	Library.picture(self,"skills",Vector2(26,18),Vector2(66,66));game.label(self,"별자리의 길",Vector2(109,26),Vector2(418,43),32)
	Library.picture(self,"skill_points",Vector2(555,35),Vector2(29,29));points=game.label(self,"",Vector2(600,30),Vector2(720,38),24);Library.attach(game.button(self,"닫기",Vector2(1400,26),Vector2(125,43),game.toggle_skills),"close",22)
	role_label=game.label(self,"",Vector2(36,88),Vector2(650,38),20)
	for i in range(3):
		var key=["skills","stats","class"][i];mode_buttons[key]=game.button(self,["스킬 지도","능력치","직업"][i],Vector2(974+i*182,87),Vector2(171,43),func():change_mode(key));Library.attach(mode_buttons[key],["skills","stat_points","class_warrior"][i],22)
	search=game.line_edit(self,"",Vector2(31,148),Vector2(300,42));search.placeholder_text="스킬 · 효과 검색";search.clear_button_enabled=true;search.text_changed.connect(func(value):pending_search=.16 if value!=applied_search_text else 0.);search.text_submitted.connect(func(_v):apply_search());view_controls.append(search)
	view_controls.append(Library.picture(self,"search",Vector2(40,159),Vector2(21,21)));search.get_theme_stylebox("normal").content_margin_left=39
	filter_picker=picker(self,Vector2(342,148),Vector2(162,42))
	for caption in ["전체 기술","사용 기술","배울 수 있음"]:filter_picker.add_item(caption)
	filter_picker.item_selected.connect(func(i):filter_index=i;focus_match());view_controls.append(filter_picker)
	branch_picker=picker(self,Vector2(515,148),Vector2(279,42));branch_picker.item_selected.connect(func(i):show_branch(i-1));view_controls.append(branch_picker)
	tag_picker=picker(self,Vector2(805,148),Vector2(265,42));tag_picker.item_selected.connect(func(i):tag_filter=str(tag_picker.get_item_metadata(i));focus_match());view_controls.append(tag_picker)
	view_controls.append(Art.panel(self,Vector2(26,202),Vector2(1054,578),"paper",21))
	graph=preload("res://scripts/skill_graph_view.gd").new();graph.setup(self);graph.position=Vector2(37,214);graph.size=Vector2(1030,510);add_child(graph);scroll=graph;plot=graph;view_controls.append(graph)
	overview_button=game.button(self,"전체 지도",Vector2(46,736),Vector2(122,37),func():show_branch(-1 if graph.scope_cluster>=0 else int(Rules.definition(choice).get("cluster",0))));view_controls.append(overview_button)
	view_controls.append(game.button(self,"선택 찾기",Vector2(179,736),Vector2(122,37),focus_choice))
	view_controls.append(game.button(self,"−",Vector2(899,736),Vector2(41,37),func():graph.zoom_at(graph.size*.5,1./1.2)))
	zoom_label=game.label(self,"",Vector2(945,740),Vector2(65,30),17);zoom_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;view_controls.append(zoom_label)
	view_controls.append(game.button(self,"+",Vector2(1019,736),Vector2(41,37),func():graph.zoom_at(graph.size*.5,1.2)))
	loadout_strip=Control.new();loadout_strip.position=Vector2(31,790);loadout_strip.size=Vector2(1045,44);add_child(loadout_strip)
	notice=game.label(self,"",Vector2(319,731),Vector2(562,44),16);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	reset_button=game.button(self,"스킬 초기화",Vector2(706,88),Vector2(237,43),func():game.session.act("reset_skills" if mode=="skills" else "reset_stats");refresh(true))
	details=Art.panel(self,Vector2(1096,146),Vector2(432,688),"paper",25)
	Art.picture(details,Art.texture("medallion"),Vector2(17,19),Vector2(91,91));selected_icon=Art.picture(details,null,Vector2(30,32),Vector2(65,65))
	selected=game.label(details,"",Vector2(119,26),Vector2(287,72),26);selected.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status=game.label(details,"",Vector2(25,113),Vector2(382,54),18);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description=game.label(details,"",Vector2(25,169),Vector2(382,43),18);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	invest=game.button(details,"",Vector2(23,217),Vector2(386,49),invest_selected,true)
	comparison_scroll=ScrollContainer.new();comparison_scroll.position=Vector2(25,282);comparison_scroll.size=Vector2(382,239);comparison_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;details.add_child(comparison_scroll)
	comparison=Control.new();comparison.custom_minimum_size=Vector2(DETAIL_WIDTH,239);comparison_scroll.add_child(comparison)
	detail_body=RichTextLabel.new();detail_body.size=Vector2(DETAIL_WIDTH,239);detail_body.fit_content=true;detail_body.scroll_active=false;detail_body.bbcode_enabled=true;detail_body.add_theme_font_override("normal_font",game.fonts);detail_body.add_theme_font_override("bold_font",game.bold_font);detail_body.add_theme_font_size_override("normal_font_size",18);detail_body.add_theme_font_size_override("bold_font_size",20);detail_body.add_theme_color_override("default_color",game.PALE);detail_body.add_theme_constant_override("line_separation",5);comparison.add_child(detail_body)
	prerequisites=Control.new();prerequisites.position=Vector2(24,535);prerequisites.size=Vector2(386,40);details.add_child(prerequisites)
	path_button=game.button(details,"경로 보기",Vector2(23,583),Vector2(184,36),show_path)
	refund_button=game.button(details,"선택 회수",Vector2(216,583),Vector2(193,36),preview_refund)
	for i in range(6):
		var action=Content.ACTIONS[i];var b=game.button(details,key_label(action)+" 배치",Vector2(23+(i%3)*130,628+int(i/3)*29),Vector2(126,27),func():game.session.act("bind_skill",action+":"+choice);refresh(true));b.add_theme_font_size_override("font_size",15);bind_buttons.append(b)
	stats_panel=Art.panel(self,Vector2(29,149),Vector2(1054,685),"paper",24);stats_text=game.label(stats_panel,"",Vector2(54,48),Vector2(966,74),25)
	var index=0
	for key in Progression.NAMES:
		Library.picture(stats_panel,"intelligence" if key=="magic" else key,Vector2(31,143+index*92),Vector2(28,28));game.label(stats_panel,Progression.NAMES[key],Vector2(74,140+index*92),Vector2(70,34),25)
		game.label(stats_panel,Progression.HELP[key],Vector2(150,142+index*92),Vector2(575,60),18).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		stat_buttons[key]=game.button(stats_panel,"+1",Vector2(846,135+index*92),Vector2(155,48),func():game.session.act("stat",key);refresh(true));Library.attach(stat_buttons[key],"stat_points",22);index+=1
	class_panel=Art.panel(self,Vector2(29,149),Vector2(1054,685),"paper",24);game.label(class_panel,"새로운 전투 방식",Vector2(54,48),Vector2(760,45),29)
	class_picker=picker(class_panel,Vector2(54,112),Vector2(397,47))
	for key in Content.CLASSES:class_picker.add_item(Content.CLASSES[key].name);class_picker.set_item_metadata(class_picker.item_count-1,key)
	class_picker.item_selected.connect(func(i):class_choice=str(class_picker.get_item_metadata(i));refresh_class())
	Art.picture(class_panel,Art.texture("alcove"),Vector2(36,173),Vector2(257,375));class_portrait=Art.picture(class_panel,null,Vector2(73,231),Vector2(178,284));class_portrait.material=preload("res://scripts/gat_art.gd").material()
	class_detail=game.label(class_panel,"",Vector2(332,190),Vector2(673,334),22);class_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	class_commit=game.button(class_panel,"직업 선택",Vector2(333,558),Vector2(668,54),func():
		if game.session.act("class",class_choice):choice="";search.text="";tag_filter="";change_mode("skills"))
	hide()

func key_label(action:String)->String:
	return game.keybindings.label(action) if game.get("keybindings")!=null else preload("res://scripts/key_bindings.gd").key_name(preload("res://scripts/key_bindings.gd").DEFAULTS[action])

func refresh_key_labels():
	signature=""
	if visible:refresh(true)

func fit_bind_label(button:Button):
	var pixels=15;var available=button.size.x-20;var font=button.get_theme_font("font")
	while pixels>11 and font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>available:pixels-=1
	button.add_theme_font_size_override("font_size",pixels);button.tooltip_text=button.text

func picker(parent:Node,at:Vector2,dimensions:Vector2)->OptionButton:
	var p=OptionButton.new();p.position=at;p.size=dimensions;p.fit_to_longest_item=false;p.clip_text=true;p.add_theme_font_override("font",game.fonts);p.add_theme_font_size_override("font_size",16);p.add_theme_color_override("font_color",game.PALE)
	for key in ["normal","hover","pressed","focus"]:
		var style=StyleBoxEmpty.new();style.content_margin_left=16;style.content_margin_right=23;p.add_theme_stylebox_override(key,style)
	p.get_popup().add_theme_stylebox_override("panel",game.style(Color.WHITE));p.get_popup().add_theme_font_override("font",game.fonts);p.get_popup().add_theme_color_override("font_color",game.PALE);parent.add_child(p);Art.decorate(p,"paper",11);return p
func player()->Dictionary:return game.session.state.players.get(game.session.local_id,{})
func _process(delta):
	if not visible:return
	if pending_search>0:
		pending_search-=delta
		if pending_search<=0:apply_search()
		return
	refresh()
func change_mode(next:String):mode=next;comparison_context="";notice.text="";refund_mode=false;refresh(true)
func node_width()->float:return 79.
func node_position(node:Dictionary)->Vector2:return graph.positions.get(node.id,Vector2.ZERO)
func matches(node:Dictionary,p:Dictionary)->bool:
	var query=search.text.strip_edges().to_lower();var definition=graph.definitions.get(node.id,node)
	var text=str(definition.get("name",""))+" "+str(definition.get("description",""))+" "+str(definition.get("tags",[]))+" "+str(definition.get("synergy",""))
	return (query.is_empty() or text.to_lower().contains(query)) and (tag_filter.is_empty() or tag_filter in definition.get("tags",[])) and (filter_index==0 or filter_index==1 and definition.get("effect","")=="active" or filter_index==2 and Rules.node_state(p,node.id).get("can_invest",false))
func select_node(id:String):choice=id;refund_mode=false;graph.planned_ids=[];graph.scope_extra.clear();notice.text="";refresh(true)
func show_branch(cluster:int):
	graph.set_scope(cluster);refund_mode=false
	if cluster>=0:
		var candidates=node_list.filter(func(n):return int(n.get("cluster",0))==cluster)
		if not candidates.any(func(n):return n.id==choice) and not candidates.is_empty():choice=candidates[0].id
	refresh(true);graph.fit_scope()
func refresh_branch_picker():
	if branch_picker==null:return
	branch_picker.clear();branch_picker.add_item("전체 지도 · %d개"%node_list.size())
	for i in range(5):branch_picker.add_item(str(graph.cluster_names.get(i,"가지 "+str(i+1)))+" · %d개"%node_list.filter(func(n):return int(n.get("cluster",0))==i).size())
	branch_picker.select(graph.scope_cluster+1);overview_button.text="전체 지도" if graph.scope_cluster>=0 else "가지 보기"
func focus_choice():graph.focus_node(choice)
func focus_match():
	apply_search()
func apply_search():
	pending_search=0;applied_search_text=search.text;search_applications+=1
	var p=player();var found=""
	if p.is_empty():return
	for node in Rules.nodes_for(p.class_id):
		if matches(node,p):found=node.id;break
	if not found.is_empty():
		choice=found;refund_mode=false;graph.planned_ids=[];graph.scope_extra.clear();notice.text=""
	else:notice.text="조건에 맞는 기술이 없습니다."
	# Select before rebuilding so a burst of typing updates content only once.
	refresh(true)
	if not found.is_empty():focus_choice()
func clear(control:Node):
	for child in control.get_children():control.remove_child(child);child.queue_free()
func invest_selected():
	if game.session.act("uninvest" if refund_mode else "invest",choice):notice.text=selected.text+(" · 선택 회수" if refund_mode else " · 성장 적용")
	else:notice.text=str(Rules.node_state(player(),choice).get("reason","현재 적용할 수 없습니다."))
	refund_mode=false;refresh(true)
func preview_refund():
	refund_mode=true;refresh(true);comparison_scroll.scroll_vertical=0
func show_path():
	var plan=Rules.path_plan(player(),choice);graph.planned_ids=[]
	for step in plan.get("steps",[]):graph.planned_ids.append(str(step.id))
	notice.text="필요 %d SP · %d개 경로"%[int(plan.get("cost",0)),plan.get("steps",[]).size()] if plan.get("ok",false) else str(plan.get("reason","경로가 잠겨 있습니다."));graph.reveal_plan()

func refresh(force=false):
	var p=player()
	if p.is_empty():return
	var next=JSON.stringify([p.class_id,p.skill_ranks,p.get("constellation_allocations",{}),p.level,p.stats,p.skill_loadout,p.equipment,p.inventory,game.dungeon.in_town(p.pos),choice,mode,search.text,filter_index,tag_filter,refund_mode])
	if next==signature and not force:return
	content_refreshes+=1;signature=next;Content.initialize_jobs();node_list=Rules.nodes_for(p.class_id)
	points.text="LV.%d · 스킬 %d SP · 능력치 %d"%[p.level,Rules.available_points(p),Progression.available(p)]
	role_label.text=Content.CLASSES[p.class_id].name+" · "+Balance.role(p.class_id)[0];role_label.tooltip_text=Balance.role(p.class_id)[1]
	for control in view_controls:control.visible=mode=="skills"
	stats_panel.visible=mode=="stats";class_panel.visible=mode=="class";loadout_strip.visible=mode=="skills";reset_button.visible=mode!="class"
	filter_picker.select(filter_index)
	if tag_picker.get_meta("class","")!=p.class_id:
		tag_picker.clear();tag_picker.add_item("모든 성격");tag_picker.set_item_metadata(0,"");var tags=[]
		for node in node_list:
			for tag in node.get("tags",[]):
				if not tags.has(tag):tags.append(tag)
		tags.sort()
		for tag in tags:tag_picker.add_item(localized_tag(str(tag)));tag_picker.set_item_metadata(tag_picker.item_count-1,tag)
		tag_picker.set_meta("class",p.class_id)
	if not node_list.any(func(n):return n.id==choice):choice=node_list[0].id
	graph.rebuild(node_list,p);nodes=graph.node_controls;refresh_branch_picker()
	var context=p.class_id+":"+choice+":"+mode
	if context!=comparison_context:comparison_context=context;comparison_scroll.scroll_vertical=0
	show_details(node_list.filter(func(n):return n.id==choice)[0],p)
	clear(loadout_strip)
	for i in range(6):
		var equipped=Content.active_node(p,Content.ACTIONS[i]);var trained=Content.action_rank(p,Content.ACTIONS[i])>0
		var b=game.button(loadout_strip,"",Vector2(i*175,0),Vector2(166,43),func():
			if trained:select_node(equipped.id);focus_choice())
		if trained:Art.picture(b,Icons.skill(equipped),Vector2(7,7),Vector2(30,30))
		var caption=game.label(b,key_label(Content.ACTIONS[i])+" · "+(equipped.get("name","") if trained else "미장착"),Vector2(42,5),Vector2(118,35),14)
		caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;caption.tooltip_text=caption.text;caption.clip_text=true
		b.tooltip_text=equipped.get("name","") if trained else "배운 사용 기술을 선택해 배치할 수 있습니다."
	reset_button.disabled=game.dungeon.zone!="town";reset_button.text="스킬 초기화" if mode=="skills" else "능력치 초기화";reset_button.tooltip_text="마을에서 사용할 수 있습니다." if reset_button.disabled else "현재 배분을 되돌립니다."
	if mode=="stats":show_stats(p)
	elif mode=="class":refresh_class()
	for b in bind_buttons:b.visible=mode=="skills"
	invest.visible=mode=="skills";path_button.visible=mode=="skills";refund_button.visible=mode=="skills"
	comparison_scroll.position.y=282 if mode=="skills" else 226;comparison_scroll.size.y=239 if mode=="skills" else 295
	selected_icon.material=Art.icon_material(selected_icon.texture)
	Library.attach(mode_buttons["class"],"class_"+p.class_id,22)
	Library.attach(reset_button,"reset",21);Library.attach(invest,"stat_points" if mode=="stats" else "reset" if refund_mode else "success" if invest.text=="최대 성장" else "locked" if invest.disabled else "skill_points",22)
	Library.attach(path_button,"skills",18);Library.attach(refund_button,"reset",18)

func paragraph(title:String,body:String)->String:return "[b]"+title+"[/b]\n"+body+"\n\n" if not body.is_empty() else ""
func localized_tag(tag:String)->String:
	return {"original":"원기술","active":"사용 기술","passive":"지속 효과","upgrade":"기술 강화","minor":"기반","notable":"주요 특성","keystone":"핵심 선택","constellation":"별자리 특화"}.get(tag,Scaling.EFFECT_NAMES.get(tag,Rules.effect_label(tag)))
func show_details(skill:Dictionary,p:Dictionary):
	var state=Rules.node_state(p,skill.id);var rank=int(state.get("rank",0));var maximum=int(skill.max_rank)
	selected.text=str(skill.name).get_slice(" · ",0) if skill.get("type","")=="minor" else str(skill.name);selected.tooltip_text=skill.name;selected_icon.texture=Icons.skill(skill)
	description.text="LV.%d · "%int(skill.get("level",1))+("선행 없음" if skill.get("parents",[]).is_empty() else ("모든 선행" if skill.get("parent_mode","any")=="all" else "선행 중 하나")+" %d랭크"%int(skill.get("required_rank",1)));description.tooltip_text=description.text
	status.text=("핵심 선택" if skill.get("type","")=="keystone" else "주요 특성" if skill.get("type","")=="notable" else "기반" if skill.get("type","")=="minor" else "사용 기술" if skill.effect=="active" else "원기술 강화")+" · %d/%d · %d SP"%[rank,maximum,int(state.get("cost",skill.get("cost",1)))]
	if not state.get("can_invest",false) and rank<maximum and not str(state.get("reason","")).begins_with("선행"):status.text+="\n"+str(state.get("reason","선행 필요"))
	comparison_rows=[];var text=""
	if skill.get("type","original")!="original":
		var effect_text=str(skill.get("effects_text",skill.get("description","")))
		text+=paragraph("얻는 변화",effect_text)+paragraph("선택의 대가",str(skill.get("tradeoff","")))+paragraph("함께 쓰는 방식",str(skill.get("synergy","")))
		text+=paragraph("적용 범위",str(skill.get("description","")).trim_prefix(effect_text).trim_prefix(". "))
		var preview=Rules.preview(p,skill.id,mini(maximum,rank+1));var before:Dictionary=preview.get("before",{});var after:Dictionary=preview.get("after",{})
		for effect in skill.get("effects",{}):comparison_rows.append([effect,str(before.get(effect,0)),str(after.get(effect,before.get(effect,0)))])
		if str(state.get("reason","")).begins_with("배타"):
			var names=[]
			for id in state.locked_by:
				var row=node_list.filter(func(n):return n.id==id)
				if not row.is_empty():names.append(str(row[0].name))
			text+=paragraph("현재 선택과 충돌"," / ".join(names))
		if skill.get("type","")=="keystone":
			text+=paragraph("핵심 선택 한도","동시에 두 개까지 선택합니다. 배타 관계의 선택은 함께 배울 수 없습니다.")
			var excluded=PackedStringArray()
			for other in node_list:
				if other.id!=skill.id and (not str(skill.get("exclusive_group","")).is_empty() and skill.exclusive_group==other.get("exclusive_group","") or other.id in skill.get("exclusive_with",[])):excluded.append(str(other.name))
			text+=paragraph("함께 선택할 수 없는 길"," / ".join(excluded))
	else:
		# Allocation cost is 1 SP on decorated nodes; combat cost must stay original.
		var combat_skill:Dictionary=skill.get("icon_node",skill)
		var bonuses=preload("res://scripts/active_skills.gd").bonuses(p)
		var current=Balance.metrics(p,combat_skill,rank,game.session.sim.damage_for(p),p.max_hp) if Content.job(p) else Scaling.metrics(combat_skill,rank,game.session.sim.damage_for(p),p.max_hp,bonuses)
		var upgraded=Balance.metrics(p,combat_skill,mini(maximum,rank+1),game.session.sim.damage_for(p),p.max_hp) if Content.job(p) else Scaling.metrics(combat_skill,mini(maximum,rank+1),game.session.sim.damage_for(p),p.max_hp,bonuses)
		if skill.effect=="active":current.append(["시전당 무력화","%.1f"%Stagger.skill_profile(combat_skill,rank,p).value]);upgraded.append(["시전당 무력화","%.1f"%Stagger.skill_profile(combat_skill,mini(maximum,rank+1),p).value])
		var rows=PackedStringArray()
		for i in range(current.size()):comparison_rows.append([current[i][0],current[i][1],upgraded[i][1]]);rows.append("%s\n%s  →  %s"%[current[i][0],current[i][1],upgraded[i][1]])
		text+=paragraph("현재 → 다음" if rank<maximum else "최대 성장 효과","\n".join(rows))+paragraph("기술 효과",str(skill.get("description","")))+paragraph("함께 쓰는 방식",str(skill.get("synergy","")))+paragraph("비교 기준","현재 장비와 능력치를 적용합니다. 직업 자원·치명타·적 상태에 따라 실제 결과가 달라집니다.")
	var tags=PackedStringArray()
	for tag in skill.get("tags",[]):tags.append(localized_tag(str(tag)))
	text+=paragraph("성격"," · ".join(tags));clear(prerequisites)
	for i in range(mini(2,skill.get("parents",[]).size())):
		var id=skill.parents[i];var row=node_list.filter(func(n):return n.id==id)
		if row.is_empty():continue
		var b=game.button(prerequisites,str(row[0].name).get_slice(" · ",0),Vector2(i*197,0),Vector2(189,38),func():select_node(id);focus_choice());b.add_theme_font_size_override("font_size",14);b.tooltip_text="선행 "+str(skill.get("required_rank",1))+"랭크 · "+row[0].name
	invest.disabled=not state.get("can_invest",false);invest.text="최대 성장" if rank>=maximum else ("배우기" if rank==0 else "강화")+" · %d SP"%int(state.get("cost",skill.get("cost",1)));invest.tooltip_text=str(state.get("reason",""));path_button.disabled=rank>=maximum
	refund_button.disabled=rank<=0 or game.dungeon.zone!="town"
	if refund_mode:
		var preview=Rules.preview(p,skill.id,maxi(0,rank-1));var names=PackedStringArray()
		for id in preview.get("removed",[]):names.append(str(Rules.definition(str(id)).get("name",id)))
		text=paragraph("회수 미리보기","%d SP 반환\n함께 해제: %s"%[int(preview.get("refund",0))," / ".join(names)])+text;invest.text="회수 적용";invest.disabled=not preview.get("ok",false) or game.dungeon.zone!="town"
	detail_body.text=text;detail_body.size.x=DETAIL_WIDTH;comparison.custom_minimum_size.y=maxf(239,detail_body.get_content_height()+12)
	for i in range(bind_buttons.size()):
		var action=Content.ACTIONS[i];var assigned=Content.active_node(p,action).get("id","")==skill.id
		bind_buttons[i].disabled=skill.effect!="active" or rank<=0 or not game.dungeon.in_town(p.pos);bind_buttons[i].text=key_label(Content.ACTIONS[i])+(" 사용 중" if assigned and rank>0 else " 배치");fit_bind_label(bind_buttons[i])

func show_stats(p:Dictionary):
	stats_text.text="사용 가능한 능력치 %d\n힘 %d · 내구 %d · 기술 %d · 민첩 %d · 마력 %d"%[Progression.available(p),Progression.bonus(p,"strength"),Progression.bonus(p,"endurance"),Progression.bonus(p,"technique"),Progression.bonus(p,"agility"),Progression.bonus(p,"magic")]
	for key in stat_buttons:stat_buttons[key].disabled=Progression.available(p)<=0
	selected.text="모험가의 성장";selected_icon.texture=Library.texture("stat_points");status.text="레벨마다 능력치 +3 / 스킬 +1";description.text="배분한 능력치와 개방된 장비 옵션을 합산합니다."
	var rows=[["물리 / 마법 공격","%d / %d"%[game.session.sim.damage_for(p,"physical"),game.session.sim.damage_for(p,"magic")]],["물리 / 마법 방어","%d / %d"%[p.defense,p.magic_defense]],["받는 피해 감소","%.1f%%"%(Progression.mitigation(p)*100)],["스킬 재사용 감소","%.1f%%"%((1-Progression.cooldown_factor(p))*100)],["스킬 무력화 피해","+%.1f%%"%((Stagger.skill_profile({},1,p).multiplier-1)*100)],["공격 / 이동 속도","+%.1f%% / +%.1f%%"%[(Progression.attack_speed(p)-1)*100,(Progression.move_speed(p)-1)*100]],["최대 생명력",str(p.max_hp)]]
	var parts=PackedStringArray()
	for row in rows:parts.append("%s  [b]%s[/b]"%[row[0],row[1]])
	detail_body.text="\n".join(parts);detail_body.size.x=DETAIL_WIDTH;comparison.custom_minimum_size.y=maxf(239,detail_body.get_content_height()+12);clear(prerequisites);invest.text="능력치 배분";invest.disabled=true

func refresh_class():
	var p=player()
	if p.is_empty():return
	if class_choice.is_empty():class_choice=p.class_id
	class_picker.select(Content.CLASSES.keys().find(class_choice))
	var c=Content.CLASSES[class_choice];var allowed=game.dungeon.zone=="town" and class_choice!=p.class_id;var reason=""
	if game.dungeon.zone!="town":reason="마을에서 직업을 바꿀 수 있습니다."
	elif class_choice==p.class_id:reason="현재 직업입니다."
	elif c.has("base") and not c.get("starter",false) and (p.level<30 or Content.base_class(p.class_id)!=c.base):reason="같은 1차 계열 · LV.30 이상 필요";allowed=false
	class_commit.disabled=not allowed;class_commit.text="이 직업으로 전직" if allowed else reason
	var identity={"warrior":"가까운 거리에서 베기와 방어로 전투의 흐름을 잡습니다.","ranger":"거리와 위치를 유지하며 원거리 표적을 관통합니다.","mage":"시전 시간을 확보해 넓은 범위에 마법을 집중합니다."}.get(class_choice,Balance.role(class_choice)[1])
	class_detail.text=c.name+"\n\n"+identity+"\n\n전용 무기와 같은 계열의 방어구를 사용합니다. 전직 시 사용할 수 없는 장비는 가방으로 이동합니다.\n\n전직하면 기존 스킬과 별자리 배분을 되돌립니다."
	var actor=p.duplicate(true);actor.class_id=class_choice;actor.costume="none";actor.avatar="auto"
	class_portrait.texture=preload("res://scripts/job_art.gd").frame(actor,0.).texture if preload("res://scripts/job_art.gd").has_sprite(actor) else preload("res://scripts/gat_art.gd").texture(preload("res://scripts/gat_art.gd").avatar(actor),0)
	if mode=="class":selected.text="직업의 정체성";selected_icon.texture=Library.texture("class_"+class_choice);selected_icon.material=Art.icon_material(selected_icon.texture);status.text=c.name;description.text=Balance.role(class_choice)[0];detail_body.text=paragraph("직업 특색",identity)+paragraph("전직 조건",reason if not reason.is_empty() else "전직할 수 있습니다.");detail_body.size.x=DETAIL_WIDTH;comparison.custom_minimum_size.y=maxf(239,detail_body.get_content_height()+12);clear(prerequisites)
