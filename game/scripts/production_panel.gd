extends Control
const Production=preload("res://scripts/production_queue.gd")
const Icons=preload("res://scripts/icon_library.gd")
const Art=preload("res://scripts/ui_art.gd")
var town
var game
var selected=""
var mode="count"
var quantity=1
var search:LineEdit
var content:Control
var pending=0
var stamp=[]
var clocks={}
var refresh_time=0.
var start_button:Button
var quantity_input:SpinBox
func setup(owner_town):
	town=owner_town;game=town.game;size=town.body.size
	search=LineEdit.new();search.position=Vector2(12,6);search.size=Vector2(434,44);search.placeholder_text="제작물 검색";search.add_theme_font_size_override("font_size",21);add_child(search);style_input(search)
	search.text_changed.connect(func(_value):rebuild())
	content=Control.new();content.size=size;add_child(content);move_child(search,-1)
	if game.session.has_signal("request_completed"):game.session.request_completed.connect(completed)
	rebuild()
func style_input(field:LineEdit):
	var style=StyleBoxTexture.new();style.texture=Art.plain_paper()
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:style.set_texture_margin(side,5);style.set_content_margin(side,10 if side in [SIDE_LEFT,SIDE_RIGHT] else 2)
	field.add_theme_stylebox_override("normal",style);field.add_theme_stylebox_override("focus",style)
	field.add_theme_color_override("font_color",Color("29434a"));field.add_theme_color_override("font_placeholder_color",Color("617776"));field.add_theme_color_override("caret_color",Color("29434a"))
func style_bar(bar:ProgressBar):
	var back=StyleBoxFlat.new();back.bg_color=Color("263a3c");back.set_border_width_all(1);back.border_color=Color("8c794b")
	var fill=StyleBoxFlat.new();fill.bg_color=Color("b68b42")
	bar.add_theme_stylebox_override("background",back);bar.add_theme_stylebox_override("fill",fill)
func completed(kind:String,_success:bool):
	if kind=="facility" and game.session.completed_sequence==pending:pending=0;stamp=[]
func text(parent,value,at,dimensions,font_size=20,lines=2):return town.wrapped(parent,value,at,dimensions,font_size,lines)
func item_name(key:String)->String:
	return Production.Items.ITEMS[key].name if Production.Items.ITEMS.has(key) else Production.Content.MATERIALS.get(key,key)
func outputs_text(outputs:Dictionary)->String:
	var parts=[]
	for key in outputs:parts.append(item_name(key)+" ×%d"%outputs[key])
	return " · ".join(parts)
func cost_text(definition:Dictionary)->String:
	var parts=["%d G"%definition.gold]
	for key in definition.materials:parts.append(item_name(key)+" %d"%definition.materials[key])
	return " · ".join(parts)
func request()->Dictionary:
	return {"facility":town.facility,"operation":"production_start","recipe":selected,"mode":mode,"quantity":1 if mode=="repeat" else quantity}
func act(value:Dictionary):
	if pending>0:return
	if game.session.get("network_role")=="client":pending=game.session.sequence+1
	if not game.session.act("facility",JSON.stringify(value)):pending=0
	stamp=[];rebuild()
func rebuild():
	for child in content.get_children():content.remove_child(child);child.queue_free()
	clocks.clear();start_button=null;quantity_input=null
	var p=town.player();var definitions=Production.recipes();var rows=[];var term=search.text.strip_edges()
	for key in definitions:
		if definitions[key].facility==town.facility and (term.is_empty() or definitions[key].name.contains(term)):rows.append(key)
	if selected not in rows:selected="" if rows.is_empty() else rows[0]
	var scroll=ScrollContainer.new();scroll.position=Vector2(8,60);scroll.size=Vector2(447,294);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scroll)
	var list=VBoxContainer.new();list.custom_minimum_size.x=424;list.add_theme_constant_override("separation",10);scroll.add_child(list)
	for key in rows:
		var definition=definitions[key];var unlocked=Production.unlocked(p,definition)
		var slot=Control.new();slot.custom_minimum_size=Vector2(424,79);list.add_child(slot)
		var button=game.button(slot,"",Vector2.ZERO,Vector2(419,79),func():selected=key;rebuild(),selected==key)
		Icons.picture(button,definition.icon,Vector2(18,16),Vector2(46,46))
		text(button,definition.name,Vector2(82,4),Vector2(311,41),22,1)
		text(button,outputs_text(definition.outputs) if unlocked else ("LV.%d부터 제작"%int(definition.level) if int(p.level)<int(definition.get("level",1)) else "선행 연구 필요"),Vector2(82,45),Vector2(311,27),17,1)
	if rows.is_empty():text(content,"검색 결과가 없습니다.",Vector2(24,90),Vector2(406,55))
	if not selected.is_empty():details(p,definitions[selected])
	var state=p.get("production",Production.empty())
	var queue=Art.panel(content,Vector2(8,376),Vector2(1234,296),"paper",4)
	text(queue,"제작 대기열  %d / %d"%[state.queue.size(),Production.MAX_QUEUE],Vector2(24,16),Vector2(490,37),25)
	text(queue,"접속 중 제작 · 예약한 1회분만 재료 보관",Vector2(520,23),Vector2(681,32),18)
	if state.queue.is_empty():text(queue,"맡긴 작업이 없습니다.",Vector2(28,105),Vector2(700,45),22)
	for index in range(state.queue.size()):
		var row=state.queue[index];var definition=definitions[row.recipe];var x=24+index*400
		Icons.picture(queue,definition.icon,Vector2(x,76),Vector2(43,43))
		text(queue,definition.name,Vector2(x+53,66),Vector2(327,33),21,1)
		var mode_text="남은 %d회"%row.remaining if row.mode=="count" else "보유 목표 %d개"%row.target if row.mode=="target" else "중지할 때까지 반복"
		text(queue,Production.World.FACILITIES[definition.facility].name+" · "+mode_text,Vector2(x+53,105),Vector2(327,29),16,1)
		var bar=ProgressBar.new();bar.position=Vector2(x+8,144);bar.size=Vector2(372,12);bar.max_value=definition.seconds;bar.show_percentage=false;queue.add_child(bar);style_bar(bar)
		var status=text(queue,"",Vector2(x+8,166),Vector2(372,38),18,1);clocks[row.id]={"bar":bar,"status":status}
		var priority=game.button(queue,"먼저 제작",Vector2(x+8,222),Vector2(178,44),func():act({"facility":town.facility,"operation":"production_priority","order":row.id}))
		priority.disabled=pending>0 or index==0 or definition.facility!=town.facility
		var value={"facility":town.facility,"operation":"production_cancel","order":row.id};var quote=Production.stage(p,value)
		var cancel=game.button(queue,"취소 · 환급",Vector2(x+202,222),Vector2(178,44),func():act(value))
		cancel.disabled=pending>0 or not quote.reason.is_empty();cancel.tooltip_text=quote.reason if not quote.reason.is_empty() else "미완료 1회분 환급 · "+cost_text(definition) if row.reserved else "아직 맡긴 재료 없음"
	town.inset_buttons(content);update_clocks(p)
