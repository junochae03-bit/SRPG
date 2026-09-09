extends Panel
## Read-only journal over the same catalogues used by combat, loot and equipment.
const DB=preload("res://scripts/game_database.gd")
const Content=preload("res://scripts/content.gd")
const Equipment=preload("res://scripts/equipment_catalog.gd")
const Art=preload("res://scripts/ui_art.gd")
const Icons=preload("res://scripts/icon_art.gd")
const PAGE_SIZE=8
const TABS=["equipment","monsters","drops","skills"]
const TAB_NAMES=["장비 도감","몬스터 도감","드랍 정보","스킬 DB"]
const ROLE_NAMES={"normal":"일반 몬스터","elite":"엘리트","boss":"보스 기본형","raid":"던전 레이드"}
var game
var selected_tab="equipment"
var selected_id=""
var filters:Dictionary={}
var page=0
var result:Dictionary={}
var row_buttons:Dictionary={}
var tab_buttons:Array=[]
var search:LineEdit
var filter_a:OptionButton
var filter_b:OptionButton
var filter_c:OptionButton
var count_label:Label
var page_label:Label
var previous_button:Button
var next_button:Button
var reset_button:Button
var list:Control
var detail_name:Label
var detail_subtitle:Label
var detail_icon:TextureRect
var detail_crest:TextureRect
var detail_scroll:ScrollContainer
var detail_body:RichTextLabel
var link_button:Button
var source_note:Label
var reference_picker:OptionButton
var rank_picker:OptionButton
var rank_index=0
var use_player_stats=false
var pending_search=0.0
var refreshing_filters=false
var link_target:Dictionary={}

func setup(owner_game):
	game=owner_game;position=Vector2(24,24);size=Vector2(1392,852);mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",StyleBoxEmpty.new());Art.decorate(self,"paper",38)
	Art.picture(self,Icons.function_icon("growth"),Vector2(30,16),Vector2(73,73))
	game.label(self,"모험 도감",Vector2(118,20),Vector2(700,42),32)
	game.label(self,"장비부터 100층 보스까지 · 모험에 필요한 기록",Vector2(120,65),Vector2(1034,27),17)
	game.button(self,"닫기  B",Vector2(1210,27),Vector2(148,44),close)
	for i in range(TABS.size()):
		var key=TABS[i]
		var b=game.button(self,TAB_NAMES[i],Vector2(27+i*336,109),Vector2(326,47),func():switch_tab(key))
		tab_buttons.append(b)
	search=game.line_edit(self,"",Vector2(27,176),Vector2(650,45));search.placeholder_text="이름·설명으로 찾기";search.clear_button_enabled=true
	search.text_changed.connect(func(_value):pending_search=.22)
	search.text_submitted.connect(func(_value):apply_search())
	reset_button=game.button(self,"조건 초기화",Vector2(692,176),Vector2(141,45),reset_filters)
	filter_a=picker(self,Vector2(28,231),Vector2(286,39))
	filter_b=picker(self,Vector2(326,231),Vector2(214,39))
	filter_c=picker(self,Vector2(553,231),Vector2(280,39))
	count_label=game.label(self,"",Vector2(43,280),Vector2(780,28),17);count_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	list=Control.new();list.position=Vector2(25,314);list.size=Vector2(813,468);add_child(list)
	previous_button=game.button(self,"← 이전",Vector2(30,791),Vector2(123,38),func():change_page(-1))
	page_label=game.label(self,"",Vector2(165,796),Vector2(510,28),17);page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	next_button=game.button(self,"다음 →",Vector2(694,791),Vector2(137,38),func():change_page(1))
	var detail=Art.panel(self,Vector2(853,171),Vector2(509,612),"paper",25)
	detail_crest=Art.picture(detail,Art.texture("medallion"),Vector2(20,19),Vector2(136,140))
	detail_icon=Art.picture(detail,null,Vector2(37,35),Vector2(101,107))
	detail_name=game.label(detail,"",Vector2(170,32),Vector2(306,87),26);detail_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_subtitle=game.label(detail,"",Vector2(171,124),Vector2(303,47),16);detail_subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	rank_picker=picker(detail,Vector2(27,181),Vector2(139,36));rank_picker.item_selected.connect(func(index):rank_index=index;refresh_detail())
	reference_picker=picker(detail,Vector2(177,181),Vector2(300,36));reference_picker.add_item("무력화 · 기술 0 기준");reference_picker.add_item("무력화 · 내 기술 적용")
	reference_picker.item_selected.connect(func(index):use_player_stats=index==1;refresh_detail())
	detail_scroll=ScrollContainer.new();detail_scroll.position=Vector2(29,231);detail_scroll.size=Vector2(452,288);detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail.add_child(detail_scroll)
	detail_body=RichTextLabel.new();detail_body.custom_minimum_size=Vector2(430,284);detail_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_body.fit_content=true;detail_body.scroll_active=false;detail_body.bbcode_enabled=true
	detail_body.add_theme_font_override("normal_font",game.fonts);detail_body.add_theme_font_override("bold_font",game.bold_font);detail_body.add_theme_font_size_override("normal_font_size",18);detail_body.add_theme_font_size_override("bold_font_size",19);detail_body.add_theme_color_override("default_color",game.PALE);detail_body.add_theme_constant_override("line_separation",5)
	detail_scroll.add_child(detail_body)
	link_button=game.button(detail,"",Vector2(28,533),Vector2(452,46),follow_link,true)
	source_note=game.label(self,"상세 기록은 마우스 휠로 더 읽을 수 있습니다.\n열람은 소지품·성장 포인트에 영향을 주지 않습니다.",Vector2(868,791),Vector2(484,42),14);source_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hide()

