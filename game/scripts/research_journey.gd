extends RefCounted
const Research=preload("res://scripts/town_research.gd")
const Abyss=preload("res://scripts/abyss_catalog.gd")
const Content=preload("res://scripts/content.gd")
const Quote=preload("res://scripts/service_quote.gd")

static func valid(data:Dictionary)->bool:
	if not Research.DEFINITIONS.has(data.item):return false
	var definition=Research.DEFINITIONS[data.item]
	if data.requirements.size()!=definition.cost.size():return false
	for material in definition.cost:
		if not data.requirements.has(material) or int(data.requirements[material])!=int(definition.cost[material]):return false
	return data.facility==definition.facility and data.operation=="research_craft" and int(data.stage) in [0,3] and data.material in definition.cost and data.target==int(definition.cost[data.material]) and int(data.floor)%10!=0

static func eligible(p:Dictionary,key:String)->bool:
	if not Research.DEFINITIONS.has(key):return false
	var definition=Research.DEFINITIONS[key];var state=p.get("town_research",Research.empty())
	return definition.parent.is_empty() or definition.parent in state.completed or state.queue.any(func(row):return row.id==definition.parent)

static func requirements(p:Dictionary,key:String)->Dictionary:
	var definition=Research.DEFINITIONS[key]
	return definition.recipe if Research.completed(p,key) else definition.cost

static func destination(p:Dictionary,material:String,preferred:int)->int:
	var found=0;var distance=101
	for depth in range(1,mini(100,int(p.highest_floor))+1):
		if depth%10==0:continue
		var forest=Abyss.config(depth).terrain=="forest"
		if material=="seed" and not forest or material=="ore" and forest:continue
		if absi(depth-preferred)<distance:found=depth;distance=absi(depth-preferred)
	return found

static func need(p:Dictionary,key:String,preferred:int)->Dictionary:
	var cost=requirements(p,key);var selected=""
	for material in cost:
		if int(p.materials.get(material,0))<int(cost[material]):selected=material;break
	if selected.is_empty():return {"material":"","target":0,"floor":maxi(1,preferred),"refine":false}
	var depth=destination(p,selected,preferred);var amount=int(cost[selected]);var refine=false
	if selected=="ore" and depth==0:
		var quote=Quote.quote(p,"alchemy","ore")
		var batches=ceili(float(amount-int(p.materials.get("ore",0)))/float(quote.outputs.ore))
		amount=int(cost.get("seed",0))+batches*int(quote.materials.seed)
		selected="seed";depth=destination(p,"seed",preferred);refine=true
	return {"material":selected,"target":amount,"floor":maxi(1,depth),"refine":refine}

static func offer(p:Dictionary,key:String,preferred:int)->Dictionary:
	if not eligible(p,key):return {}
	var definition=Research.DEFINITIONS[key];var shortage=need(p,key,preferred)
	var depth=shortage.floor
	if depth%10==0:depth-=1
	var material=definition.cost.keys()[0]
	var data={"kind":"research","floor":depth,"material":material,"target":int(definition.cost[material]),"facility":definition.facility,"operation":"research_craft","item":key,"stage":0,"requirements":definition.cost.duplicate(true)}
	var summary=describe(p,data)
	return {"id":"research:"+key,"goal":data,"title":definition.output+" 준비","detail":summary.detail,"clue":"씨앗 채집 → 광석 정제 → "+definition.output if shortage.refine else "씨앗이 떨어진 곁굴을 찾으세요." if shortage.material=="seed" else "광석 조각이 이어지는 곁굴을 찾으세요." if shortage.material=="ore" else "제단과 정예 은닉품에서 정수를 찾으세요." if shortage.material=="essence" else "모은 재료로 연구와 제작을 이어가세요.","icon":definition.icon}

static func recommendation(p:Dictionary,preferred:int)->Dictionary:
	var active=p.get("expedition_goal",{})
	if active.get("kind","")=="research" and int(active.stage)<3:return offer(p,active.item,preferred)
	var state=p.get("town_research",Research.empty())
	for key in Research.DEFINITIONS:
		if key not in state.completed and eligible(p,key) and not state.queue.any(func(row):return row.id==key):return offer(p,key,preferred)
	return {}

static func work_status(p:Dictionary,data:Dictionary)->Dictionary:
	var key=data.item;var state=p.get("town_research",Research.empty())
	if int(data.stage)==3:return {"ready":false,"reason":"제작 완료 · 다음 탐사를 선택하세요.","cost":0,"facility":"portal","operation":""}
	if state.queue.any(func(row):return row.id==key):return {"ready":false,"reason":"연구 진행 중 · 완료 후 제작","cost":0,"facility":data.facility,"operation":""}
	var operation="research_craft" if Research.completed(p,key) else "research_start"
	var shortage=need(p,key,int(data.floor))
	if shortage.refine and int(p.materials.get("seed",0))>=int(shortage.target):
		var quote=Quote.quote(p,"alchemy","ore")
		return {"ready":quote.reason.is_empty(),"reason":quote.reason,"cost":int(quote.cost),"facility":"alchemy","operation":"ore"}
	var quote=Research.stage(p,key,operation)
	return {"ready":quote.reason.is_empty(),"reason":quote.reason,"cost":int(quote.gold),"facility":data.facility,"operation":operation}

static func describe(p:Dictionary,data:Dictionary)->Dictionary:
	var definition=Research.DEFINITIONS[data.item];var state=p.get("town_research",Research.empty());var work=work_status(p,data)
	var detail="";var ready=work.ready;var shortage=need(p,data.item,int(data.floor))
	if int(data.stage)==3:detail="제작 완료 → B%d 다음 도전"%int(p.highest_floor);ready=true
	elif state.queue.any(func(row):return row.id==data.item):detail="연구 진행 중 → "+definition.output
	elif work.operation=="ore":detail="광석 정제 → "+definition.output
	elif not shortage.material.is_empty():detail="%s %d / %d%s"%[Content.MATERIALS[shortage.material],int(p.materials.get(shortage.material,0)),shortage.target," · 광석 정제용" if shortage.refine else ""]
	elif ready:detail="제작하기 · "+definition.output if Research.completed(p,data.item) else "연구 시작 · "+definition.name
	else:detail=work.reason
	return {"title":definition.output+" 준비","detail":detail,"ready":ready,"floor":int(p.highest_floor) if int(data.stage)==3 else int(shortage.floor),"icon":definition.icon,"facility":work.facility}

static func configuration()->Dictionary:
	return {"scope":"personal_research_to_first_craft_to_next_expedition","selection":"host_recomputes_current_research_offer","costs":"live_research_or_unlocked_recipe","early_ore":"gather_seed_then_existing_refinement_without_losing_research_target","completion":"successful_matching_research_craft_only","next_step":"explicit_next_expedition_selection_no_forced_travel"}
