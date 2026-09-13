extends RefCounted
const Inventory=preload("res://scripts/inventory_model.gd")
const World=preload("res://scripts/world_catalog.gd")
const Items=preload("res://scripts/consumables.gd")
const Content=preload("res://scripts/content.gd")
const MAX_QUEUE=3
const DEFINITIONS={
	"field_tools":{"name":"탐사 도구 제작","facility":"smith","parent":"","seconds":30.,"cost":{"ore":4,"seed":2},"gold":20,"icon":"smith","output":"탐사 도구","recipe":{"ore":2},"price":10,"outputs":{"tool":1}},
	"snare_engineering":{"name":"올가미 구조","facility":"smith","parent":"field_tools","seconds":60.,"cost":{"ore":8,"essence":2},"gold":40,"icon":"trap","output":"올가미 덫","recipe":{"ore":3,"seed":2},"price":12,"outputs":{"snare_trap":1}},
	"lure_mixture":{"name":"유인제 배합","facility":"alchemy","parent":"","seconds":30.,"cost":{"seed":6,"ore":2},"gold":20,"icon":"sound","output":"유인 돌","recipe":{"seed":1,"ore":1},"price":5,"outputs":{"lure_stone":1}},
	"fire_distillation":{"name":"화염 증류","facility":"alchemy","parent":"lure_mixture","seconds":60.,"cost":{"seed":8,"essence":2},"gold":40,"icon":"fire","output":"화염병","recipe":{"seed":3,"ore":2},"price":15,"outputs":{"fire_bottle":1}},
	"field_pack":{"name":"긴급 보급 꾸리기","facility":"inn","parent":"","seconds":30.,"cost":{"seed":4,"ore":4},"gold":20,"icon":"bag","output":"물약 2 · 탐사 도구 1","recipe":{"seed":3,"ore":2},"price":20,"outputs":{"potion":2,"tool":1}},
	"reserve_pack":{"name":"전투 보급 꾸리기","facility":"inn","parent":"field_pack","seconds":60.,"cost":{"seed":8,"essence":2},"gold":40,"icon":"physical_attack","output":"마나 물약 2 · 공격 강화 물약 1","recipe":{"seed":6,"ore":3,"essence":1},"price":30,"outputs":{"mana_potion":2,"power_potion":1}}
}
static func empty()->Dictionary:return {"completed":[],"queue":[]}
static func valid(value)->bool:
	if not value is Dictionary:return false
	if value.is_empty():return true
	if value.size()!=2 or not value.get("completed") is Array or not value.get("queue") is Array:return false
	if value.completed.size()>DEFINITIONS.size() or value.queue.size()>MAX_QUEUE:return false
	var known=[]
	for key in value.completed:
		if not key is String or not DEFINITIONS.has(key) or key in known:return false
		known.append(key)
	for key in known:
		if not DEFINITIONS[key].parent.is_empty() and DEFINITIONS[key].parent not in known:return false
	for index in range(value.queue.size()):
		var row=value.queue[index]
		if not row is Dictionary or row.size()!=2 or not row.get("id") is String or not DEFINITIONS.has(row.id) or row.id in known:return false
		var elapsed=row.get("elapsed")
		if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or elapsed<0 or elapsed>=DEFINITIONS[row.id].seconds:return false
		if index>0 and elapsed!=0:return false
		if not DEFINITIONS[row.id].parent.is_empty() and DEFINITIONS[row.id].parent not in known:return false
		known.append(row.id)
	return true
static func restore(value)->Dictionary:
	return value.duplicate(true) if valid(value) and not value.is_empty() else empty()
static func completed(p:Dictionary,key:String)->bool:return key in p.get("town_research",{}).get("completed",[])
static func matches(facility:String,query:String)->Array:
	var rows=[];var term=query.strip_edges().to_lower()
	for key in DEFINITIONS:
		var row=DEFINITIONS[key]
		var names=row.name+" "+row.output
		for item in row.outputs:names+=" "+(Items.ITEMS[item].name if Items.ITEMS.has(item) else Content.MATERIALS[item])
		if row.facility==facility and (term.is_empty() or names.to_lower().contains(term)):rows.append(key)
	return rows
