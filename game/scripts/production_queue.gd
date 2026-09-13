extends RefCounted
## Personal work orders reserve one batch at a time; only the authority advances them.
const Inventory=preload("res://scripts/inventory_model.gd")
const Research=preload("res://scripts/town_research.gd")
const World=preload("res://scripts/world_catalog.gd")
const Items=preload("res://scripts/consumables.gd")
const Content=preload("res://scripts/content.gd")
const MAX_QUEUE=3
const MODES=["count","target","repeat"]
const BASE={
	"alchemy:potion":{"name":"회복 물약","facility":"alchemy","gold":10,"materials":{"seed":3},"outputs":{"potion":3},"seconds":6.,"icon":"potion","research":""},
	"alchemy:mana_potion":{"name":"기력 물약","facility":"alchemy","gold":15,"materials":{"seed":3,"essence":1},"outputs":{"mana_potion":3},"seconds":6.,"icon":"stamina","research":""},
	"alchemy:power_potion":{"name":"공격 강화 물약","facility":"alchemy","gold":30,"materials":{"seed":3,"ore":2},"outputs":{"power_potion":3},"seconds":8.,"icon":"physical_attack","research":""},
	"alchemy:essence":{"name":"정원의 정수","facility":"alchemy","gold":40,"materials":{"seed":5,"ore":5},"outputs":{"essence":1},"seconds":8.,"icon":"essence","research":""},
	"alchemy:ore":{"name":"광석","facility":"alchemy","gold":20,"materials":{"seed":5},"outputs":{"ore":3},"seconds":6.,"icon":"ore","research":""}}
static func recipes()->Dictionary:
	var result=BASE.duplicate(true)
	result.merge(preload("res://scripts/exploration_crafting_data.gd").catalog().get("alchemy_recipes",{}),false)
	for key in Research.DEFINITIONS:
		var row=Research.DEFINITIONS[key]
		result["research:"+key]={"name":row.output,"facility":row.facility,"gold":row.price,"materials":row.recipe.duplicate(),"outputs":row.outputs.duplicate(),"seconds":8.,"icon":row.icon,"research":key}
	return result
static func empty()->Dictionary:return {"next_id":1,"queue":[]}
static func amount(p:Dictionary,key:String)->int:
	return Items.count(p,key) if Items.ITEMS.has(key) else int(p.get("materials",{}).get(key,0))
static func valid(value)->bool:
	if not value is Dictionary:return false
	if value.is_empty():return true
	if value.size()!=2 or not Inventory.whole_count(value.get("next_id"),2000000000) or value.next_id<1 or not value.get("queue") is Array or value.queue.size()>MAX_QUEUE:return false
	var definitions=recipes();var ids=[]
	for row in value.queue:
		if not row is Dictionary or row.size()!=7:return false
		if not Inventory.whole_count(row.get("id"),int(value.next_id)-1) or row.id<1 or row.id in ids:return false
		if not row.get("recipe") is String or not definitions.has(row.recipe) or row.get("mode") not in MODES or not row.get("reserved") is bool:return false
		if not Inventory.whole_count(row.get("remaining"),99) or not Inventory.whole_count(row.get("target"),999999):return false
		if row.mode=="count" and (row.remaining<1 or row.target!=0):return false
		if row.mode!="count" and row.remaining!=0:return false
		if row.mode!="target" and row.target!=0:return false
		var definition=definitions[row.recipe]
		if row.mode=="target" and (definition.outputs.size()!=1 or row.target<1 or row.target>Inventory.stack_limit(definition.outputs.keys()[0])):return false
		var elapsed=row.get("elapsed")
		if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or elapsed<0 or elapsed>definition.seconds or (not row.reserved and elapsed!=0):return false
		ids.append(row.id)
	return true
static func restore(value)->Dictionary:
	if not valid(value) or value.is_empty():return empty()
	var state=value.duplicate(true);state.next_id=int(state.next_id)
	for row in state.queue:
		for key in ["id","remaining","target"]:row[key]=int(row[key])
		row.elapsed=float(row.elapsed)
	return state
static func unlocked(p:Dictionary,definition:Dictionary)->bool:
	return int(p.level)>=int(definition.get("level",1)) and (definition.research.is_empty() or Research.completed(p,definition.research))
