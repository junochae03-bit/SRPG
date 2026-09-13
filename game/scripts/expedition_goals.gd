extends RefCounted
const Abyss=preload("res://scripts/abyss_catalog.gd")
const Inventory=preload("res://scripts/inventory_model.gd")
const Content=preload("res://scripts/content.gd")
const Quote=preload("res://scripts/service_quote.gd")
const Journey=preload("res://scripts/research_journey.gd")
const KINDS=["materials","secret","challenge","advance","research"]
const DEFINITIONS={
	"secret":{"title":"지도 조각 · 숨은 보관실","clue":"바람이 새는 벽 틈에 숨은 공간이 있습니다.","icon":"codex","source":"길드 지도","steps":["바람이 새는 벽 틈 찾기","발견한 벽 틈 열기","보관실 보상 회수","보관실 탐사 완료"]},
	"challenge":{"title":"탐사자의 소문 · 정예 은닉품","clue":"큰 발자국이 이어지는 곁굴에 은닉품이 있습니다.","icon":"boss","source":"탐사자의 소문","steps":["큰 발자국을 따라 곁굴 찾기","은닉품의 보상 선택","추가 적 처치 · 정수 회수","은닉품 탐사 완료"]}
}
const FIELDS=["kind","floor","material","target","facility","operation","item","stage","requirements"]

static func configuration()->Dictionary:
	return {"kinds":KINDS,"definitions":DEFINITIONS,"saved_fields":FIELDS,"selection":"personal_authority_validated_in_town","persistence":"optional_save_v7_expedition_goal","rumors":"public_biome_clues_without_coordinates","discovery":"party_shared_geometry_personal_reward_completion","material_cost":"live_service_quote","progress":"inventory_readiness_or_authoritative_site_completion"}

static func valid(value)->bool:
	if not value is Dictionary:return false
	if value.is_empty():return true
	if value.size()!=FIELDS.size():return false
	for key in FIELDS:
		if not value.has(key):return false
	for key in ["floor","target","stage"]:
		if (not value[key] is int and not value[key] is float) or not is_finite(float(value[key])) or value[key]!=floor(value[key]):return false
	if value.kind not in KINDS or value.floor<1 or value.floor>100 or value.target<1 or value.target>999999 or value.stage<0 or value.stage>3:return false
	if value.material not in ["","seed","ore","essence"] or value.facility not in ["portal","smith","alchemy","inn"] or value.operation not in ["","upgrade","potion","ore","essence","research_craft"]:return false
	if not value.item is String or value.item.length()>128:return false
	if not value.requirements is Dictionary:return false
	for material in value.requirements:
		var amount=value.requirements[material]
		if material not in ["seed","ore","essence"] or (not amount is int and not amount is float) or not is_finite(float(amount)) or amount!=floor(amount) or amount<1 or amount>999999:return false
	if value.kind=="research":return Journey.valid(value)
	if value.kind=="materials":
		if int(value.stage) not in [0,3] or value.requirements.get(value.material,0)!=value.target:return false
		if value.facility=="smith":return value.operation=="upgrade" and value.item!="" and value.material=="ore" and value.requirements.size()==1 and value.target<=5
		if value.facility!="alchemy" or value.item!="":return false
		if value.operation in ["potion","ore"]:return value.material=="seed" and value.requirements.size()==1
		return value.operation=="essence" and value.material in ["seed","ore"] and value.requirements.size()==2 and value.requirements.has("seed") and value.requirements.has("ore")
	if value.kind=="advance" and value.stage!=0:return false
	return value.requirements.is_empty() and value.material=="" and value.facility=="portal" and value.operation=="" and value.item=="" and value.target==1 and (value.kind=="advance" or int(value.floor)%10!=0)

static func restore(value)->Dictionary:
	if not valid(value) or value.is_empty():return {}
	var data=value.duplicate(true)
	for key in ["floor","target","stage"]:data[key]=int(data[key])
	for key in data.requirements:data.requirements[key]=int(data.requirements[key])
	return data

static func goal(kind:String,depth:int)->Dictionary:
	return {"kind":kind,"floor":depth,"material":"","target":1,"facility":"portal","operation":"","item":"","stage":0,"requirements":{}}

static func material_floor(p:Dictionary,material:String,preferred:int)->int:
	var found=0;var distance=101
	for depth in range(1,mini(100,int(p.highest_floor))+1):
		if depth%10==0:continue
		var terrain=Abyss.config(depth).terrain
		if material=="seed" and terrain!="forest":continue
		if material=="ore" and terrain=="forest":continue
		if absi(depth-preferred)<distance:found=depth;distance=absi(depth-preferred)
	return found