func picker(parent:Node,at:Vector2,dimensions:Vector2)->OptionButton:
	var p=OptionButton.new();p.position=at;p.size=dimensions;p.fit_to_longest_item=false;p.clip_text=true
	p.add_theme_font_override("font",game.fonts);p.add_theme_font_size_override("font_size",16);p.add_theme_color_override("font_color",game.PALE)
	for state in ["normal","hover","pressed","focus"]:
		var style=StyleBoxEmpty.new();style.content_margin_left=17;style.content_margin_right=22;p.add_theme_stylebox_override(state,style)
	p.get_popup().add_theme_stylebox_override("panel",game.style(Color.WHITE));p.get_popup().add_theme_font_override("font",game.fonts);p.get_popup().add_theme_font_size_override("font_size",17);p.get_popup().add_theme_color_override("font_color",game.PALE)
	parent.add_child(p);Art.decorate(p,"paper",10);return p

func player()->Dictionary:
	return game.session.state.players.get(game.session.local_id,{})

func open(tab:String="",initial_filters:Dictionary={}):
	if tab in TABS:selected_tab=tab
	filters=initial_filters.duplicate(true);page=0;selected_id="";rank_index=0;pending_search=0;detail_scroll.scroll_vertical=0;search.text=str(filters.get("q",""));configure_filters();show();refresh()

func close():
	search.release_focus();pending_search=0;hide()
	game.session.paused=game.bag.visible or game.skill_tree.visible or game.help_panel.visible or game.town_panel.visible

func switch_tab(tab:String):
	if tab not in TABS:return
	selected_tab=tab;filters={};page=0;selected_id="";rank_index=0;detail_scroll.scroll_vertical=0;search.text="";pending_search=0;configure_filters();refresh()

func reset_filters():
	filters={};page=0;selected_id="";search.text="";pending_search=0;configure_filters();refresh()

func set_filter(key:String,value):
	if value is String and value.is_empty() or value is int and (value==-1 or key=="floor" and value==0):filters.erase(key)
	else:filters[key]=value
	page=0;selected_id="";detail_scroll.scroll_vertical=0;refresh()

func fill_picker(p:OptionButton,key:String,entries:Array):
	for connection in p.item_selected.get_connections():p.item_selected.disconnect(connection.callable)
	p.clear()
	for entry in entries:
		p.add_item(str(entry[0]));p.set_item_metadata(p.item_count-1,entry[1])
		if filters.get(key,entries[0][1])==entry[1]:p.select(p.item_count-1)
	p.item_selected.connect(func(index):
		if not refreshing_filters:set_filter(key,p.get_item_metadata(index)))