static func reserve(p:Dictionary,row:Dictionary,definition:Dictionary)->String:
	if row.reserved:return ""
	if int(p.level)<int(definition.get("level",1)):return "LV.%d부터 제작"%int(definition.level)
	if not unlocked(p,definition):return "선행 연구가 필요합니다."
	if p.gold<definition.gold:return "금화 부족"
	for key in definition.materials:
		if amount(p,key)<definition.materials[key]:return Content.MATERIALS[key]+" 부족"
	p.gold-=definition.gold
	for key in definition.materials:
		p.materials[key]-=definition.materials[key]
		if p.materials[key]==0:p.bag_positions.erase("@mat:"+key)
	row.reserved=true;return ""
static func refund(p:Dictionary,row:Dictionary,definition:Dictionary)->String:
	if not row.reserved:return ""
	for key in definition.materials:
		if not Inventory.add_stack(p,key,definition.materials[key]):return "환급 대기 · "+Inventory.stack_failure_reason(p,key,definition.materials[key])
	p.gold+=definition.gold;row.reserved=false;row.elapsed=0.;return ""
static func target_met(p:Dictionary,row:Dictionary,definition:Dictionary)->bool:
	return row.mode=="target" and amount(p,definition.outputs.keys()[0])>=row.target
static func stage(p:Dictionary,request:Dictionary)->Dictionary:
	var result={"reason":"","player":{},"title":"제작","gold":0,"materials":{},"outputs":{}}
	var operation=request.get("operation","");var definitions=recipes();var staged=p.duplicate(true)
	staged["production"]=restore(p.get("production",{}));var state=staged.production
	if operation=="production_start":
		if request.size()!=5 or not request.get("recipe") is String or not definitions.has(request.recipe) or request.get("mode") not in MODES:result.reason="제작 방식을 선택하세요.";return result
		var definition=definitions[request.recipe];var number=request.get("quantity")
		if request.get("facility")!=definition.facility or not Inventory.whole_count(number,999999) or number<1:result.reason="제작 수량을 확인하세요.";return result
		if int(p.level)<int(definition.get("level",1)):result.reason="LV.%d부터 제작"%int(definition.level);return result
		if not unlocked(p,definition):result.reason="먼저 해당 제작 연구를 완료하세요.";return result
		if state.queue.size()>=MAX_QUEUE or state.next_id>=2000000000:result.reason="제작 예약은 최대 3개입니다.";return result
		if request.mode=="count" and number>99:result.reason="한 작업에 최대 99회까지 예약할 수 있습니다.";return result
		if request.mode=="repeat" and number!=1:result.reason="반복 제작 수량을 확인하세요.";return result
		if request.mode=="target":
			if definition.outputs.size()!=1:result.reason="여러 물품을 만드는 제작은 횟수 또는 반복을 선택하세요.";return result
			var key=definition.outputs.keys()[0];var batch=int(definition.outputs[key]);var current=amount(p,key)
			if current>=number:result.reason="목표 수량을 이미 보유하고 있습니다.";return result
			if current+ceili(float(number-current)/batch)*batch>Inventory.stack_limit(key):result.reason="묶음 제작 결과가 보관 상한을 넘습니다.";return result
		var row={"id":int(state.next_id),"recipe":request.recipe,"mode":request.mode,"remaining":int(number) if request.mode=="count" else 0,"target":int(number) if request.mode=="target" else 0,"reserved":false,"elapsed":0.}
		result.reason=reserve(staged,row,definition)
		if not result.reason.is_empty():return result
		state.next_id+=1;state.queue.append(row);result.title=definition.name+" 예약";result.gold=definition.gold;result.materials=definition.materials;result.outputs=definition.outputs
	elif operation in ["production_cancel","production_priority"]:
		if request.size()!=3 or not Inventory.whole_count(request.get("order"),2000000000):result.reason="작업을 선택하세요.";return result
		var index=-1
		for i in range(state.queue.size()):
			if state.queue[i].id==request.order:index=i;break
		if index<0:result.reason="이미 종료된 작업입니다.";return result
		var row=state.queue[index];var definition=definitions[row.recipe]
		if request.get("facility")!=definition.facility:result.reason="작업을 맡긴 시설에서 변경하세요.";return result
		if operation=="production_cancel":
			result.reason=refund(staged,row,definition)
			if not result.reason.is_empty():return result
			state.queue.remove_at(index);result.title=definition.name+" 취소 · 남은 예약 재료 환급"
		else:
			state.queue.remove_at(index);state.queue.push_front(row);result.title=definition.name+" 우선 제작"
	else:result.reason="제작 작업을 선택하세요.";return result
	result.player=staged;return result