static func material_offer(p:Dictionary,preferred:int)->Dictionary:
	var candidates=[];var weapon=Inventory.find_item(p,str(p.get("equipment",{}).get("weapon","")))
	if not weapon.is_empty() and int(weapon.get("upgrade",0))<5:candidates.append({"facility":"smith","operation":"upgrade","item":weapon.id})
	if int(p.potions)<5:candidates.append({"facility":"alchemy","operation":"potion","item":""})
	candidates.append({"facility":"alchemy","operation":"essence","item":""})
	for task in candidates:
		var quote=Quote.quote(p,task.facility,task.operation,{"item":task.item})
		for material in quote.materials:
			var required=int(quote.materials[material])
			if int(p.materials.get(material,0))>=required:continue
			var depth=material_floor(p,material,preferred)
			# Early forest characters can refine ore from seeds without needing
			# an inaccessible B11 destination or a made-up direct ore reward.
			if depth==0 and material=="ore":
				task={"facility":"alchemy","operation":"ore","item":""}
				quote=Quote.quote(p,"alchemy","ore");material="seed";required=int(quote.materials.seed);depth=material_floor(p,material,preferred)
			if depth==0 or int(p.materials.get(material,0))>=required:continue
			var data=goal("materials",depth)
			data.merge({"material":material,"target":required,"facility":task.facility,"operation":task.operation,"item":task.item,"requirements":quote.materials.duplicate(true)},true)
			return {"id":"materials","goal":data,"title":quote.title+" 재료","detail":"%s %d / %d · B%d"%[Content.MATERIALS[material],int(p.materials.get(material,0)),required,depth],"clue":"떨어진 씨앗을 따라가세요." if material=="seed" else "광석 조각이 이어지는 곁굴을 찾으세요." if material=="ore" else "마력이 흐르는 제단과 정예의 은닉품을 찾으세요.","icon":material}
	return {}

static func offers(p:Dictionary,preferred:int)->Array:
	var result=[];var depth=clampi(preferred,1,mini(100,int(p.highest_floor)))
	if depth%10==0:depth-=1
	var research=Journey.recommendation(p,depth)
	if not research.is_empty():result.append(research)
	var material=material_offer(p,depth)
	if not material.is_empty():result.append(material)
	result.append({"id":"secret","goal":goal("secret",depth),"title":DEFINITIONS.secret.title,"detail":"B%d · 정수와 금화"%depth,"clue":DEFINITIONS.secret.clue,"icon":DEFINITIONS.secret.icon})
	result.append({"id":"challenge","goal":goal("challenge",depth),"title":DEFINITIONS.challenge.title,"detail":"B%d · 선택 전투와 정수"%depth,"clue":DEFINITIONS.challenge.clue,"icon":DEFINITIONS.challenge.icon})
	var next=mini(100,int(p.highest_floor))
	if int(p.cleared_floor)<100:result.append({"id":"advance","goal":goal("advance",next),"title":"B%d 돌파"%next,"detail":"100층을 향한 다음 기록","clue":Abyss.config(next).title if next%10==0 else "수문장을 처치하면 다음 층이 열립니다.","icon":"floor"})
	return result

static func select(sim,p:Dictionary,argument:String)->bool:
	if sim.map.zone!="town" or p.hp<=0 or argument.length()>128:return false
	var request=JSON.parse_string(argument)
	if not request is Dictionary or request.size()!=2 or not request.get("id") is String:return false
	var depth=request.get("floor")
	if (not depth is int and not depth is float) or not is_finite(float(depth)) or depth!=floor(depth) or depth<1 or depth>p.highest_floor:return false
	if request.id=="clear":
		if p.get("expedition_goal",{}).is_empty():return false
		p.expedition_goal={};sim.dirty[p.id]=true;return true
	var available=offers(p,int(depth))
	if request.id.begins_with("research:"):
		var research=Journey.offer(p,request.id.trim_prefix("research:"),int(depth))
		if not research.is_empty():available.append(research)
	for offer in available:
		if offer.id!=request.id:continue
		var current=p.get("expedition_goal",{})
		if not current.is_empty() and FIELDS.filter(func(key):return key!="stage").all(func(key):return current[key]==offer.goal[key]):return false
		p["expedition_goal"]=offer.goal.duplicate(true);sim.dirty[p.id]=true;sim.notice(p.id,offer.title+" · 목표 등록");return true
	return false