static func stage(p:Dictionary,key:String,operation:String)->Dictionary:
	var q={"reason":"","player":{},"title":"","cost":{},"gold":0,"outputs":{}}
	if not DEFINITIONS.has(key) or operation not in ["research_start","research_cancel","research_craft"]:q.reason="작업을 선택하세요.";return q
	var definition=DEFINITIONS[key];var state=restore(p.get("town_research",{}));var staged=p.duplicate(true);staged["town_research"]=state
	q.title=definition.name
	var queued=state.queue.map(func(row):return row.id)
	if operation=="research_start":
		if key in state.completed or key in queued:q.reason="이미 완료했거나 예약한 연구입니다.";return q
		if state.queue.size()>=MAX_QUEUE:q.reason="연구 예약은 최대 3개입니다.";return q
		if not definition.parent.is_empty() and definition.parent not in state.completed and definition.parent not in queued:q.reason="선행 연구 · "+DEFINITIONS[definition.parent].name;return q
		q.cost=definition.cost;q.gold=definition.gold
		state.queue.append({"id":key,"elapsed":0.})
	elif operation=="research_craft":
		if key not in state.completed:q.reason="먼저 연구를 완료하세요.";return q
		q.cost=definition.recipe;q.gold=definition.price;q.outputs=definition.outputs;q.title=definition.output
	else:
		if key not in queued:q.reason="진행 중인 연구가 아닙니다.";return q
		var removed=[key]
		for row in state.queue:
			if DEFINITIONS[row.id].parent in removed:removed.append(row.id)
		for id in removed:
			q.gold-=DEFINITIONS[id].gold
			for material in DEFINITIONS[id].cost:q.outputs[material]=int(q.outputs.get(material,0))+int(DEFINITIONS[id].cost[material])
		state.queue=state.queue.filter(func(row):return row.id not in removed)
		q.title="연구 취소 · %d개 환급"%removed.size()
	if staged.gold<q.gold:q.reason="금화 %d G 부족"%(q.gold-staged.gold);return q
	staged.gold-=q.gold
	for material in q.cost:
		if int(staged.materials.get(material,0))<int(q.cost[material]):q.reason=preload("res://scripts/content.gd").MATERIALS[material]+" %d개 부족"%(int(q.cost[material])-int(staged.materials.get(material,0)));return q
		staged.materials[material]-=int(q.cost[material])
		if staged.materials[material]==0:staged.bag_positions.erase("@mat:"+material)
	for item in q.outputs:
		if not Inventory.add_stack(staged,item,q.outputs[item]):q.reason=Inventory.stack_failure_reason(staged,item,q.outputs[item]);return q
	q.player=staged
	return q
static func use(sim,p:Dictionary,request:Dictionary)->bool:
	var key=request.get("research","");var operation=request.get("operation","")
	if not key is String or not operation is String or not DEFINITIONS.has(key):return false
	if request.size()!=3 or request.get("facility","")!=DEFINITIONS[key].facility:return false
	if sim.map.zone!="town" or p.hp<=0 or p.get("network_leaving",false) or World.nearest(p.pos)!=DEFINITIONS[key].facility:return false
	var result=stage(p,key,operation)
	if not result.reason.is_empty():sim.notice(p.id,result.reason);return false
	for field in ["town_research","gold","materials","potions","consumables","bag_positions"]:p[field]=result.player[field]
	sim.dirty[p.id]=true;sim.notice(p.id,result.title+" · "+("예약 완료" if operation=="research_start" else "완료"))
	return true
static func tick(sim,delta:float):
	if delta<=0 or not is_finite(delta):return
	for p in sim.players.values():
		if p.get("network_leaving",false):continue
		var state=p.get("town_research",{})
		if state.get("queue",[]).is_empty():continue
		var remaining=delta
		while remaining>0 and not state.queue.is_empty():
			var row=state.queue[0];var definition=DEFINITIONS[row.id];var spend=minf(remaining,definition.seconds-float(row.elapsed))
			row.elapsed+=spend;remaining-=spend
			if row.elapsed<definition.seconds:break
			state.queue.pop_front();state.completed.append(row.id);sim.dirty[p.id]=true
			sim.notice(p.id,definition.name+" 연구 완료 · "+definition.output)
static func configuration()->Dictionary:
	return {"definitions":DEFINITIONS,"maximum_queue":MAX_QUEUE,"scope":"personal_character","reserve_cost":"on_enqueue","clock":"connected_session_including_personal_menus_not_offline","cancel":"refund_selected_and_queued_descendants_atomically","save":"optional_v7_town_research","unlock":"new_recipe_available_at_its_facility","existing_services":"preserved"}