static func commit(p:Dictionary,staged:Dictionary):
	for key in ["production","gold","materials","potions","consumables","bag_positions"]:p[key]=staged[key]
static func use(sim,p:Dictionary,request:Dictionary)->bool:
	if sim.map.zone!="town" or p.hp<=0 or p.get("network_leaving",false) or World.nearest(p.pos)!=request.get("facility",""):return false
	var result=stage(p,request)
	if not result.reason.is_empty():sim.notice(p.id,result.reason);return false
	commit(p,result.player);p["production_retry"]=0.;sim.dirty[p.id]=true;sim.notice(p.id,result.title);return true
static func waiting_reason(p:Dictionary,row:Dictionary)->String:
	var definition=recipes()[row.recipe];var probe=p.duplicate(true);var work=row.duplicate(true)
	if target_met(p,row,definition):return refund(probe,work,definition)
	if not row.reserved:return reserve(probe,work,definition)
	if row.elapsed>=definition.seconds:
		for key in definition.outputs:
			if not Inventory.add_stack(probe,key,definition.outputs[key]):return "완성품 보관 대기"
	return ""
static func tick(sim,delta:float):
	if delta<=0 or not is_finite(delta):return
	var definitions=recipes()
	for p in sim.players.values():
		if p.get("network_leaving",false) or p.get("production",{}).get("queue",[]).is_empty():continue
		p["production_retry"]=maxf(0.,float(p.get("production_retry",0.))-delta)
		if p.production_retry>0:continue
		var budget=delta;var iterations=0
		while budget>0 and not p.production.queue.is_empty() and iterations<128:
			iterations+=1
			var row=p.production.queue[0];var definition=definitions[row.recipe]
			if target_met(p,row,definition):
				var staged=p.duplicate(true);var reason=refund(staged,staged.production.queue[0],definition)
				if not reason.is_empty():p.production_retry=.5;break
				staged.production.queue.pop_front();commit(p,staged);sim.dirty[p.id]=true;continue
			if not row.reserved:
				var staged=p.duplicate(true);var reason=reserve(staged,staged.production.queue[0],definition)
				if not reason.is_empty():p.production_retry=.5;break
				commit(p,staged);sim.dirty[p.id]=true;row=p.production.queue[0]
			var spend=minf(budget,definition.seconds-float(row.elapsed));row.elapsed+=spend;budget-=spend
			if row.elapsed<definition.seconds:break
			var staged=p.duplicate(true);var fits=true
			for key in definition.outputs:
				if not Inventory.add_stack(staged,key,definition.outputs[key]):fits=false;break
			if not fits:p.production_retry=.5;break
			var work=staged.production.queue.pop_front();work.reserved=false;work.elapsed=0.
			if work.mode=="count":work.remaining-=1
			if (work.mode=="count" and work.remaining>0) or work.mode=="repeat" or (work.mode=="target" and not target_met(staged,work,definition)):staged.production.queue.append(work)
			commit(p,staged);sim.dirty[p.id]=true
			var action={"facility":definition.facility,"operation":"research_craft","research":definition.research} if not definition.research.is_empty() else {"facility":definition.facility,"operation":row.recipe.get_slice(":",1)}
			preload("res://scripts/expedition_goals.gd").service_completed(p,action)
			sim.notice(p.id,definition.name+" 제작 완료")
static func configuration()->Dictionary:
	return {"recipes":recipes(),"maximum_queue":MAX_QUEUE,"modes":MODES,"reserve":"one_batch_per_order; later_batches_on_start","clock":"connected_session_including_menus_not_offline","delivery":"atomic_all_outputs; wait_on_full_bag","cancel":"refund_undelivered_batch_atomically","scheduler":"round_robin_after_each_completed_batch; manual_priority","scope":"personal_character; authority_only"}