static func progress(sim,p:Dictionary,kind:String,stage:int):
	var data=p.get("expedition_goal",{})
	if data.is_empty() or data.kind!=kind or int(data.floor)!=sim.map.floor_number:return
	if stage>int(data.stage):data.stage=stage;sim.dirty[p.id]=true

static func observe(sim):
	if sim.map.floor_number<=0:return
	for p in sim.players.values():
		var data=p.get("expedition_goal",{})
		if data.is_empty() or p.get("network_leaving",false) or int(data.floor)!=sim.map.floor_number:continue
		if data.kind=="secret":
			if not sim.map.revealed_regions.is_empty():progress(sim,p,"secret",1)
			if not sim.map.opened_regions.is_empty():progress(sim,p,"secret",2)
			if sim.exploration_claims.get(p.id,{}).keys().any(func(key):return str(key).begins_with("hidden_")):progress(sim,p,"secret",3)
		elif data.kind=="challenge":
			for site in sim.map.exploration_sites:
				if site.kind!="challenge":continue
				if p.pos.distance_to(site.pos)<4. and sim.map.line_clear(p.pos,site.pos):progress(sim,p,"challenge",1)
				if sim.exploration_challenges.has(site.id):progress(sim,p,"challenge",2)
				if sim.exploration_claims.get(p.id,{}).has(site.id):progress(sim,p,"challenge",3)

static func service_completed(p:Dictionary,request:Dictionary):
	var data=p.get("expedition_goal",{})
	if data.is_empty():return
	if data.kind=="research":
		if request.get("facility","")==data.facility and request.get("operation","")=="research_craft" and request.get("research","")==data.item:data.stage=3
		return
	if data.kind!="materials":return
	if request.get("facility","")==data.facility and request.get("operation","")==data.operation and (data.item=="" or request.get("item","")==data.item):data.stage=3

static func reset_map_progress(p:Dictionary):
	var data=p.get("expedition_goal",{})
	if not data.is_empty() and data.kind in ["secret","challenge"] and int(data.stage) in [1,2]:data.stage=0

static func work_status(p:Dictionary)->Dictionary:
	var data=p.get("expedition_goal",{})
	if not data.is_empty() and data.kind=="research":return Journey.work_status(p,data)
	if data.is_empty() or data.kind!="materials":return {"ready":false,"reason":"작업 목표가 없습니다."}
	if int(data.stage)==3:return {"ready":false,"reason":"이미 완료한 작업입니다."}
	var quote=Quote.quote(p,data.facility,data.operation,{"item":data.item})
	return {"ready":quote.reason.is_empty(),"reason":quote.reason,"cost":int(quote.cost)}

static func describe(p:Dictionary)->Dictionary:
	var data=p.get("expedition_goal",{})
	if data.is_empty():return {}
	if data.kind=="research":return Journey.describe(p,data)
	var ready=false;var detail="";var title="";var icon="quest"
	match data.kind:
		"materials":
			ready=data.requirements.keys().all(func(key):return int(p.materials.get(key,0))>=int(data.requirements[key]));icon=data.material
			title={"upgrade":"강화 재료","potion":"물약 조제 재료","ore":"광석 정제 재료","essence":"정수 합성 재료"}[data.operation]
			detail="%s %d / %d"%[Content.MATERIALS[data.material],int(p.materials.get(data.material,0)),int(data.target)]
			if not ready and int(p.materials.get(data.material,0))>=int(data.target):
				for key in data.requirements:
					if int(p.materials.get(key,0))<int(data.requirements[key]):detail="추가 재료 · %s %d / %d"%[Content.MATERIALS[key],int(p.materials.get(key,0)),int(data.requirements[key])];break
			if data.operation=="upgrade" and Inventory.find_item(p,data.item).is_empty():ready=false;detail="대상 장비가 없습니다. 목표를 다시 선택하세요."
			if int(data.stage)==3:ready=true;detail="재료를 사용해 작업을 완료했습니다."
		"secret":
			title="지도 조각 · 보관실";icon="codex";ready=int(data.stage)>=3
			detail=DEFINITIONS.secret.steps[int(data.stage)]
		"challenge":
			title="소문 · 정예 은닉품";icon="boss";ready=int(data.stage)>=3
			detail=DEFINITIONS.challenge.steps[int(data.stage)]
		"advance":
			title="B%d 돌파"%data.floor;icon="floor";ready=int(p.cleared_floor)>=int(data.floor)
			detail="돌파 완료" if ready else "수문장 처치 · 다음 층 개방"
	return {"title":title,"detail":detail,"ready":ready,"floor":int(data.floor),"icon":icon,"facility":data.facility}
