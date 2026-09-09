extends RefCounted
# Pure rules: initialized by Content after loading its existing catalog. Never
# import Content here: combat profiles and save/UI callers share this module.
const Catalog=preload("res://scripts/constellation_catalog.gd")
const BUILD_VERSION=2
const MAX_KEYSTONES=2
static var _classes:Dictionary={}
static var _nodes:Dictionary={}
static var _lookup:Dictionary={}

static func initialize(skills:Dictionary,classes:Dictionary):
	_classes=classes.duplicate(true);_nodes.clear();_lookup.clear()
	for class_id in classes:
		var list=[]
		for original in skills[class_id]:
			var n=original.duplicate(true)
			n.merge({"class_id":class_id,"family":classes[class_id].get("base",class_id),"type":"original","allocation_field":"skill_ranks","cost":1,"max_rank":int(n.get("max_rank",3)),"cluster":clampi(int(n.get("tier",0)),0,4),"tags":["원기술",str(n.effect)],"synergy":"","tradeoff":"","effects_text":"","effects":{},"exclusive_group":"","icon_node":original.duplicate(true)},true)
			list.append(n)
		list.append_array(Catalog.nodes_for(class_id,classes[class_id],skills[class_id]))
		_nodes[class_id]=list
		for n in list:_lookup[n.id]=n

static func nodes_for(class_id:String)->Array:return _nodes.get(class_id,[])
static func definition(id:String)->Dictionary:return _lookup.get(id,{})
static func effect_label(key:String)->String:return Catalog.effect_label(key)
static func constellation_nodes(class_id:String)->Array:return nodes_for(class_id).filter(func(n):return n.type!="original")
static func rank(p:Dictionary,n:Dictionary)->int:return int(p.get(n.get("allocation_field","skill_ranks"),{}).get(n.get("id",""),0))
static func spent_points(p:Dictionary)->int:
	var spent=0
	for value in p.get("skill_ranks",{}).values():spent+=int(value)
	for id in p.get("constellation_allocations",{}):spent+=int(p.constellation_allocations[id])*int(definition(str(id)).get("cost",0))
	return spent
static func available_points(p:Dictionary)->int:return maxi(0,int(p.get("level",1))-1-spent_points(p))
static func _parents_met(p:Dictionary,n:Dictionary)->bool:
	if n.get("parents",[]).is_empty():return true
	var required=int(n.get("required_rank",1));var count=0
	for parent in n.parents:
		var entry=definition(parent)
		if not entry.is_empty() and rank(p,entry)>=required:count+=1
	return count==n.parents.size() if n.get("parent_mode","any")=="all" else count>0
static func _key_count(p:Dictionary)->int:
	var total=0
	for n in constellation_nodes(p.get("class_id","warrior")):
		if n.type=="keystone" and rank(p,n)>0:total+=1
	return total
static func _conflicts(p:Dictionary,n:Dictionary)->Array:
	var result=[];var group=str(n.get("exclusive_group",""))
	for other in nodes_for(p.get("class_id","warrior")):
		if other.id==n.id or rank(p,other)<=0:continue
		if (not group.is_empty() and other.get("exclusive_group","")==group) or n.get("exclusive_with",[]).has(other.id) or other.get("exclusive_with",[]).has(n.id):result.append(other.id)
	return result

