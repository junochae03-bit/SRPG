extends Control
const Goals=preload("res://scripts/expedition_goals.gd")
var town
var rows=[]
var pending=0
var status:Label
var clear_button:Button
var stamp=""
var feedback=""

func setup(owner_town):
	town=owner_town;position=Vector2(0,76);size=Vector2(724,610)
	var offers=Goals.offers(town.player(),town.selected_floor)
	for index in range(offers.size()):
		var offer=offers[index];var at=Vector2(0,index*135)
		var button=town.game.button(self,"",at,Vector2(718,124),func():choose(offer))
		town.Library.picture(button,offer.icon,Vector2(19,21),Vector2(56,56))
		town.wrapped(button,offer.title,Vector2(91,7),Vector2(526,42),22,1)
		town.wrapped(button,offer.detail,Vector2(92,48),Vector2(582,27),17,1)
		var hint=town.wrapped(button,offer.clue,Vector2(92,78),Vector2(582,31),16,1);hint.tooltip_text=offer.clue
		button.tooltip_text=offer.clue
		var selected=town.Library.picture(button,"selected",Vector2(668,17),Vector2(25,25));selected.hide()
		rows.append({"offer":offer,"button":button,"selected":selected})
	status=town.wrapped(self,"",Vector2(8,550),Vector2(542,53),18,2)
	clear_button=town.game.button(self,"목표 해제",Vector2(565,550),Vector2(146,43),func():choose({"id":"clear","goal":{"floor":town.selected_floor}}))
	if town.game.session.has_signal("request_completed"):town.game.session.request_completed.connect(completed)
	refresh()

func choose(offer:Dictionary):
	if pending>0:return
	feedback=""
	var session=town.game.session
	if session.get("network_role")=="client":pending=session.sequence+1
	var success=session.act("select_goal",JSON.stringify({"id":offer.id,"floor":mini(town.selected_floor,int(town.player().highest_floor))}))
	if session.get("network_role")!="client":
		if success:town.selected_floor=int(offer.goal.floor);town.chapter=int((town.selected_floor-1)/10);town.refresh()
		else:feedback="현재 재료와 해금을 확인해 목표를 다시 선택하세요."
	elif not success:pending=0
	stamp=""

func completed(kind:String,success:bool):
	if kind!="select_goal" or town.game.session.completed_sequence!=pending:return
	pending=0;stamp=""
	if success:
		town.selected_floor=int(town.player().expedition_goal.get("floor",town.selected_floor));town.chapter=int((town.selected_floor-1)/10);town.refresh()
	else:feedback="목표를 등록하지 못했습니다. 현재 해금과 재료를 확인하세요."

func _process(_delta):
	if is_visible_in_tree():refresh()

func refresh():
	if not town.game.session.connected:pending=0;return
	var data=town.player().get("expedition_goal",{})
	var context=JSON.stringify([data,pending,feedback])
	if context==stamp:return
	stamp=context
	clear_button.disabled=pending>0 or data.is_empty()
	for row in rows:
		var selected=not data.is_empty() and data.kind==row.offer.goal.kind and data.floor==row.offer.goal.floor and data.target==row.offer.goal.target and data.material==row.offer.goal.material and data.item==row.offer.goal.item
		row.selected.visible=selected;row.button.disabled=pending>0 or selected
	var summary=Goals.describe(town.player())
	status.text=feedback if not feedback.is_empty() else "목표 확인 중…" if pending>0 else "등록된 목표 · B%d · %s"%[summary.floor,summary.title] if not summary.is_empty() else ""
