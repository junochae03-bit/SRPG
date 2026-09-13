extends Control
const Research=preload("res://scripts/town_research.gd")
const Content=preload("res://scripts/content.gd")
const Items=preload("res://scripts/consumables.gd")
const Icons=preload("res://scripts/icon_library.gd")
const Journey=preload("res://scripts/research_journey.gd")
var town
var game
var search:LineEdit
var selected=""
var content:Control
var pending=0
var stamp=[]
var countdowns={}
var start_button:Button
var craft_button:Button
var labels=[]
var goal_button:Button
var next_destination=""
func setup(owner_town):
	town=owner_town;game=town.game;size=town.body.size
	search=LineEdit.new();search.position=Vector2(16,10);search.size=Vector2(550,46);search.placeholder_text="연구 · 제작물 검색";search.add_theme_font_size_override("font_size",21);add_child(search)
	search.text_changed.connect(func(_value):rebuild())
	content=Control.new();content.position=Vector2(0,68);content.size=Vector2(1258,622);add_child(content)
	selected=Research.matches(town.facility,"")[0]
	var goal=town.player().get("expedition_goal",{})
	if goal.get("kind","")=="research" and goal.facility==town.facility:selected=goal.item
	goal_button=game.button(self,"재료 찾기",Vector2(590,10),Vector2(648,46),choose_goal)
	if game.session.has_signal("request_completed"):game.session.request_completed.connect(completed)
	rebuild()
func completed(kind:String,_success:bool):
	if kind in ["facility","select_goal"] and game.session.completed_sequence==pending:
		pending=0;stamp=[]
		if kind=="select_goal" and _success:guide_goal()
func choose_goal():
	if pending>0 or selected.is_empty():return
	var p=town.player();var goal=p.get("expedition_goal",{})
	var finished=goal.get("kind","")=="research" and goal.item==selected and int(goal.stage)==3
	var id="advance" if finished else "research:"+selected
	next_destination="portal"
	if game.session.get("network_role")=="client":pending=game.session.sequence+1
	var success=game.session.act("select_goal",JSON.stringify({"id":id,"floor":int(p.highest_floor)}))
	if not success:pending=0;next_destination="";stamp=[];return
	if game.session.get("network_role")!="client":guide_goal()
func guide_goal():
	var goal=town.player().get("expedition_goal",{})
	if goal.get("kind","")=="research":
		var work=Journey.work_status(town.player(),goal)
		if work.ready:next_destination=work.facility
	if not next_destination.is_empty():town.close();game.guide_to_facility(next_destination);next_destination=""
func text(parent,value,at,dimensions,font_size=20):
	var label=town.wrapped(parent,value,at,dimensions,font_size,3);labels.append(label);return label
func cost_text(cost:Dictionary,gold:int)->String:
	var parts=[]
	if gold!=0:parts.append("%d G"%gold)
	for key in cost:parts.append(Content.MATERIALS[key]+" %d"%cost[key])
	return " · ".join(parts)
func output_text(outputs:Dictionary)->String:
	var parts=[]
	for key in outputs:parts.append((Items.ITEMS[key].name if Items.ITEMS.has(key) else Content.MATERIALS[key])+" ×%d"%outputs[key])
	return " · ".join(parts)
func act(key:String,operation:String):
	if pending>0:return
	if game.session.get("network_role")=="client":pending=game.session.sequence+1
	if not game.session.act("facility",JSON.stringify({"facility":town.facility,"research":key,"operation":operation})):pending=0
	stamp=[];rebuild()