static func node_state(p:Dictionary,id:String)->Dictionary:
	var n=definition(id);var reason="";var current=0;var cost=0;var locked=[]
	if n.is_empty() or n.class_id!=p.get("class_id","warrior"):reason="현재 직업의 별자리가 아닙니다."
	else:
		current=rank(p,n);cost=n.cost
		if current>=n.max_rank:reason="최대 투자 상태입니다."
		elif int(p.get("level",1))<int(n.get("level",1)):reason="LV.%d 필요"%int(n.level)
		elif not _parents_met(p,n):
			reason="선행 %s 필요 · 요구 랭크 %d"%["모두" if n.get("parent_mode","any")=="all" else "하나",int(n.get("required_rank",1))]
			for parent in n.get("parents",[]):
				if rank(p,definition(parent))<int(n.get("required_rank",1)):locked.append(parent)
		elif not _conflicts(p,n).is_empty():locked=_conflicts(p,n);reason="배타 선택: "+definition(locked[0]).name+" 해제 필요"
		elif n.type=="keystone" and current==0 and _key_count(p)>=MAX_KEYSTONES:reason="핵심 별자리는 최대 2개까지 선택할 수 있습니다."
		elif available_points(p)<cost:reason="스킬 포인트 %d 필요 · 남은 포인트 %d"%[cost,available_points(p)]
	return {"node":n,"rank":current,"max_rank":int(n.get("max_rank",0)),"cost":cost,"available":available_points(p),"can_invest":reason.is_empty(),"can_remove":current>0,"reason":reason,"locked_by":locked,"selected":current>0}

static func validate_build(p:Dictionary)->Dictionary:
	var errors=[];var class_id=p.get("class_id","warrior")
	if not _classes.has(class_id):return {"ok":false,"reason":"알 수 없는 직업입니다.","errors":["class_id"]}
	var level=p.get("level",1)
	if (not level is int and not level is float) or level!=floor(level) or level<1 or level>100:return {"ok":false,"reason":"잘못된 레벨입니다.","errors":["level"]}
	for field in ["skill_ranks","constellation_allocations"]:
		if not p.get(field,{}) is Dictionary:return {"ok":false,"reason":field+": Dictionary 필요","errors":[field]}
		for id in p.get(field,{}):
			var amount=p[field][id]
			if not id is String or (not amount is int and not amount is float):return {"ok":false,"reason":field+": 잘못된 ID·랭크 형식","errors":[field]}
	for field in ["skill_ranks","constellation_allocations"]:
		for id in p.get(field,{}):
			var n=definition(str(id));var value=p[field][id]
			if not id is String or n.is_empty() or n.class_id!=class_id or n.allocation_field!=field:errors.append(str(id)+": 잘못된 노드");continue
			if (not value is int and not value is float) or value<0 or value!=floor(value) or value>n.max_rank:errors.append(id+": 잘못된 랭크");continue
			if value<=0:continue
			if int(p.get("level",1))<int(n.get("level",1)):errors.append(id+": 해금 레벨 부족")
			# Existing ranks retain the V0.3 validation contract: prerequisite
			# enforcement on save applied to upgrades, not old ordinary nodes.
			if (n.type!="original" or n.effect=="upgrade") and not _parents_met(p,n):errors.append(id+": 선행 조건 부족")
			if not _conflicts(p,n).is_empty():errors.append(id+": 배타 선택 충돌")
	if errors.is_empty():
		if spent_points(p)>int(p.get("level",1))-1:errors.append("스킬 포인트 예산 초과")
		if _key_count(p)>MAX_KEYSTONES:errors.append("핵심 별자리 2개 초과")
	return {"ok":errors.is_empty(),"reason":"" if errors.is_empty() else errors[0],"errors":errors}

static func effects(p:Dictionary)->Dictionary:
	var result={}
	for n in constellation_nodes(p.get("class_id","warrior")):
		var amount=rank(p,n)
		if amount<=0:continue
		for key in n.effects:result[key]=float(result.get(key,0))+float(n.effects[key])*amount
	return result