func configure_filters():
	refreshing_filters=true
	Content.initialize_jobs()
	var classes:Array=[["모든 직업",""]]
	for id in Content.CLASSES:classes.append([Content.CLASSES[id].name,id])
	var grades:Array=[["모든 등급",-1]]
	for i in range(Equipment.GRADES.size()):grades.append([Equipment.GRADES[i],i])
	var slots:Array=[["모든 장비 부위",""]]
	for id in Content.SLOTS:slots.append([Content.SLOT_NAMES[id],id])
	var floors:Array=[["전체 층",0]]
	for f in range(1,101):floors.append(["%d층"%f,f])
	filter_c.show()
	match selected_tab:
		"equipment":fill_picker(filter_a,"class_id",classes);fill_picker(filter_b,"rarity",grades);fill_picker(filter_c,"slot",slots)
		"monsters":
			fill_picker(filter_a,"role",[["모든 몬스터",""] ,["일반 몬스터","normal"],["엘리트","elite"],["보스 기본형","boss"],["던전 레이드","raid"]]);fill_picker(filter_b,"floor",floors);filter_c.hide()
		"drops":fill_picker(filter_a,"floor",floors);fill_picker(filter_b,"rarity",grades);fill_picker(filter_c,"slot",slots)
		"skills":fill_picker(filter_a,"class_id",classes);fill_picker(filter_b,"effect",[["모든 스킬",""] ,["사용 스킬","active"],["지속 효과","passive"],["강화 노드","upgrade"]]);filter_c.hide()
	refreshing_filters=false

func _process(delta:float):
	if not visible or pending_search<=0:return
	pending_search-=delta
	if pending_search<=0:apply_search()

func apply_search():
	pending_search=0;var q=search.text.strip_edges()
	if q.is_empty():filters.erase("q")
	else:filters.q=q
	page=0;selected_id="";refresh()

func change_page(direction:int):
	page=clampi(page+direction,0,maxi(0,int(result.get("pages",1))-1));selected_id="";refresh()

func select_record(id:String):
	selected_id=id;rank_index=0;detail_scroll.scroll_vertical=0;refresh_cards();refresh_detail()

func refresh():
	result=DB.query(selected_tab,filters,page,PAGE_SIZE);page=int(result.page)
	if selected_id.is_empty():
		detail_scroll.scroll_vertical=0;rank_index=0
		if not result.items.is_empty():selected_id=str(result.items[0].id)
	for i in range(tab_buttons.size()):
		tab_buttons[i].text=("◆ " if TABS[i]==selected_tab else "")+TAB_NAMES[i]
	count_label.text="%s  ·  %s개 기록"%[TAB_NAMES[TABS.find(selected_tab)],int(result.total)]
	if filters.has("monster_id"):
		var source=DB.detail("monsters",str(filters.monster_id));count_label.text=str(source.get("name","선택한 몬스터"))+"의 전리품  ·  %s개 기록"%int(result.total)
	elif filters.has("equipment_id"):
		var source=DB.detail("equipment",str(filters.equipment_id));count_label.text=str(source.get("name","선택한 장비"))+" 획득처  ·  %s개 기록"%int(result.total)
	page_label.text="%d / %d 페이지  ·  %d–%d"%[page+1,maxi(1,int(result.pages)),page*PAGE_SIZE+1 if int(result.total)>0 else 0,mini((page+1)*PAGE_SIZE,int(result.total))]
	previous_button.disabled=page<=0;next_button.disabled=page+1>=int(result.pages)
	refresh_cards();refresh_detail()

func refresh_cards():
	for child in list.get_children():list.remove_child(child);child.queue_free()
	row_buttons.clear()
	if result.get("items",[]).is_empty():
		Art.picture(list,Art.texture("scroll"),Vector2(283,54),Vector2(235,216))
		var empty=game.label(list,"일치하는 기록이 없습니다.\n검색어나 필터를 바꾸어 보세요.",Vector2(73,301),Vector2(660,77),22);empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;return
	for i in range(result.items.size()):
		var row=result.items[i];var id=str(row.id);var selected=id==selected_id
		var b=game.button(list,"",Vector2(i%2*409,int(i/2)*117),Vector2(402,109),func():select_record(id),selected);row_buttons[id]=b
		Art.picture(b,Art.texture("equipped" if selected else "socket"),Vector2(12,15),Vector2(70,70))
		var icon=Art.picture(b,DB.asset_texture(row),Vector2(22,24),Vector2(50,55))
		if selected_tab=="monsters":icon.material=preload("res://scripts/gat_art.gd").material()
		if selected_tab=="equipment":
			var edge=Line2D.new();edge.points=PackedVector2Array([Vector2(21,23),Vector2(74,23),Vector2(74,79),Vector2(21,79),Vector2(21,23)]);edge.width=2;edge.default_color=Equipment.COLORS[clampi(int(row.get("rarity",0)),0,4)];edge.z_index=2;b.add_child(edge)
		var title=game.label(b,str(row.get("name","")),Vector2(97,15),Vector2(285,51),19);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var caption=game.label(b,row_caption(row),Vector2(98,72),Vector2(284,25),15);caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;b.tooltip_text=str(row.get("name",""))+"\n"+row_caption(row)