func rebuild():
	for child in content.get_children():content.remove_child(child);child.queue_free()
	countdowns.clear();labels.clear();start_button=null;craft_button=null
	var p=town.player();var state=p.get("town_research",Research.empty());var rows=Research.matches(town.facility,search.text)
	town.money.text="보유 금화  %d G"%p.gold
	for material in town.resource_labels:town.resource_labels[material].text=Content.MATERIALS[material]+"  "+str(p.materials.get(material,0))
	if selected not in rows:selected="" if rows.is_empty() else rows[0]
	var goal=p.get("expedition_goal",{});var active=goal.get("kind","")=="research" and goal.get("item","")==selected
	goal_button.text="다음 탐사 선택" if active and int(goal.stage)==3 else "등록된 탐사 목표" if active else "탐사 목표로 등록"
	goal_button.disabled=pending>0 or selected.is_empty() or (active and int(goal.stage)<3) or not Journey.eligible(p,selected) or (active and int(goal.stage)==3 and p.cleared_floor>=100)
	goal_button.tooltip_text="등록한 목표에 따라 필요한 재료와 다음 작업을 표시합니다."
	var list=preload("res://scripts/ui_art.gd").panel(content,Vector2(8,0),Vector2(567,356),"paper",4)
	if rows.is_empty():text(list,"검색 결과가 없습니다.",Vector2(25,30),Vector2(510,45))
	for index in range(rows.size()):
		var key=rows[index];var definition=Research.DEFINITIONS[key]
		var button=game.button(list,"",Vector2(18,20+index*136),Vector2(531,118),func():selected=key;rebuild(),key==selected)
		Icons.picture(button,definition.icon,Vector2(20,29),Vector2(52,52))
		text(button,definition.name,Vector2(86,16),Vector2(340,34),23)
		text(button,definition.output,Vector2(86,56),Vector2(405,44),18)
		var status="제작 가능" if key in state.completed else "예약됨" if state.queue.any(func(row):return row.id==key) else "연구"
		text(button,status,Vector2(420,16),Vector2(96,30),16)
	if not selected.is_empty():details(p,state)
	var queue=preload("res://scripts/ui_art.gd").panel(content,Vector2(8,372),Vector2(1232,234),"paper",4)
	text(queue,"연구 진행 · %d / 3"%state.queue.size(),Vector2(24,18),Vector2(900,35),23)
	text(queue,"개인 연구 · 접속 중 진행 · 시설 공통 3칸",Vector2(402,22),Vector2(794,31),18)
	if state.queue.is_empty():text(queue,"예약된 연구가 없습니다.",Vector2(28,85),Vector2(600,40))
	for index in range(state.queue.size()):
		var row=state.queue[index];var definition=Research.DEFINITIONS[row.id];var x=24+index*403
		Icons.picture(queue,definition.icon,Vector2(x,73),Vector2(38,38))
		text(queue,definition.name,Vector2(x+47,68),Vector2(336,34),20)
		countdowns[row.id]=text(queue,"",Vector2(x+47,110),Vector2(330,29),18)
		var button=game.button(queue,"취소 · 재료 환급",Vector2(x+28,155),Vector2(339,43),func():act(row.id,"research_cancel"))
		var quote=Research.stage(p,row.id,"research_cancel")
		button.disabled=pending>0 or definition.facility!=town.facility or not quote.reason.is_empty()
		button.tooltip_text=Research.World.FACILITIES[definition.facility].name+"에서 취소" if definition.facility!=town.facility else quote.reason if not quote.reason.is_empty() else "연결된 후속 예약도 취소하고 맡긴 재료를 돌려받습니다."
	town.inset_buttons(content);refresh_clock(state)
func details(p:Dictionary,state:Dictionary):
	var definition=Research.DEFINITIONS[selected]
	var panel=preload("res://scripts/ui_art.gd").panel(content,Vector2(593,0),Vector2(647,356),"paper",4)
	text(panel,definition.name,Vector2(24,16),Vector2(590,48),26)
	text(panel,"해금 · "+definition.output,Vector2(24,70),Vector2(590,48),21)
	if selected in state.completed:
		text(panel,"제작 비용 · "+cost_text(definition.recipe,definition.price),Vector2(24,133),Vector2(590,62),19)
		text(panel,"결과 · "+output_text(definition.outputs),Vector2(24,202),Vector2(590,55),19)
		var quote=Research.stage(p,selected,"research_craft")
		craft_button=game.button(panel,"제작하기",Vector2(24,282),Vector2(590,47),func():act(selected,"research_craft"))
		craft_button.disabled=pending>0 or not quote.reason.is_empty();craft_button.tooltip_text=quote.reason
	else:
		text(panel,"연구 비용 · "+cost_text(definition.cost,definition.gold),Vector2(24,126),Vector2(590,55),19)
		var prior="선행 연구 없음" if definition.parent.is_empty() else "선행 · "+Research.DEFINITIONS[definition.parent].name
		var prerequisite=game.button(panel,prior,Vector2(24,186),Vector2(590,38),func():
			if not definition.parent.is_empty():search.text="";selected=definition.parent;rebuild())
		prerequisite.disabled=definition.parent.is_empty()
		text(panel,"연구 시간 · %d초"%definition.seconds,Vector2(24,237),Vector2(590,29),18)
		var quote=Research.stage(p,selected,"research_start")
		start_button=game.button(panel,"연구 시작" if state.queue.is_empty() else "다음 연구 예약",Vector2(24,282),Vector2(590,47),func():act(selected,"research_start"))
		start_button.disabled=pending>0 or not quote.reason.is_empty();start_button.tooltip_text=quote.reason
func refresh_clock(state:Dictionary):
	for index in range(state.queue.size()):
		var row=state.queue[index]
		if countdowns.has(row.id):countdowns[row.id].text="진행 중 · %d초"%ceili(Research.DEFINITIONS[row.id].seconds-float(row.elapsed)) if index==0 else "대기 %d"%index
func _process(_delta):
	if not is_instance_valid(town) or not town.visible or not game.session.connected:return
	var p=town.player();var state=p.get("town_research",Research.empty())
	var next=[state.completed,state.queue.map(func(row):return row.id),p.gold,p.materials.hash(),p.potions,p.get("consumables",{}).hash(),p.bag_positions.hash(),p.get("expedition_goal",{}).hash(),pending]
	if next!=stamp:stamp=next.duplicate(true);rebuild()
	refresh_clock(state)