static func preview(p:Dictionary,id:String,next_rank:int)->Dictionary:
	var current=node_state(p,id);var n=current.node;var candidate=p.duplicate(true);var removed=[];var added=[];var reason=""
	if n.is_empty() or n.get("class_id","")!=p.get("class_id","warrior"):reason="현재 직업의 별자리가 아닙니다."
	elif next_rank<0 or next_rank>n.max_rank or abs(next_rank-current.rank)>1:reason="한 번에 한 랭크씩 변경하세요."
	elif next_rank>current.rank and not current.can_invest:reason=current.reason
	if reason.is_empty():
		if not candidate.has(n.allocation_field):candidate[n.allocation_field]={}
		if next_rank==0:candidate[n.allocation_field].erase(id)
		else:candidate[n.allocation_field][id]=next_rank
		if next_rank>current.rank:added.append(id)
		elif next_rank<current.rank:
			removed.append(id)
			var changed=true
			while changed:
				changed=false
				for other in nodes_for(p.get("class_id","warrior")):
					if rank(candidate,other)<=0 or _parents_met(candidate,other):continue
					if other.type=="original" and other.effect!="upgrade" and not _parents_met(p,other):continue
					candidate[other.allocation_field].erase(other.id);removed.append(other.id);changed=true
		var valid=validate_build(candidate)
		if not valid.ok:reason=valid.reason
	var difference=spent_points(candidate)-spent_points(p) if reason.is_empty() else 0
	var after_player=candidate if reason.is_empty() else p.duplicate(true)
	return {"ok":reason.is_empty(),"reason":reason,"player":after_player,"before_player":p.duplicate(true),"after_player":after_player,"before":effects(p),"after":effects(after_player),"added":added if reason.is_empty() else [],"removed":removed if reason.is_empty() else [],"refund":maxi(0,-difference),"cost":maxi(0,difference),"total":spent_points(after_player),"available":available_points(after_player)}

static func path_plan(p:Dictionary,id:String)->Dictionary:
	var candidate=p.duplicate(true);var plan=_plan(candidate,id,1,[])
	var cost=spent_points(candidate)-spent_points(p) if plan.ok else 0
	if plan.ok and cost>available_points(p):plan.ok=false;plan.reason="경로에 %dSP 필요 · 남은 포인트 %d"%[cost,available_points(p)]
	return {"ok":plan.ok,"reason":plan.reason,"steps":plan.get("steps",[]),"cost":cost,"available":available_points(p),"conflicts":plan.get("conflicts",[]),"player":candidate if plan.ok else p.duplicate(true)}

static func _plan(p:Dictionary,id:String,needed:int,visiting:Array)->Dictionary:
	var n=definition(id)
	if n.is_empty() or n.class_id!=p.get("class_id","warrior"):return {"ok":false,"reason":"다른 직업의 경로입니다.","steps":[]}
	if rank(p,n)>=needed:return {"ok":true,"reason":"","steps":[]}
	if visiting.has(id):return {"ok":false,"reason":"순환 경로입니다.","steps":[]}
	if int(p.get("level",1))<int(n.get("level",1)):return {"ok":false,"reason":"LV.%d 필요"%int(n.level),"steps":[]}
	var conflicts=_conflicts(p,n)
	if not conflicts.is_empty():return {"ok":false,"reason":"배타 별자리 해제 필요","steps":[],"conflicts":conflicts}
	if n.type=="keystone" and _key_count(p)>=MAX_KEYSTONES:return {"ok":false,"reason":"핵심 별자리는 최대 2개입니다.","steps":[]}
	var steps=[];var trail=visiting.duplicate();trail.append(id)
	if not _parents_met(p,n):
		if n.get("parent_mode","any")=="all":
			for parent in n.parents:
				var required=_plan(p,parent,int(n.get("required_rank",1)),trail)
				if not required.ok:return required
				steps.append_array(required.steps)
		else:
			var best={};var best_cost=2147483647
			for parent in n.parents:
				var trial=p.duplicate(true);var required=_plan(trial,parent,int(n.get("required_rank",1)),trail)
				if required.ok and spent_points(trial)-spent_points(p)<best_cost:best=required;best["player"]=trial;best_cost=spent_points(trial)-spent_points(p)
			if best.is_empty():return {"ok":false,"reason":"열 수 있는 선행 경로가 없습니다.","steps":[]}
			p.skill_ranks=best.player.get("skill_ranks",{});p.constellation_allocations=best.player.get("constellation_allocations",{});steps.append_array(best.steps)
	if not p.has(n.allocation_field):p[n.allocation_field]={}
	while rank(p,n)<needed:
		var next=rank(p,n)+1;p[n.allocation_field][id]=next;steps.append({"id":id,"rank":next,"cost":n.cost})
	return {"ok":true,"reason":"","steps":steps}