func row_caption(row:Dictionary)->String:
	match selected_tab:
		"equipment":return "%s · %s · LV.%d"%[row.get("grade_name",""),row.get("slot_name",""),int(row.get("required_level",1))]
		"monsters":return "%s · %s"%[ROLE_NAMES.get(row.get("role","normal"),"몬스터"),"%d층"%int(row.floor) if row.has("floor") else "%d개 층 출현"%row.get("floors",[]).size()]
		"drops":
			var source_name=str(row.get("monster_name",row.get("subtitle","")))
			if str(filters.get("monster_id","")).begins_with("raid:"):source_name=str(DB.detail("monsters",str(filters.monster_id)).get("name",source_name))
			return "%s · %s"%[probability(row),source_name]
		"skills":return "%s · %s"%[row.get("class_name",""),"사용" if row.get("node",{}).get("effect","")=="active" else "지속 / 강화"]
	return str(row.get("subtitle",""))

func probability(row:Dictionary)->String:
	return ("추가 보상 내 " if row.get("roll_mode","")=="guaranteed_extra_conditional_grade" else "독립 ")+"%s%%"%snappedf(float(row.get("chance",0))*100,.01)

func lines(values:Array)->String:
	var parts=PackedStringArray()
	for value in values:parts.append(str(value))
	return "\n".join(parts)

func section(title:String,body:String)->String:return "[b]"+title+"[/b]\n"+body+"\n\n"

func refresh_detail():
	var row=DB.detail(selected_tab,selected_id);link_target={};link_button.hide();rank_picker.hide();reference_picker.hide()
	for candidate in result.get("items",[]):
		if candidate.id==selected_id:row=candidate;break
	detail_name.text=str(row.get("name","기록을 선택하세요"));detail_subtitle.text="";detail_icon.texture=null if row.is_empty() else DB.asset_texture(row)
	detail_icon.material=preload("res://scripts/gat_art.gd").material() if selected_tab=="monsters" else null
	detail_icon.position=Vector2(20,17) if selected_tab=="monsters" else Vector2(37,35);detail_icon.size=Vector2(139,153) if selected_tab=="monsters" else Vector2(101,107)
	detail_scroll.position.y=184;detail_scroll.size.y=334;detail_body.custom_minimum_size.y=330
	if row.is_empty():
		detail_body.text="이 등급·단계 조합은 현재 드랍 규칙에 획득처가 없습니다.\n\n장비 도감은 가능한 모든 조합을 보여 줍니다. 다른 단계나 등급을 선택해 획득처를 확인하세요." if filters.has("equipment_id") else "왼쪽에서 장비, 몬스터, 전리품 또는 스킬의 그림을 선택하세요.\n\n필터를 바꾸면 전체 모험 기록을 탐색할 수 있습니다.";return
	detail_subtitle.text=row_caption(row)
	match selected_tab:
		"equipment":equipment_detail(row)
		"monsters":monster_detail(row)
		"drops":drop_detail(row)
		"skills":skill_detail(row)
	link_button.visible=not link_target.is_empty()

func equipment_detail(row:Dictionary):
	var text=section("착용 조건",str(row.get("restriction",Equipment.restriction_text(row))))
	text+=section("기본 성능","%s\n장비 보너스 +%d · 강화 +0 기준"%[str(row.get("description","")),int(row.get("bonus",0))])
	text+=section("강화와 추가 옵션",str(row.get("option_summary",Equipment.option_text(row))))
	text+=section("획득 안내","에픽·레전드리는 레이드 보스의 확정 추가 장비 보상에서 추첨합니다.\n무기는 현재 직업 전용, 방어구는 1차 직업 계열에 맞춰 생성됩니다." if int(row.get("rarity",0))>=3 else "몬스터 전리품에서 등급과 부위를 추첨합니다. 같은 부위도 획득 시점의 직업·층수에 따라 장비가 달라집니다.")
	detail_body.text=text;link_button.text="이 장비의 드랍 경로 →"
	link_target={"tab":"drops","filters":{"equipment_id":str(row.id)}}

