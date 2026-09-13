extends RefCounted
const World=preload("res://scripts/world_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const MAX_REPUTATION=1000000
const RANKS=[{"name":"견습","required":0},{"name":"정예","required":50},{"name":"선봉","required":150}]
const CONTRACTS={
	"hunt":{"name":"지역 토벌","rank":0,"target":10,"gold":180,"reputation":25,"essence":1,"icon":"quest"},
	"elite":{"name":"정예 사냥","rank":1,"target":3,"gold":320,"reputation":50,"essence":2,"icon":"boss"},
	"guardian":{"name":"수문장 토벌","rank":2,"target":1,"gold":500,"reputation":75,"essence":3,"icon":"boss"}
}
const SERVICES={
	"field_supply":{"name":"길드 탐사 보급","rank":1,"gold":40,"materials":{"seed":2,"ore":2},"outputs":{"potion":3,"tool":2},"icon":"bag"},
	"raid_supply":{"name":"길드 공략 보급","rank":2,"gold":80,"materials":{"seed":5,"ore":3},"outputs":{"mana_potion":2,"power_potion":2,"fire_bottle":2},"icon":"boss"}
}
static func valid_reputation(value)->bool:return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=0 and value<=MAX_REPUTATION
static func rank(p:Dictionary)->int:
	var result=0
	for index in range(RANKS.size()):
		if int(p.get("guild_reputation",0))>=RANKS[index].required:result=index
	return result
static func valid_contract(value)->bool:
	if not value is Dictionary:return false
	if value.is_empty():return true
	if value.size() not in [3,4] or value.get("zone","") not in World.DUNGEONS:return false
	var kind=value.get("kind","hunt")
	if not kind is String or not CONTRACTS.has(kind):return false
	if value.size()==4 and not value.has("kind"):return false
	for key in ["progress","target"]:
		var amount=value.get(key)
		if not (amount is int or amount is float) or not is_finite(float(amount)) or amount!=floor(amount) or amount<0:return false
	return value.target==CONTRACTS[kind].target and value.progress<=value.target
static func definition(p:Dictionary)->Dictionary:return CONTRACTS[p.get("guild_contract",{}).get("kind","hunt")]
static func benefits(tier:int)->String:
	var names=[]
	for row in CONTRACTS.values():
		if row.rank==tier:names.append(row.name)
	for row in SERVICES.values():
		if row.rank==tier:names.append(row.name)
	return " / ".join(names)
static func handles(operation:String)->bool:return operation in ["accept","claim"] or SERVICES.has(operation)
static func quote(p:Dictionary,operation:String,extra:Dictionary={})->Dictionary:
	return stage(p,operation,extra).quote
static func stage(p:Dictionary,operation:String,extra:Dictionary={})->Dictionary:
	var q={"title":"길드 업무","cost":0,"materials":{},"outputs":{},"result":"","reason":"","icon":"guild","item":{},"operation":operation,"extra":extra.duplicate(true)}
	var outcome={"quote":q,"player":{}};var staged=p.duplicate(true)
	if operation=="accept":
		var kind=extra.get("contract_kind","hunt");var zone=extra.get("zone","forest")
		if not kind is String or not CONTRACTS.has(kind) or not zone is String or not World.DUNGEONS.has(zone):q.reason="의뢰와 지역을 선택하세요.";return outcome
		var contract=CONTRACTS[kind];q.title=World.DUNGEONS[zone].name+" · "+contract.name;q.icon=contract.icon
		q.result="목표 %d회\n보상 선택 · %d G 또는 평판 %d\n공통 보상 · 정수 %d"%[contract.target,contract.gold,contract.reputation,contract.essence]
		if not p.guild_contract.is_empty():q.reason="진행 중인 의뢰를 먼저 완료하세요.";return outcome
		if rank(p)<contract.rank:q.reason=RANKS[contract.rank].name+" 등급부터 수락할 수 있습니다.";return outcome
		staged.guild_contract={"zone":zone,"progress":0,"target":contract.target}
		if kind!="hunt":staged.guild_contract["kind"]=kind
	elif operation=="claim":
		q.title="의뢰 보상"
		if p.guild_contract.is_empty() or p.guild_contract.progress<p.guild_contract.target:q.reason="토벌 목표를 먼저 완료하세요.";return outcome
		var reward=extra.get("reward","gold")
		if reward not in ["gold","reputation"]:q.reason="금화 또는 평판을 선택하세요.";return outcome
		var contract=definition(p);q.outputs={"essence":contract.essence};q.cost=-contract.gold if reward=="gold" else 0
		var before=int(p.get("guild_reputation",0));var after=mini(MAX_REPUTATION,before+contract.reputation) if reward=="reputation" else before
		if reward=="reputation" and after==before:q.reason="평판 상한입니다. 금화 보상을 선택하세요.";return outcome
		staged["guild_reputation"]=after;staged.guild_contract={}
		q.result=("금화 +%d G"%contract.gold if reward=="gold" else "길드 평판 %d → %d"%[before,after])+"\n정수 +%d"%contract.essence
		if reward=="reputation":
			if rank(staged)>rank(p):q.result+="\n"+RANKS[rank(staged)].name+" 등급 개방\n"+benefits(rank(staged))
			elif rank(staged)<RANKS.size()-1:
				var next=rank(staged)+1
				q.result+="\n%s까지 평판 %d\n해금 · %s"%[RANKS[next].name,RANKS[next].required-after,benefits(next)]
	elif SERVICES.has(operation):
		var service=SERVICES[operation];q.title=service.name;q.cost=service.gold;q.materials=service.materials;q.outputs=service.outputs;q.icon=service.icon
		if rank(p)<service.rank:q.reason=RANKS[service.rank].name+" 등급에서 해금됩니다.";return outcome
		for key in q.outputs:q.result+=("\n" if not q.result.is_empty() else "")+preload("res://scripts/town_operations.gd").LABELS[key]+" +%d"%q.outputs[key]
	else:q.reason="길드 업무를 선택하세요.";return outcome
	if staged.gold<q.cost:q.reason="금화 %d G 부족"%(q.cost-staged.gold);return outcome
	staged.gold-=q.cost
	for key in q.materials:
		if int(staged.materials.get(key,0))<int(q.materials[key]):q.reason=preload("res://scripts/content.gd").MATERIALS[key]+" 부족";return outcome
		staged.materials[key]-=q.materials[key]
	Inventory.initialize(staged)
	for key in q.outputs:
		if not Inventory.add_stack(staged,key,int(q.outputs[key])):q.reason=Inventory.stack_failure_reason(staged,key,int(q.outputs[key]));return outcome
	outcome.player=staged;return outcome
static func use(sim,p:Dictionary,request:Dictionary)->bool:
	if sim.map.zone!="town" or p.hp<=0 or p.get("network_leaving",false) or World.nearest(p.pos)!="guild":return false
	var result=stage(p,str(request.get("operation","")),request)
	if not result.quote.reason.is_empty():sim.notice(p.id,result.quote.reason);return false
	for field in ["guild_contract","guild_reputation","gold","materials","potions","consumables","bag_positions"]:p[field]=result.player.get(field,0 if field=="guild_reputation" else {})
	sim.dirty[p.id]=true;sim.notice(p.id,result.quote.title+" · 완료");return true
static func progress(p:Dictionary,zone:String,enemy:Dictionary):
	var contract=p.get("guild_contract",{})
	if contract.is_empty() or contract.zone!=zone:return
	var kind=contract.get("kind","hunt")
	if kind=="elite" and not enemy.get("elite",false):return
	if kind=="guardian" and not enemy.get("guardian",false):return
	contract.progress=mini(contract.target,int(contract.progress)+1)
static func configuration()->Dictionary:
	return {"ranks":RANKS,"contracts":CONTRACTS,"services":SERVICES,"maximum_reputation":MAX_REPUTATION,"ownership":"personal_character","reward":"gold_or_reputation_with_shared_material_reward","legacy":"missing_reputation_zero_and_three_field_hunt_contract","progress":"existing_authoritative_kill_recipients_and_matching_enemy_role","offline":"no_decay"}