func details(p:Dictionary,definition:Dictionary):
	if mode=="target" and definition.outputs.size()!=1:mode="count"
	quantity=clampi(quantity,1,99 if mode=="count" else Production.Inventory.stack_limit(definition.outputs.keys()[0]) if mode=="target" else 1)
	var panel=Art.panel(content,Vector2(477,0),Vector2(765,354),"paper",4)
	Icons.picture(panel,definition.icon,Vector2(24,24),Vector2(63,63))
	text(panel,definition.name,Vector2(104,12),Vector2(624,48),26,1)
	text(panel,outputs_text(definition.outputs)+" · %d초"%definition.seconds,Vector2(104,62),Vector2(624,33),20,1)
	for index in range(3):
		var key=Production.MODES[index]
		var button=game.button(panel,["횟수 지정","목표 수량","계속 제작"][index],Vector2(24+index*238,115),Vector2(222,43),func():mode=key;quantity=1;rebuild(),mode==key)
		button.disabled=key=="target" and definition.outputs.size()!=1
	text(panel,"제작 횟수" if mode=="count" else "목표 보유량" if mode=="target" else "중지할 때까지 반복",Vector2(24,179),Vector2(215,38),21)
	if mode!="repeat":
		quantity_input=SpinBox.new();quantity_input.position=Vector2(242,177);quantity_input.size=Vector2(155,43);quantity_input.min_value=1;quantity_input.max_value=99 if mode=="count" else Production.Inventory.stack_limit(definition.outputs.keys()[0]);quantity_input.step=1;quantity_input.value=quantity;quantity_input.add_theme_font_size_override("font_size",21);panel.add_child(quantity_input);style_input(quantity_input.get_line_edit())
		quantity_input.value_changed.connect(func(value):quantity=int(value);update_quote())
	text(panel,"1회 예약 · "+cost_text(definition),Vector2(24,236),Vector2(711,34),19,1)
	var quote=Production.stage(p,request())
	start_button=game.button(panel,"제작 예약" if quote.reason.is_empty() else quote.reason,Vector2(24,289),Vector2(711,44),func():act(request()))
	start_button.disabled=pending>0 or not quote.reason.is_empty();start_button.tooltip_text=quote.reason
func update_quote():
	if not is_instance_valid(start_button):return
	var quote=Production.stage(town.player(),request())
	start_button.text="제작 예약" if quote.reason.is_empty() else quote.reason
	start_button.disabled=pending>0 or not quote.reason.is_empty();start_button.tooltip_text=quote.reason
func update_clocks(p:Dictionary):
	var state=p.get("production",Production.empty())
	for index in range(state.queue.size()):
		var row=state.queue[index]
		if not clocks.has(row.id):continue
		var definition=Production.recipes()[row.recipe];var widgets=clocks[row.id];widgets.bar.value=row.elapsed
		var reason=Production.waiting_reason(p,row)
		widgets.bar.visible=index==0 and row.reserved and reason.is_empty()
		widgets.status.text=reason if not reason.is_empty() else "제작 중 · %d초"%ceili(definition.seconds-row.elapsed) if index==0 else "차례 대기"
		widgets.status.tooltip_text=widgets.status.text
func _process(delta):
	if not is_instance_valid(town) or not town.visible or not game.session.connected:return
	refresh_time+=delta
	if refresh_time<.25:return
	refresh_time=0.
	var p=town.player();var state=p.get("production",Production.empty())
	var next=[state.queue.map(func(row):return [row.id,row.remaining,row.reserved]),p.gold,p.materials.hash(),p.potions,p.consumables.hash(),p.bag_positions.hash(),p.town_research.completed,mode,pending]
	if next!=stamp:stamp=next.duplicate(true);rebuild()
	town.money.text="보유 금화  %d G"%p.gold
	for key in town.resource_labels:town.resource_labels[key].text=Production.Content.MATERIALS[key]+"  "+str(p.materials.get(key,0))
	update_clocks(p)