func monster_detail(row:Dictionary):
	var text=section("전투 기록","%s\n생명력 %s · 공격력 %s"%[str(row.get("description","")),row.get("health","—"),row.get("damage","—")])
	if filters.get("floor",0)>0 and row.get("role","")!="raid":
		var values:Array=[]
		for appearance in DB.snapshot().appearances:
			if appearance.monster_id==row.id and int(appearance.floor_id)==int(filters.floor):values.append("%s · LV.%d\n생명력 %s · 공격력 %s"%[{"normal":"일반 출현","elite":"엘리트","guardian":"층 수문장","raid":"레이드"}.get(appearance.role,"출현"),appearance.level,appearance.health,appearance.damage])
		if not values.is_empty():text=section("%d층 실제 능력치"%int(filters.floor),lines(values))+text
	text+=section("출현 위치",floor_text(row))
	if row.get("role","")=="raid":
		var stages={}
		for pattern in row.get("patterns",[]):
			var phase=int(pattern.phase)
			if not stages.has(phase):stages[phase]=[]
			for area in pattern.areas:
				var shape={"circle":"연속 원형","cone":"부채꼴","line":"직선","ring":"고리"}.get(area.shape,str(area.shape))
				if not stages[phase].has(shape):stages[phase].append(shape)
		var values:Array=[]
		for phase in stages:values.append("%d단계 · %s"%[phase," / ".join(stages[phase])])
		text+=section("공격 예고",lines(values))
	text+=section("수치 읽는 법","레이드는 표시된 층의 실제 능력치입니다. 일반 몬스터 기본형의 수치는 원형 기준이며 던전 층에 따라 강해집니다.")
	if row.get("role","") in ["boss","raid"]:
		var stagger:Dictionary=row.get("stagger",{});var body="공격을 적중시켜 HP 피해와 별도로 무력화를 축적합니다. 기술 능력치는 스킬 무력화 피해를 높입니다."
		if not stagger.is_empty():body+="\n\n일반 게이지  %s\n제한시간 체크  %s / %.0f초\n성공 시 %.0f초 넘어짐 · 받는 피해 +%.0f%%\n회복 후 %.0f초 재무력화 유예"%[stagger.get("max_value",0),stagger.get("check_max",0),float(stagger.get("check_seconds",0)),float(stagger.get("down_seconds",0)),(float(stagger.get("down_damage_multiplier",1))-1)*100,float(stagger.get("immunity_seconds",0))]
		text+=section("무력화",body)
	detail_body.text=text;link_button.text="이 몬스터의 전리품 보기 →";link_target={"tab":"drops","filters":{"monster_id":row.id}}

func floor_text(row:Dictionary)->String:
	if row.has("floor"):return str(preload("res://scripts/abyss_catalog.gd").config(int(row.floor)).name).replace("B%d ·"%int(row.floor),"%d층 ·"%int(row.floor))
	var floors:Array=row.get("floors",[])
	if floors.is_empty():return "꽃바람 숲 튜토리얼 및 기존 지역"
	var spans=PackedStringArray();var first=int(floors[0]);var last=first
	for value in floors.slice(1):
		var f=int(value)
		if f==last+1:last=f;continue
		spans.append(str(first) if first==last else "%d–%d"%[first,last]);first=f;last=f
	spans.append(str(first) if first==last else "%d–%d"%[first,last]);return " · ".join(spans)+"층"

func drop_detail(row:Dictionary):
	var conditional=row.get("roll_mode","")=="guaranteed_extra_conditional_grade"
	var source_name=str(row.get("monster_name",""));var source_id=str(row.get("monster_id",""))
	if str(filters.get("monster_id","")).begins_with("raid:"):
		source_id=str(filters.monster_id);source_name=str(DB.detail("monsters",source_id).get("name",source_name))+" · "+("추가 장비" if conditional else "기본 드랍")
	var text=section("기본 획득 확률",probability(row)+("\n보스 처치 시 추가 장비 1개는 확정입니다. 표시값은 그 1개가 해당 등급이 될 확률입니다. 전리품 확률 보너스의 영향을 받지 않습니다." if conditional else "\n전리품 확률 보너스를 적용하기 전 값입니다. 이 항목은 개별 추첨합니다. 다른 전리품과 함께 나올 수 있으며 항목의 합은 100%가 아닙니다."))
	text+=section("전리품 상세","당첨 시 수량 ×%d\n%s"%[int(row.get("amount",1)),str(row.get("description",""))])
	text+=section("획득처",source_name+(" · %d층"%int(row.floor) if row.has("floor") else ""))
	if row.get("kind","") in ["weapon","armor","accessory","equipment"] or conditional:text+=section("장비 생성 규칙","직업에 맞는 무기 또는 1차 계열 방어구가 생성됩니다. 표의 확률은 전리품 항목의 확률이며 특정 이름의 장비 1개를 얻을 확률과 다릅니다.\n추가 옵션은 필요한 강화 단계에 도달하면 개방됩니다.")
	if row.has("source_floors"):text+=section("이 장비가 나오는 층",floor_text({"floors":row.source_floors}))
	if row.has("joint_slot_chance"):text+=section("선택 장비의 부위까지 맞을 확률","등급 × 부위: %s%%\n추가 장비 1개에서 선택한 등급과 부위가 함께 맞을 확률입니다."%snappedf(float(row.joint_slot_chance)*100,.001))
	detail_body.text=text;link_button.text="획득처 몬스터 살펴보기 →";link_target={"tab":"monsters","id":source_id}
	if conditional:link_target.id="raid:%03d"%int(row.get("floor",10))

func skill_detail(row:Dictionary):
	var ranks:Array=row.get("ranks",[]);var node:Dictionary=row.get("node",{});var maximum=int(row.get("max_rank",Content.max_rank(node)))
	if rank_picker.item_count!=maximum or rank_picker.get_meta("skill","")!=selected_id:
		rank_picker.clear();rank_picker.set_meta("skill",selected_id)
		for r in range(1,maximum+1):rank_picker.add_item("랭크 %d / %d"%[r,maximum])
	rank_index=clampi(rank_index,0,maxi(0,maximum-1));rank_picker.select(rank_index);rank_picker.show();reference_picker.show();reference_picker.select(1 if use_player_stats else 0)
	detail_scroll.position.y=231;detail_scroll.size.y=288;detail_body.custom_minimum_size.y=284
	var rank:Dictionary=ranks[rank_index] if rank_index<ranks.size() else {}
	var stagger:Dictionary=rank.get("stagger",{})
	if use_player_stats:stagger=preload("res://scripts/boss_stagger.gd").skill_profile(node,rank_index+1,player())
	var metrics:Array=[];var summary:Array=[]
	for metric in rank.get("metrics",[]):
		var line="%s   %s"%[str(metric[0]),str(metric[1])];metrics.append(line)
		if summary.is_empty() or str(metric[0])=="재사용 시간":summary.append(line)
	summary.append("무력화 %s · %s"%[str(stagger.get("grade","없음")),str(snappedf(float(stagger.get("value",0)),.1))]);summary.append("기술 보정 ×%.3f"%float(stagger.get("multiplier",1)))
	var text=section("랭크 %d 핵심 수치"%(rank_index+1),lines(summary))
	text+=section("스킬 효과",str(row.get("description",node.get("description",""))))
	var parent_names=PackedStringArray()
	for parent in row.get("parents",[]):
		var other=DB.detail("skills",str(parent));parent_names.append(str(other.get("name",parent)))
	text+=section("습득 조건","%s · LV.%d 이상\n%s"%[row.get("class_name",""),int(node.get("level",1)),"선행 없음" if parent_names.is_empty() else ("선행 모두: " if node.get("parent_mode","any")=="all" else "선행 중 하나: ")+" / ".join(parent_names)+" (랭크 %d)"%int(node.get("required_rank",1))])
	text+=section("랭크 %d 수치"%(rank_index+1),lines(metrics) if not metrics.is_empty() else "설명에 표시된 효과가 랭크에 따라 강화됩니다.")
	text+=section("수치 기준",str(DB.REFERENCE.note)+"\n내 기술 선택은 무력화 수치에만 적용합니다.")
	detail_body.text=text
	if not row.get("parents",[]).is_empty():link_button.text="첫 선행 스킬 살펴보기 →";link_target={"tab":"skills","id":str(row.parents[0])}

func follow_link():
	if link_target.is_empty():return
	var target=link_target.duplicate(true)
	if target.has("id"):
		var record=DB.detail(str(target.tab),str(target.id));target["filters"]={"q":str(record.get("name",target.id))}
	open(str(target.tab),target.get("filters",{}))
	if target.has("id"):
		selected_id=str(target.id);refresh_cards();refresh_detail()
